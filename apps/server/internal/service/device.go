package service

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Device struct {
	ID       string `json:"id"`
	Token    string `json:"token"`
	Platform string `json:"platform"`
}

type DeviceService struct {
	pool *pgxpool.Pool
}

func NewDeviceService(pool *pgxpool.Pool) *DeviceService {
	return &DeviceService{pool: pool}
}

func (s *DeviceService) Register(ctx context.Context, token, platform string) (*Device, error) {
	id := "dev_" + uuid.New().String()[:8]

	query := `
		INSERT INTO devices (id, token, platform, updated_at)
		VALUES ($1, $2, $3, NOW())
		ON CONFLICT (token) DO UPDATE SET updated_at = NOW()
		RETURNING id, token, platform
	`

	var d Device
	err := s.pool.QueryRow(ctx, query, id, token, platform).Scan(&d.ID, &d.Token, &d.Platform)
	if err != nil {
		return nil, fmt.Errorf("register device: %w", err)
	}
	return &d, nil
}

func (s *DeviceService) ListTokens(ctx context.Context) ([]string, error) {
	return s.ListByPlatform(ctx, "")
}

func (s *DeviceService) ListByPlatform(ctx context.Context, platform string) ([]string, error) {
	query := "SELECT token FROM devices"
	var args []any
	if platform != "" {
		query += " WHERE platform = $1"
		args = append(args, platform)
	}

	rows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tokens []string
	for rows.Next() {
		var token string
		if err := rows.Scan(&token); err != nil {
			return nil, err
		}
		tokens = append(tokens, token)
	}
	return tokens, nil
}

func (s *DeviceService) RemoveByToken(ctx context.Context, token string) error {
	_, err := s.pool.Exec(ctx, "DELETE FROM devices WHERE token = $1", token)
	return err
}
