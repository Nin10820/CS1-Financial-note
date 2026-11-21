/** Made-up data that fills every screen for demos and first launch. Every item carries `sample: true`
    so it can be removed in one tap without touching anything the user wrote. */
import type { Asset, AssetMove, CareGift, WorthPoint } from "./assets"
import type { Bill } from "./bills"
import { addDays } from "./format"
import type { CategoryName, DayNote, Entry } from "./store"

const id = (s: string) => `sample-${s}`
const addMonthsIso = (iso: string, n: number) => {
  const [y, m, d] = iso.split("-").map(Number)
  const dt = new Date(y, m - 1 + n, Math.min(d, 28))
  return `${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, "0")}-${String(dt.getDate()).padStart(2, "0")}`
}

// [title, amount, category, flow] per day, newest day first.
const DAYS: [string, number, CategoryName, "out" | "in"][][] = [
  [
    ["Cơm tấm", 35_000, "Food", "out"],
    ["Cafe with the team", 40_000, "Food", "out"],
    ["Grab to work", 42_000, "Transport", "out"],
    ["Lunch, broken rice", 45_000, "Food", "out"],
  ],
  [
    ["Phở bò", 55_000, "Food", "out"],
    ["Petrol", 100_000, "Transport", "out"],
    ["Peter paid me back for lunch", 45_000, "Received", "in"],
    ["Milk tea", 35_000, "Food", "out"],
  ],
  [
    ["Groceries at the market", 180_000, "Food", "out"],
    ["Book", 120_000, "Shopping", "out"],
    ["Parking", 5_000, "Transport", "out"],
  ],
  [
    ["Bánh mì", 25_000, "Food", "out"],
    ["Grab home", 60_000, "Transport", "out"],
    ["Dinner with family", 320_000, "Food", "out"],
  ],
  [
    ["Haircut", 80_000, "Other", "out"],
    ["Coffee", 29_000, "Food", "out"],
    ["T-shirt", 199_000, "Shopping", "out"],
  ],
  [
    ["Salary", 18_500_000, "Received", "in"],
    ["Bún chả", 50_000, "Food", "out"],
  ],
  [
    ["Snack", 15_000, "Food", "out"],
    ["Water", 10_000, "Food", "out"],
    ["Bus card top-up", 100_000, "Transport", "out"],
  ],
]

