package service

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
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
func (s *FcmService) SendToAll(ctx context.Context, n *model.Notification) {
	tokens, err := s.deviceSvc.ListByPlatform(ctx, "android")
	if err != nil {
		logger.Error("Failed to list Android device tokens", zap.Error(err))
		return
	}

	if len(tokens) == 0 {
		return
	}

	for _, token := range tokens {
		token := token
		go func() {
			select {
			case s.sem <- struct{}{}:
			case <-ctx.Done():
				return
			}
			defer func() { <-s.sem }()
			s.sendToDevice(ctx, token, n)
		}()
	}
}

func (s *FcmService) sendToDevice(ctx context.Context, deviceToken string, n *model.Notification) {
	accessToken, err := s.getAccessToken(ctx)
	if err != nil {
		logger.Error("Failed to get FCM access token", zap.Error(err))
		metrics.PushDeliveryTotal.WithLabelValues(fcmProvider, "error").Inc()
		return
	}

	msg := map[string]any{
		"message": map[string]any{
			"token": deviceToken,
			"notification": map[string]string{
				"title": n.Title,
				"body":  n.Body,
			},
			"data": map[string]string{
				"notification_id": n.ID,
				"source":          n.Source,
				"priority":        string(n.Priority),
			},
		},
	}

	body, _ := json.Marshal(msg)
	url := fmt.Sprintf("https://fcm.googleapis.com/v1/projects/%s/messages:send", s.projectID)

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(body))
	if err != nil {
		logger.Error("Failed to create FCM request", zap.Error(err))
		metrics.PushDeliveryTotal.WithLabelValues(fcmProvider, "error").Inc()
		return
	}

	req.Header.Set("Authorization", "Bearer "+accessToken)
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.client.Do(req)
	if err != nil {
		logger.Error("FCM request failed", zap.Error(err))
		metrics.PushDeliveryTotal.WithLabelValues(fcmProvider, "error").Inc()
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode == 404 || resp.StatusCode == 410 {
		logger.Info("Removing invalid FCM device token")
		_ = s.deviceSvc.RemoveByToken(ctx, deviceToken)
		metrics.PushDeliveryTotal.WithLabelValues(fcmProvider, "invalid_token").Inc()
		return
	}

	if resp.StatusCode != 200 {
		respBody, _ := io.ReadAll(resp.Body)
		logger.Error("FCM error", zap.Int("status", resp.StatusCode), zap.String("body", string(respBody)))
		metrics.PushDeliveryTotal.WithLabelValues(fcmProvider, "error").Inc()
		return
	}

	metrics.PushDeliveryTotal.WithLabelValues(fcmProvider, "success").Inc()
}
