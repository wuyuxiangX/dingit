.PHONY: dev build test lint vet clean

# Development with hot-reload (requires: go install github.com/air-verse/air@latest)
dev:
	air

# Build binary
build:
	go build -o bin/dingit-server .

# Run directly
run:
	go run .

# Run tests
test:
	go test ./... -v

# Lint (requires: go install golang.org/x/lint/golint@latest)
lint:
	golangci-lint run ./...

# Vet
vet:
	go vet ./...

# Clean build artifacts
clean:
	rm -rf bin/ tmp/
