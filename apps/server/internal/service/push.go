package service

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"

	"go.uber.org/zap"
	"golang.org/x/oauth2/google"

	"github.com/dingit-me/server/internal/metrics"
	"github.com/dingit-me/server/internal/model"
	"github.com/dingit-me/server/internal/pkg/logger"
)

// fcmProvider is the label value used for every dingit_push_delivery_total
// increment from this file. Mirrors apnsProvider in apns.go.
const fcmProvider = "fcm"

// PushRouter dispatches push notifications to the appropriate service based on platform.
// iOS → APNs (direct, works in China)
// Android → FCM (requires Google services)
type PushRouter struct {
	apns *ApnsService // may be nil
	fcm  *FcmService  // may be nil
}

func NewPushRouter(apns *ApnsService, fcm *FcmService) *PushRouter {
	return &PushRouter{apns: apns, fcm: fcm}
}

// SendToAll sends push to all registered devices via appropriate channels.
func (r *PushRouter) SendToAll(ctx context.Context, n *model.Notification, badgeCount int) {
	if r.apns != nil {
		go r.apns.SendToAll(ctx, n, badgeCount)
	}
	if r.fcm != nil {
		go r.fcm.SendToAll(ctx, n)
	}
}

// UpdateBadge pushes a silent badge update to all iOS devices when pending
// count changes (e.g. after dismiss/action on any device). Android FCM data-only
// badge updates require vendor-specific handling and are not supported here yet.
func (r *PushRouter) UpdateBadge(ctx context.Context, badgeCount int) {
	if r.apns != nil {
		go r.apns.SendSilentBadgeUpdate(ctx, badgeCount)
	}
}

// --- FCM Service (for Android, requires Google services / VPN in China) ---

// PushProviderStats is a point-in-time snapshot of a push provider's
// delivery health, surfaced via /api/health/debug (WYX-407). Zero values
// mean "no activity yet", which the handler renders distinctively from
// "most recent attempt failed".
type PushProviderStats struct {
	LastSuccessAt time.Time
	LastErrorAt   time.Time
	LastError     string
}

// pushHealthTracker records the outcome of the most recent push
// delivery attempt from a single provider. Safe for concurrent use from
// the fan-out sender goroutines; /api/health/debug reads it through
// snapshot(). Kept dirt-simple on purpose — this is a health signal,
// not a metric, so losing an update under heavy write contention is
// fine (the Prometheus counters in the metrics package are the source
// of truth for rates and totals).
type pushHealthTracker struct {
	mu            sync.RWMutex
	lastSuccessAt time.Time
	lastErrorAt   time.Time
	lastError     string
}

func (t *pushHealthTracker) recordSuccess() {
	now := time.Now()
	t.mu.Lock()
	t.lastSuccessAt = now
	t.mu.Unlock()
}

func (t *pushHealthTracker) recordError(msg string) {
	now := time.Now()
	t.mu.Lock()
	t.lastErrorAt = now
	t.lastError = msg
	t.mu.Unlock()
}

func (t *pushHealthTracker) snapshot() PushProviderStats {
	t.mu.RLock()
	defer t.mu.RUnlock()
	return PushProviderStats{
		LastSuccessAt: t.lastSuccessAt,
		LastErrorAt:   t.lastErrorAt,
		LastError:     t.lastError,
	}
}

// fcmConcurrency bounds how many sendToDevice goroutines may be
// in-flight at once. Same reasoning as apnsConcurrency.
const fcmConcurrency = 64

type FcmService struct {
	projectID string
	deviceSvc *DeviceService
	client    *http.Client
	sem       chan struct{}
	mu        sync.Mutex
	token     string
	tokenExp  time.Time
	creds     *google.Credentials

	// stats records the outcome of the most recent FCM delivery attempt
	// so /api/health/debug can report "is FCM actually working right
	// now" without having to query Prometheus. See WYX-407.
	stats pushHealthTracker
}

func NewFcmService(projectID string, deviceSvc *DeviceService) (*FcmService, error) {
	// Bound the credential discovery so a slow/unreachable metadata
	// server can't block the server's boot path indefinitely. 10s is
	// the same budget as the HTTP client — long enough for a cold
	// start, short enough that operators notice during a rollback.
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	creds, err := google.FindDefaultCredentials(ctx, "https://www.googleapis.com/auth/firebase.messaging")
	if err != nil {
		return nil, fmt.Errorf("find credentials: %w", err)
	}

	return &FcmService{
		projectID: projectID,
		deviceSvc: deviceSvc,
		client: &http.Client{
			Timeout: 10 * time.Second,
			Transport: &http.Transport{
				MaxConnsPerHost:     100,
				MaxIdleConnsPerHost: 20,
				IdleConnTimeout:     90 * time.Second,
			},
		},
		creds: creds,
		sem:   make(chan struct{}, fcmConcurrency),
	}, nil
}

func (s *FcmService) getAccessToken(ctx context.Context) (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.token != "" && time.Now().Before(s.tokenExp) {
		return s.token, nil
	}

	tok, err := s.creds.TokenSource.Token()
	if err != nil {
		return "", fmt.Errorf("get token: %w", err)
	}

	s.token = tok.AccessToken
	s.tokenExp = tok.Expiry.Add(-time.Minute)
	return s.token, nil
}

