package metrics

import (
	"context"
	"errors"
	"testing"

	"github.com/prometheus/client_golang/prometheus"
	dto "github.com/prometheus/client_model/go"
)

// fakeHub implements WSHub for unit tests without pulling in ws.Hub's
// gorilla/websocket dependency.
type fakeHub struct{ n int }

func (f *fakeHub) ConnectedClients() int { return f.n }

// TestWSCollectorEmitsConnectedClients verifies the custom collector
// reads the hub's live value on each Collect call.
func TestWSCollectorEmitsConnectedClients(t *testing.T) {
	hub := &fakeHub{n: 7}
	c := &wsCollector{hub: hub}

	ch := make(chan prometheus.Metric, 1)
	c.Collect(ch)
	close(ch)

	got := <-ch
	if got == nil {
		t.Fatalf("wsCollector.Collect emitted no metrics")
	}

	pb := &dto.Metric{}
	if err := got.Write(pb); err != nil {
		t.Fatalf("metric.Write: %v", err)
	}
	if pb.Gauge == nil || pb.Gauge.Value == nil {
		t.Fatalf("expected gauge value, got %+v", pb)
	}
	if v := *pb.Gauge.Value; v != 7 {
		t.Fatalf("expected gauge=7, got %v", v)
	}

	// Flip the live value and re-collect — must reflect the update
	// because the collector reads at scrape time, not at register time.
	hub.n = 42
	ch2 := make(chan prometheus.Metric, 1)
	c.Collect(ch2)
	close(ch2)
	got2 := <-ch2
	pb2 := &dto.Metric{}
	_ = got2.Write(pb2)
	if v := *pb2.Gauge.Value; v != 42 {
		t.Fatalf("expected gauge=42 after hub update, got %v", v)
	}
}

// TestNotifCollectorEmitsAllStatuses verifies the notifications collector
// emits exactly one sample per status label, with values pulled from the
// injected StatusCountFunc.
func TestNotifCollectorEmitsAllStatuses(t *testing.T) {
	// The stub returns a distinct count per status so the test can
	// assert that labels are threaded through correctly.
	counts := map[string]int{
		"pending":   3,
		"actioned":  5,
		"dismissed": 2,
		"expired":   1,
	}
	c := &notifCollector{
		count: func(_ context.Context, status string) (int, error) {
			n, ok := counts[status]
			if !ok {
				return 0, errors.New("unknown status")
			}
			return n, nil
		},
	}

	ch := make(chan prometheus.Metric, len(notificationStatusLabels))
	c.Collect(ch)
	close(ch)

	got := map[string]float64{}
	for m := range ch {
		pb := &dto.Metric{}
		if err := m.Write(pb); err != nil {
			t.Fatalf("metric.Write: %v", err)
		}
		var status string
		for _, lp := range pb.Label {
			if lp.GetName() == "status" {
				status = lp.GetValue()
				break
			}
		}
		got[status] = *pb.Gauge.Value
	}

	for status, want := range counts {
		if got[status] != float64(want) {
			t.Errorf("status=%q: want %v, got %v", status, want, got[status])
		}
	}
	if len(got) != len(counts) {
		t.Errorf("expected %d samples, got %d: %v", len(counts), len(got), got)
	}
}

// TestNotifCollectorSkipsErroringBucket verifies that an error from the
// count function for one status doesn't abort the whole scrape — other
// statuses are still reported.
func TestNotifCollectorSkipsErroringBucket(t *testing.T) {
	c := &notifCollector{
		count: func(_ context.Context, status string) (int, error) {
			if status == "actioned" {
				return 0, errors.New("db down")
			}
			return 1, nil
		},
	}

	ch := make(chan prometheus.Metric, len(notificationStatusLabels))
	c.Collect(ch)
	close(ch)

	emitted := map[string]bool{}
	for m := range ch {
		pb := &dto.Metric{}
		_ = m.Write(pb)
		for _, lp := range pb.Label {
			if lp.GetName() == "status" {
				emitted[lp.GetValue()] = true
			}
		}
	}

	if emitted["actioned"] {
		t.Errorf("actioned bucket should have been skipped on error")
	}
	for _, s := range []string{"pending", "dismissed", "expired"} {
		if !emitted[s] {
			t.Errorf("expected bucket %q to be emitted despite actioned error", s)
		}
	}
}
