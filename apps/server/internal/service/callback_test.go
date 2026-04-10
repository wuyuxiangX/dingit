package service

import (
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	"github.com/dingit-me/server/internal/model"
)

// TestValidateCallbackURL_SSRF is the SSRF hardening regression. Every
// entry in the table exercises a distinct reject branch of the guard.
// If the guard ever loosens (someone adds a "helpful" exception, a new
// blocked IP range gets dropped, https enforcement gets turned off),
// this test catches it before the change lands.
//
// All cases must return a non-nil error wrapping ErrInvalidCallbackURL.
func TestValidateCallbackURL_SSRF(t *testing.T) {
	cases := []struct {
		name string
		url  string
	}{
		{"http-scheme", "http://example.com/webhook"},
		{"no-scheme", "example.com/webhook"},
		{"credentials-in-url", "https://user:pass@example.com/webhook"},
		{"loopback-ipv4", "https://127.0.0.1/webhook"},
		{"loopback-hostname", "https://localhost/webhook"},
		{"private-rfc1918-10", "https://10.0.0.1/webhook"},
		{"private-rfc1918-192168", "https://192.168.1.1/webhook"},
		{"private-rfc1918-172", "https://172.16.0.1/webhook"},
		{"cloud-metadata-169254", "https://169.254.169.254/latest/meta-data/"},
		{"empty-host", "https:///path"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := ValidateCallbackURL(tc.url)
			if err == nil {
				t.Errorf("ValidateCallbackURL(%q): expected rejection, got nil", tc.url)
			}
		})
	}

	// And one positive-control case to prove the validator isn't just
	// rejecting everything. 8.8.8.8 is a well-known public IP that
	// passes the public-IP guard without a DNS lookup.
	if err := ValidateCallbackURL("https://8.8.8.8/webhook"); err != nil {
		t.Errorf("expected public IPv4 URL to be accepted, got error: %v", err)
	}
}

// TestCallbackService_RetryExhaustion verifies the retry-then-give-up
// terminal state: given a callback endpoint that always returns 500,
// deliverWithRetry must (a) hit the endpoint exactly maxRetries (3)
// times and (b) return without error.
//
// We deliberately bypass Deliver and call deliverWithRetry directly
// because Deliver runs ValidateCallbackURL on the URL first, which
// rejects 127.0.0.1 (the httptest server's address). deliverWithRetry
// is package-private so this only works from same-package tests.
//
// The retryBackoff field (added for testability) is overridden here to
// return zero, dropping wall-clock time from ~12s to sub-millisecond.
func TestCallbackService_RetryExhaustion(t *testing.T) {
	var hits atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hits.Add(1)
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer srv.Close()

	svc := NewCallbackService()
	// Zero-duration backoff keeps the test fast. Production schedule
	// (3s + 9s) is preserved in defaultCallbackBackoff — any future
	// change to it is a separate concern from this regression test.
	svc.retryBackoff = func(int) time.Duration { return 0 }

	notif := &model.Notification{
		ID:    "ntf_test",
		Title: "test",
		Body:  "body",
	}
	resp := &model.ActionResponse{
		NotificationID: notif.ID,
		Action:         "approve",
		Timestamp:      time.Now(),
	}

	svc.deliverWithRetry(srv.URL, notif, resp)

	if got := hits.Load(); got != 3 {
		t.Errorf("expected 3 retry attempts against the failing endpoint, got %d", got)
	}
}

// TestCallbackService_SemaphoreBounded is the "queue vs explode" invariant
// test. The guarantee CallbackService.Deliver gives the rest of the
// system is: at most callbackConcurrency deliveries are in-flight at
// once — the (N+1)th caller queues up to 2s, then drops. Goroutine
// count stays bounded even under a burst.
//
// Rather than spinning up httptest servers and racing goroutines, we
// test the invariant directly at the channel level: filling the
// semaphore to capacity must block further non-blocking sends, and
// releasing a slot must unblock exactly one waiter.
func TestCallbackService_SemaphoreBounded(t *testing.T) {
	svc := NewCallbackService()

	// Saturate the semaphore — this simulates callbackConcurrency
	// goroutines currently processing deliveries.
	for i := 0; i < callbackConcurrency; i++ {
		select {
		case svc.sem <- struct{}{}:
		default:
			t.Fatalf("failed to fill semaphore at slot %d (cap=%d)", i, callbackConcurrency)
		}
	}

	// One more must not fit — a non-blocking send hits the default branch.
	select {
	case svc.sem <- struct{}{}:
		t.Fatalf("semaphore accepted an over-capacity slot; bound broken")
	default:
		// expected: full
	}

	// Release one slot and verify the next send succeeds.
	<-svc.sem
	select {
	case svc.sem <- struct{}{}:
		// expected: the released slot is now free
	default:
		t.Fatalf("released slot didn't become available")
	}

	// Final sanity: capacity equals the documented constant.
	if got := cap(svc.sem); got != callbackConcurrency {
		t.Errorf("semaphore cap = %d, want %d", got, callbackConcurrency)
	}
}
