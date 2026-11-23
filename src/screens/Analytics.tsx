import { useEffect, useMemo, useRef, useState, type ReactNode } from "react"
import { Icon, type IconName } from "../components/Icon"
import { Legend, Pie, Segmented, pct, pctText } from "../components/kit"
import { usePageSwipe } from "../lib/pageSwipe"
import { addDays, addMonthsYm, compact, money } from "../lib/format"
import {
  INCOME_COLOR,
  KIND_LOOK,
  NEEDS,
  NEED_COLOR,
  NEED_HINT,
  PERIODS,
  incomeKind,
  makeBars,
  monthsLong,
  monthsShort,
  niceMax,
  periodRange,
  periodTitle,
  savingPlan,
  spendKind,
  spendNeed,
  type Bar,
  type IncomeKind,
  type Need,
  type Period,
} from "../lib/analysis"
import { SAVINGS_ID, type AssetMove } from "../lib/assets"
import type { Entry } from "../lib/store"
import NumberSheet from "./NumberSheet"
import "./analytics.css"

type Flow = "all" | "out" | "in"
type Series = "Income" | "Expenses" | "Kept"
const SERIES_COLOR: Record<Series, string> = { Income: "var(--brand-500)", Expenses: "#ff8000", Kept: "#2e90fa" }
const ORANGE = "#ff8000"

/**
 * View Analysis — from the chart button on Today's green card. D / W / M / Y / All, the picked
 * period and its amount, bars (dark = money out, striped green = money in), the All / out / in
 * filter, then cards built from the user's own lines that follow the filter.
 */
export default function Analytics({
  entries,
  moves,
  start,
  today,
  hidden,
  savingGoal,
  countBills,
  onPrefs,
  onPutAside,
  onUndoPutAside,
  onClose,
}: {
  entries: Entry[]
  moves: AssetMove[]
  start: string
  today: string
  hidden: boolean
  savingGoal: number
  countBills: boolean
  onPrefs: (p: { savingGoal?: number; countBills?: boolean }) => void
  onPutAside: (amount: number, date: string) => void
  onUndoPutAside: (date: string) => void
  onClose: () => void
}) {
  const [anchor, setAnchor] = useState(start > today ? today : start)
  const [period, setPeriod] = useState<Period>("week")
  const [flow, setFlow] = useState<Flow>("all")
  const [picked, setPicked] = useState<number | null>(null)
  const all = useMemo(() => ({ from: entries.reduce((m, e) => (e.date < m ? e.date : m), today), to: today }), [entries, today])
  const bars = useMemo(() => makeBars(period, anchor, all, entries), [period, anchor, all, entries])
  const shown = picked != null ? bars[picked] : null
  const out = bars.reduce((t, b) => t + b.out, 0)
  const incoming = bars.reduce((t, b) => t + b.incoming, 0)
  const vOut = shown?.out ?? out
  const vIn = shown?.incoming ?? incoming
  const value = flow === "out" ? vOut : flow === "in" ? vIn : vIn - vOut
  const span = periodRange(period, anchor, all)
  const spanLines = entries.filter((e) => e.date >= span.from && e.date <= span.to)
  const month = (period === "all" ? today : anchor).slice(0, 7)

  // Swipe the top for the period before or after (never past today).
  const shift = (step: number) => {
    if (period === "all") return
    const next =
      period === "day"
        ? addDays(anchor, step)
        : period === "week"
          ? addDays(anchor, 7 * step)
          : `${addMonthsYm(anchor.slice(0, 7), period === "month" ? step : 12 * step)}-${String(Math.min(Number(anchor.slice(8, 10)), 28)).padStart(2, "0")}`
    if (next > today && step > 0 && anchor >= today) return
    setAnchor(next > today ? today : next)
    setPicked(null)
  }
  const swipe = usePageSwipe(shift)

  return (
    <div className="ana" role="dialog" aria-label="View Analysis">
      <header className="ana__bar">
        <button type="button" className="k-iconbtn" aria-label="Close" onClick={onClose}>
          <Icon name="arrow-left" size={20} />
        </button>
        <h1>View Analysis</h1>
        <span style={{ width: 44 }} />
      </header>

      <div className="ana__scroll">
        <section className="ana__top" {...swipe}>
          <Segmented
            label="Period"
            options={PERIODS}
            value={period}
            onChange={(p) => {
              setPeriod(p)
              setPicked(null)
            }}
          />
          <div className="ana__amount">
            <p>{shown?.title ?? periodTitle(period, anchor)}</p>
            <span className="tnum">
              {hidden ? "••••••" : `${value < 0 ? "-" : ""}${money(Math.abs(value))}`}
              <small>đ</small>
            </span>
          </div>
          {period !== "day" && (
            <BarChart
              bars={bars}
              flow={flow}
              picked={picked}
              hidden={hidden}
              unit={period === "year" || (period === "all" && bars.length && bars[0].label.length === 3) ? "month" : "day"}
              focus={period === "month" ? Number(anchor.slice(8, 10)) - 1 : period === "year" ? Number(anchor.slice(5, 7)) - 1 : period === "all" ? bars.length - 1 : null}
              onPick={(i) => setPicked(picked === i ? null : i)}
            />
          )}
          <FlowFilter flow={flow} onFlow={setFlow} out={out} incoming={incoming} hidden={hidden} />
        </section>

        <div className="ana__cards">
          {flow !== "in" && <WhereItWent lines={spanLines} hidden={hidden} />}
          {flow !== "in" && <Trend entries={entries} today={today} first={all.from} hidden={hidden} />}
          {flow !== "out" && <CameFrom lines={spanLines} hidden={hidden} />}
          {(period === "year" || period === "all") && (
            <OverMonths entries={entries} period={period} anchor={anchor} today={today} first={all.from} hidden={hidden} initial={flow === "out" ? "Expenses" : "Income"} />
          )}
          {flow !== "out" && (
            <Kept
              entries={entries}
              moves={moves}
              month={month}
              today={today}
              day={period === "day" ? anchor : null}
              hidden={hidden}
              goalSetting={savingGoal}
              countBills={countBills}
              onPrefs={onPrefs}
              onPutAside={onPutAside}
              onUndoPutAside={onUndoPutAside}
            />
          )}
          {flow !== "in" && <Biggest lines={entries.filter((e) => e.flow === "out" && e.date.startsWith(month))} hidden={hidden} />}
        </div>
      </div>
    </div>
  )
}

