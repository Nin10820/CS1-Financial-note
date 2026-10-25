import { useCallback, useEffect, useState } from "react"
import type { Category, Flow } from "../components/ui"
import type { Bill } from "./bills"

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

type Saved = { entries: Entry[]; name: string; notes: Record<string, DayNote>; bills: Bill[] }

function load(): Saved {
  const empty: Saved = { entries: [], name: "Nin", notes: {}, bills: [] }
  try {
    const raw = localStorage.getItem(KEY)
    if (!raw) return empty
    const p = JSON.parse(raw) as Partial<Saved>
    return {
      entries: Array.isArray(p.entries) ? p.entries : [],
      name: p.name || "Nin",
      notes: p.notes && typeof p.notes === "object" ? p.notes : {},
      bills: Array.isArray(p.bills) ? p.bills : [],
    }
  } catch {
    // Private mode or corrupt data: start empty rather than crash.
    return empty
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

  return {
    ...state,
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
