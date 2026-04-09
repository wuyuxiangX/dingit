// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Dingit';

  @override
  String get notificationConnectionConnected => '实时更新';

  @override
  String get notificationConnectionConnecting => '连接中…';

  @override
  String get notificationConnectionDisconnected => '已断开';

  @override
  String get notificationDismissedPill => '已取消';

  @override
  String get notificationUndoAction => '撤销';

  @override
  String get notificationEmptyTitle => '已清空';

  @override
  String get notificationEmptyBody => '所有通知都处理完了';

  @override
  String get notificationEmptyViewHistory => '查看历史';

  @override
  String get actionBarDismiss => '忽略';

  @override
  String get actionBarNext => '下一条';

  @override
  String get historyTitle => '历史';

  @override
  String get historyFilterAll => '全部';

  @override
  String get historyFilterActioned => '已处理';

  @override
  String get historyFilterDismissed => '已忽略';

  @override
  String get historyFilterExpired => '已过期';

  @override
  String get historyLoadFailed => '加载失败';

  @override
  String get historyRetry => '轻触重试';

  @override
  String get historyEmpty => '暂无历史';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsDone => '完成';

  @override
  String get commonCancel => '取消';

  @override
  String get settingsSectionServer => '服务器';

  @override
  String get settingsServerAddress => '地址';

  @override
  String get settingsServerPlaceholder => 'http://localhost:8080';

  @override
  String get settingsServerTestConnection => '测试连接';

  @override
  String get settingsServerConnected => '已连接';

  @override
  String get settingsServerFailed => '失败';

  @override
  String get settingsSectionAuth => '认证';

  @override
  String get settingsAuthApiKey => 'API Key';

  @override
  String get settingsAuthApiKeyPlaceholder => '输入 API Key';

  @override
  String get settingsAuthApiKeyHint => 'API Key 已在本设备加密存储。';

  @override
  String get settingsSectionPreferences => '偏好';

  @override
  String get settingsSectionAppearance => '外观';

  @override
  String get settingsAppearanceAuto => '跟随系统';

  @override
  String get settingsAppearanceLight => '浅色';

  @override
  String get settingsAppearanceDark => '深色';

  @override
  String get settingsSectionLanguage => '语言';

  @override
  String get settingsLanguageAuto => '跟随系统';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageChinese => '简体中文';

  @override
  String get settingsSectionNotifications => '通知管理';

  @override
  String get settingsNotificationsClearHistory => '清除历史';

  @override
  String get settingsNotificationsResetBadge => '清除角标';

  @override
  String get settingsClearHistoryDialogTitle => '清除历史？';

  @override
  String get settingsClearHistoryDialogMessage => '这将删除此设备上缓存的所有通知历史，且无法撤销。';

  @override
  String get settingsClearHistoryDialogConfirm => '清除';

  @override
  String get settingsClearHistoryDone => '历史已清除';

  @override
  String get settingsResetBadgeDone => '角标已清除';

  @override
  String get settingsSectionAbout => '关于';

  @override
  String get settingsAboutVersion => '版本';

  @override
  String get settingsAboutSourceCode => '源代码';

  @override
  String get settingsAboutLicenses => '开源许可';

  @override
  String get settingsSignOut => '退出登录';

  @override
  String get settingsSignOutDialogTitle => '退出登录？';

  @override
  String get settingsSignOutDialogMessage =>
      '这将清除服务器地址和 API Key 并断开连接。重新连接时需要重新输入。';

  @override
  String get settingsSignOutDialogConfirm => '退出';

  @override
  String get settingsSignedOut => '已退出';

  @override
  String settingsSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get detailNotFound => '通知不存在';

  @override
  String get detailMetadataSection => '元数据';

  @override
  String get detailActionTaken => '已处理';

  @override
  String detailActionedAt(String date) {
    return '处理时间 $date';
  }

  @override
  String get detailStatusPending => '待处理';

  @override
  String get detailStatusActioned => '已处理';

  @override
  String get detailStatusDismissed => '已忽略';

  @override
  String get detailStatusExpired => '已过期';

  @override
  String get detailPriorityUrgent => '紧急';

  @override
  String get detailPriorityHigh => '高';

  @override
  String get detailPriorityLow => '低';

  @override
  String get detailPriorityNormal => '普通';
}
