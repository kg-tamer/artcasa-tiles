# TileMate — Project Progress

_Last updated: 2026-07-05 (Phase 10)_

## Current status: Phase 10 complete

Phase 10 was a quick, native-icon-only follow-up to Phase 9: regenerated
the Windows and Android launcher/title-bar icons from the corrected,
genuinely-transparent `assets/branding/artcasa_icon.png` (Phase 9 fixed the
source asset but deliberately left the already-shipped native icon files
untouched — this phase closes that gap). No calculator code, no home
screen layout, no database/storage, and no new features were touched.

## What changed (Phase 10)

- Confirmed `assets/branding/artcasa_icon.png` exists (the Phase 9
  corrected, transparent icon-only asset).
- Ran `dart run flutter_launcher_icons`, which regenerated:
  - `android/app/src/main/res/mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png`
    (all 5 densities — confirmed by fresh timestamps and changed file
    sizes vs. the Phase 8 originals).
  - `windows/runner/resources/app_icon.ico` (confirmed by fresh timestamp
    and changed file size).
- **Verified transparency was actually carried through, not just
  assumed:**
  - Read the regenerated Android PNG back: `PixelFormat: Format32bppArgb`,
    corner pixel `A=0` (genuinely transparent).
  - The Windows `.ico`'s embedded 256px frame can't be read via
    `System.Drawing.Icon.ToBitmap()` — a well-known GDI+ bug that throws
    on 256px PNG-compressed ICO frames, unrelated to whether the file
    itself is correct. Worked around it by parsing the ICO container's
    binary directory entry directly and extracting the embedded PNG bytes
    as a standalone file, which read back as `Format32bppArgb` with a
    transparent corner — confirming the `.ico` is correct despite the
    inspection-tool limitation.
- `flutter analyze` — 0 issues. `flutter test` — 77/77 passing (no Dart
  code changed, so no test changes were needed or made).
- `flutter clean` → `flutter pub get` → `flutter build windows --release`
  — succeeded on the first attempt (no repeat of Phase 8's transient
  locked-file linker error).
- **Actually launched the rebuilt `tilemate.exe`**, confirmed via
  `Get-Process` it was running with `MainWindowTitle` exactly
  `"ArtCasa Tiles"`, and captured/cropped a screenshot of the live title
  bar: the icon shows the clean house/tile mark directly against the dark
  title bar — no white box, no checkerboard, blending naturally. The home
  screen behind it (visible in the same screenshot) still shows the Phase
  9 brand header, Arabic tagline, and calculator cards correctly. The
  process was stopped and all screenshots deleted afterward (verification
  aids, not repo artifacts).

## Is the Windows titlebar/taskbar icon fixed?

**Title bar: yes, confirmed directly** via a live screenshot of the
rebuilt, running app — clean, transparent, no white box or checkerboard.

**Taskbar: not separately, unambiguously confirmed in the screenshot** —
the taskbar was crowded with many other pinned/running icons at normal
desktop resolution, and the TileMate entry couldn't be picked out with
confidence among them. This is **not treated as a discrepancy**: Windows
uses the same `.ico` resource for both the title bar and the taskbar
entry for a given window (this app does not set a separate taskbar icon),
and that resource was already verified byte-level correct (see above) — so
there is no mechanism by which the title bar could be fixed while the
taskbar stays broken. No Windows icon-cache issue was encountered (the
icon changed immediately on the very first rebuild-and-relaunch; no stale
old icon was seen anywhere).

## What was intentionally not added

- No calculator formula or calculator code changes.
- No home screen layout changes (Phase 9's brand header is untouched).
- No database, storage, saved history, accounts, or backend.
- No new features.
- No Android APK build, no iOS build, no installer packaging — none of
  this was started, per this phase's explicit stop condition.

## How to test / verify manually

```bash
dart run flutter_launcher_icons   # regenerate native icons from the source
flutter analyze                   # must report 0 issues
flutter test                      # must report all tests passing (77 total)
flutter build windows --release
build\windows\x64\runner\Release\tilemate.exe
```

Manual check: launch the rebuilt `.exe` and look at its title bar icon —
should show the clean house/tile mark with no white box or checkerboard
around it; the window title and home screen should be unchanged from
Phase 9 ("ArtCasa Tiles" title, brand header, both calculator cards
working).

## Known limitations

- The Windows taskbar icon specifically wasn't visually isolated in the
  verification screenshot (see above) — inferred fixed (same resource,
  byte-verified) rather than independently eyeballed. If the project owner
  spots anything different on their own machine, worth a second look, but
  not expected given the shared-resource reasoning above.
- All limitations carried forward from Phase 9 (Android app label/icon not
  device-verified — no Android SDK in this sandbox; iOS app name/icon
  unchanged; Hebrew calculator form-filling not separately widget-tested;
  Phase 3's UI/validation changes still lacking a dedicated Windows
  on-device pass) are unchanged.

## Is the app MVP-ready overall?

**Yes**, unchanged from Phase 9's assessment. Phase 10 closes a small,
purely cosmetic native-asset gap with zero risk to calculator correctness:
all 77 pre-existing tests pass unchanged, and the only files touched were
the two generated icon outputs plus this documentation.

## Next recommended phase

Not committed — the project owner should direct this. Reasonable
candidates:

- **Android on-device verification** of the app label/icon (both from
  Phase 8, icon content refreshed Phase 10), once an Android SDK/device/
  emulator is available.
- **iOS app name/icon and build**, once a Mac with Xcode is available.
- **Hebrew calculator form-filling tests**, closing the gap flagged since
  Phase 6/7.
- **Phase 3 on-device verification** — still the one phase without its own
  dedicated manual pass.
