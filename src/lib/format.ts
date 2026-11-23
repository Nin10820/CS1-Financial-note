/** Dates are plain "YYYY-MM-DD" strings in the user's local time; money is whole đồng. */

export const pad = (n: number) => String(n).padStart(2, "0")

export function toISODate(d: Date) {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

export const today = () => toISODate(new Date())

export function addDays(iso: string, days: number) {
  const [y, m, d] = iso.split("-").map(Number)
  return toISODate(new Date(y, m - 1, d + days))
}

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const MONTHS_LONG = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
]

/** "August 07, 2026" — the header date pill. */
export function longDate(iso: string) {
  const [y, m, d] = iso.split("-").map(Number)
  return `${MONTHS_LONG[m - 1]} ${pad(d)}, ${y}`
}

/** "07 Aug" — "Spent on 07 Aug". */
export function shortDate(iso: string) {
  const [, m, d] = iso.split("-").map(Number)
  return `${pad(d)} ${MONTHS[m - 1]}`
}

/** "42,000" — thousands with commas, as in the Figma file. */
export const money = (n: number) => Math.round(n).toLocaleString("en-US")

export const clock = (at: number) => {
  const d = new Date(at)
  return `${pad(d.getHours())}:${pad(d.getMinutes())}`
}

export function greeting(now = new Date()) {
  const h = now.getHours()
  if (h < 12) return "Good Morning"
  if (h < 18) return "Good Afternoon"
  return "Good Evening"
}

/** 18,500,000 → "18.5M", 450,000 → "450K", 0 → "0". */
export function compact(n: number) {
  const a = Math.abs(n)
  const sign = n < 0 ? "−" : ""
  if (a >= 1_000_000) {
    const v = a / 1_000_000
    return sign + (v >= 100 || v === Math.round(v) ? String(Math.round(v)) : v.toFixed(1)) + "M"
  }
  return sign + (a >= 1000 ? `${Math.floor(a / 1000)}K` : String(a))
}

/** "16 Nov" — this year's dates without the year; "16 Nov 2025" otherwise. */
export function shortDay(iso: string) {
  const [y, m, d] = iso.split("-").map(Number)
  return `${d} ${MONTHS[m - 1]}${String(y) === today().slice(0, 4) ? "" : ` ${y}`}`
}

/** "Nov 2026" */
export const monthTitle = (ym: string) => `${MONTHS[Number(ym.slice(5, 7)) - 1]} ${ym.slice(0, 4)}`
export const monthLong = (ym: string) => MONTHS_LONG[Number(ym.slice(5, 7)) - 1]

/** "2026-11" + n months. */
export function addMonthsYm(ym: string, n: number) {
  const [y, m] = ym.split("-").map(Number)
  const t = y * 12 + (m - 1) + n
  return `${Math.floor(t / 12)}-${pad((t % 12) + 1)}`
}

export const daysIn = (ym: string) => new Date(Number(ym.slice(0, 4)), Number(ym.slice(5, 7)), 0).getDate()
