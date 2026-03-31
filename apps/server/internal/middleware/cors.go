package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/dingit-me/server/internal/config"
)

func CORS(cfg config.CORSConfig) gin.HandlerFunc {
	allowAll := len(cfg.AllowedOrigins) == 0
	if !allowAll {
		for _, o := range cfg.AllowedOrigins {
			if o == "*" {
				allowAll = true
				break
			}
		}
	}

	originSet := make(map[string]bool, len(cfg.AllowedOrigins))
	for _, o := range cfg.AllowedOrigins {
		originSet[o] = true
	}

	return func(c *gin.Context) {
		reqOrigin := c.GetHeader("Origin")

		if allowAll {
			c.Header("Access-Control-Allow-Origin", "*")
		} else if originSet[reqOrigin] {
			c.Header("Access-Control-Allow-Origin", reqOrigin)
			c.Header("Vary", "Origin")
		}

		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-API-Key")

		if c.Request.Method == "OPTIONS" {
			c.Header("Access-Control-Max-Age", "86400")
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}
