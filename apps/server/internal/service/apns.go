package service

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"io"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"go.uber.org/zap"

	"github.com/dingit-me/server/internal/metrics"
	"github.com/dingit-me/server/internal/model"
	"github.com/dingit-me/server/internal/pkg/logger"
)

// apnsProvider is the label value used for every dingit_push_delivery_total
// increment from this file. Keeping it as a constant (vs a string literal
// at each call site) makes it greppable and impossible to typo.
const apnsProvider = "apns"

type ApnsConfig struct {
	KeyFile string // path to .p8 file
	KeyID   string // e.g. BJKWPYLDG8
	TeamID  string // e.g. 2TT58G759N
	BundleID string // e.g. com.notifyhub.notifyApp
	Sandbox bool   // true for development
}

// apnsConcurrency bounds how many sendToDevice goroutines may be
// in-flight at once. Previously we spawned one goroutine per device
// with no ceiling — 10k registered devices = 10k concurrent HTTPS calls
// + 10k goroutines worth of stack. This semaphore caps it at a number
// that saturates the APNs HTTP/2 connection without torching the box.
const apnsConcurrency = 64

type ApnsService struct {
	cfg       ApnsConfig
	key       *ecdsa.PrivateKey
	deviceSvc *DeviceService
	client    *http.Client
	sem       chan struct{}

	mu       sync.Mutex
	jwtToken string
	jwtExp   time.Time

	// stats records the outcome of the most recent APNs delivery
	// attempt so /api/health/debug can report "is APNs actually working
	// right now" without having to query Prometheus. See WYX-407.
	stats pushHealthTracker
}

// Stats returns a snapshot of the most recent APNs delivery outcome.
// Safe to call concurrently with active deliveries.
func (s *ApnsService) Stats() PushProviderStats {
	return s.stats.snapshot()
}

func NewApnsService(cfg ApnsConfig, deviceSvc *DeviceService) (*ApnsService, error) {
	keyData, err := os.ReadFile(cfg.KeyFile)
	if err != nil {
		return nil, fmt.Errorf("read APNs key: %w", err)
	}

	block, _ := pem.Decode(keyData)
	if block == nil {
		return nil, fmt.Errorf("invalid PEM block in APNs key")
	}

	parsedKey, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("parse APNs key: %w", err)
	}

	ecKey, ok := parsedKey.(*ecdsa.PrivateKey)
	if !ok {
		return nil, fmt.Errorf("APNs key is not ECDSA")
	}

	return &ApnsService{
		cfg:       cfg,
		key:       ecKey,
		deviceSvc: deviceSvc,
		client: &http.Client{
			Timeout: 10 * time.Second,
			// Cap per-host TCP connections so an APNs HTTP/2 fan-out can
			// reuse streams instead of opening a new TLS handshake per
			// device. 100 is plenty — APNs HTTP/2 multiplexes up to
			// thousands of streams per connection.
			Transport: &http.Transport{
				MaxConnsPerHost:     100,
				MaxIdleConnsPerHost: 20,
				IdleConnTimeout:     90 * time.Second,
			},
		},
		sem: make(chan struct{}, apnsConcurrency),
	}, nil
}

func (s *ApnsService) getJWT() (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	// APNs JWT is valid for up to 1 hour, refresh at 50 min
	if s.jwtToken != "" && time.Now().Before(s.jwtExp) {
		return s.jwtToken, nil
	}

	now := time.Now()
	claims := jwt.MapClaims{
		"iss": s.cfg.TeamID,
		"iat": now.Unix(),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodES256, claims)
	token.Header["kid"] = s.cfg.KeyID

	signed, err := token.SignedString(s.key)
	if err != nil {
		return "", fmt.Errorf("sign JWT: %w", err)
	}

	s.jwtToken = signed
	s.jwtExp = now.Add(50 * time.Minute)
	return signed, nil
}

func (s *ApnsService) baseURL() string {
	if s.cfg.Sandbox {
		return "https://api.sandbox.push.apple.com"
	}
	return "https://api.push.apple.com"
}

// SendToAll sends push notification to all iOS devices via APNs. Each
// device dispatch acquires the semaphore before doing any work, so the
// total number of in-flight goroutines is bounded by apnsConcurrency.
func (s *ApnsService) SendToAll(ctx context.Context, n *model.Notification, badgeCount int) {
	devices, err := s.deviceSvc.ListByPlatform(ctx, "ios")
	if err != nil {
		logger.Error("Failed to list iOS device tokens", zap.Error(err))
		return
	}

	if len(devices) == 0 {
		return
	}

	logger.Info("Sending APNs push", zap.Int("devices", len(devices)), zap.String("title", n.Title))

	for _, token := range devices {
		token := token
		go func() {
			select {
			case s.sem <- struct{}{}:
			case <-ctx.Done():
				return
			}
			defer func() { <-s.sem }()
			s.sendToDevice(ctx, token, n, badgeCount)
		}()
	}
}

