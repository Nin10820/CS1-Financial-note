import { useEffect, useLayoutEffect, useRef, useState, type PointerEvent } from "react"
import "./tabbar.css"
import { Icon } from "./Icon"

/** "expense" is the Today tab (its key predates the rename). */
export type Tab = "expense" | "due" | "scan" | "finance" | "profile"

const TABS: { tab: Tab; label: string }[] = [
  { tab: "expense", label: "Today" },
  { tab: "due", label: "Due" },
  { tab: "scan", label: "Scan" },
  { tab: "finance", label: "Finance" },
  { tab: "profile", label: "Profile" },
]

/* Each screen mounts its own bar; remembering where the selection was lets the new bar
   start there and slide to the new tab, so switching tabs feels like one continuous control. */
let lastIndex = 0

/* Tab icons from Figma Navigation Bar Ver 2: calendar-01, bill, scan, chart-rose, user (solid). */
function TabIcon({ tab, size }: { tab: Tab; size: number }) {
  return <Icon name={`tab-${tab}`} size={size} />
}

/** The five tabs with a glass selection "lens" that springs between tabs and can be dragged. */
function Tabs({ active, onTab }: { active: Tab; onTab: (t: Tab) => void }) {
  const activeIndex = TABS.findIndex((t) => t.tab === active)
  // Start where the previous screen's bar was, then slide to this screen's tab.
  const [shown, setShown] = useState(lastIndex)
  const [pressing, setPressing] = useState(false)
  const nav = useRef<HTMLElement>(null)
  const drag = useRef<{ id: number; start: number; moved: boolean } | null>(null)

  useLayoutEffect(() => {
    if (shown === activeIndex) return
    const frame = requestAnimationFrame(() => setShown(activeIndex))
    return () => cancelAnimationFrame(frame)
  }, [activeIndex])
  useEffect(() => {
    lastIndex = activeIndex
  }, [activeIndex])

  const indexAt = (x: number) => {
    const r = nav.current!.getBoundingClientRect()
    const inner = r.width - 24 // 12px padding each side
    return Math.max(0, Math.min(TABS.length - 1, Math.floor(((x - r.left - 12) / inner) * TABS.length)))
  }
  const onDown = (e: PointerEvent<HTMLElement>) => {
    if (e.button !== 0) return
    drag.current = { id: e.pointerId, start: indexAt(e.clientX), moved: false }
    setPressing(true)
    setShown(indexAt(e.clientX))
    e.currentTarget.setPointerCapture(e.pointerId)
  }
  const onMove = (e: PointerEvent<HTMLElement>) => {
    const d = drag.current
    if (!d || d.id !== e.pointerId) return
    const i = indexAt(e.clientX)
    if (i !== d.start) d.moved = true
    setShown(i)
  }
  const onUp = (e: PointerEvent<HTMLElement>) => {
    const d = drag.current
    if (!d || d.id !== e.pointerId) return
    drag.current = null
    setPressing(false)
    const i = indexAt(e.clientX)
    if (e.type === "pointercancel") setShown(activeIndex)
    else {
      setShown(i)
      // Tapping the tab you're on goes back to its first screen, like iOS.
      onTab(TABS[i].tab)
    }
  }

  return (
    <nav
      ref={nav}
      className={`tabbar__tabs lg${pressing ? " is-pressing" : ""}`}
      aria-label="Main"
      onPointerDown={onDown}
      onPointerMove={onMove}
      onPointerUp={onUp}
      onPointerCancel={onUp}
    >
      <span className="tabbar__lens lg-rim" aria-hidden="true" style={{ ["--i" as string]: shown }} />
      {TABS.map(({ tab, label }, i) => (
        <button
          key={tab}
          type="button"
          className={`tabbar__tab${i === shown ? " is-lit" : ""}${tab === active ? " is-active" : ""}`}
          aria-current={tab === active ? "page" : undefined}
          onClick={(e) => {
            // Keyboard / assistive-tech activation (pointer taps are handled on release).
            if (e.detail === 0) onTab(tab)
          }}
        >
          <TabIcon tab={tab} size={24} />
          <span>{label}</span>
        </button>
      ))}
    </nav>
  )
}

/**
 * Bottom navigation — Figma Navigation Bar, Ver 2 (961:31747): the round green write button
 * floats above the right end, and the five tabs sit in one glass capsule underneath.
 */
export default function TabBar({
  active,
  onTab,
  onQuickNote,
  action,
}: {
  active: Tab
  onTab: (t: Tab) => void
  /** What the green button does when the screen gives no action of its own. */
  onQuickNote: () => void
  /** Screen-specific green button (e.g. the Note screen's "New" menu). */
  action?: { label: string; onClick: () => void; expanded?: boolean }
}) {
  return (
    <div className="tabbar">
      <button
        type="button"
        className="tabbar__write lg-press"
        aria-label={action?.label ?? "Write a note"}
        aria-expanded={action?.expanded}
        aria-haspopup={action?.expanded === undefined ? undefined : "menu"}
        onClick={action?.onClick ?? onQuickNote}
      >
        <Icon name="file-edit" size={24} />
      </button>
      <Tabs active={active} onTab={onTab} />
    </div>
  )
}
