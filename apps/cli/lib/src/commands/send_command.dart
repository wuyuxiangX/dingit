import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../api_client.dart';
import '../config.dart';

class SendCommand extends Command {
  @override
  final name = 'send';

  @override
  final description = 'Send a notification to the hub';

  SendCommand() {
    argParser
      ..addOption('title', abbr: 't', help: 'Notification title', mandatory: true)
      ..addOption('body', abbr: 'b', help: 'Notification body', mandatory: true)
      ..addMultiOption('action',
          abbr: 'a',
          help: 'Action button label (can specify multiple)')
      ..addOption('actions-json',
          help: 'Actions as JSON array (advanced)')
      ..addOption('callback', abbr: 'c', help: 'Callback URL for responses')
      ..addOption('source', abbr: 's', help: 'Notification source')
      ..addOption('server', help: 'Server URL override')
      ..addFlag('wait',
          abbr: 'w',
          help: 'Wait for user response (blocks until actioned)',
          negatable: false);
  }

  @override
  Future<void> run() async {
    final config = CliConfig.load();
    final serverUrl = argResults!['server'] as String? ?? config.serverUrl;
    final client = ApiClient(baseUrl: serverUrl);

    final title = argResults!['title'] as String;
    final body = argResults!['body'] as String;
    final source = argResults!['source'] as String? ?? config.defaultSource;
    final callbackUrl = argResults!['callback'] as String?;
    final wait = argResults!['wait'] as bool;

    // Parse actions
    List<Map<String, dynamic>> actions = [];
    final actionsJson = argResults!['actions-json'] as String?;
    final actionLabels = argResults!['action'] as List<String>;

    if (actionsJson != null) {
      actions = (jsonDecode(actionsJson) as List)
          .cast<Map<String, dynamic>>();
    } else if (actionLabels.isNotEmpty) {
      actions = actionLabels.map((label) => {
        'label': label,
        'value': label.toLowerCase().replaceAll(' ', '_'),
      }).toList();
    }

    try {
      final result = await client.sendNotification(
        title: title,
        body: body,
        source: source,
        actions: actions,
        callbackUrl: callbackUrl,
      );

      final id = result['id'] as String;
      stdout.writeln('Notification sent: $id');

      if (wait) {
        stdout.writeln('Waiting for response...');
        await _pollForResponse(client, id);
      }
    } catch (e) {
      stderr.writeln('Error: $e');
      exit(1);
    } finally {
      client.dispose();
    }
  }

  Future<void> _pollForResponse(ApiClient client, String id) async {
    while (true) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final data = await client.getNotification(id);
        final status = data['status'] as String?;
        if (status == 'actioned') {
          final action = data['actioned_value'] as String?;
          stdout.writeln('Response received: $action');
          exit(0);
        } else if (status == 'dismissed' || status == 'expired') {
          stdout.writeln('Notification $status');
          exit(1);
        }
      } catch (e) {
        stderr.writeln('Poll error: $e');
      }
    }
  }
}
