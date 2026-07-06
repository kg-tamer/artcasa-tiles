# TileMate — Test Plan

## Philosophy

TileMate's logic is small and pure (arithmetic + validation), which means
most of it is cheap to unit test exhaustively. UI tests are kept to smoke
tests that prove navigation, localization, and RTL/LTR wiring actually work
end-to-end, rather than re-testing Flutter framework behavior.

## How to run tests

```bash
flutter analyze   # static analysis, must report no issues
flutter test      # widget/unit test suite
```

Both are run in CI-less local development for now; run them before
considering any phase complete.

## Current coverage

### Phase 0 — `test/widget_test.dart` (app shell)

1. **Home screen renders with English defaults** — app title and both
   calculator card labels are present; `Directionality` resolves to `ltr`.
2. **Switching to Arabic** — via the language switcher, updates visible text
   to the Arabic translation and flips `Directionality` to `rtl`.
3. **Switching to Hebrew** — same as above, for Hebrew.
4. **First calculator card navigation** — tapping it opens the real
   Calculator 1 screen (updated in Phase 1; previously opened the
   placeholder).
5. **Second calculator card navigation** — tapping it opens the real
   Calculator 2 screen (updated in Phase 2; previously opened the
   placeholder, which no longer exists in the codebase at all).

These are the regression safety net for the localization and navigation
plumbing every phase builds on top of. If any of them start failing, treat
it as a blocker.

### Phase 1 — Calculator 1 (square meters → cartons/pallets)

**`test/calculators/square_meters_to_cartons_calculator_test.dart`** — pure
calculation logic, no widgets involved:

