import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dingit_shared/dingit_shared.dart';

import '../../../../app/theme/app_colors.dart';
import '../../providers/history_provider.dart';

class NotificationHistoryPage extends ConsumerStatefulWidget {
  const NotificationHistoryPage({super.key});

  @override
  ConsumerState<NotificationHistoryPage> createState() =>
      _NotificationHistoryPageState();
}

class _NotificationHistoryPageState
    extends ConsumerState<NotificationHistoryPage> {
  final _scrollController = ScrollController();

  static const _filters = <String?, String>{
    null: 'All',
    'actioned': 'Actioned',
    'dismissed': 'Dismissed',
    'expired': 'Expired',
  };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(historyProvider.notifier).fetch();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      ref.read(historyProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyProvider);
    final theme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.paperWarm,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          color: AppColors.ink,
          onPressed: () => context.pop(),
        ),
        title: Text(
          'History',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // -- Filter chips --
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                for (final entry in _filters.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: entry.value,
                      selected: state.statusFilter == entry.key,
                      onTap: () => ref
                          .read(historyProvider.notifier)
                          .setFilter(entry.key),
                    ),
                  ),
              ],
            ),
          ),

          // -- List --
          Expanded(child: _buildBody(state, theme)),
        ],
      ),
    );
  }

  Widget _buildBody(HistoryState state, TextTheme theme) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.ink, strokeWidth: 2),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.alertCircle, size: 40, color: AppColors.inkFaint),
            const SizedBox(height: 12),
            Text('Failed to load', style: theme.bodyMedium),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => ref.read(historyProvider.notifier).refresh(),
              child: Text(
                'Tap to retry',
                style: theme.bodyMedium?.copyWith(color: AppColors.accent),
              ),
            ),
          ],
        ),
      );
    }

    if (state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.inbox, size: 40, color: AppColors.inkFaint),
            const SizedBox(height: 12),
            Text('No history yet', style: theme.bodyMedium),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.ink,
      onRefresh: () => ref.read(historyProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.inkFaint,
                  strokeWidth: 2,
                ),
              ),
            );
          }

          final notification = state.items[index];
          final isFirst = index == 0;
          final isLast =
              index == state.items.length - 1 || state.isLoadingMore && index == state.items.length - 1;

          return _HistoryTile(
            notification: notification,
            isFirst: isFirst,
            isLast: isLast,
            onTap: () => context.push(
              '/notification/${notification.id}',
              extra: notification,
            ),
          );
        },
      ),
    );
  }
}

// -- Filter chip --

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? null
              : const [
                  BoxShadow(
                    color: AppColors.shadow1,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.paper : AppColors.inkMuted,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

// -- History tile --

class _HistoryTile extends StatelessWidget {
  final NotificationModel notification;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _HistoryTile({
    required this.notification,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final statusColor = _statusColor(notification.status);

    return Column(
      children: [
        if (isFirst)
          const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isFirst ? 14 : 0),
              topRight: Radius.circular(isFirst ? 14 : 0),
              bottomLeft: Radius.circular(isLast ? 14 : 0),
              bottomRight: Radius.circular(isLast ? 14 : 0),
            ),
            boxShadow: isFirst
                ? const [
                    BoxShadow(
                      color: AppColors.shadow1,
                      blurRadius: 8,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isFirst ? 14 : 0),
                topRight: Radius.circular(isFirst ? 14 : 0),
                bottomLeft: Radius.circular(isLast ? 14 : 0),
                bottomRight: Radius.circular(isLast ? 14 : 0),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    // Status dot
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.title,
                            style: theme.titleLarge?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (notification.source.isNotEmpty) ...[
                                Text(
                                  notification.source,
                                  style: theme.labelSmall?.copyWith(
                                    color: AppColors.accent,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                _formatRelative(notification.timestamp),
                                style: theme.labelSmall,
                              ),
                              if (notification.priority != 'normal') ...[
                                const SizedBox(width: 8),
                                Text(
                                  notification.priority.toUpperCase(),
                                  style: theme.labelSmall?.copyWith(
                                    color: _priorityColor(notification.priority),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Icon(
                      LucideIcons.chevronRight,
                      size: 16,
                      color: AppColors.inkFaint,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!isLast)
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.only(left: 36),
            child: const Divider(
              height: 0.5,
              thickness: 0.5,
              color: AppColors.divider,
            ),
          ),
      ],
    );
  }

  Color _statusColor(NotificationStatus status) {
    return switch (status) {
      NotificationStatus.pending => AppColors.accent,
      NotificationStatus.actioned => AppColors.success,
      NotificationStatus.dismissed => AppColors.inkFaint,
      NotificationStatus.expired => AppColors.warning,
    };
  }

  Color _priorityColor(String priority) {
    return switch (priority) {
      'urgent' => AppColors.destructive,
      'high' => AppColors.warning,
      _ => AppColors.inkFaint,
    };
  }

  String _formatRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }
}
