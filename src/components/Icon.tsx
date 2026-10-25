import type { CSSProperties } from "react"
import alignLeft from "../assets/icons/align-left.svg"
import arrowDown from "../assets/icons/arrow-down.svg"
import arrowUp from "../assets/icons/arrow-up.svg"
import calendar from "../assets/icons/calendar.svg"
import caretDown from "../assets/icons/caret-down.svg"
import checkCircle from "../assets/icons/check-circle.svg"
import close from "../assets/icons/close.svg"
import edit from "../assets/icons/edit.svg"
import eyeSlash from "../assets/icons/eye-slash.svg"
import fileEdit from "../assets/icons/file-edit.svg"
import history from "../assets/icons/history.svg"
import logoMark from "../assets/icons/logo-mark.svg"
import plus from "../assets/icons/plus.svg"
import sendUp from "../assets/icons/send-up.svg"
import squaresFour from "../assets/icons/squares-four.svg"
import user from "../assets/icons/user.svg"
import wallet from "../assets/icons/wallet.svg"
import waveform from "../assets/icons/waveform.svg"
import chartPie from "../assets/icons/chart-pie.svg"

/* Shapes are the exact SVGs exported from Figma; colour comes from `currentColor` via a CSS mask,
   because the exported files carry instance colours that don't match what the design shows. */
const ICONS = {
  "align-left": alignLeft,
  calendar,
  "caret-down": caretDown,
  "check-circle": checkCircle,
  close,
  edit,
  "eye-slash": eyeSlash,
  "file-edit": fileEdit,
  history,
  "logo-mark": logoMark,
  plus,
  "send-up": sendUp,
  "squares-four": squaresFour,
  user,
  wallet,
  waveform,
  "chart-pie": chartPie,
} as const

export type IconName = keyof typeof ICONS

/* Hugeicons glyphs sit inside their 24px frame with padding; these are the Figma insets
   (outer inset minus the stroke overhang), so each glyph lands where the design puts it. */
/* Fractions of the icon size: [top, right, bottom, left]. Converted to px because CSS padding
   percentages are measured against the parent's width, not the icon's own. */
const INSET: Partial<Record<IconName, [number, number, number, number]>> = {
  calendar: [0.0417, 0.0625, 0.0417, 0.0625],
  edit: [0.0476, 0.0476, 0.0476, 0.0476],
  wallet: [0.0937, 0.0521, 0.0938, 0.0521],
  "file-edit": [0.0521, 0.0937, 0.0521, 0.0937],
  "chart-pie": [0.0902, 0.0902, 0.0833, 0.0833],
}

export function Icon({ name, size = 20, style }: { name: IconName; size?: number; style?: CSSProperties }) {
  const inset = INSET[name]
  return (
    <span
      aria-hidden="true"
      className="fn-icon"
      style={{
        width: size,
        height: size,
        padding: inset?.map((f) => `${(f * size).toFixed(2)}px`).join(" "),
        ["--icon" as string]: `url("${ICONS[name]}")`,
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
        <span className="fn-icon fn-flow-arrow__glyph" style={{ ["--icon" as string]: `url("${dir === "out" ? arrowUp : arrowDown}")` }} />
      </span>
    </span>
  )
}
