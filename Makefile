.PHONY: setup codegen dev-server dev-app test format analyze clean install-cli build-cli build-server

setup:
	dart pub global activate melos
	melos bootstrap

codegen:
	cd packages/dingit_shared && dart run build_runner build --delete-conflicting-outputs

dev-server:
	cd apps/server && dart run bin/server.dart

dev-app:
	cd apps/app && flutter run

dev-app-web:
	cd apps/app && flutter run -d chrome

test:
	melos run test

format:
	melos run format

analyze:
	melos run analyze

build-server:
	cd apps/server && dart compile exe bin/server.dart -o build/server

build-cli:
	cd apps/cli && dart compile exe bin/notify.dart -o build/notify

install-cli:
	cd apps/cli && dart pub global activate --source path .

clean:
	melos clean
	cd apps/app && flutter clean
