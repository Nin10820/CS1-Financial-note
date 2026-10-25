import { useState } from "react"
import { Amount, Button, IconButton, MonthCard, SegmentedTabs } from "../components/ui"
import TabBar, { type Tab } from "../components/TabBar"
import StickyHeader from "../components/StickyHeader"
import { Icon } from "../components/Icon"
import { money, today } from "../lib/format"
import { addMonths, dueIn, installmentStep, lastDue, monthSummary, ym, type Bill } from "../lib/bills"
import ModalSheet, { ModalHeader } from "./ModalSheet"
import { BillTile, ddmmyyyy, monthLabel } from "./Due"
import dotFilled from "../assets/icons/dot-filled.svg"
import dotOutline from "../assets/icons/dot-outline.svg"
import leaderOut from "../assets/icons/leader-out.svg"
import leaderIn from "../assets/icons/leader-in.svg"

const SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const short = (n: number) => (n >= 1e6 ? `${(n / 1e6).toLocaleString("en-US", { maximumFractionDigits: 3 })} M` : money(n))

/** Figma Final › Due › Coming up (Card / Month): what each month will ask for. */
export function ComingUp({
  bills,
  month,
  onPick,
  onClose,
}: {
  bills: Bill[]
  month: string
  onPick: (m: string) => void
  onClose: () => void
}) {
  const [view, setView] = useState<"card" | "month">("month")
  const [year, setYear] = useState(Number(month.slice(0, 4)))
  const now = ym(today())
  const months = Array.from({ length: 12 }, (_, i) => `${year}-${String(i + 1).padStart(2, "0")}`)
  const next = Array.from({ length: 12 }, (_, i) => addMonths(now, i)).map((m) => ({ m, s: monthSummary(bills, m) }))

  return (
    <ModalSheet
      label="Coming up"
      onClose={onClose}
      header={<ModalHeader title="Coming up" right={<IconButton icon="close" label="Close" variant="glass-strong" onClick={onClose} />} />}
    >
      <div className="coming">
        <div className="coming__tabs">
          <SegmentedTabs
            label="View"
            value={view}
            onChange={setView}
            options={[
              { value: "card", label: "Card", icon: "align-left" },
              { value: "month", label: "Month", icon: "squares-four" },
            ]}
          />
        </div>
        {view === "month" ? (
          <>
            <div className="coming__year">
              <IconButton icon="caret-left" label="Previous year" variant="plain" size={32} iconSize={16} onClick={() => setYear(year - 1)} />
              <h3>{year}</h3>
              <IconButton icon="caret-right" label="Next year" variant="plain" size={32} iconSize={16} onClick={() => setYear(year + 1)} />
            </div>
            <div className="coming__grid">
              {months.map((m, i) => {
                const s = monthSummary(bills, m)
                const total = s.due.reduce((t, x) => t + (x.bill.paid[m]?.amount ?? x.bill.amount), 0)
                const state = !s.due.length ? "empty" : m === month ? "selected" : s.still.length === 0 ? "picked" : "idle"
                return (
                  <MonthCard
                    key={m}
                    month={SHORT[i]}
                    amount={short(total)}
                    count={`${s.due.length} ${s.due.length === 1 ? "bill" : "bills"}`}
                    state={state}
                    onClick={() => {
                      onPick(m)
                      onClose()
                    }}
                  />
                )
              })}
            </div>
            <p className="t-capture-12-r coming__legend">
              <Icon name="check-circle" size={12} /> all paid · dashed = nothing due
            </p>
          </>
        ) : (
          <ol className="coming__timeline">
            {next.map(({ m, s }) =>
              s.due.length ? (
                <li key={m}>
                  <button
                    type="button"
                    onClick={() => {
                      onPick(m)
                      onClose()
                    }}
                  >
                    <span className="coming__dot" aria-hidden="true" />
                    <span className="coming__when">
                      {monthLabel(m)}
                      {m === now ? " · this month" : ""}
                    </span>
                    <Amount value={money(s.remaining + s.paid)} size={18} />
                    <span className="t-capture-12-r coming__count">
                      {s.due.length} {s.due.length === 1 ? "bill" : "bills"}
                      {s.still.length === 0 ? " · all paid" : ` · ${s.still.length} to pay`}
                    </span>
                  </button>
                </li>
              ) : null,
            )}
            {next.every((x) => !x.s.due.length) && <p className="t-body-14-r coming__none">Nothing due in the next 12 months.</p>}
          </ol>
        )}
      </div>
    </ModalSheet>
  )
}

