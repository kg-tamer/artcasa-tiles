# TileMate — Internationalization Plan

## Approach

TileMate uses Flutter's official localization pipeline: ARB source files plus
the `gen-l10n` code generator. No third-party i18n package is used — Flutter's
own tooling is sufficient for a string set this size and keeps the dependency
list minimal, in line with the project's overall simplicity goal.

- **Source of truth:** `lib/l10n/app_en.arb` (template), `app_ar.arb`,
  `app_he.arb`.
- **Generated code:** `lib/l10n/generated/` — produced by `flutter gen-l10n`,
  configured via `l10n.yaml` at the project root, and **git-ignored** (see
  `.gitignore`). It regenerates automatically before `flutter run` /
  `flutter build` because `pubspec.yaml` sets `generate: true`, and can be
  regenerated manually at any time with `flutter gen-l10n`.
- **Access pattern:** `AppLocalizations.of(context).someKey` anywhere a
  `BuildContext` is available. The generated getter is non-nullable
  (`nullable-getter: false` in `l10n.yaml`), so no null-check or `!` is
  needed at call sites.

No visible string is ever hardcoded in a widget. If a string needs to change,
it changes in the ARB files, not in Dart code.

## l10n.yaml configuration

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-dir: lib/l10n/generated
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
```

Note: as of the Flutter version this project was built against (3.44.4),
`--synthetic-package` is deprecated and cannot be enabled — generated files
are always written to a real, importable directory (`output-dir`), which is
what this config already does.

## Supported locales

| Locale | Language | Direction |
|--------|----------|-----------|
| `en`   | English  | LTR       |
| `ar`   | Arabic   | RTL       |
| `he`   | Hebrew   | RTL       |

`AppLocalizations.supportedLocales` (generated) is the single source of truth
passed into `MaterialApp.supportedLocales` — see `lib/app.dart`. Adding a
fourth language later means adding one more `.arb` file plus generation; no
other code changes are required.

## Locale resolution and switching

**Phase 6: Arabic is now the app's default language**, deliberately *not*
the device's system locale. `MyApp` (`lib/app.dart`) takes an
`initialLocale` parameter defaulting to `const Locale('ar')`; `_MyAppState`
copies it into `_locale` in `initState()`. There is no
`localeListResolutionCallback` anymore — Phase 0–5 used one to walk the
device's preferred-locale list and fall back to English, but the explicit
brief for Phase 6 was "do not use system locale as the default if it causes
English/Hebrew to open first," so that callback (which is only ever
consulted by `MaterialApp` when `locale` is `null`) was removed as dead code
rather than left unreachable.

- Picking a language from the in-app switcher calls `setState` to pin
  `_locale` explicitly, which overrides the current session's language —
  this part is unchanged from Phase 0.
- **This selection is intentionally not persisted.** No `shared_preferences`,
  no file, no storage of any kind — restarting the app always returns to
  Arabic (`initialLocale`'s default), never to whatever the user last picked.
  This matches the product's "no storage unless explicitly requested" rule
  (see [CLAUDE_RULES.md](CLAUDE_RULES.md)) and Phase 6's explicit instruction
  not to persist language choice. If persistence is wanted later, it must be
  an explicit request, not an assumed enhancement.
- **`initialLocale` exists mainly for testability.** Most widget tests now
  pump `const MyApp()` and get Arabic, matching real startup behavior. The
  two large calculator screen-wiring test files
  (`test/calculators/square_meters_to_cartons_screen_test.dart`,
  `test/calculators/cartons_to_square_meters_screen_test.dart`) pump
  `const MyApp(initialLocale: Locale('en'))` instead — those tests exercise
  validation/calculation wiring, not language-specific wording, so pinning
  English keeps their existing (extensive) assertions unchanged rather than
  translating every message into Arabic for no added coverage. Arabic-default
  behavior itself is covered separately by `test/widget_test.dart` and
  `test/l10n/arabic_default_examples_test.dart`.

## RTL / LTR handling

Flutter derives text direction from the active locale automatically through
`GlobalWidgetsLocalizations` — Arabic and Hebrew are recognized RTL languages
out of the box. **No manual `Directionality` widget or per-widget RTL
handling was added or should be needed**; `MaterialApp` + `supportedLocales`
is sufficient. This is verified directly in `test/widget_test.dart`, which
asserts `Directionality.of(context)` flips to `TextDirection.rtl` after
switching to Arabic or Hebrew, and stays `TextDirection.ltr` for English.

One caveat carried forward from Phase 0: numeric input and output should
still display digits in standard left-to-right digit order even inside an
RTL sentence (Unicode's bidi algorithm handles this correctly for plain
digit runs by default). Both calculators' result cards use plain Western
Arabic numerals (e.g. `"70"`, `"100.80 م²"`) with no Eastern Arabic numeral
formatting attempted, matching how numeric keypads behave in `ar`/`he`
locales in practice. This has not yet had a real visual check on an
Arabic/Hebrew device — the automated tests confirm the correct localized
strings render, not that the bidi layout looks right at a glance. Add this
to the manual verification pass before shipping.

## Language switcher

`lib/widgets/language_switcher.dart` is a `PopupMenuButton<Locale>` in the
home screen's app bar (`Icons.language`), listing every entry in
`AppLocalizations.supportedLocales` by its **native name** (e.g. "العربية",
not "Arabic"), with a checkmark on whichever locale is currently active. Native
language names are themselves ARB keys (`languageNameEnglish`,
`languageNameArabic`, `languageNameHebrew`) and are defined identically
(same literal value) in all three `.arb` files, since a language's name in
its own script doesn't change based on the app's current locale.

## Wording philosophy (revised in Phase 2)

Phase 2 included a deliberate pass over every ARB string to make the app
read like a fast shop tool, not a translated spec document. This wasn't a
one-off cleanup — treat it as the standing bar for any new string:

- **English:** short, plain labels. Prefer "Area needed" over "Requested
  area," "Waste % " over "Waste percentage." Match the tiling trade's own
  vocabulary where that vocabulary *is* the plain option (e.g. "waste" is
  standard, correct tiler terminology in English, not jargon — it was kept
  as-is, unlike its Arabic counterpart below).
- **Arabic:** natural, everyday Arabic over formal/classical constructions,
  without dropping into a specific regional dialect (the app doesn't know
  which region a shop is in). Concretely: "احتياط" (allowance/reserve)
  instead of "الهالك" (waste/loss) — same practical meaning, softer and
  more natural in a shop context; "المتر المطلوب" (the requested meter)
  instead of "المساحة المطلوبة" (the requested area) — tradespeople
  colloquially say "متر" (meter) to mean square meters of tiling; "الزيادة"
  (the excess) instead of "المساحة الزائدة" (the excess area). Titles for
  both calculators were rewritten as short "احسب من X لـ Y" (calculate from
  X to Y) phrases rather than literal translations of the English arrow
  notation.
- **Hebrew:** short, practical labels over formal/academic ones. E.g.
  "שדה חובה" (required field) instead of "שדה זה הוא חובה" (this field is
  an obligation); "שטח בפועל" (actual area) instead of "שטח בפועל שיסופק"
  (the area that will actually be supplied); card subtitles rewritten as
  casual questions ("כמה קרטונים צריך" — "how many cartons are needed")
  instead of formal imperative sentences.

None of this touched *which* keys exist for the calculation-critical
strings (labels, not values) — only the wording. See
[PROJECT_HISTORY.md](../PROJECT_HISTORY.md) for the specific before/after
list.

**Phase 3 re-review:** every string was checked again against this same
bar (plus a fresh "use consistent terms" checklist for Arabic —
كرتونة/carton, متر/meter, الاحتياط/allowance, الزيادة/excess). All four of
those were already the established terms from Phase 2; no wording changes
were needed as a result of the re-review itself. The concrete Phase 3
wording work was the three new `clipboard*` keys below, needed because the
copy-to-clipboard text gained several inputs it wasn't previously echoing.

**Phase 4:** two wording changes, both Arabic-specific in spirit even
though one touched all three languages. First, every Arabic key that
referred to pallets was updated to the combined local/shop term
"باليت/مشتاح" (see the resolved note below — this was a follow-up to an
item Phase 3 deliberately left unresolved rather than guess at). Second,
Calculator 2's loose-cartons field was renamed in all three languages from
"Cartons count" (implies a required field) to "Extra cartons" (reads
correctly now that it's optional) — English "Extra cartons", Arabic
"كراتين إضافية", Hebrew "קרטונים נוספים" (this Hebrew value already existed
as `resultExtraCartons`; reused as-is for consistency between the field
label and the result row that echoes it).

> **✅ Resolved in Phase 4: "مشتاح" was a real local/shop term, not a
> typo.** Phase 3 flagged "مشتاح" as unrecognized (see the git history of
> this file for the original warning) and deliberately left it unapplied
> rather than guess. The project owner confirmed in Phase 4: it's the
> colloquial shop-floor word tilers use alongside the standard word
> "باليت" (pallet) — both are in real use, and shop workers expect to see
> both. The resolution is to use the **combined form** everywhere the app
> talks about pallets, rather than picking one over the other:
>
> - Singular/general: **"باليت/مشتاح"**
> - Plural (reads more naturally in some phrases): **"باليتات/مشاتيح"**
>
> Arabic grammar adds its own "ال" ("the") definite-article prefix to each
> side of the slash when the surrounding phrase is definite — e.g.
> "الباليتات/المشاتيح" ("the pallets/crates") vs. the bare indefinite
> "باليتات/مشاتيح" used adjectivally (e.g. "باليتات/مشاتيح كاملة", "complete
> pallets/crates"). Both forms are correct Arabic and both count as "using
> the combined term" — see `test/l10n/arabic_pallet_wording_test.dart`,
> which checks for the two root words appearing together rather than one
> rigid contiguous string.
>
> Applied to every key that previously said only "باليت"/"باليتات":
> `fieldCartonsPerPalletLabel`, `calc1FieldCartonsPerPalletHelper`,
> `calc2FieldPalletsCountLabel`, `calc2FieldPalletsCountHelper`,
> `calc2FieldCartonsPerPalletHelper`,
> `calc2ValidationCartonsPerPalletRequired`,
> `calc2ValidationCartonsOrPalletsRequired`, `resultFullPallets`,
> `resultCartonsPerPalletLabel`, and `clipboardPalletsCountLabel`.
>
> **Deliberately not applied to English or Hebrew** — the project owner
> was explicit that "مشتاح" is a local Arabic shop term, not something to
> force into the other two languages. English and Hebrew keep their
> existing plain, practical pallet wording unchanged (e.g. English "Pallets
> count", Hebrew "כמות משטחים").
>
> Also **not applied to the extra/manual-cartons keys**
> (`calc2FieldExtraCartonsLabel`/`...Helper`) — those describe loose
> cartons *not* part of a pallet, so combining in the pallet term there
> would be actively confusing. Arabic uses "كراتين إضافية" (extra cartons),
> plain and pallet-free, matching the project owner's suggested wording.

**Phase 6:** Arabic became the app's default language (see "Locale
resolution and switching" above), which prompted a fresh wording re-review
against a supplied preferred-term list: حاسبة البلاط، متر، كرتونة، كراتين،
باليت/مشتاح، باليتات/مشاتيح، الاحتياط، الزيادة، كراتين إضافية،
نسخ للواتساب/نسخ النتيجة. Almost every term was already in place from
Phases 2–4 (متر, كرتونة/كراتين, الاحتياط, الزيادة, كراتين إضافية,
باليت/مشتاح were all already used exactly as listed — see the key-by-key
list above). Two concrete decisions resulted:

- **`homeTagline` (Arabic only) changed from "حساب سريع لكمية البلاط" to
  simply "حاسبة البلاط"** ("Tile Calculator") — the one preferred term with
  no existing home. Reads as a one-line subtitle under the "TileMate" app
  title (a common app-name-plus-tagline pattern), is shorter (matching the
  "keep labels short" instruction), and is the most natural place for the
  phrase without duplicating it elsewhere or forcing it into a screen where
  it wouldn't fit (there's no other single generic "what is this app" label
  in the string set). English/Hebrew `homeTagline` were not touched —
  translations don't need to be literal restatements of each other, and
  neither language had an equivalent complaint to fix.
- **`copyResultButtonLabel` ("نسخ النتيجة") was kept as-is**, not changed to
  "نسخ للواتساب" ("Copy for WhatsApp") even though the brief offered both as
  options. The button copies generic text to the system clipboard — it has
  no WhatsApp-specific integration (Task 4 of Phase 6 explicitly ruled out
  adding a share package), so a user could just as easily paste the result
  into an SMS, a note, or another chat app. Labeling the button as if it
  were WhatsApp-specific would overpromise a feature that isn't there;
  "نسخ النتيجة" ("Copy result") accurately describes what actually happens
  and was already natural, casual Arabic.

No other Arabic string changed — the rest of the existing wording (result
labels, validation messages, field helpers) was re-checked against "simple,
short, suitable for a tile shop worker" and already met that bar from
Phases 2–4's own review passes.

**Phase 6 also added two new keys** for the quick-choice chips (see
[UI_DESIGN_PLAN.md](UI_DESIGN_PLAN.md)): `quickSizesLabel` ("Common sizes" /
"أحجام شائعة" / "מידות נפוצות") and `quickWastePercentLabel` ("Quick
allowance" / "احتياط سريع" / "פחת מהיר"). The chip values themselves
("60×60", "0%", etc.) are **not** ARB keys — they're plain digits and a
multiplication/percent sign, not language-dependent text, the same
reasoning that already applies to every other formatted number in the app
(see `unitSquareMeters` usage in the calculator screens).

**Phase 7:** `appTitle`'s value changed from "TileMate" to **"ArtCasa
Tiles"** in all three locale files, kept identical across locales (same
pattern as before — a brand name isn't translated). This is a light-
branding change, not a wording *polish* — the app is now visibly branded
for the ArtCasa Tiles shop rather than showing the underlying codebase's
own name. No other ARB value changed this phase. See
[UI_DESIGN_PLAN.md](UI_DESIGN_PLAN.md) for the accompanying logo, and
[PROJECT_HISTORY.md](../PROJECT_HISTORY.md) for why "TileMate" itself
wasn't renamed (it remains the internal package/codebase name, never shown
to the end user).

**Phase 9:** added `brandSubtitle` ("للبلاط والسيراميك"), identical across
all three locale files for the same reason `appTitle` is — it's fixed
brand identity (the ArtCasa Tiles shop's own Arabic business descriptor,
as authored in the original logo), not translatable UI copy. No existing
key's *value* changed, only `homeTagline`'s on-screen *color* (now the
teal accent) — a widget-styling change, not a wording change, so it isn't
repeated here (see [UI_DESIGN_PLAN.md](UI_DESIGN_PLAN.md)).

## Current key inventory

Full descriptions are in `lib/l10n/app_en.arb` as `@key` metadata blocks.
As of Phase 2, keys used identically by both calculator screens no longer
carry a `calc1`-specific prefix (they were renamed when Calculator 2 was
built, so nothing is duplicated); keys specific to one calculator's own
concepts are prefixed `calc1`/`calc2` accordingly. `comingSoonTitle` and
`comingSoonMessage` were removed in Phase 2 — the placeholder screen they
served no longer exists.

### Home / shell

| Key                                | Purpose                                    |
|-------------------------------------|---------------------------------------------|
| `appTitle`                          | Visible brand name (app bar, OS task switcher, copied-result header) — "ArtCasa Tiles" as of Phase 7, was "TileMate" before |
| `brandSubtitle`                     | *(Phase 9)* Fixed Arabic business descriptor ("للبلاط والسيراميك") shown beside the icon in the home screen's brand header — identical in all three locale files, same treatment as `appTitle` |
| `homeTagline`                       | Home screen subtitle (purpose tagline, e.g. "حاسبة البلاط") — styled in the teal accent color as of Phase 9 |
| `homePrompt`                        | Home screen "pick a calculator" prompt       |
| `calculatorAreaToCartonsTitle`      | Calculator 1 card title (and its screen's app bar title) |
| `calculatorAreaToCartonsSubtitle`   | Calculator 1 card subtitle                   |
| `calculatorCartonsToAreaTitle`      | Calculator 2 card title (and its screen's app bar title) |
| `calculatorCartonsToAreaSubtitle`   | Calculator 2 card subtitle                   |
| `languageSwitcherTooltip`           | Language switcher tooltip/a11y label         |
| `languageNameEnglish`               | "English" in its own script                  |
| `languageNameArabic`                | "العربية" in its own script                  |
| `languageNameHebrew`                | "עברית" in its own script                    |

### Shared across both calculator screens

| Key                                     | Purpose                                    |
|-------------------------------------------|---------------------------------------------|
| `unitSquareMeters`                      | Per-locale area unit abbreviation appended to formatted values ("m²" / "م²" / `מ"ר`) — not a proper noun like the language names, so it's translated per locale rather than kept identical |
| `validationRequiredField`               | Shown when a required field is left empty    |
| `validationMustBeGreaterThanZero`       | Shown when a field's value is zero, negative, or non-numeric |
| `validationMustBeZeroOrGreater`         | Same, but for fields where `0` itself is a valid, meaningful entry: Calculator 1's waste field, and (Phase 4) Calculator 2's extra-cartons and pallets-count fields |
| `clearButtonLabel`                      | "Clear" button on the input card             |
| `copyResultButtonLabel`                 | "Copy result" button on the result card      |
| `resultCopiedMessage`                   | Snackbar shown after a successful copy       |
| `calculatorInputSectionTitle`           | Input card heading ("Enter your numbers") — renamed from `calc1InputSectionTitle` when Calculator 2 needed the same heading |
| `calculatorResultSectionTitle`          | Result card heading ("Result") — renamed from `calc1ResultSectionTitle` |
| `calculatorOptionalSectionLabel`        | Divider label between required and optional fields — renamed from `calc1OptionalSectionLabel` |
| `fieldTileLengthLabel` / `...Helper`    | Tile length field — renamed from `calc1FieldTileLengthLabel`/`...Helper` |
| `fieldTileWidthLabel` / `...Helper`     | Tile width field — renamed from `calc1FieldTileWidthLabel`/`...Helper` |
| `fieldTilesPerCartonLabel` / `...Helper`| Tiles-per-carton field — renamed from `calc1FieldTilesPerCartonLabel`/`...Helper` |
| `fieldCartonsPerPalletLabel`            | "Cartons per pallet (optional)" label — renamed from `calc1FieldCartonsPerPalletLabel`. Each screen supplies its **own helper text** (`calc1FieldCartonsPerPalletHelper` / `calc2FieldCartonsPerPalletHelper`), since the validation relationship differs (purely optional in Calculator 1; conditionally required by pallets count in Calculator 2) |
| `resultTileArea`, `resultCartonArea`    | Result row labels, identical concept in both calculators |
| `resultFullPallets`, `resultExtraCartons` | Result row labels for the pallet breakdown — computed in Calculator 1 (ceiling/remainder), directly entered and echoed back in Calculator 2. Same real-world meaning, same label |
| `resultCartonsPerPalletLabel`           | "Cartons per pallet" (no `"(optional)"` suffix). Originally `clipboardCartonsPerPalletLabel` (Phase 3, copied-text-only); renamed in Phase 4 when Calculator 2 started also showing it as an on-screen result row (see [UI_DESIGN_PLAN.md](UI_DESIGN_PLAN.md)) |
| `clipboardWastePercentLabel`            | *(Phase 3)* "Waste %" for the copied-text input echo |
| `clipboardPalletsCountLabel`            | *(Phase 3)* "Pallets count" for the copied-text input echo (Calculator 2) |
| `quickSizesLabel`                       | *(Phase 6)* Label above the common-tile-size quick-choice chips, shown on both calculators |
| `quickWastePercentLabel`                | *(Phase 6)* Label above the waste-percentage quick-choice chips, shown on Calculator 1 only |