// SendToAll sends push notification to all Android devices via FCM.
// Semaphore-bounded the same way APNs is — see apns.go for rationale.
// Detaches the caller's cancel so a disconnecting HTTP client doesn't
// kill in-flight pushes mid-delivery (matches APNs path).
func (s *FcmService) SendToAll(ctx context.Context, n *model.Notification) {
	ctx = context.WithoutCancel(ctx)
	devices, err := s.deviceSvc.ListByPlatformFull(ctx, "android")
	if err != nil {
		logger.Error("Failed to list Android device tokens", zap.Error(err))
		return
	}

	if len(devices) == 0 {
		return
	}

	// Capture wall clock once so the DND check gives a consistent
	// answer across the whole fan-out — crossing the DND boundary
	// mid-send otherwise lets device A ring while device B goes
	// silent for the same notification event.
	now := time.Now()
	for _, dev := range devices {
		dev := dev
		go func() {
			s.sem <- struct{}{}
			defer func() { <-s.sem }()
			s.sendToDevice(ctx, dev, n, now)
		}()
	}
}

// Stats returns a snapshot of the most recent FCM delivery outcome.
// Safe to call concurrently with active deliveries.
func (s *FcmService) Stats() PushProviderStats {
	return s.stats.snapshot()
}

func (s *FcmService) sendToDevice(ctx context.Context, dev Device, n *model.Notification, now time.Time) {
	accessToken, err := s.getAccessToken(ctx)
	if err != nil {
		logger.Error("Failed to get FCM access token", zap.Error(err))
		metrics.PushDeliveryTotal.WithLabelValues(fcmProvider, "error").Inc()
		s.stats.recordError("get access token: " + err.Error())
		return
	}

	msg := buildFcmPayload(dev, n, now)
	body, _ := json.Marshal(msg)
	url := fmt.Sprintf("https://fcm.googleapis.com/v1/projects/%s/messages:send", s.projectID)

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(body))
	if err != nil {
		logger.Error("Failed to create FCM request", zap.Error(err))
		metrics.PushDeliveryTotal.WithLabelValues(fcmProvider, "error").Inc()
		s.stats.recordError("build request: " + err.Error())
		return
	}

	req.Header.Set("Authorization", "Bearer "+accessToken)
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.client.Do(req)
	if err != nil {
		logger.Error("FCM request failed", zap.Error(err))
		metrics.PushDeliveryTotal.WithLabelValues(fcmProvider, "error").Inc()
		s.stats.recordError("transport: " + err.Error())
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode == 404 || resp.StatusCode == 410 {
		// Invalid token means the *client* is stale, not that FCM is
		// unhealthy — don't taint the provider-level error signal. The
		// Prometheus counter still records it via the "invalid_token"
		// label for drill-down.
		logger.Info("Removing invalid FCM device token")
		_ = s.deviceSvc.RemoveByToken(ctx, dev.Token)
		metrics.PushDeliveryTotal.WithLabelValues(fcmProvider, "invalid_token").Inc()
		return
	}

	if resp.StatusCode != 200 {
		respBody, _ := io.ReadAll(resp.Body)
		logger.Error("FCM error", zap.Int("status", resp.StatusCode), zap.String("body", string(respBody)))
		metrics.PushDeliveryTotal.WithLabelValues(fcmProvider, "error").Inc()
		s.stats.recordError(fmt.Sprintf("http %d: %s", resp.StatusCode, truncateErrBody(respBody)))
		return
	}

	metrics.PushDeliveryTotal.WithLabelValues(fcmProvider, "success").Inc()
	s.stats.recordSuccess()
}

// buildFcmPayload builds the FCM HTTP v1 message body for one device,
// honoring per-device DND. Non-urgent during DND → data-only (no
// "notification" key, Android won't auto-display). Urgent always ships
// the full notification with android.priority=high to break through.
//
// Pure function so it can be unit-tested without FcmService/GCP creds.
// Field names MUST stay camelCase — FCM v1 rejects snake_case.
func buildFcmPayload(dev Device, n *model.Notification, now time.Time) map[string]any {
	urgent := n.Priority == model.PriorityUrgent
	silent := !urgent && dev.IsInDnd(now)

	data := map[string]string{
		"notification_id": n.ID,
		"source":          n.Source,
		"priority":        string(n.Priority),
	}
	if silent {
		data["title"] = n.Title
		data["body"] = n.Body
	}

	message := map[string]any{
		"token": dev.Token,
		"data":  data,
	}

	if !silent {
		message["notification"] = map[string]string{
			"title": n.Title,
			"body":  n.Body,
		}
		androidPriority := "normal"
		notifPriority := "PRIORITY_DEFAULT"
		if urgent {
			androidPriority = "high"
			notifPriority = "PRIORITY_HIGH"
		}
		message["android"] = map[string]any{
			"priority": androidPriority,
			"notification": map[string]string{
				"notificationPriority": notifPriority,
			},
		}
	}

	return map[string]any{"message": message}
}

// truncateErrBody caps error-body strings stored on the health tracker so
// a chatty upstream can't balloon the /api/health/debug response or pin a
// long string in memory. 200 chars is enough to read an FCM/APNs JSON
// error message without leaking full request traces.
func truncateErrBody(b []byte) string {
	const max = 200
	s := strings.TrimSpace(string(b))
	if len(s) > max {
		return s[:max] + "..."
	}
	return s
}
