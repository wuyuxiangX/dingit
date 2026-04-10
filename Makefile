.PHONY: setup codegen dev-server dev-app test format analyze check-theme-i18n clean build-cli build-server docs-install docs-dev docs-build docs-start docs-clean

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
	cd apps/server && go build -o dingit-server .

build-cli:
	cd apps/cli && go build -o dingit .

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
