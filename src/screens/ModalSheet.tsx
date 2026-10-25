import { useEffect, useRef, type ReactNode } from "react"

/** Figma "Modal": bg-1 sheet with 20px top corners and a grab handle, over a 48% dark scrim.
    Escape and a tap on the scrim close it; focus moves into the sheet and back when it closes. */
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

  return (
    <div className="modal-layer">
      <div className="modal-scrim" onClick={onClose} aria-hidden="true" />
      <div
        ref={ref}
        className={`modal modal--${size}`}
        role="dialog"
        aria-modal="true"
        aria-label={label}
        tabIndex={-1}
      >
        <span className="modal__handle" aria-hidden="true" />
        {header}
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
