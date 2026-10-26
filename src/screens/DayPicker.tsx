import { useMemo, useRef, useState, type PointerEvent } from "react"
import { Button, IconButton } from "../components/ui"
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
 * Inset glass sheet: Today · Day · Done, a month label that opens a month list, and the month grid.
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
              <Icon name="caret-right-sm" size={14} />
            </span>
          </button>
        </div>

        {months ? (
          <div className="day-picker__months">
            <div className="day-picker__year">
              <IconButton icon="caret-left" label="Previous year" variant="plain" size={32} iconSize={16} onClick={() => setView((v) => ({ ...v, y: v.y - 1 }))} />
              <span>{view.y}</span>
              <IconButton
                icon="caret-right"
                label="Next year"
                variant="plain"
                size={32}
                iconSize={16}
                disabled={view.y >= nowY}
                onClick={() => setView((v) => ({ y: v.y + 1, m: v.y + 1 === nowY ? Math.min(v.m, nowM) : v.m }))}
              />
            </div>
            <div className="day-picker__month-grid">
              {Array.from({ length: 12 }, (_, m) => {
                const future = view.y > nowY || (view.y === nowY && m > nowM)
                return (
                  <button
                    key={m}
                    type="button"
                    className={`day-picker__month-cell${m === view.m ? " is-picked" : ""}`}
                    disabled={future}
                    onClick={() => {
                      setView((v) => ({ ...v, m }))
                      setMonths(false)
                    }}
                  >
                    {monthName(view.y, m).slice(0, 3)}
                  </button>
                )
              })}
            </div>
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
