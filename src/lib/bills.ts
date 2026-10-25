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
}

export type BillIcon = Extract<IconName, "house" | "drop" | "gas-pump" | "lightning" | "phone" | "student" | "monitor" | "bell">

/** Tile colours from the Figma bill list (solid) and statement list (soft). */
export const TILE: Record<BillIcon, { solid: string; soft: string; ink: string }> = {
  house: { solid: "#3538cd", soft: "#e0eaff", ink: "#3538cd" },
  drop: { solid: "#1bacee", soft: "#dff2ff", ink: "#0085ca" },
  "gas-pump": { solid: "#15b79e", soft: "#ccfbef", ink: "#107569" },
  lightning: { solid: "#ff4405", soft: "#ffe6d5", ink: "#c4320a" },
  phone: { solid: "#5fa82f", soft: "#e2f4d3", ink: "#3b6922" },
  student: { solid: "#1570ef", soft: "#d1e9ff", ink: "#1570ef" },
  monitor: { solid: "#c85a34", soft: "#f8eadc", ink: "#c85a34" },
  bell: { solid: "#364152", soft: "#eaecf0", ink: "#364152" },
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
