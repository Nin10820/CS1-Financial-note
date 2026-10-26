import { useRef, useState, type ButtonHTMLAttributes, type CSSProperties, type HTMLAttributes, type PointerEvent as RPointerEvent, type ReactNode } from "react"
import logoMark from "../assets/icons/logo-mark.svg"
import dotFilled from "../assets/icons/dot-filled.svg"
import dotOutline from "../assets/icons/dot-outline.svg"
import leaderOut from "../assets/icons/leader-out.svg"
import leaderIn from "../assets/icons/leader-in.svg"
import { FlowArrow, Icon, type IconName } from "./Icon"

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
    sheet close), glass-strong uses the denser glass that holds up on top of sheets,
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
  size?: 32 | 36 | 40 | 48
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
        variant === "glass-strong" && "lg--thick",
      )}
      style={{ width: size, height: size, ...style }}
      {...rest}
    >
      <Icon name={icon} size={iconSize ?? (size >= 48 ? 24 : size <= 32 ? 16 : 18)} />
    </button>
  )
}

/** Button — "primary" is the dark full-width action, "confirm" the green one in the AI card,
    "outline" the Discard style, "on-dark" the Summary pill on the green card. */
export function Button({
  variant = "primary",
  size = "md",
  icon,
  children,
  className,
  ...rest
}: {
  variant?: "primary" | "confirm" | "outline" | "on-dark"
  size?: "sm" | "md" | "lg"
  icon?: IconName
  children: ReactNode
} & ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button type="button" className={cx("fn-btn", `fn-btn--${variant}`, `fn-btn--${size}`, className)} {...rest}>
      {icon && <Icon name={icon} size={size === "sm" ? 16 : 20} />}
      {children}
    </button>
  )
}

/** Header date pill: a Liquid Glass capsule with a caret. */
export function DatePill({ label, ...rest }: { label: string } & ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button type="button" className="fn-date-pill lg lg-press" {...rest}>
      <span className="t-body-14-m">{label}</span>
      <Icon name="caret-down" size={16} />
    </button>
  )
}

/* ── Selection ─────────────────────────────────────────── */

/** The All / Expense / Receive chips above a list. */
export function FilterChips<T extends string>({
  options,
  value,
  onChange,
  label,
}: {
  options: { value: T; label: string }[]
  value: T
  onChange: (v: T) => void
  label: string
}) {
  return (
    <div className="fn-chips" role="group" aria-label={label}>
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          className={cx("fn-chip", o.value === value && "is-active")}
          aria-pressed={o.value === value}
          onClick={() => onChange(o.value)}
        >
          {o.label}
        </button>
      ))}
    </div>
  )
}

/** Segmented control. The white thumb slides between options; while a finger is down it turns
    into a clear glass lens and follows the finger, then settles on the option it was released over. */
