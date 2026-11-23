import { useState, type ReactNode } from "react"
import { Icon, type IconName } from "./Icon"
import { ASSET_TILE, type AssetIcon } from "../lib/assets"
import { compact, money } from "../lib/format"
import "./kit.css"
import "../screens/template.css"

/* Shared pieces from the iOS app (ios/DESIGN.md): list rows, pies, stat cards, the number pad
   and the quick-pick card. Canvas behind, white cards on top, one row shape everywhere. */

const cx = (...c: (string | false | undefined | null)[]) => c.filter(Boolean).join(" ")

/** 40 px solid round tile with a white icon or a short mark ("Au", "₫"). */
export function Tile({ bg, icon, mark, size = 40, dim }: { bg: string; icon?: IconName; mark?: string; size?: number; dim?: boolean }) {
  return (
    <span className="k-tile" style={{ width: size, height: size, background: bg, opacity: dim ? 0.6 : 1 }} aria-hidden="true">
      {icon ? <Icon name={icon} size={Math.round(size * 0.48)} /> : <b style={{ fontSize: Math.round(size * (mark && mark.length > 1 ? 0.36 : 0.45)) }}>{mark}</b>}
    </span>
  )
}

export function AssetTile({ icon, size = 40 }: { icon: AssetIcon; size?: number }) {
  const t = ASSET_TILE[icon] ?? ASSET_TILE.cash
  return <Tile bg={t.bg} icon={t.icon} mark={t.mark} size={size} />
}

/** "Assets", "Family loans" over a card, with anything on the right. */
export function SectionTitle({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <div className="k-section">
      <h2>{title}</h2>
      {children}
    </div>
  )
}

/** A white card holding rows split by thin lines. */
export function ListCard({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cx("k-list", className)}>{children}</div>
}

/** One list row: tile, name over a grey line, and the amount with a small line under it. */
export function ListRow({
  tile,
  title,
  sub,
  amount,
  amountSub,
  amountSubTone,
  done,
  onClick,
  onAmount,
  trailing,
  label,
}: {
  tile: ReactNode
  title: ReactNode
  sub?: ReactNode
  amount?: ReactNode
  amountSub?: ReactNode
  amountSubTone?: "gain" | "muted"
  done?: boolean
  onClick?: () => void
  /** The amount is its own button (quick update). */
  onAmount?: () => void
  trailing?: ReactNode
  label?: string
}) {
  const body = (
    <>
      {tile}
      <span className="k-row__text">
        <span className={cx("k-row__title", done && "is-done")}>{title}</span>
        {sub != null && <span className="k-row__sub">{sub}</span>}
      </span>
    </>
  )
  const right = amount != null && (
    <span className="k-row__right tnum">
      <span className={cx("k-row__amount", done && "is-done")}>{amount}</span>
      {amountSub != null && <span className={cx("k-row__amount-sub", amountSubTone === "gain" && "is-gain")}>{amountSub}</span>}
    </span>
  )
  return (
    <div className="k-row">
      {onClick ? (
        <button type="button" className="k-row__main" onClick={onClick} aria-label={label}>
          {body}
          {!onAmount && right}
        </button>
      ) : (
        <div className="k-row__main">
          {body}
          {!onAmount && right}
        </div>
      )}
      {onAmount && (
        <button type="button" className="k-row__amount-btn" onClick={onAmount}>
          {right}
        </button>
      )}
      {trailing}
    </div>
  )
}

/** Big amount with its đ: "122,647,000 đ". */
export function AmountText({ value, hidden, size = 36, sign = "" }: { value: number; hidden?: boolean; size?: number; sign?: string }) {
  return (
    <span className="k-amount tnum" style={{ fontSize: size }}>
      {hidden ? "••••••" : sign + money(value)}
      <small style={{ fontSize: Math.round(size * 0.66) }}>đ</small>
    </span>
  )
}

/** A page's headline: a label, the amount large, up to three small figures under it. */
export function StatCard({
  label,
  amount,
  hidden,
  stats,
}: {
  label: string
  amount: number
  hidden?: boolean
  stats: { label: string; value: string; gain?: boolean }[]
}) {
  return (
    <div className="k-stat">
      <p className="k-stat__label">{label}</p>
      <AmountText value={Math.abs(amount)} sign={amount < 0 ? "-" : ""} hidden={hidden} />
      <div className="k-stat__row" style={{ gridTemplateColumns: `repeat(${stats.length === 4 ? 2 : Math.max(stats.length, 1)}, 1fr)` }}>
        {stats.map((s) => (
          <span key={s.label}>
            <b className={cx("tnum", s.gain && "is-gain")}>{s.value}</b>
            <small>{s.label}</small>
          </span>
        ))}
      </div>
    </div>
  )
}

