package service

import (
	"bytes"
	"encoding/json"
	"log"
	"math"
	"net/http"
	"time"

	"github.com/dingit-me/server/internal/model"
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
		log.Printf("[Callback] marshal error: %v", err)
		return
	}

	const maxRetries = 3
	for attempt := 0; attempt < maxRetries; attempt++ {
		resp, err := s.client.Post(url, "application/json", bytes.NewReader(body))
		if err == nil {
			resp.Body.Close()
			if resp.StatusCode >= 200 && resp.StatusCode < 300 {
				log.Printf("[Callback] Delivered to %s (%d)", url, resp.StatusCode)
				return
			}
			log.Printf("[Callback] Failed attempt %d: %d", attempt+1, resp.StatusCode)
		} else {
			log.Printf("[Callback] Error attempt %d: %v", attempt+1, err)
		}

		if attempt < maxRetries-1 {
			delay := time.Duration(math.Pow(3, float64(attempt+1))) * time.Second
			time.Sleep(delay)
		}
	}

	log.Printf("[Callback] All retries exhausted for %s", url)
}
