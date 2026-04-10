package ws

import (
	"encoding/json"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"go.uber.org/zap"

	"github.com/dingit-me/server/internal/model"
	"github.com/dingit-me/server/internal/pkg/logger"
)

// WebSocket resource limits. These are the per-connection safeguards that
// previously didn't exist — a dead/slow client could hold the broadcast
// goroutine forever, and two concurrent broadcasts could race on the same
// conn (Gorilla requires writes to be serialized per connection).
const (
	// Max size of an inbound message. 64 KiB is plenty for ping/action
	// responses; anything larger is almost certainly hostile or buggy.
	maxMessageSize = 64 * 1024

	// How long we wait for a write to complete. Without this a slow client
	// can block the writer goroutine indefinitely (until TCP keep-alive
	// kicks in, which can be hours).
	writeWait = 10 * time.Second

	// How long we wait for a pong after sending a ping. If the pong
	// doesn't arrive the read deadline fires and we drop the client.
	pongWait = 60 * time.Second

	// How often we send pings. Must be less than pongWait.
	pingPeriod = (pongWait * 9) / 10

	// Outbound buffer per client. If the buffer fills up (client can't
	// keep up with broadcast rate) we drop the client rather than block
	// the broadcaster. 64 messages is enough to absorb transient spikes
	// without allocating huge per-connection buffers.
	sendBuffer = 64

	// Hard cap on concurrent connections. Sized generously for the
	// single-tenant use case, but prevents a runaway fan-out attack.
	maxClients = 10_000
)

type ActionHandler func(response *model.ActionResponse)

// Client wraps a live websocket.Conn with a dedicated writer goroutine
// and an outbound channel. Every write to the conn goes through send,
// so we never call WriteMessage from more than one goroutine at a time.
// close() is idempotent; the first call wins and everything else is a
// no-op.
type Client struct {
	hub       *Hub
	conn      *websocket.Conn
	send      chan []byte
	closeOnce sync.Once
}

type Hub struct {
	mu               sync.RWMutex
	clients          map[*Client]struct{}
	onActionResponse ActionHandler
}

func NewHub(onActionResponse ActionHandler) *Hub {
	return &Hub{
		clients:          make(map[*Client]struct{}),
		onActionResponse: onActionResponse,
	}
}

func (h *Hub) ConnectedClients() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}

// AddClient registers a new connection, sends the initial sync payload,
// and spins up the dedicated read/write goroutines. The caller must not
// touch conn again after handing it to the hub — the hub owns the
// connection's lifecycle from this point on.
//
// If the hub is already at maxClients the new connection is rejected:
// we send a close frame with policy-violation code and return. This
// keeps the server's memory footprint bounded under a connection flood.
func (h *Hub) AddClient(conn *websocket.Conn, syncMessages []model.Notification) {
	h.mu.Lock()
	if len(h.clients) >= maxClients {
		h.mu.Unlock()
		logger.Warn("Rejecting WS client: hub at capacity", zap.Int("capacity", maxClients))
		_ = conn.WriteControl(
			websocket.CloseMessage,
			websocket.FormatCloseMessage(websocket.ClosePolicyViolation, "server at capacity"),
			time.Now().Add(writeWait),
		)
		conn.Close()
		return
	}
	client := &Client{
		hub:  h,
		conn: conn,
		send: make(chan []byte, sendBuffer),
	}
	h.clients[client] = struct{}{}
	h.mu.Unlock()

	// Configure read limits BEFORE starting any goroutines so the first
	// message already has the right limits applied.
	conn.SetReadLimit(maxMessageSize)
	_ = conn.SetReadDeadline(time.Now().Add(pongWait))
	conn.SetPongHandler(func(string) error {
		return conn.SetReadDeadline(time.Now().Add(pongWait))
	})

	// Queue the initial sync payload onto the send channel. Using the
	// same path as Broadcast means it's serialized with any concurrent
	// writes and respects the write deadline.
	data, err := json.Marshal(model.NewSyncFullMsg(syncMessages))
	if err != nil {
		logger.Error("Hub initial sync marshal error", zap.Error(err))
	} else {
		select {
		case client.send <- data:
		default:
			// Should never happen on a fresh channel, but if it does the
			// client gets dropped rather than blocking.
			h.removeClient(client)
			return
		}
	}

	go client.writePump()
	go client.readPump()
}

