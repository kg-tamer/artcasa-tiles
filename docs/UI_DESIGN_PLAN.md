# TileMate — UI Design Plan

## Principles

- **Clean, modern, simple.** No clutter, no unnecessary chrome.
- **Mobile-first, desktop-responsive.** Design for a phone in one hand
  first; widen gracefully for Windows desktop rather than designing desktop
  first and cramming it down.
- **Fast data entry.** A shop worker is typing numbers quickly, often
  mid-conversation with a customer. Inputs must be large, obviously tappable,
  and forgiving of imprecise taps.
- **Looks like a product, not a demo.** No default Flutter counter-demo
  aesthetics, no unstyled Material defaults left as-is.

## Design system (`lib/theme/app_theme.dart`)

TileMate uses **Material 3** with a single seed color
(`Color(0xFF0F6E6E)`, a deep teal) driving the full light and dark color
schemes via `ColorScheme.fromSeed`. This keeps every derived color
(surfaces, containers, error, outline, etc.) harmonious without hand-picking
each one, and gives dark mode "for free."

Both `AppTheme.light` and `AppTheme.dark` are built from the same
`_build(Brightness)` function so the two never drift out of sync. `MaterialApp`
wires both in with the default `ThemeMode.system`, so the app follows the
OS light/dark setting automatically.

### Tokens

| Token             | Value  | Used for                              |
|-------------------|--------|----------------------------------------|
| `cardRadius`      | 20     | Card corners                           |
| `controlRadius`   | 14     | Buttons, inputs, icon containers, menus, result hero|

(A third token, `spacingUnit`, was removed in Phase 3 — it was defined but
never actually referenced anywhere; spacing throughout the app is a small
set of hardcoded values (4/8/12/16/20/24/32) chosen per-context rather than
computed from a base unit. If a real spacing system becomes worth it later,
reintroduce a token then — don't carry unused ones "just in case.")

### Typography

A slightly enlarged, bolder scale relative to Flutter's defaults, since
readability at a glance matters more here than density:

- `headlineMedium` 28 / w700 — reserved for prominent numeric results.
- `headlineSmall` 22 / w700 — screen-level emphasis (e.g. home tagline).
- `titleLarge` 20 / w600, `titleMedium` 17 / w600 — card and section titles.
- `bodyLarge` 16, `bodyMedium` 15 — supporting text, 1.4 line height for
  comfortable reading in all three scripts.
- `labelLarge` 16 / w600 — button labels.

### Buttons and inputs

`FilledButtonThemeData` and `OutlinedButtonThemeData` both set a 56px minimum
height — a large, confident tap target appropriate for quick numeric entry
on a phone. `InputDecorationTheme` is pre-configured (filled, rounded,
no visible border except on focus/error); this was set up in Phase 0 before
any input fields existed, and paid off directly in Phase 1 and Phase 2 —
every field on both calculator screens gets the "large, readable input"
treatment for free, with zero per-field styling.

## Screens

### Home screen (`lib/screens/home_screen.dart`) — done in Phase 0

- App bar: app title (localized) + language switcher action.
- A short tagline and a one-line prompt, centered.
- Two large, equally-weighted calculator cards, each with an icon, a title,
  a one-line subtitle, and a trailing directional arrow. Tapping a card
  navigates to that calculator.
- Content is centered with a `900`-logical-pixel max width, so on a wide
  Windows window the layout doesn't stretch into unreadable full-bleed rows —
  it stays a comfortably-sized centered column instead.
- *(Phase 3)* Each card's title is capped at `maxLines: 1` and its subtitle
  at `maxLines: 2`, both with `TextOverflow.ellipsis` — insurance against a
  translated string being long enough to wrap unevenly between the two
  cards at narrow widths (Arabic and Hebrew don't always match English
  string length).
- *(Phase 6)* The tagline shown under the app title is now, in Arabic,
  simply **"حاسبة البلاط"** ("Tile Calculator") — a short subtitle under the
  brand name, matching a common app-name-plus-tagline pattern. This is also
  the phase that made Arabic the app's default language (see
  [I18N_PLAN.md](I18N_PLAN.md)), so this is what a shop worker now sees
  first on launch.
