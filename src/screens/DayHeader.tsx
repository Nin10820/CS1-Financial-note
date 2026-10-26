import { useState } from "react"
import { IconButton } from "../components/ui"
import { Icon } from "../components/Icon"
import StickyHeader from "../components/StickyHeader"
import { addDays, longDate, shortDate, today } from "../lib/format"
import DayPicker from "./DayPicker"
import "./day-header.css"

/**
 * Header shared by Transaction and Note — Figma High Fi 2 › Expense (937:20415).
 * Row 1: page name (Bricolage) and the profile button. Row 2: previous day · day pill · next day.
 * The pill opens the day picker sheet. After scrolling, a small "Transaction · Today" title takes over.
 */
export default function DayHeader({
  day,
  onDayChange,
  title,
  onProfile,
  marked,
}: {
  day: string
  onDayChange: (day: string) => void
  title: string
  onProfile?: () => void
  /** Days that have notes, shown with a light green disc in the picker. */
  marked?: Set<string>
}) {
  const [picking, setPicking] = useState(false)
  const isToday = day === today()
  return (
    <>
      <StickyHeader
        title={`${title} · ${isToday ? "Today" : shortDate(day)}`}
        left={<h1 className="day-head__title">{title}</h1>}
        right={
          <IconButton
            icon="user"
            label="Profile"
            variant="glass"
            size={48}
            iconSize={24}
            style={{ color: "var(--brand-500)", background: "var(--white-48)" }}
            onClick={onProfile}
          />
        }
      />

      <div className="day-nav">
        <IconButton icon="caret-left" label="Previous day" variant="plain" size={40} iconSize={20} onClick={() => onDayChange(addDays(day, -1))} />
        <span className="day-pill">
          <button
            type="button"
            className="day-pill__btn lg lg-press"
            aria-label={`Day: ${longDate(day)}. Change day`}
            aria-haspopup="dialog"
            onClick={() => setPicking(true)}
          >
            <Icon name="calendar-blank" size={20} />
            <span>{longDate(day)}</span>
          </button>
        </span>
        <IconButton
          icon="caret-right"
          label="Next day"
          variant="plain"
          size={40}
          iconSize={20}
          disabled={isToday}
          onClick={() => onDayChange(addDays(day, 1))}
        />
      </div>

      {picking && <DayPicker value={day} marked={marked} onPick={onDayChange} onClose={() => setPicking(false)} />}
    </>
  )
}
