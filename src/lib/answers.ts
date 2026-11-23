import { addDays, money, shortDate } from "./format"
import { addMonths, dueIn, ym, type Bill } from "./bills"
import type { Entry } from "./store"

/**
 * Answers worked out on the device, from the user's own lines (port of the iOS LocalAnswers).
 * Nothing leaves the phone; the AI chat only uses this for questions about past spending.
 */
export type Report = "today" | "week" | "month" | "lastMonth" | "bills" | "received"

const ASKING = /\?|how much|what did|review|report|summary|spending|spent|bao nhiêu|tổng|chi tiêu|xem lại|thế nào/i

/** Which report a message asks for, or null when it reads like a money note ("coffee 24k"). */
export function askedFor(text: string): Report | null {
  const t = text.toLocaleLowerCase("vi")
  if (!ASKING.test(t)) return null
  // A note with amounts in it is a note, even with a "?" at the end.
  if (/\d+\s*(k|tr|đ|d|000)\b/i.test(t)) return null
  if (/bill|hóa đơn|hoá đơn|due/.test(t)) return "bills"
  if (/receiv|income|nhận|thu nhập|lương/.test(t)) return "received"
  if (/last month|tháng trước/.test(t)) return "lastMonth"
  if (/month|tháng/.test(t)) return "month"
  if (/week|tuần/.test(t)) return "week"
  return "today"
}

const mondayOf = (iso: string) => {
  const [y, m, d] = iso.split("-").map(Number)
  return addDays(iso, -((new Date(y, m - 1, d).getDay() + 6) % 7))
}

function range(report: Report, today: string): [string, string, string] {
  if (report === "week") return [mondayOf(today), today, "this week"]
  if (report === "month" || report === "received" || report === "bills") return [`${ym(today)}-01`, today, "this month"]
  if (report === "lastMonth") {
    const m = addMonths(ym(today), -1)
    return [`${m}-01`, `${m}-31`, "last month"]
  }
  return [today, today, "today"]
}

/** The answer as a short paragraph, in the app's plain wording. */
export function answer(report: Report, entries: Entry[], bills: Bill[], today: string): string {
  if (report === "bills") {
    const month = ym(today)
    const due = bills.filter((b) => dueIn(b, month))
    if (!due.length) return "No bills this month."
    const paid = due.filter((b) => b.paid[month])
    const left = due.filter((b) => !b.paid[month])
    const leftSum = left.reduce((s, b) => s + b.amount, 0)
    const next = left.map((b) => ({ b, d: dueIn(b, month)! })).sort((a, b) => a.d.localeCompare(b.d))[0]
    return [
      `${due.length} ${due.length === 1 ? "bill" : "bills"} this month: ${paid.length} taken care of, ${left.length} still to pay (${money(leftSum)}đ).`,
      next ? `Next up: ${next.b.name}, ${money(next.b.amount)}đ on ${shortDate(next.d)}.` : "All done for this month.",
    ].join(" ")
  }

  const [from, to, label] = range(report, today)
  const list = entries.filter((e) => e.date >= from && e.date <= to)

  if (report === "received") {
    const got = list.filter((e) => e.flow === "in")
    if (!got.length) return "Nothing received this month yet."
    const sum = got.reduce((s, e) => s + e.amount, 0)
    const top = [...got].sort((a, b) => b.amount - a.amount)[0]
    return `You received ${money(sum)}đ this month, in ${got.length} ${got.length === 1 ? "line" : "lines"}. The biggest was ${top.title} (${money(top.amount)}đ).`
  }

  const out = list.filter((e) => e.flow === "out")
  if (!out.length) return `Nothing spent ${label} yet.`
  const sum = out.reduce((s, e) => s + e.amount, 0)
  const byCat = new Map<string, number>()
  for (const e of out) byCat.set(e.category, (byCat.get(e.category) ?? 0) + e.amount)
  const cats = [...byCat.entries()].sort((a, b) => b[1] - a[1]).slice(0, 3)
  const top = [...out].sort((a, b) => b.amount - a.amount)[0]
  const lines = [
    `You spent ${money(sum)}đ ${label}, in ${out.length} ${out.length === 1 ? "line" : "lines"}.`,
    `Most of it: ${cats.map(([c, v]) => `${c} ${money(v)}đ`).join(", ")}.`,
    `The biggest was ${top.title} (${money(top.amount)}đ).`,
  ]
  if (report === "month" || report === "lastMonth") {
    const days = new Set(out.map((e) => e.date)).size
    lines.push(`About ${money(sum / Math.max(days, 1))}đ on each day you spent.`)
  }
  return lines.join(" ")
}

/** Shortcut questions shown on the AI tab. */
export const SHORTCUTS: { label: string; ask: string; report: Report }[] = [
  { label: "This week's spending", ask: "How much did I spend this week?", report: "week" },
  { label: "Monthly spending review", ask: "Review my spending this month", report: "month" },
]
export const SUGGESTIONS: { label: string; report: Report }[] = [
  { label: "How much did I spend today?", report: "today" },
  { label: "What bills are left?", report: "bills" },
  { label: "How much did I receive?", report: "received" },
  { label: "Last month's spending", report: "lastMonth" },
]
