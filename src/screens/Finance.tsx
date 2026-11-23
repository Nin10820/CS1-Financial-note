import { useEffect, useRef, useState } from "react"
import { IconButton } from "../components/ui"
import { Icon } from "../components/Icon"
import StickyHeader from "../components/StickyHeader"
import { AmountText, AssetTile, HistoryLink, JoinedCard, Legend, ListCard, ListRow, Pie, PieCard, SectionTitle, Segmented, StatCard, TickMark, maskC, pct, pctText } from "../components/kit"
import { usePageSwipe } from "../lib/pageSwipe"
import { addMonthsYm, compact, money, monthTitle, shortDay, today as todayIso } from "../lib/format"
import { savingPlan, monthsShort as monthsShortList } from "../lib/analysis"
import { holdingText, pricesAt, SOURCES, type HoldingUnit } from "../lib/market"
import NumberSheet from "./NumberSheet"
import { kindOf, loanPeople, loansOwed, putInOf, shares, type Asset, type AssetKind, type AssetMove, type AssetMoveKind, type CareGift, type FamilyLoan, type WorthPoint } from "../lib/assets"
import { dueIn, monthSummary, ym, type Bill } from "../lib/bills"
import type { Entry } from "../lib/store"
import { AddAssetSheet, AddLoanSheet, AssetDetail, AssetImportSheet, DebtHistorySheet, AssetHistorySheet, FamilyPage, LifeCard, LoanPersonSheet, QuickMoveSheet, RevealPage, YourselfPage, selfLines, sinceText } from "./FinancePages"
import "./finance.css"

type View = "overview" | "total" | "debt"
type Route = { kind: "family" } | { kind: "yourself" } | { kind: "asset"; id: string } | null
type Range = 6 | 12 | 36 | 0
const RANGES: { value: Range; label: string; short: string }[] = [
  { value: 6, label: "Last 6 months", short: "6 months" },
  { value: 12, label: "Last year", short: "1 year" },
  { value: 36, label: "Last 3 years", short: "3 years" },
  { value: 0, label: "All time", short: "All" },
]
const DEBT_COLORS = ["#f97066", "#fdb022", "#7a5af8", "#2e90fa", "#00ba90", "#ee46bc"]

export type FinanceActions = {
  onAddAsset: (a: Asset) => void
  onMoveAsset: (id: string, kind: AssetMoveKind, amount: number, date: string) => void
  onEditAsset: (id: string, name: string, kind: AssetKind) => void
  onRemoveAsset: (id: string) => void
  onAddLoan: (l: FamilyLoan) => void
  onRemoveLoan: (id: string) => void
  onToggleBill: (bill: Bill, paid: boolean) => void
  /** Put in, take out or set what's held in the asset's own unit (2 phân, 100 $). */
  onMoveUnits: (id: string, kind: AssetMoveKind, units: number, date: string) => void
  onSetHolding: (id: string, quantity?: number, unit?: HoldingUnit) => void
  onRemoveMove: (id: string) => void
  /** Downloads today's prices and revalues what's held in units; false when offline. */
  onSync: () => Promise<boolean>
  goldPremium: number
  onGoldPremium: (pct: number) => void
  depositPlans: Record<string, number>
  onDepositPlans: (p: Record<string, number>) => void
  savingGoal: number
}

/** Installments still owed: per bill, how many paid and what's left. */
export function installmentDebt(bills: Bill[]) {
  const rows = bills
    .filter((b) => b.kind === "installment")
    .map((b) => {
      const paid = Object.keys(b.paid).length
      return { bill: b, paid, owe: Math.max(0, (b.payments ?? 1) - paid) * b.amount }
    })
    .filter((r) => r.owe > 0)
    .sort((a, b) => b.owe - a.owe)
  return { rows, total: rows.reduce((t, r) => t + r.owe, 0) }
}

/** Each installment left, then each family member with interest — one colour each. */
export function debts(bills: Bill[], loans: FamilyLoan[], today: string) {
  const rows = [
    ...installmentDebt(bills).rows.map((r) => ({ name: r.bill.name, sum: r.owe })),
    ...loanPeople(loans, today)
      .filter((p) => p.owed > 0)
      .map((p) => ({ name: p.who, sum: p.owed })),
  ].sort((a, b) => b.sum - a.sum)
  return rows.map((r, i) => ({ ...r, color: DEBT_COLORS[i % DEBT_COLORS.length] }))
}

/** "12 changes · last 16 Nov" */
export const historySub = (dates: string[]) => {
  if (!dates.length) return "Nothing yet"
  const last = dates.reduce((m, d) => (d > m ? d : m))
  return `${dates.length} change${dates.length === 1 ? "" : "s"} · last ${shortDay(last)}`
}

/**
 * Finance — iOS FinanceView: Overview (the total over time, net worth, both pies, invested in
 * people), Total Asset (the list with quick updates) and Debt (installments and family loans).
 * Everything here is what the user wrote down; the app never connects to a bank.
 */