- *(Phase 7)* The generic `Icons.grid_view_rounded` mark that used to sit
  above the tagline was replaced with the real **ArtCasa Tiles logo** image,
  and `appTitle` (shown in the app bar, above it) changed from "TileMate" to
  **"ArtCasa Tiles"** — see [I18N_PLAN.md](I18N_PLAN.md).
- *(Phase 9)* The Phase 7 logo **image** was itself replaced with a native
  Flutter brand header (`_BrandHeader`/`_BrandText` in `home_screen.dart`):
  a small icon mark plus real `Text` widgets for the brand name and its
  Arabic subtitle, styled with theme colors. See "Branding" below for why
  and exactly how. The tagline text is now styled in the app's teal accent
  color (`colorScheme.primary`) instead of the default text color — the
  rest of the home screen's structure (prompt, two calculator cards) is
  unchanged.

**Responsive rule:** below `640` logical pixels wide, the two calculator
cards stack vertically (`Column`); at `640` and above, they sit side by side
in a `Row` with equal `Expanded` widths. `640` was chosen because it's
comfortably past the widest phones (including landscape) while catching
small windowed desktop app sizes too — see `_wideLayoutBreakpoint` in
`home_screen.dart`.

There is no placeholder/"coming soon" screen anymore — both calculator cards
open a real screen. (`lib/screens/placeholder_calculator_screen.dart` was
deleted in Phase 2 once Calculator 2 replaced its last remaining use; the
product is fixed at exactly two calculators, so there's no future calculator
that would need it back — see [PRODUCT_SPEC.md](PRODUCT_SPEC.md).)

### Shared calculator building blocks (`lib/calculators/common/calculator_form_widgets.dart`) — since Phase 2, expanded in Phase 3

Both calculator screens are built from the same shared widgets. Three were
extracted in Phase 2 once Calculator 2 needed byte-identical copies of what
Calculator 1 already had; Phase 3 added two more after finding the "hero
number" block and the whole screen shell were *also* duplicated
verbatim between the two screens (an audit finding, not a hypothetical):

- **`CalculatorScreenScaffold`** *(Phase 3)* — the `Scaffold` → `AppBar` →
  `SafeArea` → centered, width-capped (`640`) → `SingleChildScrollView` →
  `Form` shell common to both screens. Takes a `title`, a `formKey`, and the
  list of cards to lay out in a stretched `Column`. See "Validation display"
  below for why this widget deliberately does *not* set
  `Form.autovalidateMode`.
- **`SectionCard`** *(Phase 3)* — a `Card` with a title (`titleLarge`) and a
  column of content beneath it — the shared chrome for both the input card
  and the result card on every screen.
- **`NumberField`** — a `TextFormField` with a label, helper text, a numeric
  keyboard, and `FilteringTextInputFormatter` restricting keystrokes to
  digits (and `.` for decimal fields) so a shop worker can't type letters
  into a number field in the first place. Takes an optional `fieldKey` for
  the rare case a field's validity depends on another field (see Calculator
  2 below). *(Phase 3)* Also sets `maxLength: 9` with the built-in character
  counter suppressed (`buildCounter` returns `null`) — see
  [CALCULATION_RULES.md](CALCULATION_RULES.md) validation notes and
  `numeric_input.dart` for why: a long enough pasted digit string can
  overflow a `double` to `Infinity`, which then crashes on `.ceil()`. Nine
  digits is far beyond any real shop quantity but tight enough to keep
  parsed values comfortably inside safe numeric range.
