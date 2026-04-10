package middleware

import (
	"strconv"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/dingit-me/server/internal/metrics"
)

// metricsEndpointPath is the route that serves Prometheus scrapes.
// We hard-skip it inside the metrics middleware so that Prometheus
// scraping us doesn't pump dingit_http_requests_total{route="/metrics"}
// on every scrape interval — that's noise and would drown out real traffic.
const metricsEndpointPath = "/metrics"

// Metrics returns a Gin middleware that records two things for every
// non-/metrics request:
//
//   - dingit_http_requests_total (method, route, status) — a counter
//   - dingit_http_request_duration_seconds (route) — a histogram
//
// "route" is Gin's c.FullPath() — the parameterized pattern like
// "/api/notifications/:id" — NOT the raw URL. This keeps label
// cardinality bounded: without it, every notification UUID would
// spawn its own time series and eventually OOM Prometheus.
//
// Unmatched routes (the ones that would return 404 via NoRoute) are
// bucketed as "unmatched" so scanners/probes can't create unbounded
// label cardinality by hitting random paths.
//
// Place this middleware after RequestLog but BEFORE IPRateLimit and
// APIKeyAuth so that 401/429/500 responses are still counted —
// that's exactly the kind of traffic you want visibility into.
func Metrics() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()

		route := c.FullPath()
		if route == "" {
			route = "unmatched"
		}
		if route == metricsEndpointPath {
			return
		}

		status := strconv.Itoa(c.Writer.Status())
		metrics.HTTPRequestsTotal.
			WithLabelValues(c.Request.Method, route, status).
			Inc()
		metrics.HTTPRequestDuration.
			WithLabelValues(route).
			Observe(time.Since(start).Seconds())
	}
}
