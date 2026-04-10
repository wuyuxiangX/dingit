package service

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"net"
	"net/http"
	"net/url"
	"strings"
	"time"

	"go.uber.org/zap"

	"github.com/dingit-me/server/internal/metrics"
	"github.com/dingit-me/server/internal/model"
	"github.com/dingit-me/server/internal/pkg/logger"
)

// statusClassOf buckets an HTTP status code into the coarse label used by
// dingit_callback_delivery_total{status_class=...}. Keeps label cardinality
// at O(1) regardless of how many distinct statuses upstream servers return.
func statusClassOf(code int) string {
	switch {
	case code >= 200 && code < 300:
		return "2xx"
	case code >= 400 && code < 500:
		return "4xx"
	case code >= 500 && code < 600:
		return "5xx"
	default:
		return "other"
	}
}

// ErrInvalidCallbackURL is returned by ValidateCallbackURL when the URL
// fails any of the SSRF guard rails.
var ErrInvalidCallbackURL = errors.New("invalid callback url")

// ValidateCallbackURL enforces the SSRF guard rails for user-supplied
// callback URLs:
//   - scheme must be https (http would let attackers sniff webhook payloads
//     and bypass any TLS middleboxes)
//   - host must resolve to a public IP (reject loopback, private, link-local,
//     cloud metadata, unspecified, multicast)
//   - no credentials in the URL
//
// This is called both at ingress (POST /api/notifications) and again on
// every redirect hop, so a 302 to 169.254.169.254 is caught before the
// request leaves the box.
func ValidateCallbackURL(raw string) error {
	u, err := url.Parse(raw)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrInvalidCallbackURL, err)
	}
	if u.Scheme != "https" {
		return fmt.Errorf("%w: scheme must be https, got %q", ErrInvalidCallbackURL, u.Scheme)
	}
	if u.User != nil {
		return fmt.Errorf("%w: embedded credentials not allowed", ErrInvalidCallbackURL)
	}
	host := u.Hostname()
	if host == "" {
		return fmt.Errorf("%w: empty host", ErrInvalidCallbackURL)
	}
	// Resolve the hostname and reject if any returned address is private.
	// DNS rebinding: a name could flip between public and private between
	// validation and the actual request. We mitigate partially by checking
	// every redirect hop again, but a belt-and-braces fix would require
	// pinning the resolved IP and dialing it directly. Out of scope for
	// this change.
	ips, err := net.LookupIP(host)
	if err != nil {
		return fmt.Errorf("%w: dns lookup failed: %v", ErrInvalidCallbackURL, err)
	}
	for _, ip := range ips {
		if isBlockedIP(ip) {
			return fmt.Errorf("%w: host %q resolves to non-public address %s", ErrInvalidCallbackURL, host, ip)
		}
	}
	return nil
}

// isBlockedIP returns true for any address that must not be used as a
// callback destination. Covers RFC1918, loopback, link-local (including
// AWS/GCP metadata 169.254.169.254), unspecified, and multicast ranges.
func isBlockedIP(ip net.IP) bool {
	if ip == nil {
		return true
	}
	if ip.IsLoopback() || ip.IsUnspecified() || ip.IsLinkLocalUnicast() ||
		ip.IsLinkLocalMulticast() || ip.IsMulticast() || ip.IsPrivate() {
		return true
	}
	// Extra belt: IPv6 unique local (fc00::/7) and IPv4 cloud metadata paths
	// IsPrivate already covers fc00::/7 and 10/172.16/192.168, and
	// IsLinkLocalUnicast covers 169.254.0.0/16 including 169.254.169.254.
	return false
}

// callbackConcurrency bounds the number of outbound webhook deliveries
// that can be in flight at once. Each delivery can live for up to
// ~70 seconds (3 retries * 10s client timeout + 9s+27s backoff), so
// unbounded fan-out was a straightforward way to turn one burst of
// actions into a long-lived goroutine pile.
const callbackConcurrency = 32

type CallbackService struct {
	client *http.Client
	sem    chan struct{}
}

