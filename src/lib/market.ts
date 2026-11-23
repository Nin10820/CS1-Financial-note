/**
 * Assets held in their own unit (gold by the chỉ, foreign money, coins) and today's public prices
 * in đồng (port of the iOS Market.swift). Only public price lists come in; nothing about the user
 * goes out. Sources, named on screen as their free terms ask: ExchangeRate-API, gold-api.com, CoinGecko.
 */
export type HoldingUnit = "usd" | "eur" | "jpy" | "krw" | "cny" | "sgd" | "thb" | "aud" | "chi" | "phan" | "luong" | "btc" | "eth" | "usdt"

export const UNITS: { unit: HoldingUnit; label: string; name: string }[] = [
  { unit: "chi", label: "chỉ", name: "Gold by the chỉ" },
  { unit: "phan", label: "phân", name: "Gold by the phân (1/10 chỉ)" },
  { unit: "luong", label: "lượng", name: "Gold by the lượng / cây (10 chỉ)" },
  { unit: "usd", label: "$", name: "US dollar" },
  { unit: "eur", label: "€", name: "Euro" },
  { unit: "jpy", label: "¥", name: "Japanese yen" },
  { unit: "krw", label: "₩", name: "Korean won" },
  { unit: "cny", label: "元", name: "Chinese yuan" },
  { unit: "sgd", label: "S$", name: "Singapore dollar" },
  { unit: "thb", label: "฿", name: "Thai baht" },
  { unit: "aud", label: "A$", name: "Australian dollar" },
  { unit: "btc", label: "BTC", name: "Bitcoin" },
  { unit: "eth", label: "ETH", name: "Ethereum" },
  { unit: "usdt", label: "USDT", name: "Tether" },
]
export const unitLabel = (u: HoldingUnit) => UNITS.find((x) => x.unit === u)?.label ?? u
export const isGold = (u: HoldingUnit) => u === "chi" || u === "phan" || u === "luong"
const COINS: HoldingUnit[] = ["btc", "eth", "usdt"]

/** The key in the price list and how many of it one unit is (a phân is a tenth of a chỉ). */
function priceKey(u: HoldingUnit): [string, number] {
  if (u === "chi") return ["GOLD_CHI", 1]
  if (u === "phan") return ["GOLD_CHI", 0.1]
  if (u === "luong") return ["GOLD_CHI", 10]
  return [u.toUpperCase(), 1]
}

/** "5 chỉ", "1,000 $", "0.05 BTC" */
export function holdingText(q: number, u: HoldingUnit) {
  const n = q.toLocaleString("en-US", { maximumFractionDigits: 4 })
  return isGold(u) ? `${n} ${unitLabel(u)}` : `${n} ${unitLabel(u)}`
}

/** A first guess from the asset's look: gold in chỉ, dollars, bitcoin. */
export const guessUnit = (icon: string): HoldingUnit | undefined => (icon === "gold" ? "chi" : icon === "usd" ? "usd" : icon === "coin" ? "btc" : undefined)

/* ── Prices ─────────────────────────────────────────────── */

const KEY = "financial-note:prices"
type Saved = { prices: Record<string, number>; at: number }

function read(): Saved {
  try {
    const p = JSON.parse(localStorage.getItem(KEY) ?? "null") as Saved | null
    return p && p.prices ? p : { prices: {}, at: 0 }
  } catch {
    return { prices: {}, at: 0 }
  }
}

/** When the prices were downloaded (0: never). */
export const pricesAt = () => read().at
export const SOURCES = "ExchangeRate-API, gold-api.com, CoinGecko"

/** Đồng for one of this unit, with the gold premium (percent above the world price) added. */
export function price(u: HoldingUnit, goldPremium = 0): number | null {
  const [key, times] = priceKey(u)
  const p = read().prices[key]
  if (!p) return null
  return p * times * (isGold(u) ? 1 + goldPremium / 100 : 1)
}

