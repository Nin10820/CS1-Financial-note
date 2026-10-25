import { useCallback, useEffect, useState } from "react"
import type { Category, Flow } from "../components/ui"

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
}

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

type Saved = { entries: Entry[]; name: string }

function load(): Saved {
  try {
    const raw = localStorage.getItem(KEY)
    if (raw) {
      const parsed = JSON.parse(raw) as Partial<Saved>
      return { entries: Array.isArray(parsed.entries) ? parsed.entries : [], name: parsed.name || "Nin" }
    }
  } catch {
    // Private mode or corrupt data: start empty rather than crash.
  }
  return { entries: [], name: "Nin" }
}

export const uid = () => (crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random().toString(36).slice(2)}`)

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

  const addEntries = useCallback((list: Entry[]) => {
    setState((s) => ({ ...s, entries: [...s.entries, ...list] }))
  }, [])
  const updateEntry = useCallback((id: string, patch: Partial<Entry>) => {
    setState((s) => ({ ...s, entries: s.entries.map((e) => (e.id === id ? { ...e, ...patch } : e)) }))
  }, [])
  const removeEntry = useCallback((id: string) => {
    setState((s) => ({ ...s, entries: s.entries.filter((e) => e.id !== id) }))
  }, [])
  const removeNote = useCallback((noteId: string) => {
    setState((s) => ({ ...s, entries: s.entries.filter((e) => e.noteId !== noteId) }))
  }, [])

  return { entries: state.entries, name: state.name, addEntries, updateEntry, removeEntry, removeNote }
}
