import { useEffect, useRef, useState } from "react"
import { IconButton } from "../components/ui"
import { Icon } from "../components/Icon"
import StickyHeader from "../components/StickyHeader"
import { ListCard, ListRow, TickMark, Tile, Toast } from "../components/kit"
import { usePageSwipe } from "../lib/pageSwipe"
import { money, today as todayIso } from "../lib/format"
import { TILE, addMonths, monthSummary, ym, type Bill } from "../lib/bills"
import { PeriodStrip, MONTHS, MONTHS_LONG } from "./TodayHeader"
import "./today.css"
import "./today-header.css"

const SHORT = MONTHS

export const monthLabel = (m: string) => `${MONTHS_LONG[Number(m.slice(5, 7)) - 1]}, ${m.slice(0, 4)}`
/** "Sep 15" */
export const dueLabel = (iso: string) => `${SHORT[Number(iso.slice(5, 7)) - 1]} ${Number(iso.slice(8, 10))}`
export const ddmmyyyy = (iso: string) => `${iso.slice(8, 10)}/${iso.slice(5, 7)}/${iso.slice(0, 4)}`
/** "Was due Oct 15" for a late bill still open, otherwise "Oct 15". */
const listDate = (due: string, paid: boolean, today: string) => (!paid && due < today ? `Was due ${dueLabel(due)}` : dueLabel(due))

type Filter = "all" | "still" | "done"
type Tick = { id: number; bill: Bill; amount: number; paid: boolean }

/**
 * Due — iOS DueView: the month large, three months side by side, the dark Remaining card with
 * All / Still · Done / History, then the bills in white cards. Ticking records the spending on the
 * day it's ticked; a note offers Undo.
 */
