package client

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
)

type Client struct {
	BaseURL    string
	APIKey     string
	httpClient *http.Client
}

func New(baseURL, apiKey string) *Client {
	return &Client{
		BaseURL:    baseURL,
		APIKey:     apiKey,
		httpClient: &http.Client{},
	}
}

type SendRequest struct {
	Title       string                   `json:"title"`
	Body        string                   `json:"body"`
	Source      string                   `json:"source"`
	Priority    string                   `json:"priority,omitempty"`
	Icon        string                   `json:"icon,omitempty"`
	Actions     []map[string]interface{} `json:"actions,omitempty"`
	CallbackURL string                   `json:"callback_url,omitempty"`
	Metadata    map[string]interface{}   `json:"metadata,omitempty"`
}

type SendResponse struct {
	ID        string `json:"id"`
	Status    string `json:"status"`
	Timestamp string `json:"timestamp"`
}

func (c *Client) Send(req *SendRequest) (*SendResponse, error) {
	body, _ := json.Marshal(req)
	resp, err := c.doRequest("POST", c.BaseURL+"/api/notifications", bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("connection failed: %w", err)
	}
	defer resp.Body.Close()

	data, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 201 {
		return nil, fmt.Errorf("server error (%d): %s", resp.StatusCode, string(data))
	}

	var result SendResponse
	if err := json.Unmarshal(data, &result); err != nil {
		return nil, err
	}
	return &result, nil
}

func (c *Client) List(status string, limit int) ([]map[string]interface{}, int, error) {
	u, _ := url.Parse(c.BaseURL + "/api/notifications")
	q := u.Query()
	if status != "" {
		q.Set("status", status)
	}
	q.Set("limit", fmt.Sprintf("%d", limit))
	u.RawQuery = q.Encode()

	resp, err := c.doRequest("GET", u.String(), nil)
	if err != nil {
		return nil, 0, err
	}
	defer resp.Body.Close()

	data, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 200 {
		return nil, 0, fmt.Errorf("server error (%d): %s", resp.StatusCode, string(data))
	}

	var result struct {
		Notifications []map[string]interface{} `json:"notifications"`
		Total         int                      `json:"total"`
	}
	if err := json.Unmarshal(data, &result); err != nil {
		return nil, 0, err
	}
	return result.Notifications, result.Total, nil
}

func (c *Client) Get(id string) (map[string]interface{}, error) {
	resp, err := c.doRequest("GET", c.BaseURL+"/api/notifications/"+id, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	data, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("not found (%d): %s", resp.StatusCode, string(data))
	}

	var result map[string]interface{}
	if err := json.Unmarshal(data, &result); err != nil {
		return nil, err
	}
	return result, nil
}

func (c *Client) Health() (map[string]interface{}, error) {
	resp, err := c.httpClient.Get(c.BaseURL + "/health")
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	data, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("server error (%d): %s", resp.StatusCode, string(data))
	}

	var result map[string]interface{}
	if err := json.Unmarshal(data, &result); err != nil {
		return nil, err
	}
	return result, nil
}

func (c *Client) doRequest(method, url string, body io.Reader) (*http.Response, error) {
	req, err := http.NewRequest(method, url, body)
	if err != nil {
		return nil, err
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if c.APIKey != "" {
		req.Header.Set("Authorization", "Bearer "+c.APIKey)
	}
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode == http.StatusUnauthorized {
		resp.Body.Close()
		if c.APIKey == "" {
			return nil, fmt.Errorf("authentication required: no API key configured\n\n  Set your key:  dingit config --set-api-key <key>\n  Or export:     DINGIT_API_KEY=<key>")
		}
		return nil, fmt.Errorf("authentication failed: invalid API key")
	}
	return resp, nil
}
