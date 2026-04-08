package middleware

import (
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/time/rate"

	"github.com/dingit-me/server/internal/config"
)

type keyLimiter struct {
	limiter  *rate.Limiter
	lastSeen time.Time
}

func RateLimit(cfg config.RateLimitConfig) gin.HandlerFunc {
	var mu sync.Mutex
	limiters := make(map[string]*keyLimiter)

	// Cleanup stale limiters every 5 minutes
	go func() {
		for {
			time.Sleep(5 * time.Minute)
			mu.Lock()
			for key, kl := range limiters {
				if time.Since(kl.lastSeen) > 10*time.Minute {
					delete(limiters, key)
				}
			}
			mu.Unlock()
		}
	}()

	getLimiter := func(key string) *rate.Limiter {
		mu.Lock()
		defer mu.Unlock()

		if kl, ok := limiters[key]; ok {
			kl.lastSeen = time.Now()
			return kl.limiter
		}

		l := rate.NewLimiter(rate.Limit(cfg.RequestsPerSec), cfg.BurstSize)
		limiters[key] = &keyLimiter{limiter: l, lastSeen: time.Now()}
		return l
	}

	return func(c *gin.Context) {
		apiKeyID, exists := c.Get("api_key_id")
		if !exists {
			// No API key = unauthenticated path (health, ws), skip rate limiting
			c.Next()
			return
		}

		limiter := getLimiter(apiKeyID.(string))

		// Set rate limit headers on all responses
		c.Header("X-RateLimit-Limit", fmt.Sprintf("%.0f", cfg.RequestsPerSec))
		c.Header("X-RateLimit-Burst", fmt.Sprintf("%d", cfg.BurstSize))

		if !limiter.Allow() {
			c.Header("Retry-After", "1")
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"code":    12001,
				"message": "rate limit exceeded",
			})
			return
		}

		c.Next()
	}
}
