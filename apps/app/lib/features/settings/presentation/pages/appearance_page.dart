import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/locale/locale_context_ext.dart';
import '../../../../app/theme/theme_context_ext.dart';
import '../../../../app/theme/theme_mode_provider.dart';
import '../widgets/settings_tile.dart';

/// `/settings/appearance` — three-option picker pushed from the main
/// Settings page. Mirrors the iOS Settings > Display & Brightness
/// navigation pattern: a full-screen sub-page with a back chevron, a
/// grouped-list card, and radio-style selection that pops back the
/// moment the user taps a row.
class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;

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
          l10n.settingsSectionAppearance,
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
          SettingsCard(
            children: [
              _ThemeModeTile(
                icon: LucideIcons.smartphone,
                label: l10n.settingsAppearanceAuto,
                mode: ThemeMode.system,
              ),
              const SettingsTileDivider(),
              _ThemeModeTile(
                icon: LucideIcons.sun,
                label: l10n.settingsAppearanceLight,
                mode: ThemeMode.light,
              ),
              const SettingsTileDivider(),
              _ThemeModeTile(
                icon: LucideIcons.moon,
                label: l10n.settingsAppearanceDark,
                mode: ThemeMode.dark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeModeTile extends ConsumerWidget {
  final IconData icon;
  final String label;
  final ThemeMode mode;

  const _ThemeModeTile({
    required this.icon,
    required this.label,
    required this.mode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);
    final selected = current == mode;
    final colors = context.colors;
    return SettingsActionTile(
      icon: icon,
      label: label,
      onTap: () {
        ref.read(themeModeProvider.notifier).set(mode);
        context.pop();
      },
      iconColor: selected ? colors.primary : colors.onSurface,
      labelColor: selected ? colors.primary : colors.onSurface,
      trailing: selected
          ? Icon(
              LucideIcons.check,
              size: 16,
              color: colors.primary,
            )
          : const SizedBox.shrink(),
    );
  }
}
