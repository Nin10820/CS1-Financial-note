import { useRef, type PointerEvent } from "react"

/**
 * A clear sideways swipe across the page calls `onStep(+1)` (to the left: next) or `onStep(-1)`.
 * Strips, rows and fields that slide on their own opt out with `data-no-page-swipe`.
 */
export function usePageSwipe(onStep: (n: 1 | -1) => void) {
  const start = useRef<{ x: number; y: number; id: number } | null>(null)
  return {
    onPointerDown: (e: PointerEvent) => {
      if ((e.target as Element).closest("[data-no-page-swipe], input, textarea, select")) return
      start.current = { x: e.clientX, y: e.clientY, id: e.pointerId }
    },
    onPointerUp: (e: PointerEvent) => {
      const s = start.current
      start.current = null
      if (!s || s.id !== e.pointerId) return
      const dx = e.clientX - s.x
      const dy = e.clientY - s.y
      if (Math.abs(dx) > 70 && Math.abs(dx) > Math.abs(dy) * 1.6) onStep(dx < 0 ? 1 : -1)
    },
  }
}
