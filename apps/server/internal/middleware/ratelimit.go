package middleware

import (
	"context"
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

// RateLimit enforces per-API-key quota on requests that made it past the
// auth middleware. Runs AFTER auth, so it is only meaningful for
// authenticated traffic. For unauthenticated / failing-auth traffic use
// IPRateLimit (below) which sits in front of auth.
func RateLimit(cfg config.RateLimitConfig) gin.HandlerFunc {
	var mu sync.Mutex
	limiters := make(map[string]*keyLimiter)

	// Cleanup stale limiters every 5 minutes. Tied to an application ctx
	// so it exits cleanly on shutdown instead of leaking a goroutine for
	// the life of the process (see main.go wiring).
	startLimiterGC(&mu, limiters, 10*time.Minute)

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
			// No API key = unauthenticated path (health), skip rate limiting
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

// IPRateLimit is a coarse per-client-IP rate limiter that sits in front
// of the API key auth middleware. Its job is to prevent attackers from
// brute-forcing API keys by burning a DB query per attempt.
//
// The limits are intentionally generous (authentic clients never notice)
// but tight enough that an attacker can't pound the auth path at line
// speed. Uses the same x/time/rate primitives as the per-key limiter.
func IPRateLimit(rps float64, burst int) gin.HandlerFunc {
	var mu sync.Mutex
	limiters := make(map[string]*keyLimiter)

	startLimiterGC(&mu, limiters, 10*time.Minute)

	return func(c *gin.Context) {
		ip := c.ClientIP()

		mu.Lock()
		kl, ok := limiters[ip]
		if !ok {
			kl = &keyLimiter{
				limiter:  rate.NewLimiter(rate.Limit(rps), burst),
				lastSeen: time.Now(),
			}
			limiters[ip] = kl
		} else {
			kl.lastSeen = time.Now()
		}
		mu.Unlock()

		if !kl.limiter.Allow() {
			c.Header("Retry-After", "1")
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"code":    12002,
				"message": "too many requests from this address",
			})
			return
		}

		c.Next()
	}
}

// startLimiterGC launches a background goroutine that periodically
// sweeps stale entries out of a limiter map. Previously this loop
// called time.Sleep forever with no way to stop it; now it ties its
// lifetime to a package-level context that main.go cancels on shutdown.
func startLimiterGC(mu *sync.Mutex, limiters map[string]*keyLimiter, stale time.Duration) {
	go func() {
		ticker := time.NewTicker(5 * time.Minute)
		defer ticker.Stop()
		for {
			select {
			case <-gcCtx.Done():
				return
			case <-ticker.C:
				mu.Lock()
				for k, v := range limiters {
					if time.Since(v.lastSeen) > stale {
						delete(limiters, k)
					}
				}
				mu.Unlock()
			}
		}
	}()
}

// gcCtx is the lifetime anchor for limiter-cleanup goroutines. main.go
// calls StopLimiterGC() during shutdown so every cleanup goroutine
// exits instead of leaking past server.Shutdown().
var (
	gcCtx    context.Context
	gcCancel context.CancelFunc
)

func init() {
	gcCtx, gcCancel = context.WithCancel(context.Background())
}

// StopLimiterGC cancels the package-level context used by limiter
// cleanup goroutines. Call from main.go during shutdown.
func StopLimiterGC() {
	gcCancel()
}
