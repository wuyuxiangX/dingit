import 'dart:io';

import 'package:yaml/yaml.dart';

class CliConfig {
  final String serverUrl;
  final String defaultSource;

  CliConfig({
    required this.serverUrl,
    required this.defaultSource,
  });

  static final _configPath = '${Platform.environment['HOME']}/.notify-hub.yaml';

  static CliConfig load() {
    final file = File(_configPath);
    if (file.existsSync()) {
      try {
        final yaml = loadYaml(file.readAsStringSync()) as Map?;
        return CliConfig(
          serverUrl: (yaml?['server_url'] as String?) ?? 'http://localhost:8080',
          defaultSource: (yaml?['default_source'] as String?) ?? 'cli',
        );
      } catch (_) {}
    }
    return CliConfig(serverUrl: 'http://localhost:8080', defaultSource: 'cli');
  }

  void save() {
    final content = '''server_url: $serverUrl
default_source: $defaultSource
''';
    File(_configPath).writeAsStringSync(content);
  }
}
