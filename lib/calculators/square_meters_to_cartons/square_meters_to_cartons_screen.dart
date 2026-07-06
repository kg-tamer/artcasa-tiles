import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import '../common/area_format.dart';
import '../common/calculator_form_widgets.dart';
import '../common/numeric_input.dart';
import 'square_meters_to_cartons_calculator.dart';

/// Calculator 1: how many cartons/pallets are needed to cover a requested
/// area. Recalculates live as the shop worker types — there is no separate
/// "Calculate" button, since the goal is fast, low-friction data entry.
class SquareMetersToCartonsScreen extends StatefulWidget {
  const SquareMetersToCartonsScreen({super.key});

  @override
  State<SquareMetersToCartonsScreen> createState() =>
      _SquareMetersToCartonsScreenState();
}

class _SquareMetersToCartonsScreenState
    extends State<SquareMetersToCartonsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _requestedM2Controller = TextEditingController();
  final _tileLengthController = TextEditingController();
  final _tileWidthController = TextEditingController();
  final _tilesPerCartonController = TextEditingController();
  final _cartonsPerPalletController = TextEditingController();
  final _wastePercentController = TextEditingController();

  late final List<TextEditingController> _controllers = [
    _requestedM2Controller,
    _tileLengthController,
    _tileWidthController,
    _tilesPerCartonController,
    _cartonsPerPalletController,
    _wastePercentController,
  ];

  SquareMetersToCartonsResult? _result;

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

  void _recalculate() {
    final requestedM2 = parsePositiveDouble(_requestedM2Controller.text);
    final tileLengthCm = parsePositiveDouble(_tileLengthController.text);
    final tileWidthCm = parsePositiveDouble(_tileWidthController.text);
    final tilesPerCarton = parsePositiveInt(_tilesPerCartonController.text);

    final cartonsPerPalletText = _cartonsPerPalletController.text.trim();
    int? cartonsPerPallet;
    if (cartonsPerPalletText.isNotEmpty) {
      cartonsPerPallet = parsePositiveInt(cartonsPerPalletText);
      if (cartonsPerPallet == null) {
        setState(() => _result = null);
        return;
      }
    }

    final wastePercentText = _wastePercentController.text.trim();
    var wastePercent = 0.0;
    if (wastePercentText.isNotEmpty) {
      final parsedWaste = parseNonNegativeDouble(wastePercentText);
      if (parsedWaste == null) {
        setState(() => _result = null);
        return;
      }
      wastePercent = parsedWaste;
    }

    if (requestedM2 == null ||
        tileLengthCm == null ||
        tileWidthCm == null ||
        tilesPerCarton == null) {
      setState(() => _result = null);
      return;
    }

    setState(() {
      _result = calculateSquareMetersToCartons(
        SquareMetersToCartonsInput(
          requestedM2: requestedM2,
          tileLengthCm: tileLengthCm,
          tileWidthCm: tileWidthCm,
          tilesPerCarton: tilesPerCarton,
          cartonsPerPallet: cartonsPerPallet,
          wastePercent: wastePercent,
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

  /// Fills the waste field from a "5%"-style preset.
  void _applyWastePercent(String preset) {
    _wastePercentController.text = preset.replaceAll('%', '');
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
  /// every input the shop worker entered (in the same order as the form),
  /// then the full result — so it reads as a complete, self-contained
  /// summary when pasted into WhatsApp or a note, not just a bare number.
  String _buildClipboardText(
    AppLocalizations l10n,
    SquareMetersToCartonsResult result,
  ) {
    final cartonsPerPalletText = _cartonsPerPalletController.text.trim();
    final wastePercentText = _wastePercentController.text.trim();

    final lines = <String>[
      l10n.appTitle,
      l10n.calculatorAreaToCartonsTitle,
      '',
      '${l10n.resultRequestedArea}: ${_formatM2(l10n, result.requestedM2)}',
      '${l10n.fieldTileLengthLabel}: ${_tileLengthController.text.trim()}',
      '${l10n.fieldTileWidthLabel}: ${_tileWidthController.text.trim()}',
      '${l10n.fieldTilesPerCartonLabel}: '
          '${_tilesPerCartonController.text.trim()}',
    ];
    if (cartonsPerPalletText.isNotEmpty) {
      lines.add('${l10n.resultCartonsPerPalletLabel}: $cartonsPerPalletText');
    }
    if (wastePercentText.isNotEmpty) {
      lines.add('${l10n.clipboardWastePercentLabel}: $wastePercentText%');
    }
    lines
      ..add('')
      ..add('${l10n.resultTileArea}: ${_formatM2(l10n, result.tileAreaM2)}')
      ..add('${l10n.resultCartonArea}: ${_formatM2(l10n, result.cartonAreaM2)}')
      ..add(
        '${l10n.resultRequestedWithWaste}: '
        '${_formatM2(l10n, result.requestedWithWasteM2)}',
      )
      ..add('${l10n.resultRequiredCartons}: ${result.requiredCartons}')
      ..add(
        '${l10n.resultActualDelivered}: '
        '${_formatM2(l10n, result.actualDeliveredM2)}',
      )
      ..add('${l10n.resultExtraArea}: ${_formatM2(l10n, result.extraM2)}');
    if (result.hasPalletBreakdown) {
      lines
        ..add('${l10n.resultFullPallets}: ${result.fullPallets}')
        ..add('${l10n.resultExtraCartons}: ${result.extraCartons}');
    }
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

    String? optionalPositiveIntValidator(String? text) {
      if ((text ?? '').trim().isEmpty) return null;
      return parsePositiveInt(text) == null
          ? l10n.validationMustBeGreaterThanZero
          : null;
    }

    String? optionalNonNegativeDoubleValidator(String? text) {
      if ((text ?? '').trim().isEmpty) return null;
      return parseNonNegativeDouble(text) == null
          ? l10n.validationMustBeZeroOrGreater
          : null;
    }

    return CalculatorScreenScaffold(
      title: l10n.calculatorAreaToCartonsTitle,
      formKey: _formKey,
      children: [
        SectionCard(
          title: l10n.calculatorInputSectionTitle,
          children: [
            NumberField(
              controller: _requestedM2Controller,
              label: l10n.calc1FieldRequestedAreaLabel,
              helperText: l10n.calc1FieldRequestedAreaHelper,
              validator: requiredPositiveDoubleValidator,
            ),
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
              controller: _cartonsPerPalletController,
              label: l10n.fieldCartonsPerPalletLabel,
              helperText: l10n.calc1FieldCartonsPerPalletHelper,
              validator: optionalPositiveIntValidator,
              allowDecimal: false,
            ),
            NumberField(
              controller: _wastePercentController,
              label: l10n.calc1FieldWastePercentLabel,
              helperText: l10n.calc1FieldWastePercentHelper,
              validator: optionalNonNegativeDoubleValidator,
            ),
            QuickChoiceChips(
              label: l10n.quickWastePercentLabel,
              options: const ['0%', '5%', '10%'],
              onSelected: _applyWastePercent,
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

  final SquareMetersToCartonsResult result;
  final AppLocalizations l10n;
  final String Function(double) formatM2;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: l10n.calculatorResultSectionTitle,
      children: [
        ResultHero(
          label: l10n.resultRequiredCartons,
          value: '${result.requiredCartons}',
        ),
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
          label: l10n.resultRequestedArea,
          value: formatM2(result.requestedM2),
        ),
        ResultRow(
          label: l10n.resultRequestedWithWaste,
          value: formatM2(result.requestedWithWasteM2),
        ),
        ResultRow(
          label: l10n.resultActualDelivered,
          value: formatM2(result.actualDeliveredM2),
        ),
        ResultRow(
          label: l10n.resultExtraArea,
          value: formatM2(result.extraM2),
        ),
        if (result.hasPalletBreakdown) ...[
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          ResultRow(
            label: l10n.resultFullPallets,
            value: '${result.fullPallets}',
          ),
          ResultRow(
            label: l10n.resultExtraCartons,
            value: '${result.extraCartons}',
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
