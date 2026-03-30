import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_action.freezed.dart';
part 'notification_action.g.dart';

@freezed
abstract class NotificationAction with _$NotificationAction {
  const factory NotificationAction({
    required String label,
    required String value,
    @JsonKey(name: 'color_hex') String? colorHex,
    String? icon,
    @Default(false) bool destructive,
  }) = _NotificationAction;

  factory NotificationAction.fromJson(Map<String, dynamic> json) =>
      _$NotificationActionFromJson(json);
}
