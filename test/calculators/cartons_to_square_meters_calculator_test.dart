import 'package:flutter_test/flutter_test.dart';
import 'package:tilemate/calculators/cartons_to_square_meters/cartons_to_square_meters_calculator.dart';

void main() {
  group('calculateCartonsToSquareMeters', () {
    test(
      'Phase 4 required example: pallets only (no manual cartons) -> '
      '80 total cartons, 320 total tiles, 115.20 m²',
      () {
        // cartonsCount omitted entirely -- a pure pallets-only order, the
        // scenario Phase 4 exists to support.
        final result = calculateCartonsToSquareMeters(
          const CartonsToSquareMetersInput(
            tileLengthCm: 60,
            tileWidthCm: 60,
            tilesPerCarton: 4,
            palletsCount: 2,
            cartonsPerPallet: 40,
          ),
        );

        expect(result.totalCartons, 80);
        expect(result.totalTiles, 320);
        expect(result.totalM2, closeTo(115.20, 1e-9));
        expect(result.hasPalletInfo, isTrue);
        expect(result.cartonsCount, 0);
      },
    );

    test('10 cartons, 60x60cm tile, 4 tiles/carton, no pallets', () {
      final result = calculateCartonsToSquareMeters(
        const CartonsToSquareMetersInput(
          tileLengthCm: 60,
          tileWidthCm: 60,
          tilesPerCarton: 4,
          cartonsCount: 10,
        ),
      );

      expect(result.tileAreaM2, closeTo(0.36, 1e-9));
      expect(result.cartonAreaM2, closeTo(1.44, 1e-9));
      expect(result.totalCartons, 10);
      expect(result.totalTiles, 40);
      expect(result.totalM2, closeTo(14.40, 1e-9));
      expect(result.hasPalletInfo, isFalse);
      expect(result.palletsCount, isNull);
    });

    test('1 pallet + 30 cartons, 40 cartons/pallet, 60x60cm tile, 4/carton', () {
      final result = calculateCartonsToSquareMeters(
        const CartonsToSquareMetersInput(
          tileLengthCm: 60,
          tileWidthCm: 60,
          tilesPerCarton: 4,
          cartonsCount: 30,
          palletsCount: 1,
          cartonsPerPallet: 40,
        ),
      );

      expect(result.totalCartons, 70);
      expect(result.totalTiles, 280);
      expect(result.totalM2, closeTo(100.80, 1e-9));
      expect(result.hasPalletInfo, isTrue);
      expect(result.palletsCount, 1);
      expect(result.cartonsCount, 30);
    });

    test(
      'Phase 3 required example: 33 cartons + 1 pallet of 40, 60x60cm tile, '
      '4/carton -> 73 total cartons, 105.12 m²',
      () {
        final result = calculateCartonsToSquareMeters(
          const CartonsToSquareMetersInput(
            tileLengthCm: 60,
            tileWidthCm: 60,
            tilesPerCarton: 4,
            cartonsCount: 33,
            palletsCount: 1,
            cartonsPerPallet: 40,
          ),
        );

        expect(result.totalCartons, 73);
        expect(result.totalM2, closeTo(105.12, 1e-9));
      },
    );

    test('cartons-per-pallet provided alone (no pallets count) contributes nothing', () {
      // Valid per the spec: "If cartons per pallet is filled, pallets count
      // can be empty or 0." The pure function treats a null palletsCount as
      // 0 regardless of cartonsPerPallet, and hasPalletInfo stays false
      // since no pallets were actually reported as used.
      final result = calculateCartonsToSquareMeters(
        const CartonsToSquareMetersInput(
          tileLengthCm: 60,
          tileWidthCm: 60,
          tilesPerCarton: 4,
          cartonsCount: 10,
          cartonsPerPallet: 40,
        ),
      );

      expect(result.totalCartons, 10);
      expect(result.totalM2, closeTo(14.40, 1e-9));
      expect(result.hasPalletInfo, isFalse);
    });

    test('both pallet fields omitted calculates from cartons alone', () {
      final withPalletFields = calculateCartonsToSquareMeters(
        const CartonsToSquareMetersInput(
          tileLengthCm: 60,
          tileWidthCm: 60,
          tilesPerCarton: 4,
          cartonsCount: 10,
        ),
      );

      expect(withPalletFields.totalCartons, 10);
      expect(withPalletFields.hasPalletInfo, isFalse);
    });

    test('a large but realistic order does not crash and stays precise', () {
      // A big commercial order: 2,000 pallets of 500 cartons each, plus
      // 500,000 loose cartons. Well within NumberField's 9-digit cap.
      final result = calculateCartonsToSquareMeters(
        const CartonsToSquareMetersInput(
          tileLengthCm: 60,
          tileWidthCm: 60,
          tilesPerCarton: 4,
          cartonsCount: 500000,
          palletsCount: 2000,
          cartonsPerPallet: 500,
        ),
      );

      expect(result.totalCartons, 1500000);
      expect(result.totalTiles, 6000000);
      expect(result.totalM2, closeTo(2160000, 1e-6));
    });
  });
}
