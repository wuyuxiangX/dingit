// Package metrics defines the Prometheus metrics exposed by the Dingit
// server. Counters and histograms live here as package-level variables so
// any service code can increment them without passing a metrics struct
// around. Dynamic gauges (ws clients, notifications by status) are
// implemented as custom prometheus.Collector values that compute their
// values at scrape time — no background goroutines, always fresh.
//
// Everything is registered with the default Prometheus registry, which is
// what promhttp.Handler() serves by default.
package metrics

import (
	"context"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

// HTTPRequestsTotal counts every HTTP request by method, parameterized
// route (Gin's c.FullPath(), not the raw URL), and numeric status code.
// Using FullPath keeps label cardinality bounded — without it, every
// UUID in /api/notifications/:id would spawn its own time series.
var HTTPRequestsTotal = promauto.NewCounterVec(
	prometheus.CounterOpts{
		Name: "dingit_http_requests_total",
		Help: "Total HTTP requests by method, parameterized route, and response status code.",
	},
	[]string{"method", "route", "status"},
)

// HTTPRequestDuration records request latency distributions per route.
// Default Prometheus buckets (5ms..10s) are a good fit for a notification
// API where p50 is single-digit ms and pathological cases cap at a few
// seconds.
var HTTPRequestDuration = promauto.NewHistogramVec(
	prometheus.HistogramOpts{
		Name:    "dingit_http_request_duration_seconds",
		Help:    "HTTP request latency distribution in seconds, by parameterized route.",
		Buckets: prometheus.DefBuckets,
	},
	[]string{"route"},
)

// PushDeliveryTotal counts push provider send attempts by outcome.
// Result values are a closed enum: "success", "invalid_token", "error".
// Label cardinality is therefore bounded at 2 providers × 3 results = 6.
var PushDeliveryTotal = promauto.NewCounterVec(
	prometheus.CounterOpts{
		Name: "dingit_push_delivery_total",
		Help: "Push notification deliveries by provider (apns/fcm) and result.",
	},
	[]string{"provider", "result"},
)

// CallbackDeliveryTotal counts the terminal outcome of a callback URL
// delivery attempt — NOT every retry. Retries are an implementation
// detail; users care about "did the callback eventually succeed or not".
// status_class is "2xx" / "4xx" / "5xx" / "network_error" / "none"
// (the last for rejected/dropped paths where no HTTP call was made).
var CallbackDeliveryTotal = promauto.NewCounterVec(
	prometheus.CounterOpts{
		Name: "dingit_callback_delivery_total",
		Help: "Callback deliveries by final result (success/failure/rejected/dropped) and HTTP status class.",
	},
	[]string{"result", "status_class"},
)

// WSHub is the minimal interface the metrics package needs from ws.Hub.
// Defined here, not imported from the ws package, to avoid an import
// cycle: ws code calls nothing from metrics, but metrics needs to read
// live state from the hub during scrape.
type WSHub interface {
	ConnectedClients() int
}

// StatusCountFunc returns the current number of notifications in a given
// status bucket. Injected from main.go at startup so the metrics package
// stays fully decoupled from internal/service and internal/model.
type StatusCountFunc func(ctx context.Context, status string) (int, error)

// notificationStatusLabels is the closed set of labels for the
// notifications_by_status gauge. Kept as a package-level slice so it's
// obvious from the code what gets emitted on each scrape.
var notificationStatusLabels = []string{"pending", "actioned", "dismissed", "expired"}

// RegisterDynamic registers the two scrape-time gauges backed by
// custom collectors: dingit_ws_connected_clients and
// dingit_notifications_by_status. Call once at server startup, after
// the hub and store are fully constructed.
//
// Using custom collectors instead of promauto.NewGaugeFunc / a ticker
// has two wins: (1) values are always fresh at scrape time, (2) no
// background goroutine burning CPU when nobody is scraping.
func RegisterDynamic(hub WSHub, count StatusCountFunc) {
	prometheus.MustRegister(&wsCollector{hub: hub})
	prometheus.MustRegister(&notifCollector{count: count})
}

// --- custom collectors ---

var wsClientsDesc = prometheus.NewDesc(
	"dingit_ws_connected_clients",
	"Current number of active WebSocket clients connected to the hub.",
	nil, nil,
)

type wsCollector struct{ hub WSHub }

func (c *wsCollector) Describe(ch chan<- *prometheus.Desc) {
	ch <- wsClientsDesc
}

func (c *wsCollector) Collect(ch chan<- prometheus.Metric) {
	ch <- prometheus.MustNewConstMetric(
		wsClientsDesc,
		prometheus.GaugeValue,
		float64(c.hub.ConnectedClients()),
	)
}

var notifByStatusDesc = prometheus.NewDesc(
	"dingit_notifications_by_status",
	"Number of notifications currently in each status bucket.",
	[]string{"status"}, nil,
)

type notifCollector struct{ count StatusCountFunc }

func (c *notifCollector) Describe(ch chan<- *prometheus.Desc) {
	ch <- notifByStatusDesc
}

func (c *notifCollector) Collect(ch chan<- prometheus.Metric) {
	// 2s ceiling per scrape. If the DB is slow we'd rather drop this
	// gauge for one scrape than stall the whole /metrics response —
	// Prometheus will retry on the next interval.
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	for _, status := range notificationStatusLabels {
		n, err := c.count(ctx, status)
		if err != nil {
			// Silently skip this bucket on error. The alternative is
			// emitting a 0 which would be a lie, or failing the whole
			// scrape which is worse. Loki/app logs still show the error
			// through the store layer.
			continue
		}
		ch <- prometheus.MustNewConstMetric(
			notifByStatusDesc,
			prometheus.GaugeValue,
			float64(n),
			status,
		)
	}
}
