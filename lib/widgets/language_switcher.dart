import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

/// A simple app-bar language picker. Selection lives only in memory for the
/// current session; see [MyApp] (app.dart) for where the choice is applied.
class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key, required this.onLocaleChanged});

  final ValueChanged<Locale> onLocaleChanged;

  String _nativeName(AppLocalizations l10n, String languageCode) {
    switch (languageCode) {
      case 'ar':
        return l10n.languageNameArabic;
      case 'he':
        return l10n.languageNameHebrew;
      case 'en':
      default:
        return l10n.languageNameEnglish;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentLanguageCode = Localizations.localeOf(context).languageCode;

    return PopupMenuButton<Locale>(
      tooltip: l10n.languageSwitcherTooltip,
      icon: const Icon(Icons.language),
      onSelected: onLocaleChanged,
      itemBuilder: (context) {
        return AppLocalizations.supportedLocales.map((locale) {
          final isSelected = locale.languageCode == currentLanguageCode;
          return PopupMenuItem<Locale>(
            value: locale,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Text(_nativeName(l10n, locale.languageCode)),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}
