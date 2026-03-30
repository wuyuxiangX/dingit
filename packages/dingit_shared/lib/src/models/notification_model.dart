import 'package:freezed_annotation/freezed_annotation.dart';

import 'notification_action.dart';
import 'notification_status.dart';

part 'notification_model.freezed.dart';
part 'notification_model.g.dart';

@freezed
abstract class NotificationModel with _$NotificationModel {
  const factory NotificationModel({
    required String id,
    required String title,
    required String body,
    required DateTime timestamp,
    required String source,
    @Default([]) List<NotificationAction> actions,
    @JsonKey(name: 'callback_url') String? callbackUrl,
    @Default(NotificationStatus.pending) NotificationStatus status,
    @JsonKey(name: 'actioned_at') DateTime? actionedAt,
    @JsonKey(name: 'actioned_value') String? actionedValue,
    Map<String, dynamic>? metadata,
  }) = _NotificationModel;

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);
}
