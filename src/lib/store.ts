import { useCallback, useEffect, useState } from "react"
import type { Category, Flow } from "../components/ui"
import type { Bill } from "./bills"
import type { Asset, AssetMove, CareGift, WorthPoint } from "./assets"
import { makeSample } from "./sample"
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
}

type Saved = {
  entries: Entry[]
  name: string
  notes: Record<string, DayNote>
  bills: Bill[]
  assets: Asset[]
  moves: AssetMove[]
  care: CareGift[]
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
  worth: [],
  prefs: { hideOnOpen: false, hideAssets: false, joined: today() },
  sampleNotes: [],
})

/** Adds the sample on top of what is there (sample items first removed, so it never doubles). */
function withSample(s: Saved): Saved {
  const base = withoutSample(s)
  const x = makeSample(today())
  const notes = { ...base.notes }
  const sampleNotes: string[] = []
  for (const [date, note] of Object.entries(x.notes))
    if (!notes[date]) {
      notes[date] = note
      sampleNotes.push(date)
    }
  return {
    ...base,
    entries: [...base.entries, ...x.entries],
    bills: [...base.bills, ...x.bills],
    assets: [...base.assets, ...x.assets],
    moves: [...base.moves, ...x.moves],
    care: [...base.care, ...x.care],
    worth: base.worth.length ? base.worth : x.worth,
    notes,
    sampleNotes,
    prefs: { ...base.prefs, birthYear: base.prefs.birthYear ?? x.birthYear },
  }
}

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
    worth: hadSample ? [] : s.worth,
    notes,
    sampleNotes: [],
  }
}

function load(): Saved {
  try {
    const raw = localStorage.getItem(KEY)
    // First launch on this device: start with the sample so every screen has something to show.
    if (!raw) return withSample(blank())
    const p = JSON.parse(raw) as Partial<Saved>
    const b = blank()
    return {
      entries: Array.isArray(p.entries) ? p.entries : [],
      name: p.name || "Nin",
      notes: p.notes && typeof p.notes === "object" ? p.notes : {},
      bills: Array.isArray(p.bills) ? p.bills : [],
      assets: Array.isArray(p.assets) ? p.assets : [],
      moves: Array.isArray(p.moves) ? p.moves : [],
      care: Array.isArray(p.care) ? p.care : [],
      worth: Array.isArray(p.worth) ? p.worth : [],
      prefs: { ...b.prefs, ...(p.prefs ?? {}) },
      sampleNotes: Array.isArray(p.sampleNotes) ? p.sampleNotes : [],
    }
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
  const addAsset = useCallback(
    (asset: Asset) =>
      setState((s) => ({
        ...s,
        assets: [...s.assets, asset],
        moves: [...s.moves, { id: uid(), title: asset.name, icon: asset.icon, amount: asset.amount, date: asset.updated }],
      })),
    [],
  )
  const loadSample = useCallback(() => setState((s) => withSample(s)), [])
  const clearSample = useCallback(() => setState((s) => withoutSample(s)), [])
  /** Wipes everything on this device and starts clean (no sample). */
  const clearAll = useCallback(() => setState({ ...blank() }), [])
  const hasSample = state.entries.some((e) => e.sample) || state.assets.some((a) => a.sample) || state.bills.some((b) => b.sample)

  return {
    ...state,
    hasSample,
    setName,
    setPrefs,
    addAsset,
    loadSample,
    clearSample,
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
