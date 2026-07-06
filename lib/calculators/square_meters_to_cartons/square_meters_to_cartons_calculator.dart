/// Validated input for the square-meters-to-cartons calculator.
///
/// Constructing this assumes every value has already been validated by the
/// UI layer (required fields `> 0`, optional fields `null` or `> 0`, waste
/// `>= 0`) — see `lib/calculators/common/numeric_input.dart`. This class and
/// [calculateSquareMetersToCartons] have no Flutter dependency, so they are
/// unit-testable without a widget tree.
class SquareMetersToCartonsInput {
  const SquareMetersToCartonsInput({
    required this.requestedM2,
    required this.tileLengthCm,
    required this.tileWidthCm,
    required this.tilesPerCarton,
    this.cartonsPerPallet,
    this.wastePercent = 0,
  });

  final double requestedM2;
  final double tileLengthCm;
  final double tileWidthCm;
  final int tilesPerCarton;

  /// Null when the shop worker didn't provide a pallet size.
  final int? cartonsPerPallet;

  /// Defaults to `0` when no waste allowance was entered.
  final double wastePercent;
}

/// Output of the square-meters-to-cartons calculation.
class SquareMetersToCartonsResult {
  const SquareMetersToCartonsResult({
    required this.tileAreaM2,
    required this.cartonAreaM2,
    required this.requestedM2,
    required this.requestedWithWasteM2,
    required this.requiredCartons,
    required this.actualDeliveredM2,
    required this.extraM2,
    this.fullPallets,
    this.extraCartons,
  });

  final double tileAreaM2;
  final double cartonAreaM2;
  final double requestedM2;
  final double requestedWithWasteM2;
  final int requiredCartons;
  final double actualDeliveredM2;
  final double extraM2;

  /// Null when no valid cartons-per-pallet was provided.
  final int? fullPallets;

  /// Null when no valid cartons-per-pallet was provided.
  final int? extraCartons;

  bool get hasPalletBreakdown => fullPallets != null;
}

/// Pure calculation — must match docs/CALCULATION_RULES.md exactly.
SquareMetersToCartonsResult calculateSquareMetersToCartons(
  SquareMetersToCartonsInput input,
) {
  final tileAreaM2 = (input.tileLengthCm / 100) * (input.tileWidthCm / 100);
  final cartonAreaM2 = tileAreaM2 * input.tilesPerCarton;
  final requestedWithWasteM2 =
      input.requestedM2 * (1 + input.wastePercent / 100);
  final requiredCartons = (requestedWithWasteM2 / cartonAreaM2).ceil();
  final actualDeliveredM2 = requiredCartons * cartonAreaM2;
  final extraM2 = actualDeliveredM2 - input.requestedM2;

  int? fullPallets;
  int? extraCartons;
  final cartonsPerPallet = input.cartonsPerPallet;
  if (cartonsPerPallet != null && cartonsPerPallet > 0) {
    fullPallets = requiredCartons ~/ cartonsPerPallet;
    extraCartons = requiredCartons % cartonsPerPallet;
  }

  return SquareMetersToCartonsResult(
    tileAreaM2: tileAreaM2,
    cartonAreaM2: cartonAreaM2,
    requestedM2: input.requestedM2,
    requestedWithWasteM2: requestedWithWasteM2,
    requiredCartons: requiredCartons,
    actualDeliveredM2: actualDeliveredM2,
    extraM2: extraM2,
    fullPallets: fullPallets,
    extraCartons: extraCartons,
  );
}
