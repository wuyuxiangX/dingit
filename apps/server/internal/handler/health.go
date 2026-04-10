package handler

import (
	"time"

	"github.com/gin-gonic/gin"

	"github.com/dingit-me/server/internal/model"
	"github.com/dingit-me/server/internal/pkg/response"
	"github.com/dingit-me/server/internal/service"
	"github.com/dingit-me/server/internal/ws"
)

type HealthHandler struct {
	store     *service.Store
	hub       *ws.Hub
	startTime time.Time
}

func NewHealthHandler(store *service.Store, hub *ws.Hub) *HealthHandler {
	return &HealthHandler{
		store:     store,
		hub:       hub,
		startTime: time.Now(),
	}
}

// Health is the public, unauthenticated health probe. It deliberately
// returns only `status` so unauthenticated callers can't enumerate
// operational signals like connection counts or pending queue depth.
// The richer view now lives on HealthDebug, which is authenticated.
func (h *HealthHandler) Health(c *gin.Context) {
	pending := model.StatusPending
	_, err := h.store.Count(c.Request.Context(), &pending, nil)

	status := "ok"
	if err != nil {
		status = "degraded"
	}

	response.Success(c, gin.H{"status": status})
}

// HealthDebug returns the verbose operational view. Must be mounted
// inside the authenticated route group so only API-key-holding callers
// can read it.
func (h *HealthHandler) HealthDebug(c *gin.Context) {
	pending := model.StatusPending
	count, err := h.store.Count(c.Request.Context(), &pending, nil)

	status := "ok"
	if err != nil {
		status = "degraded"
	}

	response.Success(c, gin.H{
		"status":                status,
		"uptime_seconds":        int(time.Since(h.startTime).Seconds()),
		"connected_clients":     h.hub.ConnectedClients(),
		"pending_notifications": count,
	})
}
