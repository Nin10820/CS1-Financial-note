import { useEffect, useRef, useState, type ReactNode } from "react"
import { Amount, Button, IconButton, Sheet, GlassGroup } from "../components/ui"
import TabBar, { type Tab } from "../components/TabBar"
import StickyHeader from "../components/StickyHeader"
import { Icon } from "../components/Icon"
import { money, today } from "../lib/format"
import { TILE, addMonths, monthSummary, ym, type Bill } from "../lib/bills"
import dotFilled from "../assets/icons/dot-filled.svg"
import dotOutline from "../assets/icons/dot-outline.svg"
import leaderOut from "../assets/icons/leader-out.svg"
import leaderIn from "../assets/icons/leader-in.svg"

const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
const SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

export const monthLabel = (m: string) => `${MONTHS[Number(m.slice(5, 7)) - 1]}, ${m.slice(0, 4)}`
/** "Sep 15" */
export const dueLabel = (iso: string) => `${SHORT[Number(iso.slice(5, 7)) - 1]} ${Number(iso.slice(8, 10))}`

/** Figma Final › Due (765:20114): month, what's left to pay, then STILL / DONE bills. */
export default function Due({
  month,
  onMonthChange,
  bills,
  name,
  hidden,
  onToggleHidden,
  onToggle,
  onOpenBill,
  onAdd,
  onComingUp,
  onHistory,
  onInstallments,
  onOpenAssistant,
  onTab,
}: {
  month: string
  onMonthChange: (m: string) => void
  bills: Bill[]
  name: string
  hidden: boolean
  onToggleHidden: () => void
  onToggle: (bill: Bill, paid: boolean) => void
  onOpenBill: (id: string) => void
  onAdd: () => void
  onComingUp: () => void
  onHistory: () => void
  onInstallments: () => void
  onOpenAssistant: () => void
  onTab: (t: Tab) => void
}) {
  const s = monthSummary(bills, month)
  const [open, setOpen] = useState({ still: true, done: true })
  const [menu, setMenu] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)
  const mask = (v: number) => (hidden ? "••••••" : money(v))
  const hasInstallments = bills.some((b) => b.kind === "installment")

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

  return (
    <div className="screen">
      <span className="screen__glow" aria-hidden="true" />
      <StickyHeader
        title={monthLabel(month)}
        left={
          <>
            <div className="due-head__left">
          <span className="avatar" aria-label={`Signed in as ${name}`}>
            {name.slice(0, 2).toUpperCase()}
          </span>
          <IconButton icon="calendar" label="This month" variant="glass" onClick={() => onMonthChange(ym(today()))} style={{ color: "var(--grey-500)" }} />
        </div>
          </>
        }
        right={
          <div className="pill-group" ref={menuRef}>
          <GlassGroup aria-label="Bill actions" className="pill-group__glass">
            <IconButton icon="dots-three" label="More" variant="plain" iconSize={24} aria-expanded={menu} aria-haspopup="menu" onClick={() => setMenu(!menu)} />
            <IconButton icon="plus-18" label="Add a bill" variant="plain" iconSize={18} onClick={onAdd} />
          </GlassGroup>
          {menu && (
            <div className="note-menu note-menu--top lg lg--thick lg-morph" role="menu">
              <button type="button" role="menuitem" className="note-menu__item" onClick={() => (setMenu(false), onComingUp())}>
                <Icon name="calendar-dots" size={20} />
                Coming up
              </button>
              <button
                type="button"
                role="menuitem"
                className="note-menu__item"
                disabled={!hasInstallments}
                onClick={() => (setMenu(false), onInstallments())}
              >
                <Icon name="phone" size={20} />
                Installments
              </button>
            </div>
          )}
        </div>
        }
      />

      <div className="due-month">
        <IconButton icon="caret-left" label="Previous month" variant="plain" size={32} iconSize={16} onClick={() => onMonthChange(addMonths(month, -1))} />
        <h1 className="due-month__label" aria-live="polite">
          {monthLabel(month)}
        </h1>
        <IconButton icon="caret-right" label="Next month" variant="plain" size={32} iconSize={16} onClick={() => onMonthChange(addMonths(month, 1))} />
      </div>

      <div className="screen__card due-card-wrap">
        <section className="fn-spend-card due-card" aria-label="Remaining this month">
          <p className="due-card__label">Remaining</p>
          <div className="fn-spend-card__total">
            <span className="fn-spend-card__amount tnum">
              <span className="t-amount-32">{mask(s.remaining)}</span>
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
          <div className="fn-spend-card__rows">
            <Leader dot={dotFilled} line={leaderOut} label="Paid" value={mask(s.paid)} />
            <Leader dot={dotOutline} line={leaderIn} label="Total remaining" value={mask(s.totalRemaining)} />
          </div>
          <div className="due-card__actions">
            <Button variant="on-dark" icon="clock" onClick={onHistory}>
              History
            </Button>
          </div>
        </section>
      </div>

      <Sheet className="screen__sheet due-sheet">
        {s.due.length === 0 ? (
          <div className="due-empty">
            <p className="t-body-14-r">No bills due in {monthLabel(month).split(",")[0]}.</p>
            <Button variant="primary" size="md" icon="plus" onClick={onAdd}>
              Add a bill
            </Button>
          </div>
        ) : (
          <>
            {s.still.length > 0 && (
              <Group label="Still" count={s.still.length} tone="still" open={open.still} onToggle={() => setOpen((o) => ({ ...o, still: !o.still }))}>
                {s.still.map(({ bill, date }) => (
                  <BillItem key={bill.id} bill={bill} date={date} paid={false} hidden={hidden} onToggle={() => onToggle(bill, true)} onOpen={() => onOpenBill(bill.id)} />
                ))}
              </Group>
            )}
            {s.done.length > 0 && (
              <Group label="Done" count={s.done.length} tone="done" open={open.done} onToggle={() => setOpen((o) => ({ ...o, done: !o.done }))}>
                {s.done.map(({ bill, date }) => (
                  <BillItem key={bill.id} bill={bill} date={date} paid hidden={hidden} month={month} onToggle={() => onToggle(bill, false)} onOpen={() => onOpenBill(bill.id)} />
                ))}
              </Group>
            )}
          </>
        )}
      </Sheet>

      <div className="screen__bottom">
        <TabBar active="due" onTab={onTab} onQuickNote={onOpenAssistant} />
      </div>
    </div>
  )
}

