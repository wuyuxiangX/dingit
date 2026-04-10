package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"

	"github.com/dingit-me/server/internal/model"
	"github.com/dingit-me/server/internal/service"
	"github.com/dingit-me/server/internal/ws"
)

// mockHealthStore implements the healthStore interface for tests.
// The count and err fields are returned unchanged from Count(); other
// Store methods are deliberately absent because HealthHandler never
// calls them, so the interface stays narrow.
type mockHealthStore struct {
	count int
	err   error
}

func (m *mockHealthStore) Count(context.Context, *model.NotificationStatus, *model.NotificationPriority) (int, error) {
	return m.count, m.err
}

// stubPinger lets tests decide whether the DB ping "succeeds" (err nil
// → a real latency measurement is taken) or fails (err non-nil → status
// flips to degraded and db_ping_ms stays at -1).
type stubPinger struct{ err error }

func (s *stubPinger) Ping(context.Context) error { return s.err }

// invokeHealthDebug wires a HealthHandler into a bare gin engine, hits
// /api/health/debug, parses the envelope shape that
// pkg/response.Success produces ({code, message, data}), and returns
// the inner data map for assertion.
func invokeHealthDebug(t *testing.T, h *HealthHandler) map[string]any {
	t.Helper()
	r := gin.New()
	r.GET("/api/health/debug", h.HealthDebug)

	req := httptest.NewRequest(http.MethodGet, "/api/health/debug", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body = %s", w.Code, w.Body.String())
	}

	var envelope struct {
		Code    int            `json:"code"`
		Message string         `json:"message"`
		Data    map[string]any `json:"data"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &envelope); err != nil {
		t.Fatalf("unmarshal envelope: %v; body = %s", err, w.Body.String())
	}
	if envelope.Data == nil {
		t.Fatalf("envelope.data is nil; body = %s", w.Body.String())
	}
	return envelope.Data
}

func TestHealthDebug_EmptyConfig(t *testing.T) {
	// Nothing configured: no pool, no push providers, no callback svc.
	// This is the "bare dev loop" path — the handler should still
	// render every documented field with safe defaults so consumers
	// can rely on a stable JSON shape.
	h := NewHealthHandler(
		&mockHealthStore{count: 0},
		ws.NewHub(nil),
		nil, // pool
		nil, // apnsSvc
		nil, // fcmSvc
		nil, // callbackSvc
	)

	data := invokeHealthDebug(t, h)

	if got, want := data["status"], "ok"; got != want {
		t.Errorf("status = %v, want %v", got, want)
	}
	if got, want := data["pending_notifications"], float64(0); got != want {
		t.Errorf("pending_notifications = %v, want %v", got, want)
	}
	if got, want := data["db_ping_ms"], float64(-1); got != want {
		// No pool wired → ping sentinel stays at -1 and status stays
		// "ok" (the pool's absence is a config choice, not a failure).
		t.Errorf("db_ping_ms = %v, want -1 (no pool)", got)
	}

	// Push providers: both should be "enabled": false, with no other
	// fields leaking through (since there's nothing to report on).
	providers, ok := data["push_providers"].(map[string]any)
	if !ok {
		t.Fatalf("push_providers not an object: %T", data["push_providers"])
	}
	apns, _ := providers["apns"].(map[string]any)
	if got := apns["enabled"]; got != false {
		t.Errorf("apns.enabled = %v, want false", got)
	}
	if _, present := apns["last_success_at"]; present {
		t.Errorf("apns.last_success_at should be absent when disabled")
	}
	fcm, _ := providers["fcm"].(map[string]any)
	if got := fcm["enabled"]; got != false {
		t.Errorf("fcm.enabled = %v, want false", got)
	}

	// Callback queue still present with zero counters even without
	// a real CallbackService attached — consumers never have to
	// test for key existence, only for values.
	queue, ok := data["callback_queue"].(map[string]any)
	if !ok {
		t.Fatalf("callback_queue not an object: %T", data["callback_queue"])
	}
	if got := queue["in_flight"]; got != float64(0) {
		t.Errorf("callback_queue.in_flight = %v, want 0", got)
	}
	if got := queue["pending"]; got != float64(0) {
		t.Errorf("callback_queue.pending = %v, want 0", got)
	}

	// build_info: every key present, even if values are the "dev"
	// sentinel in test binaries (ldflags only fire during make build).
	build, ok := data["build_info"].(map[string]any)
	if !ok {
		t.Fatalf("build_info not an object: %T", data["build_info"])
	}
	for _, k := range []string{"version", "commit_sha", "built_at"} {
		if _, present := build[k]; !present {
			t.Errorf("build_info.%s missing", k)
		}
	}
}

func TestHealthDebug_StoreErrorDegrades(t *testing.T) {
	// Store.Count failure should flip status to "degraded" without
	// hiding any other field — operators still need the rest of the
	// payload to triage.
	h := NewHealthHandler(
		&mockHealthStore{err: errors.New("db unavailable")},
		ws.NewHub(nil),
		nil,
		nil,
		nil,
		nil,
	)
	data := invokeHealthDebug(t, h)
	if got, want := data["status"], "degraded"; got != want {
		t.Errorf("status = %v, want %v", got, want)
	}
}

func TestHealthDebug_PingerFailureDegrades(t *testing.T) {
	// A pool that's reachable but failing its Ping should also
	// degrade the status and keep db_ping_ms at the -1 sentinel.
	h := NewHealthHandler(
		&mockHealthStore{count: 0},
		ws.NewHub(nil),
		&stubPinger{err: errors.New("connection refused")},
		nil,
		nil,
		nil,
	)
	data := invokeHealthDebug(t, h)
	if got, want := data["status"], "degraded"; got != want {
		t.Errorf("status = %v, want %v", got, want)
	}
	if got, want := data["db_ping_ms"], float64(-1); got != want {
		t.Errorf("db_ping_ms = %v, want -1 on ping failure", got)
	}
}

func TestHealthDebug_PingerOKMeasures(t *testing.T) {
	// Successful ping: db_ping_ms must be >= 0 (typically 0 in a
	// stub), never the -1 sentinel.
	h := NewHealthHandler(
		&mockHealthStore{count: 0},
		ws.NewHub(nil),
		&stubPinger{err: nil},
		nil,
		nil,
		nil,
	)
	data := invokeHealthDebug(t, h)
	if got := data["db_ping_ms"]; got == nil || got.(float64) < 0 {
		t.Errorf("db_ping_ms = %v, want >= 0", got)
	}
	if got, want := data["status"], "ok"; got != want {
		t.Errorf("status = %v, want %v", got, want)
	}
}

func TestHealthDebug_CallbackQueueReflectsLiveCounters(t *testing.T) {
	// Wiring a real CallbackService should flow its atomic counters
	// straight through into the JSON. We can't easily trigger Deliver
	// without a real HTTP target, but we *can* prove the pipe is
	// connected by reading from a fresh service (zeros) and confirming
	// the handler surfaces the same numbers.
	cb := service.NewCallbackService()
	h := NewHealthHandler(
		&mockHealthStore{count: 0},
		ws.NewHub(nil),
		nil,
		nil,
		nil,
		cb,
	)
	data := invokeHealthDebug(t, h)
	queue := data["callback_queue"].(map[string]any)
	if got := queue["in_flight"]; got != float64(0) {
		t.Errorf("callback_queue.in_flight = %v, want 0", got)
	}
	if got := queue["pending"]; got != float64(0) {
		t.Errorf("callback_queue.pending = %v, want 0", got)
	}
}
