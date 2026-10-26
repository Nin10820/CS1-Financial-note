import { useMemo, useState } from "react"
import { Amount, Button, GlassGroup, IconButton } from "../components/ui"
import { Icon } from "../components/Icon"
import StickyHeader from "../components/StickyHeader"
import TabBar, { type Tab } from "../components/TabBar"
import { ASSET_TILE, KINDS, guessAssetIcon, shares, type Asset, type AssetIcon, type AssetKind, type AssetMove, type CareGift, type WorthPoint } from "../lib/assets"
import type { Bill } from "../lib/bills"
import { addDays, money, today } from "../lib/format"
import { uid, type Entry } from "../lib/store"
import ModalSheet, { ModalHeader } from "./ModalSheet"
import "./finance.css"

type View = "overview" | "total" | "debt"

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const dayLabel = (iso: string) => {
  const [y, m, d] = iso.split("-").map(Number)
  return `${d} ${MONTHS[m - 1]} ${y}`
}
const monthLabel = (ym: string) => `${MONTHS[Number(ym.slice(5, 7)) - 1]} ${ym.slice(0, 4)}`
const short = (n: number) => (n >= 1_000_000 ? `${(n / 1_000_000).toFixed(3).replace(/\.?0+$/, "")} M` : money(n))

/**
 * Finance — Figma High Fi 2 › Asset (943:25860 overview, 943:25978 scrolled, 943:26145 family).
 * Everything here is what the user wrote down; the app never connects to a bank.
 */
export default function Finance({
  name,
  assets,
  moves,
  care,
  worth,
  bills,
  entries,
  birthYear,
  hidden,
  onToggleHidden,
  onAddAsset,
  onTab,
  onQuickNote,
  onTalk,
}: {
  name: string
  assets: Asset[]
  moves: AssetMove[]
  care: CareGift[]
  worth: WorthPoint[]
  bills: Bill[]
  entries: Entry[]
  birthYear?: number
  hidden: boolean
  onToggleHidden: () => void
  onAddAsset: (a: Asset) => void
  onTab: (t: Tab) => void
  onQuickNote: () => void
  onTalk: () => void
}) {
  const [view, setView] = useState<View>("overview")
  const [family, setFamily] = useState(false)
  const [adding, setAdding] = useState(false)
  const [menu, setMenu] = useState(false)
  const mask = (v: string) => (hidden ? "•••" : v)

  const header = (
    <StickyHeader
      title={family ? "Taken care of" : "Finance"}
      left={
        family ? (
          <IconButton icon="arrow-left" label="Back to Finance" variant="glass" onClick={() => setFamily(false)} />
        ) : (
          <span className="avatar" aria-label={`Signed in as ${name}`}>
            {name.slice(0, 2).toUpperCase()}
          </span>
        )
      }
      right={
        <div className="pill-group">
          <GlassGroup aria-label="Finance actions" className="pill-group__glass">
            <IconButton icon="dots-three" label="More" variant="plain" iconSize={24} aria-expanded={menu} aria-haspopup="menu" onClick={() => setMenu(!menu)} />
            <IconButton icon="plus-18" label="Add an asset" variant="plain" iconSize={18} onClick={() => setAdding(true)} />
          </GlassGroup>
          {menu && (
            <div className="note-menu note-menu--top lg lg--thick lg-morph" role="menu">
              <button type="button" role="menuitem" className="note-menu__item" onClick={() => (setMenu(false), onToggleHidden())}>
                <Icon name="eye-slash" size={20} />
                {hidden ? "Show amounts" : "Hide amounts"}
              </button>
              {!family && (
                <button type="button" role="menuitem" className="note-menu__item" onClick={() => (setMenu(false), setFamily(true))}>
                  <Icon name="user" size={20} />
                  For your family
                </button>
              )}
            </div>
          )}
        </div>
      }
    />
  )

  return (
    <div className="screen fin">
      <span className="screen__glow screen__glow--soft" aria-hidden="true" />
      {header}

      {family ? (
        <Family care={care} entries={entries} birthYear={birthYear} mask={mask} onTalk={onTalk} />
      ) : (
        <>
          <div className="fin-tabs" role="tablist" aria-label="Finance view">
            {(
              [
                ["overview", "Overview"],
                ["total", "Total Asset"],
                ["debt", "Debt"],
              ] as const
            ).map(([v, label]) => (
              <button key={v} type="button" role="tab" aria-selected={view === v} className={`fin-tabs__tab${view === v ? " is-active" : ""}`} onClick={() => setView(v)}>
                {label}
              </button>
            ))}
          </div>

          {view === "overview" && <Overview birthYear={birthYear} assets={assets} moves={moves} care={care} worth={worth} mask={mask} onFamily={() => setFamily(true)} onAdd={() => setAdding(true)} />}
          {view === "total" && <TotalAssets assets={assets} mask={mask} onAdd={() => setAdding(true)} />}
          {view === "debt" && <Debt bills={bills} mask={mask} />}
        </>
      )}

      <div className="screen__bottom">
        <TabBar active="finance" onTab={onTab} onQuickNote={onQuickNote} />
      </div>
      {adding && <AddAsset onClose={() => setAdding(false)} onSave={onAddAsset} />}
    </div>
  )
}

