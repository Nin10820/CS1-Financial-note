import { useEffect, useMemo, useState, type ReactNode } from "react"
import { Icon, type IconName } from "../components/Icon"
import { AddingLead, AmountPad, AmountText, AssetTile, ListCard, ListRow, QuickPickCard, SectionTitle, Segmented, StatCard, TickMark, Tile, maskC } from "../components/kit"
import { UNITS, guessUnit, holdingText, price, readNumber, readUnits, refreshPrices, unitLabel, type HoldingUnit } from "../lib/market"
import StickyHeader from "../components/StickyHeader"
import { IconButton } from "../components/ui"
import { addDays, compact, money, monthTitle, shortDay, today as todayIso } from "../lib/format"
import {
  ASSET_TILE,
  KINDS,
  LOAN_LABEL,
  MOVE_LABEL,

  guessAssetIcon,
  kindOf,
  loanPerson,
  putInOf,
  readAssetSentence,
  readAssetLines,
  sameName,
  type AssetDraft,
  valueLine,
  type Asset,
  type AssetKind,
  type AssetMove,
  type AssetMoveKind,
  type CareGift,
  type FamilyLoan,
  type LoanMove,
} from "../lib/assets"
import { TILE, type Bill } from "../lib/bills"
import { uid, type Entry } from "../lib/store"
import { fold } from "../lib/analysis"
import type { FinanceActions } from "./Finance"
import ModalSheet, { ModalHeader } from "./ModalSheet"

const CloseBtn = ({ onClick, icon = "close", label = "Close" }: { onClick: () => void; icon?: IconName; label?: string }) => (
  <button type="button" className="k-iconbtn" aria-label={label} onClick={onClick}>
    <Icon name={icon} size={18} />
  </button>
)
const SaveBtn = ({ onClick, disabled }: { onClick: () => void; disabled?: boolean }) => (
  <button type="button" className="tpl__save" aria-label="Save" disabled={disabled} onClick={onClick}>
    <Icon name="check" size={22} />
  </button>
)

/** A full page inside a tab: back on the left, the title, an optional action on the right. */
function SubPage({ title, onBack, right, children }: { title: string; onBack: () => void; right?: ReactNode; children: ReactNode }) {
  useEffect(() => {
    window.scrollTo(0, 0)
  }, [])
  return (
    <div className="screen fin2">
      <StickyHeader title={title} center={<span className="k-topbar__title">{title}</span>} left={<IconButton icon="arrow-left" label="Back" variant="glass" size={44} onClick={onBack} />} right={right} />
      <div className="k-page">{children}</div>
    </div>
  )
}

/* ── Life cards: family (pink) and yourself (blue) ──────── */

type Tint = "family" | "yourself"
const TINT: Record<Tint, { accent: string; icon: IconName; reveal: string }> = {
  family: { accent: "var(--life-family)", icon: "heart", reveal: "The things you've given the people you love, that you may never have noticed…" },
  yourself: { accent: "var(--life-self)", icon: "heartbeat", reveal: "The things you've put into yourself — learning, moving, staying well…" },
}

export function LifeCard({ tint, title, amount, sub, hidden, onClick }: { tint: Tint; title: string; amount: number; sub: string; hidden: boolean; onClick: () => void }) {
  const t = TINT[tint]
  return (
    <button type="button" className={`life life--${tint}`} onClick={onClick}>
      <span className="life__top">
        <span className="life__icon" style={{ background: t.accent }}>
          <Icon name={t.icon} size={18} />
        </span>
        <Icon name="caret-right-sm" size={14} />
      </span>
      <span className="life__title" style={{ color: t.accent }}>
        {title}
      </span>
      <span className="life__amount tnum">
        {maskC(hidden, amount)}
        <small>đ</small>
      </span>
      <span className="life__sub">{sub}</span>
    </button>
  )
}

/** One quiet line for a moment, then the page. */
export function RevealPage({ tint, children }: { tint: Tint; children: ReactNode }) {
  const reduced = typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches
  const [shown, setShown] = useState(false)
  useEffect(() => {
    const t = setTimeout(() => setShown(true), reduced ? 900 : 2200)
    return () => clearTimeout(t)
  }, [reduced])
  if (shown) return <div className="reveal-in">{children}</div>
  const t = TINT[tint]
  return (
    <button type="button" className={`reveal life--${tint}`} onClick={() => setShown(true)} aria-label="Show the page">
      <span className="reveal__icon" style={{ background: t.accent }}>
        <Icon name={t.icon} size={28} />
      </span>
      <p>{t.reveal}</p>
    </button>
  )
}

export function sinceText(care: CareGift[], birthYear?: number) {
  const first = care.reduce((m, c) => (c.date < m ? c.date : m), care[0]?.date ?? todayIso())
  if (birthYear) return `You have carried this since you were ${Number(first.slice(0, 4)) - birthYear}.`
  return `You have carried this since ${monthTitle(first.slice(0, 7))}.`
}

