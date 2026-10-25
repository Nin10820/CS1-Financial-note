import { useCallback, useState } from "react"
import Home from "./screens/Home"
import NoteScreen from "./screens/NoteScreen"
import NoteEditor from "./screens/NoteEditor"
import Due from "./screens/Due"
import BillSheet from "./screens/BillSheet"
import AddBill from "./screens/AddBill"
import { ComingUp, Installments, PaidHistory } from "./screens/DueSheets"
import Assistant, { type AssistantOpen } from "./screens/Assistant"
import SoonScreen from "./screens/SoonScreen"
import type { Tab } from "./components/TabBar"
import EntrySheet, { SummarySheet } from "./screens/EntrySheet"
import { today } from "./lib/format"
import { dueIn, ym } from "./lib/bills"
import { useStore } from "./lib/store"
import "./screens/screens.css"
import "./screens/note.css"
import "./screens/due.css"

type Screen = "transaction" | "note" | "due" | "installments" | "finance" | "profile"
type Overlay =
  | { kind: "assistant"; opts: AssistantOpen }
  | { kind: "entry"; id: string }
  | { kind: "summary" }
  | { kind: "editor" }
  | { kind: "bill"; id: string }
  | { kind: "add-bill" }
  | { kind: "coming-up" }
  | { kind: "paid-history" }
  | null

export default function App() {
  const store = useStore()
  const [screen, setScreen] = useState<Screen>("transaction")
  const [day, setDay] = useState(today)
  const [month, setMonth] = useState(() => ym(today()))
  const [hidden, setHidden] = useState(false)
  const [overlay, setOverlay] = useState<Overlay>(null)

  const close = useCallback(() => setOverlay(null), [])
  const go = (s: Screen) => {
    setOverlay(null)
    setScreen(s)
    window.scrollTo(0, 0)
  }
  const assistant = (opts: AssistantOpen = {}) => setOverlay({ kind: "assistant", opts })
  // Expense opens on Transaction (Note sits beside it); Due on the bill list.
  const onTab = (t: Tab) =>
    go(t === "expense" ? (screen === "note" ? "note" : "transaction") : t === "due" ? "due" : t)

  // The spending is recorded on the day the bill is ticked off — the day the money actually left.
  const toggleBill = (id: string, paid: boolean, amount?: number, m = month) => {
    const bill = store.bills.find((b) => b.id === id)
    if (bill) store.setBillPaid(bill, m, paid, today(), amount)
  }

  return (
    <div className="app">
      {screen === "transaction" && (
        <Home
          day={day}
          onDayChange={setDay}
          entries={store.entries}
          name={store.name}
          hidden={hidden}
          onToggleHidden={() => setHidden((h) => !h)}
          onOpenAssistant={assistant}
          onOpenEntry={(id) => setOverlay({ kind: "entry", id })}
          onSummary={() => setOverlay({ kind: "summary" })}
          onNote={() => go("note")}
          onDue={() => go("due")}
          onTab={onTab}
        />
      )}
      {screen === "note" && (
        <NoteScreen
          day={day}
          onDayChange={setDay}
          note={store.notes[day]}
          entries={store.entries}
          bills={store.bills}
          onTransactions={() => go("transaction")}
          onDue={() => go("due")}
          onNewNote={() => setOverlay({ kind: "editor" })}
          onOpenAssistant={() => assistant()}
          onTab={onTab}
        />
      )}
      {screen === "due" && (
        <Due
          month={month}
          onMonthChange={setMonth}
          bills={store.bills}
          name={store.name}
          hidden={hidden}
          onToggleHidden={() => setHidden((h) => !h)}
          onToggle={(bill, paid) => toggleBill(bill.id, paid)}
          onOpenBill={(id) => setOverlay({ kind: "bill", id })}
          onAdd={() => setOverlay({ kind: "add-bill" })}
          onComingUp={() => setOverlay({ kind: "coming-up" })}
          onHistory={() => setOverlay({ kind: "paid-history" })}
          onInstallments={() => go("installments")}
          onOpenAssistant={() => assistant()}
          onTab={onTab}
        />
      )}
      {screen === "installments" && (
        <Installments
          bills={store.bills}
          month={month}
          hidden={hidden}
          onBack={() => go("due")}
          onOpenBill={(id) => setOverlay({ kind: "bill", id })}
          onComingUp={() => setOverlay({ kind: "coming-up" })}
          onHistory={() => setOverlay({ kind: "paid-history" })}
          onAdd={() => setOverlay({ kind: "add-bill" })}
          onOpenAssistant={() => assistant()}
          onTab={onTab}
        />
      )}
      {(screen === "finance" || screen === "profile") && (
        <SoonScreen tab={screen} onTab={onTab} onOpenAssistant={() => assistant()} />
      )}

      {overlay?.kind === "assistant" && (
        <Assistant
          name={store.name}
          defaultDay={day}
          entries={store.entries}
          opts={overlay.opts}
          onClose={close}
          onSave={store.addEntries}
          onUndo={store.removeNote}
          onOpenDay={(d) => {
            setDay(d)
            go("transaction")
          }}
        />
      )}
      {overlay?.kind === "editor" && (
        <NoteEditor
          day={day}
          notes={store.notes}
          onClose={close}
          onSave={(date, lines) => {
            store.saveDayNote(date, lines)
            setDay(date)
            setOverlay({ kind: "assistant", opts: { note: { date, lines } } })
          }}
        />
      )}
      {overlay?.kind === "entry" &&
        (() => {
          const entry = store.entries.find((e) => e.id === overlay.id)
          return entry ? (
            <EntrySheet
              key={entry.id}
              entry={entry}
              onClose={close}
              onSave={(patch) => store.updateEntry(entry.id, patch)}
              onDelete={() => {
                store.removeEntry(entry.id)
                close()
              }}
            />
          ) : null
        })()}
      {overlay?.kind === "summary" && <SummarySheet day={day} entries={store.entries} onClose={close} />}
      {overlay?.kind === "bill" &&
        (() => {
          const bill = store.bills.find((b) => b.id === overlay.id)
          return bill ? (
            <BillSheet
              key={`${bill.id}-${month}`}
              bill={bill}
              month={month}
              onClose={close}
              onCheck={(paid, amount) => toggleBill(bill.id, paid, amount)}
              onDelete={() => {
                store.removeBill(bill.id)
                close()
              }}
            />
          ) : null
        })()}
      {overlay?.kind === "add-bill" && (
        <AddBill
          month={month}
          onClose={close}
          onSave={(bill) => {
            store.addBill(bill)
            // Stay on this month if the new bill shows up here; otherwise jump to when it starts.
            if (!dueIn(bill, month)) setMonth(ym(bill.start))
            setOverlay(null)
            if (screen !== "installments") setScreen("due")
          }}
        />
      )}
      {overlay?.kind === "coming-up" && <ComingUp bills={store.bills} month={month} onPick={(m) => setMonth(m)} onClose={close} />}
      {overlay?.kind === "paid-history" && (
        <PaidHistory
          bills={store.bills}
          onClose={close}
          onOpen={(id, m) => {
            setMonth(m)
            setOverlay({ kind: "bill", id })
          }}
        />
      )}
    </div>
  )
}
