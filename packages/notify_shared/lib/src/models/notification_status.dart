import 'package:json_annotation/json_annotation.dart';

enum NotificationStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('actioned')
  actioned,
  @JsonValue('dismissed')
  dismissed,
  @JsonValue('expired')
  expired,
}