/* ── Overview ───────────────────────────────────────────── */

function Overview({
  birthYear,
  assets,
  moves,
  care,
  worth,
  mask,
  onFamily,
  onAdd,
}: {
  birthYear?: number
  assets: Asset[]
  moves: AssetMove[]
  care: CareGift[]
  worth: WorthPoint[]
  mask: (v: string) => string
  onFamily: () => void
  onAdd: () => void
}) {
  const { total, groups } = shares(assets)
  // Growth against the same month last year, when the chart has that far back.
  const growth = worth.length > 12 ? Math.round(((worth[worth.length - 1].value - worth[worth.length - 13].value) / worth[worth.length - 13].value) * 100) : null
  const recent = [...moves].sort((a, b) => b.date.localeCompare(a.date)).slice(0, 3)
  const careTotal = care.reduce((s, c) => s + c.amount, 0)

  if (!assets.length)
    return (
      <section className="fin-empty">
        <p className="fin-empty__title">Nothing written down yet</p>
        <p className="fin-empty__body">Add what you keep — cash, savings, gold, a fund — and this page adds it up. Nothing connects to your bank.</p>
        <Button variant="primary" size="md" icon="plus" onClick={onAdd}>
          Add an asset
        </Button>
      </section>
    )

  return (
    <div className="fin-body">
      <section className="fin-card" aria-label="Total asset">
        <div className="fin-total">
          <p className="fin-total__label">Total Asset</p>
          <div className="fin-total__row">
            <span className="fin-total__amount tnum">{mask(money(total))}</span>
            <span className="fin-total__cur">đ</span>
            {growth !== null && !mask("x").startsWith("•") && (
              <span className={`fin-badge${growth < 0 ? " is-down" : ""}`}>
                <Icon name="trend-up" size={16} />
                {Math.abs(growth)}%
              </span>
            )}
          </div>
          <div className="fin-bar" aria-hidden="true">
            {groups
              .filter((g) => g.pct > 0)
              .map((g) => (
                <span key={g.kind} style={{ flexGrow: g.pct, background: g.color }} />
              ))}
          </div>
          <ul className="fin-legend">
            {groups.map((g) => (
              <li key={g.kind}>
                <i style={{ background: g.color }} />
                <span>{g.label}:</span>
                <b>{g.pct}%</b>
              </li>
            ))}
          </ul>
        </div>
        {worth.length > 1 ? (
          <WorthChart points={worth} mask={mask} growth={growth} />
        ) : (
          <p className="fin-chart-empty">The line appears after your second month of updates.</p>
        )}
      </section>

      <History title="History" rows={recent.map((m) => ({ id: m.id, title: m.title, date: m.date, amount: m.amount, icon: m.icon }))} mask={mask} />

      {care.length > 0 && (
        <>
          <p className="fin-eyebrow">For your family</p>
          <button type="button" className="fin-care" onClick={onFamily}>
            <span className="fin-care__label">Taken care of</span>
            <span className="fin-care__amount tnum">
              {mask(money(careTotal))} <small>đ</small>
            </span>
            <span className="fin-care__sub">{sinceText(care, birthYear)}</span>
            <span className="fin-care__more">
              See what it went to <Icon name="caret-right" size={18} />
            </span>
          </button>
        </>
      )}
    </div>
  )
}