/* ── Top: bars and filter ───────────────────────────────── */

function BarChart({
  bars,
  flow,
  picked,
  hidden,
  unit,
  focus,
  onPick,
}: {
  bars: Bar[]
  flow: Flow
  picked: number | null
  hidden: boolean
  unit: string
  focus: number | null
  onPick: (i: number) => void
}) {
  const plot = 190
  const axis = 40
  const gap = 10
  const box = useRef<HTMLDivElement>(null)
  const scroller = useRef<HTMLDivElement>(null)
  const [room, setRoom] = useState(300)
  useEffect(() => {
    const w = (box.current?.clientWidth ?? 340) - axis
    setRoom(w)
  }, [])
  const n = Math.max(bars.length, 1)
  const group = Math.max(36, (room - gap * (n - 1)) / n)
  const width = group * n + gap * (n - 1)
  const showOut = flow !== "in"
  const showIn = flow !== "out"
  const top = niceMax(Math.max(0, ...bars.map((b) => Math.max(showOut ? b.out : 0, showIn ? b.incoming : 0))))
  // Bring the day or month being looked at into view.
  useEffect(() => {
    const el = scroller.current
    if (!el || focus == null || width <= room) return
    el.scrollLeft = Math.max(0, focus * (group + gap) - room / 2 + group / 2)
  }, [focus, width, room, group, bars.length])
  const values = bars.map((b) => (flow === "in" ? b.incoming : b.out))
  const avg = values.length ? values.reduce((t, v) => t + v, 0) / values.length : 0
  return (
    <div className="ana-chart" ref={box} data-no-page-swipe>
      <div className="ana-chart__scale" style={{ height: plot }} aria-hidden="true">
        {[0, 1, 2, 3, 4].map((k) => (
          <span key={k} style={{ bottom: (plot * k) / 4 }}>
            <i />
            {!hidden && <em>{compact((top * k) / 4)}</em>}
          </span>
        ))}
        {avg > 0 && (
          <span className="ana-chart__avg" style={{ bottom: Math.min(plot, (avg / top) * plot) }}>
            <i />
            {!hidden && <em>avg {compact(avg)}/{unit}</em>}
          </span>
        )}
      </div>
      <div className="ana-chart__scroll" ref={scroller} style={{ width: room }}>
        <div className="ana-chart__bars" style={{ width, gap, height: plot }}>
          {bars.map((b, i) => (
            <button
              key={i}
              type="button"
              className={`ana-chart__pair${picked != null && picked !== i ? " is-dim" : ""}`}
              style={{ width: group }}
              aria-label={`${b.title}: out ${hidden ? "hidden" : money(b.out)}, in ${hidden ? "hidden" : money(b.incoming)}`}
              onClick={() => onPick(i)}
            >
              {showOut && <span className="ana-chart__out" style={{ height: `${(b.out / top) * 100}%` }} />}
              {showIn && <span className="ana-chart__in" style={{ height: `${(b.incoming / top) * 100}%` }} />}
            </button>
          ))}
        </div>
        <div className="ana-chart__labels" style={{ width, gap }}>
          {bars.map((b, i) => (
            <span key={i} style={{ width: group }} className={picked === i ? "is-on" : ""}>
              {b.label}
            </span>
          ))}
        </div>
      </div>
    </div>
  )
}