export default function Finance({
  onProfile,
  assets,
  moves,
  care,
  worth,
  bills,
  entries,
  loans,
  birthYear,
  hidden,
  onToggleHidden,
  addRequest,
  ...act
}: {
  onProfile: () => void
  assets: Asset[]
  moves: AssetMove[]
  care: CareGift[]
  worth: WorthPoint[]
  bills: Bill[]
  entries: Entry[]
  loans: FamilyLoan[]
  birthYear?: number
  hidden: boolean
  onToggleHidden: () => void
  /** Goes up by one each time the tab bar's + menu asks for New asset or Quick note. */
  addRequest: { n: number; mode: "new" | "note" }
} & FinanceActions) {
  const today = todayIso()
  const [view, setView] = useState<View>("overview")
  const [route, setRoute] = useState<Route>(null)
  const [adding, setAdding] = useState<"new" | "note" | null>(null)
  const [menu, setMenu] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)
  const seenAdd = useRef(addRequest.n)

  useEffect(() => {
    // Only a new press of the tab bar's + opens it, not coming back to the tab.
    if (addRequest.n !== seenAdd.current) {
      seenAdd.current = addRequest.n
      setAdding(addRequest.mode)
    }
  }, [addRequest])
  useEffect(() => {
    if (!menu) return
    const close = (e: MouseEvent) => !menuRef.current?.contains(e.target as Node) && setMenu(false)
    document.addEventListener("mousedown", close)
    return () => document.removeEventListener("mousedown", close)
  }, [menu])

  const views: View[] = ["overview", "total", "debt"]
  const swipe = usePageSwipe((n) => {
    const i = views.indexOf(view) + n
    if (i >= 0 && i < views.length) setView(views[i])
  })

  if (route?.kind === "asset") {
    const a = assets.find((x) => x.id === route.id)
    if (a) return <AssetDetail asset={a} moves={moves} hidden={hidden} today={today} onBack={() => setRoute(null)} {...act} />
  }
  if (route?.kind === "family")
    return (
      <RevealPage tint="family">
        <FamilyPage care={care} entries={entries} birthYear={birthYear} hidden={hidden} onBack={() => setRoute(null)} />
      </RevealPage>
    )
  if (route?.kind === "yourself")
    return (
      <RevealPage tint="yourself">
        <YourselfPage entries={entries} bills={bills} hidden={hidden} onBack={() => setRoute(null)} />
      </RevealPage>
    )

  return (
    <div className="screen fin2" {...swipe}>
      <StickyHeader
        title="Finance"
        right={
          <div className="today-top" ref={menuRef} style={{ position: "relative" }}>
            <IconButton icon="dots-three" label="More" variant="glass" size={44} iconSize={22} aria-expanded={menu} aria-haspopup="menu" onClick={() => setMenu(!menu)} />
            <IconButton icon="user" label="Profile" variant="glass" size={44} iconSize={24} style={{ color: "var(--brand-600)" }} onClick={onProfile} />
            {menu && (
              <div className="k-menu" role="menu">
                <button type="button" role="menuitem" onClick={() => (setMenu(false), onToggleHidden())}>
                  <Icon name="eye-slash" size={20} />
                  {hidden ? "Show amounts" : "Hide amounts"}
                </button>
                <button type="button" role="menuitem" disabled={!care.length} onClick={() => (setMenu(false), setRoute({ kind: "family" }))}>
                  <Icon name="heart" size={20} />
                  For your family
                </button>
              </div>
            )}
          </div>
        }
      />
      <div className="k-page">
        <Segmented
          label="Finance view"
          value={view}
          onChange={setView}
          options={[
            { value: "overview", label: "Overview" },
            { value: "total", label: "Total Asset" },
            { value: "debt", label: "Debt" },
          ]}
        />
        {view === "overview" && (
          <Overview
            assets={assets}
            moves={moves}
            worth={worth}
            bills={bills}
            loans={loans}
            care={care}
            entries={entries}
            birthYear={birthYear}
            hidden={hidden}
            today={today}
            onAdd={() => setAdding("new")}
            onRoute={setRoute}
            plans={act.depositPlans}
            onPlans={act.onDepositPlans}
            fallbackPlan={act.savingGoal || savingPlan(today.slice(0, 7), today, entries, 0, false).suggested}
          />
        )}
        {view === "total" && <TotalAssets assets={assets} moves={moves} hidden={hidden} today={today} onOpen={(id) => setRoute({ kind: "asset", id })} {...act} />}
        {view === "debt" && <Debt bills={bills} loans={loans} hidden={hidden} today={today} {...act} />}
      </div>
      {adding === "new" && <AddAssetSheet goldPremium={act.goldPremium} onClose={() => setAdding(null)} onSave={act.onAddAsset} />}
      {adding === "note" && (
        <AssetImportSheet
          assets={assets}
          goldPremium={act.goldPremium}
          today={today}
          onClose={() => setAdding(null)}
          onAdd={act.onAddAsset}
          onUpdate={(id, d) => {
            const a = assets.find((x) => x.id === id)
            if (d.quantity && d.unit && a?.unit === d.unit) return act.onMoveUnits(id, "value", d.quantity, today)
            if (d.quantity && d.unit) act.onSetHolding(id, d.quantity, d.unit)
            if (d.amount) act.onMoveAsset(id, "value", d.amount, today)
          }}
        />
      )}
    </div>
  )
}