func (s *ApnsService) sendToDevice(ctx context.Context, deviceToken string, n *model.Notification, badgeCount int) {
	jwtToken, err := s.getJWT()
	if err != nil {
		logger.Error("Failed to get APNs JWT", zap.Error(err))
		metrics.PushDeliveryTotal.WithLabelValues(apnsProvider, "error").Inc()
		s.stats.recordError("get jwt: " + err.Error())
		return
	}

	payload := map[string]any{
		"aps": map[string]any{
			"alert": map[string]string{
				"title": n.Title,
				"body":  n.Body,
			},
			"sound": "default",
			"badge": badgeCount,
		},
		"notification_id": n.ID,
		"source":          n.Source,
		"priority":        string(n.Priority),
	}

	body, _ := json.Marshal(payload)
	url := fmt.Sprintf("%s/3/device/%s", s.baseURL(), deviceToken)

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(body))
	if err != nil {
		logger.Error("Failed to create APNs request", zap.Error(err))
		metrics.PushDeliveryTotal.WithLabelValues(apnsProvider, "error").Inc()
		s.stats.recordError("build request: " + err.Error())
		return
	}

	req.Header.Set("Authorization", "bearer "+jwtToken)
	req.Header.Set("apns-topic", s.cfg.BundleID)
	req.Header.Set("apns-push-type", "alert")
	req.Header.Set("apns-priority", "10")

	resp, err := s.client.Do(req)
	if err != nil {
		logger.Error("APNs request failed", zap.Error(err))
		metrics.PushDeliveryTotal.WithLabelValues(apnsProvider, "error").Inc()
		s.stats.recordError("transport: " + err.Error())
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode == 200 {
		logger.Info("APNs push sent", zap.String("device", truncateToken(deviceToken)))
		metrics.PushDeliveryTotal.WithLabelValues(apnsProvider, "success").Inc()
		s.stats.recordSuccess()
		return
	}

	respBody, _ := io.ReadAll(resp.Body)

	if resp.StatusCode == 410 {
		// Token is no longer valid — remove device. A stale client
		// doesn't say anything about APNs health, so leave the stats
		// tracker alone (Prometheus still records it via the
		// "invalid_token" label).
		logger.Info("Removing expired APNs token", zap.String("device", truncateToken(deviceToken)))
		_ = s.deviceSvc.RemoveByToken(ctx, deviceToken)
		metrics.PushDeliveryTotal.WithLabelValues(apnsProvider, "invalid_token").Inc()
		return
	}

	logger.Error("APNs error",
		zap.Int("status", resp.StatusCode),
		zap.String("body", string(respBody)),
	)
	metrics.PushDeliveryTotal.WithLabelValues(apnsProvider, "error").Inc()
	s.stats.recordError(fmt.Sprintf("http %d: %s", resp.StatusCode, truncateErrBody(respBody)))
}

// SendSilentBadgeUpdate sends a background (silent) APNs push to refresh badge
// on all iOS devices without showing any alert. Used when pending count changes
// due to dismiss/action on any device.
func (s *ApnsService) SendSilentBadgeUpdate(ctx context.Context, badgeCount int) {
	devices, err := s.deviceSvc.ListByPlatform(ctx, "ios")
	if err != nil {
		logger.Error("Failed to list iOS tokens for badge update", zap.Error(err))
		return
	}
	if len(devices) == 0 {
		return
	}

	logger.Info("Sending silent badge update", zap.Int("devices", len(devices)), zap.Int("badge", badgeCount))

	for _, token := range devices {
		token := token
		go func() {
			select {
			case s.sem <- struct{}{}:
			case <-ctx.Done():
				return
			}
			defer func() { <-s.sem }()
			s.sendSilentBadge(ctx, token, badgeCount)
		}()
	}
}

func (s *ApnsService) sendSilentBadge(ctx context.Context, deviceToken string, badgeCount int) {
	jwtToken, err := s.getJWT()
	if err != nil {
		logger.Error("Failed to get APNs JWT for badge", zap.Error(err))
		return
	}

	// Silent push: content-available=1, no alert, only badge
	payload := map[string]any{
		"aps": map[string]any{
			"content-available": 1,
			"badge":             badgeCount,
		},
	}

	body, _ := json.Marshal(payload)
	url := fmt.Sprintf("%s/3/device/%s", s.baseURL(), deviceToken)

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(body))
	if err != nil {
		logger.Error("Failed to create APNs badge request", zap.Error(err))
		return
	}

	req.Header.Set("Authorization", "bearer "+jwtToken)
	req.Header.Set("apns-topic", s.cfg.BundleID)
	req.Header.Set("apns-push-type", "background") // silent push 必须用 background
	req.Header.Set("apns-priority", "5")             // background push 必须用 5 或更低

	resp, err := s.client.Do(req)
	if err != nil {
		logger.Error("APNs badge request failed", zap.Error(err))
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode == 200 {
		return
	}

	if resp.StatusCode == 410 {
		logger.Info("Removing expired APNs token (badge push)", zap.String("device", truncateToken(deviceToken)))
		_ = s.deviceSvc.RemoveByToken(ctx, deviceToken)
		return
	}

	respBody, _ := io.ReadAll(resp.Body)
	logger.Error("APNs badge error",
		zap.Int("status", resp.StatusCode),
		zap.String("body", string(respBody)),
	)
}

func truncateToken(s string) string {
	if len(s) <= 20 {
		return s
	}
	return s[:20] + "..."
}