function FlowFilter({ flow, onFlow, out, incoming, hidden }: { flow: Flow; onFlow: (f: Flow) => void; out: number; incoming: number; hidden: boolean }) {
  const short = (v: number) => (v >= 1_000_000 ? `${money(Math.floor(v / 1000))}K` : money(v))
  return (
    <div className="ana-flow" role="group" aria-label="Show">
      <div className="ana-flow__box">
        <button type="button" className={flow === "all" ? "is-on" : ""} aria-pressed={flow === "all"} onClick={() => onFlow("all")}>
          All
        </button>
      </div>
      <div className="ana-flow__box ana-flow__box--two">
        <button type="button" className={flow === "out" ? "is-on" : ""} aria-pressed={flow === "out"} onClick={() => onFlow("out")}>
          <span className="total__sign is-out">
            <Icon name="minus-circle" size={18} />
          </span>
          <span className="tnum">{hidden ? "••••" : short(out)}</span>
          <small>đ</small>
        </button>
        <button type="button" className={flow === "in" ? "is-on" : ""} aria-pressed={flow === "in"} onClick={() => onFlow("in")}>
          <span className="total__sign is-in">
            <Icon name="plus-circle" size={18} />
          </span>
          <span className="tnum">{hidden ? "••••" : short(incoming)}</span>
          <small>đ</small>
        </button>
      </div>
    </div>
  )
}

/* ── Cards ───────────────────────────────────────────────── */

function Card({ icon, tint, title, children }: { icon: IconName; tint: string; title: string; children: ReactNode }) {
  return (
    <section className="ana-card">
      <header>
        <span className="ana-card__icon" style={{ color: tint, background: `color-mix(in srgb, ${tint} 9%, transparent)` }}>
          <Icon name={icon} size={20} />
        </span>
        <h2>{title}</h2>
      </header>
      {children}
    </section>
  )
}

/** Where the money went, by how needed it was. Tap a group for its lines and kinds. */
function WhereItWent({ lines, hidden }: { lines: Entry[]; hidden: boolean }) {
  const [need, setNeed] = useState<Need | null>(null)
  const out = lines.filter((e) => e.flow === "out")
  const total = out.reduce((t, e) => t + e.amount, 0)
  const rows = NEEDS.map((n) => ({ need: n, sum: out.filter((e) => spendNeed(e) === n).reduce((t, e) => t + e.amount, 0) }))
  const pickedRow = rows.find((r) => r.need === need)
  return (
    <Card icon="chart-pie-slice" tint={ORANGE} title="Where it went">
      <div className="ana-split">
        <Pie slices={rows.map((r) => ({ id: r.need, value: r.sum, color: NEED_COLOR[r.need] }))} inner={0.72} picked={need} gap={2}>
          <b style={{ color: pickedRow ? NEED_COLOR[pickedRow.need] : "var(--text-900)" }}>{pickedRow ? `${pct(pickedRow.sum, total)}%` : hidden ? "••••" : compact(total)}</b>
          <small>{pickedRow ? pickedRow.need.toLowerCase() : "spent"}</small>
        </Pie>
        <div className="ana-split__legend">
          {rows.map((r) => (
            <Legend key={r.need} color={NEED_COLOR[r.need]} name={r.need} pct={`${pct(r.sum, total)}%`} on={need === r.need} onClick={() => setNeed(need === r.need ? null : r.need)} />
          ))}
        </div>
      </div>
      <p className="k-note">{need ? NEED_HINT[need] : "Tap a group to see what's in it."}</p>
      {need && (
        <div className="ana-detail">
          <b>{need} · Detail</b>
          <ItemList lines={out.filter((e) => spendNeed(e) === need)} hidden={hidden} color={NEED_COLOR[need]} byKind />
        </div>
      )}
    </Card>
  )
}