export function FamilyPage({ care, entries, birthYear, hidden, onBack }: { care: CareGift[]; entries: Entry[]; birthYear?: number; hidden: boolean; onBack: () => void }) {
  const total = care.reduce((s, c) => s + c.amount, 0)
  const groups = useMemo(() => {
    const map = new Map<string, CareGift[]>()
    for (const c of care) map.set(c.who, [...(map.get(c.who) ?? []), c])
    return [...map.entries()].sort((a, b) => b[1].length - a[1].length)
  }, [care])
  const since = addDays(todayIso(), -30)
  const earned = entries.filter((e) => e.flow === "in" && e.date >= since).reduce((s, e) => s + e.amount, 0)
  const gave = care.filter((c) => c.date >= since).reduce((s, c) => s + c.amount, 0)
  const share = earned ? Math.round((gave / earned) * 100) : null
  const [all, setAll] = useState(false)
  const rows = [...care].sort((a, b) => b.date.localeCompare(a.date))
  const cadence = (who: string, list: CareGift[]) =>
    /tuition|brother|sister/i.test(who + list[0].title) ? `${list.length} terms of tuition` : /household/i.test(who) ? `${list.length} bills` : `every month, ${list.length} times`
  return (
    <SubPage title="Your family" onBack={onBack}>
      <div className="life-hero life--family">
        <p style={{ color: TINT.family.accent }}>Taken care of</p>
        <AmountText value={total} hidden={hidden} />
        <span>{sinceText(care, birthYear)}</span>
      </div>
      <p className="life-quote">
        Financial progress isn&apos;t only what you keep. <b>It&apos;s also what you carry for the people you love.</b>
        {share !== null && <small>About {share}% of what you earned in the last 30 days.</small>}
      </p>
      <ListCard>
        {groups.map(([who, list]) => (
          <ListRow
            key={who}
            tile={<Tile bg="var(--life-family)" icon="heart" />}
            title={who}
            sub={cadence(who, list)}
            amount={hidden ? "•••" : `${money(list.reduce((t, c) => t + c.amount, 0))}đ`}
          />
        ))}
      </ListCard>
      <SectionTitle title="History" />
      <ListCard>
        {(all ? rows : rows.slice(0, 8)).map((c) => (
          <ListRow key={c.id} tile={<Tile bg="var(--life-family)" icon="gift" />} title={c.title} sub={`${c.who} · ${shortDay(c.date)}`} amount={hidden ? "•••" : `${money(c.amount)}đ`} />
        ))}
        {rows.length > 8 && (
          <button type="button" className="fin2-more" onClick={() => setAll(!all)}>
            {all ? "Show less" : `Show all ${rows.length}`}
          </button>
        )}
      </ListCard>
    </SubPage>
  )
}

/* ── Yourself ───────────────────────────────────────────── */

type SelfGroup = "Learning" | "Moving" | "Health"
const SELF: Record<SelfGroup, { icon: IconName; color: string; words: string[] }> = {
  Learning: { icon: "graduation-cap", color: "#2e90fa", words: ["khoa hoc", "course", "sach", "book", "ielts", "toeic", "workshop", "tai lieu", "udemy", "lop hoc", "class", "hoc phi"] },
  Moving: { icon: "heartbeat", color: "#0ba5ec", words: ["gym", "boi", "yoga", "cau long", "chay bo", "swim", "tennis", "bong da", "pilates"] },
  Health: { icon: "heart", color: "#6172f3", words: ["kham", "thuoc", "vitamin", "nha khoa", "nieng rang", "tram rang"] },
}
type SelfLine = { id: string; group: SelfGroup; title: string; date: string; amount: number }

/** What was spent on yourself, found in what you already wrote down, plus study installments paid. */
export function selfLines(entries: Entry[], bills: Bill[]): SelfLine[] {
  const groupOf = (title: string): SelfGroup | null => {
    const t = fold(title)
    if (t.includes(" gui xe ")) return null
    return (Object.keys(SELF) as SelfGroup[]).find((g) => SELF[g].words.some((w) => t.includes(w))) ?? null
  }
  const spent = entries
    .filter((e) => e.flow === "out")
    .flatMap((e) => {
      const g = groupOf(e.title)
      return g ? [{ id: e.id, group: g, title: e.title, date: e.date, amount: e.amount }] : []
    })
  const study = bills
    .filter((b) => b.icon === "student")
    .flatMap((b) => Object.entries(b.paid).map(([m, r]) => ({ id: `${b.id}-${m}`, group: "Learning" as const, title: b.name, date: new Date(r.at).toISOString().slice(0, 10), amount: r.amount })))
  return [...spent, ...study].sort((a, b) => b.date.localeCompare(a.date))
}

