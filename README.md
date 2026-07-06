# TileMate

TileMate is a simple, beautiful, **offline-only** tile quantity calculator for
tile shops and installers. It converts between requested area, cartons, and
pallets — nothing more. There is no account system, no backend, and no data
is ever saved between launches.

One Flutter codebase targets **Android**, **iOS**, and **Windows desktop**.

**TileMate is the app/codebase name; ArtCasa Tiles is the shop it's branded
for.** The app displays "ArtCasa Tiles" as its visible brand name (in-app
app bar/window title/copied result text since Phase 7; the native Android
app label, Windows window title, and Windows file-properties metadata since
Phase 8) and shows an ArtCasa Tiles brand header (icon mark + native text)
on the home screen plus a matching launcher icon — see "Branding" below.
`tilemate` remains the internal package/codebase name (pubspec.yaml, Dart
class names, the Windows executable filename, this repo's own
documentation) and is never shown to the end user.

## Status

TileMate is being built in phases. See [PROJECT_PROGRESS.md](PROJECT_PROGRESS.md)
for exactly what's done, what's next, and how to test the current build.
See [PROJECT_HISTORY.md](PROJECT_HISTORY.md) for a dated log of decisions.

## Scope

TileMate is intentionally minimal:

- No database, no SQLite, no Drift, no Supabase, no backend of any kind.
- No account system, no login.
- No saved history and no saved tile catalog — every session starts fresh.
- Just two calculators, done well, in three languages.

See [docs/PRODUCT_SPEC.md](docs/PRODUCT_SPEC.md) for the full product spec
and [docs/CLAUDE_RULES.md](docs/CLAUDE_RULES.md) for the durable rules that
govern how this project is built.

## Languages

TileMate ships with Arabic, English, and Hebrew, using Flutter's official
ARB + `gen-l10n` localization pipeline. **Arabic is the app's default
language** (RTL) — it opens in Arabic every time, regardless of the
device's system language. Arabic and Hebrew render right-to-left
automatically; English renders left-to-right. A language switcher in the app
bar lets a user change languages at any time; the choice is **not** persisted
across app restarts (by design — see [docs/I18N_PLAN.md](docs/I18N_PLAN.md)) —
restarting the app always returns to Arabic.

## Branding

`assets/branding/` holds the ArtCasa Tiles branding assets:

- **`artcasa_logo.png`** — the original full logo as provided, untouched.
  Kept as reference source material; not bundled into the app (declaring it
  as a Flutter asset would ship ~770 KB that nothing in the UI displays).
- **`artcasa_icon.png`** — a small crop containing just the house/tile
  symbol (no text), with a **genuinely transparent** background. Used both
  to generate the native Android/Windows launcher icons (Phase 8) and, as
  of Phase 9, shown directly in the home screen's brand header. See
  [docs/UI_DESIGN_PLAN.md](docs/UI_DESIGN_PLAN.md) for exactly how it was
  cropped and made transparent.