- **`ResultHero`** *(Phase 3)* — the large, tinted "headline number" at the
  top of a result card (e.g. required cartons, or total area). Wrapped in a
  `FittedBox(fit: BoxFit.scaleDown)` so an unusually long value shrinks to
  fit on one line instead of wrapping awkwardly inside the hero container.
  Previously this was ~25 lines of `Container`/`Column`/`Text` duplicated
  verbatim in each screen's `_ResultCard`; both now just call
  `ResultHero(label: ..., value: ...)`.
- **`OptionalDivider`** — the labeled divider ("Optional") separating
  required fields from optional ones.
- **`ResultRow`** — a single "label ⋯ value" row inside a result card.
  *(Phase 3)* The value is wrapped in `Flexible` with `overflow:
  TextOverflow.ellipsis` and `maxLines: 1` (previously a bare `Text` with no
  overflow protection) — an unusually long formatted number, or a long
  translated label at a narrow width, could otherwise force a `RenderFlex`
  overflow. Covered by `test/responsive_layout_test.dart`.
- **`QuickChoiceChips`** *(Phase 6)* — a small `Wrap` of `ActionChip`s under
  a short label, used purely as a text-field shortcut: tapping a chip writes
  a preset value straight into an existing controller (e.g. "60×60" sets
  both the tile-length and tile-width fields), which flows through the
  field's own listener exactly like typing would — live recalculation and
  validation both fire normally, with no separate code path. It never stores
  its own list of values, never disables the field it fills, and a shop
  worker can still type any custom value before or after tapping a chip.
  Deliberately *not* built as a dropdown/autocomplete or backed by any kind
  of saved/recent-values list — that would start to look like a tile catalog
  (explicitly out of scope for Phase 6), whereas a fixed, hardcoded row of
  common values is just a faster way to fill a field that still exists and
  still accepts anything.

Each screen still owns its own `_ResultCard` (which rows to show, and in
what order, differs per calculator), but everything else — the screen
shell, every individual field, the hero number, every result row — is
shared, so the two calculators can't visually drift apart by accident.

### Calculator 1 screen (`lib/calculators/square_meters_to_cartons/square_meters_to_cartons_screen.dart`) — done in Phase 1

A single scrollable column (max width `640`, tighter than the home screen's
`900` since this is a linear form, not a two-up layout), containing two
cards:

**Input card** — a section title ("Enter your numbers", shared with
Calculator 2), then the four required fields in the order specified in
[CALCULATION_RULES.md](CALCULATION_RULES.md) (area needed, tile length,
tile width, tiles per carton), a labeled divider reading "Optional", then
the two optional fields (cartons per pallet, waste %), and an outlined
"Clear" button. Every field has both a label and helper text (e.g. "Area
needed (m²)" / "Area you need to cover") per the "clear labels and helper
text" requirement.

**Result card** — appears only once all required fields are valid (no
"Calculate" button; the result recomputes live as the user types, since the
whole point is fast entry). The single most useful number — **required
cartons** — is shown as a large, high-contrast "hero" number in a tinted
container above everything else, because that's the one number a shop
worker actually needs to act on. Every other value (tile area, carton area,
area needed, area with waste, actual area, extra area, and — only if
cartons-per-pallet was provided — full pallets and extra cartons) is a
secondary label/value row below it. A filled "Copy result" button at the
bottom copies a plain-text summary (built from the same localized labels
used on screen) to the clipboard, with a snackbar confirmation.

*(Phase 6)* Two `QuickChoiceChips` rows were added to the input card: common
tile sizes ("60×60", "80×80", "120×60") right after the tile width field —
tapping one fills both the length and width fields — and waste-percentage
presets ("0%", "5%", "10%") right after the waste field. Both are optional
shortcuts; every field they fill remains a normal, freely-editable
`NumberField`.

**Validation display:** each `NumberField` sets its own
`autovalidateMode: AutovalidateMode.onUserInteraction` so a field only
shows an error after *that field* has actually been typed in — an empty
form never greets the user with red error text on first open, and (see
Phase 3 fix below) filling in one field doesn't prematurely flash "required"
on other, still-empty ones.

**Phase 3 correction — this used to be set on the `Form` instead, and it
was a real bug.** `Form.autovalidateMode` is not "the default each field
inherits" the way it reads — it's a form-wide gate: `FormState.build()`
checks it directly, and once *any* field has been interacted with, calls
the public, unconditional `validate()` on *every* registered field on each
subsequent rebuild, regardless of that individual field's own interaction
history. `TextFormField`'s own `autovalidateMode` independently defaults to
`AutovalidateMode.disabled` when not set explicitly — it does not read the
ambient `Form`'s value. The combination meant: as soon as a shop worker
typed into the *first* field, every other empty required field immediately
showed a red "This field is required," even though the user hadn't reached
them yet — precisely the premature-error experience this mode is supposed
to prevent. Confirmed by reading `Form`/`FormField`'s source directly
(`C:\src\flutter\packages\flutter\lib\src\widgets\form.dart`) after a new
test caught it, not assumed. Fixed by removing `autovalidateMode` from
`CalculatorScreenScaffold`'s `Form` (leaving it at its own default,
`disabled`, so the form-wide bulk-validate never fires) and setting it
explicitly on each `NumberField`'s `TextFormField` instead, which is what
actually delivers correct, independent, per-field validation timing. See
`test/widget_test.dart` and `square_meters_to_cartons_screen_test.dart` for
the regression tests.