export function YourselfPage({ entries, bills, hidden, onBack }: { entries: Entry[]; bills: Bill[]; hidden: boolean; onBack: () => void }) {
  const lines = selfLines(entries, bills)
  const total = lines.reduce((t, l) => t + l.amount, 0)
  const [all, setAll] = useState(false)
  const groups = (Object.keys(SELF) as SelfGroup[]).map((g) => [g, lines.filter((l) => l.group === g)] as const).filter(([, l]) => l.length)
  return (
    <SubPage title="Yourself" onBack={onBack}>
      {!lines.length ? (
        <div className="fin2-empty">
          <b>Nothing here yet</b>
          <p>Courses, books, the gym, a check-up — what you spend on yourself shows up here.</p>
        </div>
      ) : (
        <>
          <div className="life-hero life--yourself">
            <p style={{ color: TINT.yourself.accent }}>Invested in yourself</p>
            <AmountText value={total} hidden={hidden} />
            <span>
              {lines.length} things since {monthTitle(lines[lines.length - 1].date.slice(0, 7))}
            </span>
          </div>
          <p className="life-quote">
            Growing yourself isn&apos;t only spending. <b>It&apos;s what you carry into everything else.</b>
          </p>
          <ListCard>
            {groups.map(([g, l]) => (
              <ListRow
                key={g}
                tile={<Tile bg={SELF[g].color} icon={SELF[g].icon} />}
                title={g}
                sub={[...new Set(l.map((x) => x.title))].slice(0, 3).join(", ")}
                amount={hidden ? "•••" : `${money(l.reduce((t, x) => t + x.amount, 0))}đ`}
              />
            ))}
          </ListCard>
          <SectionTitle title="History" />
          <ListCard>
            {(all ? lines : lines.slice(0, 8)).map((l) => (
              <ListRow key={l.id} tile={<Tile bg={SELF[l.group].color} icon={SELF[l.group].icon} />} title={l.title} sub={`${l.group} · ${shortDay(l.date)}`} amount={hidden ? "•••" : `${money(l.amount)}đ`} />
            ))}
            {lines.length > 8 && (
              <button type="button" className="fin2-more" onClick={() => setAll(!all)}>
                {all ? "Show less" : `Show all ${lines.length}`}
              </button>
            )}
          </ListCard>
        </>
      )}
    </SubPage>
  )
}

/* ── One asset ───────────────────────────────────────────── */

export function AssetDetail({ asset, moves, hidden, today, onBack, ...act }: { asset: Asset; moves: AssetMove[]; hidden: boolean; today: string; onBack: () => void } & FinanceActions) {
  const [sheet, setSheet] = useState<AssetMoveKind | "edit" | null>(null)
  const [confirm, setConfirm] = useState(false)
  const put = putInOf(asset, moves)
  const line = valueLine(asset, moves)
  const mine = moves.filter((m) => m.assetId === asset.id).sort((a, b) => b.date.localeCompare(a.date))
  const gain = put != null ? asset.amount - put : null
  const t = ASSET_TILE[asset.icon]
  return (
    <SubPage
      title={asset.name}
      onBack={onBack}
      right={
        <div className="today-top">
          <IconButton icon="pencil" label="Edit" variant="glass" size={44} iconSize={20} onClick={() => setSheet("edit")} />
          <IconButton icon="trash" label="Delete" variant="glass" size={44} iconSize={20} onClick={() => setConfirm(true)} />
        </div>
      }
    >
      <div className="asset-head">
        <AssetTile icon={asset.icon} size={48} />
        <span>
          <b>{asset.name}</b>
          <small>
            {kindOf(asset.kind).label} · updated {shortDay(asset.updated)}
          </small>
        </span>
      </div>
      <div className="fin2-card">
        <StatCard
          label="Worth now"
          amount={asset.amount}
          hidden={hidden}
          stats={
            put != null && gain != null
              ? [
                  { label: "Put in", value: maskC(hidden, put) },
                  { label: gain < 0 ? "Loss" : "Growth", value: hidden ? "•••" : `${gain < 0 ? "−" : "+"}${compact(Math.abs(gain))}`, gain: gain > 0 },
                  { label: "Change", value: put ? `${gain < 0 ? "−" : "+"}${Math.abs(Math.round((gain / put) * 100))}%` : "—", gain: gain > 0 },
                ]
              : []
          }
        />
        {put == null && <p className="k-note fin2-pad">Add money or update the value once, and this shows how much you put in and how much it grew.</p>}
      </div>
      <div className="asset-actions">
        <button type="button" className="k-btn" onClick={() => setSheet("in")}>
          <Icon name="plus" size={16} />
          Add money
        </button>
        <button type="button" className="k-btn k-btn--soft" onClick={() => setSheet("out")}>
          Take out
        </button>
        <button type="button" className="k-btn k-btn--soft" onClick={() => setSheet("value")}>
          Update value
        </button>
      </div>
      {line.length > 1 && (
        <section className="fin2-section">
          <SectionTitle title="Over time" />
          <div className="fin2-card fin2-pad">
            <MiniLine points={line.map((p) => p.value)} color={t.bg} />
            <div className="asset-line__x">
              <small>{shortDay(line[0].date)}</small>
              <small>{shortDay(line[line.length - 1].date)}</small>
            </div>
          </div>
        </section>
      )}
      <section className="fin2-section">
        <SectionTitle title="History" />
        <ListCard>
          {!mine.length && <p className="k-note fin2-pad">Nothing recorded yet.</p>}
          {mine.map((m) => (
            <ListRow
              key={m.id}
              tile={<Tile bg={m.kind === "value" ? "var(--grey-400)" : m.amount < 0 ? "#e5562a" : "var(--brand-600)"} icon={m.kind === "value" ? "chart-line-up" : m.amount < 0 ? "arrow-up-right" : "arrow-down-right"} />}
              title={MOVE_LABEL[m.kind ?? "in"]}
              trailing={
                <button type="button" className="hist__del" aria-label={`Delete this ${MOVE_LABEL[m.kind ?? "in"].toLowerCase()} line`} onClick={() => act.onRemoveMove(m.id)}>
                  <Icon name="trash" size={16} />
                </button>
              }
              sub={shortDay(m.date)}
              amount={hidden ? "•••" : `${m.amount > 0 ? "+" : "−"}${money(Math.abs(m.amount))}đ`}
            />
          ))}
        </ListCard>
      </section>
      {sheet && sheet !== "edit" && <QuickMoveSheet asset={asset} moves={moves} today={today} start={sheet} goldPremium={act.goldPremium} onClose={() => setSheet(null)} onSave={act.onMoveAsset} onSaveUnits={act.onMoveUnits} />}
      {sheet === "edit" && <AddAssetSheet editing={asset} goldPremium={act.goldPremium} onClose={() => setSheet(null)} onSave={() => {}} onEdit={act.onEditAsset} onSetHolding={act.onSetHolding} />}
      {confirm && (
        <div className="confirm" role="alertdialog" aria-label="Delete asset">
          <div className="confirm__box">
            <b>Delete “{asset.name}”?</b>
            <p>Its history goes with it.</p>
            <button
              type="button"
              className="confirm__danger"
              onClick={() => {
                act.onRemoveAsset(asset.id)
                onBack()
              }}
            >
              Delete asset
            </button>
            <button type="button" onClick={() => setConfirm(false)}>
              Keep it
            </button>
          </div>
        </div>
      )}
    </SubPage>
  )
}

