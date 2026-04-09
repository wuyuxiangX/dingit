import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dingit_shared/dingit_shared.dart';

import '../../../../app/locale/locale_context_ext.dart';
import '../../../../app/theme/theme_context_ext.dart';
import '../../../../core/utils/date_formatter.dart';
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

  // Filter labels are resolved lazily against the active locale so they
  // update when the user switches languages.
  Map<String?, String> _filters(BuildContext context) {
    final l10n = context.l10n;
    return <String?, String>{
      null: l10n.historyFilterAll,
      'actioned': l10n.historyFilterActioned,
      'dismissed': l10n.historyFilterDismissed,
      'expired': l10n.historyFilterExpired,
    };
  }

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
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surfaceContainer,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          color: colors.onSurface,
          onPressed: () => context.pop(),
        ),
        title: Text(
          context.l10n.historyTitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // -- Filter chips --
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                for (final entry in _filters(context).entries)
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
          Expanded(child: _buildBody(state)),
        ],
      ),
    );
  }

  Widget _buildBody(HistoryState state) {
    final theme = context.typo;
    final colors = context.colors;
    final palette = context.palette;

    if (state.isLoading && state.items.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
            color: colors.onSurface, strokeWidth: 2),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.alertCircle, size: 40, color: palette.inkFaint),
            const SizedBox(height: 12),
            Text(context.l10n.historyLoadFailed, style: theme.bodyMedium),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => ref.read(historyProvider.notifier).refresh(),
              child: Text(
                context.l10n.historyRetry,
                style: theme.bodyMedium?.copyWith(color: colors.primary),
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
            Icon(LucideIcons.inbox, size: 40, color: palette.inkFaint),
            const SizedBox(height: 12),
            Text(context.l10n.historyEmpty, style: theme.bodyMedium),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: colors.onSurface,
      onRefresh: () => ref.read(historyProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(
                  color: palette.inkFaint,
                  strokeWidth: 2,
                ),
              ),
            );
          }

          final notification = state.items[index];
          final isFirst = index == 0;
          final isLast = index == state.items.length - 1;

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
//
// In both light and dark mode, selected = brand blue (primary), not a
// black/white luminance flip. Flipping by luminance would make the dark-mode
// "selected" chip visually pop harder than the notification cards behind
// it, inverting the intended visual hierarchy.

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
    final colors = context.colors;
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? null
              : [
                  BoxShadow(
                    color: palette.shadow1,
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? colors.onPrimary : colors.onSurfaceVariant,
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
    final theme = context.typo;
    final colors = context.colors;
    final palette = context.palette;
    final statusColor = _statusColor(context, notification.status);

    return Column(
      children: [
        if (isFirst) const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isFirst ? 14 : 0),
              topRight: Radius.circular(isFirst ? 14 : 0),
              bottomLeft: Radius.circular(isLast ? 14 : 0),
              bottomRight: Radius.circular(isLast ? 14 : 0),
            ),
            boxShadow: isFirst
                ? [
                    BoxShadow(
                      color: palette.shadow1,
                      blurRadius: 8,
                      offset: const Offset(0, 1),
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
                                    color: colors.primary,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                formatRelativeTime(notification.timestamp),
                                style: theme.labelSmall,
                              ),
                              if (notification.priority != 'normal') ...[
                                const SizedBox(width: 8),
                                Text(
                                  notification.priority.toUpperCase(),
                                  style: theme.labelSmall?.copyWith(
                                    color: _priorityColor(
                                        context, notification.priority),
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

                    Icon(
                      LucideIcons.chevronRight,
                      size: 16,
                      color: palette.inkFaint,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!isLast)
          Container(
            color: colors.surface,
            padding: const EdgeInsets.only(left: 36),
            child: Divider(
              height: 0.5,
              thickness: 0.5,
              color: colors.outlineVariant,
            ),
          ),
      ],
    );
  }

  Color _statusColor(BuildContext context, NotificationStatus status) {
    final colors = context.colors;
    final palette = context.palette;
    return switch (status) {
      NotificationStatus.pending => colors.primary,
      NotificationStatus.actioned => palette.success,
      NotificationStatus.dismissed => palette.inkFaint,
      NotificationStatus.expired => palette.warning,
    };
  }

  Color _priorityColor(BuildContext context, String priority) {
    final colors = context.colors;
    final palette = context.palette;
    return switch (priority) {
      'urgent' => colors.error,
      'high' => palette.warning,
      _ => palette.inkFaint,
    };
  }
}