### Calculator 2 screen (`lib/calculators/cartons_to_square_meters/cartons_to_square_meters_screen.dart`) — done in Phase 2, validation reworked in Phase 4

Same shape as Calculator 1 (input card → result card, live recalculation,
Clear + Copy result), reusing the shared building blocks above, with a few
differences driven by what this calculator actually needs:

- **Hero number is "Total area"** instead of required cartons, since this
  calculator answers "how much area does this cover," not "how many
  cartons do I need."
- **The loose-cartons field is optional, not required.** Originally called
  "Cartons count" and required in Phase 2, it was renamed to **"Extra
  cartons"** and made optional in Phase 4, once real-world feedback made
  clear a shop worker needs to calculate from **pallets alone** just as
  often as from loose cartons — requiring "Cartons count" made that
  impossible. It now sits in the "Optional" section alongside pallets count
  and cartons-per-pallet, not in the required section. See
  [CALCULATION_RULES.md](CALCULATION_RULES.md) for the exact input rules.
- **Cross-field validation, two rules.** Pallets count and
  cartons-per-pallet and extra cartons are all individually optional, but:
  1. If pallets count is filled in and `> 0`, cartons-per-pallet becomes
     required (unchanged since Phase 2). Plain
     `AutovalidateMode.onUserInteraction` only re-checks a field once *that*
     field has been touched, which isn't good enough here — a user could
     fill in pallets count and never touch cartons-per-pallet, and would
     never see the error. The cartons-per-pallet field gets its own
     `GlobalKey<FormFieldState<String>>` (passed via `NumberField.fieldKey`),
     and `_recalculate()` calls `.validate()` on it directly every time any
     field changes, so the error is always current regardless of which
     field the user has actually clicked into.
  2. *(Phase 4)* At least one of extra cartons / pallets count must be
     `> 0`. Unlike rule 1, this doesn't need the forced-`GlobalKey` trick:
     the rule is symmetric between the two fields, so whichever one the
     user actually touches cross-checks the other's current raw text
     directly inside its own validator — there's no "invisible to the
     user" gap the way there is for cartons-per-pallet (where the newly-
     required field is a *third*, potentially-untouched field).

*(Phase 6)* A `QuickChoiceChips` row for common tile sizes ("60×60",
"80×80", "120×60") sits right after the tile width field, same as
Calculator 1 — tapping one fills both the length and width fields. There is
no waste field on Calculator 2, so no waste chips are shown here.

