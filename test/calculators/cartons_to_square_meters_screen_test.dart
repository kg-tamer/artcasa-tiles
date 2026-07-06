// End-to-end check that Calculator 2's stateful wiring (controllers, live
// recalculation, extra-cartons/pallets/cartons-per-pallet cross-validation,
// clear button) matches the pure calculation logic already covered by
// cartons_to_square_meters_calculator_test.dart.
//
// Pinned to English (initialLocale: 'en') since Phase 6 made Arabic the
// app's default -- these tests exercise validation/calculation wiring, not
// language-specific wording, and English keeps the existing assertions
// unchanged. See test/widget_test.dart and test/l10n/ for Arabic-default
// and language-switching coverage.

import 'package:flutter/material.dart';
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
    'Filling in Calculator 2 shows a live result matching the spec examples',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp(initialLocale: Locale('en')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cartons → m²'));
      await tester.pumpAndSettle();

      // No result before any required input has been entered.
      expect(find.text('Result'), findsNothing);

      // Manual test example A: 10 cartons, 60x60cm tile, 4/carton.
      await _enterText(tester, 'Tile length (cm)', '60');
      await _enterText(tester, 'Tile width (cm)', '60');
      await _enterText(tester, 'Tiles per carton', '4');
      await _enterText(tester, 'Extra cartons', '10');
      await tester.pumpAndSettle();

      expect(find.text('Result'), findsOneWidget);
      expect(find.text('14.40 m²'), findsOneWidget); // total area (hero)
      expect(find.text('0.36 m²'), findsOneWidget); // tile area
      expect(find.text('1.44 m²'), findsOneWidget); // carton area
      // '10' matches twice: the extra-cartons input field's own text, and
      // the total-cartons result row (find.text also matches EditableText).
      expect(find.text('10'), findsNWidgets(2));
      expect(find.text('40'), findsOneWidget); // total tiles
      // No pallets used yet, so the whole pallet-breakdown block (including
      // the extra-cartons result row) stays hidden.
      expect(find.text('Full pallets'), findsNothing);

      // Manual test example B: 33 cartons + 1 pallet of 40 -> 73 total.
      await _enterText(tester, 'Extra cartons', '33');
      await _enterText(tester, 'Pallets count (optional)', '1');
      await _enterText(tester, 'Cartons per pallet (optional)', '40');
      await tester.pumpAndSettle();

      expect(find.text('105.12 m²'), findsOneWidget); // total area (hero)
      expect(find.text('73'), findsOneWidget); // total cartons
      expect(find.text('Full pallets'), findsOneWidget);
      expect(find.text('Cartons per pallet'), findsOneWidget);
      // 'Extra cartons' matches twice once pallets are in use and extra
      // cartons is > 0: the field's own label, and the result row (which is
      // only shown inside the pallet-breakdown block — see
      // cartons_to_square_meters_screen.dart's _ResultCard).
      expect(find.text('Extra cartons'), findsNWidgets(2));

      await tester.ensureVisible(find.text('Clear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(find.text('Result'), findsNothing);
    },
  );

  testWidgets(
    'Phase 4: calculating from pallets alone (no extra cartons) works',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp(initialLocale: Locale('en')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cartons → m²'));
      await tester.pumpAndSettle();

      // Spec example: extra cartons left empty entirely -- a pure
      // pallets-only order, the scenario Phase 4 exists to support.
      await _enterText(tester, 'Tile length (cm)', '60');
      await _enterText(tester, 'Tile width (cm)', '60');
      await _enterText(tester, 'Tiles per carton', '4');
      await _enterText(tester, 'Pallets count (optional)', '2');
      await _enterText(tester, 'Cartons per pallet (optional)', '40');
      await tester.pumpAndSettle();

      expect(find.text('Result'), findsOneWidget);
      expect(find.text('115.20 m²'), findsOneWidget); // total area (hero)
      expect(find.text('80'), findsOneWidget); // total cartons
      expect(find.text('320'), findsOneWidget); // total tiles
      expect(find.text('Full pallets'), findsOneWidget);
      expect(find.text('Cartons per pallet'), findsOneWidget);
      // Extra cartons is 0 (never entered), so only the field's own label
      // shows -- the result row stays hidden.
      expect(find.text('Extra cartons'), findsOneWidget);
    },
  );

  testWidgets(
    'Leaving both extra cartons and pallets count at 0/empty shows a '
    'friendly validation message and no result',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp(initialLocale: Locale('en')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cartons → m²'));
      await tester.pumpAndSettle();

      await _enterText(tester, 'Tile length (cm)', '60');
      await _enterText(tester, 'Tile width (cm)', '60');
      await _enterText(tester, 'Tiles per carton', '4');
      // An explicit 0 behaves the same as leaving the field empty, and
      // pallets count is never touched -- both sides of the "at least one"
      // rule are unsatisfied.
      await _enterText(tester, 'Extra cartons', '0');
      await tester.pumpAndSettle();

      expect(find.text('Enter cartons or pallets count'), findsOneWidget);
      expect(find.text('Result'), findsNothing);
    },
  );

  testWidgets(
    'Pallets count without cartons per pallet is rejected and does not calculate',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp(initialLocale: Locale('en')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cartons → m²'));
      await tester.pumpAndSettle();

      await _enterText(tester, 'Tile length (cm)', '60');
      await _enterText(tester, 'Tile width (cm)', '60');
      await _enterText(tester, 'Tiles per carton', '4');
      await _enterText(tester, 'Extra cartons', '10');
      await tester.pumpAndSettle();
      expect(find.text('Result'), findsOneWidget);

      // Provide pallets count only — cartons per pallet is never touched.
      await _enterText(tester, 'Pallets count (optional)', '1');
      await tester.pumpAndSettle();

      expect(
        find.text('Enter cartons per pallet, or clear the pallets count'),
        findsOneWidget,
      );
      expect(find.text('Result'), findsNothing);
    },
  );

  testWidgets(
    'Cartons per pallet alone (no pallets count) is valid and ignored in the total',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp(initialLocale: Locale('en')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cartons → m²'));
      await tester.pumpAndSettle();

      await _enterText(tester, 'Tile length (cm)', '60');
      await _enterText(tester, 'Tile width (cm)', '60');
      await _enterText(tester, 'Tiles per carton', '4');
      await _enterText(tester, 'Extra cartons', '10');
      await _enterText(tester, 'Cartons per pallet (optional)', '40');
      await tester.pumpAndSettle();

      expect(
        find.text('Enter cartons per pallet, or clear the pallets count'),
        findsNothing,
      );
      // '10' matches twice: the extra-cartons input field's own text, and
      // the total-cartons result row — proving the total is unaffected by
      // the ignored cartons-per-pallet value.
      expect(find.text('10'), findsNWidgets(2));
      // Pallets were never used, so the whole pallet-breakdown block stays
      // hidden even though cartons-per-pallet has a value.
      expect(find.text('Full pallets'), findsNothing);
    },
  );
}
