// Phase 6 made Arabic the app's default language. These re-run the two
// approved example calculations directly against that default (no language
// switch first), so the required numeric results are proven to hold in the
// actual out-of-the-box experience, not only in the English-pinned
// screen-wiring tests under test/calculators/. Also checks that the
// Arabic copied result text (Phase 6 Task 4) reads as a clean, complete
// summary -- app name, calculator type, tile size, quantities, final
// result, and the باليت/مشتاح breakdown -- suitable for pasting into
// WhatsApp.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tilemate/app.dart';

Future<void> _enterText(WidgetTester tester, String label, String text) async {
  await tester.enterText(find.widgetWithText(TextFormField, label), text);
  await tester.pump();
}

void main() {
  testWidgets(
    'Calculator 1 approved example holds in Arabic (default): 100 m², '
    '60x60cm, 4/carton, 40/pallet, 5% waste -> 73 cartons, 105.12 m², '
    '1 full pallet, 33 extra cartons; copied text reads cleanly',
    (tester) async {
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

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('متر لكراتين'));
      await tester.pumpAndSettle();

      await _enterText(tester, 'المتر المطلوب (م²)', '100');
      await _enterText(tester, 'طول البلاطة (سم)', '60');
      await _enterText(tester, 'عرض البلاطة (سم)', '60');
      await _enterText(tester, 'عدد البلاط في الكرتونة', '4');
      await _enterText(tester, 'كراتين بكل باليت/مشتاح (اختياري)', '40');
      await _enterText(tester, 'نسبة الاحتياط (اختياري)', '5');
      await tester.pumpAndSettle();

      expect(find.text('73'), findsOneWidget); // required cartons (hero)
      expect(find.text('105.12 م²'), findsOneWidget); // actual delivered area
      expect(find.text('1'), findsOneWidget); // full pallets
      expect(find.text('33'), findsOneWidget); // extra cartons

      await tester.ensureVisible(find.text('نسخ النتيجة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('نسخ النتيجة'));
      await tester.pumpAndSettle();

      expect(copiedTexts, hasLength(1));
      final copied = copiedTexts.single;
      expect(copied, contains('ArtCasa Tiles')); // app name
      expect(copied, contains('متر لكراتين')); // calculator type
      expect(copied, contains('طول البلاطة (سم): 60')); // tile size
      expect(copied, contains('عرض البلاطة (سم): 60'));
      expect(copied, contains('المتر المطلوب: 100.00 م²')); // requested meter
      expect(copied, contains('الكراتين المطلوبة: 73')); // final cartons
      expect(copied, contains('باليتات/مشاتيح كاملة: 1')); // pallet breakdown
      expect(copied, contains('كراتين إضافية: 33'));
    },
  );

  testWidgets(
    'Calculator 2 approved example holds in Arabic (default): 60x60cm, '
    '4/carton, no extra cartons, 2 pallets of 40 -> 80 cartons, 320 tiles, '
    '115.20 m²; copied text reads cleanly',
    (tester) async {
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

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('كراتين لمتر'));
      await tester.pumpAndSettle();

      await _enterText(tester, 'طول البلاطة (سم)', '60');
      await _enterText(tester, 'عرض البلاطة (سم)', '60');
      await _enterText(tester, 'عدد البلاط في الكرتونة', '4');
      await _enterText(tester, 'عدد الباليتات/المشاتيح (اختياري)', '2');
      await _enterText(tester, 'كراتين بكل باليت/مشتاح (اختياري)', '40');
      await tester.pumpAndSettle();

      expect(find.text('115.20 م²'), findsOneWidget); // total area (hero)
      expect(find.text('80'), findsOneWidget); // total cartons
      expect(find.text('320'), findsOneWidget); // total tiles

      await tester.ensureVisible(find.text('نسخ النتيجة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('نسخ النتيجة'));
      await tester.pumpAndSettle();

      expect(copiedTexts, hasLength(1));
      final copied = copiedTexts.single;
      expect(copied, contains('ArtCasa Tiles')); // app name
      expect(copied, contains('كراتين لمتر')); // calculator type
      expect(copied, contains('طول البلاطة (سم): 60')); // tile size
      expect(copied, contains('عدد الباليتات/المشاتيح: 2')); // quantities
      expect(copied, contains('كراتين بكل باليت/مشتاح: 40'));
      expect(copied, contains('إجمالي الكراتين: 80')); // final result
      expect(copied, contains('إجمالي المتر: 115.20 م²'));
    },
  );
}