**Result card, since Phase 4:** when pallets were used (pallets count
`> 0`), the card shows "Full pallets" and "Cartons per pallet" (both
redisplaying the entered values for confirmation), then "Extra cartons"
*only if it's `> 0`* — a pallets-only order has nothing to show there.
"Cartons per pallet" used to be clipboard-text-only; it's been promoted to
an on-screen row since it's no longer safe to assume the user can see it
was entered by glancing at the input field (the whole point of Phase 4 is
that a pallets-only order may be the only thing on screen). "Full pallets"
and "Extra cartons" reuse the same labels Calculator 1 uses for its
*computed* pallet breakdown, since the real-world meaning is the same
either way (see [I18N_PLAN.md](I18N_PLAN.md)).

## Icons

Material Symbols only, kept literal and simple per field:

- `Icons.square_foot` — Calculator 1 (area → cartons).
- `Icons.inventory_2_outlined` — Calculator 2 (cartons → area).
- `Icons.language` — language switcher.
- `Icons.arrow_forward_rounded` — card affordance; this glyph has
  `IconData.matchTextDirection: true` built in, so it automatically mirrors
  in RTL layouts with no extra code.
- `Icons.refresh_rounded` — the "Clear" button, shared by both calculators.
- `Icons.copy_rounded` — the "Copy result" button, shared by both
  calculators.

When adding new icons, prefer ones where Flutter/Material already ships a
direction-aware variant (like the arrow above) over anything that visually
implies a reading direction.

## Branding (Phase 7, launcher icon Phase 8, home header rebuilt Phase 9)

The home screen previously used a generic `Icons.grid_view_rounded` glyph
as its "app mark" (Phase 0's placeholder, documented at the time as
standing in for a real logo). Phase 7 replaced it with the actual **ArtCasa
Tiles logo** shown as an image. **Phase 9 replaced that image with a native
Flutter brand header** after the logo/icon image assets turned out to be
corrupted — see below for the full story. This section describes the
*current* (Phase 9) implementation first, then the history.

### The Phase 9 problem: a dark-mode bug traced to corrupted assets, not just bad widget code

The project owner reported the Phase 7/8 home-screen logo looked wrong in
dark mode: shown inside a white card, with a "dark/transparent
checkerboard-looking background" visible, the image too small and cramped,
and its baked-in text less readable than native text would be.

Investigating *before* changing any widget code (rather than assuming the
Container/white-card styling was simply wrong) found the real root cause:
at the start of Phase 9, both `assets/branding/artcasa_icon.png` and
`assets/branding/artcasa_logo_trimmed.png` on disk had been replaced with
files containing a **literal checkerboard pattern baked into fully opaque
pixels** — not real alpha transparency. Confirmed two ways, not assumed
from how they merely looked in a preview:

1. `System.Drawing.Bitmap.PixelFormat` reported `Format24bppRgb` for both
   files (no alpha channel at all — GDI+ reads this directly from the PNG's
   color-type header byte, so this is reliable, not a guess).
2. Sampling a horizontal strip of "background" pixels showed them
   alternating between two distinct opaque gray values (e.g. `~34,34,33`
   and `~27,27,26`, both `A=255`) — an actual two-tone checker baked into
   the image data, not a transparency-preview artifact of any viewer. This
   is a classic mis-export mistake (capturing a design tool's
   "this is transparent" checkerboard *indicator* as literal pixel content
   instead of real alpha transparency), and it explains every symptom in
   the bug report at once: the white `Container` in the Phase 7/8 code
   showed through as a white card (unchanged), the checkerboard-baked PNG
   showed as a checkerboard behind/around the artwork, and the
   `artcasa_logo_trimmed.png` variant's baked-in text had also been
   redrawn in light colors (white/teal) intended for a dark background —
   unreadable once forced inside that white card.

