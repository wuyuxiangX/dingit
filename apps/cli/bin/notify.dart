import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:notify_cli/src/commands/config_command.dart';
import 'package:notify_cli/src/commands/list_command.dart';
import 'package:notify_cli/src/commands/send_command.dart';
import 'package:notify_cli/src/commands/status_command.dart';

void main(List<String> args) async {
  final runner = CommandRunner<void>(
    'notify',
    'Notify Hub CLI - Send and manage notifications',
  )
    ..addCommand(SendCommand())
    ..addCommand(ListCommand())
    ..addCommand(StatusCommand())
    ..addCommand(ConfigCommand());

  try {
    await runner.run(args);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(64);
  }
}