// Broadcast fans a message out to every connected client via their send
// channels. Slow clients (full send buffer) are dropped rather than
// allowed to back up the broadcaster — this is the critical invariant
// that makes the hub bounded.
func (h *Hub) Broadcast(msg model.WsMessage) {
	data, err := json.Marshal(msg)
	if err != nil {
		logger.Error("WsHub marshal error", zap.Error(err))
		return
	}

	// Snapshot under read lock so we don't hold the mutex while sending.
	h.mu.RLock()
	clients := make([]*Client, 0, len(h.clients))
	for c := range h.clients {
		clients = append(clients, c)
	}
	h.mu.RUnlock()

	var dropped []*Client
	for _, c := range clients {
		select {
		case c.send <- data:
		default:
			// Client can't keep up. Drop it — its writer goroutine will
			// exit once the send channel is closed in removeClient.
			dropped = append(dropped, c)
		}
	}

	for _, c := range dropped {
		logger.Warn("Dropping slow WS client: send buffer full")
		h.removeClient(c)
	}
}

// removeClient unregisters a client and tears down its send channel.
// Idempotent via closeOnce, so it's safe to call from either pump or
// from the broadcaster's slow-client detection.
func (h *Hub) removeClient(c *Client) {
	c.closeOnce.Do(func() {
		h.mu.Lock()
		delete(h.clients, c)
		h.mu.Unlock()
		close(c.send)
		// Don't close c.conn here — writePump will drain send (or see
		// it closed) and then close the conn itself, which guarantees
		// no "write after close" panics.
	})
}

// writePump is the ONLY place that calls conn.WriteMessage for a given
// client. Every other component (Broadcast, initial sync, pong reply,
// ping ticker) goes through c.send. This is what makes the hub
// thread-safe against Gorilla's per-connection write serialization
// requirement.
func (c *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case data, ok := <-c.send:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				// Hub closed the channel → graceful shutdown. Send a
				// close frame so the client knows it's not a network
				// error.
				_ = c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := c.conn.WriteMessage(websocket.TextMessage, data); err != nil {
				c.hub.removeClient(c)
				return
			}
		case <-ticker.C:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				c.hub.removeClient(c)
				return
			}
		}
	}
}

// readPump reads inbound messages, dispatches recognized ones, and
// unregisters the client when anything goes wrong (including a pong
// timeout, which shows up as a read deadline exceeded error).
func (c *Client) readPump() {
	defer func() {
		c.hub.removeClient(c)
	}()

	for {
		_, data, err := c.conn.ReadMessage()
		if err != nil {
			return
		}

		msg, err := model.ParseWsMessage(data)
		if err != nil {
			logger.Warn("WsHub parse error", zap.Error(err))
			continue
		}

		switch msg.Type {
		case "action.response":
			if msg.Response != nil && c.hub.onActionResponse != nil {
				c.hub.onActionResponse(msg.Response)
			}
		case "ping":
			// Client-level JSON ping (separate from the protocol-level
			// WebSocket ping). Reply with pong via the normal send path
			// so it's serialized with any other writes.
			if pong, err := json.Marshal(model.NewPongMsg()); err == nil {
				select {
				case c.send <- pong:
				default:
					// Client's send buffer is full — it's about to get
					// dropped by the next broadcast anyway.
				}
			}
		}
	}
}

// Close shuts down every connected client. Called during server
// shutdown; new connections are already blocked because the HTTP server
// is refusing new requests at this point.
func (h *Hub) Close() {
	h.mu.Lock()
	clients := make([]*Client, 0, len(h.clients))
	for c := range h.clients {
		clients = append(clients, c)
	}
	h.mu.Unlock()

	for _, c := range clients {
		h.removeClient(c)
	}
}