/** Money out month by month (this month with its likely end) against the average of the months before. */
function Trend({ entries, today, first, hidden }: { entries: Entry[]; today: string; first: string; hidden: boolean }) {
  const current = today.slice(0, 7)
  const months: string[] = []
  for (let m = addMonthsYm(current, -5); m <= current; m = addMonthsYm(m, 1)) if (m >= first.slice(0, 7)) months.push(m)
  if (!months.length) months.push(current)
  const outLines = entries.filter((e) => e.flow === "out")
  const spent = (m: string, upTo = 31) => outLines.filter((e) => e.date.startsWith(m) && Number(e.date.slice(8, 10)) <= upTo).reduce((t, e) => t + e.amount, 0)
  const d = Number(today.slice(8, 10))
  const days = new Date(Number(current.slice(0, 4)), Number(current.slice(5, 7)), 0).getDate()
  const soFar = spent(current)
  const everyday = outLines.filter((e) => e.date.startsWith(current) && e.category !== "Bills").reduce((t, e) => t + e.amount, 0)
  const projected = Math.floor((soFar + (everyday * (days - d)) / Math.max(d, 1)) / 1000) * 1000
  const partialFirst = Number(first.slice(8, 10)) > 1 ? first.slice(0, 7) : ""
  const past = months.slice(0, -1).filter((m) => m !== partialFirst).slice(-3).map((m) => spent(m))
  const average = past.length ? past.reduce((t, v) => t + v, 0) / past.length : 0
  const change = average ? (projected - average) / average : null
  const bars = months.map((m) => ({ m, spent: m === current ? soFar : spent(m), extra: m === current ? Math.max(0, projected - soFar) : 0 }))
  const top = niceMax(Math.max(average, ...bars.map((b) => b.spent + b.extra)))
  // Kinds that moved most against the same days last month.
  const before = addMonthsYm(current, -1)
  const sumBy = (list: Entry[]) => {
    const r = new Map<string, number>()
    for (const e of list) r.set(spendKind(e), (r.get(spendKind(e)) ?? 0) + e.amount)
    return r
  }
  const nowBy = sumBy(outLines.filter((e) => e.date.startsWith(current)))
  const thenBy = sumBy(outLines.filter((e) => e.date.startsWith(before) && Number(e.date.slice(8, 10)) <= d))
  const moves = [...new Set([...nowBy.keys(), ...thenBy.keys()])]
    .map((k) => ({ kind: k as keyof typeof KIND_LOOK, diff: (nowBy.get(k) ?? 0) - (thenBy.get(k) ?? 0) }))
    .filter((x) => Math.abs(x.diff) >= 50_000)
    .sort((a, b) => Math.abs(b.diff) - Math.abs(a.diff))
    .slice(0, 4)
  const gap = compact(Math.abs(projected - average)) + "đ"
  const sentence = !average || change == null
    ? "Keep writing things down — the trend shows up after a month or two."
    : Math.abs(change) < 0.05
      ? "You're spending about as usual this month."
      : change < 0
        ? `You're spending less than usual — at this pace you'll keep about ${hidden ? "a bit" : gap} more than an average month.`
        : `You're spending more than usual — about ${hidden ? "a bit" : gap} above an average month at this pace.`
  const good = change != null && change <= 0
  return (
    <Card icon="chart-line-up" tint="var(--success)" title="Trend">
      <div className="ana-big">
        <span className="tnum">
          {hidden ? "••••••" : money(projected)}
          <small>đ</small>
        </span>
        {change != null && (
          <em className={good ? "is-good" : ""}>
            {change <= 0 ? "↓" : "↑"} {(Math.abs(change) * 100).toFixed(1)}%
          </em>
        )}
      </div>
      {change != null && (
        <p className="k-note">
          likely by the end of {monthsLong[Number(current.slice(5, 7)) - 1]} · vs. your {past.length}-month average
        </p>
      )}
      <div className="ana-trend">
        {average > 0 && (
          <span className="ana-trend__avg" style={{ bottom: `calc(${(average / top) * 100}% + 20px)` }}>
            <em>{hidden ? "avg" : `avg ${compact(average)}`}</em>
          </span>
        )}
        {bars.map((b) => (
          <div key={b.m} className="ana-trend__col">
            <div className="ana-trend__stack">
              {b.extra > 0 && <span className="is-extra" style={{ height: `${(b.extra / top) * 100}%` }} />}
              <span className={b.m === current ? "is-now" : ""} style={{ height: `${(b.spent / top) * 100}%` }} />
            </div>
            <small>{monthsShort[Number(b.m.slice(5, 7)) - 1]}</small>
          </div>
        ))}
      </div>
      <p className="ana-text">{sentence}</p>
      {moves.length > 0 && (
        <div className="ana-moves">
          <small>vs. the same days last month</small>
          {moves.map((m) => (
            <div key={m.kind}>
              <i style={{ background: KIND_LOOK[m.kind].color }} />
              <span>{m.kind}</span>
              <b className={m.diff < 0 ? "is-good" : ""}>
                {m.diff < 0 ? "↓ " : "↑ "}
                {hidden ? "••••" : `${compact(Math.abs(m.diff))}đ`}
              </b>
            </div>
          ))}
        </div>
      )}
    </Card>
  )
}

