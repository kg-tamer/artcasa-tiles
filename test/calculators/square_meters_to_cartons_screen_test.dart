// End-to-end check that the screen's stateful wiring (controllers, live
// recalculation, pallet breakdown, clear button) matches the pure
// calculation logic already covered by square_meters_to_cartons_calculator_test.dart.
//
// Pinned to English (initialLocale: 'en') since Phase 6 made Arabic the
// app's default -- these tests exercise validation/calculation wiring, not
// language-specific wording, and English keeps the existing assertions
// unchanged. See test/widget_test.dart and test/l10n/ for Arabic-default
// and language-switching coverage.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tilemate/app.dart';

Future<void> _enterText(
  WidgetTester tester,
  String label,
  String text,
) async {
  await tester.enterText(find.widgetWithText(TextFormField, label), text);
  await tester.pump();
}

void main() {
  testWidgets(
    'Filling in Calculator 1 shows a live result matching the spec example',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp(initialLocale: Locale('en')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('m² → Cartons'));
      await tester.pumpAndSettle();

      // No result before any required input has been entered.
      expect(find.text('Result'), findsNothing);

      await _enterText(tester, 'Area needed (m²)', '100');
      await _enterText(tester, 'Tile length (cm)', '60');
      await _enterText(tester, 'Tile width (cm)', '60');
      await _enterText(tester, 'Tiles per carton', '4');
      await tester.pumpAndSettle();

      // 100m², 60x60cm tile, 4/carton, no waste -> 70 required cartons.
      expect(find.text('Result'), findsOneWidget);
      expect(find.text('70'), findsOneWidget);
      expect(find.text('0.36 m²'), findsOneWidget); // tile area
      expect(find.text('1.44 m²'), findsOneWidget); // carton area
      expect(find.text('100.80 m²'), findsOneWidget); // delivered area
      expect(find.text('Full pallets'), findsNothing); // no pallet size yet

      // Adding pallet info reveals the pallet breakdown rows (70 ~/ 40 = 1,
      // 70 % 40 = 30).
      await _enterText(tester, 'Cartons per pallet (optional)', '40');
      await tester.pumpAndSettle();
      expect(find.text('Full pallets'), findsOneWidget);
      expect(find.text('Extra cartons'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);

      await tester.ensureVisible(find.text('Clear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(find.text('Result'), findsNothing);
      expect(find.text('70'), findsNothing);
    },
  );

  testWidgets('Invalid required input shows a friendly validation message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(initialLocale: Locale('en')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('m² → Cartons'));
    await tester.pumpAndSettle();

    await _enterText(tester, 'Area needed (m²)', '0');
    await tester.pumpAndSettle();

    expect(find.text('Enter a number greater than 0'), findsOneWidget);
    expect(find.text('Result'), findsNothing);
  });

  testWidgets('An empty required field shows the required-field message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(initialLocale: Locale('en')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('m² → Cartons'));
    await tester.pumpAndSettle();

    // Type then delete, so the field has genuinely been touched (required
    // for AutovalidateMode.onUserInteraction to validate it at all) but
    // ends up empty rather than merely invalid.
    await _enterText(tester, 'Area needed (m²)', '5');
    await _enterText(tester, 'Area needed (m²)', '');
    await tester.pumpAndSettle();

    expect(find.text('This field is required'), findsOneWidget);
    expect(find.text('Result'), findsNothing);
  });

  testWidgets(
    'Copying the result reflects the current values, not a stale snapshot',
    (WidgetTester tester) async {
      final copiedTexts = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<Object?, Object?>;
            copiedTexts.add(args['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(const MyApp(initialLocale: Locale('en')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('m² → Cartons'));
      await tester.pumpAndSettle();

      await _enterText(tester, 'Area needed (m²)', '100');
      await _enterText(tester, 'Tile length (cm)', '60');
      await _enterText(tester, 'Tile width (cm)', '60');
      await _enterText(tester, 'Tiles per carton', '4');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Copy result'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy result'));
      await tester.pumpAndSettle();

      expect(copiedTexts, hasLength(1));
      final firstCopy = copiedTexts.single;
      // App name, calculator type, and every main input must be present,
      // not just the final number.
      expect(firstCopy, contains('ArtCasa Tiles'));
      expect(firstCopy, contains('m² → Cartons'));
      expect(firstCopy, contains('Tile length (cm): 60'));
      expect(firstCopy, contains('Tile width (cm): 60'));
      expect(firstCopy, contains('Tiles per carton: 4'));
      expect(firstCopy, contains('Required cartons: 70'));

      // Change a field after the first copy, then copy again — the second
      // copy must reflect the new result, not repeat the first snapshot.
      await _enterText(tester, 'Area needed (m²)', '200');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Copy result'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy result'));
      await tester.pumpAndSettle();

      expect(copiedTexts, hasLength(2));
      final secondCopy = copiedTexts.last;
      expect(secondCopy, isNot(equals(firstCopy)));
      expect(secondCopy, contains('Required cartons: 139'));
    },
  );
}
