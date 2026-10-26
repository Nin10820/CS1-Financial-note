import type { CSSProperties } from "react"

/* Every SVG in assets/icons was exported from the Figma file. Most are drawn as a CSS mask so the
   colour follows `currentColor` (the exported files carry instance colours that don't match the
   design). Two-tone icons keep their own colours and are drawn as images instead. */
const FILES = import.meta.glob<string>("../assets/icons/*.svg", { eager: true, query: "?url", import: "default" })
const url = (name: string) => FILES[`../assets/icons/${name}.svg`]

export type IconName =
  | "align-left"
  | "arrow-left"
  | "bell"
  | "calendar"
  | "calendar-blank"
  | "calendar-dots"
  | "caret-down"
  | "caret-left"
  | "caret-right"
  | "caret-right-sm"
  | "chart-pie"
  | "check"
  | "check-circle"
  | "check-circle-done"
  | "check-circle-fill"
  | "circle"
  | "circle-dashed"
  | "clock"
  | "close"
  | "dots-three"
  | "drop"
  | "edit"
  | "eye-slash"
  | "file-edit"
  | "gas-pump"
  | "history"
  | "house"
  | "lightning"
  | "logo-mark"
  | "monitor"
  | "note"
  | "phone"
  | "plus"
  | "plus-18"
  | "scan"
  | "send-up"
  | "sparkle-ai"
  | "squares-four"
  | "tab-due"
  | "tab-expense"
  | "tab-finance"
  | "tab-profile"
  | "student"
  | "trash"
  | "trend-up"
  | "user"
  | "wallet"
  | "waveform"

/** Keep their own colours (white check on a dark disc, gradient sparkle). */
const RAW = new Set<IconName>(["check-circle-fill", "check-circle-done", "sparkle-ai"])

/* Hugeicons glyphs sit inside their 24px frame with padding; these are the Figma insets
   (outer inset minus the stroke overhang), as fractions of the icon size [top, right, bottom, left].
   Converted to px because CSS padding percentages are measured against the parent's width. */
const INSET: Partial<Record<IconName, [number, number, number, number]>> = {
  calendar: [0.0417, 0.0625, 0.0417, 0.0625],
  edit: [0.0476, 0.0476, 0.0476, 0.0476],
  wallet: [0.0937, 0.0521, 0.0938, 0.0521],
  "file-edit": [0.0521, 0.0937, 0.0521, 0.0937],
  "chart-pie": [0.0902, 0.0902, 0.0833, 0.0833],
  note: [0.0533, 0.0533, 0.0533, 0.0533],
  bell: [0.0521, 0.0833, 0.0521, 0.0833],
  scan: [0.0667, 0.0667, 0.0667, 0.0667],
}

export function Icon({ name, size = 20, style }: { name: IconName; size?: number; style?: CSSProperties }) {
  if (RAW.has(name))
    return <img src={url(name)} alt="" aria-hidden="true" width={size} height={size} style={{ flexShrink: 0, ...style }} />
  const inset = INSET[name]
  return (
    <span
      aria-hidden="true"
      className="fn-icon"
      style={{
        width: size,
        height: size,
        padding: inset?.map((f) => `${(f * size).toFixed(2)}px`).join(" "),
        ["--icon" as string]: `url("${url(name)}")`,
        ...style,
      }}
    />
  )
}

/* Hugeicons arrow-up/down-02-round: Figma draws a 13.5×9 glyph rotated −90° and mirrored
   inside an 18px box (inset 12.5% / 25%). Reproduced as-is so the arrow sits exactly like the design. */
export function FlowArrow({ dir, size = 18 }: { dir: "out" | "in"; size?: number }) {
  return (
    <span aria-hidden="true" className="fn-flow-arrow" style={{ width: size, height: size }}>
      <span className="fn-flow-arrow__box">
        <span
          className="fn-icon fn-flow-arrow__glyph"
          style={{ ["--icon" as string]: `url("${url(dir === "out" ? "arrow-up" : "arrow-down")}")` }}
        />
      </span>
    </span>
  )
}
