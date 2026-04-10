package middleware

import (
	"net/url"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	"github.com/dingit-me/server/internal/pkg/logger"
)

// redactQuery returns an encoded query string with any sensitiveQueryKeys
// removed, so secrets passed through the URL never land in logs.
func redactQuery(q url.Values) string {
	for k := range sensitiveQueryKeys {
		q.Del(k)
	}
	return q.Encode()
}

// sensitiveQueryKeys are stripped from the logged query string. Keep this
// in sync with any secret-bearing query parameter the server accepts.
var sensitiveQueryKeys = map[string]bool{
	"api_key": true,
}

func RequestLog() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path

		c.Next()

		latency := time.Since(start)
		status := c.Writer.Status()

		fields := []zap.Field{
			zap.Int("status", status),
			zap.String("method", c.Request.Method),
			zap.String("path", path),
			zap.String("ip", c.ClientIP()),
			zap.Duration("latency", latency),
		}

		if c.Request.URL.RawQuery != "" {
			redacted := redactQuery(c.Request.URL.Query())
			if redacted != "" {
				fields = append(fields, zap.String("query", redacted))
			}
		}

		switch {
		case status >= 500:
			logger.Error("request", fields...)
		case status >= 400:
			logger.Warn("request", fields...)
		default:
			logger.Info("request", fields...)
		}
	}
}
