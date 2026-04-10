package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"

	"github.com/dingit-me/server/internal/middleware"
	"github.com/dingit-me/server/internal/model"
	"github.com/dingit-me/server/internal/service"
	"github.com/dingit-me/server/internal/ws"
)

func init() {
	gin.SetMode(gin.TestMode)
}

// mockNotificationStore is a minimal in-memory stand-in for *service.Store
// that satisfies the notificationStore interface. Each method has an
// optional override hook (xxxFn) so individual tests can capture inputs
// or return pre-arranged values without having to restate every method.
type mockNotificationStore struct {
	addFn func(ctx context.Context, n *model.Notification) (*model.Notification, error)
}

func (m *mockNotificationStore) Add(ctx context.Context, n *model.Notification) (*model.Notification, error) {
	if m.addFn != nil {
		return m.addFn(ctx, n)
	}
	// Default: assign a deterministic ID and return the input as-is.
	n.ID = "ntf_mock"
	n.Status = model.StatusPending
	return n, nil
}

func (m *mockNotificationStore) Get(context.Context, string) (*model.Notification, error) {
	return nil, nil
}

func (m *mockNotificationStore) List(context.Context, *model.NotificationStatus, *model.NotificationPriority, int, int) ([]model.Notification, error) {
	return nil, nil
}

func (m *mockNotificationStore) Count(context.Context, *model.NotificationStatus, *model.NotificationPriority) (int, error) {
	return 0, nil
}

func (m *mockNotificationStore) UpdateStatus(context.Context, string, model.NotificationStatus, *string) (*model.Notification, error) {
	return nil, nil
}

func (m *mockNotificationStore) Delete(context.Context, string) (bool, error) {
	return false, nil
}

// newTestRouter builds a minimal gin.Engine with the notification handler
// mounted at /api/notifications. skipAuth toggles whether the real
// APIKeyAuth middleware lets the request through: when true, we add the
// target path to skipPaths so the middleware short-circuits before
// touching the (nil) apiKeySvc. When false, the middleware still
// exercises its own "no key provided" branch — also safe against nil
// svc because the nil-pointer path is unreachable for unauthenticated
// requests.
func newTestRouter(t *testing.T, store notificationStore, skipAuth bool) *gin.Engine {
	t.Helper()
	r := gin.New()
	skip := map[string]bool{}
	if skipAuth {
		skip["/api/notifications"] = true
	}
	r.Use(middleware.APIKeyAuth(nil, skip))

	hub := ws.NewHub(nil)
	t.Cleanup(hub.Close)

	// Real CallbackService and PushRouter with nil push providers —
	// both are safe no-ops for the paths exercised by these tests
	// (no callback_url in the request payload, push fan-out is a
	// detached goroutine that silently does nothing with nil providers).
	callbackSvc := service.NewCallbackService()
	pushRouter := service.NewPushRouter(nil, nil)

	h := NewNotificationHandler(store, hub, callbackSvc, pushRouter)
	r.POST("/api/notifications", h.Create)
	return r
}

// TestCreateNotification_Requires401WithoutAPIKey verifies the
// APIKeyAuth middleware rejects unauthenticated POSTs to the notifications
// endpoint with 401. This is the last line of defense against a
// misconfigured reverse proxy exposing the API — if the middleware ever
// stops gating /api/notifications, every Dingit server becomes an open
// relay. Catches accidental skipPaths entries in main.go too.
func TestCreateNotification_Requires401WithoutAPIKey(t *testing.T) {
	store := &mockNotificationStore{
		addFn: func(context.Context, *model.Notification) (*model.Notification, error) {
			t.Errorf("store.Add should never be called when auth fails")
			return nil, nil
		},
	}
	r := newTestRouter(t, store, false) // auth ENABLED

	body := bytes.NewBufferString(`{"title":"x","body":"y"}`)
	req := httptest.NewRequest(http.MethodPost, "/api/notifications", body)
	req.Header.Set("Content-Type", "application/json")

	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 without API key, got %d (body=%s)", w.Code, w.Body.String())
	}
}

// TestCreateNotification_DefaultsPriorityToNormal captures the handler's
// priority-default logic at notification.go:62-64. Omitting "priority"
// from the request body must result in the stored notification carrying
// Priority == PriorityNormal. This is user-visible: priority governs
// push routing, badge colors, and the App's sort order, so a silent
// regression here is a visible bug downstream.
func TestCreateNotification_DefaultsPriorityToNormal(t *testing.T) {
	var captured *model.Notification
	store := &mockNotificationStore{
		addFn: func(_ context.Context, n *model.Notification) (*model.Notification, error) {
			captured = n
			n.ID = "ntf_captured"
			n.Status = model.StatusPending
			return n, nil
		},
	}
	r := newTestRouter(t, store, true) // auth DISABLED

	body := bytes.NewBufferString(`{"title":"no priority","body":"body"}`)
	req := httptest.NewRequest(http.MethodPost, "/api/notifications", body)
	req.Header.Set("Content-Type", "application/json")

	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d (body=%s)", w.Code, w.Body.String())
	}
	if captured == nil {
		t.Fatalf("store.Add was not called")
	}
	if captured.Priority != model.PriorityNormal {
		t.Errorf("default priority: want %q, got %q", model.PriorityNormal, captured.Priority)
	}
}

// TestCreateNotification_MetadataRoundTrip verifies the nested-JSON
// metadata field survives untouched across the handler boundary. The
// regression risk here is the difference between json.RawMessage,
// map[string]any, and strict struct typing: if someone changes the
// createRequest.Metadata type, nested objects (maps inside maps) can
// silently lose their shape. This test uses a nested structure to
// catch that.
func TestCreateNotification_MetadataRoundTrip(t *testing.T) {
	var captured *model.Notification
	store := &mockNotificationStore{
		addFn: func(_ context.Context, n *model.Notification) (*model.Notification, error) {
			captured = n
			n.ID = "ntf_captured"
			n.Status = model.StatusPending
			return n, nil
		},
	}
	r := newTestRouter(t, store, true)

	payload := map[string]any{
		"title": "t",
		"body":  "b",
		"metadata": map[string]any{
			"foo":    "bar",
			"count":  42.0, // JSON numbers decode as float64 into map[string]any
			"nested": map[string]any{"a": "b", "c": "d"},
			"tags":   []any{"x", "y", "z"},
		},
	}
	raw, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("marshal payload: %v", err)
	}

	req := httptest.NewRequest(http.MethodPost, "/api/notifications", bytes.NewReader(raw))
	req.Header.Set("Content-Type", "application/json")

	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d (body=%s)", w.Code, w.Body.String())
	}
	if captured == nil {
		t.Fatalf("store.Add was not called")
	}
	want := payload["metadata"].(map[string]any)
	got := captured.Metadata
	// Round-trip comparison via JSON to avoid the map-equality-by-pointer
	// gotcha and to match the semantic "same data" the user cares about.
	wantJSON, _ := json.Marshal(want)
	gotJSON, _ := json.Marshal(got)
	if string(wantJSON) != string(gotJSON) {
		t.Errorf("metadata round-trip mismatch\n  want: %s\n  got:  %s", wantJSON, gotJSON)
	}
}
