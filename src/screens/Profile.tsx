import { useState, type ReactNode } from "react"
import { Button, IconButton, Switch } from "../components/ui"
import { Icon } from "../components/Icon"
import StickyHeader from "../components/StickyHeader"
import TabBar, { type Tab } from "../components/TabBar"
import { today } from "../lib/format"
import type { Store } from "../lib/store"
import "./profile.css"

type Page = "menu" | "profile" | "edit" | "data" | "ai" | "delete" | "display" | "report" | "about"

const VERSION = "0.1 · MVP"
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const since = (iso: string) => `${MONTHS[Number(iso.slice(5, 7)) - 1]} ${iso.slice(0, 4)}`
const days = (iso: string) => Math.max(1, Math.round((Date.parse(today()) - Date.parse(iso)) / 86_400_000) + 1)

/** Everything in the store, as a file the user keeps. */
function download(store: Store) {
  const data = {
    exported: new Date().toISOString(),
    name: store.name,
    entries: store.entries,
    notes: store.notes,
    bills: store.bills,
    assets: store.assets,
    moves: store.moves,
    care: store.care,
    prefs: store.prefs,
  }
  const url = URL.createObjectURL(new Blob([JSON.stringify(data, null, 2)], { type: "application/json" }))
  const a = document.createElement("a")
  a.href = url
  a.download = `financial-note-${today()}.json`
  a.click()
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}

/**
 * Profile — Figma Draft › Account (707:7360): menu, profile, data & privacy, display, help.
 * There is no account in this version, so sign-in, password, Face ID and log-out are left out
 * rather than shown as switches that do nothing.
 */
