# TileMate — Project History

A dated, append-only log of meaningful decisions and changes. Newest entries
at the top.

---

## 2026-07-05 — Phase 10: native launcher/title-bar icon refresh

Started after the project owner pointed out that Phase 9 fixed the in-app
home screen header but the native Windows title bar/taskbar icon still
showed the old, broken icon — expected, since Phase 9 explicitly noted it
had corrected the *source* asset (`assets/branding/artcasa_icon.png`) but
deliberately left the already-generated Android/Windows launcher icon
files alone, flagging the regeneration as a follow-up. Scope: exactly that
follow-up, kept small and fast per the brief — no calculator, layout,
storage, or feature changes.

### What was done, in order

1. Confirmed `assets/branding/artcasa_icon.png` exists (the Phase 9
   transparent icon).
2. `flutter pub get`, then `dart run flutter_launcher_icons` — regenerated
   `android/app/src/main/res/mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png`
   (all 5) and `windows/runner/resources/app_icon.ico`. Confirmed via file
   timestamps and changed file sizes (e.g. the Windows `.ico` went from
   58,969 bytes at 17:14 to 62,084 bytes at 18:08) that these were
   genuinely rewritten, not skipped.
3. **Verified the regenerated files actually carry real transparency,
   not just assumed it from the source asset being fixed.** Reading the
   Android PNG back showed `PixelFormat: Format32bppArgb` with a
   transparent corner pixel (`A=0`) — straightforward. The Windows `.ico`
   was trickier: `System.Drawing.Icon.ToBitmap()` threw
   `ArgumentOutOfRangeException` ("Requested range extends past the end
   of the array") for its 256px frame — a well-known, long-standing GDI+
   bug specific to large PNG-compressed ICO entries (the ICO format
   stores width/height as `0` to mean "256" per spec, and this particular
   .NET code path mishandles that for PNG-compressed frames). Rather than
   conclude the icon was broken from a tooling error, the ICO container
   was parsed manually instead: read the `ICONDIR`/`ICONDIRENTRY` binary
   structure directly (6-byte header, 16-byte directory entries), found
   this file has exactly one entry, extracted its embedded PNG bytes by
   the entry's own recorded offset/size, and saved that as a standalone
   `.png` — which a normal `Bitmap.FromFile` reads without issue:
   `Format32bppArgb`, transparent corner, correctly opaque artwork.
   Confirms the actual `.ico` content is correct; the failure was purely
   in the inspection tool, not the file.
4. `flutter analyze` (0 issues) and `flutter test` (77/77 passing) —
   unchanged, since no Dart code was touched this phase.
5. `flutter clean` → `flutter pub get` → `flutter build windows --release`
   — succeeded on the **first** attempt (Phase 8 hit a transient
   locked-file linker error here; this run didn't repeat it).
6. **Launched the rebuilt `tilemate.exe` and looked at it directly**,
   rather than trusting the regeneration step alone: `Get-Process`
   confirmed it running with `MainWindowTitle` exactly `"ArtCasa Tiles"`;
   a full-screen screenshot was captured and a tight crop of just the
   title bar was reviewed — the icon shows the clean house/tile mark
   directly against the dark title bar, blending naturally, no white box
   or checkerboard anywhere. The home screen visible behind the window in
   the same screenshot still showed Phase 9's brand header, Arabic
   tagline, and both calculator cards correctly — nothing regressed. The
   process was stopped and every screenshot/crop deleted afterward
   (verification aids only, not repo artifacts).

### Taskbar icon: inferred fixed via shared resource, not separately eyeballed

A crop of the taskbar strip from the same screenshot was reviewed too, but
at normal desktop resolution the taskbar was crowded with many other
pinned/running app icons and the TileMate entry couldn't be confidently
picked out among them. This was **not** treated as an open question worth
chasing further: the Windows title bar and taskbar icon for a given window
draw from the same `.ico` resource unless an app explicitly sets a
different one (this app doesn't), and that resource had already been
verified byte-correct in step 3 above — so there's no plausible mechanism
for the title bar to be fixed while the taskbar remains broken. Consistent
with the brief's own "do not spend too long on OS cache problems"
instruction, and unlike a real icon-cache scenario, **no stale/old icon
was observed anywhere** in this session — the new icon appeared
immediately on the very first rebuild-and-relaunch, so there was no actual
caching problem to document.

### What was intentionally not touched

No calculator code, no calculator formulas, no home screen layout (Phase
9's brand header is completely unchanged), no database/storage/history/
accounts/backend, no new features, no Android APK build, no iOS build, no
installer packaging — all explicitly out of scope for this phase and none
of it was started.

---

## 2026-07-05 — Phase 9: home screen brand header rebuilt natively (dark-mode fix)

Started after the project owner reported the Phase 7/8 home screen logo
looked broken in dark mode: shown inside a white card, a "dark/transparent
checkerboard-looking background" visible, the image too small/cramped, and
its baked-in text less readable than native text. Scope: fix the home
screen brand header specifically — explicitly not calculator behavior, not
database/storage, not a whole-app redesign.

### Root-causing the bug before touching any widget code

Rather than assume the Phase 7/8 `Container`/white-card styling was simply
wrong and start redesigning immediately, the actual asset files were
inspected first. `assets/branding/artcasa_icon.png` and
`assets/branding/artcasa_logo_trimmed.png`, as they existed on disk at the
start of this phase, both turned out to be **corrupted**: a literal
checkerboard pattern baked into fully **opaque** pixels, not real alpha
transparency.

Confirmed two ways, not assumed from appearance alone:

1. `System.Drawing.Bitmap.PixelFormat` reported `Format24bppRgb` for both
   files — no alpha channel present at all. This is read directly from the
   PNG's color-type header byte, so it's a reliable signal, not a guess.
2. Sampling a horizontal strip of pixels in what looked like the
   "background" showed them alternating between two distinct *opaque* gray
   values (`~34,34,33` and `~27,27,26`, both `A=255`) — a genuine two-tone
   checker baked into the pixel data itself, not a transparency-preview
   rendering artifact from any image viewer.

This is a classic mis-export mistake: some design tool's "this is
transparent" checkerboard *indicator* got captured as literal pixel
content instead of real alpha transparency. It explains the entire bug
report as one coherent story: the Phase 7/8 code's hardcoded-white
`Container` showed through as a white card (exactly as designed, since the
asset it was built around genuinely was opaque white at the time); the
checkerboard-baked replacement PNG showed a checkerboard through/around the
artwork; and the `artcasa_logo_trimmed.png` variant's baked-in wordmark
text had also been redrawn in light colors (white "ArtCasa", teal "Tiles")
intended for a dark background — unreadable once forced inside that white
card. **No amount of widget-code tweaking alone would have fixed this** —
the assets themselves needed correcting, which shaped everything that
followed.

### Regenerating a clean, genuinely transparent icon

The original, untouched `assets/branding/artcasa_logo.png` was checked and
confirmed still intact (plain opaque white background, no checkerboard,
matching Phase 7/8's own documentation of it). A new
`assets/branding/artcasa_icon.png` was generated from it:

1. Cropped to the icon's own content bounding box (`x:[137,417]
   y:[426,746]`, already known from Phase 8's crop work) plus a small
   margin: `left=125, top=414, width=304, height=344`. Unlike Phase 8's
   crop, this one didn't need to be square (it's not this phase's job to
   also regenerate the launcher icon — see below), so no asymmetric
   left/right trade-off was needed this time.
2. **Chroma-keyed the white background to real alpha transparency**,
   informed by actually measuring the colors involved first rather than
   guessing a threshold: background pixels average `≈254`; the *lightest*
   artwork color (the mint tile square) averages `≈220` — a comfortable
   30+ unit gap. Every pixel averaging `>=248` became fully transparent;
   `<=238` stayed fully opaque; values in between were linearly
   interpolated for a soft anti-aliased edge rather than a hard binary cut.
   Implemented as a plain per-pixel `System.Drawing`
   `GetPixel`/`SetPixel` loop — no ImageMagick or working Python was
   available in this sandbox (same limitation noted in Phase 7/8's
   history).
3. **Verified before wiring it into any widget**, not after: re-read the
   saved file back and confirmed `PixelFormat: Format32bppArgb` with a
   transparent corner (`A=0`) and a correctly-colored, fully opaque tile
   square (`A=255`); checked multiple artwork edges for a white-tinted
   "halo" fringe from the chroma-key (found none — every sampled edge
   transitions cleanly between fully transparent and fully opaque with no
   partial-alpha pixel retaining background-tinted color); and
   **composited the result onto both an approximate dark-theme and
   light-theme background color** using a small throwaway script, then
   viewed both composites directly — confirmed clean in both before
   touching `home_screen.dart` at all.

`assets/branding/artcasa_logo_trimmed.png` — the corrupted, checkerboard-
baked wide logo — was **deleted**. It's no longer referenced by any code
after this phase's change (the home screen doesn't show a wide logo image
at all anymore), and the copy on disk was broken/mis-exported, not worth
keeping as a confusing artifact. `pubspec.yaml`'s asset list was updated
to match (declares `artcasa_icon.png`, no longer declares the deleted
file).

### The native brand header

`lib/screens/home_screen.dart` gained two new private widgets,
`_BrandHeader` and `_BrandText`, replacing the old `Container`/
`Image.asset`/white-card block entirely — no image is used for any text
anymore, only for the small icon mark:

- **Icon**: `Image.asset('assets/branding/artcasa_icon.png', height: ...)`
  with **no** wrapping `Container`, background color, or border — since
  the asset is now genuinely transparent, the theme's own background shows
  through naturally in both light and dark mode, the same way any other
  icon in the app already behaves.
- **Brand name** (`l10n.appTitle`, "ArtCasa Tiles"): real `Text`,
  `colorScheme.onSurface`, bold — chosen for maximum legibility in either
  theme, at the cost of not replicating the original logo's two-tone
  "ArtCasa" (neutral) + "Tiles" (teal) coloring. Splitting the string to
  recolor just "Tiles" was considered and rejected: it would mean either a
  fragile `.split(' ')` on a translated-but-never-actually-translated ARB
  value, or a second dedicated ARB key for a purely cosmetic detail —
  neither felt worth the complexity for a look the header already achieves
  another way (see the tagline color, below).
- **Business subtitle** (new `l10n.brandSubtitle`, "للبلاط والسيراميك"):
  real `Text`, `colorScheme.onSurfaceVariant` (muted/secondary), flanked by
  two short 1.5px rule lines in a hardcoded warm taupe
  (`Color(0xFFB29684)`) — echoing the dashes either side of the same
  subtitle in the original logo. This is the one deliberately hardcoded
  (non-theme) color in the whole widget, and it's deliberately scoped to a
  decorative line rather than any text, so it carries no legibility/
  contrast risk regardless of theme.
- **Existing tagline** (`l10n.homeTagline`, "حاسبة البلاط") stayed exactly
  where it was — a separate line below `_BrandHeader`, in
  `HomeScreen.build` itself, not folded into the new widget — but is now
  styled in `colorScheme.primary` (the app's signature teal) instead of
  the default text color. This became the header's one deliberate,
  concrete use of the teal/mint brand accent on text, chosen over tinting
  the brand name itself so "ArtCasa Tiles" stays at maximum legibility.
- **Responsive**, reusing the same `640`px `_wideLayoutBreakpoint` already
  used for the two calculator cards (so both parts of the screen switch
  layout at the same width, rather than introducing a second, slightly
  different breakpoint): wide — icon beside the text block, the pair
  centered as one compact unit (`Flexible` bounds the text column so it
  can wrap instead of overflowing without being forced to stretch); narrow
  — icon centered above the text block.
- **RTL handled automatically**, the same way every other RTL concern in
  this app already is: `TextAlign.start`/`CrossAxisAlignment.start` (never
  `.left`) plus `Row`'s natural child-mirroring in a right-to-left
  `Directionality` — no manual RTL-specific code was written or needed.

### Testing

Updating for the new header surfaced an expected, understood text
collision — not a bug: with "ArtCasa Tiles" now rendered as real text in
*two* places (the app bar title, unchanged since Phase 7, and the new
home-screen header), `find.text('ArtCasa Tiles')` correctly matches twice
wherever both are visible. `test/widget_test.dart`,
`test/responsive_layout_test.dart`, and `test/branding_test.dart` were
updated from `findsOneWidget` to `findsNWidgets(2)` with an explanatory
comment — the same handling this project has used for analogous label
collisions since Phase 2/4 (e.g. Calculator 2's "Extra cartons" field
label vs. result row). `test/branding_test.dart` was also extended to
assert the new `brandSubtitle` text and the purpose tagline both render,
on top of its existing icon-presence and calculators-still-work checks.

**Went beyond widget-tree assertions to actually look at the result once
more.** A scratch (not committed) golden-image test rendered the home
screen to a PNG at: mobile width in light mode, mobile width in dark mode,
desktop width in dark mode (Arabic, to see the wide/RTL row layout), and
mobile width in dark mode switched to English (to see the same responsive
logic under LTR). All four were viewed directly: no white box, no
checkerboard, the icon blends cleanly into both theme backgrounds, the
header's wide-vs-narrow layout and RTL mirroring both work as designed,
and the teal tagline / taupe rule accents render as intended. The scratch
test file and generated PNGs were deleted after confirmation, consistent
with how this project has always handled one-time visual verification
(see Phase 7/8's equivalent checks).

Final result: `flutter analyze` — 0 issues; `flutter test` — 77/77 passing
(same total as the end of Phase 8 — assertions updated for the expected
new collision, no tests added or removed net). Both approved calculator
examples and the language switcher were re-confirmed working via
`test/branding_test.dart`'s third test and the full existing suite,
unchanged.

### What was intentionally not touched

No calculator formula, no calculator screen, no database/storage/history/
catalog/accounts/backend, no new dependency, no Android/iOS release build,
no installer packaging — all explicitly out of scope for this phase and
none of it was started. The already-generated Phase 8 Android/Windows
launcher icon files were also deliberately left alone (not regenerated
from the now-different-content `artcasa_icon.png`), since redoing the
launcher icon wasn't this phase's job — noted in
[docs/UI_DESIGN_PLAN.md](docs/UI_DESIGN_PLAN.md) for whoever next runs
`dart run flutter_launcher_icons`.

---

## 2026-07-05 — Phase 8: ArtCasa Tiles native app name and launcher icon

Started after the project owner confirmed Phase 7 (in-app ArtCasa Tiles
branding: display name + home-screen logo) was manually verified. Scope:
native-level branding only — a real icon-only launcher icon (Android +
Windows) and the visible native app name — with explicit permission to
edit native manifest/resource files and add dev-tooling dependencies
without asking each time, and an equally explicit list of things not to
touch (calculator logic, database/storage, accounts, installer packaging,
store publishing).

### Cropping the icon-only asset

Phase 7's logo-trim work had already established the full logo
(`artcasa_logo.png`, 1254×1254px, opaque `Format24bppRgb`) has a large
blank margin around its actual content. Phase 8 needed to go one step
further: extract *just* the house/tile symbol, with no "ArtCasa Tiles"
text at all, since the brief was explicit that the wordmark must not
become the launcher icon.

No ImageMagick or working Python was available in this sandbox
(`python`/`python3` resolve only to Windows Store install-stub aliases, as
already noted in Phase 7's history) — so, same as Phase 7, a
PowerShell/`System.Drawing.Bitmap` pixel scan did the work directly.
A column-by-column scan across `x=100..550` (within the known content
band `y=426..746`) found a genuine gap of blank columns between `x=418`
and `x=446`: the icon's own artwork ends at `x=417`, and the wordmark's
first stroke starts at `x=448`. This gap is what makes a text-free crop
possible at all, and it was confirmed to exist *before* committing to a
crop rectangle, not assumed from a visual guess. A finer per-pixel scan
then found the icon's precise bounding box: `x:[137,417] y:[426,746]`
(280×320px, not square).

Squaring this up while respecting the gap (so no anti-aliased text pixel
bleeds in) required asymmetric padding: the icon has generous blank canvas
on its left/top/bottom (free to use), but only ~29px of safe gap on its
right before text starts. Final crop: `left=97, top=414, width=344,
height=344` (a 344×344 square), giving the icon 56px of clear space on its
left within the frame vs. 16px on its right — a deliberate, documented
trade-off (a perfectly centered crop was not possible without either
touching the text or shrinking the icon uncomfortably tight against the
frame edges), not a mistake. Saved as `assets/branding/artcasa_icon.png`;
the original `artcasa_logo.png` was not modified.

**Verified readable before wiring it in, not after.** Downscaled preview
renders at 48×48, 96×96, and 192×192 (typical real launcher-icon sizes)
were generated and viewed directly — the house outline and four-tile grid
stayed clearly legible at all three, confirming the brief's "readable at
small size" requirement concretely rather than by assumption.

### Native app name: "ArtCasa Tiles," changed only where it's actually visible

Four fields across two platforms:

| File | Field | New value |
|------|-------|-----------|
| `android/app/src/main/AndroidManifest.xml` | `android:label` | `ArtCasa Tiles` |
| `windows/runner/main.cpp` | native window title (`Win32Window::Create`'s first argument) | `L"ArtCasa Tiles"` |
| `windows/runner/Runner.rc` | `ProductName` | `ArtCasa Tiles` |
| `windows/runner/Runner.rc` | `FileDescription` | `ArtCasa Tiles` |

**Deliberately left everything else alone**, each for a specific reason:

- Android `applicationId` (still `com.tilemate...`) — renaming this is a
  much bigger, riskier change (affects package identity, any future Play
  Store listing, signing) and wasn't what "update the visible app name"
  asked for.
- `Runner.rc`'s `CompanyName`, `InternalName`, `OriginalFilename`, and
  `LegalCopyright` — these reference `tilemate`/`com.tilemate` and were
  left as-is. `OriginalFilename` in particular *should* match the actual
  produced file (`tilemate.exe`, itself unchanged — see below), so
  "correcting" it to say ArtCasa Tiles would have made it *inaccurate*.
  `CompanyName`/`LegalCopyright` assert a legal-entity identity this
  project has no confirmed real-world detail for beyond the existing
  placeholder (documented as a placeholder reverse-DNS identifier since
  Phase 0) — not something to invent or guess at.
- The Windows executable filename and the CMake `project()`/`BINARY_NAME`
  (both still `tilemate`) — renaming the actual binary ripples into build
  output paths and any existing shortcuts/documentation referencing
  `tilemate.exe`, for no requirement-driven reason (the window title and
  file-properties metadata already carry the visible "ArtCasa Tiles" name
  a user would actually see).
- The Dart package name (`pubspec.yaml`'s `name: tilemate`), the `MyApp`
  class, and every `import 'package:tilemate/...'` statement — explicitly
  protected by this phase's own instructions ("do not rename the Dart
  package unless absolutely necessary... internal package name can remain
  tilemate"). Not touched.
- iOS's `CFBundleDisplayName`/`CFBundleName` (still "Tilemate"/"tilemate")
  — iOS work is out of scope this phase (no Mac/Xcode in this
  environment, same standing limitation since Phase 0).

### Launcher icon: `flutter_launcher_icons`, dev-only, Android + Windows

Added `flutter_launcher_icons: ^0.14.4` via
`flutter pub add --dev flutter_launcher_icons` — resolved and fetched
successfully (confirming network access was available in this sandbox for
this operation). This is the standard, low-risk Flutter-ecosystem approach
for exactly this task; it and its own transitive dependencies (`image`,
`archive`, etc.) are dev-tooling only and never ship inside the built app —
satisfying the brief's "do not add runtime dependencies for this."

Configuration added to `pubspec.yaml`:

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

Run via `flutter pub get` then `dart run flutter_launcher_icons`, which
reported success and overwrote, in place:
`android/app/src/main/res/mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png` (all
5 densities — confirmed via `find ... -newer pubspec.yaml` that every one
picked up a fresh timestamp) and `windows/runner/resources/app_icon.ico`.
No Android adaptive-icon XML existed before and none was introduced — the
project's existing flat/legacy icon structure was kept, just repainted
with the new artwork. `ios: false` explicitly skips iOS generation
entirely, matching the standing "no Mac/Xcode available" limitation.

The largest (`xxxhdpi`) and smallest (`mdpi`) generated Android icons were
both viewed directly after generation — clean, legible house/tile mark at
both extremes.

### Testing and build results

`flutter analyze` and `flutter test` were run **both before and after**
every native/config change, per this phase's own standing "confirm a clean
baseline first" discipline: 0 analyze issues and all 77 tests passing at
every checkpoint (no new tests were added — nothing Dart-level changed for
them to cover; the existing 77 are exactly what should, and did, keep
passing unchanged).

`flutter build windows --release` **failed on the first attempt**:
`LNK1104: cannot open file '...\tilemate.exe'`. Checked
`tasklist /FI "IMAGENAME eq tilemate.exe"` first rather than guessing — no
such process was actually running, so this wasn't a simple "old instance
still open" case; most likely a transient file lock (e.g. antivirus
scanning the previous build's binary, or a stale intermediate object left
over from the pre-Phase-8 build). Fixed with `flutter clean` (removes
`build\` entirely), `flutter pub get`, and a retry — succeeded in ~42s.
This is the same "a stale/locked `build\` directory can silently break a
Windows release build; clean first" lesson Phase 5 already recorded for a
different underlying symptom (leftover `cupertino_icons` assets) — worth
treating as a standing habit for this project's Windows builds generally,
not just a one-off fix.

**Didn't stop at "the build command exited 0."** Launched the built
`tilemate.exe` via `Start-Process`, confirmed via `Get-Process` that it was
still running, and read its live `MainWindowTitle` property directly:
exactly `"ArtCasa Tiles"` — proof the `main.cpp` change took effect in a
real running process, not just verified by re-reading the source. Went
one step further than Phase 5's equivalent check: captured a full-screen
screenshot of the running app and viewed it directly, confirming by eye
that (a) the title bar reads "ArtCasa Tiles", (b) the title-bar/taskbar
icon shows the new house/tile mark rather than Flutter's default, and (c)
the home screen behind it is completely unaffected — still showing the
full ArtCasa Tiles logo card, the Arabic "حاسبة البلاط" tagline, the prompt
text, and both calculator cards, all in Arabic (the app's default). The
process was then stopped (`Stop-Process`) and the screenshot deleted — it
was a one-time verification aid capturing the reviewer's own live desktop,
not something to leave lying around or commit.

No Android APK build was attempted — not required by this phase's brief,
and this sandbox still has no Android SDK (unchanged since Phase 0), so
the Android manifest-label and mipmap-icon changes were reviewed and
regenerated correctly but have **not** been run on an actual device or
emulator. Recorded explicitly as a known limitation rather than silently
assumed working, the same way Phase 3's on-device gap has been carried
forward since it was found.

### What was intentionally not touched

No calculator formula, no calculator screen, no home-screen widget code
(the full logo card from Phase 7 is completely unchanged), no database/
storage/history/catalog/accounts/backend, no runtime dependency, no
Android APK/AAB build, no iOS build, no installer, no store-publishing
work of any kind — all explicitly out of scope for this phase and none of
it was started.

---

## 2026-07-05 — Phase 7: ArtCasa Tiles branding

Started after the project owner confirmed Phase 6 (Arabic default
language) was manually verified. Scope: add light ArtCasa Tiles branding —
brand name and a logo on the home screen — without touching calculator
behavior, database/storage, accounts, new calculators, or release/signing
work, per the same standing rules as every prior phase (see
[docs/CLAUDE_RULES.md](docs/CLAUDE_RULES.md)).

### Getting the logo asset

The phase brief said the project owner had a logo image but didn't include
a file or path — rather than guess which of several unrelated images
sitting on the user's Desktop/Downloads might be it (a real risk: picking
the wrong file for a visible brand asset is a mistake worth avoiding
entirely), asked directly where it was. The project owner placed it at
`assets/branding/artcasa_logo.png` in response.

### Why the logo was cropped before use

Inspecting the provided file (`artcasa_logo.png`, 1254×1254px, opaque
`Format24bppRgb` — no transparency) showed its actual visible content (the
house/tile mark, "ArtCasa Tiles" wordmark, and Arabic subtitle "للبلاط
والسيراميك") occupies only the middle ~25% of the image's height, with a
large blank margin above and below — likely sized for a use case (social
banner, letterhead) other than an in-app logo. Displaying the file as-is at
any reasonable width would have left most of the displayed area blank,
failing the brief's own "if it fits cleanly" / "keep the UI light and not
crowded" conditions.

Rather than ask the project owner to re-export a tighter crop, a trimmed
copy was generated directly (`assets/branding/artcasa_logo_trimmed.png`,
1073×380px, ~2.8:1): the content's pixel bounding box was found via a
PowerShell scan of `System.Drawing.Bitmap` pixels (no ImageMagick or
working Python was available in this environment — `python`/`python3`
resolved only to Windows Store install stubs), then cropped with a small
margin using `System.Drawing.Graphics.DrawImage`. This only removes blank
canvas — the logo artwork itself is untouched, still the exact image the
project owner provided, just without the dead space around it. The
original file was kept in the repo unmodified (not overwritten) as
reference material, and is deliberately **not** registered in
`pubspec.yaml` — bundling an asset nothing in the UI displays would just
add ~770 KB to every build for no reason. Only the trimmed copy is
declared as a Flutter asset.

### Brand name: "ArtCasa Tiles" replaces "TileMate" as the *visible* string only

`appTitle`'s value changed from "TileMate" to "ArtCasa Tiles" in all three
ARB files (kept identical across locales, unchanged pattern — a brand name
isn't translated). This is the one string shown in the app bar, the OS
task-switcher/window title, and — since both calculators' clipboard
builders already reuse `l10n.appTitle` as the first line of the copied
result (unchanged since Phase 3) — now also the header of the copied
WhatsApp-bound text, with zero code changes needed there.

**Deliberately did not rename "TileMate" anywhere else.** The package name
in `pubspec.yaml` (`name: tilemate`), the `MyApp` class, every file name,
and this project's own documentation all still say TileMate — that's the
internal codebase/product name, distinct from ArtCasa Tiles, the shop this
particular build is branded for. Only the one user-facing string changed.
This reading matches "add **light** ArtCasa branding" rather than "rebrand
the whole codebase," and keeps a future re-brand (a different shop using
the same underlying tool) to the same one-line change.

**Also deliberately left untouched: native platform app labels.** Android's
`android:label` in `AndroidManifest.xml`, iOS's `CFBundleDisplayName` in
`Info.plist`, and the Windows native window-title strings in
`windows/runner/Runner.rc`/`main.cpp` all still reference "TileMate" — none
of these were edited. They control OS-level chrome (a phone's home-screen
label, a desktop window's native title bar) rather than in-app UI, and
editing them starts to blend into the same territory as app-icon/launcher
branding, which the brief was explicit about deferring. Documented as a
deliberate scope boundary rather than an oversight.

### Home screen: logo replaces the generic app-mark icon

`lib/screens/home_screen.dart`'s `Icons.grid_view_rounded` placeholder
(documented since Phase 0 as standing in for a real logo) was replaced with
the trimmed ArtCasa Tiles logo, wrapped in a `Container` with a hardcoded
`Colors.white` background, `AppTheme.cardRadius` corners, and a
`colorScheme.outlineVariant` border, capped at `width: 240` (Image
computes height from the asset's own aspect ratio).

**Why hardcoded white instead of a theme color:** the logo PNG has an
opaque white background baked in, with no alpha channel to make it
transparent. Using a theme-derived fill (e.g. `colorScheme.surface`, which
is dark in dark mode) would leave the logo's own white background showing
through as a mismatched, unintentional-looking box against a dark
scaffold. A deliberately-always-white card, with a thin border for
definition, reads as an intentional "logo badge" in both themes instead of
looking like a bug — confirmed by rendering both themes (see Testing
below).

The logo is not localized and not mirrored for RTL — it's a single asset
with both the English wordmark and the Arabic subtitle baked into one
image, shown identically regardless of the app's active language, matching
how most real brand logos behave.

### App icon: documented as a prerequisite, not built

Per the brief's own instruction, the full (wide, wordmark) logo must not
become the launcher icon — it wouldn't be readable shrunk to icon size and
isn't square. Documented in README.md and docs/UI_DESIGN_PLAN.md that a
separate icon-only asset (house + tile symbol only, no text, square
1024×1024, transparent or clean background) needs to be created first, and
that generating/wiring up actual Android/iOS/Windows launcher icons from
it is future work. Nothing icon-related was generated or touched this
phase.

### Testing results

Five existing assertions needed a one-line update (checking for the
literal string "TileMate", which no longer appears anywhere):
`test/widget_test.dart`, `test/responsive_layout_test.dart`, and three
clipboard-content checks across
`test/l10n/arabic_default_examples_test.dart` (×2) and
`test/calculators/square_meters_to_cartons_screen_test.dart` (×1) — all
now expect "ArtCasa Tiles" instead. `test/responsive_layout_test.dart`'s
existing Arabic-default home-screen check also gained one line confirming
the logo image specifically survives the no-overflow check
(`find.byType(Image)`).

**`test/branding_test.dart`** *(new, 3 tests)*: the brand name and logo
both show on the home screen alongside the existing "حاسبة البلاط" tagline
in Arabic (the default); both persist correctly and the language switcher
still works when switching to English and to Hebrew; both calculators
still open and function normally with the new home screen in place.

**A real Flutter-testing-environment quirk was found (and is not an app
bug), while going beyond widget-tree assertions to actually look at the
rendered result.** A scratch (not committed) golden-image test rendered
the home screen to a PNG for direct visual review in both light and dark
theme. Dark mode rendered perfectly on the first try. Light mode initially
came back with an empty white card where the logo should be — investigated
rather than assumed correct-in-spirit: the cause was `Image.asset`'s
underlying `rootBundle` decode not finishing before `pumpAndSettle()`
returned on the very first `pumpWidget` of a fresh test process (confirmed
by wrapping the wait in `tester.runAsync(() => Future.delayed(...))`,
which lets real async I/O actually complete outside the widget-test fake
clock — the logo then rendered correctly; a second test in the same
process, with the image already warm in Flutter's `imageCache`, had
rendered correctly even without this fix). This is a known category of
Flutter widget-test flakiness around asset image decoding timing, not a
defect in the app itself — an actual running app simply repaints once the
image finishes decoding, imperceptibly. Recorded in
[docs/TEST_PLAN.md](docs/TEST_PLAN.md) as the reason this project's
permanent tests check for the image's presence rather than asserting
pixel-perfect golden output. The scratch test file and generated PNGs were
deleted after visual confirmation — they were a one-time verification aid,
not intended as permanent test artifacts.

Final result: `flutter analyze` — 0 issues; `flutter test` — 77/77 passing
(up from 74 at the end of Phase 6). Both approved examples reconfirmed
exact; both calculators and the language switcher confirmed still working
with the new branding in place.

### What was intentionally not touched

No calculation formula, no new dependency, no database/storage/history/
catalog/accounts/backend, no native platform app-label/window-title
changes, no app icon, no installer/signing/store-publishing work, no new
calculator — all explicitly out of scope for this phase and none of it was
started.

---

## 2026-07-05 — Phase 6: Arabic default language, wording polish, quick-choice chips

Started after the project owner confirmed the app was functionally
MVP-ready through Phase 5 (Windows release build). Scope: make Arabic the
app's default language (still switchable to Hebrew/English, still not
persisted), polish Arabic wording now that it's primary, add small optional
quick-choice chips if they fit cleanly, and confirm the Arabic copy-result
text reads well for WhatsApp — explicitly no database/storage/backend/
accounts/new calculators/formula changes, per the same standing rules as
every prior phase (see [docs/CLAUDE_RULES.md](docs/CLAUDE_RULES.md)).

### Arabic default: why a fixed locale, not a resolved one

Phases 0–5 had `MyApp._locale` start `null`, which told `MaterialApp` to
resolve a locale via `localeListResolutionCallback`: walk the device's
preferred-locale list, use the first supported match, else fall back to
English. This phase's brief was explicit that this was no longer the
wanted behavior — "do not use system locale as the default if it causes
English/Hebrew to open first." The fix: `MyApp` now takes an
`initialLocale` parameter defaulting to `const Locale('ar')`, and
`_MyAppState.initState()` copies it into `_locale`. The now-unreachable
`localeListResolutionCallback` (only ever consulted by `MaterialApp` when
`locale` is `null`, which it now never is) was deleted rather than left in
place as dead code.

`initialLocale` being a real constructor parameter (not just a hardcoded
`Locale('ar')` inline) was a deliberate choice for testability: it lets
tests start directly in a specific language — `const MyApp()` for real
default-Arabic behavior, `const MyApp(initialLocale: Locale('en'))` for
tests that care about validation/calculation wiring rather than language —
without every test needing to drive the language-switcher UI first just to
get into a known state.

### Why the two big screen-test files were pinned to English rather than translated

`test/calculators/square_meters_to_cartons_screen_test.dart` and
`test/calculators/cartons_to_square_meters_screen_test.dart` contain the
bulk of this project's validation and cross-field-edge-case coverage
(built up over Phases 1–4) — dozens of assertions like "Enter a number
greater than 0" or "Enter cartons per pallet, or clear the pallets count".
None of that logic is language-specific; translating every assertion into
Arabic would have meant re-verifying dozens of Arabic strings by hand for
zero additional coverage, with real risk of introducing a typo that then
either silently over-matches or under-matches. Instead, both files now
pump `const MyApp(initialLocale: Locale('en'))` and are otherwise
completely unchanged — a one-line-per-test diff, all existing assertions
intact. Arabic-default behavior itself is covered separately and
specifically by `test/widget_test.dart` and the two new files below.

### A real, unrelated bug this work surfaced: `pageBack()` assumes English

`test/widget_test.dart` had two tests that call
`WidgetTester.pageBack()` to return to the home screen. Once the app
defaulted to Arabic, both started failing with "One back button expected
on screen" — reading `pageBack()`'s own source
(`flutter_test/lib/src/widget_tester.dart`) showed it looks for
`find.byTooltip('Back')` first, falling back to
`CupertinoNavigationBarBackButton` only if that's empty. Material's
`BackButton` under an Arabic `MaterialLocalizations` has a different
tooltip text (not the literal English word "Back"), so neither finder
matched. Fixed by tapping `find.byType(BackButton)` directly instead —
locale-independent, and exactly what `pageBack()` was trying to do anyway.
Worth remembering for any future test that navigates back while not in
English.

### Arabic wording polish: mostly already done, two real changes

A fresh review against a supplied preferred-term list (حاسبة البلاط، متر،
كرتونة، كراتين، باليت/مشتاح، باليتات/مشاتيح، الاحتياط، الزيادة، كراتين
إضافية، نسخ للواتساب/نسخ النتيجة) found that Phases 2–4's own wording passes
had already applied nearly every term exactly as listed. Two decisions:

1. **`homeTagline` (Arabic only)**: "حساب سريع لكمية البلاط" →
   **"حاسبة البلاط"** ("Tile Calculator") — the one preferred term with no
   existing home in the string set, and a natural short subtitle under the
   "TileMate" app title. English and Hebrew `homeTagline` were left as-is;
   translations don't need to restate each other literally.
2. **`copyResultButtonLabel`**: kept as "نسخ النتيجة" ("Copy result"),
   *not* changed to "نسخ للواتساب" ("Copy for WhatsApp"). The button copies
   to the generic system clipboard — no WhatsApp-specific integration
   exists or was added this phase — so the WhatsApp-specific wording would
   overpromise a feature that isn't there.

See [docs/I18N_PLAN.md](docs/I18N_PLAN.md) for the full writeup, including
why every other Arabic string needed no change.

### Quick-choice chips: a text-field shortcut, deliberately not a catalog

Added `QuickChoiceChips` (`lib/calculators/common/calculator_form_widgets.dart`):
a small `Wrap` of `ActionChip`s under a short label. Tapping one writes a
preset value directly into an existing `TextEditingController` — the exact
same code path typing already goes through, so live recalculation and
per-field validation both fire normally, with zero special-casing needed.

- **Calculator 1**: tile-size chips ("60×60", "80×80", "120×60") after the
  tile width field (one tap fills both length and width), and waste chips
  ("0%", "5%", "10%") after the waste field.
- **Calculator 2**: the same tile-size chips only (no waste field exists
  there to attach chips to).

Deliberately built as a fixed, hardcoded row rather than a dropdown,
autocomplete, or any kind of saved/recent-values list — the latter would
have started to look like a tile catalog, explicitly out of scope for this
phase. The chip values themselves ("60×60", "5%", etc.) were deliberately
**not** made ARB keys — they're plain digits and a multiplication/percent
sign, not language-dependent text, same reasoning already applied to every
other formatted number in the app. Two new ARB keys were added for the
labels *above* the chip rows: `quickSizesLabel` and `quickWastePercentLabel`.

Verified with a dedicated test
(`test/calculators/quick_choice_chips_test.dart`) that: a chip fills both
tile fields correctly (including a non-square preset, proving the two
fields can receive different values); a second chip tap overwrites the
first; manual typing into a field still works immediately after a chip tap
(chips are a shortcut, never a lock); and Calculator 2 shows no waste chips.
One practical finding while writing this test: the waste-chip row sits
below the fold in the default 800×600 test surface, and `tester.tap()`
(unlike `tester.enterText()`) needs the target actually scrolled into view
first — fixed with `tester.ensureVisible()`, the same pattern already used
for the "Clear"/"Copy result" buttons since earlier phases.

### Arabic copy-result verified for real, not assumed

The clipboard-text builders themselves (unchanged since Phase 3) already
produced app name → calculator type → every input → blank line → full
result, including the باليت/مشتاح breakdown when present — this logic is
locale-agnostic, since it's built from the same localized `AppLocalizations`
getters the on-screen result card uses. What Phase 6 added was **proof**,
not new logic: a new test in `test/l10n/arabic_default_examples_test.dart`
mocks `Clipboard.setData` and asserts on the literal Arabic copied string
for both calculators' approved examples, checking it contains the app name,
calculator type, tile dimensions, entered quantities, and the final
result/pallet breakdown. No share package, PDF export, or printing was
added — copying to the system clipboard for the user to paste wherever they
like (WhatsApp or otherwise) remains the entire mechanism, unchanged since
Phase 3.

### Testing results

Four new tests (2 in `test/calculators/quick_choice_chips_test.dart`, 2 in
the new `test/l10n/arabic_default_examples_test.dart`), on top of
extensive rewrites (not additions) to `test/widget_test.dart` and
`test/responsive_layout_test.dart` to match the new Arabic-by-default
navigation flow, plus the `initialLocale: Locale('en')` pin added to both
existing calculator screen-wiring test files. Final result:
`flutter analyze` — 0 issues; `flutter test` — 74/74 passing (up from 70 at
the end of Phase 5). Both approved examples (Calculator 1:
100/60/60/4/40/5%→73 cartons/105.12 m²/1 pallet/33 extra; Calculator 2:
60/60/4/empty/2/40→80 cartons/320 tiles/115.20 m²) reconfirmed exact,
including directly against the real Arabic default, not only via the
English-pinned wiring tests.

### What was intentionally not touched

No calculation formula, no new dependency, no database/storage/history/
catalog/accounts/backend, no language persistence, no share/PDF/print
package, no new calculator, no Android/iOS/installer/signing work — all
explicitly out of scope for this phase and none of it was started.

---

## 2026-07-04 — Phase 5: Windows release build

Started after the project owner confirmed Phase 4 was manually verified on
Windows. Scope: produce a clean Windows **release** build (not an
installer) and document how to run/share it — no product changes of any
kind. Same standing autonomous-work permission as Phases 3–4, with an
explicit list of things that would require stopping to ask first (missing
system tools, admin permissions, installer/packaging, new dependencies,
behavior/formula changes) — none of which came up.

### Commands run, in order

```
flutter analyze                    -> No issues found!
flutter test                       -> All 70 tests passed
flutter doctor -v                  -> confirmed Visual Studio Desktop C++
                                       workload is installed (Android SDK
                                       still isn't, but that's irrelevant
                                       to a Windows build)
flutter build windows --release    -> succeeded on the first attempt
```

At that point the release folder already looked correct, but a
`Get-ChildItem -Recurse` over it turned up an empty
`data\flutter_assets\packages\cupertino_icons\assets\` directory — a leftover
from *before* Phase 3 removed the `cupertino_icons` dependency. `flutter
build windows` on top of an existing `build\` directory doesn't prune
asset folders that are no longer referenced; only a full `flutter clean`
does. Since Phase 5's stated goal was specifically a *clean* release build,
this was worth redoing properly rather than shipping documentation around a
build folder known to contain stale cruft:

```
flutter clean                      -> removed build\, .dart_tool\, ephemeral\
flutter pub get                    -> dependencies restored (pubspec.lock
                                       versions honored; 5 packages have
                                       newer versions available upstream,
                                       left alone — upgrading wasn't asked
                                       for and would be an out-of-scope
                                       dependency change)
flutter analyze                    -> No issues found! (re-confirmed post-clean)
flutter test                       -> All 70 tests passed (re-confirmed post-clean)
flutter build windows --release    -> succeeded; 40.9s
```

The rebuilt `Release` folder no longer contains the stale `cupertino_icons`
directory (confirmed with `Test-Path`, returned `False`).

### Build result and verification

Output: `build\windows\x64\runner\Release\tilemate.exe`, alongside
`flutter_windows.dll` and a `data\` folder (`app.so`, `icudtl.dat`,
`flutter_assets\`) — total ~28 MB across the whole folder.

**Didn't stop at "the build command exited 0."** Launched `tilemate.exe`
directly from inside the built `Release` folder
(`Start-Process -PassThru`), waited a few seconds, and confirmed via
`Get-Process` that it was still running with a real main window (title
"tilemate") before stopping it. This is what the phase brief specifically
asked for — "do not tell the user to copy only the .exe unless you confirm
it works alone" — answered with an actual launch, not an assumption based
on general Flutter knowledge alone (though the general knowledge, that
`flutter_windows.dll` and `data\` are hard runtime requirements loaded at
startup, is also accurate and is why the whole folder is needed, not just
the `.exe`).

### Documentation decisions

**README.md** gained a new "Building a Windows release" section rather
than folding release instructions into the existing "Run" section — release
builds and `flutter run -d windows` debug sessions have different
prerequisites-in-practice (a release build is the thing you'd actually hand
to someone) and different output (a folder to copy vs. a live debug
session), so they read better as separate, clearly-labeled steps.

**RELEASE_NOTES.md** was added as a new top-level file, separate from
PROJECT_PROGRESS.md. PROJECT_PROGRESS.md answers "where does the project
stand and what should happen next" (a working-state doc for whoever
continues developing); RELEASE_NOTES.md answers "what's in this build and
how do I run it" (a doc for whoever just wants to *use* the app on
Windows). Distinct audiences, so kept as distinct files rather than
combined.

**Did not change `pubspec.yaml`'s version number** (`1.0.0+1`, the
`flutter create` default, never touched in any prior phase). Bumping it
would be a product/versioning decision the brief didn't ask for; documented
the build against its current version number instead of unilaterally
picking a new one.

**Flagged, but did not test, the Visual C++ Redistributable dependency.**
Standard Flutter Windows knowledge: a release build can depend on the
target machine having the Microsoft Visual C++ Redistributable, which most
Windows 10/11 machines already have. No second, genuinely clean Windows
machine was available in this environment to actually reproduce a missing-
redistributable failure, so this is documented as a known, standard caveat
with a concrete symptom to watch for (a missing-DLL error mentioning
something like `VCRUNTIME140.dll`), not something empirically confirmed
against its absence — the distinction is called out explicitly in both
README.md and PROJECT_PROGRESS.md so it doesn't read as more thoroughly
verified than it actually was.

### Testing results

No new `flutter test` cases were added — there is no meaningful automated
test for "does a native Windows release binary launch," since
`flutter_test`'s headless harness doesn't spawn real OS processes. Instead,
`docs/TEST_PLAN.md` gained a new section documenting the build-and-launch
verification *process* itself (clean → analyze → test → build → inspect
output → launch → confirm running → stop), so it's repeatable and
auditable even though it isn't a `flutter test` assertion. `docs/TEST_PLAN.md`'s
"Environment constraints" section was also updated: this sandbox now has
Visual Studio's Desktop C++ workload installed (it didn't as of Phase 0–4),
so Windows builds and on-device-equivalent runs are now possible here,
narrowing the previously-broader "no on-device verification possible in
this sandbox" caveat down to just Android (still no SDK) and iOS (still
needs a Mac).

Final result: `flutter analyze` — 0 issues; `flutter test` — 70/70 passing;
`flutter build windows --release` — succeeded; release binary confirmed to
launch and run standalone from its folder. No files under `lib/` or `test/`
were touched this phase — every change was to build tooling invocation and
documentation (`README.md`, `RELEASE_NOTES.md` (new),
`docs/TEST_PLAN.md`, `PROJECT_PROGRESS.md`, this file).

---

## 2026-07-04 — Phase 4: Calculator 2 pallets-only fix + Arabic باليت/مشتاح wording

Started after the project owner confirmed Phase 3 was complete, with the
same standing autonomous-work permission as Phase 3 for all safe, in-scope
Phase 4 changes. Scope: exactly two fixes — Calculator 2's validation logic
and Arabic pallet wording — no new features, no formula changes beyond the
specifically requested one.

### Why cartons count became optional in Calculator 2

**The report:** Calculator 2 required "cartons count," which made it
impossible to calculate a pallets-only order — a real, common scenario
(a shop worker who only knows "2 pallets of 40 cartons," with no loose
cartons at all, had no way to get a total from the app).

**The fix, in the pure calculation layer
(`cartons_to_square_meters_calculator.dart`):**
`CartonsToSquareMetersInput.cartonsCount` changed from a required `int` to
an optional `int?`, defaulting to `0` inside
`calculateCartonsToSquareMeters` exactly the way `palletsCount` and
`cartonsPerPallet` already did — this is a **type-level relaxation**, not a
formula change; `totalCartons = manualCartons + (pallets *
cartonsPerPallet)` is the same arithmetic Phase 2 shipped.
`CartonsToSquareMetersResult` also gained a `cartonsPerPallet` field
(previously computed but not stored on the result — the screen re-read it
from the raw controller text for the clipboard builder instead), needed
now that Phase 4 also puts it on-screen.

**The fix, in validation (`cartons_to_square_meters_screen.dart`):** two
cross-field rules now coexist:

1. *(Unchanged since Phase 2)* If pallets count is filled in and `> 0`,
   cartons per pallet is required. Still uses the `GlobalKey`-forced
   `.validate()` trick from Phase 2, since this rule is asymmetric — a user
   filling in pallets count might never touch cartons-per-pallet directly.
2. *(New)* At least one of extra cartons / pallets count must be `> 0`.
   This rule is **symmetric**, so it doesn't need the same forcing trick:
   whichever field the user actually touches can correctly cross-check the
   other field's current raw text from inside its own validator. There's
   no "invisible to the user" gap the way there is for rule 1, where the
   newly-required field is a *third*, potentially-untouched field. This
   distinction — symmetric cross-field rules can self-check, asymmetric
   ones need forcing — is worth remembering if Calculator 2 ever grows
   another cross-field rule.

**Empty and explicit `0` are treated identically**, for both extra cartons
and pallets count — normalized to `null` at parse time (via the new
`parseNonNegativeInt` helper in `numeric_input.dart`) so every downstream
check (`hasPalletInfo`, the "at least one" rule, the formula's defaulting)
only has to reason about one case, not two. This mirrors how waste
percentage already worked in Calculator 1 since Phase 1.

**UI wording:** the field is renamed **"Extra cartons"** (from "Cartons
count") in all three languages — English "Extra cartons", Arabic "كراتين
إضافية" (chosen over the alternative "كراتين زيادة" offered in the brief,
for consistency with the pre-existing `resultExtraCartons` value), Hebrew
"קרטונים נוספים" (reusing the existing `resultExtraCartons` value directly,
for the same consistency reason). "Cartons count" no longer accurately
described the field once it stopped being the primary required input.

**A collision this rename introduced, caught before it caused a confusing
test failure:** the renamed field label ("Extra cartons") is now the exact
same string as the pre-existing `resultExtraCartons` result-row label. Both
now render simultaneously whenever a result is showing, pallets are in
use, and extra cartons is `> 0` — `find.text('Extra cartons')` matches
twice in that specific scenario. Handled the same way Phase 2 handled an
analogous numeric collision: assert `findsNWidgets(2)` with a comment,
rather than treating it as a bug. See
[docs/TEST_PLAN.md](docs/TEST_PLAN.md).

**Result card and copy-result, both updated to match:** "Cartons per
pallet" is now shown on-screen (previously clipboard-text-only — promoted
because a pallets-only result might otherwise show almost nothing besides
the total), and "Extra cartons" only appears/is only listed when it's
actually `> 0`, rather than always appearing once any pallet info exists.

### Arabic terminology decision: باليت/مشتاح

Phase 3 encountered "مشتاح" in that phase's brief with no gloss, couldn't
match it to any recognized Arabic word for a tiling/pallet concept, and
deliberately left it unapplied rather than guess — documented as an open
question in [docs/I18N_PLAN.md](docs/I18N_PLAN.md) with the complete list
of every key using the existing "باليت"/"باليتات" term, specifically so it
would be a fast, complete lookup whenever the project owner clarified.

**The clarification, this phase:** "مشتاح" is a genuine local/shop-floor
term used alongside the standard word "باليت," and the project owner asked
for both to appear together rather than picking one. Applied the combined
form to every one of the keys Phase 3 had already catalogued —
`fieldCartonsPerPalletLabel`, `calc1FieldCartonsPerPalletHelper`,
`calc2FieldPalletsCountLabel`/`...Helper`, `calc2FieldCartonsPerPalletHelper`,
`calc2ValidationCartonsPerPalletRequired`, `resultFullPallets`, and the
renamed `resultCartonsPerPalletLabel`/`clipboardPalletsCountLabel` — plus
the new `calc2ValidationCartonsOrPalletsRequired` key added this phase.

**A grammar wrinkle worth recording:** Arabic adds its own "ال" ("the")
definite-article prefix to *each side* of the slash when the surrounding
phrase is definite (e.g. "الباليتات/المشاتيح," "the pallets/crates"), so
roughly half the affected strings read "باليت/مشتاح" bare and the other
half read "الباليت/المشتاح" or "الباليتات/المشاتيح" — both are correct
Arabic, and both count as "using the combined term." The verification test
(`test/l10n/arabic_pallet_wording_test.dart`) checks for the two root words
appearing together rather than one rigid contiguous substring, specifically
so it doesn't falsely fail on the grammatically-correct definite variants.

**Deliberately scoped to Arabic only.** English and Hebrew pallet wording
is unchanged — the project owner was explicit that "مشتاح" is a local
Arabic term and should not be forced into the other two languages. Also
deliberately **not** applied to the extra-cartons keys, since those
describe cartons *not* on a pallet at all; mentioning pallets there would
be actively confusing rather than helpful.

### Testing results

13 new/changed tests, 70 total (up from 57 at the end of Phase 3):

- `cartons_to_square_meters_calculator_test.dart` (+1): the exact
  pallets-only example from the brief (60×60cm tile, 4/carton, cartons
  count omitted, 2 pallets × 40/pallet → 80 total cartons, 320 total tiles,
  115.20 m²), added as the first test in the file to flag it as this
  phase's flagship case. All 6 pre-existing tests in this file needed no
  changes at all — `cartonsCount:` remains valid to pass explicitly, so
  every scenario that already specified it kept working unchanged.
- `numeric_input_test.dart` (+5): a new `parseNonNegativeInt` group
  (accepts zero, accepts positive, rejects negative, rejects decimals,
  rejects empty/null/non-numeric) — the helper `0`-and-empty-are-both-valid
  fields now share.
- `cartons_to_square_meters_screen_test.dart` (+1 net: one new test, one
  reworked, three relabeled): added the screen-level pallets-only
  counterpart to the calculator-level test above; replaced the old
  "invalid required input" test (which typed `0` into the then-required
  "Cartons count" and expected "Enter a number greater than 0" — no longer
  a meaningful scenario now that `0`/empty is valid there on its own) with
  a test for the new "enter cartons or pallets count" message; relabeled
  every remaining `_enterText(..., 'Cartons count', ...)` call to `'Extra
  cartons'` without changing their underlying logic, since that logic was
  already correct.
- `test/l10n/arabic_pallet_wording_test.dart` (+6, new file): the "Arabic
  wording test if practical" requested in the brief. Instantiates the
  generated `AppLocalizationsAr` class directly rather than pumping a
  widget tree — a plain Dart object test, immune to font/bidi-rendering
  flakiness, that checks specific getters for the combined term.
- `test/widget_test.dart` and `test/responsive_layout_test.dart`: one-line
  label updates each (`'Cartons count'` → `'Extra cartons'`), no new tests.

**Caught by `flutter analyze`, not a test:** `square_meters_to_cartons_screen.dart`
(Calculator 1) had one stale reference to `clipboardCartonsPerPalletLabel`,
the ARB key renamed to `resultCartonsPerPalletLabel` as part of Calculator
2's result-card change — the key is shared across both calculators'
clipboard builders, so a Calculator-2-motivated rename still had to be
chased down in Calculator 1's file too. A reminder that `flutter analyze`
after any ARB rename is load-bearing even when the rename's *purpose* was
scoped to one screen.

Final result: `flutter analyze` — 0 issues; `flutter test` — 70/70 passing.
Calculator 1 re-verified working unchanged (its own tests needed no edits
beyond the one stale clipboard-key reference above).

---

## 2026-07-04 — Phase 3: polish, validation hardening, copy-result rework

Started after the project owner confirmed Phase 2 (Calculator 2) was
manually verified working on Windows, with explicit standing permission to
make all safe, in-scope Phase 3 changes autonomously. Scope: final UI
polish, wording re-review, validation hardening, copy-result polish,
release-readiness checks — no new product features, no formula changes
unless a real bug was found.

Work was researched via three parallel investigation passes (UI/layout
code, ARB wording, validation/calculation logic) before any changes were
made, specifically to avoid guessing at what needed fixing.

### The significant find: a real validation-timing bug, present since Phase 1

A new test — "An empty required field shows the required-field message,"
added to close a gap the validation-edge-case review flagged (only
zero/negative had ever been tested against a required field, not genuinely
empty) — failed in a very telling way: after touching *only one* field,
**four** fields showed "This field is required."

Investigated by reading `Form`/`FormField`'s source directly
(`C:\src\flutter\packages\flutter\lib\src\widgets\form.dart`) rather than
guessing from documentation, since the behavior contradicted this
project's own stated design ("an empty form never greets the user with red
error text on first open," documented since Phase 1). Root cause:
`FormState.build()` treats `Form.autovalidateMode` as a **form-wide gate**
— its exact logic is `if (_hasInteractedByUser) { _validate(view); }`,
where `_hasInteractedByUser` is the form's own *aggregate* flag (true once
*any* registered field has been touched, not the touched field's own), and
`_validate()` calls the public, unconditional `FormFieldState.validate()`
on *every* field, bypassing that field's own interaction tracking entirely.
Separately, `TextFormField`'s own `autovalidateMode` constructor parameter
defaults to `AutovalidateMode.disabled` when not set — it does **not**
read the ambient `Form`'s value, despite how naturally that reads. Every
calculator screen had `autovalidateMode: AutovalidateMode.onUserInteraction`
set on the `Form` and nothing on the individual `TextFormField`s — exactly
the combination that produces this bug. In effect, `AutovalidateMode
.onUserInteraction` at the `Form` level means "once anything in this form
has been touched, bulk-validate everything on every rebuild," not "each
field validates once it individually has been touched" — the opposite of
what the name and this project's Phase 1/2 documentation assumed.

**Fixed** by removing `autovalidateMode` from `CalculatorScreenScaffold`'s
`Form` (falls back to `Form`'s own default, `disabled`, so the bulk-validate
path never fires) and adding `autovalidateMode:
AutovalidateMode.onUserInteraction` explicitly to `NumberField`'s
`TextFormField`. Verified this doesn't regress Calculator 2's cross-field
pallets validation (a separate, `GlobalKey`-based `.validate()` call added
in Phase 2), since that mechanism is unconditional and was never dependent
on either autovalidateMode setting — re-ran that specific test after the
fix to confirm. This bug had been present, silently, since Phase 1;
nothing caught it earlier because the existing "fill in all four required
fields" tests only ever checked state after *all* fields were valid, never
the intermediate "some filled, some not" state a real shop worker
routinely passes through.

### UI polish decisions

**Extracted two more shared widgets**, `CalculatorScreenScaffold` (full
screen shell: `Scaffold`/`AppBar`/`SafeArea`/centered `Form`) and
`ResultHero` (the big headline number), after the UI-layout research pass
found both duplicated verbatim between the two calculator screens — the
same category of finding that justified Phase 2's `NumberField`/
`OptionalDivider`/`ResultRow` extraction. Chose to extract rather than
leave duplicated specifically because `ResultHero` needed the same
`FittedBox` overflow fix in both places anyway — fixing it once in a shared
widget is strictly safer than remembering to apply an identical fix twice.

**Hardened `ResultRow`'s value text and `ResultHero`'s number against
overflow** (`Flexible`/ellipsis on the former, `FittedBox(scaleDown)` on
the latter) — both were previously bare, unprotected `Text` widgets. Added
`test/responsive_layout_test.dart` (12 tests: home + both calculators with
a full result showing, at mobile/tablet/desktop widths, plus the home
screen in Arabic) specifically to give these fixes real, repeatable
regression coverage rather than a one-time visual check.

**Removed `AppTheme.spacingUnit`** (declared, never referenced) and fixed
two outlier `SizedBox(height: 4)` instances to `8`, matching the rest of
the app's spacing scale. **Removed `cupertino_icons`** (unused — the app
only uses Material `Icons.*`, this was leftover from the default `flutter
create` template). **Fixed `README.md`'s stale project-structure section**,
which still described the Phase-2-deleted placeholder screen and didn't
mention the `lib/calculators/` tree at all.

### Validation hardening decisions

**Added an `isFinite` check to `parsePositiveDouble`/`parseNonNegativeDouble`.**
The validation/calculation research pass reasoned through a real crash
path: a long enough digit-only string (still passes the `[0-9.]` input
formatter one keystroke at a time — nothing about typing it looks invalid)
numerically overflows a `double` to `Infinity` on parse, which then passes
the `> 0` check (`Infinity > 0` is true), flows into
`calculateSquareMetersToCartons`, and crashes on `.ceil()` — Dart's
`double.ceil()` throws `UnsupportedError` for non-finite values, and there
is no `try`/`catch` anywhere in `lib/`. Fixed at the validation layer (the
parse helpers reject non-finite results), not by changing the calculation
formula itself.

**Added `maxLength: 9` to every `NumberField`**, with the built-in
character counter suppressed (`buildCounter` returns `null` — a visible
"0/9" under every field would be clutter). Chosen as a second, independent
layer of protection: 9 digits is far more than any real shop quantity
needs, and caps parsed values well inside the range where the `Infinity`
overflow above could even occur, without needing to reason about exact
floating-point overflow thresholds at the UI layer. Considered a tighter
cap to also rule out 64-bit integer overflow in chained multiplications
(e.g. `totalCartons * tilesPerCarton`), but the worst case requires *every*
field simultaneously maxed at 9 digits — produces a wrong number, not a
crash, and needs deliberately adversarial input no real order would
produce. Documented as an accepted limitation (see
[PROJECT_PROGRESS.md](PROJECT_PROGRESS.md)) rather than chased with a
tighter cap or cross-field size validation, which felt disproportionate to
the actual risk — over-engineering a defense for a scenario that doesn't
cost anything worse than a visibly-wrong number a shop worker would
immediately notice.

### Copy-result decisions

**Rebuilt both calculators' clipboard text.** The wording/clipboard
research pass found the existing text (unchanged since Phase 1/2) started
directly with the calculator title (no app name) and, worse, only echoed
*some* inputs — Calculator 1 showed "Area needed" but never the tile
dimensions, tiles-per-carton, waste %, or cartons-per-pallet size actually
used; Calculator 2 was similarly incomplete. A result pasted into WhatsApp
didn't actually tell the recipient what was calculated, just some derived
numbers. Rebuilt to: app name, calculator name, every input in the same
order as the form, a blank line, then the result. For Calculator 2
specifically, chose *not* to also repeat "Full pallets"/"Extra cartons" as
separate output lines the way the on-screen result card does — for that
calculator those are just the pallets-count/cartons-count inputs already
listed under different labels (see Phase 2's decision to reuse those
labels), so repeating them in a short clipboard message would say the same
two numbers twice for no benefit. Calculator 1 keeps them, since there
they're genuinely computed/derived, not an echo of a raw input.

**Added three new ARB keys** (`clipboardWastePercentLabel`,
`clipboardCartonsPerPalletLabel`, `clipboardPalletsCountLabel`) rather than
reusing the existing field labels for the affected fields, because three of
those labels have an `"(optional)"` suffix baked into their translated
value — correct on the input form, but reads oddly once copied into a
report of values that were actually entered ("Waste % (optional): 10").
Stripping the suffix programmatically was rejected as fragile and
locale-dependent; a dedicated clean label per language is simple and
correct.

**Added clipboard-content tests** by mocking `SystemChannels.platform`'s
`Clipboard.setData` call to capture the argument — previously entirely
untested, flagged explicitly as a gap in Phase 1's test plan. Included a
same-test check that copying, changing a field, and copying again produces
different text reflecting the new value, confirming the copy path was
never actually stale (the code already read current controller state at
copy-time; this just proves it).

### Wording decisions

Re-reviewed every ARB string against Phase 2's "natural, shop-casual, not
formal" bar, plus a fresh Arabic "use consistent terms" checklist supplied
in this phase's brief (كرتونة/carton, متر/meter, الاحتياط/allowance,
الزيادة/excess). All four were already the established terms from Phase 2;
no wording changes resulted from the re-review itself.

**Deliberately did not apply one term from the brief.** The checklist also
listed "مشتاح" alongside the four terms above, with no gloss and no
context. This does not correspond to any recognized Arabic word for a
tiling/carton/pallet concept. Rather than guess (a wrong or invented word
in a live shop tool is worse than leaving the existing, correct term in
place), left the established "باليت"/"باليتات" (pallet/pallets — a
standard, widely-used Arabic trade loanword, in place since Phase 1)
untouched, and documented every key using it in
[docs/I18N_PLAN.md](docs/I18N_PLAN.md) so it's a one-place lookup if the
project owner clarifies what was meant.

### Other decisions

**Did not add a language switcher to the calculator screens.** The brief
asked to verify "switching language after entering values" as an edge
case, which read as "confirm no bug," not "add a new place to switch
language." Verified via a new test (fill Calculator 1, pop to home, switch
to Arabic, reopen Calculator 1) that this already works correctly — popping
back to home fully discards a calculator's in-progress state by
construction (`Navigator.push` always builds a fresh widget/`State`), so
there was nothing to fix. Noted the alternative reading (add the switcher
to each calculator's app bar for convenience) as an available future
enhancement rather than assuming it was wanted.

### Testing results

21 new tests, 57 total (up from 36 at the end of Phase 2):
`test/responsive_layout_test.dart` (12, new file), `numeric_input_test.dart`
(+3: accepts-large-realistic-value plus two Infinity-rejection cases),
both `*_calculator_test.dart` files (+1 each: a large-but-realistic
commercial-scale order), `widget_test.dart` (+2: reopen-fresh,
language-switch-then-reopen), `square_meters_to_cartons_screen_test.dart`
(+2: empty-required-field, clipboard-content-and-freshness). Two existing
calculator tests were renamed (not added) to explicitly flag them as this
phase's required examples (100/60/60/4/40/5%→73 cartons/105.12m² for
Calculator 1; 60/60/4/33/1/40→73 cartons/105.12m² for Calculator 2) and,
for Calculator 1's, gained an `actualDeliveredM2` assertion that had been
missing. Final result: `flutter analyze` — 0 issues; `flutter test` —
57/57 passing. Both required example results confirmed still exact.

---

## 2026-07-04 — Phase 2: Calculator 2, shared widgets, and a full wording pass

Started after the project owner confirmed Phase 1 (Calculator 1) was
manually verified working on Windows. Scope: build Calculator 2
(cartons/pallets → square meters), improve ARB wording across all three
languages, keep Calculator 1 working and offline-only/database-free
throughout.

### Calculation decisions

**Modeled `palletsCount` as nullable in both the input and result**, not
defaulted to `0`, specifically so the UI can distinguish "pallets weren't
used" (hide the pallet breakdown entirely) from "pallets count happens to
be zero" (which the validation rules don't even allow, but the type
distinction matters for *why* the breakdown shows or hides). The pure
function still treats a `null` as contributing `0` to the arithmetic
(`effectivePalletsCount = input.palletsCount ?? 0`), so the two concerns —
"what number to use" vs. "whether to display the pallet section" — stay
separated instead of conflating a real zero with an absent value.

**Cross-field validation rule** ("pallets count filled requires
cartons-per-pallet filled") is enforced in two places that both had to
independently get it right: `_recalculate()` (gates whether a result is
computed at all) and the cartons-per-pallet field's own `validator`
closure (decides what error text to show). Discovered along the way: `Form`
`AutovalidateMode.onUserInteraction` only re-validates a field once *that
field itself* has been touched — so a user who fills in pallets count but
never taps cartons-per-pallet would never see the dependency error under
the default behavior. Confirmed by reading `FormField`'s source in the
installed Flutter SDK (`C:\src\flutter\packages\flutter\lib\src\widgets\form.dart`)
rather than guessing. Fixed by adding an optional `fieldKey` parameter to
the shared `NumberField` widget, attaching a
`GlobalKey<FormFieldState<String>>` to cartons-per-pallet specifically, and
calling `.validate()` on it directly at the top of `_recalculate()` (which
runs on every keystroke across all six fields) — this keeps the field's
displayed error current regardless of which field the user actually
touched, without forcing premature "required" errors on untouched fields
elsewhere (verified this doesn't happen: the cross-field validator only
produces an error when pallets count is genuinely non-empty, so calling it
early and often is harmless).

**Result-label reuse across calculators.** Calculator 2's pallet
breakdown reuses Calculator 1's `resultFullPallets` ("Full pallets") and
`resultExtraCartons` ("Extra cartons") labels for its directly-entered
pallets count and cartons count, rather than inventing new labels — the
real-world meaning is identical (a full pallet is a full pallet whether the
app computed the count or the shop worker typed it in), so one translated
label serves both. Also reused `resultTileArea`/`resultCartonArea` as-is,
since those are the same computation in both calculators. Only
`resultTotalCartons`, `resultTotalTiles`, and `resultTotalArea` were new
Calculator-2-specific result keys.

### Wording and translation cleanup decisions

Reviewed every ARB string in `en`/`ar`/`he` for tone, not just added
Calculator 2's. The instruction included specific Arabic examples, which
set the pattern applied more broadly:

- Arabic: "الاحتياط" replaced "الهالك" for the waste-allowance concept
  (same practical meaning — an extra buffer for cuts/breakage — but less
  formal/negative-sounding); "المتر المطلوب" replaced "المساحة المطلوبة"
  (colloquial "متر" for square-meterage, as tradespeople actually say it);
  "الزيادة" replaced "المساحة الزائدة"; "المتر الفعلي" replaced "المساحة
  الفعلية المسلَّمة"; both calculator titles/subtitles rewritten as short
  "احسب من X لـ Y" phrases per the given examples, deliberately avoiding a
  literal "→" arrow glyph in the translated text (a Phase 0 decision,
  reaffirmed: an arrow mixed into bidi Arabic/Hebrew text can render
  ambiguously, so "X to Y" is spelled out in words instead).
- Hebrew: shortened formal constructions — "שדה חובה" replaced "שדה זה הוא
  חובה"; "שטח בפועל" replaced "שטח בפועל שיסופק"; "משטחים" replaced
  "משטחים מלאים"; card subtitles rewritten as casual questions ("כמה
  קרטונים צריך" instead of a formal imperative sentence).
- English: shortened where it clearly helped ("Area needed" for "Requested
  area," "Waste %" for "Waste percentage") but left "waste" itself alone —
  it's standard, plain tiling-trade terminology in English, not jargon,
  unlike its Arabic counterpart which read as needlessly formal. Not every
  language needed the same treatment; matching each language's own sense of
  "plain" mattered more than mechanically parallel translations.
- `unitSquareMeters` was deliberately given a **different value per
  locale** (`"m²"` / `"م²"` / `` `מ"ר` ``) rather than kept identical like
  the language-name keys — a unit abbreviation's conventional form actually
  differs per language (Hebrew's own convention is `מ"ר`, not a Latin "m²"
  glued onto Hebrew text), unlike a proper noun such as a language's own
  name.

### Architecture decisions

**Renamed several Calculator 1 keys to drop their `calc1` prefix**
(`calc1InputSectionTitle` → `calculatorInputSectionTitle`, plus the result/
optional section labels and the tile-length/width/tiles-per-carton/
cartons-per-pallet-label fields) once it was clear Calculator 2 needed
byte-identical strings for the same concepts. Rejected the alternative of
adding parallel `calc2*` keys with duplicate values — that would leave two
places to update if the wording changes again, for no benefit. This
qualified as the "small safe change to Calculator 1 for shared UI cleanup"
the phase instructions explicitly allowed; only key names and a few
re-worded values changed, no logic.

**Extracted `NumberField`, `OptionalDivider`, and `ResultRow`** from
Calculator 1's screen into `lib/calculators/common/calculator_form_widgets.dart`
after writing Calculator 2's screen and noticing the three widget classes
were byte-for-byte duplicates. Each screen keeps its own `_ResultCard`
(the hero number and row selection genuinely differ), but the field-level
building blocks are now shared — directly serving the phase instruction to
"reuse `lib/calculators/common/`."

**Deleted `lib/screens/placeholder_calculator_screen.dart`** and its
`comingSoonTitle`/`comingSoonMessage` ARB keys once Calculator 2 replaced
its last remaining use. The product spec fixes the scope at exactly two
calculators with no third planned, so the placeholder had no remaining
purpose — kept as dead code, it would just be a stale trap for a future
reader. Removed rather than left in place, per the standing rule against
leaving unused code around "just in case."

### Testing results

Added `test/calculators/cartons_to_square_meters_calculator_test.dart` (5
tests: the 3 required numeric scenarios, cartons-per-pallet-alone, and
both-pallet-fields-omitted) and
`test/calculators/cartons_to_square_meters_screen_test.dart` (4 tests,
including one written specifically to catch the "user never touches
cartons-per-pallet directly" cross-field validation gap described above —
this test would have failed against the naive
`AutovalidateMode.onUserInteraction`-only implementation, which is exactly
why it's there). Updated `test/widget_test.dart`'s second-calculator test
from "opens the placeholder" to "opens the real Calculator 2 screen," and
updated `test/calculators/square_meters_to_cartons_screen_test.dart` for
the one Calculator 1 field-label wording change that affected it
(`'Requested area (m²)'` → `'Area needed (m²)'`).

Hit one real test-writing mistake worth recording: initial screen-test
assertions like `expect(find.text('10'), findsOneWidget)` failed with "2
widgets found" — `find.text()` matches `EditableText`'s live content in
addition to plain `Text` widgets, so when a typed input value and its
echoed result coincidentally match (e.g. typing cartons count `10` when
the total, with no pallets, is also `10`), both the input field and the
result row match. Fixed by asserting `findsNWidgets(2)` with a comment
explaining why, rather than picking different numbers to dodge the
collision — the collision is actually a useful assertion once labeled
correctly (it proves both the input retained its value and the result
echoes it correctly).

Final result: `flutter analyze` — 0 issues; `flutter test` — 36/36 passing
(27 from Phase 0/1 plus 9 new). Calculator 1 was re-verified working
unchanged after the key renames and shared-widget extraction — none of its
3 remaining local field/result values (`calc1FieldRequestedAreaLabel`,
`calc1FieldWastePercentLabel`/`Helper`, `calc1FieldCartonsPerPalletHelper`,
and the calc1-specific result rows) needed anything beyond the wording
values themselves changing.

---

## 2026-07-04 — Phase 1: Calculator 1 (square meters → cartons/pallets)

Started after the project owner confirmed Phase 0 was manually verified
running on Windows. Scope for this phase was explicitly limited to
Calculator 1 only — Calculator 2 stays on the placeholder screen, and no
database/storage/history/catalog/language-persistence was added, per
standing rules in [docs/CLAUDE_RULES.md](docs/CLAUDE_RULES.md).

**Split calculation logic from validation from UI, deliberately.** The
formulas from [docs/CALCULATION_RULES.md](docs/CALCULATION_RULES.md) live
in a plain-Dart function (`calculateSquareMetersToCartons`) with no Flutter
import at all, taking a pre-validated `SquareMetersToCartonsInput`. Parsing
raw text into validated numbers is a separate set of small pure functions
(`parsePositiveDouble`, `parseNonNegativeDouble`, `parsePositiveInt`) in
`lib/calculators/common/`, reusable by Calculator 2 later. Only the choice
of *which localized message* to show for a given validation failure lives
in the widget layer, since that's inherently tied to `BuildContext`/`l10n`.
This split is what let the required test cases be unit-tested directly
without spinning up any widget tree.

**Treated `tilesPerCarton` and `cartonsPerPallet` as integers, not generic
positive numbers**, even though the phase brief's validation section only
said "numeric and greater than 0." Real cartons/tiles come in whole counts,
`int.tryParse` naturally rejects "4.5" with the same friendly message path,
and it sidesteps a real Dart gotcha: mixing `int` and `double` in `~/`/`%`
would have made `extraCartons` silently become a `double` instead of a
clean `int`. Waste percentage, by contrast, was kept as a `double` with a
`>= 0` (not `> 0`) rule, since the brief explicitly allows `0` there —
different lower bound for a reason, not an inconsistency.

**No "Calculate" button — the result recomputes live as each field
changes**, via a listener on every `TextEditingController`. The phase brief
didn't ask for a submit button, and live feedback fits "quickly entering
numbers" better than an extra tap. To avoid greeting the user with red
validation errors on a blank form, `Form` uses
`autovalidateMode: AutovalidateMode.onUserInteraction` (a field only
validates after it's actually been touched).

**Required cartons is shown as a large "hero" number**, separate from the
other seven-ish result rows, because that's the one number a shop worker
actually needs to act on — everything else (tile area, carton area,
requested/delivered/extra area, pallet breakdown) is supporting detail.

**Copy-to-clipboard reuses the same localized result-row labels** shown on
screen to build the copied text, rather than introducing a separate
"clipboard template" string — one source of truth per label, and the
copied text can never drift out of sync with what's displayed.

**Added a new ARB key, `unitSquareMeters`, with a genuinely different value
per locale** (`"m²"` / `"م²"` / `` `מ"ר` ``) — unlike the `languageName*`
keys from Phase 0 (which are identical proper nouns in every locale), a
unit abbreviation is not: Hebrew's conventional square-meter abbreviation
is `מ"ר`, not a Latin "m²" glued onto Hebrew text.

**Testing:** wrote the 3 required numeric scenarios plus 3 extra cases
(pallets omitted, an exact-division floating-point boundary, zero-vs-
omitted waste) against the pure calculation function; 14 cases against the
parsing helpers (covering the "reject zero/negative/invalid" requirement);
and 2 screen-level `testWidgets` tests that actually fill in the rendered
form and assert on the displayed result, the pallet breakdown, the clear
button, and a validation message — not just the underlying function, since
that's the only way to catch a wiring mistake (e.g. a controller attached
to the wrong field). One of these initially failed: `tester.tap(find.text
('Clear'))` hit a widget that had scrolled outside the 800×600 test
viewport; fixed by calling `tester.ensureVisible()` first. Updated two
Phase 0 widget tests to match the new navigation (calculator 1 opens the
real screen now; calculator 2 still opens the placeholder). Final result:
`flutter analyze` — 0 issues; `flutter test` — 27/27 passing.

**Known gap carried forward:** Phase 1 has not yet had a manual on-device
verification pass (this dev sandbox still has no Android SDK or Visual
Studio C++ workload — see [docs/TEST_PLAN.md](docs/TEST_PLAN.md)). Recorded
explicitly in [PROJECT_PROGRESS.md](PROJECT_PROGRESS.md) as an open item
rather than left implicit.

---

## 2026-07-04 — Phase 0: project setup and documentation

**Flutter SDK was not present on the machine.** `flutter`, `where.exe
flutter`, winget, and common install paths all came back empty. Asked the
project owner how to proceed (install automatically vs. prep code only vs.
wait for manual install) rather than assuming; chose to install automatically
per their answer. Downloaded Flutter 3.44.4 (stable channel) directly from
Google's official release storage, extracted to `C:\src\flutter`, and added
it to the user `PATH`. Confirmed via `flutter doctor`: Flutter itself and
Windows desktop tooling paths are fine, but the **Android SDK and Visual
Studio's "Desktop development with C++" workload are not installed** — these
were explicitly called out as out of scope for automatic installation
(much larger, more invasive installs) when the owner was asked. This means
Android and Windows builds can't be produced end-to-end in this environment
yet; `flutter analyze` and `flutter test` (which use Flutter's headless
"tester" harness and need no platform SDK) were used as the verification
method instead.

**Scaffolded only Android, iOS, and Windows** (`flutter create
--platforms=android,ios,windows`), skipping the web/macOS/Linux folders
`flutter create` generates by default. Rationale: the product spec only
targets those three platforms, and the design brief explicitly says to
avoid clutter — no reason to carry scaffolding for platforms nothing will
ever ship to. Package name `tilemate`, org `com.tilemate` (a placeholder
reverse-DNS identifier; revisit if/when a real bundle ID is needed for store
submission).

**Localization: chose ARB + `gen-l10n` with a non-synthetic output
directory** (`lib/l10n/generated/`, git-ignored), rather than the older
"synthetic package" approach. This wasn't just a style preference — this
Flutter version (3.44.4) has fully deprecated `--synthetic-package`
(`flutter gen-l10n --help` reports it "cannot be enabled and should be
removed"), so the non-synthetic output directory is the only supported path
now. Set `nullable-getter: false` so `AppLocalizations.of(context)` returns
non-null, avoiding `!`-scattering at every call site.

**Language switcher selection is intentionally in-memory only** (a nullable
`Locale?` in `MyApp`'s state, resolved via `localeListResolutionCallback`
when null). This matches the product spec's explicit instruction that the
switcher does not need to persist unless asked later — deliberately did not
reach for `shared_preferences` or any storage package.

**Verified RTL/LTR is fully automatic.** Flutter resolves text direction
from the active locale via `GlobalWidgetsLocalizations` with no manual
`Directionality` overrides required. Wrote `test/widget_test.dart` to prove
this directly (asserts `Directionality.of(context)` flips to `rtl` for
Arabic and Hebrew, stays `ltr` for English) rather than taking it on faith —
these tests pass.

**Translations for Arabic and Hebrew were written directly** (not run
through machine translation as a black box), aiming for natural business/
trade phrasing rather than literal word-for-word translation — e.g. Arabic
uses "باليتات" (a common trade loanword) for pallets, Hebrew uses "משטחים"
(the standard warehouse term), and both avoid embedding a literal "→" arrow
glyph in translated card titles (used freely in the English strings) since a
directional arrow glyph mixed into bidi text can render ambiguously; the
Arabic/Hebrew titles instead spell out "X to Y" in words.

**Design system:** Material 3 with a custom teal seed color
(`0xFF0F6E6E`) instead of Material's default purple, specifically to avoid
looking like an unstyled Flutter demo. Input decoration theming was set up
in Phase 0 even though no input fields exist yet, since "large, readable
inputs" is an explicit product requirement and it costs nothing to define
once centrally now versus per-field later.

**Home screen responsive breakpoint set at 640 logical pixels** — chosen to
be comfortably past phone widths (including landscape) while still catching
smaller windowed Windows app sizes, switching the two calculator cards
between a stacked column and a side-by-side row.

**Two calculator buttons currently navigate to a shared placeholder
"coming soon" screen**, not a dead/disabled button and not the real
calculators. This was a deliberate middle ground: Phase 0 explicitly
excludes building calculator logic, but a non-functional button would
undercut the "polished small business tool" design requirement and would
leave navigation completely untested.

**Result:** `flutter analyze` reports 0 issues; `flutter test` passes 4/4
(English defaults + LTR, Arabic switch + RTL, Hebrew switch + RTL,
calculator card navigation to placeholder). Full documentation set written:
this file, `PROJECT_PROGRESS.md`, `README.md`, and `docs/PRODUCT_SPEC.md`,
`docs/CALCULATION_RULES.md`, `docs/UI_DESIGN_PLAN.md`, `docs/I18N_PLAN.md`,
`docs/TEST_PLAN.md`, `docs/CLAUDE_RULES.md`.