/** Where money in came from (salary, a business, rent…). Tap a source for its lines. */
function CameFrom({ lines, hidden }: { lines: Entry[]; hidden: boolean }) {
  const [source, setSource] = useState<IncomeKind | null>(null)
  const incoming = lines.filter((e) => e.flow === "in")
  const total = incoming.reduce((t, e) => t + e.amount, 0)
  const map = new Map<IncomeKind, Entry[]>()
  for (const e of incoming) map.set(incomeKind(e), [...(map.get(incomeKind(e)) ?? []), e])
  const rows = [...map.entries()].map(([kind, list]) => ({ kind, list, sum: list.reduce((t, e) => t + e.amount, 0) })).sort((a, b) => b.sum - a.sum)
  const pickedRow = rows.find((r) => r.kind === source)
  return (
    <Card icon="wallet" tint="var(--success)" title="Where it came from">
      <div className="ana-split">
        <Pie slices={rows.map((r) => ({ id: r.kind, value: r.sum, color: INCOME_COLOR[r.kind] }))} inner={0.72} picked={source} gap={2}>
          <b style={{ color: pickedRow ? INCOME_COLOR[pickedRow.kind] : "var(--text-900)" }}>{pickedRow ? `${pct(pickedRow.sum, total)}%` : hidden ? "••••" : compact(total)}</b>
          <small>{pickedRow ? pickedRow.kind.toLowerCase() : "received"}</small>
        </Pie>
        <div className="ana-split__legend">
          {!rows.length && <p className="k-note">No money in here</p>}
          {rows.map((r) => (
            <Legend key={r.kind} color={INCOME_COLOR[r.kind]} name={r.kind} amount={hidden ? "••••" : compact(r.sum)} pct={pctText(r.sum, total)} on={source === r.kind} onClick={() => setSource(source === r.kind ? null : r.kind)} />
          ))}
        </div>
      </div>
      {pickedRow ? <ItemList lines={pickedRow.list} hidden={hidden} color={INCOME_COLOR[pickedRow.kind]} /> : rows.length > 0 && <p className="k-note">Tap a source to see what&apos;s in it.</p>}
    </Card>
  )
}

