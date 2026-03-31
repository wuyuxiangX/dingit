package service

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"log"
	"time"

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
}

func NewAPIKeyService(pool *pgxpool.Pool) *APIKeyService {
	return &APIKeyService{pool: pool}
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

	go func() {
		bgCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_, err := s.pool.Exec(bgCtx, `UPDATE api_keys SET last_used_at = $1 WHERE id = $2`, time.Now().UTC(), ak.ID)
		if err != nil {
			log.Printf("[APIKey] Failed to update last_used_at: %v", err)
		}
	}()

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
	log.Println("[APIKey] Seeded API key from DINGIT_API_KEY environment variable")
	return nil
}

func mustRandomHex(n int) string {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		panic(err)
	}
	return hex.EncodeToString(b)
}
