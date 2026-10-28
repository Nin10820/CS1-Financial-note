import { useEffect, useRef, useState, type PointerEvent } from "react"
import { IconButton } from "../components/ui"
import { Icon } from "../components/Icon"
import StickyHeader from "../components/StickyHeader"
import { addDays, shortDate, today } from "../lib/format"
import DayPicker from "./DayPicker"
import "./day-header.css"

export type Range = "day" | "week" | "month"

const RANGES: { value: Range; label: string }[] = [
  { value: "day", label: "Daily" },
  { value: "week", label: "Weekly" },
  { value: "month", label: "Monthly" },
]
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const WEEK = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

/** Monday of the week that holds `iso`. */
export const mondayOf = (iso: string) => {
  const [y, m, d] = iso.split("-").map(Number)
  const lead = (new Date(y, m - 1, d).getDay() + 6) % 7
  return addDays(iso, -lead)
}

/**
 * Header shared by Today and Note — Figma High Fi 2 › Expense (962:31983, 1010:18444).
 * Row 1: "Today" pill and profile. Row 2: month name and the Daily / Weekly / Monthly menu.
 * Row 3: the week strip — swipe it for the next or previous week, tap the month for the picker.
 */
export default function DayHeader({
  day,
  onDayChange,
  title,
  onProfile,
  marked,
  range,
  onRange,
}: {
  day: string
  onDayChange: (day: string) => void
  /** Small title shown in the bar after scrolling. */
  title: string
  onProfile?: () => void
  /** Days that have notes: shown darker in the strip and with a disc in the picker. */
  marked?: Set<string>
  range?: Range
  onRange?: (r: Range) => void
}) {
  const [picking, setPicking] = useState(false)
  const [menu, setMenu] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)
  const now = today()
  const monday = mondayOf(day)
  const days = Array.from({ length: 7 }, (_, i) => addDays(monday, i))
  const [y, m] = day.split("-").map(Number)
  const current = RANGES.find((r) => r.value === (range ?? "day"))!

  useEffect(() => {
    if (!menu) return
    const close = (e: Event) => {
      if (e instanceof KeyboardEvent ? e.key === "Escape" : !menuRef.current?.contains(e.target as Node)) setMenu(false)
    }
    document.addEventListener("pointerdown", close)
    document.addEventListener("keydown", close)
    return () => {
      document.removeEventListener("pointerdown", close)
      document.removeEventListener("keydown", close)
    }
  }, [menu])

  // Swipe the strip sideways for the previous / next week (never past this week).
  const swipe = useRef<{ x: number; id: number } | null>(null)
  const onDown = (e: PointerEvent) => (swipe.current = { x: e.clientX, id: e.pointerId })
  const onUp = (e: PointerEvent) => {
    const s = swipe.current
    swipe.current = null
    if (!s || s.id !== e.pointerId) return
    const dx = e.clientX - s.x
    if (dx > 50) onDayChange(addDays(day, -7))
    else if (dx < -50) {
      const next = addDays(day, 7)
      onDayChange(next > now ? now : next)
    }
  }

  const scrolledTitle = range === "week" ? `${title} · Week of ${shortDate(monday)}` : range === "month" ? `${title} · ${MONTHS[m - 1]}` : `${title} · ${day === now ? "Today" : shortDate(day)}`

  return (
    <>
      <StickyHeader
        title={scrolledTitle}
        left={
          <button type="button" className="day-today lg lg-press" onClick={() => onDayChange(now)} aria-label="Go to today">
            Today
          </button>
        }
        right={
          <IconButton
            icon="user"
            label="Profile"
            variant="glass"
            size={48}
            iconSize={24}
            style={{ color: "var(--brand-500)" }}
            onClick={onProfile}
          />
        }
      />

      <div className="day-bar">
        <div className="day-bar__row">
          <button type="button" className="day-bar__month" onClick={() => setPicking(true)} aria-haspopup="dialog" aria-label={`${MONTHS[m - 1]} ${y}. Pick a day`}>
            {MONTHS[m - 1]} {y}
          </button>
          {onRange && (
            <div className="day-range" ref={menuRef}>
              <button type="button" className="day-range__btn" aria-haspopup="menu" aria-expanded={menu} onClick={() => setMenu(!menu)}>
                {current.label}
                <Icon name="caret-up-down" size={14} />
              </button>
              {menu && (
                <div className="day-range__menu lg lg--thick lg-morph" role="menu">
                  {RANGES.map((r) => (
                    <button
                      key={r.value}
                      type="button"
                      role="menuitemradio"
                      aria-checked={r.value === current.value}
                      className="day-range__item"
                      onClick={() => {
                        onRange(r.value)
                        setMenu(false)
                      }}
                    >
                      <span className="day-range__check">{r.value === current.value && <Icon name="check" size={20} />}</span>
                      {r.label}
                    </button>
                  ))}
                </div>
              )}
            </div>
          )}
        </div>

        <div className={`week${range === "week" ? " is-week" : ""}`} role="group" aria-label="This week" onPointerDown={onDown} onPointerUp={onUp}>
          {days.map((d, i) => {
            const future = d > now
            const picked = range === "week" ? true : d === day
            return (
              <button
                key={d}
                type="button"
                className={`week__day${picked && range !== "week" ? " is-picked" : ""}${marked?.has(d) || d === now ? " is-marked" : ""}`}
                disabled={future}
                aria-pressed={d === day}
                aria-label={new Date(d + "T00:00").toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" })}
                onClick={() => onDayChange(d)}
              >
                <span className="week__name">{WEEK[i]}</span>
                <span className="week__num">{d.slice(8)}</span>
              </button>
            )
          })}
        </div>
      </div>

      {picking && <DayPicker value={day} marked={marked} onPick={onDayChange} onClose={() => setPicking(false)} />}
    </>
  )
}