**Given this, no amount of widget-code tweaking alone would have fixed
it** — the assets themselves needed to be corrected. The original,
untouched `assets/branding/artcasa_logo.png` (verified still intact: plain
opaque white background, no checkerboard) was used to regenerate a clean,
**genuinely transparent** icon-only asset, and the brief's own direction —
stop relying on any image for text at all — was followed for the wordmark
and subtitle.

### The fix: a properly transparent icon + native Flutter text

**`assets/branding/artcasa_icon.png` was regenerated** (same house/tile
artwork, cropped from the same untouched `artcasa_logo.png` used in Phase
8) via:

1. Crop to `left=125, top=414, width=304, height=344` — the icon's own
   content bounding box (`x:[137,417] y:[426,746]`, already known from
   Phase 8's crop) plus a small uniform margin. Unlike Phase 8's crop, this
   one doesn't need to be square (it's no longer also used to regenerate a
   launcher icon this phase — see the note below), so no asymmetric
   trade-off was needed this time.
2. **Chroma-key the white background to real alpha transparency**, based
   on measured colors: the background is `avg(R,G,B) ≈ 254`, and the
   *lightest* artwork color (the mint tile square) is `≈ 220` — a
   comfortable 30+ unit gap. Every pixel with `avg >= 248` became fully
   transparent (`alpha=0`); `avg <= 238` stayed fully opaque; values in
   between were linearly interpolated for a soft, anti-aliased edge. This
   is plain per-pixel `System.Drawing` manipulation (`GetPixel`/`SetPixel`
   in a loop), the same tooling used for every prior crop in this project
   — no ImageMagick or working Python was available in this sandbox.
3. **Verified, not assumed:** re-read the saved file back and confirmed
   `PixelFormat: Format32bppArgb` with a transparent corner (`A=0`) and an
   opaque, correctly-colored tile square (`A=255`); checked an artwork edge
   for a white-tinted "halo" from the chroma-key (none found — the
   transition pixels are either fully transparent or fully opaque at every
   sampled edge, no partial-alpha fringe); and **composited the result onto
   both an approximate dark-theme and light-theme background color** to
   see exactly how it would look in the real app before wiring it in —
   confirmed clean in both.

**`assets/branding/artcasa_logo_trimmed.png` was deleted.** It's no longer
referenced anywhere in code (the home screen no longer shows a wide logo
image at all) and the copy that existed at the start of Phase 9 was the
corrupted, checkerboard-baked file described above — not worth keeping
around as a confusing, broken artifact. The original
`assets/branding/artcasa_logo.png` (confirmed intact) remains in the repo
as reference/documentation material, unchanged.

**Home screen widget** (`lib/screens/home_screen.dart`): a new
`_BrandHeader` (responsive layout) plus `_BrandText` (the actual text
column) replace the old `Container`/`Image.asset` block entirely:

```dart
// Inside _BrandHeader.build, via LayoutBuilder:
final mark = Image.asset(
  'assets/branding/artcasa_icon.png',
  height: isWide ? 56 : 76,
  semanticLabel: l10n.appTitle,
);
final text = _BrandText(..., centered: !isWide);

if (isWide) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [mark, const SizedBox(width: 20), Flexible(child: text)],
  );
}
return Column(children: [mark, const SizedBox(height: 14), text]);
```

- **No `Container`, no background color, no border, no card.** The icon is
  genuinely transparent now, so it's placed directly with nothing behind
  it — whatever the theme's scaffold background is (light or dark) shows
  through naturally, exactly like any other icon in the app.
- **Responsive via the same `_wideLayoutBreakpoint` (640px)** already used
  for the two calculator cards, so both parts of the screen switch layout
  at the same width. Wide: icon beside the text block, centered as one
  compact unit (`Flexible` bounds the text column's width so it can wrap
  instead of overflowing, without being stretched to fill all remaining
  space). Narrow: icon centered above the text block.
