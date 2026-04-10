package service

import (
	"context"
	"sync"
	"testing"
	"time"

	"github.com/dingit-me/server/internal/model"
)

// TestStore_Add is the happy-path smoke test for Store.Add. It verifies
// that (a) the caller gets back a notification with a generated ID and
// timestamp, (b) the persisted row round-trips correctly through Get,
// and (c) unset fields pick up the intended defaults (status=pending,
// priority=normal, empty actions slice).
func TestStore_Add(t *testing.T) {
	pool := getTestPool(t)
	t.Cleanup(func() { truncateAll(t, pool) })

	store := NewStore(pool)
	ctx := context.Background()

	created, err := store.Add(ctx, &model.Notification{
		Title: "hello",
		Body:  "world",
	})
	if err != nil {
		t.Fatalf("Add: %v", err)
	}
	if created.ID == "" {
		t.Errorf("expected generated ID, got empty")
	}
	if created.Status != model.StatusPending {
		t.Errorf("expected default status=pending, got %q", created.Status)
	}
	if created.Priority != model.PriorityNormal {
		t.Errorf("expected default priority=normal, got %q", created.Priority)
	}
	if created.Timestamp.IsZero() {
		t.Errorf("expected non-zero timestamp")
	}

	// Round-trip via Get to verify persistence.
	fetched, err := store.Get(ctx, created.ID)
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if fetched == nil {
		t.Fatalf("Get returned nil for id=%q", created.ID)
	}
	if fetched.Title != "hello" || fetched.Body != "world" {
		t.Errorf("round-trip mismatch: got title=%q body=%q", fetched.Title, fetched.Body)
	}
}

// TestStore_UpdateStatus_RaceProtection is the CRITICAL regression test
// for the `WHERE status = 'pending'` guard in UpdateStatus. Two goroutines
// racing to transition the same pending notification must produce exactly
// ONE winner — the loser must get (nil, nil), not an error. This is the
// invariant that makes callback delivery fire exactly once even when the
// same user taps "approve" on two devices simultaneously.
func TestStore_UpdateStatus_RaceProtection(t *testing.T) {
	pool := getTestPool(t)
	t.Cleanup(func() { truncateAll(t, pool) })

	store := NewStore(pool)
	ctx := context.Background()

	created, err := store.Add(ctx, &model.Notification{
		Title: "race me",
		Body:  "only one should win",
	})
	if err != nil {
		t.Fatalf("Add: %v", err)
	}

	// Two goroutines racing on the same row. We use a sync.WaitGroup +
	// a start barrier (a buffered channel acting as a latch) so both
	// calls hit the DB as close to simultaneously as the scheduler
	// allows. The race protection lives in the SQL, not in Go, so
	// success here means the DB is doing its job.
	var (
		wg      sync.WaitGroup
		barrier = make(chan struct{})
		results [2]*model.Notification
		errs    [2]error
		actions = []string{"approve", "reject"}
	)
	wg.Add(2)
	for i := 0; i < 2; i++ {
		i := i
		go func() {
			defer wg.Done()
			<-barrier
			results[i], errs[i] = store.UpdateStatus(ctx, created.ID, model.StatusActioned, &actions[i])
		}()
	}
	close(barrier)
	wg.Wait()

	// Neither call should error.
	for i, err := range errs {
		if err != nil {
			t.Errorf("goroutine %d: unexpected error: %v", i, err)
		}
	}

	// Exactly one should return a non-nil notification.
	nonNil := 0
	for _, r := range results {
		if r != nil {
			nonNil++
		}
	}
	if nonNil != 1 {
		t.Fatalf("expected exactly 1 winner, got %d", nonNil)
	}

	// A third call after the race must also return (nil, nil) — the row
	// is no longer pending, so the WHERE clause filters it out.
	third, err := store.UpdateStatus(ctx, created.ID, model.StatusActioned, &actions[0])
	if err != nil {
		t.Errorf("third call errored: %v", err)
	}
	if third != nil {
		t.Errorf("third call should return nil, got %+v", third)
	}
}

