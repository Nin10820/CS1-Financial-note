import { useEffect, useMemo, useRef, useState, type PointerEvent } from "react"
import { Button } from "../components/ui"
import { Icon } from "../components/Icon"
import { pad, today } from "../lib/format"
import ModalSheet, { ModalHeader } from "./ModalSheet"
import "./day-picker.css"

const WEEK = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
const monthName = (y: number, m: number) => new Date(y, m, 1).toLocaleString("en-US", { month: "long" })
const iso = (y: number, m: number, d: number) => {
  const dt = new Date(y, m, d)
  return `${dt.getFullYear()}-${pad(dt.getMonth() + 1)}-${pad(dt.getDate())}`
}

/** Six weeks starting on the Monday on or before the 1st, so every month has the same height. */
function monthGrid(y: number, m: number) {
  const lead = (new Date(y, m, 1).getDay() + 6) % 7
  return Array.from({ length: 42 }, (_, i) => {
    const date = iso(y, m, 1 - lead + i)
    return { date, day: Number(date.slice(8)), inMonth: Number(date.slice(5, 7)) === m + 1 }
  })
}

/**
 * Day picker — Figma High Fi 2 › Template-Modal (962:32146).
 * Inset glass sheet: Today · Day · Done, a month label that opens a month / year wheel (964:33538),
 * and the month grid.
 * Selected day is dark, today is solid green, days with notes get a light green disc.
 * Later days can't hold spending yet, so they are shown but can't be picked.
 */