/* ── Overview ───────────────────────────────────────────── */

function Overview({
  assets,
  worth,
  bills,
  loans,
  care,
  entries,
  birthYear,
  hidden,
  today,
  onAdd,
  onRoute,
  moves,
  plans,
  onPlans,
  fallbackPlan,
}: {
  moves: AssetMove[]
  plans: Record<string, number>
  onPlans: (p: Record<string, number>) => void
  fallbackPlan: number
  assets: Asset[]
  worth: WorthPoint[]
  bills: Bill[]
  loans: FamilyLoan[]
  care: CareGift[]
  entries: Entry[]
  birthYear?: number
  hidden: boolean
  today: string
  onAdd: () => void
  onRoute: (r: Route) => void
}) {
  const [range, setRange] = useState<Range>(6)
  const [picked, setPicked] = useState<string | null>(null)
  const [group, setGroup] = useState<AssetKind | null>(null)
  if (!assets.length)
    return (
      <div className="fin2-empty">
        <b>Nothing written down yet</b>
        <p>Add what you keep — cash, savings, gold, a fund — and this page adds it up. Nothing connects to your bank.</p>
        <button type="button" className="k-btn" onClick={onAdd}>
          <Icon name="plus" size={18} />
          Add an asset
        </button>
      </div>
    )
  const sh = shares(assets)
  const growth = worthGrowth(worth)
  const owed = monthSummary(bills, ym(today)).totalRemaining + loansOwed(loans, today)
  const series = fillMonths(worth, today.slice(0, 7))
  const deposits = depositsByMonth(moves, today)
  const point = series.find((p) => p.month === picked)
  const putIn = point ? deposits[point.month] : undefined
  const selfTotal = selfLines(entries, bills).reduce((t, l) => t + l.amount, 0)
  return (
    <>
      <div className="fin2-total">
        <div className="fin2-total__head">
          <div>
            <p className={point ? "is-picked" : ""}>{point ? `Total Asset · ${monthTitle(point.month)}` : "Total Asset"}</p>
            <AmountText value={point?.value ?? sh.total} hidden={hidden} />
            {point && putIn != null && !hidden && <span className="fin2-badge">Put in {compact(putIn)}</span>}
            {!point && growth != null && !hidden && (
              <span className="fin2-badge">
                <Icon name={growth < 0 ? "arrow-down-right" : "arrow-up-right"} size={12} />
                {Math.abs(growth)}%
              </span>
            )}
          </div>
          <label className="today-head__range">
            <select
              value={range}
              aria-label="Show"
              onChange={(e) => {
                setRange(Number(e.target.value) as Range)
                setPicked(null)
              }}
            >
              {RANGES.map((r) => (
                <option key={r.value} value={r.value}>
                  {r.label}
                </option>
              ))}
            </select>
            <span aria-hidden="true">{RANGES.find((r) => r.value === range)!.short}</span>
            <Icon name="caret-up-down" size={14} />
          </label>
        </div>
        {series.length > 1 ? (
          <WorthChart points={range ? series.slice(-range) : series} deposits={deposits} picked={picked} hidden={hidden} onPick={setPicked} />
        ) : (
          <p className="k-note fin2-total__none">The line appears after your second month of updates.</p>
        )}
        <NetWorthBar assets={sh.total} owed={owed} hidden={hidden} />
      </div>

      {/* Every month money went in, year by year. */}
      {moves.some((m) => m.kind !== "value" && m.amount > 0) && <DepositDots moves={moves} today={today} hidden={hidden} plans={plans} onPlans={onPlans} fallback={fallbackPlan} />}

      <div className="fin2-card">
        <AssetsPie assets={assets} hidden={hidden} picked={group} onPick={setGroup} />
      </div>
      <div className="fin2-card">
        <DebtPie bills={bills} loans={loans} today={today} hidden={hidden} />
      </div>

      <div className="fin2-people">
        <SectionTitle title="Invested in people" />
        <div className="fin2-people__row">
          <LifeCard
            tint="family"
            title="Your family"
            amount={care.reduce((t, c) => t + c.amount, 0)}
            sub={care.length ? sinceText(care, birthYear) : "Nothing yet"}
            hidden={hidden}
            onClick={() => onRoute({ kind: "family" })}
          />
          <LifeCard tint="yourself" title="Yourself" amount={selfTotal} sub="Learning, moving and health" hidden={hidden} onClick={() => onRoute({ kind: "yourself" })} />
        </div>
      </div>
    </>
  )
}