export default function Profile({ store, onTab, onQuickNote }: { store: Store; onTab: (t: Tab) => void; onQuickNote: () => void }) {
  const [page, setPage] = useState<Page>("menu")
  const go = (p: Page) => {
    setPage(p)
    window.scrollTo(0, 0)
  }
  const back = (to: Page = "menu") => go(to)
  const counts = { lines: store.entries.length, assets: store.assets.length, bills: store.bills.length }

  const titles: Record<Page, string> = {
    menu: "Profile",
    profile: "Profile",
    edit: "Edit profile",
    data: "Your data",
    ai: "What the AI does",
    delete: "Delete data",
    display: "Display",
    report: "Report a problem",
    about: "About the app",
  }

  return (
    <div className="screen prof">
      <span className="screen__glow screen__glow--soft" aria-hidden="true" />
      {page === "menu" ? (
        <StickyHeader title="Profile" left={<h1 className="day-head__title">Profile</h1>} />
      ) : (
        <StickyHeader
          title={titles[page]}
          left={<IconButton icon="arrow-left" label="Back" variant="glass" onClick={() => back(page === "edit" ? "profile" : page === "delete" ? "data" : "menu")} />}
          center={<span className="prof-head">{titles[page]}</span>}
        />
      )}

      <div className="prof-body">
        {page === "menu" && (
          <>
            <button type="button" className="prof-me" onClick={() => go("profile")}>
              <span className="prof-avatar">{store.name.slice(0, 2).toUpperCase()}</span>
              <span className="prof-me__text">
                <b>{store.name}</b>
                <small>Using it since {since(store.prefs.joined)}</small>
              </span>
              <Icon name="caret-right" size={18} />
            </button>

            <Group label="Account">
              <Row label="Profile" onClick={() => go("profile")} />
              <Row label="Currency" value="VND" />
            </Group>

            <Group label="Data & privacy">
              <Row label="Your data" sub="See what the app keeps" onClick={() => go("data")} />
              <Row label="What the AI does with notes" sub="Only reads what you send" onClick={() => go("ai")} />
              <Row label="Download your data" onClick={() => download(store)} />
              <Row
                label="Sample data"
                sub={store.hasSample ? "Showing made-up notes, bills and assets" : "Fill every screen with made-up data"}
                control={<Switch label="Sample data" checked={store.hasSample} onChange={(v) => (v ? store.loadSample() : store.clearSample())} />}
              />
            </Group>

            <Group label="Display">
              <Row label="Hide amounts when the app opens" control={<Switch label="Hide amounts when the app opens" checked={store.prefs.hideOnOpen} onChange={(v) => store.setPrefs({ hideOnOpen: v })} />} />
              <Row label="Display" onClick={() => go("display")} />
            </Group>

            <Group label="Help">
              <Row label="Report a problem" onClick={() => go("report")} />
              <Row label="About the app" value={VERSION} onClick={() => go("about")} />
            </Group>
            <p className="prof-note">No account, no server: everything you write stays on this phone.</p>
          </>
        )}

        {page === "profile" && (
          <>
            <div className="prof-hero">
              <span className="prof-avatar prof-avatar--lg">{store.name.slice(0, 2).toUpperCase()}</span>
              <h2>{store.name}</h2>
              <p>
                On this phone since {store.prefs.joined.split("-").reverse().join("/")} · {days(store.prefs.joined)} days
              </p>
            </div>
            <Group label="Info">
              <Row label="Display name" value={store.name} onClick={() => go("edit")} />
            </Group>
            <p className="prof-note">The app doesn&apos;t ask for your income, your job or your money goals — it doesn&apos;t need them to work.</p>
          </>
        )}

        {page === "edit" && <EditName name={store.name} onSave={(n) => (store.setName(n), back("profile"))} onCancel={() => back("profile")} />}

        {page === "data" && (
          <>
            <Intro title="What the app keeps" sub="The full list. Nothing hidden." />
            <Group label="On your phone">
              <Row label="Spending notes" value={`${counts.lines} ${counts.lines === 1 ? "line" : "lines"}`} />
              <Row label="Assets" value={`${counts.assets}`} />
              <Row label="Recurring bills" value={`${counts.bills}`} />
            </Group>
            <Group label="Sent to a server">
              <Row label="Nothing" sub="Notes are read on this phone in this version" />
            </Group>
            <Group label="Never collected">
              <Row label="Bank accounts" />
              <Row label="Location" />
              <Row label="Contacts" />
            </Group>
            <p className="prof-note prof-note--box">The app doesn&apos;t connect to a bank, so it can&apos;t spend money for you either.</p>
            <Group>
              <Row label="Download everything" onClick={() => download(store)} />
              <Row label="Delete everything" danger onClick={() => go("delete")} />
            </Group>
          </>
        )}

        {page === "ai" && (
          <>
            <Intro title="The AI does two things" sub="Both can be turned off — the app still works if you type everything yourself." />
            <Group label="On">
              <Row label="Reads your notes" sub="Splits items, amounts and days" control={<span className="prof-pill">On</span>} />
              <Row label="Answers when you ask" sub="Coming later · it never speaks first" control={<span className="prof-pill is-off">Later</span>} />
            </Group>
            <Group label="Not in the app">
              <Row label="Investment tips" sub="Left out on purpose, not “not yet”" />
              <Row label="Comments on how you spend" />
              <Row label="Overspending alerts" />
              <Row label="Spending or moving money" />
            </Group>
            <p className="prof-note prof-note--box">
              These four were cut, not postponed: in our survey 38% refused investment tips, 31% refused being judged on their spending, and 63% didn&apos;t want an app touching their money.
            </p>
            <p className="prof-note">In this version the note reader runs on your phone — no note leaves it.</p>
          </>
        )}

        {page === "delete" && <DeleteAll counts={counts} onDownload={() => download(store)} onDelete={() => (store.clearAll(), back("menu"))} onKeep={() => back("data")} />}

        {page === "display" && (
          <>
            <Intro title="You choose when to look" sub="No number jumps out at you." />
            <Group label="When the app opens">
              <Row label="Hide balances" sub="Tap the eye to show them" control={<Switch label="Hide balances" checked={store.prefs.hideOnOpen} onChange={(v) => store.setPrefs({ hideOnOpen: v })} />} />
              <Row label="Hide asset totals" sub="Applies to Finance too" control={<Switch label="Hide asset totals" checked={store.prefs.hideAssets} onChange={(v) => store.setPrefs({ hideAssets: v })} />} />
            </Group>
            <Group label="Numbers">
              <Row label="Currency" value="VND" />
            </Group>
          </>
        )}

        {page === "report" && <Report />}

        {page === "about" && (
          <>
            <section className="prof-principle">
              <small>Principle</small>
              <p>A layer to look through, not a layer of control</p>
            </section>
            <Group label="This app does not">
              <Row label="Hold or move your money" sub="63% don't want an app spending for them" />
              <Row label="Suggest investments or products" sub="38% refused" />
              <Row label="Comment on how you spend" sub="31% refused" />
              <Row label="Read your bank account" sub="78% worry an app knows too much" />
            </Group>
            <Group>
              <Row label="Version" value={VERSION} />
            </Group>
            <p className="prof-credit">WUD Design Challenge 2026 · Nin Nguyễn · Pham Nguyen Studio</p>
          </>
        )}
      </div>

      <div className="screen__bottom">
        <TabBar active="profile" onTab={onTab} onQuickNote={onQuickNote} />
      </div>
    </div>
  )
}

/* ── Building blocks ───────────────────────────────────── */

function Group({ label, children }: { label?: string; children: ReactNode }) {
  return (
    <section className="prof-group" aria-label={label}>
      {label && <h3 className="prof-group__label">{label}</h3>}
      <div className="prof-group__card">{children}</div>
    </section>
  )
}