function MiniLine({ points, color }: { points: number[]; color: string }) {
  const W = 320
  const H = 110
  const max = Math.max(...points)
  const min = Math.min(...points, 0)
  const x = (i: number) => (i / (points.length - 1)) * W
  const y = (v: number) => H - 6 - ((v - min) / (max - min || 1)) * (H - 12)
  const d = points.map((v, i) => `${i ? "L" : "M"}${x(i).toFixed(1)} ${y(v).toFixed(1)}`).join(" ")
  return (
    <svg className="asset-line" viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="none" aria-hidden="true">
      <path d={`${d} L${W} ${H} L0 ${H} Z`} fill={color} opacity="0.12" />
      <path d={d} fill="none" stroke={color} strokeWidth="2.5" strokeLinejoin="round" vectorEffect="non-scaling-stroke" />
    </svg>
  )
}

/* ── Quick update ───────────────────────────────────────── */

/**
 * New worth, money put in or taken out — with put in / now / gain before → after, and the day.
 * An asset held in units (gold, dollars, coins) can be typed in its unit: 2 phân, 100 $.
 */
export function QuickMoveSheet({
  asset,
  moves,
  today,
  start = "value",
  goldPremium = 0,
  onClose,
  onSave,
  onSaveUnits,
}: {
  asset: Asset
  moves: AssetMove[]
  today: string
  start?: AssetMoveKind
  goldPremium?: number
  onClose: () => void
  onSave: FinanceActions["onMoveAsset"]
  onSaveUnits?: FinanceActions["onMoveUnits"]
}) {
  const [kind, setKind] = useState<AssetMoveKind>(start)
  const [value, setValue] = useState<number | null>(null)
  const [date, setDate] = useState(today)
  const unitPrice = asset.unit ? price(asset.unit, goldPremium) : null
  const [inUnits, setInUnits] = useState(!!(asset.unit && asset.quantity != null && unitPrice))
  const [units, setUnits] = useState("")
  const put = putInOf(asset, moves) ?? asset.amount
  const q = readNumber(units) || 0
  const typed = inUnits && unitPrice ? Math.round(q * unitPrice) : (value ?? 0)
  const after =
    kind === "value"
      ? { put, now: inUnits ? (units ? typed : asset.amount) : (value ?? asset.amount) }
      : kind === "in"
        ? { put: put + typed, now: asset.amount + typed }
        : { put: put - Math.min(typed, asset.amount), now: asset.amount - Math.min(typed, asset.amount) }
  const disabled = typed <= 0 || (kind === "value" && typed === asset.amount && !inUnits) || (kind === "out" && asset.amount === 0)
  const fig = (label: string, before: number, aft: number, signed?: boolean) => {
    const f = (v: number) => (signed ? (v < 0 ? "−" : "+") : "") + compact(Math.abs(v))
    return (
      <span className="qm__fig">
        <small>{label}</small>
        <b>
          <span className={aft !== before ? "is-old" : ""}>{f(before)}</span>
          {aft !== before && (
            <>
              <Icon name="caret-right-sm" size={10} />
              <span className={signed && aft >= 0 ? "is-gain" : ""}>{f(aft)}</span>
            </>
          )}
        </b>
      </span>
    )
  }
  const save = () => {
    if (inUnits && onSaveUnits) onSaveUnits(asset.id, kind, q, date)
    else onSave(asset.id, kind, typed, date)
    onClose()
  }
  return (
    <ModalSheet
      label={asset.name}
      onClose={onClose}
      header={<ModalHeader title={asset.name} left={<CloseBtn onClick={onClose} label="Cancel" />} right={<SaveBtn disabled={disabled} onClick={save} />} />}
      footer={inUnits ? undefined : <AmountPad onChange={(f) => setValue((v) => f(v ?? 0))} />}
    >
      <div className="qm">
        <Segmented
          label="What happened"
          value={kind}
          onChange={(k) => {
            setKind(k)
            setValue(null)
            setUnits("")
          }}
          options={[
            { value: "value", label: "Update value" },
            { value: "in", label: "Put in" },
            { value: "out", label: "Take out" },
          ]}
        />
        {asset.unit && unitPrice && (
          <Segmented
            small
            label="Type in"
            value={inUnits ? "units" : "dong"}
            onChange={(v) => {
              setInUnits(v === "units")
              setValue(null)
              setUnits("")
            }}
            options={[
              { value: "units", label: `In ${unitLabel(asset.unit)}` },
              { value: "dong", label: "In đồng" },
            ]}
          />
        )}
        <div className="num-sheet" style={{ padding: 0 }}>
          <p>
            {kind === "value"
              ? inUnits
                ? `How much ${asset.name} do you hold now?`
                : `What is ${asset.name} worth now?`
              : kind === "in"
                ? "How much did you put in?"
                : "How much did you take out?"}
          </p>
          {inUnits && asset.unit ? (
            <>
              <span className="qm__units">
                <input
                  autoFocus
                  inputMode="decimal"
                  value={units}
                  placeholder={kind === "value" && asset.quantity != null ? String(asset.quantity) : "0"}
                  aria-label={`Amount in ${unitLabel(asset.unit)}`}
                  onChange={(e) => setUnits(e.target.value.replace(/[^\d.,]/g, ""))}
                />
                <small>{unitLabel(asset.unit)}</small>
              </span>
              <p className="k-note">
                ≈ {money(typed)}đ at {money(unitPrice ?? 0)}đ a {unitLabel(asset.unit)}
                {asset.quantity != null && ` · you hold ${holdingText(asset.quantity, asset.unit)}`}
              </p>
            </>
          ) : (
            <span className={`tnum${value == null ? " is-ghost" : ""}`}>
              {money(value ?? (kind === "value" ? asset.amount : 0))}
              <small>đ</small>
            </span>
          )}
        </div>
        <div className="qm__figs">
          {fig("Put in", put, after.put)}
          {fig("Now", asset.amount, after.now)}
          {fig("Gain", asset.amount - put, after.now - after.put, true)}
        </div>
        <label className="qm__day">
          <span>Day</span>
          <input type="date" value={date} max={today} onChange={(e) => e.target.value && setDate(e.target.value)} />
        </label>
      </div>
    </ModalSheet>
  )
}

