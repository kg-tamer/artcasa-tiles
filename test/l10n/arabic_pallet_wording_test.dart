// Phase 4 requested combining the standard word for "pallet" (باليت/
// باليتات) with the local shop term (مشتاح/مشاتيح) throughout the Arabic
// localization -- see docs/I18N_PLAN.md. Arabic grammar adds a "ال"
// ("the") prefix to each side of the slash when the phrase is definite
// (e.g. "الباليتات/المشاتيح"), so this checks for the two root words
// appearing together rather than one rigid contiguous substring.

import 'package:flutter_test/flutter_test.dart';
import 'package:tilemate/l10n/generated/app_localizations_ar.dart';

bool _usesCombinedPalletTerm(String value) {
  final hasStandardWord = value.contains('باليت');
  final hasLocalWord = value.contains('مشتاح') || value.contains('مشاتيح');
  return hasStandardWord && hasLocalWord;
}

void main() {
  final l10n = AppLocalizationsAr();

  group('Arabic pallet/مشتاح combined terminology (Phase 4)', () {
    test('shared cartons-per-pallet field label', () {
      expect(_usesCombinedPalletTerm(l10n.fieldCartonsPerPalletLabel), isTrue);
    });

    test('calculator 1 cartons-per-pallet helper', () {
      expect(
        _usesCombinedPalletTerm(l10n.calc1FieldCartonsPerPalletHelper),
        isTrue,
      );
    });

    test('calculator 2 pallets-count field label and helper', () {
      expect(
        _usesCombinedPalletTerm(l10n.calc2FieldPalletsCountLabel),
        isTrue,
      );
      expect(
        _usesCombinedPalletTerm(l10n.calc2FieldPalletsCountHelper),
        isTrue,
      );
    });

    test('calculator 2 cartons-per-pallet helper and validation messages', () {
      expect(
        _usesCombinedPalletTerm(l10n.calc2FieldCartonsPerPalletHelper),
        isTrue,
      );
      expect(
        _usesCombinedPalletTerm(l10n.calc2ValidationCartonsPerPalletRequired),
        isTrue,
      );
      expect(
        _usesCombinedPalletTerm(l10n.calc2ValidationCartonsOrPalletsRequired),
        isTrue,
      );
    });

    test('result/clipboard row labels', () {
      expect(_usesCombinedPalletTerm(l10n.resultFullPallets), isTrue);
      expect(_usesCombinedPalletTerm(l10n.resultCartonsPerPalletLabel), isTrue);
      expect(_usesCombinedPalletTerm(l10n.clipboardPalletsCountLabel), isTrue);
    });

    test(
      'extra/manual cartons wording intentionally stays plain (no pallet term)',
      () {
        // Phase 4 only asked for the combined term where pallets are
        // actually being discussed -- "extra cartons" is the
        // loose/non-palletized case, so it should NOT mention pallets.
        expect(
          _usesCombinedPalletTerm(l10n.calc2FieldExtraCartonsLabel),
          isFalse,
        );
      },
    );
  });
}