func NewCallbackService() *CallbackService {
	client := &http.Client{
		Timeout: 10 * time.Second,
		// Validate every redirect hop so a public host can't 302-forward
		// us to the metadata endpoint. Cap at 5 hops — webhooks that need
		// more redirection than that are almost certainly misconfigured.
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) >= 5 {
				return errors.New("stopped after 5 redirects")
			}
			return ValidateCallbackURL(req.URL.String())
		},
		Transport: &http.Transport{
			MaxConnsPerHost:     50,
			MaxIdleConnsPerHost: 10,
			IdleConnTimeout:     90 * time.Second,
		},
	}
	return &CallbackService{
		client: client,
		sem:    make(chan struct{}, callbackConcurrency),
	}
}

// trim is a defensive helper so callers that pass URLs from user input
// don't have to think about whitespace.
func trim(s string) string { return strings.TrimSpace(s) }

// Validate is exposed so handlers can reject a bad URL at ingress instead
// of only at delivery time.
func (s *CallbackService) Validate(raw string) error { return ValidateCallbackURL(trim(raw)) }

func (s *CallbackService) Deliver(notification *model.Notification, response *model.ActionResponse) {
	if notification.CallbackURL == nil || *notification.CallbackURL == "" {
		return
	}
	// Re-validate at delivery time as a safety net. The URL already passed
	// validation at ingress, but DNS may have flipped between then and now,
	// and historical rows predating this validation layer can still be in
	// the DB. Failing closed here prevents a retroactive SSRF.
	if err := ValidateCallbackURL(*notification.CallbackURL); err != nil {
		logger.Warn("Callback rejected: unsafe URL",
			zap.String("url", *notification.CallbackURL),
			zap.Error(err),
		)
		metrics.CallbackDeliveryTotal.WithLabelValues("rejected", "none").Inc()
		return
	}

	// Bound concurrency: acquire the semaphore before spawning. A burst
	// of actions will block in the select rather than allocate a pile
	// of sleeping goroutines. If we can't acquire within 2 seconds we
	// drop the delivery and log — better than unbounded queueing.
	select {
	case s.sem <- struct{}{}:
	case <-time.After(2 * time.Second):
		logger.Warn("Callback dropped: delivery queue saturated",
			zap.String("url", *notification.CallbackURL),
		)
		metrics.CallbackDeliveryTotal.WithLabelValues("dropped", "none").Inc()
		return
	}
	go func() {
		defer func() { <-s.sem }()
		s.deliverWithRetry(*notification.CallbackURL, notification, response)
	}()
}

func (s *CallbackService) deliverWithRetry(url string, notification *model.Notification, response *model.ActionResponse) {
	payload := map[string]any{
		"notification_id": notification.ID,
		"action":          response.Action,
		"timestamp":       response.Timestamp.Format(time.RFC3339Nano),
		"metadata":        notification.Metadata,
		"source":          response.Source,
	}

	body, err := json.Marshal(payload)
	if err != nil {
		logger.Error("Callback marshal error", zap.Error(err))
		metrics.CallbackDeliveryTotal.WithLabelValues("failure", "none").Inc()
		return
	}

	// lastStatusClass tracks the outcome of the most recent attempt so
	// that when all retries are exhausted we can report a meaningful
	// status_class label rather than "none". Starts as "network_error"
	// to cover the case where every attempt failed at the TCP layer.
	lastStatusClass := "network_error"

	const maxRetries = 3
	for attempt := 0; attempt < maxRetries; attempt++ {
		resp, err := s.client.Post(url, "application/json", bytes.NewReader(body))
		if err == nil {
			resp.Body.Close()
			if resp.StatusCode >= 200 && resp.StatusCode < 300 {
				logger.Info("Callback delivered", zap.String("url", url), zap.Int("status", resp.StatusCode))
				metrics.CallbackDeliveryTotal.WithLabelValues("success", "2xx").Inc()
				return
			}
			lastStatusClass = statusClassOf(resp.StatusCode)
			logger.Warn("Callback failed", zap.String("url", url), zap.Int("attempt", attempt+1), zap.Int("status", resp.StatusCode))
		} else {
			lastStatusClass = "network_error"
			logger.Warn("Callback error", zap.String("url", url), zap.Int("attempt", attempt+1), zap.Error(err))
		}

		if attempt < maxRetries-1 {
			delay := time.Duration(math.Pow(3, float64(attempt+1))) * time.Second
			time.Sleep(delay)
		}
	}

	logger.Error("Callback retries exhausted", zap.String("url", url))
	metrics.CallbackDeliveryTotal.WithLabelValues("failure", lastStatusClass).Inc()
}
