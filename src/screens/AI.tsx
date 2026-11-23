import { useMemo } from "react"
import { IconButton, LogoMark } from "../components/ui"
import { Icon } from "../components/Icon"
import StickyHeader from "../components/StickyHeader"
import { greeting, shortDate } from "../lib/format"
import { SHORTCUTS, SUGGESTIONS } from "../lib/answers"
import type { Entry } from "../lib/store"
import type { AssistantOpen } from "./Assistant"
import "./ai.css"

/**
 * AI tab — iOS AIHome: shortcuts, suggested questions, recent notes, and a composer at the foot that
 * opens the chat. Answers about spending are worked out on the phone from the user's own lines.
 */
export default function AI({
  name,
  entries,
  onOpen,
  onOpenDay,
  onProfile,
}: {
  name: string
  entries: Entry[]
  onOpen: (opts: AssistantOpen) => void
  onOpenDay: (day: string) => void
  onProfile: () => void
}) {
  const recents = useMemo(() => {
    const seen = new Map<string, Entry>()
    for (const e of [...entries].sort((a, b) => b.createdAt - a.createdAt)) if (!seen.has(e.noteId)) seen.set(e.noteId, e)
    return [...seen.values()].slice(0, 5)
  }, [entries])

  return (
    <div className="screen ai">
      <StickyHeader
        title="AI"
        left={<h1 className="ai__title">AI</h1>}
        right={<IconButton icon="user" label="Profile" variant="glass" size={44} iconSize={24} style={{ color: "var(--brand-600)" }} onClick={onProfile} />}
      />

      <div className="ai__body">
        <div className="ai__hello">
          <LogoMark size={48} />
          <h2>
            {greeting()}, {name}
          </h2>
          <p>Write what you spent, or ask about it.</p>
        </div>

        <section aria-label="Shortcuts">
          <h3 className="ai__label">Shortcuts</h3>
          <div className="ai__shortcuts">
            <button type="button" className="ai__shortcut is-main" onClick={() => onOpen({})}>
              <Icon name="ai" size={22} />
              <span>Talk With AI</span>
            </button>
            {SHORTCUTS.map((s) => (
              <button key={s.label} type="button" className="ai__shortcut" onClick={() => onOpen({ ask: { q: s.ask, report: s.report } })}>
                <Icon name={s.report === "week" ? "calendar-blank" : "trend-up"} size={22} />
                <span>{s.label}</span>
              </button>
            ))}
          </div>
        </section>

        <section aria-label="Suggestions">
          <h3 className="ai__label">Suggestions</h3>
          <div className="ai__chips">
            {SUGGESTIONS.map((s) => (
              <button key={s.label} type="button" className="ai__chip" onClick={() => onOpen({ ask: { q: s.label, report: s.report } })}>
                {s.label}
              </button>
            ))}
          </div>
        </section>

        <section aria-label="Recents">
          <h3 className="ai__label">Recents</h3>
          {recents.length === 0 ? (
            <p className="ai__none">Notes you write show up here.</p>
          ) : (
            <ul className="ai__recents">
              {recents.map((e) => (
                <li key={e.noteId}>
                  <button type="button" className="ai__recent" onClick={() => onOpenDay(e.date)}>
                    <span className="ai__recent-text">{e.source || e.title}</span>
                    <span className="ai__recent-meta">{shortDate(e.date)}</span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>

      <div className="ai__composer">
        <button type="button" className="ai__field" onClick={() => onOpen({})}>
          Ask anything or write a note…
        </button>
        <IconButton icon="mic" label="Say it" variant="dark" iconSize={20} onClick={() => onOpen({ voice: true })} />
      </div>
    </div>
  )
}