/* ── New asset ───────────────────────────────────────────── */

/**
 * New asset: step 1 picks the group (or one sentence); then name, worth — or how much is held in
 * its unit (5 chỉ, 1,000 $) — and the day the money went in. With `editing`, name, group and holding.
 */
export function AddAssetSheet({
  editing,
  goldPremium = 0,
  onClose,
  onSave,
  onEdit,
  onSetHolding,
}: {
  editing?: Asset
  goldPremium?: number
  onClose: () => void
  onSave: (a: Asset) => void
  onEdit?: (id: string, name: string, kind: AssetKind) => void
  onSetHolding?: (id: string, quantity?: number, unit?: HoldingUnit) => void
}) {
  const [picked, setPicked] = useState(!!editing)
  const [name, setName] = useState(editing?.name ?? "")
  const [amount, setAmount] = useState<number | null>(null)
  const [kind, setKind] = useState<AssetKind>(editing?.kind ?? "available")
  const [date, setDate] = useState(todayIso())
  const [unit, setUnit] = useState<HoldingUnit | "">(editing?.unit ?? "")
  const [qty, setQty] = useState(editing?.quantity != null ? String(editing.quantity) : "")
  const q = readNumber(qty) || 0
  const [, setFetched] = useState(0)
  // Held in a unit with no price yet: fetch today's prices once.
  useEffect(() => {
    if (unit && !price(unit, goldPremium)) void refreshPrices().then((ok) => ok && setFetched((n) => n + 1))
  }, [unit, goldPremium])
  const unitPrice = unit ? price(unit, goldPremium) : null
  const worth = unit ? (unitPrice && q ? Math.round(unitPrice * q) : 0) : (amount ?? 0)
  const ok = name.trim() && (editing || worth > 0)
  const save = () => {
    if (!ok) return
    if (editing) {
      onEdit?.(editing.id, name.trim(), kind)
      onSetHolding?.(editing.id, unit ? q : undefined, unit || undefined)
    } else {
      const icon = guessAssetIcon(name, kind)
      onSave({ id: uid(), name: name.trim(), kind, icon, amount: worth, updated: date, ...(unit && q ? { quantity: q, unit } : {}) })
    }
    onClose()
  }
  const pickUnit = (n: string) => {
    const g = guessUnit(guessAssetIcon(n, kind))
    if (g && !unit && !editing) setUnit(g)
  }
  return (
    <ModalSheet
      label={editing ? "Edit asset" : "New asset"}
      onClose={onClose}
      header={
        <ModalHeader
          title={editing ? "Edit asset" : "New asset"}
          left={picked && !editing ? <CloseBtn icon="arrow-left" label="Change group" onClick={() => setPicked(false)} /> : <CloseBtn onClick={onClose} />}
          right={picked ? <SaveBtn disabled={!ok} onClick={save} /> : undefined}
        />
      }
    >
      {!picked ? (
        <div className="pick-step">
          <AddingLead label="kind of" chosen={false} />
          <QuickPickCard
            title="Which group?"
            options={KINDS.map((k) => ({ id: k.kind, title: k.label, hint: k.hint, mark: k.color }))}
            placeholder="e.g. vàng 5 chỉ, tiết kiệm TPBank 50tr"
            onPick={(k) => {
              setKind(k)
              setPicked(true)
            }}
            onSay={(text) => {
              const held = readUnits(text)
              if (held) {
                const d = readAssetLines(text, goldPremium)[0]
                setName(d?.name ?? text)
                setKind(d?.kind ?? "growing")
                setUnit(held.unit)
                setQty(String(held.quantity))
              } else {
                const r = readAssetSentence(text)
                setName(r.name)
                setAmount(r.amount ?? null)
                setKind(r.kind)
              }
              setPicked(true)
            }}
          />
        </div>
      ) : (
        <div className="form-list">
          <label className="form-list__group">
            <span>What is it?</span>
            <input value={name} placeholder="Gold, Saving - TP Bank, Fund…" onChange={(e) => setName(e.target.value)} onBlur={(e) => pickUnit(e.target.value)} autoFocus={!name} />
          </label>
          <label className="form-list__group">
            <span>Held as</span>
            <span className="form-list__money">
              <select value={unit} onChange={(e) => setUnit(e.target.value as HoldingUnit | "")} aria-label="Held as">
                <option value="">Đồng</option>
                {UNITS.map((u) => (
                  <option key={u.unit} value={u.unit}>
                    {u.name}
                  </option>
                ))}
              </select>
            </span>
          </label>
          {unit ? (
            <label className="form-list__group">
              <span>How much do you hold?</span>
              <span className="form-list__money">
                <input className="tnum" inputMode="decimal" value={qty} placeholder="0" onChange={(e) => setQty(e.target.value.replace(/[^\d.,]/g, ""))} />
                <small>{unitLabel(unit)}</small>
              </span>
              <small className="form-list__hint">{unitPrice ? `≈ ${money(worth)}đ at today's price (${money(unitPrice)}đ a ${unitLabel(unit)})` : "No price yet — it fills in once the app is online."}</small>
            </label>
          ) : (
            !editing && (
              <label className="form-list__group">
                <span>How much is it worth now?</span>
                <span className="form-list__money">
                  <input className="tnum" inputMode="numeric" value={amount ? money(amount) : ""} placeholder="0" onChange={(e) => setAmount(Number(e.target.value.replace(/\D/g, "")) || null)} />
                  <small>đ</small>
                </span>
              </label>
            )
          )}
          {!editing && (
            <label className="qm__day form-list__day">
              <span>Put in on</span>
              <input type="date" value={date} max={todayIso()} onChange={(e) => e.target.value && setDate(e.target.value)} />
            </label>
          )}
          <fieldset className="form-list__group">
            <legend>Which group?</legend>
            {KINDS.map((k) => (
              <button key={k.kind} type="button" className={`form-list__choice${kind === k.kind ? " is-on" : ""}`} aria-pressed={kind === k.kind} onClick={() => setKind(k.kind)}>
                <i style={{ background: k.color }} />
                {k.label}
                {kind === k.kind && <Icon name="check" size={18} />}
              </button>
            ))}
          </fieldset>
          <p className="k-note form-list__foot">{kindOf(kind).hint}</p>
        </div>
      )}
    </ModalSheet>
  )
}