**There is no wide logo image on the home screen anymore.** Phase 7/8 had
one (`artcasa_logo_trimmed.png`, shown inside a white card) — Phase 9
removed it and deleted the file. Investigating a reported dark-mode display
bug found that file (and the `artcasa_icon.png` of the time) had been
replaced with corrupted exports: a checkerboard pattern baked into fully
opaque pixels, not real transparency, which is what actually produced the
"white card" + "checkerboard visible" + "unreadable text" symptoms. Rather
than patch around broken assets, the home screen now uses a **native
Flutter brand header**: the small transparent icon above, plus real `Text`
widgets (styled from the current theme's colors) for "ArtCasa Tiles" and
its Arabic subtitle "للبلاط والسيراميك" — see
[docs/UI_DESIGN_PLAN.md](docs/UI_DESIGN_PLAN.md) for the full writeup and
exactly how the corrupted-asset issue was confirmed.

### Native app name and launcher icon (Phase 8)

The **visible** native app name is now "ArtCasa Tiles":

- **Android**: `android:label` in `AndroidManifest.xml` → `"ArtCasa Tiles"`
  (shown under the launcher icon and in the recent-apps switcher). The
  Android `applicationId`/package (`com.tilemate...`) was **not** changed.
- **Windows**: the native window title (set in `windows/runner/main.cpp`)
  is now `"ArtCasa Tiles"` — this is the OS-level title bar/taskbar text,
  separate from (and in addition to) Flutter's own `onGenerateTitle`. The
  `Runner.rc` version-info resource's `ProductName` and `FileDescription`
  fields (shown in Explorer's file Properties dialog) were also updated to
  `"ArtCasa Tiles"`. The actual executable filename (`tilemate.exe`) and
  the CMake project/binary name were **not** changed — renaming those would
  ripple into build output paths and any existing shortcuts/docs
  referencing `tilemate.exe`, which wasn't necessary just to show a
  different name to the user.
- **iOS**: left untouched (still "Tilemate") — iOS name/icon work is
  deferred, matching this project's standing "iOS needs a Mac with Xcode,
  not available in this environment" limitation.
- **Internal names unchanged**: the Dart package (`pubspec.yaml`'s
  `name: tilemate`), the `MyApp` class, every `import 'package:tilemate/...'`
  statement, and this repo's own file/folder names all still say TileMate —
  intentionally. Only the strings an end user actually sees were changed.

**Launcher icon**: generated from `artcasa_icon.png` using the
[`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons)
package — the standard, dev-tooling-only approach for this (it never ships
inside the built app; see its config under `flutter_launcher_icons:` in
`pubspec.yaml`). Configured for **Android and Windows only** — iOS
generation is explicitly disabled (`ios: false`) since this project doesn't
build for iOS in this environment. To regenerate after changing the icon
source:

```bash
flutter pub get
dart run flutter_launcher_icons
```

This overwrites `android/app/src/main/res/mipmap-*/ic_launcher.png` and
`windows/runner/resources/app_icon.ico` directly — regenerate and commit
those files together with any icon-source change, the same way generated
code is normally handled.

**Note:** `artcasa_icon.png`'s content changed in Phase 9 (now transparent,
slightly different crop margins, to fix a home-screen dark-mode display
bug — see [docs/UI_DESIGN_PLAN.md](docs/UI_DESIGN_PLAN.md)). The
already-generated launcher icon files above were **not** regenerated that
phase and are unaffected; if the command above is ever run again, the
resulting launcher icons will pick up the transparent background too.

## Getting started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel).
  This repo was built and verified against Flutter 3.44.4.
- To run on **Android**: Android Studio with the Android SDK installed.
- To run on **iOS**: a Mac with Xcode installed (iOS apps cannot be built or
  run from Windows or Linux).
- To run on **Windows desktop**: Visual Studio 2022 or later, with the
  "Desktop development with C++" workload.

Run `flutter doctor` to confirm which of the above are available on your
machine. You don't need all of them — you only need the toolchain for the
platform you're targeting.

### Setup

```bash
flutter pub get
flutter gen-l10n   # regenerates lib/l10n/generated/ from the ARB files
```

`flutter gen-l10n` also runs automatically before `flutter run` / `flutter
build`, because `pubspec.yaml` sets `generate: true`. You only need to run it
by hand after editing the `.arb` files if you want the generated code
available immediately (e.g. for your editor).

### Run

```bash
flutter run -d windows   # Windows desktop
flutter run -d <device>  # Android or iOS device/emulator (flutter devices)
```

### Test

```bash
flutter analyze
flutter test
```

Both must report no issues / all tests passing. As of Phase 9, that's
`flutter analyze` with 0 issues and `flutter test` with all 77 tests
passing.

## Building a Windows release

This produces the real, optimized build to actually hand to someone — not
the `flutter run -d windows` debug build, which is slower and requires the
Flutter/Visual Studio toolchain to be present.

```bash
flutter analyze   # confirm 0 issues first
flutter test      # confirm all tests pass first
flutter build windows --release
```

This requires Visual Studio with the "Desktop development with C++"
workload (see Prerequisites above) — the same requirement as `flutter run
-d windows`. `flutter build windows` will tell you clearly if that
workload isn't installed; it won't partially succeed.

**Output location:**

```
build\windows\x64\runner\Release\
```

That folder contains:

```
tilemate.exe            the app itself
flutter_windows.dll     the Flutter engine — required, must sit next to the .exe
data\
  app.so                your compiled Dart code
  icudtl.dat             locale/internationalization data (needed for Arabic/Hebrew)
  flutter_assets\        fonts, shaders, and other bundled assets
```

Total size is roughly 28 MB. Since Phase 8, `tilemate.exe` shows
**"ArtCasa Tiles"** as its window title and taskbar text, and carries the
ArtCasa Tiles icon (house + tile symbol) instead of Flutter's default —
confirmed by actually launching the built `.exe` and reading back its live
`MainWindowTitle` (see [PROJECT_HISTORY.md](PROJECT_HISTORY.md)'s Phase 8
entry), not just assumed from the source change.

**To share the app with another Windows computer:** copy or zip the
**entire `Release` folder**, not just `tilemate.exe`. The `.exe` does not
run on its own — it loads `flutter_windows.dll` and the `data\` folder
from the same directory at startup, and will fail to launch (or crash
immediately) without them sitting right next to it. This has been
confirmed by actually launching `tilemate.exe` from inside a freshly built
`Release` folder (see [PROJECT_HISTORY.md](PROJECT_HISTORY.md)'s Phase 5
entry) — it was not just assumed.

The target computer does **not** need Flutter, Visual Studio, or any SDK
installed to run the app. It may, however, need the **Microsoft Visual
C++ Redistributable** if it doesn't already have one installed (most
Windows 10/11 PCs already do, since many other applications depend on it
too) — this is standard for any Flutter Windows build, not specific to
TileMate. If `tilemate.exe` fails to start on another machine with a
missing-DLL error (e.g. mentioning `VCRUNTIME140.dll` or similar), install
the redistributable from Microsoft and try again.

There is no installer — Phase 5 deliberately produced only the plain
release folder (see [docs/CLAUDE_RULES.md](docs/CLAUDE_RULES.md)). Copying
the folder and double-clicking `tilemate.exe` is how it's meant to be run
for now.

## Project structure

```
assets/
  branding/
    artcasa_logo.png              Original full logo (reference only, not bundled)
    artcasa_icon.png              Transparent icon-only crop (house+tile, no text) --
                                   home screen brand header + native launcher icons
lib/
  main.dart                        Entry point (runApp only)
  app.dart                         MaterialApp, locale state, theming
  theme/
    app_theme.dart                 Shared Material 3 design tokens
  screens/
    home_screen.dart               Home screen with the two calculator cards
  widgets/
    language_switcher.dart         App bar language picker
  calculators/
    common/
      numeric_input.dart           Pure Dart parsing/validation helpers
      area_format.dart             Square-meter display formatting
      calculator_form_widgets.dart Shared screen shell, cards, fields, result rows
    square_meters_to_cartons/      Calculator 1 (area -> cartons/pallets)
    cartons_to_square_meters/      Calculator 2 (cartons/pallets -> area)
  l10n/
    app_en.arb                     English strings (template)
    app_ar.arb                     Arabic strings
    app_he.arb                     Hebrew strings
    generated/                     Generated by flutter gen-l10n (git-ignored)
docs/
  PRODUCT_SPEC.md                  What TileMate is and isn't
  CALCULATION_RULES.md             Exact formulas for both calculators
  UI_DESIGN_PLAN.md                Design system and layout rules
  I18N_PLAN.md                     Localization architecture and key list
  TEST_PLAN.md                     Testing strategy, current and planned
  CLAUDE_RULES.md                  Durable working rules for this repo
```

Each calculator folder holds a pure Dart `*_calculator.dart` (models + the
approved formula, no Flutter import, directly unit-testable) and a
`*_screen.dart` (the form + result UI, built from the shared widgets in
`calculators/common/`). Both calculators follow this exact same shape by
design — see [docs/UI_DESIGN_PLAN.md](docs/UI_DESIGN_PLAN.md).

## Adding or changing a translated string

1. Add the key to `lib/l10n/app_en.arb` (the template file) with a
   `@key` description block.
2. Add the same key with a translated value to `lib/l10n/app_ar.arb` and
   `lib/l10n/app_he.arb`.
3. Run `flutter gen-l10n`.
4. Use it in code via `AppLocalizations.of(context).yourKey`.

Never hardcode user-facing strings directly in widgets.
