# TileMate — Rules for Claude Code (and any future contributor)

This file is the durable "constitution" for working on TileMate. It exists
so that any future session — human or AI — picking up this repo without the
original conversation still knows the ground rules. If something in this
file conflicts with a new instruction from the project owner, the new
instruction wins, but update this file to reflect the change rather than
silently drifting from it.

## Hard scope constraints

These are permanent product decisions (see
[PRODUCT_SPEC.md](PRODUCT_SPEC.md) §2), not temporary simplifications. Do
**not** add any of the following unless the project owner explicitly asks
for it in a future request:

1. No database of any kind.
2. No Supabase.
3. No SQLite.
4. No Drift.
5. No account system.
6. No saved history.
7. No saved tile catalog.
8. No backend, no network calls.
9. No feature creep — the app stays simple and fast.
10. The app is a calculator, not a data-management tool.

A corollary: don't add a state-management package (Provider, Riverpod,
Bloc, etc.), don't add persistence packages (`shared_preferences`,
`hive`, etc.), and don't add a backend client, unless a future request
explicitly changes this scope. Plain `StatefulWidget` + `setState` is the
default for anything this app needs.

## Languages

- Arabic (`ar`), Hebrew (`he`), English (`en`) are the three supported
  languages, permanently, unless a future request adds more.
- All user-facing text comes from ARB files via `flutter gen-l10n` — never
  hardcode a visible string in a widget. See [I18N_PLAN.md](I18N_PLAN.md).
- Arabic and Hebrew are RTL, English is LTR. This is handled automatically
  by Flutter's localization system — do not add manual `Directionality`
  overrides unless a genuine, specific layout bug requires it, and if so,
  document why in this file.
- The language switcher's selection is intentionally session-only (not
  persisted). Do not add persistence for it without an explicit request.

## Workflow rules

1. **Work in phases.** Don't jump ahead to later work (e.g. building the
   real calculators) without being asked, even if it seems like the
   obvious next step.
2. **After every phase, update [PROJECT_PROGRESS.md](../PROJECT_PROGRESS.md)**
   with current status, completed work, pending work, and how to test.
3. **After every phase, update [PROJECT_HISTORY.md](../PROJECT_HISTORY.md)**
   with a dated entry describing meaningful decisions and changes — not just
   "did phase N," but the *why* behind any non-obvious choice.
4. Don't skip either documentation update, even for a small phase.
5. Don't over-engineer: no abstractions, config layers, or "future-proofing"
   beyond what the current phase's stated task actually needs.

## Code style carried over from Phase 0

- Keep `lib/` organized by role: `theme/`, `screens/`, `widgets/`, `l10n/`.
  Add new folders (e.g. `models/`, `logic/`) only when a phase actually
  introduces something that belongs there (e.g. calculation engine
  functions belong in a plain-Dart file with no Flutter import, so they're
  trivially unit-testable — see [TEST_PLAN.md](TEST_PLAN.md)).
- Prefer plain Dart functions for calculation logic over widget-embedded
  math, so it can be unit tested without `WidgetTester`.
- Match [CALCULATION_RULES.md](CALCULATION_RULES.md) exactly — it is the
  agreed spec, not a suggestion. If it turns out to be wrong or incomplete,
  raise it with the project owner and update the doc; don't quietly diverge
  from it in code.
- Validation errors must be friendly and localized, never a crash or a raw
  exception surfaced to the user.

## Documentation set

This repo maintains, and expects future phases to keep updating:

- `README.md` — setup and orientation for a new developer.
- `PROJECT_PROGRESS.md` — living status: done, pending, how to test.
- `PROJECT_HISTORY.md` — dated decision log, append-only in spirit.
- `docs/PRODUCT_SPEC.md` — what the product is/isn't.
- `docs/CALCULATION_RULES.md` — the math, exactly.
- `docs/UI_DESIGN_PLAN.md` — design system and layout rules.
- `docs/I18N_PLAN.md` — localization architecture and key inventory.
- `docs/TEST_PLAN.md` — testing strategy, current and planned.
- `docs/CLAUDE_RULES.md` — this file.

If a change makes any of these inaccurate, fix the doc in the same phase as
the code change — don't let them drift.
