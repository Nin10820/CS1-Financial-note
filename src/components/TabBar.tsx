import { useEffect, useLayoutEffect, useRef, useState, type PointerEvent } from "react"
import "./tabbar.css"
import { Icon } from "./Icon"
import { LogoMark } from "./ui"

export type Tab = "expense" | "due" | "finance" | "profile"

const TABS: { tab: Tab; label: string }[] = [
  { tab: "expense", label: "Expense" },
  { tab: "due", label: "Due" },
  { tab: "finance", label: "Finance" },
  { tab: "profile", label: "Profile" },
]

/* Each screen mounts its own bar; remembering where the selection was lets the new bar
   start there and slide to the new tab, so switching tabs feels like one continuous control. */
let lastIndex = 0
let lastCollapsed = false

/* Tab icons from Figma Navigation Bar: calendar-01, bill, chart-rose, user (solid). */
function TabIcon({ tab, size }: { tab: Tab; size: number }) {
  return <Icon name={`tab-${tab}`} size={size} />
}

/** Collapses on scroll down and comes back on scroll up or near the top, like iOS 26 tab bars. */
function useCollapsed() {
  const [collapsed, setCollapsedState] = useState(() => lastCollapsed && window.scrollY > 24)
  const setCollapsed = (v: boolean) => {
    lastCollapsed = v
    setCollapsedState(v)
  }
  const last = useRef(0)
  useEffect(() => {
    last.current = window.scrollY
    const onScroll = () => {
      const y = window.scrollY
      const dy = y - last.current
      if (y < 24) setCollapsed(false)
      else if (dy > 6) setCollapsed(true)
      else if (dy < -10) setCollapsed(false)
      if (Math.abs(dy) > 6) last.current = y
    }
    window.addEventListener("scroll", onScroll, { passive: true })
    return () => window.removeEventListener("scroll", onScroll)
  }, [])
  return [collapsed, setCollapsed] as const
}

/** The four tabs with a glass selection "lens" that springs between tabs and can be dragged. */
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
    return Math.max(0, Math.min(TABS.length - 1, Math.floor(((x - r.left) / r.width) * TABS.length)))
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
    // A plain tap is handled by the button's click; a drag selects where the finger lifts.
    if (e.type === "pointercancel") setShown(activeIndex)
    else if (d.moved || i !== activeIndex) {
      setShown(i)
      if (TABS[i].tab !== active) onTab(TABS[i].tab)
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
            if (e.detail === 0 && tab !== active) onTab(tab)
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
 * Bottom navigation, styled after the iOS 26/27 system tab bar (as in the Claude and Music apps).
 * Expanded (default): quick-note field on its own row, the four tabs underneath.
 * Collapsed (after scrolling down): active tab · quick note · screen action.
 * Sizes and glass follow Figma "Navigation Bar" (949:30623), Expand=Yes / Expand=No.
 */
export default function TabBar({
  active,
  onTab,
  onQuickNote,
  action,
}: {
  active: Tab
  onTab: (t: Tab) => void
  onQuickNote: () => void
  /** Right-hand round button (e.g. the Note screen's "New" menu). */
  action?: { label: string; onClick: () => void; expanded?: boolean }
}) {
  const [collapsed, setCollapsed] = useCollapsed()
  const activeLabel = TABS.find((t) => t.tab === active)!.label
  const actionButton = action && (
    <button
      type="button"
      className="lg lg--tint lg-round lg-press tabbar__action"
      aria-label={action.label}
      aria-expanded={action.expanded}
      aria-haspopup={action.expanded === undefined ? undefined : "menu"}
      onClick={action.onClick}
    >
      <Icon name="file-edit" size={24} />
    </button>
  )

  return (
    <div className={`tabbar${collapsed ? " is-collapsed" : ""}`}>
      {/* Expanded */}
      <div className="tabbar__full" aria-hidden={collapsed} inert={collapsed}>
        <div className="tabbar__row">
          <button type="button" className="lg lg--quiet tabbar__note" onClick={onQuickNote}>
            <span className="tabbar__note-logo">
              <LogoMark size={20} />
            </span>
            <span className="tabbar__note-text">e.g. coffee 24k, breakfast 35k…</span>
          </button>
          {actionButton}
        </div>
        <Tabs active={active} onTab={onTab} />
      </div>

      {/* Collapsed — the Figma Final Bottom-bar, in the same glass */}
      <div className="tabbar__mini" aria-hidden={!collapsed} inert={!collapsed}>
        <button
          type="button"
          className="lg lg-round lg-press tabbar__mini-tab"
          aria-label={`${activeLabel} — show all tabs`}
          onClick={() => setCollapsed(false)}
        >
          <TabIcon tab={active} size={24} />
        </button>
        <button type="button" className="lg lg--quiet tabbar__note" onClick={onQuickNote}>
          <span className="tabbar__note-logo">
            <LogoMark size={20} />
          </span>
          <span className="tabbar__note-text">e.g. coffee 24k, breakfast 35k…</span>
        </button>
        {actionButton}
      </div>
    </div>
  )
}
