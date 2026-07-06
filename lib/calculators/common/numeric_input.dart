/// Parses [text] as a strictly positive double (`> 0`).
///
/// Returns `null` if [text] is `null`, empty/whitespace, unparsable, zero,
/// negative, or not finite. The finiteness check matters because a long
/// enough digit string (still just digits — it passes the numeric input
/// formatter) parses to `double.infinity` rather than failing outright;
/// left unchecked, that `Infinity` reads as "> 0" here and later crashes
/// with an `UnsupportedError` when a calculator calls `.ceil()` on it.
double? parsePositiveDouble(String? text) {
  final trimmed = text?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final value = double.tryParse(trimmed);
  if (value == null || !value.isFinite || value <= 0) return null;
  return value;
}

/// Parses [text] as a non-negative double (`>= 0`).
///
/// Returns `null` if [text] is `null`, empty/whitespace, unparsable,
/// negative, or not finite (see [parsePositiveDouble] for why finiteness is
/// checked). Used for the waste-percentage field, which allows `0`.
double? parseNonNegativeDouble(String? text) {
  final trimmed = text?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final value = double.tryParse(trimmed);
  if (value == null || !value.isFinite || value < 0) return null;
  return value;
}

/// Parses [text] as a strictly positive integer (`> 0`).
///
/// Returns `null` if [text] is `null`, empty/whitespace, unparsable
/// (including decimals, since counts of tiles/cartons are whole numbers),
/// zero, or negative.
int? parsePositiveInt(String? text) {
  final trimmed = text?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final value = int.tryParse(trimmed);
  if (value == null || value <= 0) return null;
  return value;
}

/// Parses [text] as a non-negative integer (`>= 0`).
///
/// Returns `null` if [text] is `null`, empty/whitespace, unparsable
/// (including decimals), or negative. Used for count fields where `0` is a
/// meaningful, valid entry — e.g. Calculator 2's cartons/pallets counts,
/// which are each independently optional (an explicit `0` behaves the same
/// as leaving the field empty).
int? parseNonNegativeInt(String? text) {
  final trimmed = text?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final value = int.tryParse(trimmed);
  if (value == null || value < 0) return null;
  return value;
}