/**
 * Quick note: one asset a line ("vàng 5 chỉ", "tiết kiệm TPBank 50tr", "USD 700"). The app lists
 * what it read; tick the ones to keep. A name you already have is updated, a new one is added.
 */
export function AssetImportSheet({
  assets,
  goldPremium,
  today,
  onClose,
  onAdd,
  onUpdate,
}: {
  assets: Asset[]
  goldPremium: number
  today: string
  onClose: () => void
  onAdd: (a: Asset) => void
  onUpdate: (id: string, d: AssetDraft) => void
}) {
  const [text, setText] = useState("")
  const [drafts, setDrafts] = useState<AssetDraft[] | null>(null)
  const [off, setOff] = useState<Set<string>>(new Set())
  const match = (d: AssetDraft) => assets.find((a) => sameName(a.name, d.name))
  const chosen = (drafts ?? []).filter((d) => !off.has(d.id) && (d.amount || d.quantity))
  const save = () => {
    for (const d of chosen) {
      const had = match(d)
      if (had) onUpdate(had.id, d)
      else
        onAdd({
          id: uid(),
          name: d.name,
          kind: d.kind,
          icon: guessAssetIcon(d.name, d.kind),
          amount: d.amount ?? 0,
          updated: today,
          ...(d.unit && d.quantity ? { unit: d.unit, quantity: d.quantity } : {}),
        })
    }
    onClose()
  }
  return (
    <ModalSheet
      label="Quick note"
      onClose={onClose}
      header={
        <ModalHeader
          title="Quick note"
          left={drafts ? <CloseBtn icon="arrow-left" label="Back to the note" onClick={() => setDrafts(null)} /> : <CloseBtn onClick={onClose} />}
          right={drafts ? <SaveBtn disabled={!chosen.length} onClick={save} /> : undefined}
        />
      }
    >
      {!drafts ? (
        <div className="form-list">
          <label className="form-list__group">
            <span>What do you hold? One a line</span>
            <textarea
              className="import__text"
              rows={6}
              autoFocus
              value={text}
              placeholder={"vàng 5 chỉ\ntiết kiệm TPBank 50tr\nUSD 700\nMoMo 2.5tr"}
              onChange={(e) => setText(e.target.value)}
            />
          </label>
          <button
            type="button"
            className="k-btn"
            disabled={!text.trim()}
            onClick={async () => {
              let read = readAssetLines(text, goldPremium)
              // Gold, dollars or coins without a price yet: fetch today's prices, then read again.
              if (read.some((d) => d.unit && !d.amount) && (await refreshPrices())) read = readAssetLines(text, goldPremium)
              setDrafts(read)
              setOff(new Set())
            }}
          >
            Read it
          </button>
          <p className="k-note">Read on this device. Gold, dollars and coins use today&apos;s price.</p>
        </div>
      ) : (
        <div className="hist">
          {!drafts.length && <p className="k-empty">Nothing with an amount in that note. Try “vàng 5 chỉ” or “tiết kiệm 50tr”.</p>}
          {drafts.length > 0 && (
            <ListCard>
              {drafts.map((d) => {
                const had = match(d)
                const on = !off.has(d.id)
                return (
                  <ListRow
                    key={d.id}
                    tile={<AssetTile icon={guessAssetIcon(d.name, d.kind)} />}
                    title={d.name}
                    sub={`${kindOf(d.kind).label}${d.unit && d.quantity ? ` · ${holdingText(d.quantity, d.unit)}` : ""} · ${had ? "updates yours" : "new"}`}
                    amount={d.amount ? `${money(d.amount)}đ` : "no price yet"}
                    onClick={() => setOff((s) => {
                      const n = new Set(s)
                      if (n.has(d.id)) n.delete(d.id)
                      else n.add(d.id)
                      return n
                    })}
                    trailing={
                      <span className="due2-tick" aria-hidden="true">
                        <TickMark on={on} />
                      </span>
                    }
                  />
                )
              })}
            </ListCard>
          )}
          <p className="k-note">Tick what to keep, then ✓.</p>
        </div>
      )}
    </ModalSheet>
  )
}

