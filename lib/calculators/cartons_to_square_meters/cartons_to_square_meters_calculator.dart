/// Validated input for the cartons-to-square-meters calculator.
///
/// Constructing this assumes every value has already been validated and
/// *normalized* by the UI layer — see
/// `lib/calculators/common/numeric_input.dart` and
/// `cartons_to_square_meters_screen.dart`. In particular:
/// - [cartonsCount] and [palletsCount] are each `null` when the shop
///   worker left that field empty *or* explicitly entered `0` — the two
///   are treated identically ("not using this"), so by the time a value
///   reaches this class, `null` always means "contributes nothing."
/// - At least one of [cartonsCount] or [palletsCount] must be non-null
///   (Calculator 2 needs *something* to total up).
/// - [cartonsPerPallet] must be non-null whenever [palletsCount] is
///   non-null (a pallet count without a pallet size is meaningless), but
///   may be provided on its own with [palletsCount] left `null`.
///
/// This class and [calculateCartonsToSquareMeters] have no Flutter
/// dependency, so they are unit-testable without a widget tree.
class CartonsToSquareMetersInput {
  const CartonsToSquareMetersInput({
    required this.tileLengthCm,
    required this.tileWidthCm,
    required this.tilesPerCarton,
    this.cartonsCount,
    this.palletsCount,
    this.cartonsPerPallet,
  });

  final double tileLengthCm;
  final double tileWidthCm;
  final int tilesPerCarton;

  /// Loose/manual cartons not part of a pallet. Null when not used (empty
  /// or explicit `0` — see class doc).
  final int? cartonsCount;

  /// Null when the shop worker didn't provide a pallets count.
  final int? palletsCount;

  /// Null when the shop worker didn't provide a cartons-per-pallet size.
  final int? cartonsPerPallet;
}

/// Output of the cartons-to-square-meters calculation.
class CartonsToSquareMetersResult {
  const CartonsToSquareMetersResult({
    required this.tileAreaM2,
    required this.cartonAreaM2,
    required this.totalCartons,
    required this.totalTiles,
    required this.totalM2,
    required this.cartonsCount,
    this.palletsCount,
    this.cartonsPerPallet,
  });

  final double tileAreaM2;
  final double cartonAreaM2;
  final int totalCartons;
  final int totalTiles;
  final double totalM2;

  /// Effective loose/manual cartons count (`0` if not used). The "Extra
  /// cartons" result row only shows when this is `> 0`.
  final int cartonsCount;

  /// Echoes the input pallets count. Null when pallets weren't used.
  final int? palletsCount;

  /// Echoes the input cartons-per-pallet. Non-null whenever [palletsCount]
  /// is non-null (the UI layer enforces this pairing before construction).
  final int? cartonsPerPallet;

  bool get hasPalletInfo => palletsCount != null;
}

/// Pure calculation — must match docs/CALCULATION_RULES.md exactly.
CartonsToSquareMetersResult calculateCartonsToSquareMeters(
  CartonsToSquareMetersInput input,
) {
  final tileAreaM2 = (input.tileLengthCm / 100) * (input.tileWidthCm / 100);
  final cartonAreaM2 = tileAreaM2 * input.tilesPerCarton;

  final manualCartons = input.cartonsCount ?? 0;
  final pallets = input.palletsCount ?? 0;
  final cartonsPerPallet = input.cartonsPerPallet ?? 0;

  final totalCartons = manualCartons + (pallets * cartonsPerPallet);
  final totalTiles = totalCartons * input.tilesPerCarton;
  final totalM2 = totalCartons * cartonAreaM2;

  return CartonsToSquareMetersResult(
    tileAreaM2: tileAreaM2,
    cartonAreaM2: cartonAreaM2,
    totalCartons: totalCartons,
    totalTiles: totalTiles,
    totalM2: totalM2,
    cartonsCount: manualCartons,
    palletsCount: input.palletsCount,
    cartonsPerPallet: input.cartonsPerPallet,
  );
}
