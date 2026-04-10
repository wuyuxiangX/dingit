package service

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"sync"
	"time"

	"go.uber.org/zap"

	"github.com/dingit-me/server/internal/pkg/logger"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/dingit-me/server/internal/model"
)

func GenerateAPIKey() string {
	return "dingit_" + mustRandomHex(32)
}

func HashAPIKey(rawKey string) string {
	h := sha256.Sum256([]byte(rawKey))
	return hex.EncodeToString(h[:])
}

type APIKeyService struct {
	pool *pgxpool.Pool

	// lastUsedBatcher coalesces per-request last_used_at updates into a
	// single timed UPDATE. Previously every auth request spawned its
	// own goroutine to UPDATE one row, which at 100 rps was 100
	// goroutines + 100 DB round-trips per second just to maintain a
	// "last seen" column. The batcher dedupes by key id and flushes
	// every flushInterval; a map of at most N distinct keys gets
	// written in a single transaction with the latest timestamp per key.
	lastUsedMu      sync.Mutex
	lastUsedBuf     map[string]time.Time
	lastUsedStop    chan struct{}
	lastUsedStopped chan struct{}
}

const lastUsedFlushInterval = 5 * time.Second

func NewAPIKeyService(pool *pgxpool.Pool) *APIKeyService {
	svc := &APIKeyService{
		pool:            pool,
		lastUsedBuf:     make(map[string]time.Time),
		lastUsedStop:    make(chan struct{}),
		lastUsedStopped: make(chan struct{}),
	}
	go svc.lastUsedFlusher()
	return svc
}

// Stop shuts down the background flusher and drains any pending
// last_used_at updates. Safe to call multiple times.
func (s *APIKeyService) Stop() {
	select {
	case <-s.lastUsedStop:
		return // already stopped
	default:
	}
	close(s.lastUsedStop)
	<-s.lastUsedStopped
}

func (s *APIKeyService) lastUsedFlusher() {
	defer close(s.lastUsedStopped)
	ticker := time.NewTicker(lastUsedFlushInterval)
	defer ticker.Stop()
	for {
		select {
		case <-s.lastUsedStop:
			s.flushLastUsed()
			return
		case <-ticker.C:
			s.flushLastUsed()
		}
	}
}

func (s *APIKeyService) flushLastUsed() {
	s.lastUsedMu.Lock()
	if len(s.lastUsedBuf) == 0 {
		s.lastUsedMu.Unlock()
		return
	}
	batch := s.lastUsedBuf
	s.lastUsedBuf = make(map[string]time.Time)
	s.lastUsedMu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	for id, ts := range batch {
		_, err := s.pool.Exec(ctx, `UPDATE api_keys SET last_used_at = $1 WHERE id = $2`, ts, id)
		if err != nil {
			logger.Error("Failed to flush last_used_at",
				zap.String("key_id", id),
				zap.Error(err),
			)
		}
	}
}

func (s *APIKeyService) queueLastUsed(id string, ts time.Time) {
	s.lastUsedMu.Lock()
	defer s.lastUsedMu.Unlock()
	// Keep only the latest timestamp per id. No point writing an older
	// timestamp if a more recent auth hit already arrived.
	if existing, ok := s.lastUsedBuf[id]; ok && existing.After(ts) {
		return
	}
	s.lastUsedBuf[id] = ts
}

func (s *APIKeyService) Create(ctx context.Context, name, rawKey string) (*model.APIKey, error) {
	id := fmt.Sprintf("key_%s", uuid.New().String()[:8])
	keyHash := HashAPIKey(rawKey)
	prefix := rawKey
	if len(prefix) > 15 {
		prefix = prefix[:15]
	}
	now := time.Now().UTC()

	_, err := s.pool.Exec(ctx, `
		INSERT INTO api_keys (id, name, key_hash, prefix, created_at)
		VALUES ($1, $2, $3, $4, $5)
	`, id, name, keyHash, prefix, now)
	if err != nil {
		return nil, fmt.Errorf("insert api key: %w", err)
	}

	return &model.APIKey{
		ID:        id,
		Name:      name,
		KeyHash:   keyHash,
		Prefix:    prefix,
		CreatedAt: now,
	}, nil
}

func (s *APIKeyService) ValidateKey(ctx context.Context, rawKey string) (*model.APIKey, error) {
	keyHash := HashAPIKey(rawKey)

	var ak model.APIKey
	err := s.pool.QueryRow(ctx, `
		SELECT id, name, key_hash, prefix, created_at, last_used_at
		FROM api_keys WHERE key_hash = $1
	`, keyHash).Scan(&ak.ID, &ak.Name, &ak.KeyHash, &ak.Prefix, &ak.CreatedAt, &ak.LastUsedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("validate api key: %w", err)
	}

	// Coalesce the last_used_at update instead of firing a goroutine
	// per request. See lastUsedFlusher for the write path.
	s.queueLastUsed(ak.ID, time.Now().UTC())

	return &ak, nil
}

func (s *APIKeyService) Count(ctx context.Context) (int, error) {
	var count int
	err := s.pool.QueryRow(ctx, `SELECT COUNT(*) FROM api_keys`).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("count api keys: %w", err)
	}
	return count, nil
}

func (s *APIKeyService) SeedFromEnv(ctx context.Context, rawKey string) error {
	if rawKey == "" {
		return nil
	}

	keyHash := HashAPIKey(rawKey)

	var exists bool
	err := s.pool.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM api_keys WHERE key_hash = $1)`, keyHash).Scan(&exists)
	if err != nil {
		return fmt.Errorf("check existing key: %w", err)
	}
	if exists {
		return nil
	}

	_, err = s.Create(ctx, "env-seed", rawKey)
	if err != nil {
		return fmt.Errorf("seed api key: %w", err)
	}
	logger.Info("Seeded API key from DINGIT_API_KEY environment variable")
	return nil
}

func mustRandomHex(n int) string {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		panic(err)
	}
	return hex.EncodeToString(b)
}
