import { useEffect, useLayoutEffect, useRef, useState, type PointerEvent } from "react"
import "./tabbar.css"
import { Icon } from "./Icon"

/** "expense" is the Today tab (its key predates the rename). */
export type Tab = "expense" | "due" | "finance" | "ai"

const TABS: { tab: Tab; label: string }[] = [
  { tab: "expense", label: "Today" },
  { tab: "due", label: "Due" },
  { tab: "finance", label: "Finance" },
  { tab: "ai", label: "AI" },
]

/* Remembering where the selection was lets a remounted bar slide from there. */
let lastIndex = 0

function TabIcon({ tab, size }: { tab: Tab; size: number }) {
  if (tab === "ai") return <Icon name="ai" size={size} />
  return <Icon name={`tab-${tab}`} size={size} />
}

/** The four tabs in one capsule with a lens that slides to the picked tab and can be dragged. */
function Tabs({ active, onTab }: { active: Tab; onTab: (t: Tab) => void }) {
  const activeIndex = TABS.findIndex((t) => t.tab === active)
  const [shown, setShown] = useState(lastIndex)
  const [pressing, setPressing] = useState(false)
  const nav = useRef<HTMLElement>(null)
  const drag = useRef<{ id: number } | null>(null)

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
    const inner = r.width - 8
    return Math.max(0, Math.min(TABS.length - 1, Math.floor(((x - r.left - 4) / inner) * TABS.length)))
  }
  const onDown = (e: PointerEvent<HTMLElement>) => {
    if (e.button !== 0) return
    drag.current = { id: e.pointerId }
    setPressing(true)
    setShown(indexAt(e.clientX))
    try {
      e.currentTarget.setPointerCapture(e.pointerId)
    } catch {
      /* the pointer is already gone */
    }
  }
  const onMove = (e: PointerEvent<HTMLElement>) => {
    if (drag.current?.id !== e.pointerId) return
    setShown(indexAt(e.clientX))
  }
  const onUp = (e: PointerEvent<HTMLElement>) => {
    if (drag.current?.id !== e.pointerId) return
    drag.current = null
    setPressing(false)
    if (e.type === "pointercancel") return setShown(activeIndex)
    const i = indexAt(e.clientX)
    setShown(i)
    onTab(TABS[i].tab)
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
      <span className="tabbar__lens" aria-hidden="true" style={{ ["--i" as string]: shown }} />
      {TABS.map(({ tab, label }, i) => (
        <button
          key={tab}
          type="button"
          className={`tabbar__tab${i === shown ? " is-lit" : ""}`}
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
 * Navigation Bar (Figma 2026-10-30, as built in the iOS app): Today, Due, Finance, AI in one
 * capsule and the round green + beside it. On Due the + adds a bill, on Finance an asset; on Today
 * and AI it opens the menu (Talk With AI, Template, Scan) and turns into ×.
 */
export default function TabBar({
  active,
  onTab,
  onPlus,
  plusLabel,
  menuOpen,
}: {
  active: Tab
  onTab: (t: Tab) => void
  onPlus: () => void
  plusLabel: string
  menuOpen: boolean
}) {
  return (
    <div className="tabbar">
      <Tabs active={active} onTab={onTab} />
      <button
        type="button"
        className={`tabbar__plus${menuOpen ? " is-open" : ""}`}
        aria-label={menuOpen ? "Close menu" : plusLabel}
        aria-expanded={active === "due" || active === "finance" ? undefined : menuOpen}
        onClick={onPlus}
      >
        <Icon name="plus" size={24} />
      </button>
    </div>
  )
}

/** The three pills above the + (Figma Today 1073:18526); they grow out of the button. */
export function ActionMenu({
  onClose,
  onTalk,
  onTemplate,
  onScan,
}: {
  onClose: () => void
  onTalk: () => void
  onTemplate: () => void
  onScan: () => void
}) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose()
    document.addEventListener("keydown", onKey)
    return () => document.removeEventListener("keydown", onKey)
  }, [onClose])
  return (
    <div className="action-menu">
      <div className="action-menu__dim" onClick={onClose} aria-hidden="true" />
      <div className="action-menu__pills" role="menu" aria-label="Add">
        <button type="button" role="menuitem" className="action-pill" onClick={onTalk}>
          <Icon name="mic" size={20} />
          Talk With AI
        </button>
        <button type="button" role="menuitem" className="action-pill" onClick={onTemplate}>
          <Icon name="template" size={20} />
          Template
        </button>
        <button type="button" role="menuitem" className="action-pill" onClick={onScan}>
          <Icon name="tab-scan" size={20} />
          Scan
        </button>
      </div>
    </div>
  )
}
