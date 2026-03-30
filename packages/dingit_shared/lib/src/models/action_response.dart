import 'package:freezed_annotation/freezed_annotation.dart';

part 'action_response.freezed.dart';
part 'action_response.g.dart';

@freezed
abstract class ActionResponse with _$ActionResponse {
  const factory ActionResponse({
    @JsonKey(name: 'notification_id') required String notificationId,
    required String action,
    required DateTime timestamp,
    String? source,
  }) = _ActionResponse;

  factory ActionResponse.fromJson(Map<String, dynamic> json) =>
      _$ActionResponseFromJson(json);
}
