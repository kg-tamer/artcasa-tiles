# TileMate — Product Specification

## 1. What TileMate is

TileMate is an **offline-only tile quantity calculator** built for tile shop
workers and installers who need fast, accurate answers to two everyday
questions:

1. "I need this many square meters of tiles — how many cartons and pallets
   do I order?"
2. "I have this many cartons and/or pallets — how much area does that
   actually cover?"

TileMate is a calculator, not a business system. It does one job and does it
well, quickly, in the language the user is comfortable with.

## 2. What TileMate is explicitly not

These exclusions are permanent product decisions, not temporary shortcuts.
They must not be reversed without an explicit request from the project owner:

1. No database of any kind.
2. No Supabase.
3. No SQLite.
4. No Drift.
5. No account system or login.
6. No saved calculation history.
7. No saved tile catalog.
8. No backend or network dependency — the app works fully offline, always.
9. The app stays simple and fast; no feature creep.
10. The app is a calculator. Nothing it does should require data to outlive
    the current session.

See [CLAUDE_RULES.md](CLAUDE_RULES.md) for how these constraints translate
into working rules for anyone (human or AI) developing this codebase.

## 3. Target platforms

A single Flutter codebase targets:

- **Android** (phones and tablets)
- **iOS** (iPhone and iPad)
- **Windows** (desktop)

Mobile is the primary experience; Windows desktop must remain fully usable
but is treated as a responsive adaptation of the same mobile-first design
(see [UI_DESIGN_PLAN.md](UI_DESIGN_PLAN.md)).

## 4. Target user

A tile shop worker or installer, often mid-conversation with a customer or on
a job site, who needs to:

- Enter a few numbers quickly, without hunting through menus.
- Get an unambiguous, correctly-rounded answer.
- Work in Arabic, Hebrew, or English, whichever they're most comfortable
  with, without the app fighting their reading direction.
- Trust the app even with no signal/Wi-Fi, since shops and job sites don't
  always have reliable connectivity.

## 5. Supported languages

- English (`en`) — left-to-right.
- Arabic (`ar`) — right-to-left.
- Hebrew (`he`) — right-to-left.

All user-facing text is sourced from ARB files via Flutter's official
`gen-l10n` pipeline — see [I18N_PLAN.md](I18N_PLAN.md). A language switcher in
the app bar lets the user change languages at any time; the selection is
intentionally **not** persisted between app launches unless a future request
explicitly asks for persistence.

## 6. The two calculators

Full formulas live in [CALCULATION_RULES.md](CALCULATION_RULES.md). This is
the product-level summary.

### Calculator 1 — Square meters → cartons/pallets

**Inputs:** requested square meters, tile length (cm), tile width (cm), tiles
per carton, cartons per pallet (optional), waste percentage (optional).

**Output:** how many cartons to order (always rounded up), how much area
that actually delivers, how much extra area that is over the request, and —
if cartons-per-pallet was given — how many full pallets plus leftover loose
cartons that comes out to.

### Calculator 2 — Cartons/pallets → square meters

**Inputs:** tile length (cm), tile width (cm), tiles per carton, cartons
count, pallets count (optional), cartons per pallet (optional).

**Output:** total cartons, total tiles, and total covered area in square
meters.

## 7. Validation philosophy

- Required numeric fields must be greater than 0.
- Optional fields may be left empty.
- Invalid or empty input must never crash the app — it must show a friendly,
  localized validation message instead.
- Displayed areas are rounded to 2 decimal places. Required cartons are
  always rounded **up** (ceiling), never down or to nearest — ordering short
  is not an acceptable outcome for a tile shop.

## 8. Out of scope for now (do not build unless explicitly requested)

- Any form of persistence (history, favorites, saved tile presets).
- Multi-currency or pricing features.
- User accounts, sync, or cloud backup.
- Barcode/QR scanning, camera features.
- Any network call whatsoever.

If a future request reintroduces any of these, it should come with an
explicit, deliberate scope change from the project owner — not be inferred
from a loosely related feature request.
