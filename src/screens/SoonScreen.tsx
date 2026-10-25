import { LogoMark, PageTitle } from "../components/ui"
import TabBar, { type Tab } from "../components/TabBar"

const COPY: Record<"finance" | "profile", { title: string; sub: string; body: string }> = {
  finance: {
    title: "Finance",
    sub: "Overview",
    body: "Assets, savings and the big picture of your money are coming in a later version. For now, Expense and Due are ready.",
  },
  profile: {
    title: "Profile",
    sub: "You",
    body: "Your name, settings and backups are coming in a later version. Everything you record stays on this device.",
  },
}

/** Placeholder for tabs that aren't built yet — says so plainly instead of pretending. */
export default function SoonScreen({
  tab,
  onTab,
  onOpenAssistant,
}: {
  tab: "finance" | "profile"
  onTab: (t: Tab) => void
  onOpenAssistant: () => void
}) {
  const c = COPY[tab]
  return (
    <div className="screen">
      <span className="screen__glow screen__glow--soft" aria-hidden="true" />
      <div className="soon__top" />
      <PageTitle title={c.title} sub={c.sub} />
      <section className="soon">
        <LogoMark size={48} />
        <span className="soon__badge">Coming soon</span>
        <p className="t-body-14-r soon__body">{c.body}</p>
      </section>
      <div className="screen__bottom">
        <TabBar active={tab} onTab={onTab} onQuickNote={onOpenAssistant} />
      </div>
    </div>
  )
}
