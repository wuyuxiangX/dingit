// Package buildinfo exposes version metadata injected at link time via
// -ldflags -X. The default values are "dev" so unlinked binaries (e.g.
// `go run .` in development or `go test`) report a recognisable sentinel
// instead of an empty string.
//
// Three call sites must stay in sync, or a release will ship with "dev"
// values in production:
//
//  1. Makefile  BUILD_LDFLAGS_SERVER
//  2. apps/server/Dockerfile  ARG + go build -ldflags
//  3. .github/workflows/release.yml  docker/build-push-action build-args
//
// See WYX-411 for the rationale.
package buildinfo

// Version is the human-readable release tag (e.g. "v1.1.0"). In
// development or when built without -ldflags it stays "dev".
var Version = "dev"

// CommitSHA is the short git commit the binary was built from. Stays
// "dev" when not linked.
var CommitSHA = "dev"

// BuiltAt is an RFC 3339 timestamp (UTC) captured at build time. Stays
// "dev" when not linked.
var BuiltAt = "dev"

// String returns a compact one-line summary suitable for --version output
// and `/api/health/debug` consumption.
func String() string {
	return Version + " (" + CommitSHA + ", built " + BuiltAt + ")"
}
