// Phase 7 added ArtCasa Tiles branding (brand name + a logo image on the
// home screen). Phase 9 replaced that logo image with a native Flutter
// brand header (small icon mark + real Text for the brand name and its
// Arabic subtitle) after the logo/icon PNG assets turned out to have a
// checkerboard pattern baked into their pixels instead of real
// transparency, which broke the dark-mode look -- see
// docs/UI_DESIGN_PLAN.md. These tests confirm the brand name and icon
// mark still show correctly (now as native text, not image text), that
// both calculators and the language switcher still work, and that
// nothing regressed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tilemate/app.dart';

void main() {
  testWidgets(
    'ArtCasa Tiles brand header (icon + native text) shows on the home '
    'screen in Arabic (default)',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Matches twice: the app bar title and the home screen's own brand
      // header both show the brand name as real text.
      expect(find.text('ArtCasa Tiles'), findsNWidgets(2));
      expect(find.byType(Image), findsOneWidget); // ArtCasa Tiles icon mark
      expect(find.text('للبلاط والسيراميك'), findsOneWidget); // brand subtitle
      expect(find.text('حاسبة البلاط'), findsOneWidget); // purpose tagline
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ArtCasa Tiles brand header persists after switching to English or '
    'Hebrew, and the language switcher still works',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.language));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      // The brand name and its Arabic subtitle are fixed brand identity,
      // kept identical across locales -- unaffected by which language is
      // selected.
      expect(find.text('ArtCasa Tiles'), findsNWidgets(2));
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('للبلاط والسيراميك'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.language));
      await tester.pumpAndSettle();
      await tester.tap(find.text('עברית'));
      await tester.pumpAndSettle();

      expect(find.text('ArtCasa Tiles'), findsNWidgets(2));
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('للبلاط والسيراميك'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Both calculators still open and work with the new brand header in place',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('متر لكراتين'));
      await tester.pumpAndSettle();
      expect(find.text('أدخل الأرقام'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('كراتين لمتر'));
      await tester.pumpAndSettle();
      expect(find.text('أدخل الأرقام'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