- 100 m², 60×60cm tile, 4 tiles/carton, no waste → 70 required cartons,
  100.8 m² delivered (the spec's required test case 1).
- Same, with 5% waste → 73 required cartons, 105.12 m² delivered (test
  case 2).
- 73 required cartons with 40 cartons/pallet → 1 full pallet + 33 extra
  cartons (test case 3).
- Omitting cartons-per-pallet leaves the pallet breakdown `null` (not
  zero) and doesn't change `requiredCartons` (test case 5).
- Exact-division boundary (50 m² over exactly 50 cartons' worth of area)
  doesn't round up an unneeded extra carton — guards against floating-point
  drift near a whole number.
- Zero waste percentage produces the same result as omitting waste
  entirely.

**`test/calculators/numeric_input_test.dart`** — the parsing/validation
helpers in `lib/calculators/common/numeric_input.dart`:

- Zero, negative, empty, `null`, and non-numeric text are all rejected by
  `parsePositiveDouble` / `parsePositiveInt` (test case 4).
- `parseNonNegativeDouble` accepts `0` (needed for waste percentage) but
  still rejects negative and non-numeric text.
- `parsePositiveInt` rejects decimals, since tile/carton counts are whole
  numbers.

**`test/calculators/square_meters_to_cartons_screen_test.dart`** — the
stateful screen wired up end-to-end (controllers, live recalculation,
clipboard-adjacent state, clear button), since the pure-logic tests alone
don't prove the UI calls them correctly:

- Filling in the four required fields live-updates the result card with the
  correct tile area, carton area, delivered area, and required cartons —
  with no result shown beforehand.
- Adding a cartons-per-pallet value reveals the full-pallets/extra-cartons
  rows with the correct numbers.
- Tapping "Clear" removes the result and empties the fields.
- An invalid required field (e.g. `0`) shows the localized "Enter a number
  greater than 0" message and withholds the result.

**Not covered by an automated test as of Phase 1** (fixed in Phase 3 — see
below): the copy-to-clipboard button's actual clipboard content, since
`flutter_test`'s default `TestWidgetsFlutterBinding` mocks platform channels
including `Clipboard.setData`. Phase 1 only exercised the button's
`onPressed` wiring via the "Result card exists" path, without asserting the
copied string.

### Phase 2 — Calculator 2 (cartons/pallets → square meters) + wording pass

**`test/calculators/cartons_to_square_meters_calculator_test.dart`** — pure
calculation logic:

- 10 cartons, 60×60cm tile, 4 tiles/carton, no pallets → 10 total cartons,
  40 total tiles, 14.40 m² (test case 1).
- 1 pallet + 30 cartons, 40 cartons/pallet → 70 total cartons, 280 total
  tiles, 100.80 m² (test case 2).
- 1 pallet + 33 cartons, 40 cartons/pallet → 73 total cartons, 105.12 m²
  (test case 3).
- Cartons-per-pallet provided alone (no pallets count) contributes nothing
  to the total and `hasPalletInfo` stays `false` — proves the "may be
  provided alone" half of the cross-field rule at the calculation layer.
- Both pallet fields omitted calculates from cartons alone (test case 6).

Test case 4 (invalid zero/negative required input) and test case 5
(pallets count without cartons per pallet) are validation-layer concerns,
not pure-function concerns — the pure function assumes pre-validated input,
same division of responsibility as Calculator 1. They're covered by the
screen-level tests below instead.

**`test/calculators/cartons_to_square_meters_screen_test.dart`** — the
stateful screen wired up end-to-end:

- Filling in the spec's example A (10 cartons, no pallets) live-shows the
  correct result; filling in example B (33 cartons + 1 pallet of 40) updates
  it to 73 total cartons / 105.12 m² and reveals the pallet breakdown rows.
- Tapping "Clear" removes the result.
- An invalid required field shows the friendly validation message (test
  case 4).
- **Pallets count filled without cartons per pallet** shows the specific
  "Enter cartons per pallet, or clear the pallets count" message and
  withholds the result — **without the user ever touching the
  cartons-per-pallet field directly** (test case 5). This specific "never
  touched" scenario matters: see "Cross-field validation" below.
- Cartons per pallet filled alone (no pallets count) is valid, shows no
  error, and doesn't affect the total.

**Cross-field validation implementation note:** `AutovalidateMode.onUserInteraction`
only re-validates a field once *that specific field* has been interacted
with (confirmed by reading `FormField`'s source in the Flutter SDK). Since
cartons-per-pallet's validity depends on *pallets count*'s value, a user who
fills in pallets count but never touches cartons-per-pallet would not have
seen the dependency error under plain `onUserInteraction` — the error would
silently wait until they happened to tap that field. Fixed by giving the
cartons-per-pallet field its own `GlobalKey<FormFieldState<String>>` and
calling `.validate()` on it directly from `_recalculate()` (which runs on
every keystroke in any of the six fields), forcing it to always reflect the
current cross-field state regardless of interaction history. The test above
specifically exercises the "never touched" path to guard against regressing
this.

**Shared widgets:** `NumberField`, `OptionalDivider`, and `ResultRow` were
extracted from Calculator 1's screen into
`lib/calculators/common/calculator_form_widgets.dart` during this phase
(they had become byte-identical duplicates once Calculator 2 needed the
same building blocks). Both screens' tests continue to pass unchanged after
this refactor, which is exactly the point of extracting truly-identical
code rather than hand-copying it.

**Wording pass:** many ARB string values changed in this phase (see
[I18N_PLAN.md](I18N_PLAN.md) for the full list), including Calculator 1's
field labels and result labels. `square_meters_to_cartons_screen_test.dart`
was updated to match (`'Requested area (m²)'` → `'Area needed (m²)'`); all
of Calculator 1's numeric assertions were re-verified passing unchanged,
confirming the wording pass didn't touch any calculation logic.

### Phase 3 — polish, validation hardening, release-readiness

**A real, pre-existing bug was found and fixed: premature "required" errors
across untouched fields.** A new test ("An empty required field shows the
required-field message" in `square_meters_to_cartons_screen_test.dart")
initially failed with *four* matches for "This field is required" after
touching only *one* field. Root cause, confirmed by reading
`Form`/`FormField`'s source directly
(`C:\src\flutter\packages\flutter\lib\src\widgets\form.dart`): `Form`'s own
`build()` treats `autovalidateMode` as a form-wide gate — once *any* field
has been interacted with, it calls the public, unconditional `validate()`
on *every* registered field on the next rebuild, regardless of that
field's own interaction state. `TextFormField`'s own `autovalidateMode`
separately defaults to `disabled` when not set explicitly, and does *not*
inherit the ambient `Form`'s value. The combination — `onUserInteraction`
set on the `Form`, nothing set on each field — meant typing into the first
field immediately flashed "required" on every other empty required field.
This has been present since Phase 1; no earlier test happened to check the
"some required fields filled, others still empty" intermediate state,
since the existing "fills in all four fields" test never paused to look in
between. Fixed by moving `autovalidateMode: AutovalidateMode.onUserInteraction`
from `CalculatorScreenScaffold`'s `Form` (removed — falls back to `Form`'s
own default, `disabled`) to each `NumberField`'s `TextFormField` (added
explicitly). See [UI_DESIGN_PLAN.md](UI_DESIGN_PLAN.md) for the full
writeup. The cross-field `GlobalKey`-based validation added in Phase 2
(described above) is unaffected — it calls `.validate()` directly and was
never dependent on either autovalidateMode setting.

**`test/responsive_layout_test.dart`** *(new)* — pumps the home screen and
both calculators, with a full result showing (pallet breakdown included,
the densest state), at three surface sizes (`360×800` mobile, `768×1024`
tablet, `1280×800` desktop) via `tester.binding.setSurfaceSize`, asserting
`tester.takeException()` is `null` at each. The home screen is additionally
checked in Arabic (RTL) at all three sizes. 12 tests total. This is what
"reviewed the UI at mobile/tablet/desktop widths" means concretely for this
project — see [UI_DESIGN_PLAN.md](UI_DESIGN_PLAN.md) for the full table.

**`test/calculators/numeric_input_test.dart`** — two new cases: a
400-digit numeral (still just digits, so it would pass the input
formatter) is rejected by both `parsePositiveDouble` and
`parseNonNegativeDouble`, since it numerically overflows a `double` to
`Infinity`. Guards a real crash: `Infinity` used to pass the `> 0` check,
then reach `.ceil()` in the calculator (which throws `UnsupportedError` for
non-finite values) with no `try`/`catch` anywhere in `lib/`.

**Both `*_calculator_test.dart` files** — one new "large but realistic
order" case each (e.g. ~1,000,000 m² / 500,000+ cartons), confirming large,
plausible commercial-scale inputs compute correctly and don't crash. These
stay well inside 64-bit `int` range (Dart's native `int` is a fixed 64-bit
two's-complement type, not arbitrary-precision) — see the "Known
limitations" note below on `NumberField`'s `maxLength: 9`.

**`test/widget_test.dart`** — two new tests: reopening a calculator after
navigating back to home starts genuinely fresh (no leftover values or
result from the previous visit — `Navigator.push` always builds a new
widget/State, so this was already correct by construction, but is now
regression-tested); and switching language after visiting a calculator,
then reopening it, works correctly in the new language with no crash and
no leftover state from the previous language's session.

**Both `*_screen_test.dart` files** — an explicit "empty required field"
test (previously only zero/negative were asserted, not genuinely empty),
and a clipboard-content test that mocks `SystemChannels.platform`'s
`Clipboard.setData` method call to capture the actual copied string,
asserting it contains the app name, every main input, and the final
result — then changes a field and copies again, asserting the second copy
differs from the first and reflects the new value (guards against a stale
snapshot). This directly closes the Phase 1 "not covered" gap noted above.

**Copy-result content rework:** both calculators' clipboard text was
rebuilt to include the app name, every main input (previously several were
missing — see [PROJECT_HISTORY.md](../PROJECT_HISTORY.md) for the
before/after), and the result. Three new ARB keys support this — see
[I18N_PLAN.md](I18N_PLAN.md).

**Shared widgets grew by two:** `CalculatorScreenScaffold` (the whole
screen shell) and `ResultHero` (the big headline number), on top of
Phase 2's three. Both were previously duplicated verbatim between the two
calculator screens. See [UI_DESIGN_PLAN.md](UI_DESIGN_PLAN.md).

### Phase 4 — Calculator 2 validation fix (pallets-only support) + Arabic wording

**The bug:** Calculator 2 required "cartons count" even when a shop worker
wanted to calculate from pallets alone (a very common real order). Fixed by
making both "extra cartons" (renamed from "cartons count") and pallets
count independently optional, with a new rule requiring at least one of the
two to be `> 0`. See [CALCULATION_RULES.md](CALCULATION_RULES.md) for the
exact input rules and formula (unchanged arithmetic — `cartonsCount` simply
defaults to `0` instead of being required at the type level).

**`cartons_to_square_meters_calculator.dart` model change:**
`CartonsToSquareMetersInput.cartonsCount` changed from a required `int` to
an optional `int?`, and `CartonsToSquareMetersResult` gained a
`cartonsPerPallet` field (previously only echoed via the input controller's
raw text in the clipboard builder, not stored on the result at all — needed
now that it's also an on-screen result row).

**`test/calculators/cartons_to_square_meters_calculator_test.dart`** — one
new test, added first as the flagship Phase 4 case: pallets only (60×60cm
tile, 4 tiles/carton, `cartonsCount` omitted entirely, 2 pallets × 40
cartons/pallet) → 80 total cartons, 320 total tiles, 115.20 m². All six
pre-existing tests were re-verified passing unchanged (`cartonsCount:` is
still a valid named constructor argument when passed explicitly, so none of
them needed edits).

**`test/calculators/cartons_to_square_meters_screen_test.dart`** — rewritten:

- Every `_enterText(tester, 'Cartons count', ...)` call became `'Extra
  cartons'`, matching the renamed field label.
- *(New)* "Calculating from pallets alone (no extra cartons) works" —
  the screen-level counterpart to the flagship calculator-level test above,
  proving the fix end-to-end through real widget interaction rather than
  only the pure function.
- *(Reworked)* The old "invalid required input" test (typed `0` into the
  now-required "Cartons count" field, expected "Enter a number greater than
  0") no longer makes sense now that `0`/empty is valid for that field on
  its own. Replaced with "Leaving both extra cartons and pallets count at
  0/empty shows a friendly validation message and no result", which types
  `0` into extra cartons (pallets count is never touched) and expects the
  new `calc2ValidationCartonsOrPalletsRequired` message ("Enter cartons or
  pallets count").
- The existing "pallets count without cartons per pallet" and "cartons per
  pallet alone" tests needed only the label rename — their underlying logic
  and expected messages were already correct and unaffected by the fix.

**A non-obvious text collision, worth flagging for future edits to this
file:** the renamed field label `calc2FieldExtraCartonsLabel` ("Extra
cartons") is now the **exact same string** as the pre-existing result-row
label `resultExtraCartons` ("Extra cartons", shared with Calculator 1, and
already used by Calculator 2 before Phase 4). Before the rename these were
different strings ("Cartons count" vs. "Extra cartons") with no collision.
Now, whenever a result is showing *and* pallets are in use *and* extra
cartons is `> 0`, `find.text('Extra cartons')` matches **twice** — the
field's own label plus the result row — so the mixed-scenario assertion in
the first test uses `findsNWidgets(2)` with an explanatory comment rather
than `findsOneWidget`. The pallets-only test (extra cartons `== 0`, so the
result row stays hidden) correctly still uses `findsOneWidget`.

**`test/widget_test.dart`** and **`test/responsive_layout_test.dart`** —
one-line label updates each (`'Cartons count'` → `'Extra cartons'`); no
behavioral changes needed.

**`test/l10n/arabic_pallet_wording_test.dart`** *(new file)* — the "Arabic
wording test if practical" the project owner asked for. Rather than pumping
`MyApp` in Arabic and searching the widget tree (which would couple the
test to which screens happen to show which strings, and to font/bidi
rendering), it instantiates the generated `AppLocalizationsAr` class
directly and checks specific getters for the combined term — a plain Dart
object test, no widget tree needed. Checks for the two root words ("باليت"
and "مشتاح"/"مشاتيح") appearing together rather than one rigid contiguous
substring, since Arabic grammar prepends "ال" ("the") to *each side* of the
slash when the phrase is definite (e.g. "الباليتات/المشاتيح"), which would
break a naive `contains('باليتات/مشاتيح')` check on roughly half of the
affected strings. See [I18N_PLAN.md](I18N_PLAN.md) for the full decision
record.

**Also fixed:** `square_meters_to_cartons_screen.dart` (Calculator 1) had
one stale reference to `clipboardCartonsPerPalletLabel`, the ARB key
renamed to `resultCartonsPerPalletLabel` as part of this phase's Calculator
2 result-card change (the key is shared across both calculators' clipboard
builders). Caught immediately by `flutter analyze`, not by a test — a
reminder that `flutter analyze` after an ARB rename is not optional even
when the rename's *purpose* was specific to one screen.

**Test count:** 70 tests total, all passing (`flutter test`), after this
phase's changes.

### Phase 5 — Windows release build verification

Phase 5 added no new `flutter test` cases (there's no meaningful unit/widget
test for "does a release binary launch" — that's inherently a manual/process
check, not something `flutter_test`'s headless harness exercises). Instead,
release-readiness was verified as a build-and-launch process:

1. `flutter analyze` and `flutter test` were run **and confirmed passing
   first**, before attempting a build — a release build on top of failing
   checks would just be a fast way to ship a known-broken binary.
2. `flutter clean` was run before the release build specifically to catch a
   real (if harmless) stale-artifact issue: an empty
   `data\flutter_assets\packages\cupertino_icons\` folder was still present
   in `build\` from before that dependency was removed in Phase 3.
   `flutter build windows` alone does not clear out asset directories that
   are no longer referenced, so a "clean" release build needs an actual
   `flutter clean` first, not just a rebuild on top of an old `build\`
   directory. Confirmed absent after the clean rebuild.
3. `flutter build windows --release` was run and its output inspected
   directly (`Get-ChildItem` on `build\windows\x64\runner\Release\`) rather
   than just trusting the "Built ..." success message — confirming exactly
   which files exist and their sizes (documented in
   [README.md](../README.md#building-a-windows-release)).
4. **`tilemate.exe` was actually launched** from inside the built `Release`
   folder (`Start-Process`, then confirmed the process was still running a
   few seconds later with `Get-Process`, then stopped it). This is a real
   smoke test, not an assumption — it's what justifies telling the project
   owner in the README that the app "works" from that folder, as opposed to
   just "the build command exited 0."

This is intentionally a manual/scripted process check rather than an
automated `flutter test` case: there's no reasonable way to launch and
assert on a native Windows GUI process from within `flutter_test`'s
headless widget-testing harness, and building a custom launch-and-probe
test harness for a one-off release verification would be over-engineering
relative to the actual risk.

### Phase 6 — Arabic default language, quick-choice chips, wording polish

**Arabic became the app's default language** (see
[I18N_PLAN.md](I18N_PLAN.md)). `MyApp` gained an `initialLocale` parameter
(defaulting to `Locale('ar')`) specifically so tests can start directly in
a given language without first driving the switcher UI — most tests now
pump `const MyApp()` and get Arabic, matching real startup behavior.

**Every test file that navigates or asserts on-screen text had to be
updated**, since `find.text('m² → Cartons')`-style lookups against the old
English-by-default app no longer matched anything once the default became
Arabic:

- **`test/widget_test.dart`** — rewritten. The default-language test now
  asserts Arabic + RTL; the old "switch to Arabic" test became "switch to
  English" (the direction that actually changes behavior now); "switch to
  Hebrew" is unchanged in spirit. Calculator-navigation and
  reopen-starts-fresh tests now drive the app in Arabic directly (its real
  default), and the language-switch-then-reopen test now starts in Arabic
  and switches to English (inverse of before Phase 6).
- **`test/responsive_layout_test.dart`** — the Calculator 1/2 overflow
  checks now fill the form and assert result labels in Arabic, which is
  arguably a better regression guard than the old English version: Arabic
  strings are often longer (e.g. "باليتات/مشاتيح كاملة" vs. "Full
  pallets"), so overflow is more likely to surface there first. The old
  "Home screen in Arabic (RTL)" per-size check was replaced with "Home
  screen switched to English (LTR)," since Arabic overflow is now already
  covered by the (Arabic-by-default) calculator checks in the same file.
- **`test/calculators/square_meters_to_cartons_screen_test.dart`** and
  **`test/calculators/cartons_to_square_meters_screen_test.dart`** — left
  otherwise untouched (all their detailed validation/cross-field-edge-case
  assertions still read as before) by pumping
  `const MyApp(initialLocale: Locale('en'))` instead of `const MyApp()`.
  These files test screen *wiring* (controllers, live recalculation,
  validation timing), not language-specific wording, so pinning English
  avoided translating dozens of assertions for no additional coverage.
- **A real, unrelated bug surfaced by this work:** `WidgetTester.pageBack()`
  looks for a back button by its **English** tooltip text ("Back"), falling
  back to `CupertinoNavigationBarBackButton` if that's not found — neither
  matches a Material `BackButton` under an Arabic `MaterialLocalizations`
  tooltip (e.g. "رجوع"). `test/widget_test.dart`'s two tests that navigate
  back to home now tap `find.byType(BackButton)` directly instead, which is
  locale-independent. Worth remembering for any future test that navigates
  back while not in English.

**New test coverage, not just migrated:**

- **`test/l10n/arabic_default_examples_test.dart`** *(new)* — re-runs both
  calculators' approved example results directly against the real Arabic
  default (no language switch first), so the required numbers
  (73 cartons/105.12 m² for Calculator 1; 80 cartons/320 tiles/115.20 m² for
  Calculator 2) are proven to hold in the actual out-of-the-box experience,
  not only in the English-pinned screen-wiring tests. Also mocks
  `Clipboard.setData` to inspect the Arabic copy-result text directly,
  asserting it contains the app name, calculator type, tile size, entered
  quantities, and the final result/pallet breakdown — the concrete check
  behind Phase 6's "clean WhatsApp-paste" requirement.
- **`test/calculators/quick_choice_chips_test.dart`** *(new)* — tapping a
  tile-size chip fills both the length and width fields with the right
  values (including a non-square preset, "120×60", to prove the two fields
  can differ); tapping a different chip afterward overwrites the previous
  values; manual typing into a field still works after a chip was tapped
  (chips are a shortcut, never a lock); Calculator 1's waste chips fill the
  waste field; Calculator 2 shows no waste chips (it has no waste field).
  One practical finding while writing this: the waste-chip row sits below
  the fold in the default 800×600 test surface, and `tester.tap()` (unlike
  `tester.enterText()`) needs the target actually scrolled into view first
  — fixed with `tester.ensureVisible()` before the tap, the same pattern
  already used for the "Clear"/"Copy result" buttons in earlier phases.

**Wording changes needing no test changes:** the `homeTagline` Arabic value
change (see [I18N_PLAN.md](I18N_PLAN.md)) isn't asserted by any existing
test (no test checked that specific string before or after), so no test
needed updating for it.

**Test count:** 74 tests total, all passing (`flutter test`), up from 70 at
the end of Phase 5. `flutter analyze` remains at 0 issues.

### Phase 7 — ArtCasa Tiles branding

Phase 7 was a light branding change (`appTitle` → "ArtCasa Tiles", plus a
logo on the home screen) with no calculator logic touched. Five existing
assertions needed updating simply because they checked for the literal
string "TileMate", which no longer appears anywhere in the app:
`test/widget_test.dart`, `test/responsive_layout_test.dart` (both check
`find.text` for the app-bar title), and three clipboard-content checks
(`test/l10n/arabic_default_examples_test.dart` ×2,
`test/calculators/square_meters_to_cartons_screen_test.dart` ×1) that
assert the copied result text contains the app name.

**`test/branding_test.dart`** *(new)* — three tests specifically for the
new branding, checking it's additive rather than disruptive:

- "ArtCasa Tiles" and the logo image both show on the home screen in
  Arabic (the default), alongside the existing "حاسبة البلاط" tagline.
- Both persist correctly after switching to English and to Hebrew (the
  brand name/logo are locale-independent — same asset, same string,
  regardless of which language is active) — the language switcher itself
  still works.
- Both calculators still open and function normally with the new home
  screen in place.

**`test/responsive_layout_test.dart`** also gained one assertion
(`expect(find.byType(Image), findsOneWidget)`) inside the existing "Home
screen (Arabic default) has no overflow" check, confirming the logo
specifically survives the no-overflow check at all three screen widths,
not just the text around it.

**Visual verification beyond widget-tree assertions.** Since this phase is
a visible UI change, the rendered home screen was actually captured as an
image (via a scratch `matchesGoldenFile` test, not committed) at a mobile
size in both light and dark theme, and viewed directly rather than only
trusting `find.byType(Image)`/no-overflow assertions. This caught a real
Flutter *testing*-environment quirk worth recording: on the very first
`pumpWidget` in a fresh test process, `Image.asset`'s underlying
`rootBundle` load didn't finish decoding before `pumpAndSettle()` returned,
so the captured frame showed an empty white card — purely a widget-test
timing artifact (confirmed by wrapping the pump in
`tester.runAsync(() => Future.delayed(...))` to let the real async asset
decode complete, after which the logo rendered correctly; a second test in
the same process, with the image already warm in `imageCache`, rendered
correctly even without the extra wait). This is not a real app bug — an
actual running app repaints automatically once an asset finishes decoding,
typically within a single imperceptible frame — but it's a reason none of
this project's permanent tests assert pixel-perfect golden images of
`Image.asset` content; the existing `find.byType(Image)` presence check
plus a manual on-device look is the more reliable combination.

**Test count:** 77 tests total, all passing (`flutter test`), up from 74
at the end of Phase 6. `flutter analyze` remains at 0 issues.

### Phase 8 — ArtCasa Tiles native app name and launcher icon

Phase 8 touched no Dart code and no calculator logic at all — every change
was either a new binary asset (`assets/branding/artcasa_icon.png`), a
native platform file (`AndroidManifest.xml`, `windows/runner/main.cpp`,
`windows/runner/Runner.rc`), or build tooling config
(`flutter_launcher_icons` in `pubspec.yaml`). Consequently there are no new
`flutter test` cases this phase — same reasoning as Phase 5's Windows
release-build verification: there's no meaningful widget/unit test for "is
the native window title X" or "does the launcher icon look like Y," so
verification was a build-and-inspect process instead, run in this order:

1. `flutter analyze` — confirmed 0 issues, **before** touching any native
   file, to establish a clean baseline.
2. `flutter test` — confirmed all 77 tests passing before any change (the
   same 77 from the end of Phase 7 — Phase 8 added none, since nothing
   Dart-level changed for them to cover).
3. Icon-only asset created and visually checked at 344×344 (full size) and
   downscaled previews at 48/96/192px (typical launcher icon sizes) —
   confirmed the house/tile symbol stays legible at all of them — *before*
   wiring it into any build config.
4. `flutter pub add --dev flutter_launcher_icons`, then
   `dart run flutter_launcher_icons` — regenerated
   `android/app/src/main/res/mipmap-*/ic_launcher.png` (all 5 densities)
   and `windows/runner/resources/app_icon.ico`. Output confirmed via
   `find ... -newer pubspec.yaml` (all 5 Android PNGs and the Windows ICO
   had fresh timestamps) and by viewing the largest Android PNG directly.
5. `flutter analyze` and `flutter test` **re-run after** the native
   manifest/resource edits — still 0 issues, still 77/77 passing (expected,
   since none of these files are part of the Dart analysis/test graph, but
   confirmed rather than assumed).
6. `flutter build windows --release` — **failed on the first attempt**
   with `LNK1104: cannot open file '...\tilemate.exe'` (a locked-file
   linker error, not a code problem — `tasklist` confirmed no `tilemate.exe`
   process was actually running at the time, so this was most likely a
   transient lock, e.g. from antivirus scanning the previous build's binary
   or a stale intermediate object). Fixed by `flutter clean` (removes
   `build\` entirely) followed by `flutter pub get` and a retry, which
   succeeded — same "clean before a release build" lesson Phase 5 already
   documented for a different symptom (stale `cupertino_icons` assets);
   worth remembering as a general "if a Windows release build fails with a
   link/file-lock error, `flutter clean` first" note.
7. **Actually launched the built `tilemate.exe`** (not just trusted the
   build's success message) via `Start-Process`, confirmed via
   `Get-Process` that it was running, and read back its live
   `MainWindowTitle` property — it was exactly `"ArtCasa Tiles"`, proving
   the `main.cpp` change took effect in a real running process, not just in
   source. A full-screen screenshot was also captured and viewed directly:
   confirmed the title bar reads "ArtCasa Tiles", the title-bar/taskbar
   icon shows the new house/tile mark (not Flutter's default), and the
   home screen behind it still shows the full ArtCasa Tiles logo card, the
   Arabic "حاسبة البلاط" tagline, and both calculator cards, in Arabic (the
   default) — i.e. nothing about the actual app UI regressed. The process
   was then stopped and the screenshot deleted (a one-time verification
   aid capturing the reviewer's own desktop, not a repo artifact).

**Test count:** unchanged at 77 (all passing); `flutter analyze` unchanged
at 0 issues. No Android APK build was attempted — not required by this
phase's brief, and the Android SDK's presence/readiness in this sandbox
wasn't re-verified since the manifest-only label change doesn't need a full
build to validate (XML is either well-formed or `flutter analyze`'s
underlying build tooling would have already flagged a gross error, which it
didn't).

## Environment constraints (current dev sandbox)

This machine has the Flutter SDK and, as of Phase 5, **Visual Studio with
the "Desktop development with C++" workload** installed — `flutter build
windows` and on-device Windows runs are now both possible here (confirmed
by Phase 5's build). The Android SDK is still **not** installed, so an
Android on-device/emulator run still cannot be performed in this sandbox;
`flutter test`/`flutter analyze` remain the verification method for
Android-relevant logic (which is all platform-independent Dart/widget code
anyway — nothing in this app is Android-specific).

The project owner has manually verified Phase 0, Phase 1, Phase 2, and
Phase 4 running on Windows, and Phase 5's Windows release build specifically
(see [PROJECT_HISTORY.md](../PROJECT_HISTORY.md)). **Phase 3's changes have
not yet had an equivalent dedicated manual on-device pass** — treat that as
a standing open follow-up. Run `flutter doctor` to see what's available
locally. iOS still requires a Mac with Xcode regardless of environment —
that has not changed and was not in scope for Phase 5.

## Planned test coverage for later phases

Both calculators are now implemented; no further calculators are planned
(see [PRODUCT_SPEC.md](PRODUCT_SPEC.md) — the product is fixed at exactly
two). Remaining gaps are about hardening what exists, not building more:

### Validation — remaining gaps

- Non-numeric text pasted into a field (vs. simply zero/negative) — covered
  indirectly since `double.tryParse`/`int.tryParse` reject it the same way,
  but not asserted via a widget test.
- The extreme, deliberately-adversarial case of filling *every* numeric
  field with its 9-digit maximum simultaneously (chained multiplication —
  e.g. `totalCartons * tilesPerCarton` in Calculator 2 — could still
  exceed 64-bit `int` range if every factor is maxed at once). This
  produces a silently wrong number, not a crash, and requires input no
  real shop order would ever produce; documented as an accepted limitation
  in [PROJECT_PROGRESS.md](../PROJECT_PROGRESS.md) rather than chased with
  more validation complexity. Revisit only if real usage ever suggests
  otherwise.

### Widget/integration tests

- *(Done as of Phase 6)* Both calculators' form-filling now runs in Arabic
  by default across `test/responsive_layout_test.dart`,
  `test/l10n/arabic_default_examples_test.dart`, and
  `test/calculators/quick_choice_chips_test.dart` — covering the exact
  gap this bullet used to describe. **Still not done: Hebrew.** Neither
  calculator has been form-filled and asserted specifically in Hebrew (only
  the home screen, via `test/widget_test.dart`'s Hebrew-switch test). Since
  neither calculator uses any calculator-specific `Directionality` handling
  and the RTL mechanism itself is proven app-wide, the risk is low, but a
  real visual check in Hebrew is still recommended before shipping.

### Golden tests (optional, consider once visual design stabilizes)

Snapshot the home screen and both calculator screens in LTR and RTL to catch
unintended visual regressions early.
