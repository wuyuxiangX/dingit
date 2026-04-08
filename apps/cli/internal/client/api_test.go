package client

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestNew(t *testing.T) {
	c := New("http://localhost:8080", "dingit_test")

	if c.BaseURL != "http://localhost:8080" {
		t.Errorf("expected base URL http://localhost:8080, got %s", c.BaseURL)
	}
	if c.APIKey != "dingit_test" {
		t.Errorf("expected API key dingit_test, got %s", c.APIKey)
	}
	if c.httpClient == nil {
		t.Error("expected http client to be initialized")
	}
}

func TestClient_Send(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			t.Errorf("expected POST, got %s", r.Method)
		}
		if r.URL.Path != "/api/notifications" {
			t.Errorf("expected /api/notifications, got %s", r.URL.Path)
		}
		if r.Header.Get("Authorization") != "Bearer test_key" {
			t.Errorf("expected Bearer test_key, got %s", r.Header.Get("Authorization"))
		}
		if r.Header.Get("Content-Type") != "application/json" {
			t.Errorf("expected Content-Type application/json, got %s", r.Header.Get("Content-Type"))
		}

		w.WriteHeader(201)
		json.NewEncoder(w).Encode(map[string]string{
			"id":        "ntf_abc123",
			"status":    "pending",
			"timestamp": "2026-01-01T00:00:00Z",
		})
	}))
	defer server.Close()

	c := New(server.URL, "test_key")
	resp, err := c.Send(&SendRequest{
		Title:  "Test",
		Body:   "Hello",
		Source: "test",
	})

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.ID != "ntf_abc123" {
		t.Errorf("expected ID ntf_abc123, got %s", resp.ID)
	}
	if resp.Status != "pending" {
		t.Errorf("expected status pending, got %s", resp.Status)
	}
}

func TestClient_Send_ServerError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(400)
		w.Write([]byte(`{"error":"title required"}`))
	}))
	defer server.Close()

	c := New(server.URL, "key")
	_, err := c.Send(&SendRequest{})

	if err == nil {
		t.Error("expected error for 400 response")
	}
}

func TestClient_List(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "GET" {
			t.Errorf("expected GET, got %s", r.Method)
		}
		if r.URL.Query().Get("status") != "pending" {
			t.Errorf("expected status=pending, got %s", r.URL.Query().Get("status"))
		}
		if r.URL.Query().Get("page") != "1" {
			t.Errorf("expected page=1, got %s", r.URL.Query().Get("page"))
		}

		json.NewEncoder(w).Encode(map[string]any{
			"code": 0,
			"data": map[string]any{
				"items":       []map[string]any{{"id": "ntf_1", "title": "Test"}},
				"total":       1,
				"page":        1,
				"total_pages": 1,
			},
		})
	}))
	defer server.Close()

	c := New(server.URL, "key")
	result, err := c.List("pending", "", 1, 20)

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result.Total != 1 {
		t.Errorf("expected total 1, got %d", result.Total)
	}
	if len(result.Items) != 1 {
		t.Errorf("expected 1 item, got %d", len(result.Items))
	}
}

func TestClient_Health(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/health" {
			t.Errorf("expected /health, got %s", r.URL.Path)
		}
		json.NewEncoder(w).Encode(map[string]any{
			"status":         "ok",
			"uptime_seconds": 42,
		})
	}))
	defer server.Close()

	c := New(server.URL, "")
	result, err := c.Health()

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result["status"] != "ok" {
		t.Errorf("expected status ok, got %v", result["status"])
	}
}

func TestClient_Unauthorized_NoKey(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(401)
	}))
	defer server.Close()

	c := New(server.URL, "")
	_, err := c.Send(&SendRequest{Title: "Test", Body: "Body"})

	if err == nil {
		t.Error("expected error for 401")
	}
}

func TestClient_Unauthorized_BadKey(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(401)
	}))
	defer server.Close()

	c := New(server.URL, "bad_key")
	_, err := c.Send(&SendRequest{Title: "Test", Body: "Body"})

	if err == nil {
		t.Error("expected error for invalid key")
	}
}

func TestClient_Get(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/notifications/ntf_123" {
			t.Errorf("expected /api/notifications/ntf_123, got %s", r.URL.Path)
		}
		json.NewEncoder(w).Encode(map[string]any{
			"id":    "ntf_123",
			"title": "Test",
		})
	}))
	defer server.Close()

	c := New(server.URL, "key")
	result, err := c.Get("ntf_123")

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result["id"] != "ntf_123" {
		t.Errorf("expected id ntf_123, got %v", result["id"])
	}
}

func TestClient_Get_NotFound(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(404)
		w.Write([]byte(`{"error":"not found"}`))
	}))
	defer server.Close()

	c := New(server.URL, "key")
	_, err := c.Get("ntf_nonexistent")

	if err == nil {
		t.Error("expected error for 404")
	}
}
