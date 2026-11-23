import type { IconName } from "../components/Icon"

/** A bill the user wants to remember. Recurring and installment bills repeat monthly. */
export type BillKind = "recurring" | "installment" | "oneoff"

export type Bill = {
  id: string
  kind: BillKind
  name: string
  icon: BillIcon
  /** Expected amount per payment (an estimate when `varies`). */
  amount: number
  varies: boolean
  /** First due date, "YYYY-MM-DD". Repeats on the same day each month. */
  start: string
  code?: string
  payWith?: string
  /** Installments only. */
  lender?: string
  principal?: number
  payments?: number
  /** Monthly interest, percent. */
  rate?: number
  /** One-time conversion fee, percent of the principal. */
  fee?: number
  /** Paid months: "YYYY-MM" → what was paid and which Transaction entry recorded it. */
  paid: Record<string, { amount: number; at: number; entryId?: string }>
  createdAt: number
  /** Part of the sample data (removable in one tap). */
  sample?: boolean
}

export type BillIcon = Extract<IconName, "house" | "drop" | "gas-pump" | "lightning" | "phone" | "student" | "monitor" | "bell">

/** Tile colours from the Figma bill list (solid) and statement list (soft). */
export const TILE: Record<BillIcon, { solid: string; soft: string; ink: string }> = {
  // Pink, so purple stays for installments on Due.
  house: { solid: "#dd2590", soft: "#fce7f6", ink: "#c11574" },
  drop: { solid: "#1bacee", soft: "#dff2ff", ink: "#0085ca" },
  "gas-pump": { solid: "#15b79e", soft: "#ccfbef", ink: "#107569" },
  lightning: { solid: "#ff4405", soft: "#ffe6d5", ink: "#c4320a" },
  phone: { solid: "#5fa82f", soft: "#e2f4d3", ink: "#3b6922" },
  student: { solid: "#1570ef", soft: "#d1e9ff", ink: "#1570ef" },
  monitor: { solid: "#c85a34", soft: "#f8eadc", ink: "#c85a34" },
  bell: { solid: "#364152", soft: "#eaecf0", ink: "#364152" },
}

/** Due's names for the kinds. */
export const KIND_LABEL: Record<BillKind, string> = { recurring: "Bill", installment: "Installment", oneoff: "Other" }

/**
 * A bill's colour on Due: a bill (electricity, water…) keeps its icon's colour; every installment
 * is the same purple; other payments are slate.
 */
export function billColor(b: Bill): string {
  if (b.kind === "installment") return "#7a5af8"
  if (b.kind === "oneoff") return "#4b5565"
  return TILE[b.icon].solid
}

/** Where a bill is paid: the lender, who an Other payment is to, or the bank / wallet it's paid with. */
export function billSource(b: Bill): string | undefined {
  return (b.lender ?? b.payWith)?.trim() || undefined
}

/** Picks a tile from the name the user typed (Vietnamese or English). */
export function guessIcon(name: string, kind: BillKind): BillIcon {
  const n = name.toLocaleLowerCase("vi")
  if (/rent|nhà|nha tro|phòng|thuê/.test(n)) return "house"
  if (/water|nước|nuoc/.test(n)) return "drop"
  if (/gas|xăng|xang|petrol/.test(n)) return "gas-pump"
  if (/điện|dien|electric|power|evn/.test(n)) return "lightning"
  if (/phone|iphone|samsung|điện thoại|sim|4g|wifi|internet|mạng/.test(n)) return "phone"
  if (/course|học|hoc|school|english|tuition|lớp/.test(n)) return "student"
  if (/macbook|laptop|tv|monitor|máy tính|ipad/.test(n)) return "monitor"
  return kind === "installment" ? "phone" : "bell"
}

export const ym = (iso: string) => iso.slice(0, 7)

