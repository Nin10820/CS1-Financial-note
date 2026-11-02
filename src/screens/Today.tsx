import { useMemo, useRef, useState, type PointerEvent, type ReactNode } from "react"
import { LogoMark } from "../components/ui"
import { Icon } from "../components/Icon"
import { addDays, clock, greeting, longDate, money, shortDate } from "../lib/format"
import { categoryTone, type DayNote, type Entry } from "../lib/store"
import TodayHeader, { MONTHS, MONTHS_LONG, bounds, type Range } from "./TodayHeader"
import "./today.css"

type Flow = "all" | "out" | "in"
type Pane = "recent" | "file"

/**
 * Today — as built in the iOS app (TodayView): the header and strip, then the greeting on an empty
 * day or the dark Total Amount card with Recent | File underneath. Swipe the page sideways for the
 * previous / next day (month, year) — never past today.
 */
export default function Today({
  day,
  today,
  onDayChange,
  range,
  onRange,
  entries,
  notes,
  name,
  hidden,
  onToggleHidden,
  onOpenEntry,
  onDeleteEntry,
  onOpenNote,
  onIdea,
  onProfile,
}: {
  day: string
  today: string
  onDayChange: (d: string) => void
  range: Range
  onRange: (r: Range) => void
  entries: Entry[]
  notes: Record<string, DayNote>
  name: string
  hidden: boolean
  onToggleHidden: () => void
  onOpenEntry: (id: string) => void
  onDeleteEntry: (id: string) => void
  /** Opens Notes of the day for that date. */
  onOpenNote: (date: string) => void
  onIdea: (idea: "write" | "due" | "decisions") => void
  onProfile: () => void
}) {
  const [pane, setPane] = useState<Pane>("recent")
  const [flow, setFlow] = useState<Flow>("all")
  const [deleting, setDeleting] = useState<Entry | null>(null)

  const [from, to] = bounds(range, day)
  const list = useMemo(
    () =>
      entries
        .filter((e) => e.date >= from && e.date <= to)
        .sort((a, b) => (a.date === b.date ? b.createdAt - a.createdAt : b.date.localeCompare(a.date))),
    [entries, from, to],
  )
  const out = list.filter((e) => e.flow === "out").reduce((s, e) => s + e.amount, 0)
  const incoming = list.filter((e) => e.flow === "in").reduce((s, e) => s + e.amount, 0)
  const noteCount = new Set(list.map((e) => e.noteId)).size
  const updated = list.length ? clock(Math.max(...list.map((e) => e.createdAt))) : "—"
  const [, m] = day.split("-").map(Number)
  const nothing =
    range === "year" ? `Nothing recorded in ${day.slice(0, 4)}.` : range === "month" ? `Nothing recorded in ${MONTHS_LONG[m - 1]}.` : day === today ? null : `Nothing recorded on ${shortDate(day)}.`

  // Page swipe: a clear sideways move anywhere except the strips and rows (they have their own).
  const swipe = useRef<{ x: number; y: number; id: number } | null>(null)
  const step = (n: number) => {
    let next = day
    if (range === "day") next = addDays(day, n)
    else if (range === "month") {
      const d = new Date(Number(day.slice(0, 4)), m - 1 + n, 1)
      const k = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`
      next = k === today.slice(0, 7) ? today : `${k}-01`
    } else {
      const y = Number(day.slice(0, 4)) + n
      next = String(y) === today.slice(0, 4) ? today : `${y}-01-01`
    }
    if (next <= today) onDayChange(next)
  }

  return (
    <div
      className="screen today"
      onPointerDown={(e: PointerEvent) => {
        if ((e.target as Element).closest("[data-no-page-swipe], input, textarea, select")) return
        swipe.current = { x: e.clientX, y: e.clientY, id: e.pointerId }
      }}
      onPointerUp={(e: PointerEvent) => {
        const s = swipe.current
        swipe.current = null
        if (!s || s.id !== e.pointerId) return
        const dx = e.clientX - s.x
        const dy = e.clientY - s.y
        if (Math.abs(dx) > 70 && Math.abs(dx) > Math.abs(dy) * 1.6) step(dx < 0 ? 1 : -1)
      }}
    >
      <span className="today__glow" aria-hidden="true" />
      <TodayHeader day={day} today={today} onDayChange={onDayChange} range={range} onRange={onRange} entries={entries} hidden={hidden} onProfile={onProfile} />

      <div className="today__body">
        {list.length === 0 && pane === "recent" && range === "day" ? (
          <section className="home-empty" aria-label="Nothing recorded yet">
            <LogoMark size={64} />
            <h2 className="home-empty__hello">
              {greeting()}, {name}
            </h2>
            <ul className="home-empty__ideas">
              <li>
                <button type="button" onClick={() => onIdea("write")}>
                  <Icon name="logo-mark" size={16} />
                  <span>What can I help you think through today?</span>
                </button>
              </li>
              <li>
                <button type="button" onClick={() => onIdea("due")}>
                  <Icon name="logo-mark" size={16} />
                  <span>What&apos;s worth talking about today?</span>
                </button>
              </li>
              <li>
                <button type="button" onClick={() => onIdea("decisions")}>
                  <Icon name="logo-mark" size={16} />
                  <span>Any decisions on your mind today?</span>
                </button>
              </li>
            </ul>
            {nothing && <p className="t-capture-12-r home-empty__day">{nothing}</p>}
          </section>
        ) : (
          <>
            <TotalCard out={out} incoming={incoming} notes={noteCount} updated={updated} hidden={hidden} onToggleHidden={onToggleHidden} flow={flow} onFlow={setFlow} />
            <div className="today__panes" role="tablist" aria-label="Show">
              {(["recent", "file"] as const).map((p) => (
                <button key={p} type="button" role="tab" aria-selected={pane === p} className={`today__pane${pane === p ? " is-on" : ""}`} onClick={() => setPane(p)}>
                  {p === "recent" ? "Recent" : "File"}
                </button>
              ))}
            </div>
            {pane === "recent" ? (
              <Recent
                list={list.filter((e) => flow === "all" || e.flow === flow)}
                many={range !== "day"}
                today={today}
                hidden={hidden}
                nothing={nothing ?? "Nothing recorded yet."}
                onOpen={onOpenEntry}
                onDelete={(e) => setDeleting(e)}
              />
            ) : (
              <FilePane notes={notes} from={from} to={to} range={range} day={day} today={today} onOpen={onOpenNote} />
            )}
          </>
        )}
      </div>

      {deleting && (
        <div className="confirm" role="alertdialog" aria-label={`Delete “${deleting.title}”?`}>
          <div className="confirm__scrim" onClick={() => setDeleting(null)} />
          <div className="confirm__box">
            <p className="confirm__title">Delete “{deleting.title}”?</p>
            <button
              type="button"
              className="confirm__btn is-danger"
              onClick={() => {
                onDeleteEntry(deleting.id)
                setDeleting(null)
              }}
            >
              Yes, delete
            </button>
            <button type="button" className="confirm__btn" onClick={() => setDeleting(null)}>
              Keep it
            </button>
          </div>
        </div>
      )}
    </div>
  )
}

/** "Total Amount" (Figma __card-transaction 1116:35317): in − out, the eye, notes · updated, and All / − out / + in. */
function TotalCard({
  out,
  incoming,
  notes,
  updated,
  hidden,
  onToggleHidden,
  flow,
  onFlow,
}: {
  out: number
  incoming: number
  notes: number
  updated: string
  hidden: boolean
  onToggleHidden: () => void
  flow: Flow
  onFlow: (f: Flow) => void
}) {
  const net = incoming - out
  // From a million up, thousands with K ("1,900K"), so the chips don't fill with zeros.
  const short = (v: number) => (v >= 1_000_000 ? `${money(Math.floor(v / 1000))}K` : money(v))
  return (
    <section className="total" aria-label="Total amount">
      <p className="total__label">Total Amount</p>
      <div className="total__row">
        <span className="total__amount tnum" aria-label={hidden ? "Total amount, hidden" : `Total amount, ${net < 0 ? "minus " : ""}${money(Math.abs(net))} dong`}>
          <span className="total__num">{hidden ? "••••••" : `${net < 0 ? "-" : ""}${money(Math.abs(net))}`}</span>
          <span className="total__cur">đ</span>
        </span>
        <button type="button" className="total__eye" aria-label={hidden ? "Show amounts" : "Hide amounts"} aria-pressed={hidden} onClick={onToggleHidden}>
          <Icon name="eye-slash" size={16} />
        </button>
      </div>
      <p className="total__meta">
        {notes} {notes === 1 ? "note" : "notes"} <i /> updated {updated}
      </p>
      <div className="total__filters" role="group" aria-label="Show">
        <div className="total__box">
          <button type="button" className={`total__chip${flow === "all" ? " is-on" : ""}`} aria-pressed={flow === "all"} onClick={() => onFlow("all")}>
            All
          </button>
        </div>
        <div className="total__box total__box--two">
          <button type="button" className={`total__chip${flow === "out" ? " is-on" : ""}`} aria-pressed={flow === "out"} onClick={() => onFlow("out")} aria-label={`Money out, ${hidden ? "hidden" : `${money(out)} dong`}`}>
            <span className="total__sign is-out">
              <Icon name="minus-circle" size={18} />
            </span>
            <span className="tnum">{hidden ? "••••" : short(out)}</span>
            <small>đ</small>
          </button>
          <button type="button" className={`total__chip${flow === "in" ? " is-on" : ""}`} aria-pressed={flow === "in"} onClick={() => onFlow("in")} aria-label={`Money in, ${hidden ? "hidden" : `${money(incoming)} dong`}`}>
            <span className="total__sign is-in">
              <Icon name="plus-circle" size={18} />
            </span>
            <span className="tnum">{hidden ? "••••" : short(incoming)}</span>
            <small>đ</small>
          </button>
        </div>
      </div>
    </section>
  )
}

/** The lines: a day heading per day when the range covers many days; each row slides for Edit / Delete. */
function Recent({
  list,
  many,
  today,
  hidden,
  nothing,
  onOpen,
  onDelete,
}: {
  list: Entry[]
  many: boolean
  today: string
  hidden: boolean
  nothing: string
  onOpen: (id: string) => void
  onDelete: (e: Entry) => void
}) {
  if (!list.length) return <p className="recent__none">{nothing}</p>
  return (
    <div className="recent">
      {list.map((e, i) => (
        <div key={e.id}>
          {many && (i === 0 || list[i - 1].date !== e.date) && <h3 className="recent__day">{dayHeading(e.date, today)}</h3>}
          <SwipeRow onTap={() => onOpen(e.id)} onEdit={() => onOpen(e.id)} onDelete={() => onDelete(e)}>
            <EntryRow entry={e} hidden={hidden} />
          </SwipeRow>
        </div>
      ))}
    </div>
  )
}

/** "Today", "Yesterday", or "Mon 26 Oct". */
function dayHeading(iso: string, today: string) {
  if (iso === today) return "Today"
  if (iso === addDays(today, -1)) return "Yesterday"
  const [y, m, d] = iso.split("-").map(Number)
  const names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  return `${names[new Date(y, m - 1, d).getDay()]} ${d} ${MONTHS[m - 1]}`
}

/** One line: round ↗ / ↘ tile, title, "Food • 21:14:00", the amount in Bricolage. */
export function EntryRow({ entry, hidden }: { entry: Entry; hidden: boolean }) {
  const t = new Date(entry.createdAt)
  const time = [t.getHours(), t.getMinutes(), t.getSeconds()].map((n) => String(n).padStart(2, "0")).join(":")
  return (
    <div className="erow">
      <span className={`erow__tile${entry.flow === "in" ? " is-in" : ""}`} aria-hidden="true">
        <Icon name={entry.flow === "in" ? "arrow-down-right" : "arrow-up-right"} size={18} />
      </span>
      <span className="erow__text">
        <span className="erow__title">{entry.title}</span>
        <span className="erow__meta">
          <span className={`fn-trans__cat is-${categoryTone(entry.category)}`}>{entry.category}</span>
          <i />
          <span className="tnum">{time}</span>
        </span>
      </span>
      <span className={`erow__amount tnum${entry.flow === "in" ? " is-in" : ""}`}>
        {hidden ? "••••••" : money(entry.amount)}
        <small>đ</small>
      </span>
    </div>
  )
}

/** Slide right for a green Edit, left for a red Delete. Tap opens it (or closes the buttons). */
function SwipeRow({ onTap, onEdit, onDelete, children }: { onTap: () => void; onEdit: () => void; onDelete: () => void; children: ReactNode }) {
  const [offset, setOffset] = useState(0)
  const start = useRef<{ x: number; y: number; base: number; id: number; moved: boolean } | null>(null)
  const REVEAL = 60
  const close = () => setOffset(0)
  return (
    <div className="swipe" data-no-page-swipe>
      {offset > 0 && (
        <button type="button" className="swipe__btn is-edit" aria-label="Edit" onClick={() => (close(), onEdit())}>
          <Icon name="pencil" size={20} />
        </button>
      )}
      {offset < 0 && (
        <button type="button" className="swipe__btn is-delete" aria-label="Delete" onClick={() => (close(), onDelete())}>
          <Icon name="trash" size={20} />
        </button>
      )}
      <button
        type="button"
        className={`swipe__row${offset ? " is-open" : ""}`}
        style={{ transform: `translateX(${offset}px)`, transition: start.current?.moved ? "none" : undefined }}
        onPointerDown={(e) => {
          start.current = { x: e.clientX, y: e.clientY, base: offset, id: e.pointerId, moved: false }
        }}
        onPointerMove={(e) => {
          const s = start.current
          if (!s || s.id !== e.pointerId) return
          const dx = e.clientX - s.x
          if (!s.moved && (Math.abs(dx) < 12 || Math.abs(dx) < Math.abs(e.clientY - s.y))) return
          s.moved = true
          setOffset(Math.max(-REVEAL * 1.3, Math.min(REVEAL * 1.3, s.base + dx)))
        }}
        onPointerUp={() => {
          const s = start.current
          start.current = null
          if (!s?.moved) return
          setOffset((o) => (o > REVEAL / 2 ? REVEAL : o < -REVEAL / 2 ? -REVEAL : 0))
        }}
        onPointerCancel={() => {
          start.current = null
          close()
        }}
        onClick={(e) => {
          if (start.current?.moved) return e.preventDefault()
          if (offset) close()
          else onTap()
        }}
      >
        {children}
      </button>
    </div>
  )
}

/** "File": the notes written for the period, as cards. Tap one to open it. */
function FilePane({
  notes,
  from,
  to,
  range,
  day,
  today,
  onOpen,
}: {
  notes: Record<string, DayNote>
  from: string
  to: string
  range: Range
  day: string
  today: string
  onOpen: (date: string) => void
}) {
  const shown = Object.entries(notes)
    .filter(([d, n]) => d >= from && d <= to && n.lines.length)
    .sort((a, b) => b[0].localeCompare(a[0]))
  const when = range === "day" ? (day === today ? "today" : `on ${shortDate(day)}`) : range === "month" ? "this month" : "this year"
  return (
    <div className="file">
      {!shown.length && <p className="recent__none">No note written {when}.</p>}
      {shown.map(([d, n]) => (
        <button key={d} type="button" className="note-file" onClick={() => onOpen(d)}>
          <span className="note-file__title">Note - {longDate(d)}</span>
          {n.lines.slice(0, 3).map((l, i) => (
            <span key={i} className="note-file__line">
              {l}
            </span>
          ))}
          {n.lines.length > 3 && <span className="note-file__more">+{n.lines.length - 3} more</span>}
          <span className="note-file__tag">Note</span>
        </button>
      ))}
      <button type="button" className="file__write" onClick={() => onOpen(day)}>
        <Icon name="file-edit" size={18} />
        Write a note for {day === today ? "today" : shortDate(day)}
      </button>
    </div>
  )
}