/** Percent up or down on a year ago (or the first month when there's less). */
function worthGrowth(worth: WorthPoint[]) {
  if (worth.length < 2) return null
  const last = worth[worth.length - 1]
  const base = worth[Math.max(0, worth.length - 13)]
  return base.value ? Math.round(((last.value - base.value) / base.value) * 100) : null
}

/** Every month from the first point to now; a month nobody wrote down keeps the one before. */
export function fillMonths(points: WorthPoint[], now: string): WorthPoint[] {
  const sorted = [...points].sort((a, b) => a.month.localeCompare(b.month))
  if (!sorted.length) return []
  const out: WorthPoint[] = []
  let i = 0
  let value = sorted[0].value
  const end = sorted[sorted.length - 1].month > now ? sorted[sorted.length - 1].month : now
  for (let m = sorted[0].month; m <= end; m = addMonthsYm(m, 1)) {
    while (i < sorted.length && sorted[i].month <= m) value = sorted[i++].value
    out.push({ month: m, value })
  }
  return out
}

/** Money put in, summed by month ("2024-03": 4000000). Money taken out and value changes don't count. */
export function depositsByMonth(moves: AssetMove[], today: string) {
  const out: Record<string, number> = {}
  for (const m of moves) if (m.amount > 0 && m.kind !== "value" && m.kind !== "out" && m.date <= today) out[m.date.slice(0, 7)] = (out[m.date.slice(0, 7)] ?? 0) + m.amount
  return out
}

/**
 * Total assets month by month, edge to edge: a soft line over a fading fill, floored at 0đ;
 * a dot on the bar under it for each month money went in; touch a month to read it.
 */
function WorthChart({
  points,
  deposits,
  picked,
  hidden,
  onPick,
}: {
  points: WorthPoint[]
  deposits: Record<string, number>
  picked: string | null
  hidden: boolean
  onPick: (m: string | null) => void
}) {
  const W = 360
  const H = 150
  const max = Math.max(...points.map((p) => p.value), 1)
  const min = Math.min(...points.map((p) => p.value))
  const lo = Math.max(0, min - (max - min) * 0.12)
  const x = (i: number) => (points.length === 1 ? W / 2 : (i / (points.length - 1)) * W)
  const y = (v: number) => H - 6 - ((v - lo) / (max - lo || 1)) * (H - 16)
  const line = points.map((p, i) => `${i ? "L" : "M"}${x(i).toFixed(1)} ${y(p.value).toFixed(1)}`).join(" ")
  const pi = Math.max(0, points.findIndex((p) => p.month === picked))
  const at = picked ? pi : points.length - 1
  const p = points[at]
  const years = points.length > 24
  const labelEvery = Math.ceil(points.length / 8)
  const box = useRef<HTMLDivElement>(null)
  const pickAt = (clientX: number) => {
    const r = box.current?.getBoundingClientRect()
    if (!r) return
    const i = Math.round(((clientX - r.left) / r.width) * (points.length - 1))
    const k = Math.min(points.length - 1, Math.max(0, i))
    onPick(k === points.length - 1 ? null : points[k].month)
  }
  const anyDeposit = points.some((pt) => deposits[pt.month])
  return (
    <div
      className="fin2-chart"
      ref={box}
      data-no-page-swipe
      onPointerDown={(e) => pickAt(e.clientX)}
      onPointerMove={(e) => e.buttons && pickAt(e.clientX)}
      role="img"
      aria-label={`Total asset from ${monthTitle(points[0].month)} to ${monthTitle(points[points.length - 1].month)}`}
    >
      <svg viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="none" aria-hidden="true">
        <defs>
          <linearGradient id="fin2-fill" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0" stopColor="var(--brand-500)" stopOpacity="0.22" />
            <stop offset="1" stopColor="var(--brand-500)" stopOpacity="0" />
          </linearGradient>
        </defs>
        <rect x={x(at) - W / points.length / 2} y="0" width={W / points.length} height={H} fill="var(--brand-500)" opacity="0.07" />
        <path d={`${line} L${W} ${H} L0 ${H} Z`} fill="url(#fin2-fill)" />
        <path d={line} fill="none" stroke="var(--brand-500)" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" vectorEffect="non-scaling-stroke" />
      </svg>
      <span className="fin2-chart__dot" style={{ left: `${(x(at) / W) * 100}%`, top: `${(y(p.value) / H) * 100}%` }} />
      {!hidden && (
        <span className="fin2-chart__pill" style={{ left: `clamp(32px, ${(x(at) / W) * 100}%, calc(100% - 32px))` }}>
          {compact(p.value)}
        </span>
      )}
      {/* The bar under the line: a dot for every month money went in. */}
      {anyDeposit && (
        <div className="fin2-chart__deposits" aria-hidden="true">
          {points.map((pt, i) =>
            deposits[pt.month] ? <i key={pt.month} className={i === at ? "is-on" : ""} style={{ left: `${(x(i) / W) * 100}%` }} /> : null,
          )}
        </div>
      )}
      {years ? (
        <div className="fin2-chart__years">
          {points.map((pt, i) =>
            pt.month.endsWith("-01") ? (
              <small key={pt.month} style={{ left: `${(x(i) / W) * 100}%` }}>
                {pt.month.slice(0, 4)}
              </small>
            ) : null,
          )}
        </div>
      ) : (
        <div className="fin2-chart__x">
          {points.map((pt, i) => (
            <small key={pt.month} className={i === at ? "is-on" : ""}>
              {i % labelEvery === (points.length - 1) % labelEvery ? monthTitle(pt.month).slice(0, 3) : ""}
            </small>
          ))}
        </div>
      )}
    </div>
  )
}

