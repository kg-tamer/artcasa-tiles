import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

/// Shared building blocks for the calculator input/result cards. Used
/// identically by both calculator screens so the two never visually drift
/// apart — see square_meters_to_cartons_screen.dart and
/// cartons_to_square_meters_screen.dart.

/// The scrollable "app bar + centered, width-capped form" shell common to
/// every calculator screen. [children] is typically the input [SectionCard]
/// followed by an optional result [SectionCard].
///
/// Deliberately does *not* set `Form.autovalidateMode`. `Form`'s own
/// `build()` treats that mode as a form-wide gate: once *any* field has
/// been touched, it calls the public, unconditional `validate()` on *every*
/// registered field on the next rebuild — regardless of each field's own
/// interaction state. In practice that meant typing into one field
/// immediately flashed "This field is required" on every other still-empty
/// required field, which is exactly the premature-error UX
/// `AutovalidateMode.onUserInteraction` is supposed to avoid. Each
/// [NumberField] instead sets its own `autovalidateMode`, which keeps
/// `Form`'s gate at its default `disabled` (never bulk-validates) while
/// each field independently validates once *it* — not some sibling — has
/// been interacted with.
class CalculatorScreenScaffold extends StatelessWidget {
  const CalculatorScreenScaffold({
    super.key,
    required this.title,
    required this.formKey,
    required this.children,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A card with a title and a column of content — the shared chrome for both
/// the input card and the result card on every calculator screen.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A labeled divider used to separate required fields from optional ones.
class OptionalDivider extends StatelessWidget {
  const OptionalDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Divider(color: color)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Divider(color: color)),
        ],
      ),
    );
  }
}

/// A numeric text field with a label, helper text, and a keyboard/formatter
/// restricted to digits (and optionally a decimal point).
///
/// [maxLength] defaults to a generous 9 digits — far beyond any realistic
/// shop quantity (a tile 999,999,999 cm long, or a 999,999,999-carton
/// order, isn't a real order) — specifically to keep a pasted or fat-fingered
/// wall of digits from ever reaching [double.tryParse]/[int.tryParse] in a
/// range where results become imprecise or, for doubles, overflow to
/// `Infinity` (see numeric_input.dart). The built-in character counter is
/// suppressed since a "0/9" counter under every field would be visual
/// clutter inconsistent with a clean shop-tool look.
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.helperText,
    required this.validator,
    this.allowDecimal = true,
    this.fieldKey,
    this.maxLength = 9,
  });

  final TextEditingController controller;
  final String label;
  final String helperText;
  final FormFieldValidator<String> validator;
  final bool allowDecimal;
  final int maxLength;

  /// Optional key on the underlying [TextFormField] itself (distinct from
  /// this widget's own [key]), so a caller can force-revalidate this exact
  /// field via `GlobalKey<FormFieldState<String>>.currentState?.validate()`.
  /// Needed for fields whose validity depends on another field's value
  /// (cross-field validation), where [AutovalidateMode.onUserInteraction]
  /// alone wouldn't re-check this field until the user touches it directly.
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: fieldKey,
        controller: controller,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
        maxLength: maxLength,
        buildCounter:
            (
              context, {
              required currentLength,
              required isFocused,
              required maxLength,
            }) => null,
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            allowDecimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
          ),
        ],
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          helperMaxLines: 2,
        ),
        validator: validator,
      ),
    );
  }
}

/// A row of small chips that prefill an existing field with a common preset
/// value when tapped (e.g. a tile size or a waste percentage) — a shortcut
/// for values a shop worker types often. Purely a text-field shortcut: it
/// never stores anything of its own, never disables manual typing, and any
/// value not listed here can still be typed directly into the field below.
class QuickChoiceChips extends StatelessWidget {
  const QuickChoiceChips({
    super.key,
    required this.label,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                ActionChip(
                  label: Text(option),
                  onPressed: () => onSelected(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The large, high-contrast "headline number" shown at the top of a result
/// card — the single most important answer (e.g. required cartons, or
/// total area). Wrapped in a [FittedBox] so an unusually long value shrinks
/// to fit on one line instead of wrapping or clipping.
class ResultHero extends StatelessWidget {
  const ResultHero({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontSize: 40,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single "label ..... value" row inside a result card. The value is
/// [Flexible] with ellipsis overflow (rather than a bare [Text]) so an
/// unusually long formatted number — or a long translated label — can't
/// force a `RenderFlex` overflow on narrow screens.
class ResultRow extends StatelessWidget {
  const ResultRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}
