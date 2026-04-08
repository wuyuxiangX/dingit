package model

import (
	"encoding/json"
	"testing"
)

func TestNewNotificationNewMsg(t *testing.T) {
	n := &Notification{ID: "ntf_123", Title: "Test"}
	msg := NewNotificationNewMsg(n)

	if msg.Type != "notification.new" {
		t.Errorf("expected type notification.new, got %s", msg.Type)
	}
	if msg.Notification.ID != "ntf_123" {
		t.Errorf("expected notification ID ntf_123, got %s", msg.Notification.ID)
	}
}

func TestNewNotificationUpdatedMsg(t *testing.T) {
	n := &Notification{ID: "ntf_456", Status: StatusActioned}
	msg := NewNotificationUpdatedMsg(n)

	if msg.Type != "notification.updated" {
		t.Errorf("expected type notification.updated, got %s", msg.Type)
	}
}

func TestNewSyncFullMsg_NilSlice(t *testing.T) {
	msg := NewSyncFullMsg(nil)

	if msg.Type != "sync.full" {
		t.Errorf("expected type sync.full, got %s", msg.Type)
	}
	if msg.Notifications == nil {
		t.Error("expected non-nil notifications slice for nil input")
	}
	if len(msg.Notifications) != 0 {
		t.Errorf("expected empty slice, got %d items", len(msg.Notifications))
	}
}

func TestNewSyncFullMsg_WithData(t *testing.T) {
	notifications := []Notification{{ID: "ntf_1"}, {ID: "ntf_2"}}
	msg := NewSyncFullMsg(notifications)

	if len(msg.Notifications) != 2 {
		t.Errorf("expected 2 notifications, got %d", len(msg.Notifications))
	}
}

func TestNewNotificationDeletedMsg(t *testing.T) {
	msg := NewNotificationDeletedMsg("ntf_789")

	if msg.Type != "notification.deleted" {
		t.Errorf("expected type notification.deleted, got %s", msg.Type)
	}
	if msg.NotificationID == nil || *msg.NotificationID != "ntf_789" {
		t.Error("expected notification_id ntf_789")
	}
}

func TestNewPongMsg(t *testing.T) {
	msg := NewPongMsg()
	if msg.Type != "pong" {
		t.Errorf("expected type pong, got %s", msg.Type)
	}
}

func TestParseWsMessage_Valid(t *testing.T) {
	data := []byte(`{"type":"notification.new","notification":{"id":"ntf_1","title":"Hello","body":"World","timestamp":"2026-01-01T00:00:00Z","source":"test","status":"pending","priority":"normal"}}`)
	msg, err := ParseWsMessage(data)

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if msg.Type != "notification.new" {
		t.Errorf("expected type notification.new, got %s", msg.Type)
	}
	if msg.Notification == nil || msg.Notification.ID != "ntf_1" {
		t.Error("expected notification with ID ntf_1")
	}
}

func TestParseWsMessage_Invalid(t *testing.T) {
	_, err := ParseWsMessage([]byte("not json"))
	if err == nil {
		t.Error("expected error for invalid JSON")
	}
}

func TestNotificationJSON_OmitsEmptyIcon(t *testing.T) {
	n := Notification{ID: "ntf_1", Title: "Test", Body: "Body", Status: StatusPending, Priority: PriorityNormal}
	data, err := json.Marshal(n)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var m map[string]any
	json.Unmarshal(data, &m)
	if _, ok := m["icon"]; ok {
		t.Error("expected icon to be omitted when nil")
	}
}

func TestStatusConstants(t *testing.T) {
	statuses := map[NotificationStatus]string{
		StatusPending:   "pending",
		StatusActioned:  "actioned",
		StatusDismissed: "dismissed",
		StatusExpired:   "expired",
	}
	for s, expected := range statuses {
		if string(s) != expected {
			t.Errorf("expected %s, got %s", expected, s)
		}
	}
}

func TestPriorityConstants(t *testing.T) {
	priorities := map[NotificationPriority]string{
		PriorityUrgent: "urgent",
		PriorityHigh:   "high",
		PriorityNormal: "normal",
		PriorityLow:    "low",
	}
	for p, expected := range priorities {
		if string(p) != expected {
			t.Errorf("expected %s, got %s", expected, p)
		}
	}
}