const LEVELS = ["Less", "On plan", "More"] as const
/** 0 less than the plan, 1 about the plan (90–120%), 2 more than the plan. */
const level = (sum: number, plan: number) => (plan <= 0 ? 1 : sum / plan < 0.9 ? 0 : sum / plan <= 1.2 ? 1 : 2)

/**
 * How often money went in: one row a year, one square a month, against that year's monthly plan
 * (tap the year to set it). Grey = nothing went in, then three greens: less, on plan, more.
 * A year with no plan uses the nearest earlier year's, else the saving goal.
 */
function DepositDots({
  moves,
  today,
  hidden,
  plans,
  onPlans,
  fallback,
}: {
  moves: AssetMove[]
  today: string
  hidden: boolean
  plans: Record<string, number>
  onPlans: (p: Record<string, number>) => void
  fallback: number
}) {
  const [picked, setPicked] = useState<string | null>(null)
  const [editing, setEditing] = useState<number | null>(null)
  const sums = depositsByMonth(moves, today)
  const now = today.slice(0, 7)
  const months = Object.keys(sums).sort()
  const first = months[0] ?? now
  const y0 = Number(first.slice(0, 4))
  const y1 = Number(now.slice(0, 4))
  const years = Array.from({ length: y1 - y0 + 1 }, (_, i) => y1 - i)
  const span = (y1 - y0) * 12 + Number(now.slice(5, 7)) - Number(first.slice(5, 7)) + 1
  const planFor = (y: number) => {
    if (plans[y] != null) return plans[y]
    const earlier = Object.keys(plans)
      .map(Number)
      .filter((k) => k < y)
      .sort((a, b) => b - a)[0]
    return earlier != null ? plans[earlier] : fallback
  }
  let best = 0
  let run = 0
  months.forEach((m, i) => {
    run = i > 0 && addMonthsYm(months[i - 1], 1) === m ? run + 1 : 1
    best = Math.max(best, run)
  })
  const focus = picked ?? now
  const lvl = (m: string) => level(sums[m], planFor(Number(m.slice(0, 4))))
  return (
    <section className="fin2-card dots" aria-label="How often you put money in">
      <p className="k-piecard__title">How often you put money in</p>
      <div className="dots__stats">
        <span>
          <b className="tnum">
            {months.length} of {span}
          </b>
          <small>months with money in</small>
        </span>
        <span>
          <b className="tnum">{best}</b>
          <small>months in a row, best</small>
        </span>
      </div>
      <div className="dots__grid">
        <span className="dots__head" />
        {monthsShortList.map((m, i) => (
          <span key={i} className="dots__head">
            {m[0]}
          </span>
        ))}
        {years.map((y) => (
          <div key={y} className="dots__row">
            <button type="button" className="dots__year" onClick={() => setEditing(y)} aria-label={`${y}: plan ${hidden ? "hidden" : money(planFor(y))} đ a month. Set the plan`}>
              {y}
              <small className={plans[y] != null ? "is-set" : ""}>{hidden ? "•••" : compact(planFor(y))}</small>
            </button>
            {monthsShortList.map((_, i) => {
              const m = `${y}-${String(i + 1).padStart(2, "0")}`
              const has = sums[m] != null
              return (
                <button
                  key={m}
                  type="button"
                  disabled={m > now}
                  className={`dots__sq${has ? ` is-l${lvl(m)}` : ""}${m > now || m < first ? " is-off" : ""}${m === focus ? " is-on" : ""}`}
                  aria-label={`${monthTitle(m)}: ${has ? `put in ${hidden ? "" : money(sums[m])}, ${LEVELS[lvl(m)].toLowerCase()}` : "nothing put in"}`}
                  onClick={() => setPicked(m === picked ? null : m)}
                />
              )
            })}
          </div>
        ))}
      </div>
      <div className="dots__legend" aria-hidden="true">
        <span>
          <i className="dots__sq" /> None
        </span>
        {LEVELS.map((n, i) => (
          <span key={n}>
            <i className={`dots__sq is-l${i}`} /> {n}
          </span>
        ))}
      </div>
      <p className="k-note">
        {monthTitle(focus)} · {sums[focus] != null ? `put in ${hidden ? "•••" : `${compact(sums[focus])}đ`} · ${LEVELS[lvl(focus)].toLowerCase()}` : "nothing put in"}
      </p>
      {editing != null && (
        <NumberSheet
          title={`Plan for ${editing}`}
          prompt={`How much do you plan to put in each month of ${editing}?`}
          start={planFor(editing)}
          note={`Each month of ${editing} is compared with this: less, on plan or more.`}
          onClose={() => setEditing(null)}
          onSave={(v) => onPlans({ ...plans, [editing]: v })}
        />
      )}
    </section>
  )
}

