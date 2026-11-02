import { useRef, useState, type PointerEvent } from "react"
import { IconButton } from "../components/ui"
import { Icon } from "../components/Icon"
import StickyHeader from "../components/StickyHeader"
import { addDays, money, shortDate } from "../lib/format"
import type { Entry } from "../lib/store"
import DayPicker from "./DayPicker"
import "./today-header.css"

/** What the card and list on Today cover. */
export type Range = "day" | "month" | "year"
export const RANGES: { value: Range; label: string }[] = [
  { value: "day", label: "Daily" },
  { value: "month", label: "Monthly" },
  { value: "year", label: "Yearly" },
]
export const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
export const MONTHS_LONG = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
const WEEK = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

/** First and last day covered, as ISO strings (compared as text). */
export function bounds(range: Range, day: string): [string, string] {
  if (range === "month") return [`${day.slice(0, 7)}-01`, `${day.slice(0, 7)}-31`]
  if (range === "year") return [`${day.slice(0, 4)}-01-01`, `${day.slice(0, 4)}-12-31`]
  return [day, day]
}

/** Monday of the week that holds `iso`. */
export const mondayOf = (iso: string) => {
  const [y, m, d] = iso.split("-").map(Number)
  return addDays(iso, -((new Date(y, m - 1, d).getDay() + 6) % 7))
}
const addMonth = (ym: string, n: number) => {
  const [y, m] = ym.split("-").map(Number)
  const d = new Date(y, m - 1 + n, 1)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`
}

/**
 * Today's header — iOS TodayView: "Today" and profile top right; the picked day large (with a red
 * dot when it is now) and "Oct 2026"; Daily / Monthly / Yearly; then the week strip, or months /
 * years side by side with what went out in each.
 */
export default function TodayHeader({
  day,
  today,
  onDayChange,
  range,
  onRange,
  entries,
  hidden,
  onProfile,
}: {
  day: string
  today: string
  onDayChange: (d: string) => void
  range: Range
  onRange: (r: Range) => void
  entries: Entry[]
  hidden: boolean
  onProfile: () => void
}) {
  const [picking, setPicking] = useState(false)
  const [y, m, d] = day.split("-").map(Number)
  const isNow =
    range === "day" ? day === today : range === "month" ? day.slice(0, 7) === today.slice(0, 7) : day.slice(0, 4) === today.slice(0, 4)
  const scrolledTitle =
    range === "day" ? (day === today ? "Today" : `Today · ${shortDate(day)}`) : range === "month" ? `Today · ${MONTHS[m - 1]}` : `Today · ${y}`

  return (
    <>
      <StickyHeader
        title={scrolledTitle}
        right={
          <div className="today-top">
            <button type="button" className="today-top__today" onClick={() => onDayChange(today)} aria-label="Go to today">
              Today
            </button>
            <IconButton icon="user" label="Profile" variant="glass" size={44} iconSize={24} style={{ color: "var(--brand-600)" }} onClick={onProfile} />
          </div>
        }
      />

      <div className="today-head">
        <button type="button" className="today-head__date" onClick={() => setPicking(true)} aria-label="Pick a day">
          <span className="today-head__big tnum">{range === "day" ? String(d).padStart(2, "0") : y}</span>
          {isNow && <i className="today-head__dot" aria-label="now" />}
          {range === "day" && (
            <span className="today-head__month">
              {MONTHS[m - 1]} {y}
            </span>
          )}
        </button>
        <label className="today-head__range">
          <select value={range} onChange={(e) => onRange(e.target.value as Range)} aria-label="Show">
            {RANGES.map((r) => (
              <option key={r.value} value={r.value}>
                {r.label}
              </option>
            ))}
          </select>
          <span aria-hidden="true">{RANGES.find((r) => r.value === range)!.label}</span>
          <Icon name="caret-up-down" size={14} />
        </label>
      </div>

      {range === "day" && <WeekStrip day={day} today={today} marked={new Set(entries.map((e) => e.date))} onDay={onDayChange} />}
      {range === "month" && <MonthStrip day={day} today={today} entries={entries} hidden={hidden} onDay={onDayChange} />}
      {range === "year" && <YearStrip day={day} today={today} entries={entries} hidden={hidden} onDay={onDayChange} />}

      {picking && <DayPicker value={day} marked={new Set(entries.map((e) => e.date))} onPick={onDayChange} onClose={() => setPicking(false)} />}
    </>
  )
}

/** Mo–Su; swipe for the previous / next week (never past this week). Today's weekday is red. */
function WeekStrip({ day, today, marked, onDay }: { day: string; today: string; marked: Set<string>; onDay: (d: string) => void }) {
  const monday = mondayOf(day)
  const swipe = useRef<{ x: number; id: number } | null>(null)
  const move = (n: number) => {
    const next = addDays(day, n)
    onDay(next > today ? today : next)
  }
  return (
    <div
      className="week2"
      data-no-page-swipe
      role="group"
      aria-label={`Week of ${shortDate(monday)}`}
      onPointerDown={(e: PointerEvent) => (swipe.current = { x: e.clientX, id: e.pointerId })}
      onPointerUp={(e: PointerEvent) => {
        const s = swipe.current
        swipe.current = null
        if (!s || s.id !== e.pointerId) return
        const dx = e.clientX - s.x
        if (dx > 50) move(-7)
        else if (dx < -50) move(7)
      }}
    >
      {Array.from({ length: 7 }, (_, i) => {
        const d = addDays(monday, i)
        const picked = d === day
        const strong = marked.has(d) || d === today
        return (
          <button
            key={d}
            type="button"
            className={`week2__day${picked ? " is-picked" : ""}${strong ? " is-strong" : ""}${d === today ? " is-today" : ""}`}
            disabled={d > today}
            aria-pressed={picked}
            onClick={() => onDay(d)}
          >
            <span className="week2__num tnum">{d.slice(8)}</span>
            <span className="week2__name">{WEEK[i]}</span>
          </button>
        )
      })}
    </div>
  )
}

/** Months side by side with what went out: "4,608K đ / October". The picked one sits in the middle. */
function MonthStrip({ day, today, entries, hidden, onDay }: { day: string; today: string; entries: Entry[]; hidden: boolean; onDay: (d: string) => void }) {
  const now = today.slice(0, 7)
  const firstYear = Math.min(Number(now.slice(0, 4)) - 1, ...entries.map((e) => Number(e.date.slice(0, 4))))
  const keys: string[] = []
  for (let k = `${firstYear}-01`; k <= `${now.slice(0, 4)}-12`; k = addMonth(k, 1)) keys.push(k)
  const spent: Record<string, number> = {}
  for (const e of entries) if (e.flow === "out") spent[e.date.slice(0, 7)] = (spent[e.date.slice(0, 7)] ?? 0) + e.amount
  return (
    <PeriodStrip
      keys={keys}
      last={now}
      selected={day.slice(0, 7)}
      spent={spent}
      hidden={hidden}
      title={(k) => MONTHS_LONG[Number(k.slice(5, 7)) - 1]}
      label="Months"
      onSelect={(k) => onDay(k === now ? today : `${k}-01`)}
    />
  )
}

/** Years side by side, two years ahead greyed out. */
function YearStrip({ day, today, entries, hidden, onDay }: { day: string; today: string; entries: Entry[]; hidden: boolean; onDay: (d: string) => void }) {
  const now = Number(today.slice(0, 4))
  const first = Math.min(now - 2, ...entries.map((e) => Number(e.date.slice(0, 4))))
  const keys: string[] = []
  for (let k = first; k <= now + 2; k++) keys.push(String(k))
  const spent: Record<string, number> = {}
  for (const e of entries) if (e.flow === "out") spent[e.date.slice(0, 4)] = (spent[e.date.slice(0, 4)] ?? 0) + e.amount
  return (
    <PeriodStrip
      keys={keys}
      last={String(now)}
      selected={day.slice(0, 4)}
      spent={spent}
      hidden={hidden}
      title={(k) => k}
      label="Years"
      onSelect={(k) => onDay(k === String(now) ? today : `${k}-01-01`)}
    />
  )
}

/** Three slots — before | picked | after. Swipe sideways or tap a side cell; future ones are grey. */
function PeriodStrip({
  keys,
  last,
  selected,
  spent,
  hidden,
  title,
  label,
  onSelect,
}: {
  keys: string[]
  last: string
  selected: string
  spent: Record<string, number>
  hidden: boolean
  title: (k: string) => string
  label: string
  onSelect: (k: string) => void
}) {
  const idx = Math.max(0, keys.indexOf(selected))
  const lastIdx = keys.reduce((a, k, i) => (k <= last ? i : a), 0)
  const [drag, setDrag] = useState(0)
  const start = useRef<{ x: number; id: number } | null>(null)
  const box = useRef<HTMLDivElement>(null)
  const move = (i: number) => {
    const t = Math.min(Math.max(i, 0), lastIdx)
    if (t !== idx) onSelect(keys[t])
  }
  return (
    <div
      ref={box}
      className="period"
      data-no-page-swipe
      role="slider"
      tabIndex={0}
      aria-label={label}
      aria-valuetext={`${title(selected)}, ${hidden ? "amount hidden" : `${money(spent[selected] ?? 0)} dong spent`}`}
      aria-valuenow={idx}
      aria-valuemin={0}
      aria-valuemax={lastIdx}
      onKeyDown={(e) => {
        if (e.key === "ArrowRight") move(idx + 1)
        if (e.key === "ArrowLeft") move(idx - 1)
      }}
      onPointerDown={(e) => {
        start.current = { x: e.clientX, id: e.pointerId }
      }}
      onPointerMove={(e) => {
        if (start.current?.id === e.pointerId) setDrag(e.clientX - start.current.x)
      }}
      onPointerUp={(e) => {
        const s = start.current
        start.current = null
        setDrag(0)
        if (!s || s.id !== e.pointerId) return
        const slot = (box.current?.clientWidth ?? 360) / 3
        const steps = Math.round(-(e.clientX - s.x) / slot)
        if (steps) move(idx + steps)
      }}
      onPointerCancel={() => {
        start.current = null
        setDrag(0)
      }}
    >
      <div className="period__row" style={{ transform: `translateX(calc(${-(idx - 1)} * 100% / 3 + ${drag}px))`, transition: drag ? "none" : undefined }}>
        {keys.map((k, i) => {
          const future = k > last
          const v = spent[k] ?? 0
          const amount = future ? "—" : hidden ? "•••" : v >= 1000 ? `${money(Math.floor(v / 1000))}K` : money(v)
          return (
            <button
              key={k}
              type="button"
              tabIndex={-1}
              className={`period__cell${i === idx ? " is-picked" : ""}${future ? " is-future" : ""}`}
              onClick={() => !drag && move(i)}
            >
              <span className="period__amount tnum">
                {amount}
                <small>đ</small>
              </span>
              <span className="period__name">{title(k)}</span>
            </button>
          )
        })}
      </div>
    </div>
  )
}