/* ── History sheets ──────────────────────────────────────── */

type HLine = { id: string; tile: ReactNode; title: string; sub: string; amount: string; group: string; date: string }

function HistorySheet({ title, lines, filters, onClose }: { title: string; lines: HLine[]; filters: string[]; onClose: () => void }) {
  const [f, setF] = useState(filters[0])
  const shown = f === filters[0] ? lines : lines.filter((l) => l.group === f)
  return (
    <ModalSheet label={title} onClose={onClose} header={<ModalHeader title={title} left={<CloseBtn onClick={onClose} />} />}>
      <div className="hist">
        {filters.length > 2 && (
          <div className="hist__chips">
            {filters.map((x) => (
              <button key={x} type="button" className={x === f ? "is-on" : ""} onClick={() => setF(x)}>
                {x}
              </button>
            ))}
          </div>
        )}
        <ListCard>
          {!shown.length && <p className="k-note fin2-pad">Nothing yet.</p>}
          {shown.map((l) => (
            <ListRow key={l.id} tile={l.tile} title={l.title} sub={l.sub} amount={l.amount} />
          ))}
        </ListCard>
      </div>
    </ModalSheet>
  )
}

/** Every change to the assets: money put in or taken out, values updated. */
export function AssetHistorySheet({ moves, hidden, onClose }: { moves: AssetMove[]; hidden: boolean; onClose: () => void }) {
  const lines = [...moves]
    .sort((a, b) => b.date.localeCompare(a.date))
    .map((m) => ({
      id: m.id,
      tile: <AssetTile icon={m.icon} />,
      title: m.title,
      sub: `${MOVE_LABEL[m.kind ?? "in"]} · ${shortDay(m.date)}`,
      amount: hidden ? "•••" : `${m.amount > 0 ? "+" : "−"}${money(Math.abs(m.amount))}đ`,
      group: MOVE_LABEL[m.kind ?? "in"],
      date: m.date,
    }))
  return <HistorySheet title="Asset history" lines={lines} filters={["All", "Put in", "Took out", "Value changed"]} onClose={onClose} />
}

/** Every move on what you owe: installments paid, money from family and paying it back. */
export function DebtHistorySheet({ bills, loans, hidden, onClose }: { bills: Bill[]; loans: FamilyLoan[]; hidden: boolean; onClose: () => void }) {
  const inst = bills
    .filter((b) => b.kind === "installment")
    .flatMap((b) =>
      Object.entries(b.paid).map(([m, r]) => {
        const date = new Date(r.at).toISOString().slice(0, 10)
        return {
          id: `${b.id}-${m}`,
          tile: <Tile bg={TILE[b.icon].solid} icon={b.icon} />,
          title: b.name,
          sub: `Paid · ${shortDay(date)}`,
          amount: hidden ? "•••" : `−${money(r.amount)}đ`,
          group: "Installments",
          date,
        }
      }),
    )
  const fam = loans.map((l) => ({
    id: l.id,
    tile: <Tile bg={l.kind === "received" ? "#7a5af8" : "var(--brand-600)"} mark={l.who.slice(0, 1).toUpperCase()} />,
    title: l.title,
    sub: `${LOAN_LABEL[l.kind]} · ${shortDay(l.date)}`,
    amount: hidden ? "•••" : `${l.kind === "received" ? "+" : "−"}${money(l.amount)}đ`,
    group: l.who,
    date: l.date,
  }))
  const lines = [...inst, ...fam].sort((a, b) => b.date.localeCompare(a.date))
  return <HistorySheet title="Debt history" lines={lines} filters={["All", "Installments", ...new Set(loans.map((l) => l.who))]} onClose={onClose} />
}

