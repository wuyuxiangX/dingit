package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/dingit-me/server/internal/config"
	"github.com/dingit-me/server/internal/db"
	"github.com/dingit-me/server/internal/handler"
	"github.com/dingit-me/server/internal/model"
	"github.com/dingit-me/server/internal/service"
	"github.com/dingit-me/server/internal/ws"
)

func main() {
	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Connect to PostgreSQL
	ctx := context.Background()
	pool, err := db.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer pool.Close()
	log.Println("[DB] Connected to PostgreSQL")

	// Services
	store := service.NewStore(pool)
	callbackSvc := service.NewCallbackService()

	// WebSocket Hub (use pointer so the closure can reference it)
	var hub *ws.Hub
	hub = ws.NewHub(func(response *model.ActionResponse) {
		log.Printf("[Server] Action response: %s -> %s", response.NotificationID, response.Action)

		updated, err := store.UpdateStatus(ctx, response.NotificationID, model.StatusActioned, &response.Action)
		if err != nil {
			log.Printf("[Server] Failed to update status: %v", err)
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
	notificationHandler := handler.NewNotificationHandler(store, hub)
	healthHandler := handler.NewHealthHandler(store, hub)
	wsHandler := handler.NewWsHandler(store, hub)

	// Router
	r := gin.Default()

	// CORS
	r.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	})

	// Routes
	r.GET("/health", healthHandler.Health)
	r.GET("/ws", wsHandler.Handle)

	api := r.Group("/api")
	{
		api.POST("/notifications", notificationHandler.Create)
		api.GET("/notifications", notificationHandler.List)
		api.GET("/notifications/:id", notificationHandler.GetByID)
	}

	// Server with graceful shutdown
	addr := fmt.Sprintf(":%d", cfg.Port)
	srv := &http.Server{
		Addr:    addr,
		Handler: r,
	}

	go func() {
		log.Printf("🚀 Dingit Server running on http://localhost:%d", cfg.Port)
		log.Printf("   REST API: http://localhost:%d/api/notifications", cfg.Port)
		log.Printf("   WebSocket: ws://localhost:%d/ws", cfg.Port)
		log.Printf("   Health: http://localhost:%d/health", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server error: %v", err)
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}
	log.Println("Server stopped")
}
