import { useRef, useState, type KeyboardEvent } from "react"
import { IconButton } from "../components/ui"
import { Icon } from "../components/Icon"
import { longDate, shortDate, today } from "../lib/format"
import type { DayNote } from "../lib/store"
import ModalSheet, { ModalHeader } from "./ModalSheet"

/** Figma Final › Note-action (765:19695 / 19721 / 19749): a numbered list for the day.
    The green check saves the note and hands it to the Assistant to read. */
export default function NoteEditor({
  day,
  notes,
  onClose,
  onSave,
}: {
  day: string
  notes: Record<string, DayNote>
  onClose: () => void
  onSave: (date: string, lines: string[]) => void
}) {
  const [date, setDate] = useState(day)
  const [lines, setLines] = useState<string[]>(() => {
    const saved = notes[day]?.lines.filter((l) => l.trim())
    return saved?.length ? [...saved, ""] : [""]
  })
  const [focus, setFocus] = useState(0)
  const [history, setHistory] = useState(false)
  const inputs = useRef<(HTMLInputElement | null)[]>([])
  const picker = useRef<HTMLInputElement>(null)
  const filled = lines.filter((l) => l.trim())

  const focusAt = (i: number) => requestAnimationFrame(() => inputs.current[i]?.focus())

  const onKey = (e: KeyboardEvent<HTMLInputElement>, i: number) => {
    if (e.nativeEvent.isComposing) return
    if (e.key === "Enter") {
      e.preventDefault()
      setLines((ls) => [...ls.slice(0, i + 1), "", ...ls.slice(i + 1)])
      focusAt(i + 1)
    } else if (e.key === "Backspace" && !lines[i] && lines.length > 1) {
      e.preventDefault()
      setLines((ls) => ls.filter((_, k) => k !== i))
      focusAt(Math.max(0, i - 1))
    } else if (e.key === "ArrowDown" && i < lines.length - 1) focusAt(i + 1)
    else if (e.key === "ArrowUp" && i > 0) focusAt(i - 1)
  }

  const past = Object.entries(notes)
    .filter(([, n]) => n.lines.some((l) => l.trim()))
    .sort((a, b) => b[0].localeCompare(a[0]))

  return (
    <ModalSheet
      label="Note"
      onClose={onClose}
      header={
        <ModalHeader
          title={history ? "Past notes" : "Note"}
          left={
            <IconButton
              icon="history"
              label={history ? "Back to note" : "Past notes"}
              variant="glass-strong"
              aria-pressed={history}
              onClick={() => setHistory(!history)}
            />
          }
          right={
            history ? (
              <IconButton icon="close" label="Close" variant="glass-strong" onClick={onClose} />
            ) : (
              <button
                type="button"
                className="note-save"
                aria-label={filled.length ? "Save and read this note" : "Close"}
                onClick={() => (filled.length ? onSave(date, filled) : onClose())}
              >
                <Icon name="check-circle" size={20} />
              </button>
            )
          }
        />
      }
    >
      {history ? (
        <div className="history">
          {past.length === 0 && <p className="t-body-14-r history__none">Notes you write will show up here.</p>}
          {past.map(([d, n]) => (
            <button
              key={d}
              type="button"
              className="history__item"
              onClick={() => {
                setDate(d)
                setLines([...n.lines.filter((l) => l.trim()), ""])
                setHistory(false)
              }}
            >
              <span className="t-body-14-m history__text">{n.lines.filter((l) => l.trim()).join(" · ")}</span>
              <span className="t-capture-12-r history__meta">
                {shortDate(d)} · {n.lines.filter((l) => l.trim()).length} lines
              </span>
            </button>
          ))}
        </div>
      ) : (
        <div className="note-editor">
          <h3 className="note-editor__lead">
            This is your space —<br />
            jot down whatever, whenever.
          </h3>
          <div>
            <button
              type="button"
              className="composer__day"
              onClick={() => {
                const el = picker.current
                if (el && typeof el.showPicker === "function") el.showPicker()
                else el?.click()
              }}
              aria-label={`Note for ${longDate(date)}. Change day`}
            >
              <span>{longDate(date)}</span>
              <Icon name="caret-down" size={16} />
            </button>
            <input
              ref={picker}
              className="visually-hidden"
              type="date"
              value={date}
              max={today()}
              tabIndex={-1}
              aria-hidden="true"
              onChange={(e) => {
                if (!e.target.value) return
                setDate(e.target.value)
                const saved = notes[e.target.value]?.lines.filter((l) => l.trim())
                setLines(saved?.length ? [...saved, ""] : [""])
              }}
            />
          </div>
          <h4 className="note-editor__label">What you spent {date === today() ? "today" : `on ${shortDate(date)}`}</h4>
          <ol className="note-editor__list">
            {lines.map((l, i) => (
              <li key={i} className={focus === i ? "is-focus" : ""}>
                <span className="note-editor__n">{i + 1}.</span>
                <input
                  ref={(el) => {
                    inputs.current[i] = el
                  }}
                  value={l}
                  autoFocus={i === lines.length - 1}
                  placeholder={i === 0 ? "e.g. coffee 24k, breakfast 35k…" : ""}
                  aria-label={`Line ${i + 1}`}
                  onFocus={() => setFocus(i)}
                  onChange={(e) => setLines((ls) => ls.map((x, k) => (k === i ? e.target.value : x)))}
                  onKeyDown={(e) => onKey(e, i)}
                />
                {focus === i && l && (
                  <button
                    type="button"
                    className="note-editor__clear"
                    aria-label={`Clear line ${i + 1}`}
                    onMouseDown={(e) => e.preventDefault()}
                    onClick={() => setLines((ls) => ls.map((x, k) => (k === i ? "" : x)))}
                  >
                    <Icon name="close" size={10} />
                  </button>
                )}
              </li>
            ))}
          </ol>
          <p className="t-capture-12-r note-editor__hint">
            Enter adds a line. Tap ✓ when you're done — the Assistant reads it and you confirm before anything is saved.
          </p>
        </div>
      )}
    </ModalSheet>
  )
}
