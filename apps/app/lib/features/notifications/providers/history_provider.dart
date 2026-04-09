import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dingit_shared/dingit_shared.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/notification_cache.dart';
import 'notifications_provider.dart';

class HistoryState {
  final List<NotificationModel> items;
  final int total;
  final int page;
  final int totalPages;
  final bool isLoading;
  final bool isLoadingMore;
  final String? statusFilter;
  final String? error;

  const HistoryState({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.totalPages = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.statusFilter,
    this.error,
  });

  bool get hasMore => page < totalPages;

  HistoryState copyWith({
    List<NotificationModel>? items,
    int? total,
    int? page,
    int? totalPages,
    bool? isLoading,
    bool? isLoadingMore,
    String? Function()? statusFilter,
    String? Function()? error,
  }) {
    return HistoryState(
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      statusFilter: statusFilter != null ? statusFilter() : this.statusFilter,
      error: error != null ? error() : this.error,
    );
  }
}

final historyProvider =
    NotifierProvider<HistoryNotifier, HistoryState>(HistoryNotifier.new);

class HistoryNotifier extends Notifier<HistoryState> {
  NotificationCache get _cache => ref.read(notificationCacheProvider);

  @override
  HistoryState build() {
    _loadFromCache();
    return const HistoryState();
  }

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> _loadFromCache() async {
    final cached = await _cache.loadHistory();
    if (cached.isNotEmpty && state.items.isEmpty) {
      state = state.copyWith(items: cached);
    }
  }

  Future<void> fetch({String? status}) async {
    state = state.copyWith(
      isLoading: true,
      error: () => null,
      statusFilter: () => status,
    );

    try {
      final result = await _api.getNotifications(
        status: status,
        page: 1,
        pageSize: 20,
      );
      state = state.copyWith(
        items: result.items,
        total: result.total,
        page: result.page,
        totalPages: result.totalPages,
        isLoading: false,
      );
      _cache.saveHistory(result.items);
    } catch (e) {
      debugPrint('[History] fetch error: $e');
      state = state.copyWith(
        isLoading: false,
        error: () => e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.page + 1;
      final result = await _api.getNotifications(
        status: state.statusFilter,
        page: nextPage,
        pageSize: 20,
      );
      state = state.copyWith(
        items: [...state.items, ...result.items],
        total: result.total,
        page: result.page,
        totalPages: result.totalPages,
        isLoadingMore: false,
      );
      _cache.saveHistory(state.items);
    } catch (e) {
      debugPrint('[History] loadMore error: $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> refresh() async {
    await fetch(status: state.statusFilter);
  }

  void setFilter(String? status) {
    fetch(status: status);
  }

  /// Drop every cached history item and the persisted SharedPreferences
  /// cache entry. This is a *local-only* clear — the server keeps the
  /// notifications, so the next `refresh()` repopulates the list.
  /// Pending notifications and the last-sync timestamp are left alone.
  Future<void> clearLocal() async {
    state = const HistoryState();
    await _cache.clearHistory();
  }
}
