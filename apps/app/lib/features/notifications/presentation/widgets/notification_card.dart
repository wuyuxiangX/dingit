import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dingit_shared/dingit_shared.dart';

import '../../../../app/theme/app_colors.dart';

class NotificationCard extends StatelessWidget {
  final NotificationModel notification;

  const NotificationCard({
    super.key,
    required this.notification,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.shadow2, blurRadius: 30, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.paperWarm,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formatDate(notification.timestamp),
              style: theme.labelMedium?.copyWith(color: AppColors.inkMuted),
            ),
          ),

          const SizedBox(height: 24),

          // Source — small, subtle
          if (notification.source.isNotEmpty) ...[
            Text(
              notification.source.toUpperCase(),
              style: theme.titleSmall?.copyWith(
                letterSpacing: 1.5,
                fontSize: 11,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Title
          Text(
            notification.title,
            style: theme.titleLarge?.copyWith(
              fontSize: 22,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 16),

          // Body — fill available space
          Expanded(
            child: Text(
              notification.body,
              style: theme.bodyLarge?.copyWith(
                height: 1.7,
                fontSize: 15,
              ),
              overflow: TextOverflow.fade,
            ),
          ),

          const SizedBox(height: 16),

          // Bottom arrow
          Align(
            alignment: Alignment.bottomRight,
            child: Icon(
              Icons.arrow_outward_rounded,
              size: 18,
              color: AppColors.inkFaint,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(dateDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(date);
    return DateFormat('MMM d').format(date);
  }
}
