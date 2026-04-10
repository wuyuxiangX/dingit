# === Build stage ===
FROM golang:1.25-alpine AS builder

WORKDIR /build

# Cache dependencies
COPY go.mod go.sum ./
RUN go mod download

# Build metadata (WYX-411) — passed in via `docker build --build-arg …`.
# Defaults to "dev" so plain `docker build .` still produces a working
# binary with a recognisable sentinel. The release workflow overrides
# all three from the git ref / commit / timestamp.
ARG VERSION=dev
ARG COMMIT_SHA=dev
ARG BUILT_AT=dev

# Build static binary. -ldflags -X injects the buildinfo variables at
# link time — must stay in sync with the Makefile's BUILD_LDFLAGS_SERVER
# and the release.yml build-args.
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build \
        -ldflags="-s -w \
            -X github.com/dingit-me/server/internal/buildinfo.Version=${VERSION} \
            -X github.com/dingit-me/server/internal/buildinfo.CommitSHA=${COMMIT_SHA} \
            -X github.com/dingit-me/server/internal/buildinfo.BuiltAt=${BUILT_AT}" \
        -o dingit-server .

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
