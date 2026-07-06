# TileMate — Calculation Rules

This document is the single source of truth for calculator math. Any
implementation of Calculator 1 or Calculator 2 must match this exactly.
Formulas here use `^` for exponent-free notation (i.e. `cm / 100` converts
centimeters to meters) and `ceil()` / integer division as noted.

Status: **both calculators implemented** (Calculator 1 in Phase 1, Calculator
2 in Phase 2; Calculator 2's input validation revised in Phase 4 — see below).

- Calculator 1: `lib/calculators/square_meters_to_cartons/square_meters_to_cartons_calculator.dart`
  (pure calculation) and `.../square_meters_to_cartons_screen.dart` (form +
  result UI). Verified by `test/calculators/square_meters_to_cartons_calculator_test.dart`.
- Calculator 2: `lib/calculators/cartons_to_square_meters/cartons_to_square_meters_calculator.dart`
  (pure calculation) and `.../cartons_to_square_meters_screen.dart` (form +
  result UI). Verified by `test/calculators/cartons_to_square_meters_calculator_test.dart`.

## Shared building blocks

Both calculators derive tile and carton area the same way:

```
tileAreaM2   = (lengthCm / 100) * (widthCm / 100)
cartonAreaM2 = tileAreaM2 * tilesPerCarton
```

## Calculator 1 — Square meters → cartons/pallets

### Inputs

| Field                 | Required | Notes                     |
|-----------------------|----------|----------------------------|
| Requested square meters | Yes    | Must be > 0                |
| Tile length (cm)      | Yes      | Must be > 0                |
| Tile width (cm)       | Yes      | Must be > 0                |
| Tiles per carton      | Yes      | Must be > 0                |
| Cartons per pallet    | No       | If provided, must be > 0   |
| Waste percentage      | No       | e.g. `10` means +10%       |

### Formulas

```
tileAreaM2        = (lengthCm / 100) * (widthCm / 100)
cartonAreaM2       = tileAreaM2 * tilesPerCarton

requestedWithWaste = requestedM2 * (1 + wastePercent / 100)
requiredCartons     = ceil(requestedWithWaste / cartonAreaM2)
actualDeliveredM2   = requiredCartons * cartonAreaM2
extraM2             = actualDeliveredM2 - requestedM2

# Only when cartonsPerPallet is provided and > 0:
fullPallets  = requiredCartons ~/ cartonsPerPallet   # integer division
extraCartons = requiredCartons % cartonsPerPallet    # remainder
```

If `wastePercent` is left empty, treat it as `0` (i.e. `requestedWithWaste =
requestedM2`). If `cartonsPerPallet` is left empty or is `0`, omit the
pallet breakdown from the result entirely — do not show `fullPallets: 0`.

### Outputs

- Required cartons (integer, always rounded up)
- Actual delivered area (m², 2 decimal places)
- Extra area over the request (m², 2 decimal places)
- Full pallets + extra loose cartons (only if cartons-per-pallet was given)

## Calculator 2 — Cartons/pallets → square meters

### Inputs

*(Revised in Phase 4 — "Cartons count" was originally required, which made
it impossible to calculate a pallets-only order. It is now "Extra cartons,"
optional, on equal footing with pallets count.)*

| Field              | Required | Notes                   |
|--------------------|----------|--------------------------|
| Tile length (cm)   | Yes      | Must be > 0              |
| Tile width (cm)    | Yes      | Must be > 0              |
| Tiles per carton   | Yes      | Must be > 0              |
| Extra cartons      | No       | Loose/manual cartons not part of a pallet. Empty or `0` both mean "not used." If provided, must be `0` or a positive integer — see the "at least one" cross-field rule below |
| Pallets count      | No       | Empty or `0` both mean "not used." If provided and `> 0`, must be a positive integer and **also requires cartons per pallet to be provided** (see cross-field rule below) |
| Cartons per pallet | No       | Optional when pallets count is empty or `0`; **required and must be `> 0`** when pallets count is `> 0`. May be provided alone, without pallets count |

At least one of **extra cartons** or **pallets count** must be `> 0` —
otherwise there is nothing to total up.

### Formulas

```
manualCartons  = cartonsCount empty/0 ? 0 : cartonsCount
pallets        = palletsCount empty/0 ? 0 : palletsCount
cartonsPerPallet = cartonsPerPallet empty ? 0 : cartonsPerPallet

tileAreaM2   = (lengthCm / 100) * (widthCm / 100)
cartonAreaM2 = tileAreaM2 * tilesPerCarton

totalCartons = manualCartons + (pallets * cartonsPerPallet)
totalTiles   = totalCartons * tilesPerCarton
totalM2      = totalCartons * cartonAreaM2
```

If `palletsCount` or `cartonsPerPallet` is left empty, treat the missing one
as `0` so the `palletsCount * cartonsPerPallet` term contributes nothing —
i.e. pallets only add to the total when **both** pallet fields are provided.
The same applies symmetrically to `cartonsCount`: empty or explicit `0` both
mean "not used," and contribute `0` to `totalCartons`.

**Cross-field rule 1 (pallet size required):** if `palletsCount` is filled
in and `> 0`, `cartonsPerPallet` **must** also be filled in and `> 0` — a
pallet count without a pallet size is meaningless and must be rejected
(friendly validation message, no calculation) rather than silently treated
as `0` pallets. The reverse is not required: `cartonsPerPallet` may be
filled in on its own, with `palletsCount` left empty — in that case it
simply doesn't affect `totalCartons` (equivalent to 0 pallets), since there's
nothing wrong with a shop worker noting a pallet size out of habit before
they've entered how many pallets they have.

**Cross-field rule 2 (at least one quantity, added Phase 4):** `cartonsCount`
and `palletsCount` are each individually optional, but at least one of them
must be `> 0`. If both are empty or explicitly `0`, there is nothing to
total up — reject with a friendly validation message rather than showing a
"total" of zero. This is what makes a **pallets-only** order (the Phase 4
motivating case) valid while still rejecting a genuinely empty form.

### Outputs

- Total cartons
- Total tiles
- Total area (m², 2 decimal places)
- If pallets were actually used (`palletsCount > 0`):
  - Full pallets (the pallets count, redisplayed for confirmation)
  - Cartons per pallet (redisplayed for confirmation — shown on-screen
    since Phase 4; previously clipboard-only)
  - Extra cartons — only shown if `> 0`, since Phase 4 made it possible to
    have none at all (a pure pallets-only order)

## Validation rules (apply to both calculators)

1. Every required numeric field must be strictly greater than `0`. Empty,
   zero, negative, or non-numeric input in a required field is invalid.
2. Optional fields may be left empty. An empty optional field is valid and
   is treated per the "missing optional field" rule for that calculator
   (above), **not** as a validation error.
3. If an optional field is filled in, it is still validated — a
   provided-but-invalid optional value is rejected, not silently ignored.
   The lower bound depends on the field: cartons-per-pallet must be `> 0`
   if provided (a pallet of 0 cartons is meaningless), while **waste
   percentage** (Calculator 1) **and extra cartons / pallets count**
   (Calculator 2) **may be exactly `0`** if provided — an explicit `0` is a
   valid input, treated identically to leaving the field empty.
4. Invalid input must never crash the app. Show a friendly, localized
   validation message instead and withhold the result until input is valid.
5. All displayed square-meter values are rounded to 2 decimal places for
   display. Internal math should not round early — round only at display
   time to avoid compounding rounding error.
6. Required cartons (Calculator 1) always round **up** (`ceil`), never to
   nearest and never down. Under-ordering tiles is not an acceptable
   outcome.
7. Cross-field validation (Calculator 2 only): pallets count filled without
   a valid cartons-per-pallet is invalid on its own terms, even though both
   fields are individually "optional." Likewise, extra cartons and pallets
   count being simultaneously empty/zero is invalid, even though each is
   individually "optional." See the two cross-field rules under
   Calculator 2 above.
8. *(Added Phase 3)* A value that parses but isn't finite is invalid. A
   digit-only string long enough (hundreds of digits) numerically overflows
   a `double` to `Infinity` rather than failing to parse — which would
   otherwise pass the "> 0" check and later crash `.ceil()` (Calculator 1)
   with an `UnsupportedError`, since `Infinity`/`NaN` can't convert to
   `int`. Every input field also caps at 9 digits (`NumberField.maxLength`)
   — far beyond any real shop quantity — which independently keeps parsed
   values well inside the range where this could occur in the first place.
   This is an input-validation fix, not a formula change; see
   `lib/calculators/common/numeric_input.dart` and
   [TEST_PLAN.md](TEST_PLAN.md).

## Worked examples

These are the examples verified by
`test/calculators/square_meters_to_cartons_calculator_test.dart` for
Calculator 1 (see that file for the full list, including the exact-division
boundary case and the zero-waste-equals-omitted-waste case).

**100 m², tile 60cm × 60cm, 4 tiles/carton, no waste:**

```
tileAreaM2      = 0.6 * 0.6 = 0.36
cartonAreaM2    = 0.36 * 4 = 1.44
requiredCartons = ceil(100 / 1.44) = ceil(69.44...) = 70
actualDeliveredM2 = 70 * 1.44 = 100.8
```

**Same tile, 5% waste:**

```
requestedWithWaste = 100 * 1.05 = 105
requiredCartons     = ceil(105 / 1.44) = ceil(72.91...) = 73
actualDeliveredM2   = 73 * 1.44 = 105.12
```

**That 73-carton result, with 40 cartons/pallet:**

```
fullPallets  = 73 ~/ 40 = 1
extraCartons = 73 % 40 = 33
```

**Original worked example (Calculator 1), for reference:**

Requested: 50 m², tile 60cm × 60cm, 4 tiles/carton, 8 cartons/pallet, 10%
waste.

```
tileAreaM2         = 0.6 * 0.6 = 0.36
cartonAreaM2        = 0.36 * 4 = 1.44
requestedWithWaste  = 50 * 1.10 = 55
requiredCartons      = ceil(55 / 1.44) = ceil(38.19...) = 39
actualDeliveredM2    = 39 * 1.44 = 56.16
extraM2              = 56.16 - 50 = 6.16
fullPallets          = 39 ~/ 8 = 4
extraCartons         = 39 % 8 = 7
```

### Calculator 2 worked examples

Verified by `test/calculators/cartons_to_square_meters_calculator_test.dart`.

**Phase 4 motivating example — 2 pallets only (no extra cartons), 40
cartons/pallet, tile 60cm × 60cm, 4 tiles/carton:**

```
tileAreaM2   = 0.6 * 0.6 = 0.36
cartonAreaM2 = 0.36 * 4 = 1.44
totalCartons = 0 + (2 * 40) = 80
totalTiles   = 80 * 4 = 320
totalM2      = 80 * 1.44 = 115.20
```

**10 cartons, tile 60cm × 60cm, 4 tiles/carton, no pallets:**

```
tileAreaM2   = 0.6 * 0.6 = 0.36
cartonAreaM2 = 0.36 * 4 = 1.44
totalCartons = 10 + (0 * 0) = 10
totalTiles   = 10 * 4 = 40
totalM2      = 10 * 1.44 = 14.40
```

**1 pallet + 30 loose cartons, 40 cartons/pallet, same tile:**

```
totalCartons = 30 + (1 * 40) = 70
totalTiles   = 70 * 4 = 280
totalM2      = 70 * 1.44 = 100.80
```

**1 pallet + 33 loose cartons, 40 cartons/pallet, same tile:**

```
totalCartons = 33 + (1 * 40) = 73
totalM2      = 73 * 1.44 = 105.12
```
