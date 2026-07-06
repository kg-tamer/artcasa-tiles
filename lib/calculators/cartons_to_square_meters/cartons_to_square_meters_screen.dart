import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import '../common/area_format.dart';
import '../common/calculator_form_widgets.dart';
import '../common/numeric_input.dart';
import 'cartons_to_square_meters_calculator.dart';

/// Calculator 2: how much area a given number of cartons/pallets covers.
/// Mirrors Calculator 1's structure (live recalculation, no submit button,
/// input card + result card) — see
/// `../square_meters_to_cartons/square_meters_to_cartons_screen.dart`.
///
/// Since Phase 4, "extra cartons" and "pallets count" are both optional —
/// a shop worker can calculate from pallets alone, cartons alone, or a mix
/// of both. At least one of the two must be positive; see
/// docs/CALCULATION_RULES.md.
class CartonsToSquareMetersScreen extends StatefulWidget {
  const CartonsToSquareMetersScreen({super.key});

  @override
  State<CartonsToSquareMetersScreen> createState() =>
      _CartonsToSquareMetersScreenState();
}

class _CartonsToSquareMetersScreenState
    extends State<CartonsToSquareMetersScreen> {
  final _formKey = GlobalKey<FormState>();

  // Cartons-per-pallet's validity depends on pallets count (cross-field
  // validation). AutovalidateMode.onUserInteraction only re-checks a field
  // once *that* field has been touched, so pallets count alone changing
  // wouldn't reveal the dependency error until the user separately touched
  // cartons-per-pallet. This key lets `_recalculate` force-refresh it.
  final _cartonsPerPalletFieldKey = GlobalKey<FormFieldState<String>>();

  final _tileLengthController = TextEditingController();
  final _tileWidthController = TextEditingController();
  final _tilesPerCartonController = TextEditingController();
  final _extraCartonsController = TextEditingController();
  final _palletsCountController = TextEditingController();
  final _cartonsPerPalletController = TextEditingController();

  late final List<TextEditingController> _controllers = [
    _tileLengthController,
    _tileWidthController,
    _tilesPerCartonController,
    _extraCartonsController,
    _palletsCountController,
    _cartonsPerPalletController,
  ];

  CartonsToSquareMetersResult? _result;

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(_recalculate);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Reads [text] as "how many" for a field where empty and an explicit `0`
  /// mean the same thing ("not using this"), and invalid text is also
  /// treated as 0 here — format errors are surfaced separately by that
  /// field's own validator, so this is only used for the *cross-field*
  /// "is this side of the equation actually being used" checks.
  int _effectiveNonNegative(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return parseNonNegativeInt(trimmed) ?? 0;
  }

  void _recalculate() {
    // Keep the cross-field error in sync even if the user only ever
    // touches pallets count and never the cartons-per-pallet field itself.
    _cartonsPerPalletFieldKey.currentState?.validate();

    final tileLengthCm = parsePositiveDouble(_tileLengthController.text);
    final tileWidthCm = parsePositiveDouble(_tileWidthController.text);
    final tilesPerCarton = parsePositiveInt(_tilesPerCartonController.text);

    final extraCartonsText = _extraCartonsController.text.trim();
    int? extraCartons;
    if (extraCartonsText.isNotEmpty) {
      final parsed = parseNonNegativeInt(extraCartonsText);
      if (parsed == null) {
        setState(() => _result = null);
        return;
      }
      // An explicit 0 behaves the same as leaving the field empty.
      extraCartons = parsed > 0 ? parsed : null;
    }

    final palletsCountText = _palletsCountController.text.trim();
    int? palletsCount;
    if (palletsCountText.isNotEmpty) {
      final parsed = parseNonNegativeInt(palletsCountText);
      if (parsed == null) {
        setState(() => _result = null);
        return;
      }
      palletsCount = parsed > 0 ? parsed : null;
    }

    final cartonsPerPalletText = _cartonsPerPalletController.text.trim();
    // Cross-field rule: pallets actually being used (> 0) requires a
    // cartons-per-pallet size.
    if (palletsCount != null && cartonsPerPalletText.isEmpty) {
      setState(() => _result = null);
      return;
    }

    int? cartonsPerPallet;
    if (cartonsPerPalletText.isNotEmpty) {
      cartonsPerPallet = parsePositiveInt(cartonsPerPalletText);
      if (cartonsPerPallet == null) {
        setState(() => _result = null);
        return;
      }
    }

    // At least one of extra cartons / pallets count must actually be used.
    if (extraCartons == null && palletsCount == null) {
      setState(() => _result = null);
      return;
    }

    if (tileLengthCm == null || tileWidthCm == null || tilesPerCarton == null) {
      setState(() => _result = null);
      return;
    }

    setState(() {
      _result = calculateCartonsToSquareMeters(
        CartonsToSquareMetersInput(
          tileLengthCm: tileLengthCm,
          tileWidthCm: tileWidthCm,
          tilesPerCarton: tilesPerCarton,
          cartonsCount: extraCartons,
          palletsCount: palletsCount,
          cartonsPerPallet: cartonsPerPallet,
        ),
      );
    });
  }

  void _handleClear() {
    for (final controller in _controllers) {
      controller.clear();
    }
    _formKey.currentState?.reset();
    FocusScope.of(context).unfocus();
    setState(() => _result = null);
  }

  /// Fills the tile length/width fields from a "60×60"-style preset. Only
  /// ever writes to the two existing controllers -- there is no saved tile
  /// list behind this, just a shortcut for common shop sizes.
  void _applyTileSize(String preset) {
    final parts = preset.split('×');
    if (parts.length != 2) return;
    _tileLengthController.text = parts[0];
    _tileWidthController.text = parts[1];
  }

  Future<void> _handleCopyResult() async {
    final result = _result;
    if (result == null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await Clipboard.setData(
      ClipboardData(text: _buildClipboardText(l10n, result)),
    );
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.resultCopiedMessage)));
  }

  String _formatM2(AppLocalizations l10n, double value) {
    return '${formatAreaM2(value)} ${l10n.unitSquareMeters}';
  }

  /// Builds the text copied to the clipboard: app name, calculator type,
  /// every input the shop worker actually used (in the same order as the
  /// form; a pallets-only order won't mention extra cartons at all, and
  /// vice versa), then the result. Unlike the on-screen result card, this
  /// does not repeat "Full pallets" as a separate output line — for this
  /// calculator that's just the pallets-count input echoed under a
  /// different label (see resultFullPallets's doc comment), so showing it
  /// twice would say the same number twice in a short message. "Cartons
  /// per pallet" and "Extra cartons" are genuinely part of the input
  /// picture though, so those stay in the inputs section.
  String _buildClipboardText(
    AppLocalizations l10n,
    CartonsToSquareMetersResult result,
  ) {
    final lines = <String>[
      l10n.appTitle,
      l10n.calculatorCartonsToAreaTitle,
      '',
      '${l10n.fieldTileLengthLabel}: ${_tileLengthController.text.trim()}',
      '${l10n.fieldTileWidthLabel}: ${_tileWidthController.text.trim()}',
      '${l10n.fieldTilesPerCartonLabel}: '
          '${_tilesPerCartonController.text.trim()}',
    ];
    if (result.cartonsCount > 0) {
      lines.add('${l10n.calc2FieldExtraCartonsLabel}: ${result.cartonsCount}');
    }
    if (result.hasPalletInfo) {
      lines
        ..add('${l10n.clipboardPalletsCountLabel}: ${result.palletsCount}')
        ..add(
          '${l10n.resultCartonsPerPalletLabel}: ${result.cartonsPerPallet}',
        );
    }
    lines
      ..add('')
      ..add('${l10n.resultTileArea}: ${_formatM2(l10n, result.tileAreaM2)}')
      ..add('${l10n.resultCartonArea}: ${_formatM2(l10n, result.cartonAreaM2)}')
      ..add('${l10n.resultTotalCartons}: ${result.totalCartons}')
      ..add('${l10n.resultTotalTiles}: ${result.totalTiles}')
      ..add('${l10n.resultTotalArea}: ${_formatM2(l10n, result.totalM2)}');
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    String? requiredPositiveDoubleValidator(String? text) {
      if ((text ?? '').trim().isEmpty) return l10n.validationRequiredField;
      return parsePositiveDouble(text) == null
          ? l10n.validationMustBeGreaterThanZero
          : null;
    }

    String? requiredPositiveIntValidator(String? text) {
      if ((text ?? '').trim().isEmpty) return l10n.validationRequiredField;
      return parsePositiveInt(text) == null
          ? l10n.validationMustBeGreaterThanZero
          : null;
    }

    // Extra cartons and pallets count are each independently optional (0
    // or empty both mean "not using this"), but at least one of the two
    // must be positive -- there'd be nothing to total up otherwise.
    String? extraCartonsValidator(String? text) {
      final trimmed = (text ?? '').trim();
      if (trimmed.isNotEmpty && parseNonNegativeInt(trimmed) == null) {
        return l10n.validationMustBeZeroOrGreater;
      }
      final extraCartons = _effectiveNonNegative(text ?? '');
      final pallets = _effectiveNonNegative(_palletsCountController.text);
      if (extraCartons == 0 && pallets == 0) {
        return l10n.calc2ValidationCartonsOrPalletsRequired;
      }
      return null;
    }

    String? palletsCountValidator(String? text) {
      final trimmed = (text ?? '').trim();
      if (trimmed.isNotEmpty && parseNonNegativeInt(trimmed) == null) {
        return l10n.validationMustBeZeroOrGreater;
      }
      final pallets = _effectiveNonNegative(text ?? '');
      final extraCartons = _effectiveNonNegative(_extraCartonsController.text);
      if (pallets == 0 && extraCartons == 0) {
        return l10n.calc2ValidationCartonsOrPalletsRequired;
      }
      return null;
    }

    String? cartonsPerPalletValidator(String? text) {
      final trimmed = (text ?? '').trim();
      if (trimmed.isEmpty) {
        final palletsInUse =
            _effectiveNonNegative(_palletsCountController.text) > 0;
        return palletsInUse
            ? l10n.calc2ValidationCartonsPerPalletRequired
            : null;
      }
      return parsePositiveInt(trimmed) == null
          ? l10n.validationMustBeGreaterThanZero
          : null;
    }

    return CalculatorScreenScaffold(
      title: l10n.calculatorCartonsToAreaTitle,
      formKey: _formKey,
      children: [
        SectionCard(
          title: l10n.calculatorInputSectionTitle,
          children: [
            NumberField(
              controller: _tileLengthController,
              label: l10n.fieldTileLengthLabel,
              helperText: l10n.fieldTileLengthHelper,
              validator: requiredPositiveDoubleValidator,
            ),
            NumberField(
              controller: _tileWidthController,
              label: l10n.fieldTileWidthLabel,
              helperText: l10n.fieldTileWidthHelper,
              validator: requiredPositiveDoubleValidator,
            ),
            QuickChoiceChips(
              label: l10n.quickSizesLabel,
              options: const ['60×60', '80×80', '120×60'],
              onSelected: _applyTileSize,
            ),
            NumberField(
              controller: _tilesPerCartonController,
              label: l10n.fieldTilesPerCartonLabel,
              helperText: l10n.fieldTilesPerCartonHelper,
              validator: requiredPositiveIntValidator,
              allowDecimal: false,
            ),
            OptionalDivider(label: l10n.calculatorOptionalSectionLabel),
            const SizedBox(height: 8),
            NumberField(
              controller: _extraCartonsController,
              label: l10n.calc2FieldExtraCartonsLabel,
              helperText: l10n.calc2FieldExtraCartonsHelper,
              validator: extraCartonsValidator,
              allowDecimal: false,
            ),
            NumberField(
              controller: _palletsCountController,
              label: l10n.calc2FieldPalletsCountLabel,
              helperText: l10n.calc2FieldPalletsCountHelper,
              validator: palletsCountValidator,
              allowDecimal: false,
            ),
            NumberField(
              fieldKey: _cartonsPerPalletFieldKey,
              controller: _cartonsPerPalletController,
              label: l10n.fieldCartonsPerPalletLabel,
              helperText: l10n.calc2FieldCartonsPerPalletHelper,
              validator: cartonsPerPalletValidator,
              allowDecimal: false,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _handleClear,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.clearButtonLabel),
            ),
          ],
        ),
        if (_result != null) ...[
          const SizedBox(height: 20),
          _ResultCard(
            result: _result!,
            l10n: l10n,
            formatM2: (value) => _formatM2(l10n, value),
            onCopy: _handleCopyResult,
          ),
        ],
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.l10n,
    required this.formatM2,
    required this.onCopy,
  });

  final CartonsToSquareMetersResult result;
  final AppLocalizations l10n;
  final String Function(double) formatM2;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: l10n.calculatorResultSectionTitle,
      children: [
        ResultHero(label: l10n.resultTotalArea, value: formatM2(result.totalM2)),
        const SizedBox(height: 8),
        ResultRow(
          label: l10n.resultTileArea,
          value: formatM2(result.tileAreaM2),
        ),
        ResultRow(
          label: l10n.resultCartonArea,
          value: formatM2(result.cartonAreaM2),
        ),
        ResultRow(
          label: l10n.resultTotalCartons,
          value: '${result.totalCartons}',
        ),
        ResultRow(
          label: l10n.resultTotalTiles,
          value: '${result.totalTiles}',
        ),
        if (result.hasPalletInfo) ...[
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          ResultRow(
            label: l10n.resultFullPallets,
            value: '${result.palletsCount}',
          ),
          ResultRow(
            label: l10n.resultCartonsPerPalletLabel,
            value: '${result.cartonsPerPallet}',
          ),
          if (result.cartonsCount > 0)
            ResultRow(
              label: l10n.resultExtraCartons,
              value: '${result.cartonsCount}',
            ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onCopy,
          icon: const Icon(Icons.copy_rounded),
          label: Text(l10n.copyResultButtonLabel),
        ),
      ],
    );
  }
}
