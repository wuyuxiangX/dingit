package ws

import (
	"encoding/json"
	"log"
	"sync"

	"github.com/gorilla/websocket"

	"github.com/dingit-me/server/internal/model"
)

type ActionHandler func(response *model.ActionResponse)

type Hub struct {
	mu              sync.RWMutex
	clients         map[*websocket.Conn]struct{}
	onActionResponse ActionHandler
}

func NewHub(onActionResponse ActionHandler) *Hub {
	return &Hub{
		clients:         make(map[*websocket.Conn]struct{}),
		onActionResponse: onActionResponse,
	}
}

func (h *Hub) ConnectedClients() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}

func (h *Hub) AddClient(conn *websocket.Conn, syncMessages []model.Notification) {
	h.mu.Lock()
	h.clients[conn] = struct{}{}
	h.mu.Unlock()

	// Send full sync
	h.sendTo(conn, model.NewSyncFullMsg(syncMessages))

	// Start reading in background
	go h.readPump(conn)
}

func (h *Hub) Broadcast(msg model.WsMessage) {
	data, err := json.Marshal(msg)
	if err != nil {
		log.Printf("[WsHub] marshal error: %v", err)
		return
	}

	h.mu.RLock()
	clients := make([]*websocket.Conn, 0, len(h.clients))
	for c := range h.clients {
		clients = append(clients, c)
	}
	h.mu.RUnlock()

	var stale []*websocket.Conn
	for _, c := range clients {
		if err := c.WriteMessage(websocket.TextMessage, data); err != nil {
			stale = append(stale, c)
		}
	}

	if len(stale) > 0 {
		h.mu.Lock()
		for _, c := range stale {
			delete(h.clients, c)
			c.Close()
		}
		h.mu.Unlock()
	}
}

func (h *Hub) readPump(conn *websocket.Conn) {
	defer func() {
		h.mu.Lock()
		delete(h.clients, conn)
		h.mu.Unlock()
		conn.Close()
	}()

	for {
		_, data, err := conn.ReadMessage()
		if err != nil {
			return
		}

		msg, err := model.ParseWsMessage(data)
		if err != nil {
			log.Printf("[WsHub] parse error: %v", err)
			continue
		}

		switch msg.Type {
		case "action.response":
			if msg.Response != nil && h.onActionResponse != nil {
				h.onActionResponse(msg.Response)
			}
		case "ping":
			h.sendTo(conn, model.NewPongMsg())
		}
	}
}

func (h *Hub) sendTo(conn *websocket.Conn, msg model.WsMessage) {
	data, err := json.Marshal(msg)
	if err != nil {
		return
	}
	if err := conn.WriteMessage(websocket.TextMessage, data); err != nil {
		h.mu.Lock()
		delete(h.clients, conn)
		h.mu.Unlock()
		conn.Close()
	}
}

func (h *Hub) Close() {
	h.mu.Lock()
	defer h.mu.Unlock()
	for c := range h.clients {
		c.Close()
		delete(h.clients, c)
	}
}