- **`_BrandText` never hardcodes alignment** — it takes `centered` from
  the parent and derives `CrossAxisAlignment`/`TextAlign` from it
  (`.start`/`.center`), and uses `TextAlign.start`/`CrossAxisAlignment
  .start` rather than `.left`, so RTL mirroring (Arabic: icon and text
  swap sides in the wide layout; text right-aligns in the narrow layout)
  is automatic — no manual `Directionality` handling needed, consistent
  with how RTL is handled everywhere else in this app.
- **All text is real `Text` widgets, styled from theme colors:**
  - `l10n.appTitle` ("ArtCasa Tiles") — `colorScheme.onSurface`, bold —
    the highest-contrast, most legible color available in either theme,
    used for the single most important line.
  - `l10n.brandSubtitle` ("للبلاط والسيراميك", new key — see
    [I18N_PLAN.md](I18N_PLAN.md)) — `colorScheme.onSurfaceVariant` (muted,
    secondary), flanked by two short rule lines in a hardcoded warm taupe
    (`Color(0xFFB29684)`) — the one deliberately-hardcoded color in this
    widget, used only for these two decorative 1.5px-tall rules (not
    text), echoing the dashes either side of the same subtitle in the
    original logo. A hardcoded color here carries no contrast risk since
    it's a decorative line, not something that needs to be read.
  - `l10n.homeTagline` ("حاسبة البلاط") — unchanged in position (still a
    separate line below the header, in `HomeScreen.build` itself, not
    inside `_BrandHeader`) but now styled with `colorScheme.primary` (the
    app's signature teal) instead of the default text color — the one
    deliberate use of the teal/mint brand accent on text in this header,
    chosen over tinting the brand name itself so "ArtCasa Tiles" stays at
    maximum legibility.
- **Text overflow guarded**: `maxLines: 1` + `TextOverflow.ellipsis` on
  both the brand name and the subtitle, consistent with this project's
  standing overflow-hardening practice (see `ResultRow`,
  `_CalculatorCard`'s title/subtitle, etc.) — cheap insurance against an
  unexpectedly long translated string at a narrow width, even though
  neither of these two strings is expected to ever wrap in practice.

**Launcher icon note (ties back to Phase 8, regenerated Phase 10).**
Phase 9 changed `assets/branding/artcasa_icon.png`'s *content* (now
transparent, slightly different crop margins than Phase 8's square opaque
version) but deliberately did not regenerate the already-shipped
Android/Windows launcher icon files — that was flagged as a follow-up.
**Phase 10 did that follow-up**: re-ran
`dart run flutter_launcher_icons`, which overwrote
`android/app/src/main/res/mipmap-*/ic_launcher.png` (all 5 densities) and
`windows/runner/resources/app_icon.ico` with icons generated from the
corrected, transparent source. Verified (not just assumed) by extracting
the raw pixel data of both outputs: the Android PNG reads back as
`Format32bppArgb` with a transparent corner pixel; the `.ico`'s embedded
256px frame was extracted from the ICO container directly (GDI+'s
`Icon.ToBitmap()` has a long-standing bug that throws on 256px
PNG-compressed ICO frames — a decoder limitation, not a sign anything was
wrong with the file) and also reads back as genuinely transparent. A
rebuilt Windows release was launched and screenshotted: the title-bar icon
(same `.ico` resource the taskbar uses) shows the clean house/tile mark
directly against the dark title bar, with no white box or checkerboard.
See [PROJECT_HISTORY.md](../PROJECT_HISTORY.md)'s Phase 10 entry for the
full verification steps.

*Exact crop method* (reproducible if the source logo is ever replaced):

1. The full logo's overall visible-content bounding box was already known
   from Phase 7's trim (`x:[137,1130] y:[426,746]` in the original
   1254×1254 image).
