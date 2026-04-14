import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/locale/locale_context_ext.dart';
import '../../../../app/locale/locale_provider.dart';
import '../../../../app/theme/theme_context_ext.dart';
import '../../../../app/theme/theme_mode_provider.dart';
import '../../../../core/push/badge_service.dart';
import '../../../../core/ui/undo_pill.dart';
import '../../../../core/websocket/ws_client.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../notifications/providers/history_provider.dart';
import '../../../notifications/providers/notifications_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/settings_tile.dart';

/// Source code URL shown in the About section.
const _kSourceCodeUrl = 'https://github.com/wuyuxiangX/dingit';

// -- Page ---------------------------------------------------------------------

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _serverUrlController;
  late final TextEditingController _apiKeyController;
  bool _obscureApiKey = true;
  bool _isTesting = false;
  bool _isSaving = false;
  _TestResult? _testResult;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _serverUrlController = TextEditingController();
    _apiKeyController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider);
      _serverUrlController.text = settings.serverUrl;
      _apiKeyController.text = settings.apiKey;
      if (settings.serverUrl.isNotEmpty) {
        _testConnection();
      }
    });

    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _appVersion = '${info.version} (${info.buildNumber})');
    } catch (_) {
      // Non-fatal — the About row will just show an empty value.
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (_isTesting) return;
    setState(() => _isTesting = true);

    _TestResult? nextResult;
    try {
      final url = _serverUrlController.text.trim();
      final apiKey = _apiKeyController.text.trim();

      final uri = Uri.parse('$url/health');
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);

      try {
        final request = await client.getUrl(uri);
        if (apiKey.isNotEmpty) {
          request.headers.set('Authorization', 'Bearer $apiKey');
        }
        final response = await request.close();
        nextResult = response.statusCode == 200
            ? const _TestResult.success()
            : _TestResult.failure('HTTP ${response.statusCode}');
      } finally {
        client.close();
      }
    } catch (e) {
      nextResult = _TestResult.failure(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testResult = nextResult;
        });
      }
    }
  }

  Widget _buildTestTrailing() {
    // Priority: in-flight > result > nothing.
    //
    // We deliberately do NOT fall back to a chevron when idle. The
    // "Test Connection" row is an action, not a navigation row, so a
    // chevron was misleading — and during testing the chevron made it
    // look like nothing was happening on the right side at all (the
    // spinner only appeared on the left, where the activity icon used
    // to be). With this layout the right side either announces
    // progress, the result, or stays empty.
    if (_isTesting) {
      return Text(
        context.l10n.settingsServerTesting,
        key: const ValueKey('testing'),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: context.palette.inkFaint,
        ),
      );
    }
    final result = _testResult;
    if (result != null) {
      return _StatusBadge(
        key: ValueKey(result.isSuccess ? 'ok' : 'fail'),
        result: result,
      );
    }
    return const SizedBox.shrink(key: ValueKey('empty'));
  }

  /// Persist server URL + API key, reconnect the WebSocket, and pop back
  /// to the previous route. This is the action wired to the AppBar
  /// trailing "Done" button — Settings now follows the iOS pattern where
  /// the top-right action saves and closes instead of having a dedicated
  /// Save button at the bottom of the form.
  Future<void> _saveAndClose() async {
    if (_isSaving) return;
    final serverUrl = _serverUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    setState(() => _isSaving = true);
    try {
      await ref.read(settingsProvider.notifier).saveAll(
            serverUrl: serverUrl,
            apiKey: apiKey,
          );

      // Wait until the new WsClient (rebuilt by Riverpod when settings
      // changed) finishes its auto-connect handshake before popping, so
      // the notifications page doesn't see a disconnected→connecting→
      // connected flicker the instant we return. Do NOT call
      // reconnectWithUrl here: that would race against the auto-connect
      // already in flight and the two competing connect() calls cancel
      // each other's channel, producing the very flicker we're trying
      // to fix. 2s is enough for a healthy LAN handshake — if it takes
      // longer, the URL is almost certainly bad and the user is better
      // served by a clear error than by being silently bounced back to
      // a red banner on the notifications page.
      final wsClient = ref.read(wsClientProvider);
      try {
        await _awaitConnected(wsClient.connectionState)
            .timeout(const Duration(seconds: 2));
      } on TimeoutException {
        // Connection didn't come up in time. Keep the user on this
        // page so they can fix the URL/key — popping back to a red
        // banner is technically correct but feels like the save just
        // hung for no reason.
        if (mounted) {
          showUndoPill(
            context,
            message: context.l10n.settingsServerUnreachable,
            icon: LucideIcons.alertCircle,
            iconColor: const Color(0xFFFF6961),
            duration: const Duration(seconds: 3),
          );
        }
        return;
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        // Use the same HUD-style pill as every other Settings toast, with
        // an error icon tinted red so it reads as a failure instead of a
        // confirmation. No undo — the caller can simply press Done again.
        showUndoPill(
          context,
          message: context.l10n.settingsSaveFailed(e.toString()),
          icon: LucideIcons.alertCircle,
          iconColor: const Color(0xFFFF6961),
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Resolve when the WebSocket connection state transitions to
  /// `connected`. If it is already connected, resolves immediately.
  /// Caller is expected to wrap in a `.timeout(...)` for the unreachable
  /// case — this future has no internal deadline.
  Future<void> _awaitConnected(
    ValueNotifier<WsConnectionState> state,
  ) {
    if (state.value == WsConnectionState.connected) {
      return Future.value();
    }
    final completer = Completer<void>();
    void listener() {
      if (state.value == WsConnectionState.connected &&
          !completer.isCompleted) {
        state.removeListener(listener);
        completer.complete();
      }
    }
    state.addListener(listener);
    return completer.future;
  }

  Future<void> _clearHistory() async {
    final l10n = context.l10n;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(l10n.settingsClearHistoryDialogTitle),
        content: Text(l10n.settingsClearHistoryDialogMessage),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.settingsClearHistoryDialogConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(historyProvider.notifier).clearLocal();

    if (!mounted) return;
    showUndoPill(
      context,
      message: l10n.settingsClearHistoryDone,
      icon: LucideIcons.trash2,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _resetBadge() async {
    await BadgeService.clear();
    if (!mounted) return;
    showUndoPill(
      context,
      message: context.l10n.settingsResetBadgeDone,
      icon: LucideIcons.bellOff,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _signOut() async {
    final l10n = context.l10n;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(l10n.settingsSignOutDialogTitle),
        content: Text(l10n.settingsSignOutDialogMessage),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.settingsSignOutDialogConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Tear the session down. Clearing the settings state causes
    // `wsClientProvider` to rebuild and dispose the existing WsClient;
    // the new client sees an empty serverUrl and skips auto-connect
    // (see the guard in notifications_provider.dart). We still nuke the
    // cache up front so the UI flashes empty immediately instead of
    // waiting for the providers to rebuild.
    await ref.read(notificationCacheProvider).clear();
    await ref.read(settingsProvider.notifier).signOut();

    if (!mounted) return;
    _serverUrlController.clear();
    _apiKeyController.clear();
    setState(() => _testResult = null);
    showUndoPill(
      context,
      message: l10n.settingsSignedOut,
      icon: LucideIcons.logOut,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _openSourceCode() async {
    final uri = Uri.parse(_kSourceCodeUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openLicensePage() {
    showLicensePage(
      context: context,
      applicationName: context.l10n.appTitle,
      applicationVersion: _appVersion,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final colors = context.colors;
    final l10n = context.l10n;

    if (settings.isLoaded && _serverUrlController.text.isEmpty) {
      _serverUrlController.text = settings.serverUrl;
      _apiKeyController.text = settings.apiKey;
    }

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
          l10n.settingsTitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveAndClose,
            style: TextButton.styleFrom(
              foregroundColor: colors.primary,
              textStyle: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: _isSaving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(colors.primary),
                    ),
                  )
                : Text(l10n.settingsDone),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          // ── Server ──────────────────────────────────────────
          SettingsSectionTitle(l10n.settingsSectionServer),
          SettingsCard(
            children: [
              _TextFieldTile(
                label: l10n.settingsServerAddress,
                controller: _serverUrlController,
                placeholder: l10n.settingsServerPlaceholder,
                keyboardType: TextInputType.url,
              ),
              const SettingsTileDivider(),
              SettingsActionTile(
                icon: LucideIcons.activity,
                label: l10n.settingsServerTestConnection,
                onTap: _isTesting ? null : _testConnection,
                isLoading: _isTesting,
                trailing: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: _buildTestTrailing(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Authentication ──────────────────────────────────
          SettingsSectionTitle(l10n.settingsSectionAuth),
          SettingsCard(
            children: [
              _TextFieldTile(
                label: l10n.settingsAuthApiKey,
                controller: _apiKeyController,
                placeholder: l10n.settingsAuthApiKeyPlaceholder,
                obscureText: _obscureApiKey,
                suffixIcon: GestureDetector(
                  onTap: () =>
                      setState(() => _obscureApiKey = !_obscureApiKey),
                  child: Icon(
                    _obscureApiKey ? LucideIcons.eyeOff : LucideIcons.eye,
                    size: 17,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              l10n.settingsAuthApiKeyHint,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: context.palette.inkFaint,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Preferences ────────────────────────────────────
          // Appearance and Language share a single grouped card so the
          // section reads as one semantic unit ("things about how the
          // app looks and sounds").
          SettingsSectionTitle(l10n.settingsSectionPreferences),
          SettingsCard(
            children: [
              SettingsActionTile(
                icon: LucideIcons.palette,
                label: l10n.settingsSectionAppearance,
                onTap: () => context.push('/settings/appearance'),
                trailing: SettingsDisclosureValue(
                  _themeModeLabel(l10n, themeMode),
                ),
              ),
              const SettingsTileDivider(),
              SettingsActionTile(
                icon: LucideIcons.globe,
                label: l10n.settingsSectionLanguage,
                onTap: () => context.push('/settings/language'),
                trailing: SettingsDisclosureValue(
                  _localeLabel(l10n, locale),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Notifications management ───────────────────────
          SettingsSectionTitle(l10n.settingsSectionNotifications),
          SettingsCard(
            children: [
              SettingsActionTile(
                icon: LucideIcons.trash2,
                label: l10n.settingsNotificationsClearHistory,
                onTap: _clearHistory,
              ),
              const SettingsTileDivider(),
              SettingsActionTile(
                icon: LucideIcons.bellOff,
                label: l10n.settingsNotificationsResetBadge,
                onTap: _resetBadge,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── About ───────────────────────────────────────────
          SettingsSectionTitle(l10n.settingsSectionAbout),
          SettingsCard(
            children: [
              SettingsActionTile(
                icon: LucideIcons.info,
                label: l10n.settingsAboutVersion,
                onTap: null,
                trailing: Text(
                  _appVersion,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: context.palette.inkFaint,
                  ),
                ),
              ),
              const SettingsTileDivider(),
              SettingsActionTile(
                icon: LucideIcons.github,
                label: l10n.settingsAboutSourceCode,
                onTap: _openSourceCode,
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: context.palette.inkFaint,
                ),
              ),
              const SettingsTileDivider(),
              SettingsActionTile(
                icon: LucideIcons.fileText,
                label: l10n.settingsAboutLicenses,
                onTap: _openLicensePage,
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: context.palette.inkFaint,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Sign out ────────────────────────────────────────
          // Standalone destructive card at the very bottom, mirroring
          // the iOS Settings convention where "Sign Out" lives on its
          // own row away from any specific account field.
          SettingsCard(
            children: [
              SettingsActionTile(
                icon: LucideIcons.logOut,
                label: l10n.settingsSignOut,
                onTap: _signOut,
                iconColor: colors.error,
                labelColor: colors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Label helpers ───────────────────────────────────────────────────────────

String _themeModeLabel(AppLocalizations l10n, ThemeMode mode) {
  return switch (mode) {
    ThemeMode.system => l10n.settingsAppearanceAuto,
    ThemeMode.light => l10n.settingsAppearanceLight,
    ThemeMode.dark => l10n.settingsAppearanceDark,
  };
}

String _localeLabel(AppLocalizations l10n, Locale? locale) {
  if (locale == null) return l10n.settingsLanguageAuto;
  return switch (locale.languageCode) {
    'en' => l10n.settingsLanguageEnglish,
    'zh' => l10n.settingsLanguageChinese,
    _ => l10n.settingsLanguageAuto,
  };
}

// ── Text field tile (still private, only used on the main page) ────────────

class _TextFieldTile extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String placeholder;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  const _TextFieldTile({
    required this.label,
    required this.controller,
    required this.placeholder,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: settingsLabelStyle(context)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              obscureText: obscureText,
              autocorrect: false,
              enableSuggestions: false,
              style: settingsLabelStyle(context),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: settingsHintStyle(context),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          // Render the suffix as a sibling of the TextField instead of
          // baking it into InputDecoration.suffixIcon. The decorator's
          // suffixIcon path forces a minimum height/baseline shift that
          // makes the obscured API key text drift out of vertical
          // alignment with the left-side label and pushes its right
          // edge inward, so the field above (without a suffix) and this
          // one no longer line up. As a sibling, the eye icon takes a
          // fixed slot at the right edge of the row and the TextField's
          // baseline matches the URL row exactly.
          if (suffixIcon != null) ...[
            const SizedBox(width: 8),
            suffixIcon!,
          ],
        ],
      ),
    );
  }
}

// ── Test result model + badge ──────────────────────────────────────────────

class _TestResult {
  final bool isSuccess;
  final String? error;

  const _TestResult.success()
      : isSuccess = true,
        error = null;

  const _TestResult.failure(this.error) : isSuccess = false;
}

class _StatusBadge extends StatelessWidget {
  final _TestResult result;
  const _StatusBadge({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isOk = result.isSuccess;
    final color = isOk ? context.palette.success : context.colors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isOk
            ? context.l10n.settingsServerConnected
            : context.l10n.settingsServerFailed,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
