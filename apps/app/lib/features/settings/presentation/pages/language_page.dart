import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/locale/locale_context_ext.dart';
import '../../../../app/locale/locale_provider.dart';
import '../../../../app/theme/theme_context_ext.dart';
import '../widgets/settings_tile.dart';

/// `/settings/language` — three-option locale picker pushed from the
/// main Settings page. Same push-and-pop pattern as `AppearancePage`:
/// tap a row, the `LocaleNotifier` state is updated, and the page pops
/// back to Settings immediately.
class LanguagePage extends ConsumerWidget {
  const LanguagePage({super.key});

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
          l10n.settingsSectionLanguage,
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
              _LocaleTile(
                icon: LucideIcons.smartphone,
                label: l10n.settingsLanguageAuto,
                locale: null,
              ),
              const SettingsTileDivider(),
              _LocaleTile(
                icon: LucideIcons.globe,
                label: l10n.settingsLanguageEnglish,
                locale: const Locale('en'),
              ),
              const SettingsTileDivider(),
              _LocaleTile(
                icon: LucideIcons.languages,
                label: l10n.settingsLanguageChinese,
                locale: const Locale('zh'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocaleTile extends ConsumerWidget {
  final IconData icon;
  final String label;
  /// `null` means "follow system" (Auto).
  final Locale? locale;

  const _LocaleTile({
    required this.icon,
    required this.label,
    required this.locale,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider);
    final selected = current == locale;
    final colors = context.colors;
    return SettingsActionTile(
      icon: icon,
      label: label,
      onTap: () {
        ref.read(localeProvider.notifier).set(locale);
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