/** One chỉ is 3.75 g; a troy ounce is 31.1034768 g. */
const CHI_PER_OUNCE = 3.75 / 31.1034768

async function json<T>(url: string): Promise<T | null> {
  try {
    const ctrl = new AbortController()
    const t = setTimeout(() => ctrl.abort(), 10_000)
    const r = await fetch(url, { signal: ctrl.signal, cache: "no-store" })
    clearTimeout(t)
    return r.ok ? ((await r.json()) as T) : null
  } catch {
    return null
  }
}

/** Downloads the three lists, keeping whatever each gave. False when nothing came back (offline). */
export async function refreshPrices(): Promise<boolean> {
  const out = { ...read().prices }
  const [fx, gold, coins] = await Promise.all([
    json<{ rates: Record<string, number> }>("https://open.er-api.com/v6/latest/USD"),
    json<{ price: number }>("https://api.gold-api.com/price/XAU"),
    json<Record<string, { vnd: number }>>("https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,tether&vs_currencies=vnd"),
  ])
  let got = false
  const vnd = fx?.rates?.VND
  if (vnd) {
    // The list is per US dollar: đồng for one of each = VND ÷ that currency's rate.
    for (const u of UNITS) {
      if (isGold(u.unit) || COINS.includes(u.unit)) continue
      const r = fx!.rates[u.unit.toUpperCase()]
      if (r) out[u.unit.toUpperCase()] = vnd / r
    }
    got = true
  }
  if (gold?.price && out.USD) {
    out.GOLD_CHI = Math.round(gold.price * CHI_PER_OUNCE * out.USD)
    got = true
  }
  if (coins) {
    for (const [id, key] of [
      ["bitcoin", "BTC"],
      ["ethereum", "ETH"],
      ["tether", "USDT"],
    ] as const)
      if (coins[id]?.vnd) out[key] = coins[id].vnd
    got = true
  }
  if (!got) return false
  try {
    localStorage.setItem(KEY, JSON.stringify({ prices: out, at: Date.now() }))
  } catch {
    // Storage blocked: prices last until the page closes.
  }
  return true
}

/** Prices older than three hours (or none yet). */
export const pricesStale = () => Date.now() - read().at > 3 * 3600_000

/* ── Reading holdings from words ───────────────────────── */

/** "1,000" and "1.000" are a thousand; "3,5" and "0.01" are decimals. */
export function readNumber(s: string) {
  if (/^\d{1,3}([.,]\d{3})+$/.test(s)) return Number(s.replace(/\D/g, ""))
  return Number(s.replace(",", "."))
}

/** The quantity and unit in a line ("5 chỉ", "700 usd", "$700", "0.01 btc"), and the rest of the line. */
export function readUnits(line: string): { quantity: number; unit: HoldingUnit; rest: string } | null {
  const lower = line.toLocaleLowerCase("vi")
  const pats: [RegExp, number, number][] = [
    [/(\d+(?:[.,]\d+)*)\s*(chỉ|chi|phân|phan|lượng|luong|cây|cay|usd|đô la|đô|eur|€|btc|eth|usdt|\$)(?![\p{L}])/u, 1, 2],
    [/(?<![\p{L}])(usd|eur|btc|eth|usdt|\$|€)\s*(\d+(?:[.,]\d+)*)/u, 2, 1],
  ]
  for (const [re, ni, ui] of pats) {
    const m = lower.match(re)
    if (!m) continue
    const q = readNumber(m[ni])
    if (!(q > 0)) continue
    const w = m[ui]
    const unit: HoldingUnit =
      w === "chỉ" || w === "chi" ? "chi" : w === "phân" || w === "phan" ? "phan" : ["lượng", "luong", "cây", "cay"].includes(w) ? "luong" : w === "eur" || w === "€" ? "eur" : w === "btc" ? "btc" : w === "eth" ? "eth" : w === "usdt" ? "usdt" : "usd"
    return { quantity: q, unit, rest: line.slice(0, m.index) + line.slice((m.index ?? 0) + m[0].length) }
  }
  return null
}
