/** What the user owns, as they choose to write it down. Nothing here talks to a bank. */
import type { IconName } from "../components/Icon"
import { price, readUnits, type HoldingUnit } from "./market"

/** The four groups from Figma High Fi 2 › Asset (943:25860). */
export type AssetKind = "available" | "growing" | "aside" | "owed"

export type AssetIcon = "gold" | "fund" | "bank" | "cash" | "lent" | "usd" | "stock" | "coin" | "piggy"

export type Asset = {
  id: string
  name: string
  kind: AssetKind
  icon: AssetIcon
  amount: number
  /** Last time the user updated the amount, "YYYY-MM-DD". */
  updated: string
  sample?: boolean
  /** Held in its own unit (5 chỉ, 1,000 $, 0.05 BTC): the worth follows today's price. */
  quantity?: number
  unit?: HoldingUnit
}

export type AssetMoveKind = "in" | "out" | "value"

/** One change to an asset: money put in (+), taken out (−), or its worth changing on its own. */
export type AssetMove = {
  id: string
  title: string
  icon: AssetIcon
  amount: number
  date: string
  sample?: boolean
  /** The asset it belongs to (older moves have none). */
  assetId?: string
  /** "in" money put in, "out" taken out, "value" the worth changed on its own. */
  kind?: AssetMoveKind
}

export const MOVE_LABEL: Record<AssetMoveKind, string> = { in: "Put in", out: "Took out", value: "Value changed" }

/** Money given to family — counted as "Taken care of", never as spending. */
export type CareGift = {
  id: string
  /** Who it was for: "Parents", "Young brother", "Household"… */
  who: string
  title: string
  amount: number
  date: string
  sample?: boolean
}

/** Net worth at the end of a month, for the chart. */
export type WorthPoint = { month: string; value: number; sample?: boolean }

/** Money from family, owed back with yearly interest. */
export type LoanMove = "received" | "back" | "interest"
export type FamilyLoan = {
  id: string
  who: string
  title: string
  kind: LoanMove
  amount: number
  date: string
  /** Percent a year, e.g. 6. */
  rate: number
  sample?: boolean
}
export const LOAN_LABEL: Record<LoanMove, string> = { received: "Received", back: "Paid back", interest: "Interest paid" }

/** The asset the saving goal fills ("Savings", set aside). */
export const SAVINGS_ID = "saving-goal"

export const KINDS: { kind: AssetKind; label: string; color: string; hint: string }[] = [
  { kind: "available", label: "Available", color: "var(--asset-available)", hint: "Money you can use right away — cash, your main account." },
  { kind: "growing", label: "Growing", color: "var(--asset-growing)", hint: "Put somewhere to grow — gold, a fund, stocks." },
  { kind: "aside", label: "Set aside", color: "var(--asset-aside)", hint: "Locked away for later — a savings deposit." },
  { kind: "owed", label: "Owed", color: "var(--asset-owed)", hint: "Money someone owes you." },
]
export const kindOf = (k: AssetKind) => KINDS.find((x) => x.kind === k)!

/** Solid round tile per asset: its colour and an icon, or a short mark ("Au", "₫", "$"). */
export const ASSET_TILE: Record<AssetIcon, { bg: string; icon?: IconName; mark?: string }> = {
  gold: { bg: "var(--asset-gold)", mark: "Au" },
  fund: { bg: "var(--asset-fund)", icon: "chart-pie-slice" },
  bank: { bg: "var(--asset-bank)", icon: "wallet" },
  cash: { bg: "var(--asset-cash)", mark: "₫" },
  lent: { bg: "var(--asset-lent)", icon: "arrow-up-right" },
  usd: { bg: "var(--asset-usd)", mark: "$" },
  stock: { bg: "var(--asset-stock)", icon: "chart-line-up" },
  coin: { bg: "var(--asset-coin)", mark: "₿" },
  piggy: { bg: "var(--asset-piggy)", icon: "piggy-bank" },
}

export const guessAssetIcon = (name: string, kind: AssetKind): AssetIcon => {
  const n = name.toLocaleLowerCase("vi")
  if (kind === "owed") return "lent"
  if (/gold|vàng|vang|sjc|pnj|doji/.test(n)) return "gold"
  if (/usd|dollar|đô|\$/.test(n)) return "usd"
  if (/coin|btc|bitcoin|eth|crypto|usdt/.test(n)) return "coin"
  if (/stock|cổ phiếu|co phieu|vn30|vnindex|chứng khoán/.test(n)) return "stock"
  if (/fund|quỹ|quy|fmarket|etf|dcds|vesaf/.test(n)) return "fund"
  if (/bank|tiết kiệm|tiet kiem|saving|tp|vcb|techcom|mb|acb|gửi/.test(n)) return "bank"
  return "cash"
}