function sinceText(care: CareGift[], birthYear?: number) {
  const first = care.reduce((m, c) => (c.date < m ? c.date : m), care[0]?.date ?? today())
  if (birthYear) return `You have carried this since you were ${Number(first.slice(0, 4)) - birthYear}.`
  return `You have carried this since ${monthLabel(first.slice(0, 7))}.`
}

/** Month-end net worth, with the latest point called out (Figma tooltip "12 Sep 2026 · 5.034 M"). */
function WorthChart({ points, mask, growth }: { points: WorthPoint[]; mask: (v: string) => string; growth: number | null }) {
  const W = 330
  const H = 110
  const max = Math.max(...points.map((p) => p.value))
  const top = Math.ceil(max / 1_000_000 / 20) * 20 * 1_000_000 || 1
  const x = (i: number) => (i / (points.length - 1)) * W
  const y = (v: number) => H - (v / top) * H
  const line = points.map((p, i) => `${i ? "L" : "M"}${x(i).toFixed(1)},${y(p.value).toFixed(1)}`).join(" ")
  const last = points[points.length - 1]
  const lx = x(points.length - 1)
  const ly = y(last.value)
  return (
    <figure className="fin-chart" aria-label={`Net worth from ${monthLabel(points[0].month)} to ${monthLabel(last.month)}`}>
      <div className="fin-chart__plot">
        <span className="fin-chart__y" style={{ top: 0 }}>
          {mask(money(top / 1000))}
        </span>
        <span className="fin-chart__y" style={{ top: "50%" }}>
          {mask(money(top / 2000))}
        </span>
        <svg viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="none" aria-hidden="true">
          <defs>
            <linearGradient id="fin-fill" x1="0" x2="0" y1="0" y2="1">
              <stop offset="0" stopColor="#5fa82f" stopOpacity="0.28" />
              <stop offset="1" stopColor="#5fa82f" stopOpacity="0" />
            </linearGradient>
          </defs>
          {[0, 0.5, 1].map((f) => (
            <line key={f} x1="0" x2={W} y1={H * f} y2={H * f} className="fin-chart__grid" />
          ))}
          <path d={`${line} L${W},${H} L0,${H} Z`} fill="url(#fin-fill)" />
          <path d={line} className="fin-chart__line" />
          <line x1={lx} x2={lx} y1="0" y2={H} className="fin-chart__cursor" />
          <circle cx={lx} cy={ly} r="3.5" className="fin-chart__dot" />
        </svg>
        {!mask("x").startsWith("•") && (
          <span className="fin-chart__tip" style={{ top: `${Math.max(0, (ly / H) * 100 - 30)}%` }}>
            <b>{monthLabel(last.month)}</b>
            <span>
              {short(last.value)}
              {growth !== null && (
                <em>
                  {" "}
                  · <Icon name="trend-up" size={12} /> {growth}%
                </em>
              )}
            </span>
          </span>
        )}
      </div>
      <figcaption className="fin-chart__x">
        <span>{monthLabel(points[0].month)}</span>
        <span>{monthLabel(last.month)}</span>
      </figcaption>
    </figure>
  )
}

function History({
  title,
  rows,
  mask,
  plain,
}: {
  title: string
  rows: { id: string; title: string; date: string; amount: number; icon?: AssetIcon }[]
  mask: (v: string) => string
  plain?: boolean
}) {
  const [all, setAll] = useState(false)
  const shown = all ? rows : rows.slice(0, plain ? 6 : 3)
  if (!rows.length) return null
  return (
    <section className={`fin-card fin-history${plain ? " is-plain" : ""}`} aria-label={title}>
      {!plain && (
        <div className="fin-history__head">
          <h2>{title}</h2>
          {rows.length > 3 && (
            <button type="button" onClick={() => setAll(!all)}>
              {all ? "Show less" : "See all"}
            </button>
          )}
        </div>
      )}
      <ul>
        {shown.map((r) => (
          <li key={r.id} className="fin-row">
            {r.icon && (
              <span className="fin-row__tile" style={{ background: ASSET_TILE[r.icon].bg, color: ASSET_TILE[r.icon].ink }} aria-hidden="true">
                {ASSET_TILE[r.icon].mark}
              </span>
            )}
            <span className="fin-row__text">
              <span className="fin-row__title">{r.title}</span>
              <span className="fin-row__date">{dayLabel(r.date)}</span>
            </span>
            <Amount value={mask(money(r.amount))} />
          </li>
        ))}
      </ul>
      {plain && rows.length > 6 && (
        <button type="button" className="fin-history__more" onClick={() => setAll(!all)}>
          {all ? "Show less" : `Show all ${rows.length}`}
        </button>
      )}
    </section>
  )
}