/** Net worth today — total assets less what's owed — as one bar split between the two. */
function NetWorthBar({ assets, owed, hidden }: { assets: number; owed: number; hidden: boolean }) {
  const net = assets - owed
  const netPct = pct(Math.max(net, 0), Math.max(assets, 1))
  return (
    <div className="fin2-net">
      <div className="fin2-net__head">
        <span>Net worth</span>
        <b className="tnum">{hidden ? "••••••" : `${net < 0 ? "-" : ""}${money(Math.abs(net))}đ`}</b>
      </div>
      <div className="fin2-net__bar" aria-hidden="true">
        {net > 0 && <span style={{ width: `${netPct}%`, background: "var(--brand-500)" }} />}
        {owed > 0 && <span style={{ flex: 1, background: "#f97066" }} />}
      </div>
      <div className="fin2-net__legend">
        <span>
          <i style={{ background: "var(--brand-500)" }} /> Net worth <b>{netPct}%</b>
        </span>
        <span>
          <i style={{ background: "#f97066" }} /> Debt {hidden ? "" : compact(owed)} <b>{100 - netPct}%</b>
        </span>
      </div>
      <p className="k-note">All you own, less installments and family loans still owed.</p>
    </div>
  )
}

/** What you own by group, as a ring; tap a group to filter (Total Asset) or read its share. */
function AssetsPie({ assets, hidden, picked, onPick }: { assets: Asset[]; hidden: boolean; picked: AssetKind | null; onPick: (k: AssetKind | null) => void }) {
  const sh = shares(assets)
  const owned = sh.groups.filter((g) => g.sum > 0)
  const top = owned.reduce<(typeof owned)[number] | undefined>((m, g) => (!m || g.sum > m.sum ? g : m), undefined)
  const shown = owned.find((g) => g.kind === picked) ?? top
  return (
    <PieCard
      title="Where your money is"
      chart={
        <Pie slices={owned.map((g) => ({ id: g.kind, value: g.sum, color: g.color }))} picked={picked}>
          {shown && (
            <>
              <b style={{ color: shown.color }}>{shown.pct}%</b>
              <small>{shown.label.toLowerCase()}</small>
            </>
          )}
        </Pie>
      }
      legend={sh.groups.map((g) => (
        <Legend key={g.kind} color={g.color} name={g.label} amount={maskC(hidden, g.sum)} pct={`${g.pct}%`} on={picked === g.kind} onClick={() => onPick(picked === g.kind ? null : g.kind)} />
      ))}
    />
  )
}

/** What you owe by source, as a solid pie with its slices apart. */
function DebtPie({ bills, loans, today, hidden }: { bills: Bill[]; loans: FamilyLoan[]; today: string; hidden: boolean }) {
  const rows = debts(bills, loans, today)
  const total = rows.reduce((t, r) => t + r.sum, 0)
  return (
    <PieCard
      title="Who you still owe"
      chart={
        <Pie slices={rows.map((r) => ({ id: r.name, value: r.sum, color: r.color }))} inner={0} gap={4}>
          {!rows.length && <small>None</small>}
        </Pie>
      }
      legend={rows.map((r) => <Legend key={r.name} color={r.color} name={r.name} amount={maskC(hidden, r.sum)} pct={pctText(r.sum, total)} />)}
    />
  )
}

/* ── Total Asset ─────────────────────────────────────────── */

function TotalAssets({
  assets,
  moves,
  hidden,
  today,
  onOpen,
  ...act
}: {
  assets: Asset[]
  moves: AssetMove[]
  hidden: boolean
  today: string
  onOpen: (id: string) => void
} & FinanceActions) {
  const [group, setGroup] = useState<AssetKind | null>(null)
  const [quick, setQuick] = useState<Asset | null>(null)
  const [history, setHistory] = useState(false)
  const held = assets.some((a) => a.unit && a.quantity)
  const worth = assets.reduce((t, a) => t + a.amount, 0)
  const putIn = assets.reduce((t, a) => t + (putInOf(a, moves) ?? a.amount), 0)
  const gain = worth - putIn
  const change = putIn ? (gain / putIn) * 100 : 0
  const list = group ? assets.filter((a) => a.kind === group) : assets
  return (
    <>
      <JoinedCard
        top={
          <StatCard
            label="Total asset"
            amount={worth}
            hidden={hidden}
            stats={[
              { label: "Put in", value: maskC(hidden, putIn) },
              { label: gain < 0 ? "Loss" : "Gain", value: hidden ? "•••" : `${gain < 0 ? "−" : "+"}${compact(Math.abs(gain))}`, gain: gain > 0 },
              { label: "Change", value: `${gain < 0 ? "−" : "+"}${Math.abs(change).toFixed(1)}%`, gain: gain > 0 },
            ]}
          />
        }
        bottom={<AssetsPie assets={assets} hidden={hidden} picked={group} onPick={setGroup} />}
      />
      <div style={{ marginTop: -8 }}>
        <HistoryLink sub={historySub(moves.map((m) => m.date))} onClick={() => setHistory(true)} />
      </div>
      {held && <PricesRow onSync={act.onSync} goldPremium={act.goldPremium} onGoldPremium={act.onGoldPremium} />}
      <Holdings title={group ? kindOf(group).label : "Assets"} assets={[...list].sort((a, b) => b.amount - a.amount)} moves={moves} hidden={hidden} onOpen={onOpen} onQuick={setQuick} />
      {quick && <QuickMoveSheet key={quick.id} asset={quick} moves={moves} today={today} goldPremium={act.goldPremium} onClose={() => setQuick(null)} onSave={act.onMoveAsset} onSaveUnits={act.onMoveUnits} />}
      {history && <AssetHistorySheet moves={moves} hidden={hidden} onClose={() => setHistory(false)} />}
    </>
  )
}