/** "History" on the Remaining card: everything checked off, newest first. */
export function PaidHistory({ bills, onClose, onOpen }: { bills: Bill[]; onClose: () => void; onOpen: (id: string, month: string) => void }) {
  const rows = bills
    .flatMap((b) => Object.entries(b.paid).map(([m, p]) => ({ b, m, p })))
    .sort((a, b) => b.p.at - a.p.at)
  return (
    <ModalSheet
      label="Payment history"
      onClose={onClose}
      size="auto"
      header={<ModalHeader title="History" right={<IconButton icon="close" label="Close" variant="glass-strong" onClick={onClose} />} />}
    >
      <div className="paid-history">
        {rows.length === 0 && <p className="t-body-14-r history__none">Bills you check off will show up here.</p>}
        {rows.map(({ b, m, p }) => (
          <button key={`${b.id}-${m}`} type="button" className="paid-history__row" onClick={() => onOpen(b.id, m)}>
            <BillTile bill={b} size={32} soft />
            <span className="paid-history__text">
              <span className="t-body-14-m">{b.name}</span>
              <span className="t-capture-12-r">{monthLabel(m)}</span>
            </span>
            <Amount value={money(p.amount)} />
          </button>
        ))}
      </div>
    </ModalSheet>
  )
}

/** Figma Final › Due › Statement (765:20761): installments together, what this month asks for. */
export function Installments({
  bills,
  month,
  hidden,
  onBack,
  onOpenBill,
  onComingUp,
  onHistory,
  onAdd,
  onOpenAssistant,
  onTab,
}: {
  bills: Bill[]
  month: string
  hidden: boolean
  onBack: () => void
  onOpenBill: (id: string) => void
  onComingUp: () => void
  onHistory: () => void
  onAdd: () => void
  onOpenAssistant: () => void
  onTab: (t: Tab) => void
}) {
  const list = bills.filter((b) => b.kind === "installment")
  const thisMonth = list.filter((b) => dueIn(b, month))
  const statement = thisMonth.reduce((s, b) => s + b.amount, 0)
  const comingUp = thisMonth.filter((b) => !b.paid[month]).reduce((s, b) => s + b.amount, 0)
  const remaining = list.reduce((s, b) => s + installmentStep(b, month).left * b.amount, 0)
  const lastDay = thisMonth.map((b) => dueIn(b, month)!).sort().pop()
  const mask = (n: number) => (hidden ? "••••••" : money(n))

  return (
    <div className="screen">
      <span className="screen__glow" aria-hidden="true" />
      <StickyHeader
        title={"Installments"}
        left={
          <>
            <IconButton icon="arrow-left" label="Back to Due" variant="glass" onClick={onBack} />
          </>
        }
        right={
          <div className="pill-group">
          <IconButton icon="plus-18" label="Add an installment" variant="plain" iconSize={18} onClick={onAdd} />
        </div>
        }
      />
      <div className="screen__card due-card-wrap">
        <section className="fn-spend-card due-card" aria-label="Installments this month">
          <p className="t-body-16-m due-card__kicker">Statement · {monthLabel(month).replace(",", "")}</p>
          <span className="fn-spend-card__amount tnum">
            <span className="due-card__big">{mask(statement)}</span>
            <span className="fn-spend-card__cur">đ</span>
          </span>
          {lastDay && <p className="t-body-14-m due-card__sub">Due {ddmmyyyy(lastDay)}</p>}
          <div className="fn-spend-card__rows">
            <Leader dot={dotFilled} line={leaderOut} label="Coming up" value={mask(comingUp)} />
            <Leader dot={dotOutline} line={leaderIn} label="Remaining" value={mask(remaining)} />
          </div>
          <div className="due-card__actions">
            <Button variant="on-dark" icon="clock" onClick={onHistory}>
              History
            </Button>
            <Button variant="on-dark" icon="calendar-dots" onClick={onComingUp}>
              Coming up
            </Button>
          </div>
        </section>
      </div>
      <section className="statement" aria-labelledby="statement-title">
        <h2 id="statement-title" className="statement__title">
          Statement List
        </h2>
        {list.length === 0 && <p className="t-body-14-r statement__none">No installments yet.</p>}
        {list.map((b) => {
          const st = installmentStep(b, month)
          const end = lastDue(b)
          const line =
            st.left === 0 ? "All paid" : st.left === 1 ? "Last one — done this month" : `${st.left} left · ends ${ddmmyyyy(end)}`
          return (
            <button key={b.id} type="button" className="bill-item ins-item" onClick={() => onOpenBill(b.id)}>
              <span className="bill-item__top">
                <BillTile bill={b} size={32} soft />
                <span className="bill-item__text">
                  <span className="bill-item__name ins-item__name">{b.name}</span>
                  <span className="t-capture-12-r ins-item__sub">{line}</span>
                </span>
                <span className="t-capture-12-m ins-item__count">
                  {st.paidCount}/{st.total} paid
                </span>
              </span>
              <span className="bill-item__bottom ins-item__bottom">
                <span className="ins-item__amount tnum">
                  {mask(b.amount)}
                  <span className="bill-item__cur">đ</span>
                  <span className="t-capture-12-r ins-item__per"> /month</span>
                </span>
                <Icon name="caret-right-sm" size={14} />
              </span>
            </button>
          )
        })}
      </section>
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