/** Money in, out or kept month by month, as a line. */
function OverMonths({ entries, period, anchor, today, first, hidden, initial }: { entries: Entry[]; period: Period; anchor: string; today: string; first: string; hidden: boolean; initial: Series }) {
  const [series, setSeries] = useState<Series>(initial)
  const [pick, setPick] = useState<string | null>(null)
  const nowM = today.slice(0, 7)
  const endRaw = period === "all" ? nowM : `${anchor.slice(0, 4)}-12`
  const end = endRaw < nowM ? endRaw : nowM
  const start = period === "all" ? first.slice(0, 7) : `${anchor.slice(0, 4)}-01`
  let months: string[] = []
  for (let m = start; m <= end; m = addMonthsYm(m, 1)) months.push(m)
  if (!months.length) months = [end]
  while (months.length > 3 && months[0] < first.slice(0, 7)) months.shift()
  const value = (m: string) => {
    const l = entries.filter((e) => e.date.startsWith(m))
    const i = l.filter((e) => e.flow === "in").reduce((t, e) => t + e.amount, 0)
    const o = l.filter((e) => e.flow === "out").reduce((t, e) => t + e.amount, 0)
    return series === "Income" ? i : series === "Expenses" ? o : i - o
  }
  const points = months.map((m) => ({ m, v: value(m) }))
  const p = points.find((x) => x.m === pick) ?? points[points.length - 1]
  const W = 320
  const H = 140
  const max = Math.max(...points.map((x) => x.v), 1)
  const min = Math.min(0, ...points.map((x) => x.v))
  const x = (i: number) => (points.length === 1 ? W / 2 : (i / (points.length - 1)) * W)
  const y = (v: number) => H - ((v - min) / (max - min || 1)) * (H - 12) - 6
  const line = points.map((pt, i) => `${i ? "L" : "M"}${x(i).toFixed(1)} ${y(pt.v).toFixed(1)}`).join(" ")
  const color = SERIES_COLOR[series]
  const pi = points.indexOf(p)
  return (
    <Card icon="chart-line-up" tint="var(--success)" title="Month by month">
      <div className="ana-series">
        <label className="ana-series__pick">
          <i style={{ background: color }} />
          <select value={series} onChange={(e) => setSeries(e.target.value as Series)} aria-label="Show">
            {(["Income", "Expenses", "Kept"] as const).map((s) => (
              <option key={s}>{s}</option>
            ))}
          </select>
          <span>{series}</span>
          <Icon name="caret-down" size={12} />
        </label>
        <span className="ana-series__when">{monthsLong[Number(p.m.slice(5, 7)) - 1]}</span>
        <b style={{ background: `color-mix(in srgb, ${color} 25%, transparent)` }}>{hidden ? "••••" : `${p.v < 0 ? "−" : ""}${compact(Math.abs(p.v))}đ`}</b>
      </div>
      <svg className="ana-line" viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="none" aria-hidden="true">
        <defs>
          <linearGradient id="ana-fill" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0" stopColor={color} stopOpacity="0.18" />
            <stop offset="1" stopColor={color} stopOpacity="0" />
          </linearGradient>
        </defs>
        <path d={`${line} L${x(points.length - 1)} ${H} L${x(0)} ${H} Z`} fill="url(#ana-fill)" />
        <path d={line} fill="none" stroke={color} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" vectorEffect="non-scaling-stroke" />
      </svg>
      <div className="ana-line__hits">
        {points.map((pt, i) => (
          <button key={pt.m} type="button" className={pt.m === p.m ? "is-on" : ""} onClick={() => setPick(pt.m)} aria-label={monthsLong[Number(pt.m.slice(5, 7)) - 1]}>
            {pt.m === p.m && <i style={{ borderColor: color, top: `${(y(pt.v) / H) * 100}%` }} />}
            <small>{points.length > 8 && i % 2 && i !== pi ? "" : monthsShort[Number(pt.m.slice(5, 7)) - 1]}</small>
          </button>
        ))}
      </div>
    </Card>
  )
}

