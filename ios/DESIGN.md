# Design rules — Financial Note (iOS)

The rules every screen and sheet follows, so the app looks like one thing. Colours live in
`FinancialNote/Design/Tokens.swift`, type in `Design/Fonts.swift`, the layer helpers in
`Components/Surfaces.swift`. Use the token names below; never a hex value in a view.

## 1. Layers

Every screen is two layers, plus a few special surfaces.

| Layer | Token | Light | Dark | Used for |
|---|---|---|---|---|
| 0 · Canvas | `Tokens.canvas` (= `bgGrouped`) | `#EAECF0` | `#0C1019` | Behind every page, sheet, full-screen cover, List and Form |
| 1 · Card | `Tokens.card` (= `bgWhite`) | `#FFFFFF` | `#171C25` | Cards, list rows, form rows, the top panel of a sheet (View Analysis) |
| Hero card | `cardSurface` (green gradient) | — | — | One per page at most: Today's spend card, Due's remaining card |
| Idle chip / track | `Tokens.bg4` | `#EAECF0` | `#1D2533` | Segmented tracks, idle chips, empty pie |
| Picked segment | `Tokens.segmentOn` | `#FFFFFF` | `#364152` | The picked pill on a track (D/W/M/Y, All/out/in) |
| Keypad tray | `Tokens.keypadTray` / `keypadKey` | `#DFE1E6` / `#FFFFFF` | `#272A32` / `#364152` | The number pad only |

How to apply:

- **Sheets and covers:** put `.sheetSurface()` on the sheet's content at the `.sheet { }` /
  `.fullScreenCover { }` call. It sets `presentationBackground(Tokens.canvas)`. Don't leave
  the system's grey sheet colour.
- **Pages:** `.background(Tokens.canvas)` on the page's root.
- **List / Form:** `.appListSurface()` on the List or Form, and
  `.listRowBackground(Tokens.card)` on each `Section` (or on the `ForEach` of rows).
  This keeps Profile, asset, bill and loan sheets the same colour as the rest of the app.
- **Cards:** `.background(Tokens.card, in: .rect(cornerRadius: Corner.c20))`, padding `Space.s16`.
- Don't use `bg1`, `bg2` or `bg3` for a new background. They stay only for old code paths.

## 2. Edges and lines

| Token | Light | Dark | Used for |
|---|---|---|---|
| `bd0` | `#EEF2F6` | `#1D2533` | Row dividers inside a card |
| `bd1` | `#E3E8EF` | `#262E3C` | Hairline card edge (0.5 pt), dashed split inside a joined card |
| `bd2` | `#CDD5DF` | `#364152` | Dashed outlines (add slots), strong edges |

- Cards have no border by default. A card that joins two parts (`JoinedCard`) gets a 0.5 pt
  `bd1` edge and a dashed `bd1` line between the parts.
- No drop shadows on cards. Floating controls use Liquid Glass (`.glass`, `.glassEffect`).

## 3. Text colours

| Token | Light | Dark | Used for |
|---|---|---|---|
| `text900` | `#0D121C` | `#F3F4F6` | Titles, amounts, legend names, anything you read first |
| `text700` | `#364152` | `#CDD5DF` | Labels over amounts ("Total asset"), secondary values |
| `grey400` | `#697586` | `#9AA4B2` | Sub-lines, captions, hints, axis labels, `đ` |
| `grey300` | `#9AA4B2` | `#697586` | Disabled, empty ticks, chevrons |
| `onDark` / `onDarkMuted` | `#DCE5D6` / `#B3BFAD` | same | Text on the green hero card |

## 4. Meaning colours

- **Brand green** `brand500` (marks, ticks, bars) and `brand600` (tinted buttons, links).
  `action` (`#3B6922`) fills prominent buttons that carry white text.
- **Gain / done:** `success`. **Loss:** `grey400`, never red. There are no red "overdue" alarms.
- **Today's date dot:** `todayRed`, the only red in the app.
- **Categories / asset groups / tiles:** `Tokens.category(_)`, `Tokens.assetKind(_)`,
  `Tokens.assetTile(_)`, `Tokens.billTile(_)`. Pick from these; don't invent new hues in a view.

## 5. Type

| Role | Font call | Size |
|---|---|---|
| Big amount (hero card, page headline, stat card) | `AppFont.amount(36)` + `currency(for: 36)` | 36 |
| Section title over a card ("Assets", "Family loans") | `FinanceSectionTitle` / `heading(18, .medium)` | 18 |
| Card title ("Where your money is", "Who you still owe") | `AppFont.main(14, .semibold)` | 14 |
| Row title | `AppFont.table(15, .semibold)` | 15 |
| Row sub-line | `AppFont.table(12)` in `grey400` | 12 |
| Row amount | `AppFont.heading(16, .semibold)` | 16 |
| Legend name | `AppFont.table(13, .medium)` in `text900` | 13 |
| Caption / hint | `AppFont.main(11–12)` in `grey400` | 11–12 |

`AppFont.main` adds 1 pt for readability; `AppFont.table` doesn't (dense tables and lists).

## 6. Spacing and shape

- Space scale: `Space.s4 … s32`. Between blocks on a page: `s24`. Title to its card: `s8`.
  Inside a card: `s16` padding, rows `s12` vertical.
- Corners: cards `Corner.c20`, tiles `c8`, round tiles are circles (40 pt in lists).
- Tap targets at least 44 pt. Legend rows at least 32 pt high.

## 6b. List rows (Assets, Family loans, Due bills)

One row shape everywhere: a 40 pt solid round tile with a white icon (or "Au" / an initial),
the name (`table(15, .semibold)`) over a `grey400` sub-line (`table(12)`), and on the right
the amount with `đ` attached (`heading(16, .semibold)`) over a small second line. The card
pads `s16` on the left; dividers start under the name. Done or paid rows turn the name and
amount `grey400` and dim the tile to 60%.

## 7. Sheets checklist

Before shipping a new sheet:

1. `.sheetSurface()` at the call site.
2. List or Form → `.appListSurface()` + `.listRowBackground(Tokens.card)` per section.
3. Close / Cancel on the leading side (`xmark`); Save on the trailing side as
   `.glassProminent` tinted `brand600`.
4. Amount entry: `AmountPad` in `.safeAreaInset(edge: .bottom)`, flush with the bottom.
5. Check it in light and dark mode on the 18 Pro Simulator.
