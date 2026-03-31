package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"go.uber.org/zap"

	"github.com/dingit-me/server/internal/model"
	"github.com/dingit-me/server/internal/pkg/logger"
	"github.com/dingit-me/server/internal/service"
	"github.com/dingit-me/server/internal/ws"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

type WsHandler struct {
	store *service.Store
	hub   *ws.Hub
}

func NewWsHandler(store *service.Store, hub *ws.Hub) *WsHandler {
	return &WsHandler{store: store, hub: hub}
}

func (h *WsHandler) Handle(c *gin.Context) {
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		logger.Error("WebSocket upgrade error", zap.Error(err))
		return
	}

	logger.Info("New WebSocket client connected", zap.String("ip", c.ClientIP()))

	pending := model.StatusPending
	notifications, err := h.store.List(c.Request.Context(), &pending, nil, 1000, 0)
	if err != nil {
		logger.Error("Failed to load pending notifications", zap.Error(err))
		notifications = []model.Notification{}
	}

	h.hub.AddClient(conn, notifications)
}