function Row({
  label,
  sub,
  value,
  control,
  danger,
  onClick,
}: {
  label: string
  sub?: string
  value?: string
  control?: ReactNode
  danger?: boolean
  onClick?: () => void
}) {
  const body = (
    <>
      <span className="prof-row__text">
        <span className={`prof-row__label${danger ? " is-danger" : ""}`}>{label}</span>
        {sub && <span className="prof-row__sub">{sub}</span>}
      </span>
      {value && <span className="prof-row__value">{value}</span>}
      {control}
      {onClick && <Icon name="caret-right" size={16} />}
    </>
  )
  return onClick ? (
    <button type="button" className="prof-row" onClick={onClick}>
      {body}
    </button>
  ) : (
    <div className="prof-row">{body}</div>
  )
}

function Intro({ title, sub }: { title: string; sub: string }) {
  return (
    <div className="prof-intro">
      <h2>{title}</h2>
      <p>{sub}</p>
    </div>
  )
}

function EditName({ name, onSave, onCancel }: { name: string; onSave: (n: string) => void; onCancel: () => void }) {
  const [value, setValue] = useState(name)
  return (
    <form
      className="prof-edit"
      onSubmit={(e) => {
        e.preventDefault()
        if (value.trim()) onSave(value)
      }}
    >
      <span className="prof-avatar prof-avatar--lg">{(value || name).slice(0, 2).toUpperCase()}</span>
      <label className="prof-field">
        <span>Display name</span>
        <input className="field" value={value} maxLength={40} autoFocus onChange={(e) => setValue(e.target.value)} />
      </label>
      <p className="prof-note">This is the name in “Good morning, …”. It stays on this phone.</p>
      <div className="prof-actions">
        <Button variant="outline" size="lg" onClick={onCancel}>
          Cancel
        </Button>
        <Button variant="primary" size="lg" type="submit" disabled={!value.trim()}>
          Save
        </Button>
      </div>
    </form>
  )
}

function DeleteAll({
  counts,
  onDownload,
  onDelete,
  onKeep,
}: {
  counts: { lines: number; assets: number; bills: number }
  onDownload: () => void
  onDelete: () => void
  onKeep: () => void
}) {
  const [typed, setTyped] = useState("")
  const ok = typed.trim().toUpperCase() === "DELETE"
  return (
    <div className="prof-delete">
      <section className="prof-warn">
        <b>Deleting is permanent</b>
        <p>
          {counts.lines} notes, {counts.assets} assets and {counts.bills} recurring bills will be gone. There is no undo.
        </p>
      </section>
      <section className="prof-copy">
        <div>
          <b>Want to keep a copy?</b>
          <small>Download a file to your phone first</small>
        </div>
        <Button variant="outline" size="sm" onClick={onDownload}>
          Download
        </Button>
      </section>
      <label className="prof-field">
        <span>Type DELETE to confirm</span>
        <input className="field prof-field--danger" value={typed} placeholder="DELETE" autoCapitalize="characters" onChange={(e) => setTyped(e.target.value)} />
      </label>
      <div className="prof-actions prof-actions--stack">
        <Button variant="outline" size="lg" onClick={onKeep}>
          No, keep it
        </Button>
        <Button variant="primary" size="lg" className="is-danger" disabled={!ok} onClick={onDelete}>
          Delete everything
        </Button>
      </div>
    </div>
  )
}

function Report() {
  const TOPICS = ["Misread my note", "Slow", "Wrong number", "Other"]
  const [topic, setTopic] = useState(TOPICS[0])
  const [text, setText] = useState("")
  const body = `${topic}\n\n${text}\n\n— Financial Note ${VERSION}, ${navigator.userAgent}`
  return (
    <div className="prof-report">
      <Intro title="What went wrong?" sub="Write it any way you like." />
      <div className="prof-topics" role="group" aria-label="Topic">
        {TOPICS.map((t) => (
          <button key={t} type="button" className={`fn-chip${topic === t ? " is-active" : ""}`} aria-pressed={topic === t} onClick={() => setTopic(t)}>
            {t}
          </button>
        ))}
      </div>
      <textarea
        className="field prof-report__text"
        rows={5}
        value={text}
        placeholder="I typed “cà phê 24k” and it read 240k…"
        onChange={(e) => setText(e.target.value)}
      />
      <p className="prof-note prof-note--box">Only the app version and your browser go with it. No amounts, no notes.</p>
      <a className={`fn-btn fn-btn--primary fn-btn--lg prof-send${text.trim() ? "" : " is-disabled"}`} aria-disabled={!text.trim()} href={text.trim() ? `mailto:?subject=${encodeURIComponent(`Financial Note: ${topic}`)}&body=${encodeURIComponent(body)}` : undefined}>
        Send by email
      </a>
    </div>
  )
}
