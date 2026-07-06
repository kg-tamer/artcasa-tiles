/// Formats a square-meter value to 2 decimal places for display, per
/// docs/CALCULATION_RULES.md ("Round displayed square meters to 2 decimal
/// places"). Does not append a unit — callers combine this with a
/// localized unit string (see `AppLocalizations.unitSquareMeters`).
String formatAreaM2(double value) => value.toStringAsFixed(2);
