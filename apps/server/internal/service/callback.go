package service

import (
	"bytes"
	"encoding/json"
	"math"
	"net/http"
	"time"

	"go.uber.org/zap"

	"github.com/dingit-me/server/internal/model"
	"github.com/dingit-me/server/internal/pkg/logger"
)

type CallbackService struct {
	client *http.Client
}

func NewCallbackService() *CallbackService {
	return &CallbackService{
		client: &http.Client{Timeout: 10 * time.Second},
	}
}

func (s *CallbackService) Deliver(notification *model.Notification, response *model.ActionResponse) {
	if notification.CallbackURL == nil || *notification.CallbackURL == "" {
		return
	}

	go s.deliverWithRetry(*notification.CallbackURL, notification, response)
}

func (s *CallbackService) deliverWithRetry(url string, notification *model.Notification, response *model.ActionResponse) {
	payload := map[string]any{
		"notification_id": notification.ID,
		"action":          response.Action,
		"timestamp":       response.Timestamp.Format(time.RFC3339Nano),
		"metadata":        notification.Metadata,
		"source":          response.Source,
	}

	body, err := json.Marshal(payload)
	if err != nil {
		logger.Error("Callback marshal error", zap.Error(err))
		return
	}

	const maxRetries = 3
	for attempt := 0; attempt < maxRetries; attempt++ {
		resp, err := s.client.Post(url, "application/json", bytes.NewReader(body))
		if err == nil {
			resp.Body.Close()
			if resp.StatusCode >= 200 && resp.StatusCode < 300 {
				logger.Info("Callback delivered", zap.String("url", url), zap.Int("status", resp.StatusCode))
				return
			}
			logger.Warn("Callback failed", zap.String("url", url), zap.Int("attempt", attempt+1), zap.Int("status", resp.StatusCode))
		} else {
			logger.Warn("Callback error", zap.String("url", url), zap.Int("attempt", attempt+1), zap.Error(err))
		}

		if attempt < maxRetries-1 {
			delay := time.Duration(math.Pow(3, float64(attempt+1))) * time.Second
			time.Sleep(delay)
		}
	}

	logger.Error("Callback retries exhausted", zap.String("url", url))
}