/** Two parts in one card, split by a faint dashed line. */
export function JoinedCard({ top, bottom }: { top: ReactNode; bottom: ReactNode }) {
  return (
    <div className="k-joined">
      {top}
      <hr />
      {bottom}
    </div>
  )
}

/** "History · 12 changes · last 16 Nov ›" */
export function HistoryLink({ sub, onClick }: { sub: string; onClick: () => void }) {
  return (
    <button type="button" className="k-history" onClick={onClick}>
      <Icon name="clock" size={20} />
      <span className="k-history__text">
        <b>History</b>
        <small>{sub}</small>
      </span>
      <Icon name="caret-right-sm" size={14} />
    </button>
  )
}

/** iOS segmented control: a grey track with the picked one on a white pill. */
export function Segmented<T extends string>({
  options,
  value,
  onChange,
  label,
  small,
}: {
  options: { value: T; label: ReactNode }[]
  value: T
  onChange: (v: T) => void
  label: string
  small?: boolean
}) {
  return (
    <div className={cx("k-seg", small && "k-seg--small")} role="tablist" aria-label={label}>
      {options.map((o) => (
        <button key={o.value} type="button" role="tab" aria-selected={value === o.value} className={cx("k-seg__item", value === o.value && "is-on")} onClick={() => onChange(o.value)}>
          {o.label}
        </button>
      ))}
    </div>
  )
}

/* ── Pies ─────────────────────────────────────────────────── */

export type Slice = { id: string; value: number; color: string }

/** Annular sector from a0 to a1 (radians, 0 = top). */
function arc(cx0: number, cy0: number, r0: number, r1: number, a0: number, a1: number) {
  const p = (r: number, a: number) => `${(cx0 + r * Math.sin(a)).toFixed(2)} ${(cy0 - r * Math.cos(a)).toFixed(2)}`
  const large = a1 - a0 > Math.PI ? 1 : 0
  if (r0 <= 0) return `M${cx0} ${cy0} L${p(r1, a0)} A${r1} ${r1} 0 ${large} 1 ${p(r1, a1)} Z`
  return `M${p(r1, a0)} A${r1} ${r1} 0 ${large} 1 ${p(r1, a1)} L${p(r0, a1)} A${r0} ${r0} 0 ${large} 0 ${p(r0, a0)} Z`
}

/** A ring (inner > 0) or a solid pie, slices apart by a small gap. A picked slice stays full; the rest fade. */
export function Pie({ slices, inner = 0.78, size = 140, picked, gap = 3, children }: { slices: Slice[]; inner?: number; size?: number; picked?: string | null; gap?: number; children?: ReactNode }) {
  const shown = slices.filter((s) => s.value > 0)
  const total = shown.reduce((t, s) => t + s.value, 0)
  const r1 = size / 2
  const r0 = r1 * inner
  let a = 0
  return (
    <div className="k-pie" style={{ width: size, height: size }}>
      <svg viewBox={`0 0 ${size} ${size}`} aria-hidden="true">
        {!total && (inner > 0 ? <circle cx={r1} cy={r1} r={(r0 + r1) / 2} fill="none" stroke="var(--bg-4)" strokeWidth={r1 - r0} /> : <circle cx={r1} cy={r1} r={r1 - 12} fill="var(--bg-4)" />)}
        {shown.map((s) => {
          const span = (s.value / total) * Math.PI * 2
          const pad = shown.length > 1 ? gap / r1 : 0
          const d = span >= Math.PI * 2 - 0.001 ? null : arc(r1, r1, r0, r1, a + pad / 2, a + span - pad / 2)
          a += span
          const dim = picked && picked !== s.id
          return d ? (
            <path key={s.id} d={d} fill={s.color} opacity={dim ? 0.3 : 1} />
          ) : (
            <circle key={s.id} cx={r1} cy={r1} r={inner > 0 ? (r0 + r1) / 2 : r1 / 2} fill="none" stroke={s.color} strokeWidth={inner > 0 ? r1 - r0 : r1} opacity={dim ? 0.3 : 1} />
          )
        })}
      </svg>
      {children && <div className="k-pie__center">{children}</div>}
    </div>
  )
}

/** "● Mom   41.1M   47%" */
export function Legend({ color, name, amount, pct, on, onClick }: { color: string; name: string; amount?: string; pct: string; on?: boolean; onClick?: () => void }) {
  const body = (
    <>
      <i style={{ background: color }} />
      <span className="k-legend__name">{name}</span>
      {amount != null && <span className="k-legend__amount tnum">{amount}</span>}
      <b className="tnum">{pct}</b>
    </>
  )
  return onClick ? (
    <button type="button" className={cx("k-legend", on && "is-on")} style={on ? { background: `color-mix(in srgb, ${color} 14%, transparent)` } : undefined} aria-pressed={on} onClick={onClick}>
      {body}
    </button>
  ) : (
    <div className="k-legend">{body}</div>
  )
}

