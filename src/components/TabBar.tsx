import { useEffect, useRef, useState } from "react"
import "./tabbar.css"
import { ChartPieSlice, Receipt, User } from "@phosphor-icons/react"
import { Icon } from "./Icon"
import { IconButton, LogoMark } from "./ui"

export type Tab = "expense" | "due" | "finance" | "profile"

const TABS: { tab: Tab; label: string }[] = [
  { tab: "expense", label: "Expense" },
  { tab: "due", label: "Due" },
  { tab: "finance", label: "Finance" },
  { tab: "profile", label: "Profile" },
]

/* Expense uses the filled wallet from the Figma file; Due / Finance / Profile use Phosphor,
   the icon library the Figma file is built with (the tab bar itself isn't in the file yet). */
function TabIcon({ tab, size }: { tab: Tab; size: number }) {
  if (tab === "expense") return <Icon name="wallet" size={size} />
  if (tab === "due") return <Receipt size={size} weight="fill" aria-hidden="true" />
  if (tab === "finance") return <ChartPieSlice size={size} weight="fill" aria-hidden="true" />
  return <User size={size} weight="fill" aria-hidden="true" />
}

/** Collapses on scroll down and comes back on scroll up or near the top, like iOS 26 tab bars. */
function useCollapsed() {
  const [collapsed, setCollapsed] = useState(false)
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

/**
 * Bottom navigation.
 * Expanded (default): the quick-note field on its own row, the four tabs underneath.
 * Collapsed (after scrolling down): the Figma "Bottom-bar" — active tab · quick note · extra action.
 */
export default function TabBar({
  active,
  onTab,
  onQuickNote,
  onVoice,
  action,
}: {
  active: Tab
  onTab: (t: Tab) => void
  onQuickNote: () => void
  onVoice?: () => void
  /** Right-hand button of the collapsed bar (e.g. the Note screen's "New" menu). */
  action?: { label: string; onClick: () => void; expanded?: boolean }
}) {
  const [collapsed, setCollapsed] = useCollapsed()
  const activeLabel = TABS.find((t) => t.tab === active)!.label

  return (
    <div className={`tabbar${collapsed ? " is-collapsed" : ""}`}>
      {/* Expanded */}
      <div className="tabbar__full" aria-hidden={collapsed} inert={collapsed}>
        <div className="tabbar__row">
          <button type="button" className="tabbar__note" onClick={onQuickNote}>
            <span className="tabbar__note-logo">
              <LogoMark size={26} />
            </span>
            <span className="tabbar__note-text">e.g. coffee 24k, breakfast 35k…</span>
          </button>
          {action && (
            <IconButton
              icon="file-edit"
              label={action.label}
              variant="white"
              size={48}
              onClick={action.onClick}
              aria-expanded={action.expanded}
              aria-haspopup={action.expanded === undefined ? undefined : "menu"}
            />
          )}
        </div>
        <nav className="tabbar__tabs" aria-label="Main">
          {TABS.map(({ tab, label }) => (
            <button
              key={tab}
              type="button"
              className={`tabbar__tab${tab === active ? " is-active" : ""}`}
              aria-current={tab === active ? "page" : undefined}
              onClick={() => onTab(tab)}
            >
              <TabIcon tab={tab} size={26} />
              <span>{label}</span>
            </button>
          ))}
        </nav>
      </div>

      {/* Collapsed — the Figma Final Bottom-bar */}
      <div className="tabbar__mini fn-bottom-bar" aria-hidden={!collapsed} inert={!collapsed}>
        <button
          type="button"
          className="fn-icon-btn fn-icon-btn--glass-80 tabbar__mini-tab"
          style={{ width: 48, height: 48 }}
          aria-label={`${activeLabel} — show all tabs`}
          onClick={() => setCollapsed(false)}
        >
          <TabIcon tab={active} size={24} />
        </button>
        <div className="fn-quick-note">
          <button type="button" className="fn-quick-note__open" onClick={onQuickNote}>
            <span className="fn-quick-note__logo">
              <LogoMark size={24} />
            </span>
            <span className="t-body-14-r fn-quick-note__placeholder">e.g. coffee 24k, breakfast 35k…</span>
          </button>
          <IconButton icon="waveform" label="Voice note" variant="plain" size={40} iconSize={24} onClick={onVoice ?? onQuickNote} />
        </div>
        {action && (
          <IconButton
            icon="file-edit"
            label={action.label}
            variant="white"
            size={48}
            onClick={action.onClick}
            aria-expanded={action.expanded}
            aria-haspopup={action.expanded === undefined ? undefined : "menu"}
          />
        )}
      </div>
    </div>
  )
}