**Why `clipboardWastePercentLabel`/`clipboardPalletsCountLabel` exist
instead of reusing the field labels:** `calc1FieldWastePercentLabel` and
`calc2FieldPalletsCountLabel` both have an `"(optional)"` suffix baked into
their value — correct and useful on the input *form*, where it tells the
user they may skip the field, but wrong once copied into a *report* of
values that were actually entered (`"Waste % (optional): 10"` reads oddly
once a value **has** been entered). Rather than stripping the suffix
programmatically (fragile, locale-dependent), each gets a clean,
non-suffixed counterpart used only by the clipboard text builders. Fields
that never had an `"(optional)"` suffix in the first place (tile length,
tile width, tiles per carton, extra cartons) don't need a separate
clipboard-only counterpart — their existing field/result label is reused
as-is. `fieldCartonsPerPalletLabel` did have the suffix and originally
followed the same pattern, but since Phase 4 its clean counterpart
(`resultCartonsPerPalletLabel`) is also used on-screen, so it no longer
belongs in this "clipboard-only" group even though the reasoning for why
it needs to exist at all is the same.

### Calculator 1 — square meters to cartons

| Key                                          | Purpose                                    |
|-----------------------------------------------|---------------------------------------------|
| `calc1FieldRequestedAreaLabel` / `...Helper` | "Area needed (m²)" field                    |
| `calc1FieldWastePercentLabel` / `...Helper`  | "Waste % (optional)" field                  |
| `calc1FieldCartonsPerPalletHelper`           | "Leave empty to skip the pallet breakdown" — no dependency on other fields |
| `resultRequestedArea`, `resultRequestedWithWaste`, `resultRequiredCartons`, `resultActualDelivered`, `resultExtraArea` | Result rows unique to Calculator 1 — reused verbatim (with the shared rows above) to build the copy-to-clipboard text |