export default function DayPicker({
  value,
  marked,
  onPick,
  onClose,
}: {
  value: string
  /** Days that already have notes. */
  marked?: Set<string>
  onPick: (day: string) => void
  onClose: () => void
}) {
  const now = today()
  const [picked, setPicked] = useState(value)
  const [view, setView] = useState(() => ({ y: Number(value.slice(0, 4)), m: Number(value.slice(5, 7)) - 1 }))
  const [months, setMonths] = useState(false)
  const cells = useMemo(() => monthGrid(view.y, view.m), [view])
  // Trim the trailing week when it belongs entirely to the next month.
  const shown = cells.slice(35).every((c) => !c.inMonth) ? cells.slice(0, 35) : cells

  const shift = (n: number) => setView((v) => ({ y: v.y + Math.floor((v.m + n) / 12), m: (((v.m + n) % 12) + 12) % 12 }))
  const nowY = Number(now.slice(0, 4))
  const nowM = Number(now.slice(5, 7)) - 1
  const atLatest = view.y > nowY || (view.y === nowY && view.m >= nowM)

  // Swipe sideways on the grid to change month.
  const swipe = useRef<{ x: number; id: number } | null>(null)
  const onDown = (e: PointerEvent) => (swipe.current = { x: e.clientX, id: e.pointerId })
  const onUp = (e: PointerEvent) => {
    const s = swipe.current
    swipe.current = null
    if (!s || s.id !== e.pointerId) return
    const dx = e.clientX - s.x
    if (dx > 50) shift(-1)
    else if (dx < -50 && !atLatest) shift(1)
  }

  const goToday = () => {
    setPicked(now)
    setView({ y: nowY, m: nowM })
    setMonths(false)
  }

  return (
    <ModalSheet
      label="Pick a day"
      size="auto"
      onClose={onClose}
      header={
        <ModalHeader
          title="Day"
          left={
            <Button variant="glass" size="md" onClick={goToday}>
              Today
            </Button>
          }
          right={
            <Button
              variant="glass"
              size="md"
              onClick={() => {
                onPick(picked)
                onClose()
              }}
            >
              Done
            </Button>
          }
        />
      }
    >
      <div className="day-picker">
        <div className="day-picker__bar">
          <button
            type="button"
            className="day-picker__month"
            aria-expanded={months}
            onClick={() => setMonths((o) => !o)}
          >
            {monthName(view.y, view.m)} {view.y}
            <span className={`day-picker__caret${months ? " is-open" : ""}`}>
              <Icon name="caret-down" size={14} />
            </span>
          </button>
        </div>

        {months ? (
          <div className="day-picker__wheels">
            <Wheel
              label="Month"
              items={Array.from({ length: 12 }, (_, m) => ({ value: m, text: monthName(2000, m), disabled: view.y === nowY && m > nowM }))}
              value={view.m}
              onChange={(m) => setView((v) => ({ ...v, m }))}
            />
            <Wheel
              label="Year"
              items={Array.from({ length: nowY - 2019 }, (_, i) => ({ value: 2020 + i, text: String(2020 + i) }))}
              value={view.y}
              onChange={(y) => setView((v) => ({ y, m: y === nowY ? Math.min(v.m, nowM) : v.m }))}
            />
          </div>
        ) : (
          <div className="day-picker__grid" role="grid" aria-label={`${monthName(view.y, view.m)} ${view.y}`} onPointerDown={onDown} onPointerUp={onUp}>
            {WEEK.map((w) => (
              <span key={w} className="day-picker__week" role="columnheader">
                {w}
              </span>
            ))}
            {shown.map((c) => {
              const future = c.date > now
              const state =
                c.date === picked ? "is-picked" : c.date === now ? "is-today" : marked?.has(c.date) && c.inMonth ? "is-marked" : ""
              return (
                <button
                  key={c.date}
                  type="button"
                  role="gridcell"
                  className={`day-picker__day ${state}${c.inMonth ? "" : " is-outside"}`}
                  disabled={future}
                  aria-selected={c.date === picked}
                  aria-current={c.date === now ? "date" : undefined}
                  aria-label={new Date(c.date + "T00:00").toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" })}
                  onClick={() => {
                    setPicked(c.date)
                    if (!c.inMonth) setView({ y: Number(c.date.slice(0, 4)), m: Number(c.date.slice(5, 7)) - 1 })
                  }}
                >
                  {c.day}
                </button>
              )
            })}
          </div>
        )}
      </div>
    </ModalSheet>
  )
}

const ROW = 34 // px per wheel row; five rows show

/** iOS-style picker wheel: scroll-snapped column, the row in the middle is the value. */
function Wheel<T extends number>({
  label,
  items,
  value,
  onChange,
}: {
  label: string
  items: { value: T; text: string; disabled?: boolean }[]
  value: T
  onChange: (v: T) => void
}) {
  const ref = useRef<HTMLDivElement>(null)
  const index = Math.max(0, items.findIndex((i) => i.value === value))
  const [shown, setShown] = useState(index)
  const settle = useRef(0)

  // Jump to the value on open and whenever it changes from outside (e.g. the year clamps the month).
  useEffect(() => {
    const el = ref.current
    if (el && Math.round(el.scrollTop / ROW) !== index) el.scrollTo({ top: index * ROW })
    setShown(index)
  }, [index])

  const onScroll = () => {
    const el = ref.current
    if (!el) return
    const i = Math.min(items.length - 1, Math.max(0, Math.round(el.scrollTop / ROW)))
    setShown(i)
    window.clearTimeout(settle.current)
    settle.current = window.setTimeout(() => {
      // A disabled row (a future month) springs back to the nearest allowed one.
      let j = i
      while (j > 0 && items[j].disabled) j--
      if (j !== i) el.scrollTo({ top: j * ROW, behavior: "smooth" })
      if (items[j].value !== value) onChange(items[j].value)
    }, 120)
  }

  return (
    <div
      ref={ref}
      className="wheel"
      role="listbox"
      aria-label={label}
      tabIndex={0}
      onScroll={onScroll}
      onKeyDown={(e) => {
        const step = e.key === "ArrowDown" ? 1 : e.key === "ArrowUp" ? -1 : 0
        if (!step) return
        e.preventDefault()
        const j = Math.min(items.length - 1, Math.max(0, index + step))
        if (!items[j].disabled) onChange(items[j].value)
      }}
    >
      {items.map((it, i) => (
        <div
          key={it.value}
          role="option"
          aria-selected={i === index}
          aria-disabled={it.disabled}
          className={`wheel__row${i === shown ? " is-center" : ""}${it.disabled ? " is-disabled" : ""}`}
          style={{ ["--d" as string]: Math.min(2, Math.abs(i - shown)) }}
          onClick={() => !it.disabled && ref.current?.scrollTo({ top: i * ROW, behavior: "smooth" })}
        >
          {it.text}
        </div>
      ))}
    </div>
  )
}
