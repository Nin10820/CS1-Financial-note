import { useMemo, useState } from "react"
import { FilterChips, LogoMark, PageSwitch, Sheet, SpendCard, TransItem } from "../components/ui"
import { Icon } from "../components/Icon"
import { clock, greeting, money, shortDate, today } from "../lib/format"
import { categoryTone, type Entry } from "../lib/store"
import type { AssistantOpen } from "./Assistant"
import DayHeader from "./DayHeader"
import TabBar, { type Tab } from "../components/TabBar"

type Filter = "all" | "expense" | "receive"

/** Figma Final › Transaction › Home (765:19641 empty, 765:19666 with entries). */
export default function Home({
  day,
  onDayChange,
  entries,
  name,
  hidden,
  onToggleHidden,
  onOpenAssistant,
  onOpenEntry,
  onSummary,
  onNote,
  onDue,
  onTab,
}: {
  day: string
  onDayChange: (day: string) => void
  entries: Entry[]
  name: string
  hidden: boolean
  onToggleHidden: () => void
  onOpenAssistant: (opts?: AssistantOpen) => void
  onOpenEntry: (id: string) => void
  onSummary: () => void
  onNote: () => void
  onDue: () => void
  onTab: (t: Tab) => void
}) {
  const [filter, setFilter] = useState<Filter>("all")

  const list = useMemo(() => entries.filter((e) => e.date === day).sort((a, b) => b.createdAt - a.createdAt), [entries, day])
  const out = list.filter((e) => e.flow === "out").reduce((s, e) => s + e.amount, 0)
  const incoming = list.filter((e) => e.flow === "in").reduce((s, e) => s + e.amount, 0)
  const notes = new Set(list.map((e) => e.noteId)).size
  const updated = list.length ? Math.max(...list.map((e) => e.createdAt)) : 0
  const shown = list.filter((e) => filter === "all" || (filter === "expense" ? e.flow === "out" : e.flow === "in"))

  return (
    <div className="screen">
      <span className="screen__glow" aria-hidden="true" />
      <DayHeader day={day} onDayChange={onDayChange} title="Transaction" onProfile={() => onTab("profile")} />

      <PageSwitch title="Transaction" other="Note" onOther={onNote} />

      {list.length === 0 ? (
        <section className="home-empty" aria-label="Nothing recorded yet">
          <LogoMark size={64} />
          <h2 className="home-empty__hello">
            {greeting()}, {name}
          </h2>
          <ul className="home-empty__ideas">
            {(
              [
                ["Write what you spent", {}],
                ["Ask about a bill", "due"],
                ["Add an asset", { notice: "Assets aren't in this version yet. For now I can record what you spend and receive." }],
              ] as const
            ).map(([label, opts]) => (
              <li key={label}>
                <button type="button" onClick={() => (opts === "due" ? onDue() : onOpenAssistant(opts))}>
                  <Icon name="logo-mark" size={14} />
                  <span className="t-body-14-r">{label}</span>
                </button>
              </li>
            ))}
          </ul>
          {day !== today() && <p className="t-capture-12-r home-empty__day">Nothing recorded on {shortDate(day)}.</p>}
        </section>
      ) : (
        <>
          <div className="screen__card">
            <SpendCard
              label={day === today() ? "Spent today" : `Spent on ${shortDate(day)}`}
              amount={money(out)}
              meta={`${notes} ${notes === 1 ? "note" : "notes"} · updated ${clock(updated)}`}
              out={money(out)}
              in={money(incoming)}
              hidden={hidden}
              onToggleHidden={onToggleHidden}
              onSummary={onSummary}
            />
          </div>
          <Sheet className="screen__sheet">
            <div className="screen__list-head">
              <h2 className="t-body-18-s screen__list-title">List</h2>
              <FilterChips
                label="Filter the list"
                value={filter}
                onChange={setFilter}
                options={[
                  { value: "all", label: "All" },
                  { value: "expense", label: "Expense" },
                  { value: "receive", label: "Receive" },
                ]}
              />
            </div>
            {shown.length ? (
              <div className="screen__rows">
                {shown.map((e) => (
                  <TransItem
                    key={e.id}
                    title={e.title}
                    category={e.category}
                    categoryTone={categoryTone(e.category)}
                    amount={hidden ? "•••" : money(e.amount)}
                    flow={e.flow}
                    onClick={() => onOpenEntry(e.id)}
                  />
                ))}
              </div>
            ) : (
              <p className="t-body-14-r screen__none">Nothing {filter === "expense" ? "spent" : "received"} on this day.</p>
            )}
          </Sheet>
        </>
      )}

      <div className="screen__bottom">
        <TabBar active="expense" onTab={onTab} onQuickNote={() => onOpenAssistant()} action={{ label: "Note", onClick: onNote }} />
      </div>
    </div>
  )
}