/** "vàng SJC 15tr", "tiết kiệm TPBank 50 triệu", "cho Minh mượn 2tr" → name, amount and group. */
export function readAssetSentence(text: string): { name: string; amount?: number; kind: AssetKind } {
  const lower = text.toLocaleLowerCase("vi")
  const kind: AssetKind = /cho .* mượn|cho mượn|mượn|muon|lent|owes|owed|nợ tôi|no toi/.test(lower)
    ? "owed"
    : /tiết kiệm|tiet kiem|saving|gửi góp|kỳ hạn|ky han|deposit/.test(lower)
      ? "aside"
      : /vàng|vang|gold|sjc|pnj|quỹ|quy|fund|fmarket|cổ phiếu|co phieu|stock|chứng khoán|etf|crypto|bitcoin|btc/.test(lower)
        ? "growing"
        : "available"
  const m = text.match(/(\d+(?:[.,]\d+)?)\s*(tr|triệu|trieu|m|k|nghìn|ngàn|đ|d)?(\d*)\b/i)
  let amount: number | undefined
  let name = text
  if (m) {
    const n = Number(m[1].replace(",", "."))
    const unit = (m[2] ?? "").toLowerCase()
    const tail = m[3] ? Number(`0.${m[3]}`) : 0
    amount = Math.round(unit.startsWith("tr") || unit === "m" ? (n + tail) * 1_000_000 : unit === "k" || unit.startsWith("ng") ? n * 1000 : n)
    name = text.replace(m[0], " ")
  }
  name = name.replace(/\s+/g, " ").replace(/^[\s,.-]+|[\s,.-]+$/g, "")
  return { name: name || text, amount: amount && amount > 0 ? amount : undefined, kind }
}

/** Share of each group, rounded so the four always add up to 100. */
export function shares(assets: Asset[]) {
  const total = assets.reduce((s, a) => s + a.amount, 0)
  const raw = KINDS.map((k) => {
    const sum = assets.filter((a) => a.kind === k.kind).reduce((s, a) => s + a.amount, 0)
    return { ...k, sum, pct: total ? (sum / total) * 100 : 0 }
  })
  const rounded = raw.map((r) => ({ ...r, pct: Math.floor(r.pct) }))
  let left = total ? 100 - rounded.reduce((s, r) => s + r.pct, 0) : 0
  // Give the leftover points to the groups that lost the most when rounding down.
  ;[...raw]
    .map((r, i) => ({ i, frac: r.pct - Math.floor(r.pct) }))
    .sort((a, b) => b.frac - a.frac)
    .forEach(({ i }) => {
      if (left > 0 && raw[i].sum > 0) {
        rounded[i].pct++
        left--
      }
    })
  return { total, groups: rounded }
}

/** What went into an asset (in − out). Null when it has no moves yet. */
export function putInOf(asset: Asset, moves: AssetMove[]): number | null {
  const mine = moves.filter((m) => m.assetId === asset.id)
  if (!mine.length) return null
  return mine.filter((m) => m.kind !== "value").reduce((s, m) => s + m.amount, 0)
}

/** The asset's worth after each move, oldest first, for its line. */
export function valueLine(asset: Asset, moves: AssetMove[]) {
  const mine = moves.filter((m) => m.assetId === asset.id).sort((a, b) => a.date.localeCompare(b.date))
  let running = 0
  const out: { date: string; value: number }[] = []
  for (const m of mine) {
    running += m.amount
    const last = out[out.length - 1]
    if (last?.date === m.date) last.value = running
    else out.push({ date: m.date, value: running })
  }
  return out
}

/* ── Family loans ─────────────────────────────────────────── */

export type LoanPerson = {
  who: string
  received: number
  paidBack: number
  interest: number
  interestPaid: number
  rate: number
  /** Borrowed still out, plus interest not yet paid. */
  owed: number
  principal: number
}

const dayDiff = (a: string, b: string) => Math.round((Date.parse(b) - Date.parse(a)) / 86_400_000)

