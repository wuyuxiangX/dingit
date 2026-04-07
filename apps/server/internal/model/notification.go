package model

import (
	"encoding/json"
	"time"
)

type NotificationStatus string

const (
	StatusPending   NotificationStatus = "pending"
	StatusActioned  NotificationStatus = "actioned"
	StatusDismissed NotificationStatus = "dismissed"
	StatusExpired   NotificationStatus = "expired"
)

type NotificationPriority string

const (
	PriorityUrgent NotificationPriority = "urgent"
	PriorityHigh   NotificationPriority = "high"
	PriorityNormal NotificationPriority = "normal"
	PriorityLow    NotificationPriority = "low"
)

type NotificationAction struct {
	Label       string  `json:"label"`
	Value       string  `json:"value"`
	ColorHex    *string `json:"color_hex"`
	Icon        *string `json:"icon"`
	Destructive bool    `json:"destructive"`
}

type Notification struct {
	ID            string               `json:"id"`
	Title         string               `json:"title"`
	Body          string               `json:"body"`
	Timestamp     time.Time            `json:"timestamp"`
	Source        string               `json:"source"`
	Actions       []NotificationAction `json:"actions"`
	CallbackURL   *string              `json:"callback_url"`
	Status        NotificationStatus   `json:"status"`
	Priority      NotificationPriority `json:"priority"`
	Icon          *string              `json:"icon,omitempty"`
	ActionedAt    *time.Time           `json:"actioned_at"`
	ActionedValue *string              `json:"actioned_value"`
	Metadata      map[string]any       `json:"metadata"`
	ExpiresAt     *time.Time           `json:"expires_at,omitempty"`
}

type ActionResponse struct {
	NotificationID string    `json:"notification_id"`
	Action         string    `json:"action"`
	Timestamp      time.Time `json:"timestamp"`
	Source         *string   `json:"source,omitempty"`
}

// --- WebSocket Protocol Messages ---

type WsMessage struct {
	Type           string          `json:"type"`
	Notification   *Notification   `json:"notification,omitempty"`
	Notifications  []Notification  `json:"notifications"`
	Response       *ActionResponse `json:"response,omitempty"`
	NotificationID *string         `json:"notification_id,omitempty"`
}

func NewNotificationNewMsg(n *Notification) WsMessage {
	return WsMessage{Type: "notification.new", Notification: n}
}

func NewNotificationUpdatedMsg(n *Notification) WsMessage {
	return WsMessage{Type: "notification.updated", Notification: n}
}

func NewSyncFullMsg(notifications []Notification) WsMessage {
	if notifications == nil {
		notifications = []Notification{}
	}
	return WsMessage{Type: "sync.full", Notifications: notifications}
}

func NewNotificationDeletedMsg(id string) WsMessage {
	return WsMessage{Type: "notification.deleted", NotificationID: &id}
}

func NewPongMsg() WsMessage {
	return WsMessage{Type: "pong"}
}

func ParseWsMessage(data []byte) (*WsMessage, error) {
	var msg WsMessage
	if err := json.Unmarshal(data, &msg); err != nil {
		return nil, err
	}
	return &msg, nil
}
