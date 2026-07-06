// Smoke tests for the app shell: home screen rendering, the language
// switcher's effect on locale/text direction, and calculator navigation.
//
// Phase 6 made Arabic the app's default language (RTL), selectable away
// from via the language switcher to Hebrew or English (both still RTL/LTR
// as before) -- these tests exercise that default plus every switch
// direction, not just "switch to Arabic" as before Phase 6.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tilemate/app.dart';

void main() {
  testWidgets('App starts in Arabic by default and is RTL', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Matches twice: the app bar title and the home screen's own brand
    // header (Phase 9) both show the brand name as real text.
    expect(find.text('ArtCasa Tiles'), findsNWidgets(2));
    expect(find.text('متر لكراتين'), findsOneWidget);
    expect(find.text('كراتين لمتر'), findsOneWidget);

    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);
  });

  testWidgets('Switching to English updates text and flips layout to LTR', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.language));
    await tester.pumpAndSettle();

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('m² → Cartons'), findsOneWidget);

    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(directionality.textDirection, TextDirection.ltr);
  });

  testWidgets('Switching to Hebrew updates text and flips layout to RTL', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.language));
    await tester.pumpAndSettle();

    await tester.tap(find.text('עברית'));
    await tester.pumpAndSettle();

    expect(find.text('שטח לקרטונים'), findsOneWidget);

    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);
  });

  testWidgets(
    'Tapping the first calculator card opens the real Calculator 1 screen',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('متر لكراتين'));
      await tester.pumpAndSettle();

      expect(find.text('أدخل الأرقام'), findsOneWidget);
      expect(find.text('عدد البلاط في الكرتونة'), findsOneWidget);
    },
  );

  testWidgets(
    'Tapping the second calculator card opens the real Calculator 2 screen',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('كراتين لمتر'));
      await tester.pumpAndSettle();

      expect(find.text('أدخل الأرقام'), findsOneWidget);
      expect(find.text('كراتين إضافية'), findsOneWidget);
      expect(find.text('عدد الباليتات/المشاتيح (اختياري)'), findsOneWidget);
    },
  );

  testWidgets(
    'Reopening a calculator after navigating back starts fresh',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('متر لكراتين'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'المتر المطلوب (م²)'),
        '100',
      );
      await tester.pumpAndSettle();
      expect(find.text('100'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('متر لكراتين'), findsOneWidget); // back on home

      await tester.tap(find.text('متر لكراتين'));
      await tester.pumpAndSettle();

      // A brand-new screen instance with empty controllers, not the
      // previous one still holding '100' and a result.
      expect(find.text('100'), findsNothing);
      expect(find.text('النتيجة'), findsNothing);
    },
  );

  testWidgets(
    'Switching language after visiting a calculator does not break reopening it',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('متر لكراتين'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'المتر المطلوب (م²)'),
        '50',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.language));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('m² → Cartons'));
      await tester.pumpAndSettle();

      // Fresh, correctly localized in English, no crash, and no leftover
      // Arabic-session state (the '50' typed before switching language).
      expect(tester.takeException(), isNull);
      expect(find.text('Enter your numbers'), findsOneWidget);
      expect(find.text('50'), findsNothing);

      final directionality = tester.widget<Directionality>(
        find.byType(Directionality).first,
      );
      expect(directionality.textDirection, TextDirection.ltr);
    },
  );
}
