package service

import (
	"context"
	"time"

	"go.uber.org/zap"

	"github.com/dingit-me/server/internal/model"
	"github.com/dingit-me/server/internal/pkg/logger"
	"github.com/dingit-me/server/internal/ws"
)

type ExpiryService struct {
	store    *Store
	hub      *ws.Hub
	interval time.Duration
}

func NewExpiryService(store *Store, hub *ws.Hub, interval time.Duration) *ExpiryService {
	return &ExpiryService{store: store, hub: hub, interval: interval}
}

func (s *ExpiryService) Start(ctx context.Context) {
	ticker := time.NewTicker(s.interval)
	defer ticker.Stop()

	logger.Info("Expiry service started", zap.Duration("interval", s.interval))

	for {
		select {
		case <-ctx.Done():
			logger.Info("Expiry service stopped")
			return
		case <-ticker.C:
			s.sweep(ctx)
		}
	}
}

func (s *ExpiryService) sweep(ctx context.Context) {
	if ctx.Err() != nil {
		return
	}

	expired, err := s.store.ExpireOverdue(ctx)
	if err != nil {
		if ctx.Err() != nil {
			return // shutting down, expected
		}
		logger.Error("Expiry sweep failed", zap.Error(err))
		return
	}

	for i := range expired {
		s.hub.Broadcast(model.NewNotificationUpdatedMsg(&expired[i]))
	}

	if len(expired) > 0 {
		logger.Info("Expired notifications", zap.Int("count", len(expired)))
	}
}
