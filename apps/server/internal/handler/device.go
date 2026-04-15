package handler

import (
	"regexp"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	"github.com/dingit-me/server/internal/pkg/logger"
	"github.com/dingit-me/server/internal/pkg/response"
	"github.com/dingit-me/server/internal/service"
)

type DeviceHandler struct {
	deviceSvc *service.DeviceService
}

func NewDeviceHandler(deviceSvc *service.DeviceService) *DeviceHandler {
	return &DeviceHandler{deviceSvc: deviceSvc}
}

type registerDeviceRequest struct {
	Token    string `json:"token" binding:"required"`
	Platform string `json:"platform"`
	// DND bounds are wall-clock HH:MM in the device's local timezone.
	// DndTzOffsetMinutes is the device's UTC offset at registration time
	// (e.g. 480 for UTC+8) and is applied server-side before comparing
	// time.Now() against the window.
	DndEnabled         bool   `json:"dnd_enabled"`
	DndStart           string `json:"dnd_start"`
	DndEnd             string `json:"dnd_end"`
	DndTzOffsetMinutes int    `json:"dnd_tz_offset_minutes"`
}

type unregisterDeviceRequest struct {
	Token string `json:"token" binding:"required"`
}

var validPlatforms = map[string]bool{"ios": true, "android": true}

// APNs device tokens are 64 hex characters (32 bytes). Anything that
// doesn't match this shape is definitely not a real token, so we reject
// at the gate instead of wasting an APNs round-trip.
var apnsTokenRE = regexp.MustCompile(`^[0-9a-fA-F]{64}$`)

// FCM tokens are a dot-separated structure of base64url-ish segments.
// Length varies (often 140-200 chars) but always URL-safe characters
// plus colon and underscore. This is intentionally permissive — FCM
// token format is undocumented and changes over time.
var fcmTokenRE = regexp.MustCompile(`^[A-Za-z0-9_\-:.]{100,300}$`)

// Register godoc
//
//	@Summary		Register a device
//	@Description	Register a device token for push notifications (APNs or FCM).
//	@Tags			devices
//	@Accept			json
//	@Produce		json
//	@Param			body	body		registerDeviceRequest	true	"Device token and platform"
//	@Success		200		{object}	response.Response		"Registered device"
//	@Failure		400		{object}	response.Response		"Invalid token or platform"
//	@Failure		401		{object}	response.Response		"Unauthorized"
//	@Failure		500		{object}	response.Response		"Internal error"
//	@Security		BearerAuth
//	@Router			/api/devices [post]
func (h *DeviceHandler) Register(c *gin.Context) {
	var req registerDeviceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, response.CodeBadRequest, "token is required")
		return
	}

	platform := req.Platform
	if platform == "" {
		platform = "ios"
	}
	if !validPlatforms[platform] {
		response.BadRequest(c, response.CodeBadRequest, "invalid platform, must be ios or android")
		return
	}

	switch platform {
	case "ios":
		if !apnsTokenRE.MatchString(req.Token) {
			response.BadRequest(c, response.CodeBadRequest, "invalid iOS APNs token format (expect 64 hex chars)")
			return
		}
	case "android":
		if !fcmTokenRE.MatchString(req.Token) {
			response.BadRequest(c, response.CodeBadRequest, "invalid Android FCM token format")
			return
		}
	}

	dndStart, err := parseDndMinute(req.DndStart)
	if err != nil {
		response.BadRequest(c, response.CodeBadRequest, "invalid dnd_start, expected HH:MM")
		return
	}
	dndEnd, err := parseDndMinute(req.DndEnd)
	if err != nil {
		response.BadRequest(c, response.CodeBadRequest, "invalid dnd_end, expected HH:MM")
		return
	}
	if req.DndEnabled && (dndStart == nil || dndEnd == nil) {
		response.BadRequest(c, response.CodeBadRequest, "dnd_start and dnd_end are required when dnd_enabled is true")
		return
	}
	// Reject offsets outside the valid civilian timezone range to catch
	// obviously-wrong clients (e.g. sending seconds instead of minutes).
	if req.DndTzOffsetMinutes < -12*60 || req.DndTzOffsetMinutes > 14*60 {
		response.BadRequest(c, response.CodeBadRequest, "invalid dnd_tz_offset_minutes")
		return
	}

	device, err := h.deviceSvc.Register(c.Request.Context(), service.RegisterParams{
		Token:              req.Token,
		Platform:           platform,
		DndEnabled:         req.DndEnabled,
		DndStartMinute:     dndStart,
		DndEndMinute:       dndEnd,
		DndTzOffsetMinutes: req.DndTzOffsetMinutes,
	})
	if err != nil {
		logger.Error("register device failed", zap.Error(err))
		response.InternalError(c, "Failed to register device")
		return
	}

	response.Success(c, device)
}

// Unregister godoc
//
//	@Summary		Unregister a device
//	@Description	Remove a device token so the server stops pushing to it.
//	@Tags			devices
//	@Accept			json
//	@Produce		json
//	@Param			body	body		unregisterDeviceRequest	true	"Device token"
//	@Success		200		{object}	response.Response		"Unregistered"
//	@Failure		400		{object}	response.Response		"Invalid request"
//	@Failure		401		{object}	response.Response		"Unauthorized"
//	@Failure		500		{object}	response.Response		"Internal error"
//	@Security		BearerAuth
//	@Router			/api/devices/unregister [post]
func (h *DeviceHandler) Unregister(c *gin.Context) {
	var req unregisterDeviceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, response.CodeBadRequest, "token is required")
		return
	}
	if err := h.deviceSvc.RemoveByToken(c.Request.Context(), req.Token); err != nil {
		logger.Error("unregister device failed", zap.Error(err))
		response.InternalError(c, "Failed to unregister device")
		return
	}
	response.Success(c, gin.H{"ok": true})
}

// parseDndMinute parses an "HH:MM" wall-clock string into a minute-of-day
// integer (0-1439). Empty input returns nil, treated as "not set" by the
// service layer.
func parseDndMinute(s string) (*int, error) {
	if s == "" {
		return nil, nil
	}
	t, err := time.Parse("15:04", s)
	if err != nil {
		return nil, err
	}
	m := t.Hour()*60 + t.Minute()
	return &m, nil
}
