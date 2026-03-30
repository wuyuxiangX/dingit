.PHONY: setup codegen dev-server dev-app test format analyze clean build-cli build-server

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

build-server:
	cd apps/server && go build -o dingit-server .

build-cli:
	cd apps/cli && go build -o dingit .

clean:
	melos clean
	cd apps/app && flutter clean
	rm -f apps/server/dingit-server
	rm -f apps/cli/dingit