/* ── Family loans ───────────────────────────────────────── */

export function LoanPersonSheet({
  who,
  loans,
  today,
  hidden,
  onClose,
  onAdd,
  onRemove,
}: {
  who: string
  loans: FamilyLoan[]
  today: string
  hidden: boolean
  onClose: () => void
  onAdd: () => void
  onRemove: (id: string) => void
}) {
  const p = loanPerson(who, loans, today)
  const rows = [...loans].sort((a, b) => b.date.localeCompare(a.date))
  return (
    <ModalSheet
      label={who}
      onClose={onClose}
      header={
        <ModalHeader
          title={who}
          left={<CloseBtn onClick={onClose} />}
          right={
            <button type="button" className="k-iconbtn" aria-label="Add" onClick={onAdd}>
              <Icon name="plus" size={18} />
            </button>
          }
        />
      }
    >
      <div className="hist">
        <div className="fin2-card">
          <StatCard
            label="Owed today"
            amount={p.owed}
            hidden={hidden}
            stats={[
              { label: "Received", value: maskC(hidden, p.received) },
              { label: "Paid back", value: maskC(hidden, p.paidBack) },
              { label: "Interest left", value: maskC(hidden, Math.max(0, p.interest - p.interestPaid)) },
            ]}
          />
        </div>
        <SectionTitle title="History" />
        <ListCard>
          {rows.map((l) => (
            <ListRow
              key={l.id}
              tile={<Tile bg={l.kind === "received" ? "#7a5af8" : "var(--brand-600)"} icon={l.kind === "received" ? "arrow-down-right" : "arrow-up-right"} />}
              title={l.title}
              sub={`${LOAN_LABEL[l.kind]} · ${shortDay(l.date)}`}
              amount={hidden ? "•••" : `${money(l.amount)}đ`}
              trailing={
                <button type="button" className="hist__del" aria-label={`Delete ${l.title}`} onClick={() => onRemove(l.id)}>
                  <Icon name="trash" size={16} />
                </button>
              }
            />
          ))}
        </ListCard>
      </div>
    </ModalSheet>
  )
}

/** Money received from family, a payment back, or interest paid: who, how much, the day and the yearly rate. */
export function AddLoanSheet({ people, today, onClose, onSave }: { people: string[]; today: string; onClose: () => void; onSave: (l: FamilyLoan) => void }) {
  const [who, setWho] = useState(people[0] ?? "")
  const [kind, setKind] = useState<LoanMove>("received")
  const [amount, setAmount] = useState<number | null>(null)
  const [date, setDate] = useState(today)
  const [rate, setRate] = useState("6")
  const ok = who.trim() && (amount ?? 0) > 0
  return (
    <ModalSheet
      label="Family loan"
      onClose={onClose}
      header={
        <ModalHeader
          title="Family loan"
          left={<CloseBtn onClick={onClose} label="Cancel" />}
          right={
            <SaveBtn
              disabled={!ok}
              onClick={() => {
                onSave({ id: uid(), who: who.trim(), title: `${LOAN_LABEL[kind]} · ${who.trim()}`, kind, amount: amount ?? 0, date, rate: Number(rate) || 6 })
                onClose()
              }}
            />
          }
        />
      }
      footer={<AmountPad onChange={(f) => setAmount((v) => f(v ?? 0))} />}
    >
      <div className="qm">
        <Segmented label="What happened" value={kind} onChange={setKind} options={(Object.keys(LOAN_LABEL) as LoanMove[]).map((k) => ({ value: k, label: LOAN_LABEL[k] }))} />
        <div className="num-sheet" style={{ padding: 0 }}>
          <p>How much?</p>
          <span className={`tnum${amount == null ? " is-ghost" : ""}`}>
            {money(amount ?? 0)}
            <small>đ</small>
          </span>
        </div>
        <div className="form-list form-list--flat">
          <label className="form-list__group">
            <span>Who</span>
            <input value={who} list="loan-people" placeholder="Mom, Grandma…" onChange={(e) => setWho(e.target.value)} />
            <datalist id="loan-people">
              {people.map((p) => (
                <option key={p} value={p} />
              ))}
            </datalist>
          </label>
          <label className="qm__day">
            <span>Day</span>
            <input type="date" value={date} max={today} onChange={(e) => e.target.value && setDate(e.target.value)} />
          </label>
          {kind === "received" && (
            <label className="qm__day">
              <span>Interest a year</span>
              <span>
                <input className="qm__rate" inputMode="decimal" value={rate} onChange={(e) => setRate(e.target.value.replace(/[^\d.]/g, ""))} /> %
              </span>
            </label>
          )}
        </div>
      </div>
    </ModalSheet>
  )
}


