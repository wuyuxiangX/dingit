package service

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Device struct {
	ID                 string `json:"id"`
	Token              string `json:"token"`
	Platform           string `json:"platform"`
	DndEnabled         bool   `json:"dnd_enabled"`
	DndStartMinute     *int   `json:"dnd_start_minute,omitempty"`
	DndEndMinute       *int   `json:"dnd_end_minute,omitempty"`
	DndTzOffsetMinutes int    `json:"dnd_tz_offset_minutes"`
}

// IsInDnd reports whether `at` falls inside the device's Do Not Disturb
// window. The window is interpreted in the device's local wall clock —
// `at` is shifted by the stored UTC offset before comparison so that a
// server in UTC and a client in UTC+8 agree on "22:00 means 22:00 for
// the user". Cross-midnight windows (22:00-08:00) are supported; when
// start == end the device is in DND for the entire day.
func (d *Device) IsInDnd(at time.Time) bool {
	if !d.DndEnabled || d.DndStartMinute == nil || d.DndEndMinute == nil {
		return false
	}
	local := at.UTC().Add(time.Duration(d.DndTzOffsetMinutes) * time.Minute)
	now := local.Hour()*60 + local.Minute()
	start, end := *d.DndStartMinute, *d.DndEndMinute
	if start == end {
		return true
	}
	if start < end {
		return now >= start && now < end
	}
	return now >= start || now < end
}

type DeviceService struct {
	pool *pgxpool.Pool
}

func NewDeviceService(pool *pgxpool.Pool) *DeviceService {
	return &DeviceService{pool: pool}
}

type RegisterParams struct {
	Token              string
	Platform           string
	DndEnabled         bool
	DndStartMinute     *int
	DndEndMinute       *int
	DndTzOffsetMinutes int
}

func (s *DeviceService) Register(ctx context.Context, p RegisterParams) (*Device, error) {
	id := "dev_" + uuid.New().String()[:8]

	query := `
		INSERT INTO devices (id, token, platform, dnd_enabled, dnd_start_minute, dnd_end_minute, dnd_tz_offset_minutes, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
		ON CONFLICT (token) DO UPDATE SET
			dnd_enabled           = EXCLUDED.dnd_enabled,
			dnd_start_minute      = EXCLUDED.dnd_start_minute,
			dnd_end_minute        = EXCLUDED.dnd_end_minute,
			dnd_tz_offset_minutes = EXCLUDED.dnd_tz_offset_minutes,
			updated_at            = NOW()
		RETURNING id, token, platform, dnd_enabled, dnd_start_minute, dnd_end_minute, dnd_tz_offset_minutes
	`

	var d Device
	err := s.pool.QueryRow(ctx, query, id, p.Token, p.Platform, p.DndEnabled, p.DndStartMinute, p.DndEndMinute, p.DndTzOffsetMinutes).
		Scan(&d.ID, &d.Token, &d.Platform, &d.DndEnabled, &d.DndStartMinute, &d.DndEndMinute, &d.DndTzOffsetMinutes)
	if err != nil {
		return nil, fmt.Errorf("register device: %w", err)
	}
	return &d, nil
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

// ListByPlatformFull returns full Device records including DND config.
func (s *DeviceService) ListByPlatformFull(ctx context.Context, platform string) ([]Device, error) {
	query := "SELECT id, token, platform, dnd_enabled, dnd_start_minute, dnd_end_minute, dnd_tz_offset_minutes FROM devices"
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

	var devices []Device
	for rows.Next() {
		var d Device
		if err := rows.Scan(&d.ID, &d.Token, &d.Platform, &d.DndEnabled, &d.DndStartMinute, &d.DndEndMinute, &d.DndTzOffsetMinutes); err != nil {
			return nil, err
		}
		devices = append(devices, d)
	}
	return devices, nil
}

func (s *DeviceService) RemoveByToken(ctx context.Context, token string) error {
	_, err := s.pool.Exec(ctx, "DELETE FROM devices WHERE token = $1", token)
	return err
}
