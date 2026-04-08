# === Build stage ===
FROM golang:1.25-alpine AS builder

WORKDIR /build

# Cache dependencies
COPY go.mod go.sum ./
RUN go mod download

# Build static binary
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o dingit-server .

# === Runtime stage ===
FROM alpine:3.21

RUN apk add --no-cache ca-certificates tzdata \
    && adduser -D -u 1000 dingit

WORKDIR /app
COPY --from=builder /build/dingit-server /usr/local/bin/dingit-server
COPY --from=builder /build/configs/production.yaml configs/production.yaml

EXPOSE 8080
USER dingit

ENTRYPOINT ["/usr/local/bin/dingit-server"]
