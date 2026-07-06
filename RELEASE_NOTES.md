# TileMate — Release Notes

## Windows release build — 2026-07-04 (Phase 5, version 1.0.0+1)

The first Windows release build of TileMate, covering everything built in
Phases 0–4. This is a plain release folder, not an installer — see
[README.md](README.md#building-a-windows-release) for how it was built and
how to share it.

### What's in this build

- **Calculator 1** — square meters → cartons/pallets needed, with an
  optional waste percentage.
- **Calculator 2** — cartons/pallets → total square meters. Supports
  cartons-only, pallets-only, and mixed orders (fixed in Phase 4 — pallets
  no longer require a cartons count too).
- **English, Arabic, and Hebrew**, switchable at any time from the app bar.
  Arabic and Hebrew render right-to-left automatically. Arabic pallet
  wording uses the combined shop term "باليت/مشتاح".
- **Copy result** — copies a plain-text summary of any calculation to the
  clipboard for pasting into WhatsApp, notes, etc.
- Fully offline. No account, no login, no saved history, no database, no
  network access of any kind.

### How to run this build

Copy the entire `build\windows\x64\runner\Release\` folder to the target
Windows computer (not just `tilemate.exe` — see README for why) and
double-click `tilemate.exe`. No installation step, no admin rights needed.

### Known limitations

- **No installer.** This phase deliberately produced only the plain
  release folder — packaging (MSIX, an `.exe`/`.msi` installer, etc.) is a
  separate, not-yet-requested piece of work.
- **No custom app icon.** The build currently uses Flutter's default
  Windows application icon. Icon/branding work is out of scope until
  explicitly requested.
- **Target machine may need the Visual C++ Redistributable.** Standard for
  any Flutter Windows build; most Windows 10/11 PCs already have it. See
  the README for what to do if `tilemate.exe` fails to start with a
  missing-DLL error.
- Language choice and all calculator inputs reset every time the app is
  reopened — this is intentional (see
  [docs/PRODUCT_SPEC.md](docs/PRODUCT_SPEC.md)), not a bug.
- Android and iOS builds were not produced in this phase — Phase 5 was
  scoped to Windows only. See [PROJECT_PROGRESS.md](PROJECT_PROGRESS.md).

### Verification

`flutter analyze` (0 issues) and `flutter test` (70/70 passing) were run
immediately before this build, from a clean `flutter clean` state. The
built `tilemate.exe` was launched directly from the release folder and
confirmed to start and stay running. See
[PROJECT_HISTORY.md](PROJECT_HISTORY.md)'s Phase 5 entry for the exact
commands and results.
