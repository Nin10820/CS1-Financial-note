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
import plus from "../assets/icons/plus.svg"
import sendUp from "../assets/icons/send-up.svg"
import squaresFour from "../assets/icons/squares-four.svg"
import user from "../assets/icons/user.svg"
import wallet from "../assets/icons/wallet.svg"
import waveform from "../assets/icons/waveform.svg"

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
  plus,
  "send-up": sendUp,
  "squares-four": squaresFour,
  user,
  wallet,
  waveform,
} as const

export type IconName = keyof typeof ICONS

export function Icon({ name, size = 20, style }: { name: IconName; size?: number; style?: CSSProperties }) {
  return (
    <span
      aria-hidden="true"
      className="fn-icon"
      style={{ width: size, height: size, ["--icon" as string]: `url("${ICONS[name]}")`, ...style }}
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
