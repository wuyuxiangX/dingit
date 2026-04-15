package service

import (
	"testing"
	"time"

	"github.com/dingit-me/server/internal/model"
)

func intPtr(i int) *int { return &i }

// fixedNow: 2026-04-15 23:30 UTC. A UTC+8 device sees this as 07:30
// next day — inside a 22:00→08:00 DND window, which exercises the
// cross-midnight wraparound branch of IsInDnd.
var fixedNow = time.Date(2026, 4, 15, 23, 30, 0, 0, time.UTC)

// dndDevice is a UTC+8 Android device with DND enabled 22:00→08:00 local.
// At fixedNow (07:30 local) the device IS inside the DND window.
func dndDevice() Device {
	return Device{
		ID:                 "dev_test_01",
		Token:              "test-token-dnd",
		Platform:           "android",
		DndEnabled:         true,
		DndStartMinute:     intPtr(22 * 60), // 22:00
		DndEndMinute:       intPtr(8 * 60),  // 08:00
		DndTzOffsetMinutes: 8 * 60,          // UTC+8
	}
}

// openDevice is the same device with DND disabled — used to assert that
// non-urgent notifications still get the full ringing payload when DND
// is off.
func openDevice() Device {
	d := dndDevice()
	d.DndEnabled = false
	d.Token = "test-token-open"
	return d
}

func testNotification(priority model.NotificationPriority) *model.Notification {
	return &model.Notification{
		ID:       "n_test_1",
		Title:    "Build failed",
		Body:     "CI pipeline broke on main",
		Source:   "github-actions",
		Priority: priority,
	}
}

func TestBuildFcmPayload_NonUrgentDuringDND_IsDataOnly(t *testing.T) {
	payload := buildFcmPayload(dndDevice(), testNotification(model.PriorityNormal), fixedNow)

	msg := payload["message"].(map[string]any)

	if _, hasNotification := msg["notification"]; hasNotification {
		t.Errorf("expected data-only payload during DND, but 'notification' key was present")
	}
	if _, hasAndroid := msg["android"]; hasAndroid {
		t.Errorf("expected data-only payload during DND, but 'android' config was present (would force heads-up)")
	}

	data := msg["data"].(map[string]string)
	if data["title"] == "" || data["body"] == "" {
		t.Errorf("data-only payload should carry title/body in 'data' so the app can build a local notification: %#v", data)
	}
	if data["notification_id"] != "n_test_1" {
		t.Errorf("data.notification_id should survive DND redirect, got %q", data["notification_id"])
	}
}

func TestBuildFcmPayload_UrgentDuringDND_BreaksThrough(t *testing.T) {
	payload := buildFcmPayload(dndDevice(), testNotification(model.PriorityUrgent), fixedNow)
	msg := payload["message"].(map[string]any)

	notif, ok := msg["notification"].(map[string]string)
	if !ok {
		t.Fatalf("urgent notifications must ship a 'notification' object even during DND")
	}
	if notif["title"] != "Build failed" {
		t.Errorf("expected title in notification block, got %#v", notif)
	}

	android, ok := msg["android"].(map[string]any)
	if !ok {
		t.Fatalf("urgent notifications must include android config")
	}
	if android["priority"] != "high" {
		t.Errorf("urgent android.priority should be 'high', got %v", android["priority"])
	}
	andNotif := android["notification"].(map[string]string)
	// FCM v1 REST API requires camelCase field names. Shipping
	// snake_case here silently 400s every urgent push on Android —
	// guard against the regression explicitly.
	if _, bad := andNotif["notification_priority"]; bad {
		t.Errorf("snake_case notification_priority is not accepted by FCM v1 — must be notificationPriority")
	}
	if andNotif["notificationPriority"] != "PRIORITY_HIGH" {
		t.Errorf("urgent android.notification.notificationPriority should be PRIORITY_HIGH, got %v", andNotif["notificationPriority"])
	}
}

func TestBuildFcmPayload_NonUrgentOutsideDND_IsFullNotification(t *testing.T) {
	payload := buildFcmPayload(openDevice(), testNotification(model.PriorityNormal), fixedNow)
	msg := payload["message"].(map[string]any)

	notif, ok := msg["notification"].(map[string]string)
	if !ok {
		t.Fatalf("non-urgent outside DND should still ring: expected 'notification' object")
	}
	if notif["title"] != "Build failed" {
		t.Errorf("unexpected notification block: %#v", notif)
	}

	android := msg["android"].(map[string]any)
	if android["priority"] != "normal" {
		t.Errorf("non-urgent android.priority should be 'normal', got %v", android["priority"])
	}
}

func TestBuildFcmPayload_PreservesDataKeys(t *testing.T) {
	// Every payload shape must carry the core metadata keys used by the
	// Android client to look up the notification in history. If a future
	// refactor drops one of these, the Android app's dismiss-sync and
	// deep-link flows break silently.
	cases := []struct {
		name     string
		dev      Device
		priority model.NotificationPriority
	}{
		{"urgent+dnd", dndDevice(), model.PriorityUrgent},
		{"urgent+open", openDevice(), model.PriorityUrgent},
		{"normal+dnd", dndDevice(), model.PriorityNormal},
		{"normal+open", openDevice(), model.PriorityNormal},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			payload := buildFcmPayload(tc.dev, testNotification(tc.priority), fixedNow)
			msg := payload["message"].(map[string]any)
			data := msg["data"].(map[string]string)

			if data["notification_id"] != "n_test_1" {
				t.Errorf("missing notification_id in data: %#v", data)
			}
			if data["source"] != "github-actions" {
				t.Errorf("missing source in data: %#v", data)
			}
			if data["priority"] != string(tc.priority) {
				t.Errorf("missing/wrong priority in data: got %q want %q", data["priority"], tc.priority)
			}
		})
	}
}
