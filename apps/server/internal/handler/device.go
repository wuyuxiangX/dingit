package handler

import (
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

func (h *DeviceHandler) Register(c *gin.Context) {
	var req registerDeviceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, response.CodeBadRequest, "token is required")
		return
	}

	if len(req.Token) > 256 || len(req.Token) < 10 {
		response.BadRequest(c, response.CodeBadRequest, "invalid token length")
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

	device, err := h.deviceSvc.Register(c.Request.Context(), req.Token, platform)
	if err != nil {
		response.InternalError(c, "Failed to register device")
		return
	}

	response.Success(c, device)
}