/**
 * "Today's prices · updated 14:05 · Sync": gold, foreign money and coins follow public prices.
 * Gold's premium over the world price (SJC is often 15–20% above) can be set here.
 */
function PricesRow({ onSync, goldPremium, onGoldPremium }: { onSync: () => Promise<boolean>; goldPremium: number; onGoldPremium: (p: number) => void }) {
  const [state, setState] = useState<"idle" | "busy" | "offline">("idle")
  const [at, setAt] = useState(pricesAt)
  const [premium, setPremium] = useState(String(goldPremium))
  const when = at ? new Date(at) : null
  const stamp = when ? (todayIso() === when.toISOString().slice(0, 10) ? `${String(when.getHours()).padStart(2, "0")}:${String(when.getMinutes()).padStart(2, "0")}` : shortDay(when.toISOString().slice(0, 10))) : "not yet"
  return (
    <div className="prices">
      <span className="prices__text">
        <b>Today&apos;s prices</b>
        <small>{state === "offline" ? "Couldn't reach the price lists — try again online." : `≈ updated ${stamp} · ${SOURCES}`}</small>
      </span>
      <button
        type="button"
        className="fin2-add"
        disabled={state === "busy"}
        onClick={async () => {
          setState("busy")
          const ok = await onSync()
          setAt(pricesAt())
          setState(ok ? "idle" : "offline")
        }}
      >
        <Icon name="history" size={14} />
        {state === "busy" ? "Syncing…" : "Sync"}
      </button>
      <label className="prices__premium">
        <span>Gold above world price</span>
        <span>
          <input
            inputMode="decimal"
            value={premium}
            aria-label="Gold premium, percent"
            onChange={(e) => setPremium(e.target.value.replace(/[^\d.]/g, ""))}
            onBlur={() => onGoldPremium(Number(premium) || 0)}
          />
          %
        </span>
      </label>
    </div>
  )
}

/** The assets as a list: tile, name with what went in, and what it's worth with the gain. */
export function Holdings({
  title,
  assets,
  moves,
  hidden,
  onOpen,
  onQuick,
}: {
  title: string
  assets: Asset[]
  moves: AssetMove[]
  hidden: boolean
  onOpen: (id: string) => void
  onQuick?: (a: Asset) => void
}) {
  return (
    <section className="fin2-section">
      <SectionTitle title={title} />
      <ListCard>
        {!assets.length && <p className="k-note fin2-pad">Nothing here yet.</p>}
        {assets.map((a) => {
          const put = putInOf(a, moves) ?? a.amount
          const ch = a.amount - put
          const p = put > 0 ? Math.round((ch / put) * 100) : 0
          const line = ch === 0 ? "No change" : `${ch > 0 ? "+" : "−"}${hidden ? "•••" : compact(Math.abs(ch))}${put > 0 ? ` · ${p === 0 ? "<1%" : `${ch > 0 ? "+" : "−"}${Math.abs(p)}%`}` : ""}`
          return (
            <ListRow
              key={a.id}
              tile={<AssetTile icon={a.icon} />}
              title={a.name}
              sub={`${a.unit && a.quantity ? `${holdingText(a.quantity, a.unit)} · ` : ""}${hidden ? "" : `in ${compact(put)} · `}${shortDay(a.updated)}`}
              amount={hidden ? "•••" : `${money(a.amount)}đ`}
              amountSub={line}
              amountSubTone={ch > 0 ? "gain" : "muted"}
              onClick={() => onOpen(a.id)}
              onAmount={onQuick ? () => onQuick(a) : undefined}
              label={`${a.name}, open`}
            />
          )
        })}
      </ListCard>
    </section>
  )
}

/* ── Debt ─────────────────────────────────────────────────── */

