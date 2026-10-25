/** Edge blur that gets stronger toward the screen edge, like iOS 26 apps (Claude, Music):
    five stacked backdrop blurs, each masked to a band, plus a light tint. Works in Safari. */
export default function ProgressiveBlur({ edge, visible = true }: { edge: "top" | "bottom"; visible?: boolean }) {
  return (
    <div className={`pblur pblur--${edge}${visible ? " is-on" : ""}`} aria-hidden="true">
      <i />
      <i />
      <i />
      <i />
      <i />
      <b />
    </div>
  )
}
