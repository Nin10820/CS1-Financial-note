import { useRef } from "react"
import { DatePill, IconButton } from "../components/ui"
import StickyHeader from "../components/StickyHeader"
import { longDate, shortDate, today } from "../lib/format"

/** Header shared by Transaction and Note: calendar, the day pill, profile.
    After scrolling, the pill gives way to a small "Transaction · 26 Oct" title. */
export default function DayHeader({
  day,
  onDayChange,
  title,
  onProfile,
}: {
  day: string
  onDayChange: (day: string) => void
  title: string
  onProfile?: () => void
}) {
  const picker = useRef<HTMLInputElement>(null)
  const open = () => {
    const el = picker.current
    if (!el) return
    if (typeof el.showPicker === "function") el.showPicker()
    else el.click()
  }
  return (
    <StickyHeader
      title={`${title} · ${day === today() ? "Today" : shortDate(day)}`}
      left={
        <>
          <IconButton icon="calendar" label="Pick a day" variant="glass" onClick={open} style={{ color: "var(--grey-500)" }} />
          <input
            ref={picker}
            className="visually-hidden"
            type="date"
            value={day}
            max={today()}
            tabIndex={-1}
            aria-hidden="true"
            onChange={(e) => e.target.value && onDayChange(e.target.value)}
          />
        </>
      }
      center={<DatePill label={longDate(day)} onClick={open} aria-label={`Day: ${longDate(day)}. Change day`} />}
      right={<IconButton icon="user" label="Profile" variant="glass" iconSize={24} style={{ color: "var(--brand-500)" }} onClick={onProfile} />}
    />
  )
}