export default function Due({
  onProfile,
  month,
  onMonthChange,
  bills,
  hidden,
  onToggleHidden,
  onToggle,
  onOpenBill,
  onAdd,
  onComingUp,
  onHistory,
  onInstallments,
}: {
  onProfile: () => void
  month: string
  onMonthChange: (m: string) => void
  bills: Bill[]
  hidden: boolean
  onToggleHidden: () => void
  onToggle: (bill: Bill, paid: boolean) => void
  onOpenBill: (id: string) => void
  onAdd: () => void
  onComingUp: () => void
  onHistory: () => void
  onInstallments: () => void
}) {
  const today = todayIso()
  const s = monthSummary(bills, month)
  const [filter, setFilter] = useState<Filter>("all")
  const [menu, setMenu] = useState(false)
  // Bills ticked while looking stay in the group they were in, so the list doesn't jump under the finger.
  const [stay, setStay] = useState<Record<string, boolean>>({})
  const [tick, setTick] = useState<Tick | null>(null)
  const menuRef = useRef<HTMLDivElement>(null)
  const hasInstallments = bills.some((b) => b.kind === "installment")

  useEffect(() => {
    setStay({})
    setTick(null)
  }, [month])
  useEffect(() => {
    if (!tick) return
    const t = setTimeout(() => setTick(null), 4000)
    return () => clearTimeout(t)
  }, [tick])
  useEffect(() => {
    if (!menu) return
    const close = (e: MouseEvent | KeyboardEvent) => {
      if (e instanceof KeyboardEvent ? e.key === "Escape" : !menuRef.current?.contains(e.target as Node)) setMenu(false)
    }
    document.addEventListener("mousedown", close)
    document.addEventListener("keydown", close)
    return () => {
      document.removeEventListener("mousedown", close)
      document.removeEventListener("keydown", close)
    }
  }, [menu])

  const inDone = (b: Bill) => stay[b.id] ?? !!b.paid[month]
  const still = s.due.filter((x) => !inDone(x.bill))
  const done = s.due.filter((x) => inDone(x.bill))

  const toggle = (bill: Bill) => {
    const paid = !bill.paid[month]
    setStay((m) => (bill.id in m ? m : { ...m, [bill.id]: !paid }))
    onToggle(bill, paid)
    setTick({ id: Date.now(), bill, amount: bill.paid[month]?.amount ?? bill.amount, paid })
  }

  // What's due in each month, for the strip. Bills are known ahead, so months to come can be picked.
  const now = ym(today)
  const earliest = bills.reduce((m, b) => (ym(b.start) < m ? ym(b.start) : m), now)
  const first = earliest < addMonths(now, -12) ? earliest : addMonths(now, -12)
  const last = addMonths(now, 12)
  const keys: string[] = []
  const dueBy: Record<string, number> = {}
  for (let k = first; k <= last; k = addMonths(k, 1)) {
    keys.push(k)
    dueBy[k] = monthSummary(bills, k).due.reduce((t, x) => t + (x.bill.paid[k]?.amount ?? x.bill.amount), 0)
  }

  const swipe = usePageSwipe((n) => onMonthChange(addMonths(month, n)))
  const short = (v: number) => (v >= 1_000_000 ? `${money(Math.floor(v / 1000))}K` : money(v))
  const [y, mo] = month.split("-").map(Number)

  const group = (title: string, items: typeof s.due) => (
    <section className="due2-group">
      <h3 className="due2-group__title">
        {title} · {items.length}
      </h3>
      <ListCard className="due2-list">
        {items.map(({ bill, date }) => {
          const record = bill.paid[month]
          const paid = !!record
          const amount = record?.amount ?? bill.amount
          return (
            <ListRow
              key={bill.id}
              tile={<Tile bg={TILE[bill.icon].solid} icon={bill.icon} dim={paid} />}
              title={bill.name}
              sub={listDate(date, paid, today)}
              amount={`${!paid && bill.varies ? "~" : ""}${hidden ? "•••" : `${money(amount)}đ`}`}
              done={paid}
              label={`${bill.name}, ${listDate(date, paid, today)}`}
              onClick={() => onOpenBill(bill.id)}
              trailing={
                <button
                  type="button"
                  className={`due2-tick${paid ? " is-on" : ""}`}
                  aria-label={paid ? `Mark ${bill.name} as not paid` : `Mark ${bill.name} as paid`}
                  aria-pressed={paid}
                  onClick={() => toggle(bill)}
                >
                  <TickMark on={paid} />
                </button>
              }
            />
          )
        })}
      </ListCard>
    </section>
  )

  return (
    <div className="screen" {...swipe}>
      <span className="screen__glow" aria-hidden="true" />
      <StickyHeader
        title="Due"
        left={<IconButton icon="calendar" label="This month" variant="glass" size={44} onClick={() => onMonthChange(ym(today))} />}
        right={
          <div className="today-top" ref={menuRef} style={{ position: "relative" }}>
            <IconButton icon="dots-three" label="More" variant="glass" size={44} iconSize={22} aria-expanded={menu} aria-haspopup="menu" onClick={() => setMenu(!menu)} />
            <IconButton icon="user" label="Profile" variant="glass" size={44} iconSize={24} style={{ color: "var(--brand-600)" }} onClick={onProfile} />
            {menu && (
              <div className="k-menu" role="menu">
                <button type="button" role="menuitem" onClick={() => (setMenu(false), onComingUp())}>
                  <Icon name="calendar-dots" size={20} />
                  Coming up
                </button>
                <button type="button" role="menuitem" disabled={!hasInstallments} onClick={() => (setMenu(false), onInstallments())}>
                  <Icon name="phone" size={20} />
                  Installments
                </button>
                <button type="button" role="menuitem" onClick={() => (setMenu(false), onHistory())}>
                  <Icon name="history" size={20} />
                  History
                </button>
              </div>
            )}
          </div>
        }
      />

      <div className="today-head">
        <h1 className="today-head__date" aria-label={monthLabel(month)}>
          <span className="today-head__big">{SHORT[mo - 1]}</span>
          {month === now && <i className="today-head__dot" aria-label="this month" />}
          <span className="today-head__month">{y}</span>
        </h1>
      </div>

      <PeriodStrip
        keys={keys}
        last={last}
        selected={month}
        spent={dueBy}
        hidden={hidden}
        title={(k) => MONTHS_LONG[Number(k.slice(5, 7)) - 1]}
        label="Months"
        onSelect={onMonthChange}
      />

      <div className="due2">
        <section className="total" aria-label="Remaining this month">
          <p className="total__label">Remaining</p>
          <div className="total__row">
            <span className="total__amount tnum">
              <span className="total__num">{hidden ? "••••••" : money(s.remaining)}</span>
              <span className="total__cur">đ</span>
            </span>
            <button type="button" className="total__eye" aria-label={hidden ? "Show amounts" : "Hide amounts"} aria-pressed={hidden} onClick={onToggleHidden}>
              <Icon name="eye-slash" size={16} />
            </button>
          </div>
          <p className="total__meta">
            paid {hidden ? "••••" : `${short(s.paid)}đ`} <i /> left overall {hidden ? "••••" : `${short(s.totalRemaining)}đ`}
          </p>
          <div className="total__filters" role="group" aria-label="Show">
            <div className="total__box">
              <button type="button" className={`total__chip${filter === "all" ? " is-on" : ""}`} aria-pressed={filter === "all"} onClick={() => setFilter("all")}>
                All
              </button>
            </div>
            <div className="total__box total__box--two">
              <button type="button" className={`total__chip${filter === "still" ? " is-on" : ""}`} aria-pressed={filter === "still"} onClick={() => setFilter("still")}>
                <Icon name="circle-dashed" size={16} />
                Still <span className="total__count">{still.length}</span>
              </button>
              <button type="button" className={`total__chip${filter === "done" ? " is-on" : ""}`} aria-pressed={filter === "done"} onClick={() => setFilter("done")}>
                <span style={{ color: "var(--brand-400)", display: "inline-flex" }}>
                  <Icon name="check-circle" size={16} />
                </span>
                Done <span className="total__count">{done.length}</span>
              </button>
            </div>
            <button type="button" className="total__tool" aria-label="History" onClick={onHistory}>
              <Icon name="history" size={20} />
            </button>
          </div>
        </section>

        {s.due.length === 0 ? (
          <div className="due2-empty">
            <p>No bills due in {MONTHS_LONG[mo - 1]}.</p>
            <button type="button" className="k-btn" onClick={onAdd}>
              <Icon name="plus" size={18} />
              Add a bill
            </button>
          </div>
        ) : (
          <>
            {filter !== "done" && still.length > 0 && group("Still", still)}
            {filter !== "still" && done.length > 0 && group("Done", done)}
            {filter === "still" && still.length === 0 && <p className="k-empty">Everything&apos;s paid this month.</p>}
            {filter === "done" && done.length === 0 && <p className="k-empty">Nothing ticked yet this month.</p>}
          </>
        )}
      </div>

      {tick && (
        <Toast
          key={tick.id}
          icon={
            <span style={{ color: tick.paid ? "var(--success)" : "var(--grey-400)", display: "inline-flex" }}>
              <Icon name={tick.paid ? "check-circle" : "history"} size={22} />
            </span>
          }
          title={tick.paid ? `Paid ${tick.bill.name}` : `${tick.bill.name} not paid yet`}
          sub={tick.paid ? (hidden ? "Added to Today" : `${money(tick.amount)}đ added to Today`) : "Taken off Today"}
          onUndo={() => {
            onToggle(tick.bill, !tick.paid)
            setTick(null)
          }}
        />
      )}
    </div>
  )
}

export function BillTile({ bill, size = 36, soft }: { bill: Bill; size?: number; soft?: boolean }) {
  const t = TILE[bill.icon]
  return (
    <span
      className="bill-tile"
      style={{ width: size, height: size, background: soft ? t.soft : t.solid, color: soft ? t.ink : "#fff", borderRadius: size >= 36 ? 12 : 10 }}
    >
      <Icon name={bill.icon} size={Math.round(size * 0.56)} />
    </span>
  )
}
