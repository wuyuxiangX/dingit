package main

import (
	"context"
	"flag"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	"github.com/dingit-me/server/internal/config"
	"github.com/dingit-me/server/internal/db"
	"github.com/dingit-me/server/internal/handler"
	"github.com/dingit-me/server/internal/middleware"
	"github.com/dingit-me/server/internal/model"
	"github.com/dingit-me/server/internal/pkg/logger"
	"github.com/dingit-me/server/internal/service"
	"github.com/dingit-me/server/internal/ws"
)

func main() {
	// CLI flags
	generateKey := flag.Bool("generate-key", false, "Generate a new API key and exit")
	flag.Parse()

	if *generateKey {
		fmt.Println(service.GenerateAPIKey())
		os.Exit(0)
	}

	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to load config: %v\n", err)
		os.Exit(1)
	}

	// Initialize structured logger
	logger.Init(logger.Config(cfg.Logger))
	defer logger.Sync()

	// Gin mode
	if cfg.IsProduction() {
		gin.SetMode(gin.ReleaseMode)
	}

	// App-wide context, cancelled on shutdown
	ctx, ctxCancel := context.WithCancel(context.Background())
	defer ctxCancel()
	pool, err := db.Connect(ctx, cfg.Database.URL)
	if err != nil {
		logger.Fatal("Failed to connect to database", zap.Error(err))
	}
	defer pool.Close()
	logger.Info("Connected to PostgreSQL")

	// Services
	store := service.NewStore(pool)
	callbackSvc := service.NewCallbackService()
	apiKeySvc := service.NewAPIKeyService(pool)
	deviceSvc := service.NewDeviceService(pool)

	// Push notification services
	var apnsSvc *service.ApnsService
	if keyFile := os.Getenv("APNS_KEY_FILE"); keyFile != "" {
		apnsCfg := service.ApnsConfig{
			KeyFile:  keyFile,
			KeyID:    os.Getenv("APNS_KEY_ID"),
			TeamID:   os.Getenv("APNS_TEAM_ID"),
			BundleID: envOrDefault("APNS_BUNDLE_ID", "com.notifyhub.notifyApp"),
			Sandbox:  os.Getenv("APNS_ENV") != "production",
		}
		var err error
		apnsSvc, err = service.NewApnsService(apnsCfg, deviceSvc)
		if err != nil {
			logger.Warn("APNs push disabled", zap.Error(err))
		} else {
			logger.Info("APNs push enabled", zap.String("key_id", apnsCfg.KeyID))
		}
	}

	var fcmSvc *service.FcmService
	if projectID := os.Getenv("FCM_PROJECT_ID"); projectID != "" {
		var err error
		fcmSvc, err = service.NewFcmService(projectID, deviceSvc)
		if err != nil {
			logger.Warn("FCM push disabled", zap.Error(err))
		} else {
			logger.Info("FCM push enabled", zap.String("project_id", projectID))
		}
	}

	pushRouter := service.NewPushRouter(apnsSvc, fcmSvc)

	// Seed API key from env if provided
	if err := apiKeySvc.SeedFromEnv(ctx, cfg.APIKey); err != nil {
		logger.Fatal("Failed to seed API key", zap.Error(err))
	}

	// Auto-generate key on first startup if none exist
	keyCount, err := apiKeySvc.Count(ctx)
	if err != nil {
		logger.Fatal("Failed to count API keys", zap.Error(err))
	}
	if keyCount == 0 {
		rawKey := service.GenerateAPIKey()
		if _, err := apiKeySvc.Create(ctx, "auto-generated", rawKey); err != nil {
			logger.Fatal("Failed to save API key", zap.Error(err))
		}

		// Write the full key to a 0600 file so operators can recover it
		// even if they missed the stderr banner. Try candidate paths in
		// priority order until one accepts the write:
		//   1. /secrets/.initial-api-key — preferred because operators
		//      look in /secrets for anything credential-shaped.
		//   2. .initial-api-key (CWD) — fallback for bare-metal deploys
		//      where there is no /secrets mount.
		//   3. /tmp/.initial-api-key — last resort, survives until the
		//      container restarts but is always writable inside typical
		//      containers where /app and /secrets are non-writable.
		//
		// /secrets is typically mounted read-only in production (which
		// is the right call — credentials are injected by the
		// orchestrator, not writable by the app), so we probe
		// writability by actually attempting the write, not just
		// stat-ing the directory. Same story for CWD: non-root users
		// in a well-hardened image usually can't write to WORKDIR.
		keyCandidates := []string{
			"/secrets/.initial-api-key",
			".initial-api-key",
			"/tmp/.initial-api-key",
		}
		var keyFilePath string
		var writeErr error
		for _, p := range keyCandidates {
			if err := os.WriteFile(p, []byte(rawKey+"\n"), 0o600); err != nil {
				writeErr = err
				continue
			}
			keyFilePath = p
			writeErr = nil
			break
		}

		// Print the full key to stderr with a loud banner. Stderr bypasses
		// the structured logger so it always shows even under JSON mode,
		// and ops scripts can grep for the banner marker.
		banner := "\n" +
			"================================================================\n" +
			"  DINGIT: initial API key generated (first run)\n" +
			"  Save this value — the full key cannot be recovered from the DB.\n" +
			"----------------------------------------------------------------\n" +
			"  " + rawKey + "\n" +
			"================================================================\n"
		if writeErr == nil {
			banner += "  Also written to: " + keyFilePath + " (chmod 600)\n"
		} else {
			banner += "  WARNING: failed to persist key file: " + writeErr.Error() + "\n"
		}
		fmt.Fprint(os.Stderr, banner)

		// The structured log still gets a record, but only with the prefix
		// so the full key never ends up in log aggregation / SIEM.
		logger.Info("No API keys found. Generated initial key",
			zap.String("key_prefix", rawKey[:15]+"..."),
			zap.String("key_file", keyFilePath),
		)
	}

	// WebSocket Hub
	var hub *ws.Hub
	hub = ws.NewHub(func(response *model.ActionResponse) {
		logger.Info("Action response",
			zap.String("notification_id", response.NotificationID),
			zap.String("action", response.Action),
		)

		opCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		updated, err := store.UpdateStatus(opCtx, response.NotificationID, model.StatusActioned, &response.Action)
		if err != nil {
			logger.Error("Failed to update status", zap.Error(err))
			return
		}
		if updated == nil {
			return
		}

		hub.Broadcast(model.NewNotificationUpdatedMsg(updated))

		if updated.CallbackURL != nil {
			callbackSvc.Deliver(updated, response)
		}
	})
	defer hub.Close()

	// Expiry service
	expirySvc := service.NewExpiryService(store, hub, 60*time.Second)
	go expirySvc.Start(ctx)

	// Handlers
	notificationHandler := handler.NewNotificationHandler(store, hub, callbackSvc, pushRouter)
	healthHandler := handler.NewHealthHandler(store, hub)
	wsHandler := handler.NewWsHandler(store, hub, cfg.CORS)
	deviceHandler := handler.NewDeviceHandler(deviceSvc)

	// Router
	r := gin.New()

	// Global middleware chain (order matters)
	r.Use(middleware.Recovery())
	r.Use(middleware.SecurityHeaders())
	r.Use(middleware.CORS(cfg.CORS))
	r.Use(middleware.RequestLog())

	// Per-IP rate limit BEFORE auth. This caps the damage from anyone
	// brute-forcing API keys — without it, every invalid key cost us a
	// DB query with no throttle. Limits are generous so legitimate
	// clients never notice (50 rps burst 100 per IP).
	r.Use(middleware.IPRateLimit(50, 100))

	// API Key auth middleware. Only /health is exempt — /ws now requires
	// the same API key as the REST API, either via Authorization header,
	// X-API-Key header, or ?api_key= query param (for browser clients
	// that cannot set headers during the WebSocket upgrade).
	r.Use(middleware.APIKeyAuth(apiKeySvc, map[string]bool{
		"/health": true,
	}))

	// Rate limiting (after auth, so api_key_id is available)
	if cfg.RateLimit.Enabled {
		r.Use(middleware.RateLimit(cfg.RateLimit))
		logger.Info("Rate limiting enabled",
			zap.Float64("rps", cfg.RateLimit.RequestsPerSec),
			zap.Int("burst", cfg.RateLimit.BurstSize),
		)
	}

	// Routes
	r.GET("/health", healthHandler.Health)
	r.GET("/ws", wsHandler.Handle)

	api := r.Group("/api")
	{
		api.POST("/notifications", notificationHandler.Create)
		api.GET("/notifications", notificationHandler.List)
		api.GET("/notifications/:id", notificationHandler.GetByID)
		api.PATCH("/notifications/:id", notificationHandler.Update)
		api.DELETE("/notifications/:id", notificationHandler.Delete)
		api.POST("/devices", deviceHandler.Register)
		// Verbose health view is authenticated so unauthenticated
		// clients can't enumerate connection counts or queue depth.
		api.GET("/health/debug", healthHandler.HealthDebug)
	}

	// Server with timeouts and graceful shutdown
	addr := fmt.Sprintf(":%d", cfg.Server.Port)
	srv := &http.Server{
		Addr:              addr,
		Handler:           r,
		ReadHeaderTimeout: 10 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

	go func() {
		logger.Info("Dingit Server started",
			zap.String("addr", addr),
			zap.String("env", cfg.App.Env),
		)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("Server error", zap.Error(err))
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down server...")
	ctxCancel()                 // stop expiry service before closing hub
	middleware.StopLimiterGC() // stop rate-limiter sweeper goroutines
	apiKeySvc.Stop()           // drain last_used_at batcher
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		logger.Fatal("Server forced to shutdown", zap.Error(err))
	}
	logger.Info("Server stopped")
}

func envOrDefault(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