export function addMonths(month: string, n: number) {
  const [y, m] = month.split("-").map(Number)
  const d = new Date(y, m - 1 + n, 1)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`
}

const monthsBetween = (a: string, b: string) => {
  const [y1, m1] = a.split("-").map(Number)
  const [y2, m2] = b.split("-").map(Number)
  return (y2 - y1) * 12 + (m2 - m1)
}

/** The day this bill is due in `month`, or null when it isn't due then. */
export function dueIn(bill: Bill, month: string): string | null {
  const offset = monthsBetween(ym(bill.start), month)
  if (offset < 0) return null
  if (bill.kind === "oneoff" && offset !== 0) return null
  if (bill.kind === "installment" && offset >= (bill.payments ?? 1)) return null
  const [y, m] = month.split("-").map(Number)
  const last = new Date(y, m, 0).getDate()
  const day = Math.min(Number(bill.start.slice(8, 10)), last)
  return `${month}-${String(day).padStart(2, "0")}`
}

/** Installment number for `month` (1-based) and how many are left after it. */
export function installmentStep(bill: Bill, month: string) {
  const n = bill.payments ?? 1
  const index = monthsBetween(ym(bill.start), month) + 1
  const paidCount = Object.keys(bill.paid).length
  return { index, total: n, paidCount, left: Math.max(0, n - paidCount) }
}

export function lastDue(bill: Bill) {
  if (bill.kind !== "installment") return bill.start
  return dueIn(bill, addMonths(ym(bill.start), (bill.payments ?? 1) - 1)) ?? bill.start
}

/** Equal monthly payment: principal split evenly plus flat monthly interest on the principal. */
export function installmentPayment(principal: number, payments: number, ratePct: number) {
  if (!principal || !payments) return 0
  return Math.round(principal / payments + (principal * ratePct) / 100)
}

/** What the Due screen shows for one month. */
export function monthSummary(bills: Bill[], month: string) {
  const due = bills
    .map((b) => ({ bill: b, date: dueIn(b, month) }))
    .filter((x): x is { bill: Bill; date: string } => !!x.date)
    .sort((a, b) => a.date.localeCompare(b.date))
  const still = due.filter((x) => !x.bill.paid[month])
  const done = due.filter((x) => x.bill.paid[month])
  const paid = done.reduce((s, x) => s + x.bill.paid[month].amount, 0)
  const remaining = still.reduce((s, x) => s + x.bill.amount, 0)
  // Everything still owed from this month on: this month's unpaid bills plus future installments.
  const future = bills
    .filter((b) => b.kind === "installment")
    .reduce((s, b) => {
      const n = b.payments ?? 1
      let owed = 0
      for (let i = 1; i < n + 1; i++) {
        const m = addMonths(ym(b.start), i - 1)
        if (m > month && !b.paid[m]) owed += b.amount
      }
      return s + owed
    }, 0)
  return { due, still, done, paid, remaining, totalRemaining: remaining + future }
}

/** What "Say it your way" read from one sentence, to fill the New bill form. */
export type BillDraft = { kind: BillKind; name: string; amount?: number; principal?: number; due?: string; payments?: number; varies: boolean; payWith?: string }

/** Reads an amount like "250k", "1tr2", "12 triệu", "340.000". */
export function readAmount(text: string): { amount?: number; rest: string } {
  const m = text.match(/(\d+(?:[.,]\d{3})+|\d+(?:[.,]\d+)?)\s*(tr|triệu|trieu|m\b|k\b|nghìn|ngàn|đ|d\b|vnd)?\s*(\d{1,3}(?!\d))?/i)
  if (!m) return { rest: text }
  const raw = m[1]
  const unit = (m[2] ?? "").toLowerCase()
  const thousands = /^\d+([.,]\d{3})+$/.test(raw)
  const n = thousands ? Number(raw.replace(/[.,]/g, "")) : Number(raw.replace(",", "."))
  const tail = m[3] ? Number(m[3]) / 10 ** m[3].length : 0
  const amount = unit.startsWith("tr") || unit === "m" ? Math.round((n + tail) * 1_000_000) : unit === "k" || unit.startsWith("ng") ? Math.round(n * 1000) : Math.round(n)
  return { amount: amount > 0 ? amount : undefined, rest: text.replace(m[0], " ") }
}

/** "Internet 250k every month on the 5th", "laptop 12tr trả góp 12 tháng", "bảo hiểm 1tr2 một lần ngày 20". */
export function readBillSentence(text: string, month: string, today: string): BillDraft {
  const lower = text.toLocaleLowerCase("vi")
  const kind: BillKind = /trả góp|tra gop|góp|installment|instalment/.test(lower)
    ? "installment"
    : /một lần|1 lần|mot lan|once|one[- ]?off|lần này/.test(lower)
      ? "oneoff"
      : "recurring"
  const num = (re: RegExp) => {
    const m = lower.match(re)
    return m ? Number(m[1]) : undefined
  }
  const day = num(/(?:ngày|ngay|mùng|mung|day)\s*(\d{1,2})/) ?? num(/on the\s*(\d{1,2})/) ?? num(/\b(\d{1,2})(?:st|nd|rd|th)\b/)
  const last = new Date(Number(month.slice(0, 4)), Number(month.slice(5, 7)), 0).getDate()
  const due = day && day >= 1 && day <= 31 ? `${month}-${String(Math.min(day, last)).padStart(2, "0")}` : month === today.slice(0, 7) ? today : `${month}-15`
  const payments = kind === "installment" ? num(/(\d{1,3})\s*(?:tháng|thang|kỳ|ky|months?|payments?)/) : undefined
  const varies = kind === "recurring" && /khoảng|tầm|tam |about|around|~|thay đổi|changes/.test(lower)
  let rest = text
  for (const p of [
    /(trả góp|tra gop|góp|installment|instalment)/gi,
    /(một lần|1 lần|mot lan|once|one[- ]?off|lần này)/gi,
    /(mỗi tháng|hàng tháng|hang thang|moi thang|every month|monthly|per month|\/tháng|\/month)/gi,
    /(ngày|ngay|mùng|mung|day)\s*\d{1,2}/gi,
    /on the\s*\d{1,2}(st|nd|rd|th)?/gi,
    /\b\d{1,2}(st|nd|rd|th)\b/gi,
    /\d{1,3}\s*(tháng|thang|kỳ|ky|months?|payments?)/gi,
    /\b(khoảng|tầm|about|around)\b|~/gi,
  ])
    rest = rest.replace(p, " ")
  const read = readAmount(rest)
  const name = read.rest.replace(/\s+/g, " ").replace(/^[\s,.\-–—]+|[\s,.\-–—]+$/g, "")
  return {
    kind,
    name: name || text,
    amount: kind === "installment" ? undefined : read.amount,
    principal: kind === "installment" ? read.amount : undefined,
    due,
    payments,
    varies,
  }
}
