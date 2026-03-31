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

func (h *HealthHandler) Health(c *gin.Context) {
	pending := model.StatusPending
	count, _ := h.store.Count(c.Request.Context(), &pending, nil)

	response.Success(c, gin.H{
		"status":                "ok",
		"uptime_seconds":        int(time.Since(h.startTime).Seconds()),
		"connected_clients":     h.hub.ConnectedClients(),
		"pending_notifications": count,
	})
}
