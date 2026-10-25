import { useEffect, useRef, type PointerEvent, type ReactNode } from "react"

const CLOSE_DISTANCE = 120 // px dragged before letting go closes the sheet
const FLICK_SPEED = 0.5 // px/ms — a quick flick closes it even when short

/** Figma "Modal": bg-1 sheet with 20px top corners and a grab handle, over a 48% dark scrim.
    Escape, a tap on the scrim, or dragging the handle down closes it; focus moves into the sheet
    and back when it closes. */
export default function ModalSheet({
  label,
  onClose,
  header,
  children,
  footer,
  size = "tall",
}: {
  label: string
  onClose: () => void
  header?: ReactNode
  children: ReactNode
  footer?: ReactNode
  size?: "tall" | "auto"
}) {
  const ref = useRef<HTMLDivElement>(null)
  const scrim = useRef<HTMLDivElement>(null)
  const drag = useRef<{ y: number; t: number; dy: number; id: number } | null>(null)
  const closing = useRef(false)

  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null
    ref.current?.focus()
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose()
    document.addEventListener("keydown", onKey)
    const overflow = document.body.style.overflow
    document.body.style.overflow = "hidden"
    return () => {
      document.removeEventListener("keydown", onKey)
      document.body.style.overflow = overflow
      previous?.focus?.()
    }
  }, [onClose])

  const reduced = () => window.matchMedia("(prefers-reduced-motion: reduce)").matches

  const setOffset = (dy: number, transition?: string) => {
    const sheet = ref.current
    if (!sheet) return
    sheet.style.transition = transition ?? "none"
    sheet.style.transform = `translate(-50%, ${dy}px)`
    if (scrim.current) {
      scrim.current.style.transition = transition ? "opacity 0.25s ease" : "none"
      scrim.current.style.opacity = String(Math.max(0.35, 1 - dy / 500))
    }
  }

  const close = () => {
    if (closing.current) return
    closing.current = true
    if (reduced() || !ref.current) return onClose()
    const h = ref.current.getBoundingClientRect().height
    setOffset(h, "transform 0.22s cubic-bezier(0.4, 0, 1, 1)")
    if (scrim.current) scrim.current.style.opacity = "0"
    window.setTimeout(onClose, 200)
  }

  const onDown = (e: PointerEvent<HTMLDivElement>) => {
    // Buttons and fields in the header keep working; only the bare handle area drags.
    if ((e.target as Element).closest("button, input, select, textarea, a")) return
    if (e.button !== 0) return
    drag.current = { y: e.clientY, t: performance.now(), dy: 0, id: e.pointerId }
    e.currentTarget.setPointerCapture(e.pointerId)
  }
  const onMove = (e: PointerEvent<HTMLDivElement>) => {
    const d = drag.current
    if (!d || d.id !== e.pointerId) return
    const raw = e.clientY - d.y
    // Downward follows the finger; upward resists, like iOS sheets.
    d.dy = raw > 0 ? raw : raw / 6
    setOffset(d.dy)
  }
  const onUp = (e: PointerEvent<HTMLDivElement>) => {
    const d = drag.current
    if (!d || d.id !== e.pointerId) return
    drag.current = null
    const speed = d.dy / Math.max(1, performance.now() - d.t)
    if (d.dy > CLOSE_DISTANCE || (d.dy > 30 && speed > FLICK_SPEED)) close()
    else setOffset(0, "transform 0.35s cubic-bezier(0.2, 0.9, 0.3, 1.15)")
  }

  return (
    <div className="modal-layer">
      <div ref={scrim} className="modal-scrim" onClick={close} aria-hidden="true" />
      <div
        ref={ref}
        className={`modal modal--${size}`}
        role="dialog"
        aria-modal="true"
        aria-label={label}
        tabIndex={-1}
      >
        <div className="modal__grab" onPointerDown={onDown} onPointerMove={onMove} onPointerUp={onUp} onPointerCancel={onUp}>
          <span className="modal__handle" aria-hidden="true" />
          {header}
        </div>
        <div className="modal__body">{children}</div>
        {footer}
      </div>
    </div>
  )
}

/** __modal-top: a button on each side, the title centred over them. */
export function ModalHeader({ title, left, right }: { title: string; left?: ReactNode; right?: ReactNode }) {
  return (
    <div className="modal__top">
      <span className="modal__side">{left}</span>
      <h2 className="t-body-18-s modal__title">{title}</h2>
      <span className="modal__side">{right}</span>
    </div>
  )
}
