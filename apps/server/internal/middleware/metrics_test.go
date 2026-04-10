package middleware

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus"
	dto "github.com/prometheus/client_model/go"

	"github.com/dingit-me/server/internal/metrics"
)

func init() {
	gin.SetMode(gin.TestMode)
}

// countHTTPSamples returns the sum of all samples in
// dingit_http_requests_total matching the provided label filter.
// labelFilter is an AND predicate over the metric's labels.
func countHTTPSamples(t *testing.T, labelFilter map[string]string) float64 {
	t.Helper()
	mfs, err := prometheus.DefaultGatherer.Gather()
	if err != nil {
		t.Fatalf("gather: %v", err)
	}
	var total float64
	for _, mf := range mfs {
		if mf.GetName() != "dingit_http_requests_total" {
			continue
		}
		for _, m := range mf.Metric {
			if matchLabels(m.Label, labelFilter) {
				total += m.Counter.GetValue()
			}
		}
	}
	return total
}

func matchLabels(got []*dto.LabelPair, want map[string]string) bool {
	for k, v := range want {
		found := false
		for _, lp := range got {
			if lp.GetName() == k && lp.GetValue() == v {
				found = true
				break
			}
		}
		if !found {
			return false
		}
	}
	return true
}

// TestMetricsMiddlewareUsesFullPath verifies the middleware tags each
// metric sample with the parameterized route pattern (c.FullPath()), not
// the raw URL. This is the critical cardinality safety invariant —
// without it, every notification UUID spawns its own time series and
// Prometheus eventually OOMs.
func TestMetricsMiddlewareUsesFullPath(t *testing.T) {
	r := gin.New()
	r.Use(Metrics())
	r.GET("/api/notifications/:id", func(c *gin.Context) {
		c.String(http.StatusOK, "ok")
	})

	// Hit the same route with 5 distinct path params. If the middleware
	// were using c.Request.URL.Path we'd see 5 separate time series;
	// with FullPath() they all collapse to /api/notifications/:id.
	before := countHTTPSamples(t, map[string]string{
		"route": "/api/notifications/:id",
	})

	ids := []string{"a", "b", "c", "d", "e"}
	for _, id := range ids {
		req := httptest.NewRequest("GET", "/api/notifications/"+id, nil)
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		if w.Code != http.StatusOK {
			t.Fatalf("unexpected status %d", w.Code)
		}
	}

	after := countHTTPSamples(t, map[string]string{
		"route": "/api/notifications/:id",
	})

	if delta := after - before; delta != float64(len(ids)) {
		t.Errorf("expected %d samples under /api/notifications/:id, got delta=%v", len(ids), delta)
	}

	// Sanity: specific raw paths must NOT appear as their own label.
	// If they did, the user's parameterized-path safety net would be broken.
	for _, id := range ids {
		raw := "/api/notifications/" + id
		bad := countHTTPSamples(t, map[string]string{"route": raw})
		if bad > 0 {
			t.Errorf("raw path %q should not appear as a route label (cardinality explosion)", raw)
		}
	}
}

// TestMetricsMiddlewareSkipsSelf verifies /metrics does not instrument
// itself. If it did, every Prometheus scrape would pump the counter
// forever just from being scraped, which pollutes dashboards.
func TestMetricsMiddlewareSkipsSelf(t *testing.T) {
	r := gin.New()
	r.Use(Metrics())
	r.GET("/metrics", func(c *gin.Context) {
		c.String(http.StatusOK, "# metrics output\n")
	})

	before := countHTTPSamples(t, map[string]string{"route": "/metrics"})

	req := httptest.NewRequest("GET", "/metrics", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	after := countHTTPSamples(t, map[string]string{"route": "/metrics"})

	if after != before {
		t.Errorf("/metrics self-scrape should not increment HTTPRequestsTotal (before=%v, after=%v)", before, after)
	}
}

// TestMetricsMiddlewareUnmatchedBucket verifies routes Gin doesn't know
// about are bucketed into a single "unmatched" label — otherwise any
// scanner hitting /.git, /wp-admin, /phpmyadmin etc. would create a
// cardinality explosion via the 404 path.
func TestMetricsMiddlewareUnmatchedBucket(t *testing.T) {
	r := gin.New()
	r.Use(Metrics())
	// Intentionally no routes registered.

	paths := []string{"/.git", "/wp-admin", "/phpmyadmin", "/robots.txt"}
	for _, p := range paths {
		req := httptest.NewRequest("GET", p, nil)
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
	}

	for _, p := range paths {
		bad := countHTTPSamples(t, map[string]string{"route": p})
		if bad > 0 {
			t.Errorf("unmatched path %q should not appear as its own route label", p)
		}
	}

	unmatched := countHTTPSamples(t, map[string]string{"route": "unmatched"})
	if unmatched < float64(len(paths)) {
		t.Errorf("expected at least %d samples under route=unmatched, got %v", len(paths), unmatched)
	}
}

// TestHelpTextHasCorrectMetricName is a safety net to catch accidental
// renaming of the counters the Grafana dashboard JSON in deploy/grafana/
// depends on. We touch each one with a label set so the metric family
// appears in the registry's Gather output — without at least one
// observation, promauto-registered Vecs are present in the registry but
// invisible to Gather, which is why we can't just rely on import
// side-effects.
func TestHelpTextHasCorrectMetricName(t *testing.T) {
	// Drive one observation on each family we want to assert on.
	r := gin.New()
	r.Use(Metrics())
	r.GET("/ping", func(c *gin.Context) { c.String(200, "pong") })
	req := httptest.NewRequest("GET", "/ping", nil)
	r.ServeHTTP(httptest.NewRecorder(), req)

	metrics.PushDeliveryTotal.WithLabelValues("apns", "success").Add(0)
	metrics.CallbackDeliveryTotal.WithLabelValues("success", "2xx").Add(0)

	mfs, err := prometheus.DefaultGatherer.Gather()
	if err != nil {
		t.Fatalf("gather: %v", err)
	}
	names := map[string]bool{}
	for _, mf := range mfs {
		names[mf.GetName()] = true
	}
	wants := []string{
		"dingit_http_requests_total",
		"dingit_http_request_duration_seconds",
		"dingit_push_delivery_total",
		"dingit_callback_delivery_total",
	}
	for _, w := range wants {
		if !names[w] {
			registered := make([]string, 0, len(names))
			for n := range names {
				registered = append(registered, n)
			}
			t.Errorf("expected metric %q to be registered; registered = %s", w, strings.Join(registered, ", "))
		}
	}
}
