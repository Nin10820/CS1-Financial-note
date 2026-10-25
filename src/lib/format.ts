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
