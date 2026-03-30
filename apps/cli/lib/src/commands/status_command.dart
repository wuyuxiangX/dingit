import 'dart:io';

import 'package:args/command_runner.dart';

import '../api_client.dart';
import '../config.dart';

class StatusCommand extends Command {
  @override
  final name = 'status';

  @override
  final description = 'Check notification status or server health';

  StatusCommand() {
    argParser
      ..addOption('id', help: 'Notification ID to check')
      ..addOption('server', help: 'Server URL override');
  }

  @override
  Future<void> run() async {
    final config = CliConfig.load();
    final serverUrl = argResults!['server'] as String? ?? config.serverUrl;
    final client = ApiClient(baseUrl: serverUrl);

    try {
      final id = argResults!['id'] as String?;

      if (id != null) {
        final data = await client.getNotification(id);
        stdout.writeln('Notification: ${data['id']}');
        stdout.writeln('  Title: ${data['title']}');
        stdout.writeln('  Status: ${data['status']}');
        stdout.writeln('  Source: ${data['source']}');
        if (data['actioned_value'] != null) {
          stdout.writeln('  Action: ${data['actioned_value']}');
        }
      } else {
        // Show server health
        final health = await client.health();
        stdout.writeln('Server Status: ${health['status']}');
        stdout.writeln('  Uptime: ${health['uptime_seconds']}s');
        stdout.writeln('  Connected clients: ${health['connected_clients']}');
        stdout.writeln('  Pending notifications: ${health['pending_notifications']}');
      }
    } catch (e) {
      stderr.writeln('Error: $e');
      exit(1);
    } finally {
      client.dispose();
    }
  }
}
