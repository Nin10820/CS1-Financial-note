import { useCallback, useEffect, useState } from "react"
import type { Category, Flow } from "../components/ui"
import type { Bill } from "./bills"
import { SAVINGS_ID, guessAssetIcon, type Asset, type AssetKind, type AssetMove, type AssetMoveKind, type CareGift, type FamilyLoan, type WorthPoint } from "./assets"
import type { Appearance } from "./theme"
import { price, type HoldingUnit } from "./market"
import { today } from "./format"

/** One saved line. Lines saved together from one note share a `noteId`. */
export type Entry = {
  id: string
  date: string
  title: string
  amount: number
  flow: Flow
  category: CategoryName
  noteId: string
  /** The note exactly as the user wrote it. */
  source: string
  createdAt: number
  /** Set when the entry was created by checking off a bill. */
  billId?: string
  /** Part of the sample data (removable in one tap). */
  sample?: boolean
  /** Tags picked in the entry sheet ("Food", "Drinks", or the user's own). */
  tags?: string[]
  /** The user's own words about this line. */
  comment?: string
  /** Where the money came from or went to: "Cash", "Card", "Transfer" or an asset's name. */
  paidFrom?: string
}

/** The free-form note for a day (the "Note" screen): lines as the user wrote them. */
export type DayNote = { lines: string[]; updatedAt: number }

export const CATEGORIES = ["Food", "Transport", "Shopping", "Bills", "Received", "Other"] as const
export type CategoryName = (typeof CATEGORIES)[number]

/** Colour group for the category label on a row. */
export function categoryTone(c: CategoryName): Category {
  if (c === "Food") return "food"
  if (c === "Transport") return "transport"
  if (c === "Received") return "received"
  return "other"
}

const KEY = "financial-note:v1"

/** Display choices from Profile › Display. */
export type Prefs = {
  /** Start with amounts hidden every time the app opens. */
  hideOnOpen: boolean
  /** Apply the same hiding to the Finance tab. */
  hideAssets: boolean
  /** "YYYY-MM-DD" — first time the app was opened on this device. */
  joined: string
  birthYear?: number
  /** Tags the user made with "New tag". */
  customTags?: string[]
  /** Bank apps the user pays from (VietQR app ids), picked after scanning a QR. */
  banks?: string[]
  /** Auto (follow the phone), Light or Dark. */
  appearance?: Appearance
  /** The monthly saving goal on Analytics (0 or unset: use the suggestion). */
  savingGoal?: number
  /** Count bills in the daily budget on Analytics. */
  countBills?: boolean
  /** Each year's monthly plan for money going in ("2024": 5000000). */
  depositPlans?: Record<string, number>
  /** How much more gold costs here than the world price, in percent. */
  goldPremium?: number
}

type Saved = {
  entries: Entry[]
  name: string
  notes: Record<string, DayNote>
  bills: Bill[]
  assets: Asset[]
  moves: AssetMove[]
  care: CareGift[]
  loans: FamilyLoan[]
  /** Month-end net worth for the chart. Only sample data fills it today. */
  worth: WorthPoint[]
  prefs: Prefs
  /** Day-note dates that came from the sample, so removing it leaves the user's notes alone. */
  sampleNotes: string[]
}

const blank = (): Saved => ({
  entries: [],
  name: "Nin",
  notes: {},
  bills: [],
  assets: [],
  moves: [],
  care: [],
  loans: [],
  worth: [],
  prefs: { hideOnOpen: false, hideAssets: false, joined: today() },
  sampleNotes: [],
})

/** Drops the old sample items a browser may still have saved; the user's own data stays. */
function withoutSample(s: Saved): Saved {
  const keep = <T extends { sample?: boolean }>(list: T[]) => list.filter((i) => !i.sample)
  const notes = { ...s.notes }
  for (const d of s.sampleNotes) delete notes[d]
  const hadSample = s.assets.some((a) => a.sample) || s.entries.some((e) => e.sample)
  return {
    ...s,
    entries: keep(s.entries),
    bills: keep(s.bills),
    assets: keep(s.assets),
    moves: keep(s.moves),
    care: keep(s.care),
    loans: keep(s.loans),
    worth: hadSample ? [] : s.worth,
    notes,
    sampleNotes: [],
  }
}

/**
 * One move on an asset. Held in units, money in or out buys or sells some at today's price
 * (unless `exactUnits`: the caller sets the quantity itself).
 */
