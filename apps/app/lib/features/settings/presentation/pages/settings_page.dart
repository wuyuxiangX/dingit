import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/locale/locale_context_ext.dart';
import '../../../../app/locale/locale_provider.dart';
import '../../../../app/theme/theme_context_ext.dart';
import '../../../../app/theme/theme_mode_provider.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../notifications/providers/notifications_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/settings_tile.dart';

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
  _TestResult? _testResult;

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
    final result = _testResult;
    if (result != null) {
      return _StatusBadge(
        key: ValueKey(result.isSuccess ? 'ok' : 'fail'),
        result: result,
      );
    }
    return Icon(
      LucideIcons.chevronRight,
      key: const ValueKey('chev'),
      size: 16,
      color: context.palette.inkFaint,
    );
  }

  Future<void> _save() async {
    final serverUrl = _serverUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    try {
      await ref.read(settingsProvider.notifier).saveAll(
            serverUrl: serverUrl,
            apiKey: apiKey,
          );

      final wsClient = ref.read(wsClientProvider);
      final settings = ref.read(settingsProvider);
      await wsClient.reconnectWithUrl(settings.wsUrl, newApiKey: settings.apiKey);

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.settingsSaveFailed(e.toString()),
              style: settingsLabelStyle(context)
                  .copyWith(color: context.colors.onError),
            ),
            backgroundColor: context.colors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
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
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          // ── Server section ──────────────────────────────────
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

          // ── Authentication section ──────────────────────────
          SettingsSectionTitle(l10n.settingsSectionAuth),
          SettingsCard(
            children: [
              _TextFieldTile(
                label: l10n.settingsAuthApiKey,
                controller: _apiKeyController,
                placeholder: l10n.settingsAuthApiKeyPlaceholder,
                obscureText: _obscureApiKey,
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _obscureApiKey = !_obscureApiKey),
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

          const SizedBox(height: 32),

          // ── Appearance ──────────────────────────────────────
          // Tap → push /settings/appearance sub-page. Current value is shown
          // in the trailing slot so the tile reads e.g. "Appearance   Dark ›"
          // — same pattern as iOS Settings > Display & Brightness.
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
            ],
          ),

          const SizedBox(height: 16),

          // ── Language ────────────────────────────────────────
          SettingsCard(
            children: [
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

          const SizedBox(height: 32),

          // ── Save ────────────────────────────────────────────
          SettingsCard(
            children: [
              SettingsActionTile(
                icon: LucideIcons.check,
                label: l10n.settingsSave,
                onTap: _save,
                iconColor: colors.primary,
                labelColor: colors.primary,
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
                suffixIcon: suffixIcon,
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 24,
                  minHeight: 24,
                ),
              ),
            ),
          ),
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
