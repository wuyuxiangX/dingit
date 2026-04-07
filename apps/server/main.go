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

	// Connect to PostgreSQL
	ctx := context.Background()
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

	// Push notification service (optional — requires GOOGLE_APPLICATION_CREDENTIALS)
	var pushSvc *service.PushService
	if projectID := os.Getenv("FCM_PROJECT_ID"); projectID != "" {
		var err error
		pushSvc, err = service.NewPushService(projectID, deviceSvc)
		if err != nil {
			logger.Warn("FCM push disabled — credentials not found", zap.Error(err))
		} else {
			logger.Info("FCM push enabled", zap.String("project_id", projectID))
		}
	}

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
		logger.Info("No API keys found. Generated initial key",
			zap.String("key", rawKey),
		)
		logger.Warn("Save this key — it will not be shown again")
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

	// Handlers
	notificationHandler := handler.NewNotificationHandler(store, hub, callbackSvc, pushSvc)
	healthHandler := handler.NewHealthHandler(store, hub)
	wsHandler := handler.NewWsHandler(store, hub)
	deviceHandler := handler.NewDeviceHandler(deviceSvc)

	// Router
	r := gin.New()

	// Global middleware chain (order matters)
	r.Use(middleware.Recovery())
	r.Use(middleware.SecurityHeaders())
	r.Use(middleware.CORS(cfg.CORS))
	r.Use(middleware.RequestLog())

	// API Key auth middleware
	r.Use(middleware.APIKeyAuth(apiKeySvc, map[string]bool{
		"/health": true,
		"/ws":     true,
	}))

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
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		logger.Fatal("Server forced to shutdown", zap.Error(err))
	}
	logger.Info("Server stopped")
}
