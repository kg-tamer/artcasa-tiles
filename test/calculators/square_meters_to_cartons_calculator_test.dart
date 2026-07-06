import 'package:flutter_test/flutter_test.dart';
import 'package:tilemate/calculators/square_meters_to_cartons/square_meters_to_cartons_calculator.dart';

void main() {
  group('calculateSquareMetersToCartons', () {
    test('100m², 60x60cm tile, 4 tiles/carton, no waste', () {
      final result = calculateSquareMetersToCartons(
        const SquareMetersToCartonsInput(
          requestedM2: 100,
          tileLengthCm: 60,
          tileWidthCm: 60,
          tilesPerCarton: 4,
        ),
      );

      expect(result.tileAreaM2, closeTo(0.36, 1e-9));
      expect(result.cartonAreaM2, closeTo(1.44, 1e-9));
      expect(result.requestedWithWasteM2, closeTo(100, 1e-9));
      expect(result.requiredCartons, 70);
      expect(result.actualDeliveredM2, closeTo(100.8, 1e-9));
      expect(result.extraM2, closeTo(0.8, 1e-9));
      expect(result.fullPallets, isNull);
      expect(result.extraCartons, isNull);
      expect(result.hasPalletBreakdown, isFalse);
    });

    test('100m², 60x60cm tile, 4 tiles/carton, 5% waste', () {
      final result = calculateSquareMetersToCartons(
        const SquareMetersToCartonsInput(
          requestedM2: 100,
          tileLengthCm: 60,
          tileWidthCm: 60,
          tilesPerCarton: 4,
          wastePercent: 5,
        ),
      );

      expect(result.requestedWithWasteM2, closeTo(105, 1e-9));
      expect(result.requiredCartons, 73);
      expect(result.actualDeliveredM2, closeTo(105.12, 1e-9));
    });

    test(
      'Phase 3 required example: 100m² + 5% waste, 40 cartons/pallet '
      '-> 73 cartons, 105.12 m², 1 full pallet + 33 extra',
      () {
        final result = calculateSquareMetersToCartons(
          const SquareMetersToCartonsInput(
            requestedM2: 100,
            tileLengthCm: 60,
            tileWidthCm: 60,
            tilesPerCarton: 4,
            wastePercent: 5,
            cartonsPerPallet: 40,
          ),
        );

        expect(result.requiredCartons, 73);
        expect(result.actualDeliveredM2, closeTo(105.12, 1e-9));
        expect(result.fullPallets, 1);
        expect(result.extraCartons, 33);
        expect(result.hasPalletBreakdown, isTrue);
      },
    );

    test('omitted cartons-per-pallet leaves pallet breakdown null, cartons unaffected', () {
      final withPallet = calculateSquareMetersToCartons(
        const SquareMetersToCartonsInput(
          requestedM2: 100,
          tileLengthCm: 60,
          tileWidthCm: 60,
          tilesPerCarton: 4,
          cartonsPerPallet: 40,
        ),
      );
      final withoutPallet = calculateSquareMetersToCartons(
        const SquareMetersToCartonsInput(
          requestedM2: 100,
          tileLengthCm: 60,
          tileWidthCm: 60,
          tilesPerCarton: 4,
        ),
      );

      expect(withoutPallet.requiredCartons, withPallet.requiredCartons);
      expect(withoutPallet.fullPallets, isNull);
      expect(withoutPallet.extraCartons, isNull);
      expect(withoutPallet.hasPalletBreakdown, isFalse);
    });

    test('exact-division boundary does not round up an unneeded extra carton', () {
      // tileArea = 0.25, cartonArea = 0.25 * 4 = 1.0 -> 50 / 1.0 = exactly 50.
      final result = calculateSquareMetersToCartons(
        const SquareMetersToCartonsInput(
          requestedM2: 50,
          tileLengthCm: 50,
          tileWidthCm: 50,
          tilesPerCarton: 4,
        ),
      );

      expect(result.requiredCartons, 50);
      expect(result.actualDeliveredM2, closeTo(50, 1e-9));
      expect(result.extraM2, closeTo(0, 1e-9));
    });

    test('zero waste percentage behaves the same as omitted waste', () {
      final zeroWaste = calculateSquareMetersToCartons(
        const SquareMetersToCartonsInput(
          requestedM2: 100,
          tileLengthCm: 60,
          tileWidthCm: 60,
          tilesPerCarton: 4,
          wastePercent: 0,
        ),
      );
      final omittedWaste = calculateSquareMetersToCartons(
        const SquareMetersToCartonsInput(
          requestedM2: 100,
          tileLengthCm: 60,
          tileWidthCm: 60,
          tilesPerCarton: 4,
        ),
      );

      expect(zeroWaste.requiredCartons, omittedWaste.requiredCartons);
      expect(zeroWaste.requestedWithWasteM2, omittedWaste.requestedWithWasteM2);
    });

    test('a large but realistic order does not crash and stays precise', () {
      // A big commercial order: ~1,000,000 m² of 1m x 1m tiles, one per
      // carton. Well within NumberField's 9-digit cap but far bigger than
      // the examples elsewhere in this file.
      final result = calculateSquareMetersToCartons(
        const SquareMetersToCartonsInput(
          requestedM2: 999999,
          tileLengthCm: 100,
          tileWidthCm: 100,
          tilesPerCarton: 1,
          cartonsPerPallet: 500,
        ),
      );

      expect(result.requiredCartons, 999999);
      expect(result.actualDeliveredM2, closeTo(999999, 1e-6));
      expect(result.extraM2, closeTo(0, 1e-6));
      expect(result.fullPallets, 1999);
      expect(result.extraCartons, 499);
    });
  });
}
