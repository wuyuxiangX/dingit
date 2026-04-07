import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../notifications/providers/notifications_provider.dart';
import '../../providers/settings_provider.dart';

// -- Shared text styles -------------------------------------------------------

TextStyle _label() => GoogleFonts.plusJakartaSans(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: AppColors.ink,
    );

TextStyle _hint() => GoogleFonts.plusJakartaSans(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: AppColors.inkFaint,
    );

TextStyle _sectionTitle() => GoogleFonts.plusJakartaSans(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: AppColors.inkFaint,
    );

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
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final url = _serverUrlController.text.trim();
      final apiKey = _apiKeyController.text.trim();

      final uri = Uri.parse('$url/health');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      try {
        final request = await client.getUrl(uri);
        if (apiKey.isNotEmpty) {
          request.headers.set('Authorization', 'Bearer $apiKey');
        }
        final response = await request.close();

        if (response.statusCode == 200) {
          setState(() => _testResult = const _TestResult.success());
        } else {
          setState(
            () => _testResult = _TestResult.failure('HTTP ${response.statusCode}'),
          );
        }
      } finally {
        client.close();
      }
    } catch (e) {
      setState(() => _testResult = _TestResult.failure(e.toString()));
    } finally {
      setState(() => _isTesting = false);
    }
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
            content: Text('Save failed: $e', style: _label().copyWith(color: AppColors.paper)),
            backgroundColor: AppColors.destructive,
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

    if (settings.isLoaded && _serverUrlController.text.isEmpty) {
      _serverUrlController.text = settings.serverUrl;
      _apiKeyController.text = settings.apiKey;
    }

    return Scaffold(
      backgroundColor: AppColors.paperWarm,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          color: AppColors.ink,
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          // ── Server section ──────────────────────────────────
          _SectionTitle('SERVER'),
          _Card(
            children: [
              _TextFieldTile(
                label: 'Address',
                controller: _serverUrlController,
                placeholder: 'http://localhost:8080',
                keyboardType: TextInputType.url,
              ),
              const _TileDivider(),
              _ActionTile(
                icon: LucideIcons.activity,
                label: 'Test Connection',
                onTap: _isTesting ? null : _testConnection,
                isLoading: _isTesting,
                trailing: _testResult != null
                    ? _StatusBadge(result: _testResult!)
                    : const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.inkFaint),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Authentication section ──────────────────────────
          _SectionTitle('AUTHENTICATION'),
          _Card(
            children: [
              _TextFieldTile(
                label: 'API Key',
                controller: _apiKeyController,
                placeholder: 'Enter your API key',
                obscureText: _obscureApiKey,
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _obscureApiKey = !_obscureApiKey),
                  child: Icon(
                    _obscureApiKey ? LucideIcons.eyeOff : LucideIcons.eye,
                    size: 17,
                    color: AppColors.inkFaint,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Your API key is encrypted and stored securely on this device.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.inkFaint,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ── Save ────────────────────────────────────────────
          _Card(
            children: [
              _ActionTile(
                icon: LucideIcons.check,
                label: 'Save Settings',
                onTap: _save,
                iconColor: AppColors.accent,
                labelColor: AppColors.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -- Section title ------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(title, style: _sectionTitle()),
    );
  }
}

// -- Grouped card container ---------------------------------------------------

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow1,
            blurRadius: 8,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

// -- Indented divider inside card ---------------------------------------------

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 16),
      child: Divider(height: 0.5, thickness: 0.5, color: AppColors.divider),
    );
  }
}

// -- Text field tile ----------------------------------------------------------

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
            child: Text(label, style: _label()),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              obscureText: obscureText,
              autocorrect: false,
              enableSuggestions: false,
              style: _label(),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: _hint(),
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

// -- Tappable action tile -----------------------------------------------------

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final Widget? trailing;
  final Color? iconColor;
  final Color? labelColor;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.trailing,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final ic = iconColor ?? AppColors.ink;
    final lc = labelColor ?? AppColors.ink;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
          child: Row(
            children: [
              if (isLoading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ic),
                )
              else
                Icon(icon, size: 18, color: ic),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: lc,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

// -- Test result model --------------------------------------------------------

class _TestResult {
  final bool isSuccess;
  final String? error;

  const _TestResult.success()
      : isSuccess = true,
        error = null;

  const _TestResult.failure(this.error) : isSuccess = false;
}

// -- Status badge -------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final _TestResult result;
  const _StatusBadge({required this.result});

  @override
  Widget build(BuildContext context) {
    final isOk = result.isSuccess;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isOk ? AppColors.success : AppColors.destructive).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isOk ? 'Connected' : 'Failed',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isOk ? AppColors.success : AppColors.destructive,
        ),
      ),
    );
  }
}