function Debt({ bills, loans, hidden, today, ...act }: { bills: Bill[]; loans: FamilyLoan[]; hidden: boolean; today: string } & FinanceActions) {
  const [history, setHistory] = useState(false)
  const [adding, setAdding] = useState(false)
  const [person, setPerson] = useState<string | null>(null)
  const d = installmentDebt(bills)
  const month = ym(today)
  const monthly = d.rows.reduce((t, r) => t + r.bill.amount, 0)
  const family = loanPeople(loans, today)
  const familyOwed = family.reduce((t, p) => t + p.owed, 0)
  const colors = Object.fromEntries(debts(bills, loans, today).map((r) => [r.name, r.color]))
  const dates = [...bills.filter((b) => b.kind === "installment").flatMap((b) => Object.values(b.paid).map((p) => new Date(p.at).toISOString().slice(0, 10))), ...loans.map((l) => l.date)]
  return (
    <>
      <JoinedCard
        top={
          <StatCard
            label="Still to pay"
            amount={d.total + familyOwed}
            hidden={hidden}
            stats={[
              { label: "Installments", value: maskC(hidden, d.total) },
              { label: "Family", value: maskC(hidden, familyOwed) },
              { label: "A month", value: maskC(hidden, monthly) },
            ]}
          />
        }
        bottom={<DebtPie bills={bills} loans={loans} today={today} hidden={hidden} />}
      />
      <div style={{ marginTop: -8 }}>
        <HistoryLink sub={historySub(dates)} onClick={() => setHistory(true)} />
      </div>

      <section className="fin2-section">
        <SectionTitle title="Family loans">
          <button type="button" className="fin2-add" onClick={() => setAdding(true)}>
            <Icon name="plus" size={14} />
            Add
          </button>
        </SectionTitle>
        <ListCard>
          {!family.length && <p className="k-note fin2-pad">Money from family you&apos;ll pay back goes here, with its interest.</p>}
          {family.map((p) => (
            <ListRow
              key={p.who}
              tile={<span className="k-tile" style={{ width: 40, height: 40, background: colors[p.who] ?? "var(--grey-400)", fontSize: 16 }}>{p.who.slice(0, 1).toUpperCase()}</span>}
              title={p.who}
              sub={`${hidden ? "" : `got ${compact(p.principal)} · `}${p.rate}% a year`}
              amount={hidden ? "•••" : `${money(p.owed)}đ`}
              amountSub={hidden ? "•••" : `+${compact(Math.max(0, p.interest - p.interestPaid))} interest`}
              onClick={() => setPerson(p.who)}
            />
          ))}
          <p className="k-note fin2-foot">Interest runs day by day on what&apos;s still borrowed. Paying interest takes it off first.</p>
        </ListCard>
      </section>

      {d.rows.length ? (
        <section className="fin2-section">
          <SectionTitle title="Installments" />
          <div className="fin2-table">
            <div className="fin2-table__head">
              <span>Installment</span>
              <span>Paid</span>
              <span>Left</span>
              <span>{monthTitle(month).slice(0, 3)}</span>
            </div>
            {d.rows.map((r) => {
              const due = !!dueIn(r.bill, month)
              const paidNow = !!r.bill.paid[month]
              return (
                <div key={r.bill.id} className="fin2-table__row">
                  <span className="fin2-table__name">
                    <b>{r.bill.name}</b>
                    <small>
                      {r.bill.lender ? `${r.bill.lender} · ` : ""}
                      {maskC(hidden, r.bill.amount)}/month
                    </small>
                    <progress value={r.paid} max={Math.max(r.bill.payments ?? 1, 1)} />
                  </span>
                  <span className="tnum">
                    {r.paid}/{r.bill.payments ?? 0}
                  </span>
                  <b className="tnum">{maskC(hidden, r.owe)}</b>
                  <button
                    type="button"
                    className={`due2-tick${paidNow ? " is-on" : ""}`}
                    disabled={!due}
                    aria-label={paidNow ? `Mark ${r.bill.name} as not paid` : `Mark ${r.bill.name} as paid`}
                    onClick={() => act.onToggleBill(r.bill, !paidNow)}
                  >
                    <TickMark on={paidNow} />
                  </button>
                </div>
              )
            })}
            <p className="k-note fin2-foot">Tick a month here or in Due — both stay in step.</p>
          </div>
        </section>
      ) : (
        <p className="k-note" style={{ textAlign: "center" }}>
          No installments left to pay.
        </p>
      )}

      {history && <DebtHistorySheet bills={bills} loans={loans} hidden={hidden} onClose={() => setHistory(false)} />}
      {adding && <AddLoanSheet people={[...new Set(loans.map((l) => l.who))].sort()} today={today} onClose={() => setAdding(false)} onSave={act.onAddLoan} />}
      {person && (
        <LoanPersonSheet
          who={person}
          loans={loans.filter((l) => l.who === person)}
          today={today}
          hidden={hidden}
          onClose={() => setPerson(null)}
          onAdd={() => setAdding(true)}
          onRemove={act.onRemoveLoan}
        />
      )}
    </>
  )
}


