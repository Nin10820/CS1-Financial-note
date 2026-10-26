import { useEffect, useMemo, useRef, useState, type KeyboardEvent } from "react"
import { Icon } from "../components/Icon"
import { Amount } from "../components/ui"
import { longDate, money } from "../lib/format"
import { parseNote, type Draft } from "../lib/parse"
import { categoryTone, uid, type Entry } from "../lib/store"
import DayPicker from "./DayPicker"
import "./quick-note.css"

const DEFAULT_CHIPS = ["đậu hũ 15k", "thịt xay 50k"]

/**
 * Quick note — Figma High Fi 2 › Quick-note (943:24983, 943:25079) and Frame 85 (944:30328).
 * A card that floats just above the keyboard: "## n Submit your note expense", the day, the note,
 * two quick chips and send. Sending turns it into "Here's what I got"; the green check saves.
 * "Not quite?" hands the note to the full assistant to fix.
 */
export default function QuickNote({
  day,
  entries,
  onClose,
  onSave,
  onFix,
}: {
  day: string
  entries: Entry[]
  onClose: () => void
  /** Saves the entries; `date` is the day they landed on. */
  onSave: (list: Entry[], date: string) => void
  /** Opens the full assistant on this note so a line can be corrected. */
  onFix: (text: string, date: string) => void
}) {
  const [date, setDate] = useState(day)
  const [text, setText] = useState("")
  const [drafts, setDrafts] = useState<Draft[] | null>(null)
  const [picking, setPicking] = useState(false)
  const [lift, setLift] = useState(0)
  const input = useRef<HTMLTextAreaElement>(null)

  // Which note of the day this is: "## 3" when two were already written.
  const number = useMemo(() => new Set(entries.filter((e) => e.date === date).map((e) => e.noteId)).size + 1, [entries, date])

  // The user's own recent lines first, so the common ones are one tap away.
  const chips = useMemo(() => {
    const seen = new Set<string>()
    for (const e of [...entries].sort((a, b) => b.createdAt - a.createdAt)) {
      if (e.flow === "out") seen.add(`${e.title.toLocaleLowerCase("vi")} ${Math.round(e.amount / 1000)}k`)
      if (seen.size === 2) break
    }
    return seen.size === 2 ? [...seen] : DEFAULT_CHIPS
  }, [entries])

  useEffect(() => {
    input.current?.focus({ preventScroll: true })
    const prev = document.body.style.overflow
    document.body.style.overflow = "hidden"
    const onKey = (e: globalThis.KeyboardEvent) => e.key === "Escape" && !document.querySelector(".modal") && onClose()
    document.addEventListener("keydown", onKey)
    // Keep the card above the on-screen keyboard (iOS shrinks the visual viewport, not the layout).
    const vv = window.visualViewport
    const onResize = () => vv && setLift(Math.max(0, window.innerHeight - vv.height - vv.offsetTop))
    vv?.addEventListener("resize", onResize)
    vv?.addEventListener("scroll", onResize)
    return () => {
      document.body.style.overflow = prev
      document.removeEventListener("keydown", onKey)
      vv?.removeEventListener("resize", onResize)
      vv?.removeEventListener("scroll", onResize)
    }
  }, [onClose])

  const send = () => {
    const note = text.trim()
    if (note) setDrafts(parseNote(note, date))
  }
  const onKeyDown = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    // Vietnamese IMEs hold Enter while composing — never send mid-word.
    if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing) {
      e.preventDefault()
      send()
    }
  }
  const addChip = (chip: string) => {
    setText((t) => (t.trim() ? `${t.trim().replace(/,$/, "")}, ${chip}` : chip))
    input.current?.focus({ preventScroll: true })
  }

  const missing = drafts?.some((d) => d.amount === null) ?? false
  const confirm = () => {
    if (!drafts?.length || missing) return
    const noteId = uid()
    const now = Date.now()
    onSave(
      drafts.map((d, i) => ({
        id: uid(),
        date: d.date,
        title: d.title,
        amount: d.amount ?? 0,
        flow: d.flow,
        category: d.category,
        noteId,
        source: text.trim(),
        createdAt: now + i,
      })),
      drafts[0].date,
    )
  }
  const fix = () => onFix(text.trim(), date)

  return (
    <div className="quick-layer" role="dialog" aria-modal="true" aria-label="Quick note">
      <div className="quick-scrim" onClick={onClose} aria-hidden="true" />
      <div className="quick" style={{ bottom: `calc(${lift}px + var(--sp-12) + env(safe-area-inset-bottom))` }}>
        {drafts === null ? (
          <form
            className="quick-card"
            onSubmit={(e) => {
              e.preventDefault()
              send()
            }}
          >
            <div className="quick-card__head">
              <span className="quick-card__num">## {number}</span>
              <span className="quick-card__title">Submit your note expense</span>
              <button type="button" className="quick-card__day" onClick={() => setPicking(true)} aria-label={`For ${longDate(date)}. Change day`}>
                {longDate(date)}
              </button>
            </div>
            <textarea
              ref={input}
              className="quick-card__input"
              rows={2}
              value={text}
              placeholder="e.g. coffee 24k, breakfast 35k…"
              aria-label="Write what you spent"
              onChange={(e) => setText(e.target.value)}
              onKeyDown={onKeyDown}
            />
            <div className="quick-card__foot">
              {chips.map((c) => (
                <button key={c} type="button" className="quick-card__chip" onClick={() => addChip(c)}>
                  {c}
                </button>
              ))}
              <button type="submit" className="quick-card__send" aria-label="Send" disabled={!text.trim()}>
                <Icon name="send-up" size={18} />
              </button>
            </div>
          </form>
        ) : (
          <section className="quick-card quick-card--result" aria-label="Here's what I got">
            <div className="quick-result__head">
              <div>
                <p className="quick-result__count">
                  {drafts.length} {drafts.length === 1 ? "item" : "items"}
                </p>
                <h2 className="quick-result__title">{drafts.length ? "Here's what I got" : "I couldn't find an amount"}</h2>
              </div>
              <button type="button" className="quick-result__ok" aria-label="Save" disabled={!drafts.length || missing} onClick={confirm}>
                <Icon name="check" size={20} />
              </button>
            </div>
            <ol className="quick-result__rows">
              {drafts.map((d, i) => (
                <li key={d.key}>
                  <button type="button" className="quick-result__row" onClick={fix}>
                    <span className="quick-result__num">{i + 1}</span>
                    <span className="quick-result__text">
                      <span className="quick-result__name">{d.title}</span>
                      <span className={`quick-result__cat fn-trans__cat is-${categoryTone(d.category)}`}>{d.category}</span>
                    </span>
                    {d.amount === null ? (
                      <span className="quick-result__missing">Add amount</span>
                    ) : (
                      <Amount value={money(d.amount)} sign={d.flow === "out" ? "-" : undefined} />
                    )}
                  </button>
                </li>
              ))}
            </ol>
            <div className="quick-result__foot">
              <button type="button" className="quick-result__fix" aria-label="Fix in the assistant" onClick={fix}>
                <Icon name="edit" size={20} />
              </button>
              <span>{missing ? "One line has no amount. Tap it to fix" : "Not quite? Tap a row to fix"}</span>
            </div>
          </section>
        )}
      </div>
      {picking && <DayPicker value={date} marked={new Set(entries.map((e) => e.date))} onPick={setDate} onClose={() => setPicking(false)} />}
    </div>
  )
}