/* ── Total Asset ────────────────────────────────────────── */

function TotalAssets({ assets, mask, onAdd }: { assets: Asset[]; mask: (v: string) => string; onAdd: () => void }) {
  const { total, groups } = shares(assets)
  return (
    <div className="fin-body">
      {groups.map((g) => {
        const list = assets.filter((a) => a.kind === g.kind)
        return (
          <section key={g.kind} className="fin-card fin-group" aria-label={g.label}>
            <div className="fin-group__head">
              <i style={{ background: g.color }} />
              <h2>{g.label}</h2>
              <span className="fin-group__pct">{g.pct}%</span>
              <Amount value={mask(money(g.sum))} />
            </div>
            {list.length ? (
              <ul>
                {list.map((a) => (
                  <li key={a.id} className="fin-row">
                    <span className="fin-row__tile" style={{ background: ASSET_TILE[a.icon].bg, color: ASSET_TILE[a.icon].ink }} aria-hidden="true">
                      {ASSET_TILE[a.icon].mark}
                    </span>
                    <span className="fin-row__text">
                      <span className="fin-row__title">{a.name}</span>
                      <span className="fin-row__date">Updated {dayLabel(a.updated)}</span>
                    </span>
                    <Amount value={mask(money(a.amount))} />
                  </li>
                ))}
              </ul>
            ) : (
              <p className="fin-group__none">Nothing here yet.</p>
            )}
          </section>
        )
      })}
      <p className="fin-foot">
        {mask(money(total))} đ in total · <button type="button" onClick={onAdd}>Add an asset</button>
      </p>
    </div>
  )
}

/* ── Debt ───────────────────────────────────────────────── */

function Debt({ bills, mask }: { bills: Bill[]; mask: (v: string) => string }) {
  const rows = bills
    .filter((b) => b.kind === "installment" && b.payments)
    .map((b) => {
      const paid = Object.keys(b.paid).length
      const left = Math.max(0, (b.payments ?? 0) - paid)
      return { b, paid, left, owe: left * b.amount }
    })
    .filter((r) => r.left > 0)
  const total = rows.reduce((s, r) => s + r.owe, 0)
  return (
    <div className="fin-body">
      <section className="fin-card fin-total" aria-label="Still to pay">
        <p className="fin-total__label">Still to pay on installments</p>
        <div className="fin-total__row">
          <span className="fin-total__amount tnum">{mask(money(total))}</span>
          <span className="fin-total__cur">đ</span>
        </div>
        <p className="fin-debt__note">Worked out from your installments in Due. Paying one off there updates this.</p>
      </section>
      {rows.length ? (
        <section className="fin-card fin-history" aria-label="Installments">
          <ul>
            {rows.map(({ b, paid, left, owe }) => (
              <li key={b.id} className="fin-row fin-debt">
                <span className="fin-row__text">
                  <span className="fin-row__title">{b.name}</span>
                  <span className="fin-row__date">
                    {b.lender ? `${b.lender} · ` : ""}
                    {left} of {b.payments} left
                  </span>
                  <span className="fin-debt__bar" aria-hidden="true">
                    <i style={{ width: `${(paid / (b.payments ?? 1)) * 100}%` }} />
                  </span>
                </span>
                <Amount value={mask(money(owe))} />
              </li>
            ))}
          </ul>
        </section>
      ) : (
        <p className="fin-foot">No installments left to pay.</p>
      )}
    </div>
  )
}

/* ── For your family ────────────────────────────────────── */