/** Saving goal: how much of the month's goal is put aside, the daily budget, a dot per day. */
function Kept({
  entries,
  moves,
  month,
  today,
  day,
  hidden,
  goalSetting,
  countBills,
  onPrefs,
  onPutAside,
  onUndoPutAside,
}: {
  entries: Entry[]
  moves: AssetMove[]
  month: string
  today: string
  day: string | null
  hidden: boolean
  goalSetting: number
  countBills: boolean
  onPrefs: (p: { savingGoal?: number; countBills?: boolean }) => void
  onPutAside: (amount: number, date: string) => void
  onUndoPutAside: (date: string) => void
}) {
  const [sheet, setSheet] = useState<"goal" | "save" | null>(null)
  const plan = savingPlan(month, today, entries, goalSetting, countBills)
  const saves = moves.filter((m) => m.assetId === SAVINGS_ID && m.kind === "in")
  const putAside = saves.filter((m) => m.date.startsWith(month)).reduce((t, m) => t + m.amount, 0)
  const savedToday = saves.filter((m) => m.date === today).reduce((t, m) => t + m.amount, 0)
  const leftToday = Math.max(0, plan.dailyBudget - plan.spent(today))
  const share = plan.goal ? Math.min(1, Math.max(0, putAside / plan.goal)) : 0
  const gold = "#ffc400"
  const m = (v: number) => (hidden ? "••••" : compact(v))
  const [yy, mm] = month.split("-").map(Number)
  const lead = (new Date(yy, mm - 1, 1).getDay() + 6) % 7
  const R = 55
  const C = 2 * Math.PI * R
  return (
    <Card icon="piggy-bank" tint="#e0a100" title="Saving goal">
      <div className="ana-goal">
        <div className="ana-ring">
          <svg viewBox="0 0 138 138" aria-hidden="true">
            <circle cx="69" cy="69" r={R} fill="none" stroke="#fff3c4" strokeWidth="14" />
            <circle cx="69" cy="69" r={R} fill="none" stroke={gold} strokeWidth="14" strokeLinecap="round" strokeDasharray={`${share * C} ${C}`} transform="rotate(-90 69 69)" />
          </svg>
          <span>
            <b>{Math.round(share * 100)}%</b>
            <small>of goal</small>
          </span>
        </div>
        <div className="ana-goal__stats">
          <button type="button" className="ana-stat ana-stat--btn" onClick={() => setSheet("goal")}>
            <b>
              {m(plan.goal)} <Icon name="pencil" size={14} />
            </b>
            <small>{goalSetting > 0 ? "Goal this month" : "Suggested goal"}</small>
          </button>
          <span className="ana-stat">
            <b>{m(putAside)}</b>
            <small>Put aside</small>
          </span>
          <span className="ana-stat">
            <b>{m(plan.dailyBudget)}</b>
            <small>To spend a day</small>
          </span>
        </div>
      </div>
      {day && (
        <div className="ana-day">
          <span className="ana-stat">
            <b>{m(plan.spent(day))}</b>
            <small>Spent this day</small>
          </span>
          <span className="ana-stat">
            <b>{hidden ? "••••" : `${plan.dailyBudget - plan.spent(day) < 0 ? "−" : ""}${compact(Math.abs(plan.dailyBudget - plan.spent(day)))}`}</b>
            <small>{plan.dailyBudget - plan.spent(day) >= 0 ? "Still fine to spend" : "Over the day's budget"}</small>
          </span>
        </div>
      )}
      <div className="ana-dots" aria-label="Days this month">
        {["M", "T", "W", "T", "F", "S", "S"].map((d, i) => (
          <small key={i}>{d}</small>
        ))}
        {Array.from({ length: lead }, (_, i) => (
          <span key={`l${i}`} />
        ))}
        {plan.days.map((d) => {
          const lv = plan.level(d)
          const ring = d === (day ?? today)
          return <span key={d} className={`ana-dot${lv == null ? " is-future" : ""}${ring ? " is-ring" : ""}`} style={lv != null ? { background: `color-mix(in srgb, ${gold} ${lv * 100}%, transparent)` } : undefined} />
        })}
      </div>
      <div className="ana-goal__foot">
        <p className="k-note">Darker days stayed further under the daily budget.</p>
        <label className="ana-check">
          <input type="checkbox" checked={countBills} onChange={(e) => onPrefs({ countBills: e.target.checked })} />
          Count bills
        </label>
      </div>
      {month === today.slice(0, 7) && (
        <>
          <div className="ana-save">
            <button
              type="button"
              className={`k-btn${savedToday ? "" : " is-gold"}`}
              disabled={!savedToday && !leftToday}
              onClick={() => (savedToday ? onUndoPutAside(today) : onPutAside(leftToday, today))}
            >
              <Icon name={savedToday ? "check-circle" : "piggy-bank"} size={18} />
              {savedToday ? `Saved today · ${hidden ? "••••" : `${compact(savedToday)}đ`}` : leftToday ? `Save today's ${hidden ? "••••" : `${compact(leftToday)}đ`}` : "Nothing left today"}
            </button>
            <button type="button" className="k-btn k-btn--soft" onClick={() => setSheet("save")}>
              Custom
            </button>
          </div>
          <p className="k-note">Only noted here and on Savings in Finance — no money moves.</p>
        </>
      )}
      {sheet && (
        <NumberSheet
          title={sheet === "goal" ? "Saving goal" : "Put aside"}
          prompt={sheet === "goal" ? "How much do you want to keep this month?" : "How much did you put aside?"}
          start={sheet === "goal" ? plan.goal : 0}
          note={sheet === "goal" ? `Suggested: ${compact(plan.suggested)}đ — from last month's spending, with a little room.` : `Left of today's budget: ${compact(leftToday)}đ`}
          onClose={() => setSheet(null)}
          onSave={(v) => (sheet === "goal" ? onPrefs({ savingGoal: v }) : onPutAside(v, today))}
        />
      )}
    </Card>
  )
}

