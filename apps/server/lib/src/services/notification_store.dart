import 'package:notify_shared/notify_shared.dart';
import 'package:uuid/uuid.dart';

class NotificationStore {
  final Map<String, NotificationModel> _notifications = {};
  final _uuid = const Uuid();

  NotificationModel add({
    required String title,
    required String body,
    required String source,
    List<NotificationAction> actions = const [],
    String? callbackUrl,
    Map<String, dynamic>? metadata,
  }) {
    final id = 'ntf_${_uuid.v4().substring(0, 8)}';
    final notification = NotificationModel(
      id: id,
      title: title,
      body: body,
      timestamp: DateTime.now().toUtc(),
      source: source,
      actions: actions,
      callbackUrl: callbackUrl,
      metadata: metadata,
    );
    _notifications[id] = notification;
    return notification;
  }

  NotificationModel? get(String id) => _notifications[id];

  List<NotificationModel> list({
    NotificationStatus? status,
    int limit = 50,
    int offset = 0,
  }) {
    var items = _notifications.values.toList();
    if (status != null) {
      items = items.where((n) => n.status == status).toList();
    }
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (offset >= items.length) return [];
    return items.skip(offset).take(limit).toList();
  }

  int count({NotificationStatus? status}) {
    if (status == null) return _notifications.length;
    return _notifications.values.where((n) => n.status == status).length;
  }

  NotificationModel? updateStatus(
    String id,
    NotificationStatus status, {
    String? actionedValue,
  }) {
    final existing = _notifications[id];
    if (existing == null) return null;
    final updated = existing.copyWith(
      status: status,
      actionedAt: status == NotificationStatus.actioned ? DateTime.now().toUtc() : null,
      actionedValue: actionedValue,
    );
    _notifications[id] = updated;
    return updated;
  }

  void removeExpired(Duration maxAge) {
    final cutoff = DateTime.now().toUtc().subtract(maxAge);
    _notifications.removeWhere((_, n) => n.timestamp.isBefore(cutoff));
  }
}