function Leader({ dot, line, label, value }: { dot: string; line: string; label: string; value: string }) {
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

function Group({
  label,
  count,
  tone,
  open,
  onToggle,
  children,
}: {
  label: string
  count: number
  tone: "still" | "done"
  open: boolean
  onToggle: () => void
  children: ReactNode
}) {
  return (
    <section className="due-group">
      <button type="button" className={`due-filter due-filter--${tone}`} aria-expanded={open} onClick={onToggle}>
        <Icon name={tone === "still" ? "circle-dashed" : "check-circle-done"} size={18} />
        <span className="due-filter__label">{label}</span>
        <span className="due-filter__count">({count})</span>
        <span className={`due-filter__caret${open ? "" : " is-closed"}`}>
          <Icon name="caret-down" size={14} />
        </span>
      </button>
      {open && <div className="due-group__list">{children}</div>}
    </section>
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

function BillItem({
  bill,
  date,
  paid,
  hidden,
  month,
  onToggle,
  onOpen,
}: {
  bill: Bill
  date: string
  paid: boolean
  hidden: boolean
  month?: string
  onToggle: () => void
  onOpen: () => void
}) {
  const amount = paid && month ? bill.paid[month].amount : bill.amount
  return (
    <article className="bill-item">
      <div className="bill-item__top">
        <BillTile bill={bill} />
        <div className="bill-item__text">
          <span className="bill-item__name">{bill.name}</span>
          <span className="bill-item__date">{dueLabel(date)}</span>
        </div>
        <button
          type="button"
          className="bill-item__check"
          aria-label={paid ? `Mark ${bill.name} as not paid` : `Mark ${bill.name} as paid`}
          aria-pressed={paid}
          onClick={onToggle}
        >
          <Icon name={paid ? "check-circle-fill" : "circle"} size={24} />
        </button>
      </div>
      <button type="button" className="bill-item__bottom" onClick={onOpen} aria-label={`${bill.name} details`}>
        <span className="bill-item__amount tnum">
          {!paid && bill.varies ? "~" : ""}
          {hidden ? "••••••" : money(amount)}
          <span className="bill-item__cur">đ</span>
        </span>
        <Icon name="caret-right-sm" size={14} />
      </button>
    </article>
  )
}

export const ddmmyyyy = (iso: string) => `${iso.slice(8, 10)}/${iso.slice(5, 7)}/${iso.slice(0, 4)}`