/** A white card: title, the chart on the left, the legend on the right. */
export function PieCard({ title, chart, legend }: { title: string; chart: ReactNode; legend: ReactNode }) {
  return (
    <div className="k-piecard">
      <p className="k-piecard__title">{title}</p>
      <div className="k-piecard__body">
        {chart}
        <div className="k-piecard__legend">{legend}</div>
      </div>
    </div>
  )
}

export const pct = (part: number, whole: number) => (whole ? Math.round((part / whole) * 100) : 0)
export const pctText = (part: number, whole: number) => {
  const p = pct(part, whole)
  return p === 0 && part > 0 ? "<1%" : `${p}%`
}
export const maskC = (hidden: boolean | undefined, n: number) => (hidden ? "•••" : compact(n))

/* ── Number pad ───────────────────────────────────────────── */

/** 1–9, 000, 0, ⌫ and Done — flush with the bottom of the sheet. */
export function AmountPad({ onChange, onDone, doneLabel = "Done" }: { onChange: (f: (v: number) => number) => void; onDone?: () => void; doneLabel?: string }) {
  const press = (k: string) => {
    if (k === "⌫") return onChange((a) => Math.floor(a / 10))
    onChange((a) => {
      const next = Number(`${a || ""}${k}`)
      return next < 1e12 ? next : a
    })
  }
  return (
    <div className="tpl__pad" role="group" aria-label="Amount keypad">
      {["1", "2", "3", "4", "5", "6", "7", "8", "9", "000", "0", "⌫"].map((k) => (
        <button key={k} type="button" className="tpl__key" aria-label={k === "⌫" ? "Delete digit" : k} onClick={() => press(k)}>
          {k}
        </button>
      ))}
      {onDone && (
        <button type="button" className="tpl__done" onClick={onDone}>
          {doneLabel}
        </button>
      )}
    </div>
  )
}

/* ── Quick pick (New bill, New asset) ────────────────────── */

/** "Adding new [kind of] — tell us what you know:" */
export function AddingLead({ label, chosen }: { label: string; chosen: boolean }) {
  return (
    <h3 className="k-lead">
      Adding new <span className={chosen ? "is-on" : ""}>{label}</span> — tell us what you know:
    </h3>
  )
}

/** Step 1 card: the choices, then "Not quite? Say it your way" — one sentence instead of the form. */
export function QuickPickCard<T extends string>({
  step = "Step 1 of 2",
  title,
  options,
  placeholder,
  onPick,
  onSay,
}: {
  step?: string
  title: string
  options: { id: T; title: string; hint: string; mark?: string }[]
  placeholder: string
  onPick: (id: T) => void
  onSay: (text: string) => void
}) {
  const [saying, setSaying] = useState(false)
  const [text, setText] = useState("")
  const send = () => text.trim() && onSay(text.trim())
  return (
    <div className="k-pick">
      <div className="k-pick__head">
        <small>{step}</small>
        <b>{title}</b>
      </div>
      <div className="k-pick__list">
        {options.map((o) => (
          <button key={o.id} type="button" className="k-pick__opt" onClick={() => onPick(o.id)}>
            {o.mark && <i style={{ background: o.mark }} />}
            <span>
              <b>{o.title}</b>
              <small>{o.hint}</small>
            </span>
          </button>
        ))}
      </div>
      <div className="k-pick__say">
        <span className="k-pick__pen">
          <Icon name="pencil" size={20} />
        </span>
        {saying ? (
          <>
            <input
              autoFocus
              value={text}
              placeholder={placeholder}
              aria-label="Say it your way"
              onChange={(e) => setText(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && send()}
            />
            <button type="button" className="k-pick__send" aria-label="Send" disabled={!text.trim()} onClick={send}>
              <Icon name="send-up" size={18} />
            </button>
          </>
        ) : (
          <button type="button" className="k-pick__open" onClick={() => setSaying(true)}>
            Not quite? Say it your way
          </button>
        )}
      </div>
    </div>
  )
}

/** "Paid Rent · 2,500,000đ added to Today  Undo" — a small note above the tab bar that goes by itself. */
export function Toast({ icon, title, sub, onUndo }: { icon: ReactNode; title: string; sub: string; onUndo: () => void }) {
  return (
    <div className="k-toast" role="status">
      {icon}
      <span className="k-toast__text">
        <b>{title}</b>
        <small>{sub}</small>
      </span>
      <button type="button" onClick={onUndo}>
        Undo
      </button>
    </div>
  )
}

/** The round tick on a bill: an empty ring, or a solid green disc with a white check. */
export function TickMark({ on }: { on: boolean }) {
  return on ? (
    <span className="k-tick is-on">
      <Icon name="check" size={14} />
    </span>
  ) : (
    <span className="k-tick" />
  )
}
