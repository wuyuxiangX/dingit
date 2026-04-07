import 'package:flutter/widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';

const notificationIconMap = <String, IconData>{
  'github': LucideIcons.github,
  'slack': LucideIcons.messageSquare,
  'mail': LucideIcons.mail,
  'alert': LucideIcons.alertTriangle,
  'check': LucideIcons.checkCircle2,
  'deploy': LucideIcons.rocket,
  'ci': LucideIcons.activity,
  'server': LucideIcons.server,
  'database': LucideIcons.database,
  'bug': LucideIcons.bug,
};

IconData resolveNotificationIcon(String iconName) {
  return notificationIconMap[iconName.toLowerCase().trim()] ?? LucideIcons.bell;
}