/** The biggest single spends this month, as bars. */
function Biggest({ lines, hidden }: { lines: Entry[]; hidden: boolean }) {
  const top = [...lines].sort((a, b) => b.amount - a.amount).slice(0, 4)
  const max = top[0]?.amount ?? 1
  const colors = ["#00ba90", "#00c900", ORANGE, "#ff4d00"]
  return (
    <Card icon="receipt" tint={ORANGE} title="Biggest spends">
      {!top.length && <p className="k-note">No spending yet</p>}
      {top.map((e, i) => (
        <div key={e.id} className="ana-biggest">
          <div>
            <span>{e.title}</span>
            <b className="tnum">{hidden ? "••••" : `${money(e.amount)}đ`}</b>
          </div>
          <span className="ana-biggest__track" style={{ background: `color-mix(in srgb, ${colors[i]} 13%, transparent)` }}>
            <span style={{ width: `${Math.max(3, (e.amount / max) * 100)}%`, background: colors[i] }} />
          </span>
        </div>
      ))}
    </Card>
  )
}

/** The lines in a group, by kind when asked (Food & Drinks, Transportation…). */
function ItemList({ lines, hidden, color, byKind }: { lines: Entry[]; hidden: boolean; color: string; byKind?: boolean }) {
  const [all, setAll] = useState(false)
  if (byKind) {
    const map = new Map<string, number>()
    for (const e of lines) map.set(spendKind(e), (map.get(spendKind(e)) ?? 0) + e.amount)
    const kinds = [...map.entries()].sort((a, b) => b[1] - a[1])
    const total = lines.reduce((t, e) => t + e.amount, 0)
    return (
      <div className="ana-items">
        {kinds.map(([k, sum]) => {
          const look = KIND_LOOK[k as keyof typeof KIND_LOOK]
          return (
            <div key={k} className="ana-item">
              <span className="ana-item__icon" style={{ color: look.color, background: `color-mix(in srgb, ${look.color} 12%, transparent)` }}>
                <Icon name={look.icon} size={16} />
              </span>
              <span className="ana-item__name">{k}</span>
              <small>{pctText(sum, total)}</small>
              <b className="tnum">{hidden ? "••••" : `${compact(sum)}đ`}</b>
            </div>
          )
        })}
      </div>
    )
  }
  const sorted = [...lines].sort((a, b) => b.amount - a.amount)
  const shown = all ? sorted : sorted.slice(0, 5)
  return (
    <div className="ana-items">
      {shown.map((e) => (
        <div key={e.id} className="ana-item">
          <i style={{ background: color }} />
          <span className="ana-item__name">{e.title}</span>
          <small>{e.date.slice(8, 10)}/{e.date.slice(5, 7)}</small>
          <b className="tnum">{hidden ? "••••" : `${money(e.amount)}đ`}</b>
        </div>
      ))}
      {sorted.length > 5 && (
        <button type="button" className="ana-more" onClick={() => setAll(!all)}>
          {all ? "Show less" : `Show all ${sorted.length}`}
        </button>
      )}
    </div>
  )
}

