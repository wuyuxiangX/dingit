package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"github.com/dingit-me/server/internal/service"
)

func APIKeyAuth(apiKeySvc *service.APIKeyService, skipPaths map[string]bool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if skipPaths[c.Request.URL.Path] {
			c.Next()
			return
		}

		rawKey := extractAPIKey(c.Request)
		if rawKey == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "API key required"})
			return
		}

		apiKey, err := apiKeySvc.ValidateKey(c.Request.Context(), rawKey)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
			return
		}
		if apiKey == nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid API key"})
			return
		}

		c.Set("api_key_id", apiKey.ID)
		c.Next()
	}
}

func extractAPIKey(r *http.Request) string {
	// Try Authorization: Bearer <key>
	if auth := r.Header.Get("Authorization"); auth != "" {
		if strings.HasPrefix(auth, "Bearer ") {
			return strings.TrimPrefix(auth, "Bearer ")
		}
	}
	// Try X-API-Key header
	if key := r.Header.Get("X-API-Key"); key != "" {
		return key
	}
	// WebSocket clients that cannot set headers during upgrade (e.g. browser
	// WebSocket API) can pass the key as a query parameter. Only read this
	// for the /ws path so the key never ends up in request logs for regular
	// HTTP routes.
	if r.URL.Path == "/ws" {
		if key := r.URL.Query().Get("api_key"); key != "" {
			return key
		}
	}
	return ""
}
