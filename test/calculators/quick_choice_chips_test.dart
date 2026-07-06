// Phase 6: quick-choice chips (common tile sizes, and Calculator 1's waste
// presets) are a pure text-field shortcut -- they only ever fill the
// existing controllers, never store a list of their own, and never stop the
// user from typing a custom value instead or afterwards. Run against the
// app's actual default (Arabic), since that's the primary experience these
// chips were added for.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tilemate/app.dart';

String _textOf(WidgetTester tester, String label) {
  final field = tester.widget<TextFormField>(
    find.widgetWithText(TextFormField, label),
  );
  return field.controller!.text;
}

void main() {
  testWidgets(
    'Calculator 1: tile-size chips fill both length and width, waste chips '
    'fill the waste field, and manual typing still overrides either',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('متر لكراتين'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('60×60'));
      await tester.pumpAndSettle();
      expect(_textOf(tester, 'طول البلاطة (سم)'), '60');
      expect(_textOf(tester, 'عرض البلاطة (سم)'), '60');

      // A non-square preset fills the two fields with different values.
      await tester.tap(find.text('120×60'));
      await tester.pumpAndSettle();
      expect(_textOf(tester, 'طول البلاطة (سم)'), '120');
      expect(_textOf(tester, 'عرض البلاطة (سم)'), '60');

      // Manual typing still works after a chip was tapped -- chips are a
      // shortcut, never a replacement for the field.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'طول البلاطة (سم)'),
        '75',
      );
      await tester.pumpAndSettle();
      expect(find.text('75'), findsOneWidget);

      await tester.ensureVisible(find.text('5%'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5%'));
      await tester.pumpAndSettle();
      expect(_textOf(tester, 'نسبة الاحتياط (اختياري)'), '5');

      await tester.ensureVisible(find.text('10%'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10%'));
      await tester.pumpAndSettle();
      expect(_textOf(tester, 'نسبة الاحتياط (اختياري)'), '10');
    },
  );

  testWidgets(
    'Calculator 2: tile-size chips fill both length and width, and no '
    'waste chips are shown (Calculator 2 has no waste field)',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('كراتين لمتر'));
      await tester.pumpAndSettle();

      expect(find.text('احتياط سريع'), findsNothing);

      await tester.tap(find.text('80×80'));
      await tester.pumpAndSettle();
      expect(_textOf(tester, 'طول البلاطة (سم)'), '80');
      expect(_textOf(tester, 'عرض البلاطة (سم)'), '80');
    },
  );
}
