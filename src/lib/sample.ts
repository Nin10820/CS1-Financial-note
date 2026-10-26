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

  // 122,647,000 đ split 40 / 30 / 20 / 10 like the Figma overview.
  const assets: Asset[] = [
    { id: id("cash"), name: "Cash & bank account", kind: "available", icon: "cash", amount: 49_059_000, updated: today, sample: true },
    { id: id("gold"), name: "Gold", kind: "growing", icon: "gold", amount: 14_500_000, updated: addDays(today, -66), sample: true },
    { id: id("fund"), name: "Fund - Fmarket", kind: "growing", icon: "fund", amount: 22_294_000, updated: addDays(today, -95), sample: true },
    { id: id("saving"), name: "Saving - TP Bank", kind: "aside", icon: "bank", amount: 24_529_000, updated: addDays(today, -280), sample: true },
    { id: id("lent"), name: "Lent to Minh", kind: "owed", icon: "lent", amount: 12_265_000, updated: addDays(today, -40), sample: true },
  ]

  const moves: AssetMove[] = [
    { id: id("m1"), title: "Gold", icon: "gold", amount: 14_500_000, date: addDays(today, -66), sample: true },
    { id: id("m2"), title: "Fund - Fmarket", icon: "fund", amount: 5_000_000, date: addDays(today, -95), sample: true },
    { id: id("m3"), title: "Saving - TP Bank", icon: "bank", amount: 450_000, date: addDays(today, -280), sample: true },
    { id: id("m4"), title: "Lent to Minh", icon: "lent", amount: 12_265_000, date: addDays(today, -40), sample: true },
    { id: id("m5"), title: "Fund - Fmarket", icon: "fund", amount: 3_000_000, date: addDays(today, -160), sample: true },
  ]

  // Family support: parents every month, the younger brother's tuition each term, household bills.
  const care: CareGift[] = []
  for (let k = 0; k < 46; k++) care.push({ id: id(`p${k}`), who: "Parents", title: "Parents support", amount: k < 12 ? 2_000_000 : 1_500_000, date: addMonthsIso(addDays(today, -6), -k), sample: true })
  for (let k = 0; k < 4; k++) care.push({ id: id(`b${k}`), who: "Young brother", title: "Sibling tuition", amount: 6_500_000, date: addMonthsIso(addDays(today, -45), -6 * k), sample: true })
  for (let k = 0; k < 24; k++) care.push({ id: id(`h${k}`), who: "Household", title: "Household", amount: 1_250_000, date: addMonthsIso(addDays(today, -3), -k), sample: true })
  care.push({ id: id("med"), who: "Parents", title: "Medical costs", amount: 4_034_000, date: addMonthsIso(today, -9), sample: true })

  // Net worth by month since Jan 2020: slow growth with some wobble, ending at today's total.
  const total = assets.reduce((s, a) => s + a.amount, 0)
  const [ty, tm] = today.split("-").map(Number)
  const months = (ty - 2020) * 12 + tm
  const worth: WorthPoint[] = Array.from({ length: months }, (_, k) => {
    const t = k / (months - 1)
    const wobble = Math.sin(k * 0.9) * 0.05 + Math.sin(k * 0.37) * 0.07
    const value = Math.round(total * (0.18 + 0.82 * t ** 1.6) * (1 + wobble * (1 - t * 0.6)))
    const y = 2020 + Math.floor(k / 12)
    return { month: `${y}-${String((k % 12) + 1).padStart(2, "0")}`, value: k === months - 1 ? total : value }
  })

  return { entries, notes, bills, assets, moves, care, worth, birthYear: Number(today.slice(0, 4)) - 27 }
}
