import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/action_response.dart';
import '../models/notification_model.dart';

part 'ws_message.freezed.dart';
part 'ws_message.g.dart';

@Freezed(unionKey: 'type')
sealed class WsMessage with _$WsMessage {
  @FreezedUnionValue('notification.new')
  const factory WsMessage.notificationNew({
    required NotificationModel notification,
  }) = WsNotificationNew;

  @FreezedUnionValue('notification.updated')
  const factory WsMessage.notificationUpdated({
    required NotificationModel notification,
  }) = WsNotificationUpdated;

  @FreezedUnionValue('action.response')
  const factory WsMessage.actionResponse({
    required ActionResponse response,
  }) = WsActionResponse;

  @FreezedUnionValue('sync.full')
  const factory WsMessage.syncFull({
    required List<NotificationModel> notifications,
  }) = WsSyncFull;

  @FreezedUnionValue('ping')
  const factory WsMessage.ping() = WsPing;

  @FreezedUnionValue('pong')
  const factory WsMessage.pong() = WsPong;

  factory WsMessage.fromJson(Map<String, dynamic> json) =>
      _$WsMessageFromJson(json);
}
