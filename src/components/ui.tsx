import { useRef, useState, type ButtonHTMLAttributes, type ReactNode } from "react"
import logoMark from "../assets/icons/logo-mark.svg"
import { Icon, type IconName } from "./Icon"

const cx = (...c: (string | false | undefined)[]) => c.filter(Boolean).join(" ")

/* ── Brand ─────────────────────────────────────────────── */

/** The green asterisk used in the quick-note pill and the assistant greeting. */
export function LogoMark({ size = 24 }: { size?: number }) {
  return <img src={logoMark} alt="" aria-hidden="true" width={size * (21.9 / 23.8)} height={size} />
}

/* ── Money ─────────────────────────────────────────────── */

/** __amount: the number, then a smaller, quieter "đ". `tone` follows the surface it sits on. */
export function Amount({
  value,
  size = 14,
  tone = "default",
  sign,
}: {
  value: string
  size?: 14 | 18 | 28 | 32
  tone?: "default" | "on-dark"
  sign?: "+" | "-"
}) {
  return (
    <span className={cx("fn-amount tnum", `fn-amount--${size}`, tone === "on-dark" && "fn-amount--on-dark")}>
      <span className="fn-amount__num">
        {sign}
        {value}
      </span>
      <span className="fn-amount__cur">đ</span>
    </span>
  )
}

/* ── Buttons ───────────────────────────────────────────── */

type IconButtonVariant = "glass" | "glass-80" | "white" | "glass-strong" | "soft" | "dark" | "on-dark" | "plain"

/** Button--Icon. glass / glass-80 / glass-strong = Liquid Glass round button (header, bottom bar,
    sheet header — Figma __modal-top uses the same white 24% glass),
    soft = bg-3 (composer +), dark = send, on-dark = white 10% on the green card, plain = no fill. */
export function IconButton({
  icon,
  label,
  variant = "glass",
  size = 40,
  iconSize,
  style,
  ...rest
}: {
  icon: IconName
  label: string
  variant?: IconButtonVariant
  size?: 32 | 36 | 40 | 44 | 48
  iconSize?: number
} & ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button
      type="button"
      aria-label={label}
      className={cx(
        "fn-icon-btn",
        `fn-icon-btn--${variant}`,
        variant.startsWith("glass") && "lg lg-press",
      )}
      style={{ width: size, height: size, ...style }}
      {...rest}
    >
      <Icon name={icon} size={iconSize ?? (size >= 48 ? 24 : size <= 32 ? 16 : 18)} />
    </button>
  )
}

/** Button — "primary" is the dark full-width action, "confirm" the green one in the AI card,
    "outline" the Discard style, "on-dark" the Summary pill on the green card,
    "glass" the Today / Done pills in sheet headers (white 32% glass, green label). */
export function Button({
  variant = "primary",
  size = "md",
  icon,
  children,
  className,
  ...rest
}: {
  variant?: "primary" | "confirm" | "outline" | "on-dark" | "glass"
  size?: "sm" | "md" | "lg"
  icon?: IconName
  children: ReactNode
} & ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button
      type="button"
      className={cx("fn-btn", `fn-btn--${variant}`, `fn-btn--${size}`, variant === "glass" && "lg lg-press", className)}
      {...rest}
    >
      {icon && <Icon name={icon} size={size === "sm" ? 16 : 20} />}
      {children}
    </button>
  )
}

/** On/off switch. Tap to flip; while held or dragged the knob becomes a glass lens. */
export function Switch({ checked, onChange, label }: { checked: boolean; onChange: (v: boolean) => void; label: string }) {
  const [pressing, setPressing] = useState(false)
  const start = useRef<{ x: number; moved: boolean } | null>(null)
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      className={cx("lg-switch", pressing && "is-pressing")}
      onPointerDown={(e) => {
        try {
      e.currentTarget.setPointerCapture(e.pointerId)
    } catch {
      /* the pointer is already gone */
    }
        start.current = { x: e.clientX, moved: false }
        setPressing(true)
      }}
      onPointerMove={(e) => {
        const s0 = start.current
        if (!s0) return
        const dx = e.clientX - s0.x
        if (Math.abs(dx) > 10) {
          s0.moved = true
          if ((dx > 0) !== checked) onChange(dx > 0)
        }
      }}
      onPointerUp={() => {
        if (start.current && !start.current.moved) onChange(!checked)
        start.current = null
        setPressing(false)
      }}
      onPointerCancel={() => ((start.current = null), setPressing(false))}
      onClick={(e) => e.detail === 0 && onChange(!checked)}
    >
      <span className="lg-switch__knob" aria-hidden="true" />
    </button>
  )
}

export type Flow = "out" | "in"
export type Category = "food" | "transport" | "received" | "other"

/** __trans-item. Default = outgoing (peach tile, up arrow), in = incoming (green tile, down arrow),
    `onEdit` turns it into the confirm-card row (no tile, pencil on the right). */
export function MonthCard({
  month,
  amount,
  count,
  state = "idle",
  onClick,
}: {
  month: string
  amount?: string
  count?: string
  state?: "selected" | "idle" | "empty" | "picked"
  onClick?: () => void
}) {
  return (
    <button
      type="button"
      className={cx("fn-month", `fn-month--${state}`)}
      aria-pressed={state === "selected" || state === "picked"}
      disabled={state === "empty"}
      onClick={onClick}
    >
      <span className="fn-month__head">
        <span className="fn-month__name">{month}</span>
        {state === "picked" && <Icon name="check-circle" size={18} />}
      </span>
      {state === "empty" ? (
        <span className="t-capture-12-m fn-month__none">None</span>
      ) : (
        <span className="fn-month__body">
          <span className="fn-month__amount tnum">
            <span>{amount}</span>
            <span className="fn-month__cur">đ</span>
          </span>
          <span className="t-micro-10-s fn-month__count">{count}</span>
        </span>
      )}
    </button>
  )
}

/* ── Chat ──────────────────────────────────────────────── */

/** __chat-send: the user's message, brand-200, square top-right corner. */
export function ChatBubble({ children }: { children: ReactNode }) {
  return (
    <div className="fn-bubble-row">
      <p className="fn-bubble t-body-14-m">{children}</p>
    </div>
  )
}

/* ── Navigation ────────────────────────────────────────── */
