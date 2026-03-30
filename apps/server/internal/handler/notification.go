package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"github.com/dingit-me/server/internal/model"
	"github.com/dingit-me/server/internal/service"
	"github.com/dingit-me/server/internal/ws"
)

type NotificationHandler struct {
	store *service.Store
	hub   *ws.Hub
}

func NewNotificationHandler(store *service.Store, hub *ws.Hub) *NotificationHandler {
	return &NotificationHandler{store: store, hub: hub}
}

type createRequest struct {
	Title       string                     `json:"title" binding:"required"`
	Body        string                     `json:"body" binding:"required"`
	Source      string                     `json:"source"`
	Actions     []model.NotificationAction `json:"actions"`
	CallbackURL *string                    `json:"callback_url"`
	Metadata    map[string]any             `json:"metadata"`
}

func (h *NotificationHandler) Create(c *gin.Context) {
	var req createRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "title and body are required"})
		return
	}

	source := req.Source
	if source == "" {
		source = "unknown"
	}

	n := &model.Notification{
		Title:       req.Title,
		Body:        req.Body,
		Source:      source,
		Actions:     req.Actions,
		CallbackURL: req.CallbackURL,
		Metadata:    req.Metadata,
	}

	created, err := h.store.Add(c.Request.Context(), n)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	h.hub.Broadcast(model.NewNotificationNewMsg(created))

	c.JSON(http.StatusCreated, gin.H{
		"id":        created.ID,
		"status":    created.Status,
		"timestamp": created.Timestamp,
	})
}

func (h *NotificationHandler) List(c *gin.Context) {
	ctx := c.Request.Context()

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	var status *model.NotificationStatus
	if s := c.Query("status"); s != "" {
		st := model.NotificationStatus(s)
		status = &st
	}

	notifications, err := h.store.List(ctx, status, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	total, _ := h.store.Count(ctx, status)

	c.JSON(http.StatusOK, gin.H{
		"notifications": notifications,
		"total":         total,
	})
}

func (h *NotificationHandler) GetByID(c *gin.Context) {
	id := c.Param("id")

	n, err := h.store.Get(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if n == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Not found"})
		return
	}

	c.JSON(http.StatusOK, n)
}
