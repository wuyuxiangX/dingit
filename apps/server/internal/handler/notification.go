package handler

import (
	"context"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/dingit-me/server/internal/model"
	"github.com/dingit-me/server/internal/pkg/pagination"
	"github.com/dingit-me/server/internal/pkg/response"
	"github.com/dingit-me/server/internal/service"
	"github.com/dingit-me/server/internal/ws"
)

type NotificationHandler struct {
	store       *service.Store
	hub         *ws.Hub
	callbackSvc *service.CallbackService
	pushRouter  *service.PushRouter
}

func NewNotificationHandler(store *service.Store, hub *ws.Hub, callbackSvc *service.CallbackService, pushRouter *service.PushRouter) *NotificationHandler {
	return &NotificationHandler{store: store, hub: hub, callbackSvc: callbackSvc, pushRouter: pushRouter}
}

type createRequest struct {
	Title       string                     `json:"title" binding:"required"`
	Body        string                     `json:"body" binding:"required"`
	Source      string                     `json:"source"`
	Priority    string                     `json:"priority"`
	Icon        *string                    `json:"icon"`
	Actions     []model.NotificationAction `json:"actions"`
	CallbackURL *string                    `json:"callback_url"`
	Metadata    map[string]any             `json:"metadata"`
	TTL         *int                       `json:"ttl"`
	ExpiresAt   *string                    `json:"expires_at"`
}

func (h *NotificationHandler) Create(c *gin.Context) {
	var req createRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, response.CodeBadRequest, "title and body are required")
		return
	}

	source := req.Source
	if source == "" {
		source = "unknown"
	}

	priority := model.NotificationPriority(req.Priority)
	if req.Priority == "" {
		priority = model.PriorityNormal
	} else if !isValidPriority(priority) {
		response.BadRequest(c, response.CodeInvalidPriority, "Invalid priority value. Allowed: urgent, high, normal, low")
		return
	}

	var expiresAt *time.Time
	if req.TTL != nil {
		if *req.TTL < 0 {
			response.BadRequest(c, response.CodeBadRequest, "TTL must be a positive number of seconds")
			return
		}
		if *req.TTL > 0 {
			t := time.Now().UTC().Add(time.Duration(*req.TTL) * time.Second)
			expiresAt = &t
		}
	} else if req.ExpiresAt != nil && *req.ExpiresAt != "" {
		t, err := time.Parse(time.RFC3339, *req.ExpiresAt)
		if err != nil {
			response.BadRequest(c, response.CodeBadRequest, "Invalid expires_at format, use RFC3339")
			return
		}
		if t.Before(time.Now()) {
			response.BadRequest(c, response.CodeBadRequest, "expires_at must be in the future")
			return
		}
		expiresAt = &t
	}

	n := &model.Notification{
		Title:       req.Title,
		Body:        req.Body,
		Source:      source,
		Priority:    priority,
		Icon:        req.Icon,
		Actions:     req.Actions,
		CallbackURL: req.CallbackURL,
		Metadata:    req.Metadata,
		ExpiresAt:   expiresAt,
	}

	created, err := h.store.Add(c.Request.Context(), n)
	if err != nil {
		response.InternalError(c, "Failed to create notification")
		return
	}

	h.hub.Broadcast(model.NewNotificationNewMsg(created))

	// Send push notification with current pending count as badge
	pending := model.StatusPending
	pendingCount, _ := h.store.Count(c.Request.Context(), &pending, nil)
	h.pushRouter.SendToAll(context.Background(), created, pendingCount)

	response.Created(c, gin.H{
		"id":        created.ID,
		"status":    created.Status,
		"timestamp": created.Timestamp,
	})
}

func (h *NotificationHandler) List(c *gin.Context) {
	ctx := c.Request.Context()

	var p pagination.Params
	_ = c.ShouldBindQuery(&p)
	page, pageSize, offset := p.Normalize()

	var status *model.NotificationStatus
	if s := c.Query("status"); s != "" {
		st := model.NotificationStatus(s)
		if !isValidStatus(st) {
			response.BadRequest(c, response.CodeInvalidStatus, "Invalid status filter")
			return
		}
		status = &st
	}

	var priority *model.NotificationPriority
	if p := c.Query("priority"); p != "" {
		pr := model.NotificationPriority(p)
		if !isValidPriority(pr) {
			response.BadRequest(c, response.CodeInvalidPriority, "Invalid priority filter")
			return
		}
		priority = &pr
	}

	notifications, err := h.store.List(ctx, status, priority, pageSize, offset)
	if err != nil {
		response.InternalError(c, "Failed to list notifications")
		return
	}

	total, err := h.store.Count(ctx, status, priority)
	if err != nil {
		response.InternalError(c, "Failed to count notifications")
		return
	}

	response.Success(c, pagination.NewResult(notifications, int64(total), page, pageSize))
}

func (h *NotificationHandler) GetByID(c *gin.Context) {
	id := c.Param("id")

	n, err := h.store.Get(c.Request.Context(), id)
	if err != nil {
		response.InternalError(c, "Failed to get notification")
		return
	}
	if n == nil {
		response.NotFound(c, "Notification not found")
		return
	}

	response.Success(c, n)
}

type updateRequest struct {
	Status        *model.NotificationStatus `json:"status"`
	ActionedValue *string                   `json:"actioned_value"`
}

func (h *NotificationHandler) Update(c *gin.Context) {
	id := c.Param("id")
	ctx := c.Request.Context()

	var req updateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, response.CodeBadRequest, "Invalid request body")
		return
	}

	if req.Status == nil {
		response.BadRequest(c, response.CodeBadRequest, "status is required")
		return
	}

	if !isValidStatus(*req.Status) {
		response.BadRequest(c, response.CodeInvalidStatus, "Invalid status value")
		return
	}

	updated, err := h.store.UpdateStatus(ctx, id, *req.Status, req.ActionedValue)
	if err != nil {
		response.InternalError(c, "Failed to update notification")
		return
	}
	if updated == nil {
		response.NotFound(c, "Notification not found")
		return
	}

	h.hub.Broadcast(model.NewNotificationUpdatedMsg(updated))

	if *req.Status == model.StatusActioned && updated.CallbackURL != nil && req.ActionedValue != nil {
		h.callbackSvc.Deliver(updated, &model.ActionResponse{
			NotificationID: id,
			Action:         *req.ActionedValue,
		})
	}

	response.Success(c, updated)
}

func (h *NotificationHandler) Delete(c *gin.Context) {
	id := c.Param("id")

	deleted, err := h.store.Delete(c.Request.Context(), id)
	if err != nil {
		response.InternalError(c, "Failed to delete notification")
		return
	}
	if !deleted {
		response.NotFound(c, "Notification not found")
		return
	}

	h.hub.Broadcast(model.NewNotificationDeletedMsg(id))

	response.NoContent(c)
}

func isValidStatus(s model.NotificationStatus) bool {
	switch s {
	case model.StatusPending, model.StatusActioned, model.StatusDismissed, model.StatusExpired:
		return true
	}
	return false
}

func isValidPriority(p model.NotificationPriority) bool {
	switch p {
	case model.PriorityUrgent, model.PriorityHigh, model.PriorityNormal, model.PriorityLow:
		return true
	}
	return false
}
