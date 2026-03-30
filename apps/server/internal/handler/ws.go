package handler

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"

	"github.com/dingit-me/server/internal/model"
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
		log.Printf("[WS] upgrade error: %v", err)
		return
	}

	log.Println("[Server] New WebSocket client connected")

	// Get pending notifications for sync
	pending := model.StatusPending
	notifications, err := h.store.List(c.Request.Context(), &pending, 1000, 0)
	if err != nil {
		log.Printf("[WS] failed to load pending: %v", err)
		notifications = []model.Notification{}
	}

	h.hub.AddClient(conn, notifications)
}
