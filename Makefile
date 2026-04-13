.PHONY: setup codegen dev-server dev-app test format analyze check-theme-i18n clean build-cli build-server swagger docs-install docs-dev docs-build docs-start docs-clean

# ── Build metadata (WYX-411) ───────────────────────────────────────────────
# Injected into Go binaries at link time via -ldflags -X so both
# `dingit-server --version` and `dingit --version` print the real release
# tag instead of the "dev" sentinel. These values also flow into
# /api/health/debug's build_info field via the buildinfo package.
#
# Three call sites must stay in sync (change one, change all):
#   1. Makefile                            (this file)
#   2. apps/server/Dockerfile              (ARG + -ldflags)
#   3. .github/workflows/release.yml       (build-args for buildx)
#
# BUILD_VERSION falls back to "dev" when the workspace is outside git
# (e.g. a tarball extract), so the LDFLAGS always produce a valid symbol
# even in untarred sources.
BUILD_VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
BUILD_COMMIT  ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo dev)
BUILD_DATE    ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)

BUILD_LDFLAGS_SERVER := -ldflags "-s -w \
	-X github.com/dingit-me/server/internal/buildinfo.Version=$(BUILD_VERSION) \
	-X github.com/dingit-me/server/internal/buildinfo.CommitSHA=$(BUILD_COMMIT) \
	-X github.com/dingit-me/server/internal/buildinfo.BuiltAt=$(BUILD_DATE)"

BUILD_LDFLAGS_CLI := -ldflags "-s -w \
	-X github.com/dingit-me/cli/internal/buildinfo.Version=$(BUILD_VERSION) \
	-X github.com/dingit-me/cli/internal/buildinfo.CommitSHA=$(BUILD_COMMIT) \
	-X github.com/dingit-me/cli/internal/buildinfo.BuiltAt=$(BUILD_DATE)"

setup:
	dart pub global activate melos
	melos bootstrap
	cd apps/server && go mod tidy
	cd apps/cli && go mod tidy

codegen:
	cd packages/dingit_shared && dart run build_runner build --delete-conflicting-outputs

dev-server:
	cd apps/server && go run .

dev-app:
	cd apps/app && flutter run

dev-app-web:
	cd apps/app && flutter run -d chrome

test:
	melos run test
	cd apps/server && go test ./...
	cd apps/cli && go test ./...

format:
	melos run format

analyze:
	melos run analyze
	cd apps/server && go vet ./...
	cd apps/cli && go vet ./...
	$(MAKE) check-theme-i18n

# Static guard for the Flutter app: no hex color literals outside the token
# layer, no references to the deleted AppColors class, and no hard-coded
# Chinese text outside lib/l10n/. Safe to run in pre-commit or CI.
check-theme-i18n:
	bash apps/app/scripts/check-theme-i18n.sh

build-server:
	cd apps/server && go build $(BUILD_LDFLAGS_SERVER) -o dingit-server .

build-cli:
	cd apps/cli && go build $(BUILD_LDFLAGS_CLI) -o dingit .

swagger:
	cd apps/server && swag init --output internal/docs --parseDependency --parseInternal

clean:
	melos clean
	cd apps/app && flutter clean
	rm -f apps/server/dingit-server
	rm -f apps/cli/dingit

# ── Docs site (apps/docs) ──────────────────────────────────────────────────
# Fumadocs + Next.js 16 + Tailwind v4, deployed to docs.dingit.me.
# Managed from the root via pnpm workspace — never cd into apps/docs to run
# these, always go through the workspace filter so the lockfile stays at root.

docs-install:
	pnpm install

docs-dev:
	pnpm --filter @dingit/docs dev

docs-build:
	pnpm --filter @dingit/docs build

docs-start:
	pnpm --filter @dingit/docs start

docs-clean:
	rm -rf apps/docs/.next apps/docs/.source apps/docs/node_modules