function applyMove(s: Saved, id: string, kind: AssetMoveKind, amount: number, date: string, exactUnits = false): Saved {
  const a = s.assets.find((x) => x.id === id)
  if (!a) return s
  const change = kind === "in" ? amount : kind === "out" ? -Math.min(amount, a.amount) : amount - a.amount
  if (!change) return s
  const p = a.unit ? price(a.unit, s.prefs.goldPremium ?? 0) : null
  const quantity = !exactUnits && kind !== "value" && a.quantity != null && p ? Math.max(0, Math.round((a.quantity + change / p) * 10_000) / 10_000) : a.quantity
  const assets = s.assets.map((x) => (x.id === id ? { ...x, amount: x.amount + change, quantity, updated: date > x.updated ? date : x.updated } : x))
  const moves = [...withStart(s.moves, a), { id: uid(), title: a.name, icon: a.icon, amount: change, date, assetId: a.id, kind }]
  return shiftWorth({ ...s, assets, moves }, change, date)
}

/** An asset written down before moves were kept gets its amount then as a starting point. */
function withStart(moves: AssetMove[], a: Asset): AssetMove[] {
  if (moves.some((m) => m.assetId === a.id)) return moves
  return [...moves, { id: uid(), title: a.name, icon: a.icon, amount: a.amount, date: a.updated, assetId: a.id, kind: "in" }]
}

/**
 * Money dated in the past moves the line from that month on instead of overwriting it; this
 * month's point is then the total of everything now.
 */
function shiftWorth(s: Saved, change: number, date: string): Saved {
  const month = date.slice(0, 7)
  const now = today().slice(0, 7)
  let worth = s.worth
  if (month < now) {
    worth = worth.map((p) => (p.month >= month && p.month < now ? { ...p, value: Math.max(0, p.value + change) } : p))
    if (!worth.some((p) => p.month === month)) {
      const before = [...worth].filter((p) => p.month < month).sort((x, y) => y.month.localeCompare(x.month))[0]?.value ?? 0
      worth = [...worth, { month, value: Math.max(0, before + change) }].sort((x, y) => x.month.localeCompare(y.month))
    }
  }
  return recordWorth({ ...s, worth }, today())
}

/** The Total Asset line: this month's point is the total of everything now. */
function recordWorth(s: Saved, date: string): Saved {
  const month = date.slice(0, 7)
  const value = s.assets.reduce((t, a) => t + a.amount, 0)
  const worth = s.worth.some((p) => p.month === month)
    ? s.worth.map((p) => (p.month === month ? { ...p, value } : p))
    : [...s.worth, { month, value }].sort((a, b) => a.month.localeCompare(b.month))
  return { ...s, worth }
}

function load(): Saved {
  try {
    const raw = localStorage.getItem(KEY)
    // First launch on this device: start empty.
    if (!raw) return blank()
    const p = JSON.parse(raw) as Partial<Saved>
    const b = blank()
    const loaded: Saved = {
      entries: Array.isArray(p.entries) ? p.entries : [],
      name: p.name || "Nin",
      notes: p.notes && typeof p.notes === "object" ? p.notes : {},
      bills: Array.isArray(p.bills) ? p.bills : [],
      assets: Array.isArray(p.assets) ? p.assets : [],
      moves: Array.isArray(p.moves) ? p.moves : [],
      care: Array.isArray(p.care) ? p.care : [],
      loans: Array.isArray(p.loans) ? p.loans : [],
      worth: Array.isArray(p.worth) ? p.worth : [],
      prefs: { ...b.prefs, ...(p.prefs ?? {}) },
      sampleNotes: Array.isArray(p.sampleNotes) ? p.sampleNotes : [],
    }
    return withoutSample(loaded)
  } catch {
    // Private mode or corrupt data: start empty rather than crash.
    return blank()
  }
}

