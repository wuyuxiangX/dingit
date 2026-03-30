import 'dart:io';

import 'package:args/command_runner.dart';

import '../config.dart';

class ConfigCommand extends Command {
  @override
  final name = 'config';

  @override
  final description = 'Configure CLI settings';

  ConfigCommand() {
    argParser
      ..addOption('server', help: 'Set server URL')
      ..addOption('source', help: 'Set default source name')
      ..addFlag('show',
          help: 'Show current config', negatable: false);
  }

  @override
  Future<void> run() async {
    final config = CliConfig.load();
    final show = argResults!['show'] as bool;

    if (show) {
      stdout.writeln('Current config:');
      stdout.writeln('  server_url: ${config.serverUrl}');
      stdout.writeln('  default_source: ${config.defaultSource}');
      return;
    }

    final server = argResults!['server'] as String?;
    final source = argResults!['source'] as String?;

    if (server == null && source == null) {
      stdout.writeln('Use --server or --source to set config, or --show to view.');
      return;
    }

    final updated = CliConfig(
      serverUrl: server ?? config.serverUrl,
      defaultSource: source ?? config.defaultSource,
    );
    updated.save();
    stdout.writeln('Config saved.');
  }
}
