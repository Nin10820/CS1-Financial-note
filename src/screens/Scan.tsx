import { Button } from "../components/ui"
import StickyHeader from "../components/StickyHeader"
import TabBar, { type Tab } from "../components/TabBar"
import { Icon } from "../components/Icon"
import "./scan.css"

/**
 * Scan tab. Reading a photo of a handwritten list needs the AI reader, which isn't in this version,
 * so the tab says so plainly and offers the typed route that already works.
 */
export default function Scan({ onTab, onQuickNote }: { onTab: (t: Tab) => void; onQuickNote: () => void }) {
  return (
    <div className="screen">
      <span className="screen__glow screen__glow--soft" aria-hidden="true" />
      <StickyHeader title="Scan" left={<h1 className="scan__title">Scan</h1>} />
      <section className="scan">
        <div className="scan__frame" aria-hidden="true">
          <i />
          <i />
          <i />
          <i />
          <Icon name="tab-scan" size={40} />
        </div>
        <h2>Scan a paper note</h2>
        <p>
          Point the camera at a handwritten list and the amounts are read for you. That comes in a later version — for now, type the
          list and it&apos;s split the same way.
        </p>
        <span className="scan__badge">Coming later</span>
        <Button variant="primary" size="lg" icon="file-edit" onClick={onQuickNote}>
          Write it instead
        </Button>
      </section>
      <div className="screen__bottom">
        <TabBar active="scan" onTab={onTab} onQuickNote={onQuickNote} />
      </div>
    </div>
  )
}
