import { useEffect, useRef, useState } from "react"
import { PageSwitch } from "../components/ui"
import TabBar, { type Tab } from "../components/TabBar"
import { Icon } from "../components/Icon"
import { money, shortDate, today } from "../lib/format"
import { addMonths, monthSummary, ym, type Bill } from "../lib/bills"
import type { DayNote, Entry } from "../lib/store"
import DayHeader from "./DayHeader"

/** Figma Final › Note (765:19858): coming-up bills, what was written today, New note / Scan menu. */
export default function NoteScreen({
  day,
  onDayChange,
  note,
  entries,
  bills,
  onTransactions,
  onDue,
  onNewNote,
  onOpenAssistant,
  onTab,
}: {
  day: string
  onDayChange: (day: string) => void
  note?: DayNote
  entries: Entry[]
  bills: Bill[]
  onTransactions: () => void
  onDue: () => void
  onNewNote: () => void
  onOpenAssistant: () => void
  onTab: (t: Tab) => void
}) {
  const [menu, setMenu] = useState(false)
  const barRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!menu) return
    const close = (e: MouseEvent | KeyboardEvent) => {
      if (e instanceof KeyboardEvent ? e.key === "Escape" : !barRef.current?.contains(e.target as Node)) setMenu(false)
    }
    document.addEventListener("mousedown", close)
    document.addEventListener("keydown", close)
    return () => {
      document.removeEventListener("mousedown", close)
      document.removeEventListener("keydown", close)
    }
  }, [menu])

  // Bills not yet paid this month and next — what "coming up" means on the Note screen.
  const month = ym(today())
  const upcoming = [month, addMonths(month, 1)].flatMap((m) => monthSummary(bills, m).still).length

  // "Spent today": the note as written; if there's none, the lines saved from the Assistant.
  const written = note?.lines.filter((l) => l.trim()) ?? []
  const lines = written.length
    ? written
    : entries
      .filter((e) => e.date === day)
      .sort((a, b) => a.createdAt - b.createdAt)
      .map((e) => `${e.title} ${money(e.amount)}`)
  const shown = lines.slice(0, 5)

  return (
    <div className="screen">
      <span className="screen__glow screen__glow--soft" aria-hidden="true" />
      <DayHeader day={day} onDayChange={onDayChange} title="Note" onProfile={() => onTab("profile")} />
      <PageSwitch title="Note" other="Transaction" onOther={onTransactions} />

      <section className="note-block" aria-labelledby="coming-up">
        <h2 id="coming-up" className="note-block__label">
          Coming up
        </h2>
        <button type="button" className="note-card note-card--row" onClick={onDue}>
          <span className="note-card__bell">
            <Icon name="bell" size={18} />
          </span>
          <span className="note-card__row-text">
            {upcoming ? `${upcoming} ${upcoming === 1 ? "bill" : "bills"} coming up` : "No bills coming up — add one"}
          </span>
          <Icon name="caret-right-sm" size={14} />
        </button>
      </section>

      <section className="note-block note-block--grow" aria-labelledby="spent-today">
        <div className="note-card">
          <div className="note-card__head">
            <h2 id="spent-today" className="note-card__title">
              {day === today() ? "Spent today" : `Spent on ${shortDate(day)}`}
            </h2>
            <button type="button" className="note-card__more" onClick={onTransactions}>
              See More <Icon name="caret-right-sm" size={14} />
            </button>
          </div>
          {shown.length ? (
            <ol className="note-lines">
              {shown.map((l, i) => (
                <li key={i}>
                  <span className="note-lines__n">{i + 1}.</span>
                  <span className="note-lines__text">{l}</span>
                </li>
              ))}
              {lines.length > shown.length && <li className="note-lines__more">+{lines.length - shown.length} more</li>}
            </ol>
          ) : (
            <button type="button" className="note-card__empty" onClick={onNewNote}>
              Nothing written yet. Tap to jot down what you spent.
            </button>
          )}
        </div>
      </section>

      <div className="screen__bottom" ref={barRef}>
        <div className="note-menu-anchor">
          {menu && (
            <div className="note-menu lg lg--thick lg-morph" role="menu" aria-label="New">
              <button
                type="button"
                role="menuitem"
                className="note-menu__item"
                onClick={() => {
                  setMenu(false)
                  onNewNote()
                }}
              >
                <Icon name="note" size={20} />
                New note
              </button>
              <button type="button" role="menuitem" className="note-menu__item" disabled title="Scanning paper notes is coming later">
                <Icon name="scan" size={20} />
                Scan <span className="note-menu__soon">soon</span>
              </button>
            </div>
          )}
        </div>
        <TabBar
          active="expense"
          onTab={onTab}
          onQuickNote={onOpenAssistant}
          action={{ label: "New", onClick: () => setMenu((m) => !m), expanded: menu }}
        />
      </div>
    </div>
  )
}
