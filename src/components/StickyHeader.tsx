import { useEffect, useState, type ReactNode } from "react"
import "./sticky-header.css"
import "./pblur.css"
import ProgressiveBlur from "./ProgressiveBlur"

/** True once the page has scrolled past `threshold` px (rAF-throttled). */
export function useScrolled(threshold = 56) {
  const [scrolled, setScrolled] = useState(() => window.scrollY > threshold)
  useEffect(() => {
    let frame = 0
    const onScroll = () => {
      cancelAnimationFrame(frame)
      frame = requestAnimationFrame(() => setScrolled(window.scrollY > threshold))
    }
    onScroll()
    window.addEventListener("scroll", onScroll, { passive: true })
    return () => {
      cancelAnimationFrame(frame)
      window.removeEventListener("scroll", onScroll)
    }
  }, [threshold])
  return scrolled
}

/**
 * iOS-style navigation bar: at the top it is clear and the page's large title sits below it.
 * Once you scroll, it sticks, turns to frosted glass with a hairline shadow, and the large title
 * collapses into a small centred one. Tapping that small title scrolls back to the top.
 */
export default function StickyHeader({
  left,
  center,
  right,
  title,
}: {
  left?: ReactNode
  /** Shown while at the top (e.g. the day pill). Replaced by `title` once scrolled. */
  center?: ReactNode
  right?: ReactNode
  /** Small title shown in the bar after scrolling. */
  title: string
}) {
  const scrolled = useScrolled()
  return (
    <header className={`nav-bar${scrolled ? " is-scrolled" : ""}`}>
      <ProgressiveBlur edge="top" visible={scrolled} />
      <div className="nav-bar__side">{left}</div>
      <div className="nav-bar__center">
        {center && (
          <div className="nav-bar__swap nav-bar__swap--top" aria-hidden={scrolled} inert={scrolled}>
            {center}
          </div>
        )}
        <button
          type="button"
          className="nav-bar__swap nav-bar__title lg lg-press"
          aria-hidden={!scrolled}
          tabIndex={scrolled ? 0 : -1}
          onClick={() => window.scrollTo({ top: 0, behavior: "smooth" })}
          title="Back to top"
        >
          {title}
        </button>
      </div>
      <div className="nav-bar__side nav-bar__side--right">{right}</div>
    </header>
  )
}