/** Simple interest, day by day, on what's still borrowed, at the rate of the latest money received. */
export function loanPerson(who: string, moves: FamilyLoan[], today: string): LoanPerson {
  const sorted = moves.filter((m) => m.date <= today).sort((a, b) => a.date.localeCompare(b.date))
  let principal = 0
  let interest = 0
  let last: string | null = null
  let rate = 6
  let received = 0
  let back = 0
  let paidInterest = 0
  const accrue = (day: string) => {
    if (last) interest += (Math.max(0, principal) * rate) / 100 * Math.max(0, dayDiff(last, day)) / 365
    last = day
  }
  for (const m of sorted) {
    accrue(m.date)
    if (m.kind === "received") {
      principal += m.amount
      received += m.amount
      rate = m.rate
    } else if (m.kind === "back") {
      principal -= m.amount
      back += m.amount
    } else paidInterest += m.amount
  }
  accrue(today)
  const i = Math.round(interest)
  const p = Math.max(0, received - back)
  return { who, received, paidBack: back, interest: i, interestPaid: paidInterest, rate, principal: p, owed: p + Math.max(0, i - paidInterest) }
}

export function loanPeople(loans: FamilyLoan[], today: string): LoanPerson[] {
  const by = new Map<string, FamilyLoan[]>()
  for (const l of loans) by.set(l.who, [...(by.get(l.who) ?? []), l])
  return [...by.entries()].map(([who, list]) => loanPerson(who, list, today)).sort((a, b) => b.owed - a.owed)
}

export const loansOwed = (loans: FamilyLoan[], today: string) => loanPeople(loans, today).reduce((s, p) => s + p.owed, 0)

/* ── Reading assets from a note ───────────────────────── */

/** One asset read from a quick note, to check before it is added. */
export type AssetDraft = { id: string; name: string; kind: AssetKind; amount?: number; quantity?: number; unit?: HoldingUnit }

const plain = (s: string) =>
  s
    .toLocaleLowerCase("vi")
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/đ/g, "d")

/** The group the words point to, when they say. */
export function kindHint(name: string): AssetKind | null {
  const n = plain(name)
  if (/cho .*muon|cho muon|lent|owes|no toi/.test(n)) return "owed"
  if (/tiet kiem|saving|deposit|ky han|gui gop/.test(n)) return "aside"
  if (/vang|gold|sjc|pnj|doji|quy|fund|co phieu|stock|chung khoan|etf|crypto|bitcoin|btc|eth/.test(n)) return "growing"
  if (/momo|zalopay|vnpay|shopeepay|tai khoan|account|tien mat|cash|vi /.test(n)) return "available"
  return null
}

/** The same asset under another spelling: "Vàng SJC" and "vang sjc". */
export const sameName = (a: string, b: string) => plain(a).replace(/\s+/g, " ").trim() === plain(b).replace(/\s+/g, " ").trim()

/** One asset a line: "vàng 5 chỉ", "tiết kiệm TPBank 50tr", "USD 700", "MoMo 2.5tr". */
export function readAssetLines(text: string, goldPremium = 0): AssetDraft[] {
  return text
    .split(/\n|;/)
    .map((l) => l.trim())
    .filter(Boolean)
    .flatMap((line, i): AssetDraft[] => {
      const id = `d${i}`
      const held = readUnits(line)
      if (held) {
        let rest = held.rest.replace(/[\s,.:;-]+/g, " ").trim()
        const gold = held.unit === "chi" || held.unit === "phan" || held.unit === "luong"
        if (!rest) rest = gold ? "Gold" : ["btc", "eth", "usdt"].includes(held.unit) ? "Coin" : held.unit.toUpperCase()
        const p = price(held.unit, goldPremium)
        const growing = gold || held.unit === "btc" || held.unit === "eth"
        return [
          {
            id,
            name: rest[0].toUpperCase() + rest.slice(1),
            kind: growing ? "growing" : (kindHint(line) ?? "available"),
            quantity: held.quantity,
            unit: held.unit,
            amount: p ? Math.round(p * held.quantity) : undefined,
          },
        ]
      }
      const r = readAssetSentence(line)
      if (!r.amount) return []
      return [{ id, name: r.name.charAt(0).toUpperCase() + r.name.slice(1), kind: kindHint(line) ?? r.kind, amount: r.amount }]
    })
}
