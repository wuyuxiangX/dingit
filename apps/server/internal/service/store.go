package service

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/dingit-me/server/internal/model"
)

const notificationColumns = `id, title, body, source, status, priority, actions, callback_url, metadata, actioned_value, created_at, actioned_at, expires_at`

type Store struct {
	pool *pgxpool.Pool
}

func NewStore(pool *pgxpool.Pool) *Store {
	return &Store{pool: pool}
}

func (s *Store) Add(ctx context.Context, n *model.Notification) (*model.Notification, error) {
	n.ID = fmt.Sprintf("ntf_%s", uuid.New().String()[:8])
	n.Timestamp = time.Now().UTC()
	n.Status = model.StatusPending
	if n.Priority == "" {
		n.Priority = model.PriorityNormal
	}

	if n.Actions == nil {
		n.Actions = []model.NotificationAction{}
	}

	actionsJSON, err := json.Marshal(n.Actions)
	if err != nil {
		return nil, fmt.Errorf("marshal actions: %w", err)
	}

	var metadataJSON []byte
	if n.Metadata != nil {
		metadataJSON, err = json.Marshal(n.Metadata)
		if err != nil {
			return nil, fmt.Errorf("marshal metadata: %w", err)
		}
	}

	_, err = s.pool.Exec(ctx, `
		INSERT INTO notifications (id, title, body, source, status, priority, actions, callback_url, metadata, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`, n.ID, n.Title, n.Body, n.Source, n.Status, n.Priority, actionsJSON, n.CallbackURL, metadataJSON, n.Timestamp)
	if err != nil {
		return nil, fmt.Errorf("insert notification: %w", err)
	}

	return n, nil
}

func (s *Store) Get(ctx context.Context, id string) (*model.Notification, error) {
	return s.scanOne(ctx, `SELECT `+notificationColumns+` FROM notifications WHERE id = $1`, id)
}

func (s *Store) List(ctx context.Context, status *model.NotificationStatus, priority *model.NotificationPriority, limit, offset int) ([]model.Notification, error) {
	query := `SELECT ` + notificationColumns + ` FROM notifications`
	var conditions []string
	var args []any
	argIdx := 1

	if status != nil {
		conditions = append(conditions, fmt.Sprintf("status = $%d", argIdx))
		args = append(args, string(*status))
		argIdx++
	}
	if priority != nil {
		conditions = append(conditions, fmt.Sprintf("priority = $%d", argIdx))
		args = append(args, string(*priority))
		argIdx++
	}
	if len(conditions) > 0 {
		query += " WHERE " + strings.Join(conditions, " AND ")
	}
	query += fmt.Sprintf(" ORDER BY created_at DESC LIMIT $%d OFFSET $%d", argIdx, argIdx+1)
	args = append(args, limit, offset)

	rows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list notifications: %w", err)
	}
	defer rows.Close()

	var result []model.Notification
	for rows.Next() {
		n, err := scanNotification(rows)
		if err != nil {
			return nil, err
		}
		result = append(result, *n)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate notifications: %w", err)
	}
	if result == nil {
		result = []model.Notification{}
	}
	return result, nil
}

func (s *Store) Count(ctx context.Context, status *model.NotificationStatus, priority *model.NotificationPriority) (int, error) {
	query := `SELECT COUNT(*) FROM notifications`
	var conditions []string
	var args []any
	argIdx := 1

	if status != nil {
		conditions = append(conditions, fmt.Sprintf("status = $%d", argIdx))
		args = append(args, string(*status))
		argIdx++
	}
	if priority != nil {
		conditions = append(conditions, fmt.Sprintf("priority = $%d", argIdx))
		args = append(args, string(*priority))
		argIdx++
	}
	if len(conditions) > 0 {
		query += " WHERE " + strings.Join(conditions, " AND ")
	}

	var count int
	err := s.pool.QueryRow(ctx, query, args...).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("count notifications: %w", err)
	}
	return count, nil
}

func (s *Store) UpdateStatus(ctx context.Context, id string, status model.NotificationStatus, actionedValue *string) (*model.Notification, error) {
	var actionedAt *time.Time
	if status == model.StatusActioned {
		now := time.Now().UTC()
		actionedAt = &now
	}

	return s.scanOne(ctx, `
		UPDATE notifications SET status = $1, actioned_value = $2, actioned_at = $3
		WHERE id = $4
		RETURNING `+notificationColumns,
		string(status), actionedValue, actionedAt, id)
}

func (s *Store) Delete(ctx context.Context, id string) (bool, error) {
	tag, err := s.pool.Exec(ctx, `DELETE FROM notifications WHERE id = $1`, id)
	if err != nil {
		return false, fmt.Errorf("delete notification: %w", err)
	}
	return tag.RowsAffected() > 0, nil
}

func (s *Store) scanOne(ctx context.Context, query string, args ...any) (*model.Notification, error) {
	rows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	if !rows.Next() {
		if err := rows.Err(); err != nil {
			return nil, fmt.Errorf("scan query: %w", err)
		}
		return nil, nil
	}
	return scanNotification(rows)
}

func scanNotification(rows pgx.Rows) (*model.Notification, error) {
	var n model.Notification
	var actionsJSON, metadataJSON []byte
	var status, priority string

	err := rows.Scan(
		&n.ID, &n.Title, &n.Body, &n.Source, &status, &priority,
		&actionsJSON, &n.CallbackURL, &metadataJSON, &n.ActionedValue,
		&n.Timestamp, &n.ActionedAt, &n.ExpiresAt,
	)
	if err != nil {
		return nil, fmt.Errorf("scan notification: %w", err)
	}

	n.Status = model.NotificationStatus(status)
	n.Priority = model.NotificationPriority(priority)

	if actionsJSON != nil {
		if err := json.Unmarshal(actionsJSON, &n.Actions); err != nil {
			return nil, fmt.Errorf("unmarshal actions: %w", err)
		}
	}
	if n.Actions == nil {
		n.Actions = []model.NotificationAction{}
	}

	if metadataJSON != nil {
		if err := json.Unmarshal(metadataJSON, &n.Metadata); err != nil {
			return nil, fmt.Errorf("unmarshal metadata: %w", err)
		}
	}

	return &n, nil
}
