package handler

import (
	"context"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/dingit-me/server/internal/buildinfo"
	"github.com/dingit-me/server/internal/model"
	"github.com/dingit-me/server/internal/pkg/response"
	"github.com/dingit-me/server/internal/service"
	"github.com/dingit-me/server/internal/ws"
)

// healthStore is the subset of *service.Store that HealthHandler
// actually touches. Defined as an unexported interface so the handler
// can be exercised by unit tests without standing up a real pgxpool.
// Go's structural typing means *service.Store satisfies this without
// any changes to its declaration.
type healthStore interface {
	Count(ctx context.Context, status *model.NotificationStatus, priority *model.NotificationPriority) (int, error)
}

// dbPinger is the subset of *pgxpool.Pool HealthHandler uses for its
// liveness RTT measurement. Keeping it as an interface (rather than
// importing pgxpool here) lets tests swap in a stub pinger without
// pulling in a real database driver.
type dbPinger interface {
	Ping(ctx context.Context) error
}

// HealthHandler serves /health and /api/health/debug.
//
// /health is unauthenticated and deliberately minimal — it only
// returns {"status": "ok|degraded"} so anonymous callers can't
// enumerate operational signals.
//
// /api/health/debug lives behind the API-key auth middleware and
// returns a richer picture for humans SSHing in to curl it: DB
// round-trip, push provider delivery health, callback queue depth,
// WebSocket client count, and build metadata injected at link time
// (WYX-411). It is the operator's first stop when something feels
// off, complementing the Prometheus scrape target at /metrics.
type HealthHandler struct {
	store       healthStore
	hub         *ws.Hub
	pool        dbPinger                 // may be nil in tests
	apnsSvc     *service.ApnsService     // may be nil if APNs not configured
	fcmSvc      *service.FcmService      // may be nil if FCM not configured
	callbackSvc *service.CallbackService // may be nil in tests
	startTime   time.Time
}

// NewHealthHandler wires up the health endpoints. Every dependency
// except store/hub/startTime can be nil — the verbose view renders
// "enabled": false for absent push providers instead of erroring
// out, so operators running in a minimal configuration (e.g. only
// APNs, or server-only dev loops) still get a useful payload.
//
// store is typed as an interface so tests can supply an in-memory
// stand-in. Production callers pass *service.Store unchanged.
func NewHealthHandler(
	store healthStore,
	hub *ws.Hub,
	pool dbPinger,
	apnsSvc *service.ApnsService,
	fcmSvc *service.FcmService,
	callbackSvc *service.CallbackService,
) *HealthHandler {
	return &HealthHandler{
		store:       store,
		hub:         hub,
		pool:        pool,
		apnsSvc:     apnsSvc,
		fcmSvc:      fcmSvc,
		callbackSvc: callbackSvc,
		startTime:   time.Now(),
	}
}

// healthStatus is the response payload for the public health endpoint.
type healthStatus struct {
	Status string `json:"status" example:"ok"`
}

// Health godoc
//
//	@Summary		Health check
//	@Description	Public, unauthenticated liveness probe. Returns "ok" or "degraded".
//	@Tags			health
//	@Produce		json
//	@Success		200	{object}	response.Response{data=healthStatus}	"Server health"
//	@Router			/health [get]
func (h *HealthHandler) Health(c *gin.Context) {
	pending := model.StatusPending
	_, err := h.store.Count(c.Request.Context(), &pending, nil)

	status := "ok"
	if err != nil {
		status = "degraded"
	}

	response.Success(c, gin.H{"status": status})
}

// HealthDebug godoc
//
//	@Summary		Debug health (verbose)
//	@Description	Authenticated verbose health view with DB ping, push provider status, callback queue depth, WebSocket client count, and build metadata.
//	@Tags			health
//	@Produce		json
//	@Success		200	{object}	response.Response	"Verbose health"
//	@Failure		401	{object}	response.Response	"Unauthorized"
//	@Security		BearerAuth
//	@Router			/api/health/debug [get]
func (h *HealthHandler) HealthDebug(c *gin.Context) {
	ctx := c.Request.Context()

	pending := model.StatusPending
	count, err := h.store.Count(ctx, &pending, nil)

	status := "ok"
	if err != nil {
		status = "degraded"
	}

	// Short-ping the DB pool separately so we report the actual TCP
	// round-trip, not "whatever the pending count query took". Uses
	// its own 2s deadline so a wedged DB doesn't freeze the whole
	// /api/health/debug response — a bounded timeout is more useful
	// to operators than a hung request.
	dbPingMs := -1
	if h.pool != nil {
		pingCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
		start := time.Now()
		if err := h.pool.Ping(pingCtx); err == nil {
			dbPingMs = int(time.Since(start).Milliseconds())
		} else {
			status = "degraded"
		}
		cancel()
	}

	resp := gin.H{
		"status":                status,
		"uptime_seconds":        int(time.Since(h.startTime).Seconds()),
		"connected_clients":     h.hub.ConnectedClients(),
		"pending_notifications": count,
		"db_ping_ms":            dbPingMs,
		"push_providers": gin.H{
			"apns": apnsStatus(h.apnsSvc),
			"fcm":  fcmStatus(h.fcmSvc),
		},
		"callback_queue": callbackQueueStatus(h.callbackSvc),
		"build_info": gin.H{
			"version":    buildinfo.Version,
			"commit_sha": buildinfo.CommitSHA,
			"built_at":   buildinfo.BuiltAt,
		},
	}

	response.Success(c, resp)
}

// apnsStatus renders an APNs provider block. Nil service means APNs
// was not configured via environment variables at boot — the JSON
// still carries an "enabled": false field so consumers always see a
// consistent shape.
func apnsStatus(s *service.ApnsService) gin.H {
	if s == nil {
		return gin.H{"enabled": false}
	}
	return pushProviderStatus(s.Stats())
}

func fcmStatus(s *service.FcmService) gin.H {
	if s == nil {
		return gin.H{"enabled": false}
	}
	return pushProviderStatus(s.Stats())
}

// pushProviderStatus renders a single push provider's stats block.
// Zero timestamps turn into empty strings so JSON consumers can
// distinguish "never attempted" from a real RFC3339 value without
// dealing with Go's 0001-01-01 sentinel.
func pushProviderStatus(s service.PushProviderStats) gin.H {
	return gin.H{
		"enabled":         true,
		"last_success_at": timeOrEmpty(s.LastSuccessAt),
		"last_error_at":   timeOrEmpty(s.LastErrorAt),
		"last_error":      s.LastError,
	}
}

func callbackQueueStatus(s *service.CallbackService) gin.H {
	if s == nil {
		return gin.H{"in_flight": 0, "pending": 0}
	}
	stats := s.Stats()
	return gin.H{
		"in_flight": stats.InFlight,
		"pending":   stats.Pending,
	}
}

func timeOrEmpty(t time.Time) string {
	if t.IsZero() {
		return ""
	}
	return t.UTC().Format(time.RFC3339Nano)
}