export const uid = () =>
  crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random().toString(36).slice(2)}`

/** Everything lives on this device (localStorage). No account, no server. */
export function useStore() {
  const [state, setState] = useState<Saved>(load)

  useEffect(() => {
    try {
      localStorage.setItem(KEY, JSON.stringify(state))
    } catch {
      // Storage full or blocked; the session still works in memory.
    }
  }, [state])

  const addEntries = useCallback((list: Entry[]) => setState((s) => ({ ...s, entries: [...s.entries, ...list] })), [])
  const updateEntry = useCallback(
    (id: string, patch: Partial<Entry>) =>
      setState((s) => ({ ...s, entries: s.entries.map((e) => (e.id === id ? { ...e, ...patch } : e)) })),
    [],
  )
  const removeEntry = useCallback((id: string) => setState((s) => ({ ...s, entries: s.entries.filter((e) => e.id !== id) })), [])
  const removeNote = useCallback(
    (noteId: string) => setState((s) => ({ ...s, entries: s.entries.filter((e) => e.noteId !== noteId) })),
    [],
  )

  const saveDayNote = useCallback(
    (date: string, lines: string[]) =>
      setState((s) => ({ ...s, notes: { ...s.notes, [date]: { lines, updatedAt: Date.now() } } })),
    [],
  )

  const addBill = useCallback((bill: Bill) => setState((s) => ({ ...s, bills: [...s.bills, bill] })), [])
  const updateBill = useCallback(
    (id: string, patch: Partial<Bill>) =>
      setState((s) => ({ ...s, bills: s.bills.map((b) => (b.id === id ? { ...b, ...patch } : b)) })),
    [],
  )
  const removeBill = useCallback(
    (id: string) =>
      setState((s) => ({ ...s, bills: s.bills.filter((b) => b.id !== id), entries: s.entries.filter((e) => e.billId !== id) })),
    [],
  )

  /** Checking a bill off also records it as spending, so the Transaction list stays complete. */
  const setBillPaid = useCallback((bill: Bill, month: string, paid: boolean, date: string, amount?: number) => {
    setState((s) => {
      const current = s.bills.find((b) => b.id === bill.id)
      if (!current) return s
      if (paid) {
        if (current.paid[month]) return s
        const entryId = uid()
        const now = Date.now()
        const entry: Entry = {
          id: entryId,
          date,
          title: current.name,
          amount: amount ?? current.amount,
          flow: "out",
          category: "Bills",
          noteId: `bill-${current.id}-${month}`,
          source: `Checked off “${current.name}” in Due`,
          createdAt: now,
          billId: current.id,
        }
        return {
          ...s,
          entries: [...s.entries, entry],
          bills: s.bills.map((b) =>
            b.id === current.id ? { ...b, paid: { ...b.paid, [month]: { amount: amount ?? current.amount, at: now, entryId } } } : b,
          ),
        }
      }
      const record = current.paid[month]
      if (!record) return s
      const rest = { ...current.paid }
      delete rest[month]
      return {
        ...s,
        entries: s.entries.filter((e) => e.id !== record.entryId),
        bills: s.bills.map((b) => (b.id === current.id ? { ...b, paid: rest } : b)),
      }
    })
  }, [])

  const setName = useCallback((name: string) => setState((s) => ({ ...s, name: name.trim() || s.name })), [])
  const setPrefs = useCallback((patch: Partial<Prefs>) => setState((s) => ({ ...s, prefs: { ...s.prefs, ...patch } })), [])
  /** A new asset; money dated in the past ("Put in on") shows on the line from that month. */
  const addAsset = useCallback(
    (asset: Asset) =>
      setState((s) =>
        shiftWorth(
          {
            ...s,
            assets: [...s.assets, asset],
            moves: [...s.moves, { id: uid(), title: asset.name, icon: asset.icon, amount: asset.amount, date: asset.updated, assetId: asset.id, kind: "in" }],
          },
          asset.amount,
          asset.updated,
        ),
      ),
    [],
  )
  /** Money put in, taken out, or the value now. `amount` is what moved, or for "value" the worth now. */
  const moveAsset = useCallback((id: string, kind: AssetMoveKind, amount: number, date: string) => {
    setState((s) => applyMove(s, id, kind, amount, date))
  }, [])
  /** Put in, take out or set what's held in the asset's own unit (2 phân, 100 $) at today's price. */
  const moveUnits = useCallback((id: string, kind: AssetMoveKind, units: number, date: string) => {
    setState((s) => {
      const a = s.assets.find((x) => x.id === id)
      const p = a?.unit ? price(a.unit, s.prefs.goldPremium ?? 0) : null
      if (!a || !a.unit || !p) return s
      const held = a.quantity ?? 0
      const out = Math.min(units, held)
      const q = kind === "in" ? held + units : kind === "out" ? held - out : units
      const dong = Math.round((kind === "out" ? out : units) * p)
      const next = applyMove(s, id, kind, dong, date, true)
      return { ...next, assets: next.assets.map((x) => (x.id === id ? { ...x, quantity: Math.round(q * 10_000) / 10_000 } : x)) }
    })
  }, [])
  /** Sets what an asset holds in its own unit (or clears it). */
  const setHolding = useCallback((id: string, quantity?: number, unit?: HoldingUnit) => {
    setState((s) => ({
      ...s,
      assets: s.assets.map((a) => (a.id === id ? { ...a, quantity: unit && quantity ? quantity : undefined, unit: unit && quantity ? unit : undefined } : a)),
    }))
  }, [])
  /** Every asset held in units at quantity × today's price; one "Value changed" line a day each. */
  const revalueHoldings = useCallback(() => {
    setState((s) => {
      const day = today()
      let next = s
      for (const a of s.assets) {
        const p = a.unit ? price(a.unit, s.prefs.goldPremium ?? 0) : null
        if (!a.quantity || !p) continue
        const delta = Math.round(a.quantity * p) - a.amount
        if (!delta) continue
        let moves = withStart(next.moves, a)
        const latest = moves.filter((m) => m.assetId === a.id).sort((x, y) => x.date.localeCompare(y.date)).pop()
        if (latest && latest.kind === "value" && latest.date === day)
          moves = moves.map((m) => (m === latest ? { ...m, amount: m.amount + delta } : m)).filter((m) => m.amount !== 0)
        else moves = [...moves, { id: uid(), title: a.name, icon: a.icon, amount: delta, date: day, assetId: a.id, kind: "value" }]
        next = shiftWorth(
          { ...next, moves, assets: next.assets.map((x) => (x.id === a.id ? { ...x, amount: x.amount + delta, updated: day > x.updated ? day : x.updated } : x)) },
          delta,
          day,
        )
      }
      return next
    })
  }, [])
  /** Deletes one line of an asset's history: its amount and the line go back as if it never happened. */
  const removeMove = useCallback((moveId: string) => {
    setState((s) => {
      const m = s.moves.find((x) => x.id === moveId)
      if (!m) return s
      const assets = s.assets.map((a) => (a.id === m.assetId ? { ...a, amount: Math.max(0, a.amount - m.amount) } : a))
      return shiftWorth({ ...s, assets, moves: s.moves.filter((x) => x.id !== moveId) }, -m.amount, m.date)
    })
  }, [])
  /** Renames or regroups an asset; its history follows the new name. */
  const editAsset = useCallback((id: string, name: string, kind: AssetKind) => {
    setState((s) => {
      const icon = id === SAVINGS_ID ? "piggy" : guessAssetIcon(name, kind)
      return {
        ...s,
        assets: s.assets.map((a) => (a.id === id ? { ...a, name, kind, icon } : a)),
        moves: s.moves.map((m) => (m.assetId === id ? { ...m, title: name, icon } : m)),
      }
    })
  }, [])
  const removeAsset = useCallback(
    (id: string) =>
      setState((s) => recordWorth({ ...s, assets: s.assets.filter((a) => a.id !== id), moves: s.moves.filter((m) => m.assetId !== id) }, today())),
    [],
  )
  /** Notes money put aside toward the saving goal, on the Savings asset. No money moves. */
  const putAside = useCallback((amount: number, date: string) => {
    if (amount <= 0) return
    setState((s) => {
      const had = s.assets.find((a) => a.id === SAVINGS_ID)
      const savings: Asset = had ?? { id: SAVINGS_ID, name: "Savings", kind: "aside", icon: "piggy", amount: 0, updated: date }
      const next = { ...savings, amount: savings.amount + amount, updated: date > savings.updated ? date : savings.updated }
      const assets = had ? s.assets.map((a) => (a.id === SAVINGS_ID ? next : a)) : [...s.assets, next]
      return recordWorth(
        { ...s, assets, moves: [...s.moves, { id: uid(), title: "Savings", icon: "piggy", amount, date, assetId: SAVINGS_ID, kind: "in" }] },
        date,
      )
    })
  }, [])
  /** Takes back what was put aside on a day (the quick save's undo). */
  const undoPutAside = useCallback((date: string) => {
    setState((s) => {
      const gone = s.moves.filter((m) => m.assetId === SAVINGS_ID && m.date === date && m.kind === "in")
      const sum = gone.reduce((t, m) => t + m.amount, 0)
      return recordWorth(
        {
          ...s,
          assets: s.assets.map((a) => (a.id === SAVINGS_ID ? { ...a, amount: a.amount - Math.min(a.amount, sum) } : a)),
          moves: s.moves.filter((m) => !gone.includes(m)),
        },
        date,
      )
    })
  }, [])
  const addLoan = useCallback((loan: FamilyLoan) => setState((s) => ({ ...s, loans: [...s.loans, loan] })), [])
  const removeLoan = useCallback((id: string) => setState((s) => ({ ...s, loans: s.loans.filter((l) => l.id !== id) })), [])
  /** Wipes everything on this device and starts clean. */
  const clearAll = useCallback(() => setState({ ...blank() }), [])

  return {
    ...state,
    setName,
    setPrefs,
    addAsset,
    moveAsset,
    moveUnits,
    setHolding,
    revalueHoldings,
    removeMove,
    editAsset,
    removeAsset,
    putAside,
    undoPutAside,
    addLoan,
    removeLoan,
    clearAll,
    addEntries,
    updateEntry,
    removeEntry,
    removeNote,
    saveDayNote,
    addBill,
    updateBill,
    removeBill,
    setBillPaid,
  }
}

export type Store = ReturnType<typeof useStore>
