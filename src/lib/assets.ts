/** What the user owns, as they choose to write it down. Nothing here talks to a bank. */

/** The four groups from Figma High Fi 2 › Asset (943:25860). */
export type AssetKind = "available" | "growing" | "aside" | "owed"

export type AssetIcon = "gold" | "fund" | "bank" | "cash" | "lent"

export type Asset = {
  id: string
  name: string
  kind: AssetKind
  icon: AssetIcon
  amount: number
  /** Last time the user updated the amount, "YYYY-MM-DD". */
  updated: string
  sample?: boolean
}

/** One change to an asset: put money in (positive) or took it out (negative). */
export type AssetMove = {
  id: string
  title: string
  icon: AssetIcon
  amount: number
  date: string
  sample?: boolean
}

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
export type WorthPoint = { month: string; value: number }

export const KINDS: { kind: AssetKind; label: string; color: string }[] = [
  { kind: "available", label: "Available", color: "var(--brand-600)" },
  { kind: "growing", label: "Growing", color: "#eaaa08" },
  { kind: "aside", label: "Set aside", color: "#5d65ef" },
  { kind: "owed", label: "Owed", color: "#e5562a" },
]

/** Tile for history rows: background, text, short mark. */
export const ASSET_TILE: Record<AssetIcon, { bg: string; ink: string; mark: string }> = {
  gold: { bg: "#f4b400", ink: "#fff", mark: "Au" },
  fund: { bg: "#1570ef", ink: "#fff", mark: "fm" },
  bank: { bg: "#6927da", ink: "#fff", mark: "TP" },
  cash: { bg: "#4c8a26", ink: "#fff", mark: "₫" },
  lent: { bg: "#e5562a", ink: "#fff", mark: "→" },
}

export const guessAssetIcon = (name: string, kind: AssetKind): AssetIcon => {
  const n = name.toLocaleLowerCase("vi")
  if (/gold|vàng|vang|sjc|pnj/.test(n)) return "gold"
  if (/fund|quỹ|quy|fmarket|stock|cổ phiếu|etf|vn30/.test(n)) return "fund"
  if (/bank|tiết kiệm|tiet kiem|saving|tp|vcb|techcom|mb|acb/.test(n)) return "bank"
  if (kind === "owed") return "lent"
  return "cash"
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
