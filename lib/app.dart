import 'package:flutter/material.dart';

import 'l10n/generated/app_localizations.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

/// Root widget for TileMate.
///
/// Owns the currently selected locale. `_locale` starts at [initialLocale]
/// (Phase 6: Arabic is the app's default/primary language, deliberately
/// *not* the device's system locale) and is only ever changed by the
/// in-app language switcher. This selection is intentionally in-memory
/// only and resets back to [initialLocale] on next launch — see
/// docs/I18N_PLAN.md.
class MyApp extends StatefulWidget {
  const MyApp({super.key, this.initialLocale = const Locale('ar')});

  /// The locale the app starts in. Defaults to Arabic. Overridable so
  /// tests can start directly in a given language without first driving
  /// the language-switcher UI.
  final Locale initialLocale;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
  }

  void _setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: HomeScreen(onLocaleChanged: _setLocale),
    );
  }
}
