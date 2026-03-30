import 'dart:io';

import 'package:args/command_runner.dart';

import '../api_client.dart';
import '../config.dart';

class ListCommand extends Command {
  @override
  final name = 'list';

  @override
  final description = 'List notifications';

  ListCommand() {
    argParser
      ..addOption('status',
          allowed: ['pending', 'actioned', 'dismissed', 'expired'],
          help: 'Filter by status')
      ..addOption('limit', defaultsTo: '20', help: 'Max results')
      ..addOption('server', help: 'Server URL override');
  }

  @override
  Future<void> run() async {
    final config = CliConfig.load();
    final serverUrl = argResults!['server'] as String? ?? config.serverUrl;
    final client = ApiClient(baseUrl: serverUrl);

    try {
      final data = await client.listNotifications(
        status: argResults!['status'] as String?,
        limit: int.parse(argResults!['limit'] as String),
      );

      final notifications = data['notifications'] as List;
      final total = data['total'] as int;

      if (notifications.isEmpty) {
        stdout.writeln('No notifications found.');
        return;
      }

      stdout.writeln('Notifications ($total total):');
      stdout.writeln('${'─' * 60}');

      for (final n in notifications) {
        final status = (n['status'] as String).toUpperCase();
        final id = n['id'] as String;
        final title = n['title'] as String;
        final source = n['source'] as String;
        final timestamp = n['timestamp'] as String;

        stdout.writeln('  [$status] $id');
        stdout.writeln('  $title (from: $source)');
        stdout.writeln('  $timestamp');
        stdout.writeln('');
      }
    } catch (e) {
      stderr.writeln('Error: $e');
      exit(1);
    } finally {
      client.dispose();
    }
  }
}
