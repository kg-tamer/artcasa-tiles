// Verifies the home screen and both calculator screens (with a full result
// showing, i.e. maximum content density) render without a RenderFlex
// overflow or any other exception at three representative widths: a small
// phone, a tablet, and a Windows desktop window.
//
// Phase 6 made Arabic the app's default (RTL) language, so these checks now
// run against Arabic by default -- Arabic strings are often longer than
// their English counterparts (e.g. "باليتات/مشاتيح كاملة" vs. "Full
// pallets"), which makes this the more demanding case to guard against
// overflow. A dedicated English (LTR) check is included too, so both text
// directions stay covered.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tilemate/app.dart';

const _mobile = Size(360, 800);
const _tablet = Size(768, 1024);
const _desktop = Size(1280, 800);
const _sizes = [_mobile, _tablet, _desktop];

Future<void> _setSurfaceSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _enterText(
  WidgetTester tester,
  String label,
  String text,
) async {
  await tester.enterText(find.widgetWithText(TextFormField, label), text);
  await tester.pump();
}

String _label(Size size) => '${size.width.toInt()}x${size.height.toInt()}';

void main() {
  for (final size in _sizes) {
    testWidgets('Home screen (Arabic default) has no overflow at ${_label(size)}', (
      tester,
    ) async {
      await _setSurfaceSize(tester, size);
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Matches twice: the app bar title and the home screen's own brand
      // header (Phase 9) both show the brand name as real text.
      expect(find.text('ArtCasa Tiles'), findsNWidgets(2));
      expect(find.byType(Image), findsOneWidget); // ArtCasa Tiles icon mark
      final directionality = tester.widget<Directionality>(
        find.byType(Directionality).first,
      );
      expect(directionality.textDirection, TextDirection.rtl);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Calculator 1 with a full result (incl. pallet breakdown) has no '
      'overflow at ${_label(size)}',
      (tester) async {
        await _setSurfaceSize(tester, size);
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

        // Sanity check that the densest state (pallet breakdown showing)
        // actually rendered, so this test would fail loudly if setup broke.
        expect(find.text('باليتات/مشاتيح كاملة'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Calculator 2 with a full result (incl. pallet breakdown) has no '
      'overflow at ${_label(size)}',
      (tester) async {
        await _setSurfaceSize(tester, size);
        await tester.pumpWidget(const MyApp());
        await tester.pumpAndSettle();

        await tester.tap(find.text('كراتين لمتر'));
        await tester.pumpAndSettle();

        await _enterText(tester, 'طول البلاطة (سم)', '60');
        await _enterText(tester, 'عرض البلاطة (سم)', '60');
        await _enterText(tester, 'عدد البلاط في الكرتونة', '4');
        await _enterText(tester, 'كراتين إضافية', '33');
        await _enterText(tester, 'عدد الباليتات/المشاتيح (اختياري)', '1');
        await _enterText(tester, 'كراتين بكل باليت/مشتاح (اختياري)', '40');
        await tester.pumpAndSettle();

        expect(find.text('باليتات/مشاتيح كاملة'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Home screen switched to English (LTR) has no overflow at ${_label(size)}',
      (tester) async {
        await _setSurfaceSize(tester, size);
        await tester.pumpWidget(const MyApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.language));
        await tester.pumpAndSettle();
        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();

        final directionality = tester.widget<Directionality>(
          find.byType(Directionality).first,
        );
        expect(directionality.textDirection, TextDirection.ltr);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