export function makeSample(today: string) {
  const now = Date.now()
  const entries: Entry[] = []
  const notes: Record<string, DayNote> = {}

  DAYS.forEach((day, i) => {
    const date = addDays(today, -i)
    const noteId = id(`note-${i}`)
    day.forEach(([title, amount, category, flow], j) =>
      entries.push({
        id: id(`e-${i}-${j}`),
        date,
        title,
        amount,
        flow,
        category,
        noteId,
        source: day.map(([t, a]) => `${t} ${Math.round(a / 1000)}k`).join(", "),
        createdAt: now - i * 86_400_000 - (day.length - j) * 600_000,
        sample: true,
      }),
    )
    if (i < 2)
      notes[date] = {
        lines: day.map(([t, a], k) => (k === 1 ? `${t} ${Math.round(a / 1000)}k · cash` : `${t} ${Math.round(a / 1000)}k`)),
        updatedAt: now - i * 86_400_000,
      }
  })

  const thisMonth = today.slice(0, 7)
  const day15 = `${thisMonth}-15`
  const paidMonths = (from: number, to: number, amount: number) => {
    const out: Bill["paid"] = {}
    for (let k = from; k <= to; k++) out[addMonthsIso(day15, -k).slice(0, 7)] = { amount, at: now - k * 2_592_000_000 }
    return out
  }

  const bills: Bill[] = [
    { id: id("rent"), kind: "recurring", name: "Rent", icon: "house", amount: 2_500_000, varies: false, start: addMonthsIso(`${thisMonth}-05`, -8), payWith: "Transfer", paid: paidMonths(0, 8, 2_500_000), createdAt: now, sample: true },
    { id: id("power"), kind: "recurring", name: "Electricity", icon: "lightning", amount: 420_000, varies: true, start: addMonthsIso(`${thisMonth}-12`, -8), code: "PE0400123456", paid: paidMonths(0, 8, 410_000), createdAt: now, sample: true },
    { id: id("water"), kind: "recurring", name: "Water Bill", icon: "drop", amount: 120_000, varies: true, start: addMonthsIso(day15, -8), code: "WT2451234151", paid: paidMonths(0, 8, 118_000), createdAt: now, sample: true },
    { id: id("net"), kind: "recurring", name: "Internet", icon: "phone", amount: 220_000, varies: false, start: addMonthsIso(`${thisMonth}-20`, -8), paid: paidMonths(0, 8, 220_000), createdAt: now, sample: true },
    { id: id("iphone"), kind: "installment", name: "iPhone 15 Pro", icon: "phone", amount: 1_100_000, varies: false, start: addMonthsIso(`${thisMonth}-25`, -3), lender: "TP Bank", principal: 12_120_000, payments: 12, rate: 0, fee: 1.5, payWith: "TP Bank", paid: paidMonths(1, 3, 1_100_000), createdAt: now, sample: true },
    { id: id("course"), kind: "installment", name: "English Course", icon: "student", amount: 367_000, varies: false, start: addMonthsIso(`${thisMonth}-18`, -5), lender: "Home Credit", principal: 2_200_000, payments: 6, rate: 0, fee: 0, paid: paidMonths(1, 5, 367_000), createdAt: now, sample: true },
  ]

  // Assets from Nin's Investment Diary: every time money went in (or came out), on its real day,
  // from the first fund in Oct 2021, then what each is worth now. Same as the iOS sample.
  const FUND: [number, string][] = [
    [5_300_000, "2021-10-21"], [4_000_000, "2021-10-22"], [5_000_000, "2021-11-23"], [5_200_000, "2021-11-26"],
    [5_000_000, "2021-12-22"], [10_000_000, "2021-12-24"], [5_000_000, "2022-01-20"], [2_000_000, "2022-01-21"],
    [2_000_000, "2022-02-22"], [750_000, "2023-01-30"], [3_000_000, "2023-02-23"], [100_000, "2023-11-24"],
    [2_000_000, "2024-01-23"], [4_000_000, "2024-02-22"], [2_000_000, "2024-02-22"], [500_000, "2024-02-22"],
    [1_000_000, "2024-03-04"], [2_000_000, "2024-03-21"], [2_000_000, "2024-03-21"], [500_000, "2024-04-23"],
    [1_000_000, "2024-05-23"], [2_000_000, "2024-05-23"], [3_000_000, "2024-06-21"], [2_500_000, "2024-08-08"],
    [200_000, "2024-08-29"], [3_000_000, "2024-09-05"], [500_000, "2024-09-24"], [1_500_000, "2024-11-21"],
    [2_000_000, "2024-12-12"], [5_000_000, "2025-03-21"], [1_000_000, "2025-04-14"], [1_000_000, "2025-04-23"],
    [1_500_000, "2025-05-19"], [700_000, "2025-06-22"], [500_000, "2025-07-22"], [1_000_000, "2025-07-30"],
  ]
  // Stock, with money from Mom and Grandma put straight in, and one 60M taken out.
  const STOCK: [number, string][] = [
    [5_500_000, "2025-04-08"], [4_500_000, "2025-04-11"], [10_000_000, "2025-04-22"], [3_000_000, "2025-05-13"],
    [5_000_000, "2025-05-16"], [2_000_000, "2025-06-19"], [6_500_000, "2025-07-18"], [6_300_000, "2025-07-29"],
    [1_300_000, "2025-09-19"], [20_000_000, "2025-09-20"], [10_000_000, "2025-10-11"], [-60_000_000, "2025-10-28"],
    [10_000_000, "2025-11-11"], [25_000_000, "2026-01-12"], [8_000_000, "2026-01-14"], [10_000_000, "2026-01-31"],
    [5_000_000, "2026-02-01"], [10_000_000, "2026-02-06"], [20_000_000, "2026-03-05"], [5_000_000, "2026-03-10"],
    [1_200_000, "2026-09-20"],
  ]
  type Holding = { key: string; name: string; kind: Asset["kind"]; icon: Asset["icon"]; ins: [number, string][]; now: number }
  const gold: [number, string][] = [...Array.from({ length: 4 }, (): [number, string] => [5_575_000, "2022-08-10"]), [7_700_000, "2024-08-10"]]
  const raw: Holding[] = [
    { key: "vnd", name: "VND", kind: "available", icon: "cash", ins: [[1_000_000, "2023-05-01"], [2_000_000, "2025-05-25"], [1_000_000, "2026-02-17"]], now: 4_000_000 },
    { key: "usd", name: "USD", kind: "available", icon: "cash", ins: [[2_600_000, "2023-08-10"], [4_500_000, "2025-04-10"], [13_000_000, "2026-02-26"]], now: 20_000_000 },
    { key: "saving", name: "Saving", kind: "aside", icon: "bank", ins: [[1_000_000, addDays(today, -88)]], now: 1_000_000 },
    { key: "gold", name: "Gold", kind: "growing", icon: "gold", ins: gold, now: 65_000_000 },
    { key: "fund", name: "Fund", kind: "growing", icon: "fund", ins: FUND, now: 110_000_000 },
    { key: "stock", name: "Stock", kind: "growing", icon: "fund", ins: STOCK, now: 75_000_000 },
    { key: "coin", name: "Coin", kind: "growing", icon: "cash", ins: [[200_000, "2026-02-20"]], now: 200_000 },
    { key: "lent", name: "Lent to Minh", kind: "owed", icon: "lent", ins: [[12_265_000, addDays(today, -40)]], now: 12_265_000 },
  ]
  // Only what has happened by today, oldest first.
  const holdings = raw.map((h) => ({ ...h, ins: h.ins.filter(([, d]) => d <= today).sort((x, y) => x[1].localeCompare(y[1])) }))

  const assets: Asset[] = holdings.map((h) => ({
    id: id(h.key),
    name: h.name,
    kind: h.kind,
    icon: h.icon,
    amount: h.now,
    updated: h.ins.reduce((s, [v]) => s + v, 0) !== h.now ? addDays(today, -3) : (h.ins[h.ins.length - 1]?.[1] ?? today),
    sample: true,
  }))
  const moves: AssetMove[] = holdings.flatMap((h) =>
    h.ins.map(([amount, date], k) => ({ id: id(`m-${h.key}-${k}`), title: h.name, icon: h.icon, amount, date, sample: true })),
  )

  // Family support: parents every month, the younger brother's tuition each term, household bills.
  const care: CareGift[] = []
  for (let k = 0; k < 46; k++) care.push({ id: id(`p${k}`), who: "Parents", title: "Parents support", amount: k < 12 ? 2_000_000 : 1_500_000, date: addMonthsIso(addDays(today, -6), -k), sample: true })
  for (let k = 0; k < 4; k++) care.push({ id: id(`b${k}`), who: "Young brother", title: "Sibling tuition", amount: 6_500_000, date: addMonthsIso(addDays(today, -45), -6 * k), sample: true })
  for (let k = 0; k < 24; k++) care.push({ id: id(`h${k}`), who: "Household", title: "Household", amount: 1_250_000, date: addMonthsIso(addDays(today, -3), -k), sample: true })
  care.push({ id: id("med"), who: "Parents", title: "Medical costs", amount: 4_034_000, date: addMonthsIso(today, -9), sample: true })

  // Total assets month by month, from 0 đ the month before the first deposit: what was put in so
  // far, with each asset's gain or loss growing in step until it reaches today's worth.
  const total = assets.reduce((s, a) => s + a.amount, 0)
  const nowMonth = today.slice(0, 7)
  const firstDay = holdings.flatMap((h) => h.ins.map(([, d]) => d)).sort()[0] ?? today
  const between = (a: string, b: string) => (Number(b.slice(0, 4)) - Number(a.slice(0, 4))) * 12 + Number(b.slice(5, 7)) - Number(a.slice(5, 7))
  const worth: WorthPoint[] = []
  for (let month = addMonthsIso(`${firstDay.slice(0, 7)}-01`, -1).slice(0, 7); month <= nowMonth; month = addMonthsIso(`${month}-01`, 1).slice(0, 7)) {
    let value = 0
    for (const h of holdings) {
      const put = h.ins.filter(([, d]) => d.slice(0, 7) <= month).reduce((s, [v]) => s + v, 0)
      const all = h.ins.reduce((s, [v]) => s + v, 0)
      if (put <= 0 || all <= 0) continue
      const first = h.ins[0][1].slice(0, 7)
      const f = Math.min(Math.max(between(first, month) / Math.max(between(first, nowMonth), 1), 0), 1)
      value += put * (1 + (h.now / all - 1) * f)
    }
    worth.push({ month, value: month === nowMonth ? total : Math.round(value) })
  }

  return { entries, notes, bills, assets, moves, care, worth, birthYear: Number(today.slice(0, 4)) - 27 }
}