2. A column-by-column pixel scan (`System.Drawing.Bitmap.GetPixel` via
   PowerShell — no ImageMagick or working Python was available in this
   environment) across `x:100..550` within that vertical range found a
   clear gap of blank (near-white) columns between `x=418` and `x=446`:
   the house/tile icon's own content ends at `x=417`, and the "ArtCasa
   Tiles" wordmark's first stroke starts at `x=448`. This gap is what
   makes a clean icon-only crop possible at all — confirmed before
   cropping, not assumed.
3. A finer per-pixel scan restricted to `x:100..430` refined the icon-only
   bounding box to exactly `x:[137,417] y:[426,746]` (280×320px).
4. Padded to a square, biased to stay inside the safe blank gap on the
   right (so no anti-aliased text pixels bleed in) and using the generous
   blank canvas on the left/top/bottom freely: final crop rectangle
   `left=97, top=414, width=344, height=344` (344×344px square). This
   places the icon slightly right-of-center within its own square frame
   (56px clear space on the left vs. 16px on the right) — an accepted,
   minor trade-off given the hard constraint of not touching the nearby
   text; confirmed visually acceptable at both full size and downscaled
   previews (48/96/192px) before committing to it.

**Launcher icon generation.** The
[`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons)
package (`^0.14.4`) was added as a **dev dependency only** — it runs at
build/tooling time to write PNG/ICO files into the native platform folders
and is never part of the shipped app. Configured in `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/branding/artcasa_icon.png"
  windows:
    generate: true
    image_path: "assets/branding/artcasa_icon.png"
    icon_size: 256
```

Run via `dart run flutter_launcher_icons` (after `flutter pub get`). This
overwrote `android/app/src/main/res/mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png`
and `windows/runner/resources/app_icon.ico` in place — the same flat,
non-adaptive icon structure the Flutter project template already used, so
no new Android adaptive-icon XML or format was introduced. `ios: false`
deliberately skips iOS entirely (this project doesn't build for iOS in this
environment; deferred, not attempted).

**The home screen still shows the full logo, not the small icon.** Phase 8
only added the launcher/OS-level icon; `home_screen.dart`'s widget (above)
was not touched.

## Responsiveness notes for Windows desktop

- No fixed pixel-perfect desktop layout is designed. Instead, the same
  widget tree reflows using `LayoutBuilder`, so mobile and desktop stay in
  sync with zero duplicated screens.
- Tap targets sized for touch (56px+) remain comfortable with a mouse — no
  separate "desktop-only" tightened layout is planned; simplicity wins over
  density here.

## Automated responsive/overflow verification (Phase 3)

`test/responsive_layout_test.dart` pumps the home screen and both
calculators — with a full result showing, including the pallet breakdown,
i.e. the densest state each screen can be in — at three surface sizes via
`tester.binding.setSurfaceSize`:

| Label     | Size (logical px) | Represents            |
|-----------|--------------------|------------------------|
| Mobile    | 360 × 800          | A small phone           |
| Tablet    | 768 × 1024         | A tablet                |
| Desktop   | 1280 × 800         | A Windows desktop window|

Each check asserts `tester.takeException()` is `null` after settling —
catching `RenderFlex` overflow and any other rendering exception directly,
rather than relying on someone visually spotting it. *(Phase 6)* Since
Arabic is now the app's default, every check in this file runs against
Arabic by default (previously English, with a separate Arabic-switch case)
— this is arguably the more demanding direction to test, since Arabic
strings are often longer than their English counterparts (e.g.
"باليتات/مشاتيح كاملة" vs. "Full pallets"), and it's also what a shop worker
actually sees first. A dedicated "switched to English (LTR)" check was
added per size so the opposite text direction stays covered too. This is
what "reviewed the UI at small mobile / tablet / desktop widths" concretely
means for this project: real, repeatable, automated coverage rather than a
one-time manual look — though a real visual check on-device is still
worthwhile (see [TEST_PLAN.md](TEST_PLAN.md) for what automated tests can
and can't catch).