### Calculator 2 — cartons to square meters

| Key                                          | Purpose                                    |
|-----------------------------------------------|---------------------------------------------|
| `calc2FieldExtraCartonsLabel` / `...Helper`  | "Extra cartons" field (optional, since Phase 4). Renamed from `calc2FieldCartonsCountLabel`/`...Helper` ("Cartons count", required) — see [UI_DESIGN_PLAN.md](UI_DESIGN_PLAN.md) and [PROJECT_HISTORY.md](../PROJECT_HISTORY.md) for why |
| `calc2FieldPalletsCountLabel` / `...Helper`  | "Pallets count (optional)" field            |
| `calc2FieldCartonsPerPalletHelper`           | "Required if you entered a pallets count" — explains the cross-field dependency |
| `calc2ValidationCartonsPerPalletRequired`    | Shown on the cartons-per-pallet field when pallets count is filled but this isn't |
| `calc2ValidationCartonsOrPalletsRequired`    | *(Phase 4)* Shown on extra-cartons and/or pallets-count when both are empty/zero — at least one must be positive |
| `resultTotalCartons`, `resultTotalTiles`, `resultTotalArea` | Result rows unique to Calculator 2 — `resultTotalArea` is also the hero number |

Standard widget chrome (back button tooltips, etc.) is already localized for
`ar`/`en`/`he` by Flutter's own `GlobalMaterialLocalizations` and does not
need a TileMate-specific key.

## Future keys

No further calculators are planned — the product is fixed at exactly two
(see [PRODUCT_SPEC.md](PRODUCT_SPEC.md)). Future ARB changes are expected to
be wording refinements to existing keys rather than net-new screens' worth
of keys.

## Adding a new string — process

1. Add the key to `app_en.arb` with a `@key` description.
2. Add the same key to `app_ar.arb` and `app_he.arb` with real translations
   (not machine-literal — natural phrasing per language, matching the tone
   used for existing keys).
3. Run `flutter gen-l10n`.
4. Reference it via `AppLocalizations.of(context).yourKey`.
5. Add or update a widget test if the string is load-bearing for a user
   flow (see [TEST_PLAN.md](TEST_PLAN.md)).
