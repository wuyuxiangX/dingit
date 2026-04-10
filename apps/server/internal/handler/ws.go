package handler

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"go.uber.org/zap"

	"github.com/dingit-me/server/internal/config"
	"github.com/dingit-me/server/internal/model"
	"github.com/dingit-me/server/internal/pkg/logger"
	"github.com/dingit-me/server/internal/service"
	"github.com/dingit-me/server/internal/ws"
)

// buildUpgrader returns a websocket.Upgrader whose CheckOrigin is driven
// by the same CORS config as the REST API. Without this, any page on any
// origin can cross-site-WebSocket-hijack a logged-in user's session.
func buildUpgrader(cors config.CORSConfig) *websocket.Upgrader {
	allowAll := len(cors.AllowedOrigins) == 0
	allowed := make(map[string]bool, len(cors.AllowedOrigins))
	for _, o := range cors.AllowedOrigins {
		if o == "*" {
			allowAll = true
			continue
		}
		allowed[o] = true
	}
	return &websocket.Upgrader{
		CheckOrigin: func(r *http.Request) bool {
			origin := r.Header.Get("Origin")
			// Non-browser clients (Flutter IO, CLI tools) don't send Origin.
			// These are already gated by the API-key middleware upstream, so
			// it's safe to let them through.
			if origin == "" {
				return true
			}
			if allowAll {
				return true
			}
			return allowed[origin]
		},
	}
}

type WsHandler struct {
	store    *service.Store
	hub      *ws.Hub
	upgrader *websocket.Upgrader
}

func NewWsHandler(store *service.Store, hub *ws.Hub, cors config.CORSConfig) *WsHandler {
	return &WsHandler{store: store, hub: hub, upgrader: buildUpgrader(cors)}
}

func (h *WsHandler) Handle(c *gin.Context) {
	conn, err := h.upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		logger.Error("WebSocket upgrade error", zap.Error(err))
		return
	}

	logger.Info("New WebSocket client connected", zap.String("ip", c.ClientIP()))

	var notifications []model.Notification

	// If client provides "since" param, send all notifications since that time
	if sinceStr := c.Query("since"); sinceStr != "" {
		since, err := time.Parse(time.RFC3339, sinceStr)
		if err == nil {
			notifications, err = h.store.ListSince(c.Request.Context(), since, 1000)
			if err != nil {
				logger.Error("Failed to load notifications since", zap.Error(err))
				notifications = []model.Notification{}
			}
		}
	}

	// Default: send all pending notifications (backward compatible)
	if notifications == nil {
		pending := model.StatusPending
		notifications, err = h.store.List(c.Request.Context(), &pending, nil, 1000, 0)
		if err != nil {
			logger.Error("Failed to load pending notifications", zap.Error(err))
			notifications = []model.Notification{}
		}
	}

	h.hub.AddClient(conn, notifications)
}
