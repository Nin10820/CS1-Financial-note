import { useRef } from "react"
import { DatePill, IconButton } from "../components/ui"
import { longDate, today } from "../lib/format"

/** Header shared by Transaction and Note: calendar, the day pill, profile. */
export default function DayHeader({ day, onDayChange }: { day: string; onDayChange: (day: string) => void }) {
  const picker = useRef<HTMLInputElement>(null)
  const open = () => {
    const el = picker.current
    if (!el) return
    if (typeof el.showPicker === "function") el.showPicker()
    else el.click()
  }
  return (
    <header className="screen__header">
      <IconButton icon="calendar" label="Pick a day" variant="glass" onClick={open} style={{ color: "var(--grey-500)" }} />
      <DatePill label={longDate(day)} onClick={open} aria-label={`Day: ${longDate(day)}. Change day`} />
      <IconButton icon="user" label="Profile" variant="glass" iconSize={24} style={{ color: "var(--brand-500)" }} />
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
    </header>
  )
}