function Family({
  care,
  entries,
  birthYear,
  mask,
  onTalk,
}: {
  care: CareGift[]
  entries: Entry[]
  birthYear?: number
  mask: (v: string) => string
  onTalk: () => void
}) {
  const total = care.reduce((s, c) => s + c.amount, 0)
  const groups = useMemo(() => {
    const map = new Map<string, CareGift[]>()
    for (const c of care) map.set(c.who, [...(map.get(c.who) ?? []), c])
    return [...map.entries()].sort((a, b) => b[1].length - a[1].length)
  }, [care])
  // Share of income over the last 30 days that went to family.
  const since = addDays(today(), -30)
  const earned = entries.filter((e) => e.flow === "in" && e.date >= since).reduce((s, e) => s + e.amount, 0)
  const gave = care.filter((c) => c.date >= since).reduce((s, c) => s + c.amount, 0)
  const share = earned ? Math.round((gave / earned) * 100) : null
  const rows = [...care].sort((a, b) => b.date.localeCompare(a.date))

  const cadence = (who: string, list: CareGift[]) => {
    if (/tuition|brother|sister|em/i.test(who + list[0].title)) return `${list.length} terms of tuition`
    if (/household|nhà/i.test(who)) return `${list.length} bills`
    return `every month, ${list.length} times`
  }

  return (
    <div className="fin-body fin-family">
      <section className="fin-care is-static" aria-label="Taken care of">
        <span className="fin-care__label">Taken care of</span>
        <span className="fin-care__amount tnum">
          {mask(money(total))} <small>đ</small>
        </span>
        <span className="fin-care__sub">{sinceText(care, birthYear)}</span>
        <ul className="fin-care__list">
          {groups.map(([who, list]) => (
            <li key={who}>
              <i />
              <span>{who}</span>
              <small>{cadence(who, list)}</small>
            </li>
          ))}
        </ul>
      </section>

      <section className="fin-quote">
        <p>
          Financial progress isn&apos;t only what you keep. <b>It&apos;s also what you carry for the people you love.</b>
        </p>
        {share !== null && <span>About {share}% of what you earned in the last 30 days</span>}
      </section>

      <h2 className="fin-family__title">History</h2>
      <History title="History" rows={rows} mask={mask} plain />

      <div className="fin-talk">
        <button type="button" className="fin-talk__btn lg lg-press" onClick={onTalk}>
          <Icon name="sparkle-ai" size={20} />
          Talk with Monez
        </button>
      </div>
    </div>
  )
}

/* ── Add asset ──────────────────────────────────────────── */

function AddAsset({ onClose, onSave }: { onClose: () => void; onSave: (a: Asset) => void }) {
  const [name, setName] = useState("")
  const [amount, setAmount] = useState("")
  const [kind, setKind] = useState<AssetKind>("available")
  const value = Number(amount.replace(/[^\d]/g, ""))
  const ok = name.trim() && value > 0
  return (
    <ModalSheet
      label="Add an asset"
      size="auto"
      onClose={onClose}
      header={
        <ModalHeader
          title="New asset"
          left={
            <Button variant="glass" size="md" onClick={onClose}>
              Cancel
            </Button>
          }
          right={
            <Button
              variant="glass"
              size="md"
              disabled={!ok}
              onClick={() => {
                onSave({ id: uid(), name: name.trim(), kind, icon: guessAssetIcon(name, kind), amount: value, updated: today() })
                onClose()
              }}
            >
              Save
            </Button>
          }
        />
      }
    >
      <div className="fin-add">
        <label className="fin-add__field">
          <span>What is it?</span>
          <input className="field" value={name} placeholder="Gold, Saving - TP Bank, Fund…" onChange={(e) => setName(e.target.value)} autoFocus />
        </label>
        <label className="fin-add__field">
          <span>How much is it worth now?</span>
          <input
            className="field tnum"
            inputMode="numeric"
            value={amount ? money(value) : ""}
            placeholder="0"
            onChange={(e) => setAmount(e.target.value)}
          />
        </label>
        <fieldset className="fin-add__kinds">
          <legend>Which group?</legend>
          {KINDS.map((k) => (
            <button key={k.kind} type="button" className={`fin-add__kind${kind === k.kind ? " is-active" : ""}`} aria-pressed={kind === k.kind} onClick={() => setKind(k.kind)}>
              <i style={{ background: k.color }} />
              {k.label}
            </button>
          ))}
        </fieldset>
        <p className="fin-add__hint">
          {kind === "available" && "Money you can use right away — cash, your main account."}
          {kind === "growing" && "Put somewhere to grow — gold, a fund, stocks."}
          {kind === "aside" && "Locked away for later — a savings deposit."}
          {kind === "owed" && "Money someone owes you."}
        </p>
      </div>
    </ModalSheet>
  )
}
