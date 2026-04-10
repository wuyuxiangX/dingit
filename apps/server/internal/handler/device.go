package handler

import (
	"regexp"

	"github.com/gin-gonic/gin"

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

	// Platform-specific token format validation. Previously we only
	// checked length (10-256 chars), which let garbage strings into
	// the push routing table. Strict-ish regex validation stops that
	// without being brittle to FCM token rotation.
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

	device, err := h.deviceSvc.Register(c.Request.Context(), req.Token, platform)
	if err != nil {
		response.InternalError(c, "Failed to register device")
		return
	}

	response.Success(c, device)
}