export function SegmentedTabs<T extends string>({
  options,
  value,
  onChange,
  label,
}: {
  options: { value: T; label: string; icon?: IconName }[]
  value: T
  onChange: (v: T) => void
  label: string
}) {
  const ref = useRef<HTMLDivElement>(null)
  const [drag, setDrag] = useState<number | null>(null)
  const current = Math.max(0, options.findIndex((o) => o.value === value))
  const indexAt = (x: number) => {
    const r = ref.current!.getBoundingClientRect()
    return Math.min(options.length - 1, Math.max(0, Math.floor(((x - r.left) / r.width) * options.length)))
  }
  const down = (e: RPointerEvent<HTMLDivElement>) => {
    if (e.button !== 0) return
    ref.current!.setPointerCapture(e.pointerId)
    setDrag(indexAt(e.clientX))
  }
  const move = (e: RPointerEvent<HTMLDivElement>) => drag !== null && setDrag(indexAt(e.clientX))
  const up = () => {
    if (drag !== null && options[drag].value !== value) onChange(options[drag].value)
    setDrag(null)
  }
  const shown = drag ?? current
  return (
    <div
      ref={ref}
      className={cx("lg-seg", drag !== null && "is-pressing")}
      role="tablist"
      aria-label={label}
      style={{ "--n": options.length, "--i": shown } as CSSProperties}
      onPointerDown={down}
      onPointerMove={move}
      onPointerUp={up}
      onPointerCancel={() => setDrag(null)}
    >
      <span className="lg-seg__thumb" aria-hidden="true" />
      {options.map((o, i) => (
        <button
          key={o.value}
          type="button"
          role="tab"
          aria-selected={o.value === value}
          className={cx("lg-seg__item", i === shown && "is-active")}
          onClick={(e) => e.detail === 0 && onChange(o.value)}
        >
          {o.icon && <Icon name={o.icon} size={18} />}
          <span className="t-body-14-m">{o.label}</span>
        </button>
      ))}
    </div>
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
        e.currentTarget.setPointerCapture(e.pointerId)
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

/** Toolbar group: related icon actions sharing one glass capsule (Apple: group similar actions). */
export function GlassGroup({ children, className, ...rest }: { children: ReactNode; className?: string } & HTMLAttributes<HTMLDivElement>) {
  return (
    <div className={cx("lg lg-group", className)} role="group" {...rest}>
      {children}
    </div>
  )
}

/* ── Page structure ────────────────────────────────────── */

/** __tabs-namePage: Merriweather title with a quieter second word ("Transaction  Note"). */
export function PageTitle({ title, sub }: { title: string; sub?: string }) {
  return (
    <div className="fn-page-title">
      <h1 className="t-title">{title}</h1>
      {sub && <span className="t-title-sub">{sub}</span>}
    </div>
  )
}

/** The white list sheet that slides up over the screen (ge): bg-2, 20px top corners, grab handle. */
export function Sheet({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <section className={cx("fn-sheet", className)}>
      <span className="fn-sheet__handle" aria-hidden="true" />
      {children}
    </section>
  )
}

/* ── Data display ──────────────────────────────────────── */

export type Flow = "out" | "in"
export type Category = "food" | "transport" | "received" | "other"

/** __trans-item. Default = outgoing (peach tile, up arrow), in = incoming (green tile, down arrow),
    `onEdit` turns it into the confirm-card row (no tile, pencil on the right). */
export function TransItem({
  title,
  category,
  categoryTone = "food",
  amount,
  flow = "out",
  onEdit,
  onClick,
}: {
  title: string
  category: string
  categoryTone?: Category
  amount: string
  flow?: Flow
  onEdit?: () => void
  onClick?: () => void
}) {
  const text = (
    <span className="fn-trans__text">
      <span className="fn-trans__title t-body-14-m">{title}</span>
      <span className={cx("fn-trans__cat t-capture-12-m", `is-${categoryTone}`)}>{category}</span>
    </span>
  )
  if (onEdit)
    return (
      <div className="fn-trans fn-trans--confirm">
        {text}
        <span className="fn-trans__right">
          <Amount value={amount} sign={flow === "out" ? "-" : "+"} />
          <IconButton icon="edit" label={`Edit ${title}`} variant="plain" size={32} iconSize={14} onClick={onEdit} />
        </span>
      </div>
    )
  const Tag = onClick ? "button" : "div"
  return (
    <Tag type={onClick ? "button" : undefined} className="fn-trans" onClick={onClick}>
      <span className={cx("fn-trans__tile", flow === "in" && "is-in")}>
        <FlowArrow dir={flow} />
      </span>
      <span className="fn-trans__body">
        {text}
        <Amount value={amount} sign={flow === "out" ? "-" : undefined} />
      </span>
    </Tag>
  )
}

/** __card-transaction: dark green card with the day's total, Out / In leader rows and Summary. */
export function SpendCard({
  label,
  amount,
  meta,
  out,
  in: incoming,
  hidden,
  onToggleHidden,
  onSummary,
}: {
  label: string
  amount: string
  meta: string
  out: string
  in: string
  hidden?: boolean
  onToggleHidden?: () => void
  onSummary?: () => void
}) {
  const mask = (v: string) => (hidden ? "••••••" : v)
  return (
    <section className="fn-spend-card" aria-label={label}>
      <p className="t-body-14-m fn-spend-card__label">{label}</p>
      <div className="fn-spend-card__total">
        <span className="fn-spend-card__amount tnum">
          <span className="t-amount-32">{mask(amount)}</span>
          <span className="fn-spend-card__cur">đ</span>
        </span>
        <IconButton
          icon="eye-slash"
          label={hidden ? "Show amounts" : "Hide amounts"}
          variant="on-dark"
          size={32}
          iconSize={16}
          aria-pressed={hidden}
          onClick={onToggleHidden}
        />
      </div>
      <p className="t-capture-12-r fn-spend-card__meta">{meta}</p>
      <div className="fn-spend-card__rows">
        <LeaderRow dot={dotFilled} line={leaderOut} label="Out" value={mask(out)} />
        <LeaderRow dot={dotOutline} line={leaderIn} label="In" value={mask(incoming)} />
      </div>
      <div>
        <Button variant="on-dark" icon="chart-pie" onClick={onSummary}>
          Summary
        </Button>
      </div>
    </section>
  )
}

function LeaderRow({ dot, line, label, value }: { dot: string; line: string; label: string; value: string }) {
  return (
    <div className="fn-leader">
      <span className="fn-leader__label">
        <img src={dot} alt="" width={8} height={8} />
        <span className="t-body-14-m">{label}</span>
      </span>
      <img className="fn-leader__line" src={line} alt="" aria-hidden="true" />
      <Amount value={value} tone="on-dark" />
    </div>
  )
}

/** __inner-month: one card in the month strip. selected = dark green, idle = white,
    empty = dashed "không có", picked = light green with a check (compare mode). */
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
        <span className="t-capture-12-m fn-month__none">không có</span>
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

/** Bottom-bar: wallet, the quick-note pill (logo · placeholder · voice), and the note button. */
export function BottomBar({
  placeholder = "e.g. coffee 24k, breakfast 35k…",
  onWallet,
  onQuickNote,
  onVoice,
  onNotes,
  notesLabel = "Notes",
  notesExpanded,
}: {
  placeholder?: string
  onWallet?: () => void
  onQuickNote?: () => void
  onVoice?: () => void
  /** Omit to hide the note button (the Due screen has none). */
  onNotes?: () => void
  notesLabel?: string
  /** Set when the button opens a menu, so screen readers hear whether it's open. */
  notesExpanded?: boolean
}) {
  return (
    <nav className="fn-bottom-bar" aria-label="Main">
      <IconButton icon="wallet" label="Transactions" variant="glass-80" size={48} onClick={onWallet} />
      <div className="fn-quick-note">
        <button type="button" className="fn-quick-note__open" onClick={onQuickNote}>
          <span className="fn-quick-note__logo">
            <LogoMark size={24} />
          </span>
          <span className="t-body-14-r fn-quick-note__placeholder">{placeholder}</span>
        </button>
        <IconButton icon="waveform" label="Voice note" variant="plain" size={40} iconSize={24} onClick={onVoice} />
      </div>
      {onNotes && (
        <IconButton
          icon="file-edit"
          label={notesLabel}
          variant="white"
          size={48}
          onClick={onNotes}
          aria-expanded={notesExpanded}
          aria-haspopup={notesExpanded === undefined ? undefined : "menu"}
        />
      )}
    </nav>
  )
}

/** Switchable page title: "Transaction  Note" — tapping the quieter word opens that page. */
export function PageSwitch({ title, other, onOther }: { title: string; other: string; onOther: () => void }) {
  return (
    <div className="fn-page-title">
      <h1 className="t-title">{title}</h1>
      <button type="button" className="t-title-sub fn-page-title__switch" onClick={onOther}>
        {other}
      </button>
    </div>
  )
}
