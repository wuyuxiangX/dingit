/// Build-time configuration for default server endpoints.
///
/// The defaults point at `localhost` over plaintext because the app is
/// almost always run against a locally-hosted dingit server during
/// development. Production builds should set these via
/// `--dart-define=API_URL=https://…` at build time, which the main
/// `Makefile` enforces. If you ship a production build without setting
/// `API_URL`, the user will see "无法连接服务器" on first run — that's
/// by design, we do not want a production app quietly talking to a
/// non-existent localhost server.
abstract final class EnvConfig {
  static const wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://localhost:8080/ws',
  );

  static const apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8080',
  );

  static const apiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: '',
  );
}