// TestStore_ExpireOverdue verifies the expiry sweeper:
//   - pending rows whose expires_at has passed get flipped to expired
//     and returned by the call;
//   - pending rows without expires_at are left alone;
//   - already-actioned rows are left alone even if expires_at has passed.
//
// The test inserts 3 notifications covering these cases and asserts the
// sweeper touches exactly the one it should.
func TestStore_ExpireOverdue(t *testing.T) {
	pool := getTestPool(t)
	t.Cleanup(func() { truncateAll(t, pool) })

	store := NewStore(pool)
	ctx := context.Background()

	past := time.Now().Add(-1 * time.Hour)

	// (1) pending + expired — should get swept.
	expiredTime := past
	target, err := store.Add(ctx, &model.Notification{
		Title:     "expire me",
		Body:      "overdue",
		ExpiresAt: &expiredTime,
	})
	if err != nil {
		t.Fatalf("Add expired: %v", err)
	}

	// (2) pending + no expiry — should be left alone.
	permanent, err := store.Add(ctx, &model.Notification{
		Title: "permanent",
		Body:  "no ttl",
	})
	if err != nil {
		t.Fatalf("Add permanent: %v", err)
	}

	// (3) actioned + expired — should also be left alone because the
	// sweeper only touches status='pending' rows.
	actionedExpired, err := store.Add(ctx, &model.Notification{
		Title:     "actioned already",
		Body:      "do not touch",
		ExpiresAt: &expiredTime,
	})
	if err != nil {
		t.Fatalf("Add actionedExpired: %v", err)
	}
	action := "ok"
	if _, err := store.UpdateStatus(ctx, actionedExpired.ID, model.StatusActioned, &action); err != nil {
		t.Fatalf("UpdateStatus: %v", err)
	}

	expired, err := store.ExpireOverdue(ctx)
	if err != nil {
		t.Fatalf("ExpireOverdue: %v", err)
	}

	// Exactly one row should have been swept — the target.
	if len(expired) != 1 {
		t.Fatalf("expected 1 expired row, got %d: %+v", len(expired), expired)
	}
	if expired[0].ID != target.ID {
		t.Errorf("expired wrong row: want %q, got %q", target.ID, expired[0].ID)
	}
	if expired[0].Status != model.StatusExpired {
		t.Errorf("swept row status: want expired, got %q", expired[0].Status)
	}

	// Verify the permanent row is untouched.
	stillPermanent, err := store.Get(ctx, permanent.ID)
	if err != nil {
		t.Fatalf("Get permanent: %v", err)
	}
	if stillPermanent.Status != model.StatusPending {
		t.Errorf("permanent row got touched: status=%q", stillPermanent.Status)
	}
}

// TestStore_ListSince verifies the cursor semantics of ListSince:
// only rows with created_at strictly greater than the cursor are
// returned, ordered ASCending so the client can pick the last row's
// created_at as its next cursor. This is the contract the WS replay
// protocol depends on.
func TestStore_ListSince(t *testing.T) {
	pool := getTestPool(t)
	t.Cleanup(func() { truncateAll(t, pool) })

	store := NewStore(pool)
	ctx := context.Background()

	// Insert 3 notifications and pin their created_at to known
	// timestamps via raw SQL. Doing it this way (instead of time.Sleep
	// between Add calls) makes the test deterministic and fast.
	base := time.Now().UTC().Truncate(time.Second)
	for i, title := range []string{"first", "second", "third"} {
		n, err := store.Add(ctx, &model.Notification{Title: title, Body: "b"})
		if err != nil {
			t.Fatalf("Add %s: %v", title, err)
		}
		ts := base.Add(time.Duration(i) * time.Minute)
		if _, err := pool.Exec(ctx,
			"UPDATE notifications SET created_at = $1 WHERE id = $2",
			ts, n.ID); err != nil {
			t.Fatalf("pin created_at: %v", err)
		}
	}

	// Cursor between the first and second rows. Should return
	// second + third, in that order.
	cursor := base.Add(30 * time.Second)
	rows, err := store.ListSince(ctx, cursor, 10)
	if err != nil {
		t.Fatalf("ListSince: %v", err)
	}
	if len(rows) != 2 {
		t.Fatalf("expected 2 rows after cursor, got %d: %+v", len(rows), rows)
	}
	if rows[0].Title != "second" || rows[1].Title != "third" {
		t.Errorf("ascending order broken: got [%q, %q]", rows[0].Title, rows[1].Title)
	}

	// Cursor at or after the last row — should return empty.
	future := base.Add(10 * time.Minute)
	emptyRows, err := store.ListSince(ctx, future, 10)
	if err != nil {
		t.Fatalf("ListSince future: %v", err)
	}
	if len(emptyRows) != 0 {
		t.Errorf("expected 0 rows past the last notification, got %d", len(emptyRows))
	}
}
