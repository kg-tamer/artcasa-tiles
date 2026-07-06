import 'package:flutter/material.dart';

import '../calculators/cartons_to_square_meters/cartons_to_square_meters_screen.dart';
import '../calculators/square_meters_to_cartons/square_meters_to_cartons_screen.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/language_switcher.dart';

/// Wide-vs-narrow breakpoint for switching the two calculator cards
/// between a stacked (mobile) and side-by-side (desktop) layout.
const double _wideLayoutBreakpoint = 640;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onLocaleChanged});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          LanguageSwitcher(onLocaleChanged: onLocaleChanged),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const _BrandHeader(),
                  const SizedBox(height: 20),
                  Text(
                    l10n.homeTagline,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.homePrompt,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final areaToCartons = _CalculatorCard(
                        icon: Icons.square_foot,
                        title: l10n.calculatorAreaToCartonsTitle,
                        subtitle: l10n.calculatorAreaToCartonsSubtitle,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SquareMetersToCartonsScreen(),
                          ),
                        ),
                      );
                      final cartonsToArea = _CalculatorCard(
                        icon: Icons.inventory_2_outlined,
                        title: l10n.calculatorCartonsToAreaTitle,
                        subtitle: l10n.calculatorCartonsToAreaSubtitle,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CartonsToSquareMetersScreen(),
                          ),
                        ),
                      );

                      if (constraints.maxWidth >= _wideLayoutBreakpoint) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: areaToCartons),
                            const SizedBox(width: 20),
                            Expanded(child: cartonsToArea),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          areaToCartons,
                          const SizedBox(height: 16),
                          cartonsToArea,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalculatorCard extends StatelessWidget {
  const _CalculatorCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(
                    AppTheme.controlRadius,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// The home screen's brand mark: a small ArtCasa Tiles icon plus real
/// Flutter text (never text baked into an image) for the brand name and
/// its Arabic business subtitle, so both always read correctly against
/// the current theme's colors in light *and* dark mode.
///
/// Phase 9 replaced the previous wide logo image (shown inside a
/// hardcoded white card) with this widget after the underlying logo/icon
/// PNG assets turned out to have a checkerboard pattern baked directly
/// into their (opaque) pixels rather than real transparency -- see
/// docs/UI_DESIGN_PLAN.md. Native text sidesteps that class of problem
/// entirely: there is no baked-in background or baked-in text color to
/// go wrong against an arbitrary theme.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  /// Warm beige/taupe pulled from the ArtCasa Tiles brand palette, used
  /// only as a small decorative accent (the short rule on each side of the
  /// Arabic subtitle, echoing the same dashes in the original logo) --
  /// everything else in this widget uses theme colors so it adapts to
  /// light/dark automatically.
  static const _brandTaupe = Color(0xFFB29684);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;

        final mark = Image.asset(
          'assets/branding/artcasa_icon.png',
          height: isWide ? 56 : 76,
          semanticLabel: l10n.appTitle,
        );

        final text = _BrandText(
          l10n: l10n,
          theme: theme,
          brandTaupe: _brandTaupe,
          centered: !isWide,
        );

        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [mark, const SizedBox(width: 20), Flexible(child: text)],
          );
        }
        return Column(children: [mark, const SizedBox(height: 14), text]);
      },
    );
  }
}

class _BrandText extends StatelessWidget {
  const _BrandText({
    required this.l10n,
    required this.theme,
    required this.brandTaupe,
    required this.centered,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final Color brandTaupe;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final crossAxisAlignment = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final textAlign = centered ? TextAlign.center : TextAlign.start;
    final rule = Container(width: 18, height: 1.5, color: brandTaupe);

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.appTitle,
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            rule,
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                l10n.brandSubtitle,
                textAlign: textAlign,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            rule,
          ],
        ),
      ],
    );
  }
}
