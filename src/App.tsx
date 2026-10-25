import { useCallback, useState } from "react"
import Home from "./screens/Home"
import Assistant, { type AssistantOpen } from "./screens/Assistant"
import EntrySheet, { SummarySheet } from "./screens/EntrySheet"
import { today } from "./lib/format"
import { useStore } from "./lib/store"
import "./screens/screens.css"

export default function App() {
  const store = useStore()
  const [day, setDay] = useState(today)
  const [hidden, setHidden] = useState(false)
  const [assistant, setAssistant] = useState<AssistantOpen | null>(null)
  const [openEntry, setOpenEntry] = useState<string | null>(null)
  const [summary, setSummary] = useState(false)

  const closeAssistant = useCallback(() => setAssistant(null), [])
  const closeEntry = useCallback(() => setOpenEntry(null), [])
  const closeSummary = useCallback(() => setSummary(false), [])
  const entry = store.entries.find((e) => e.id === openEntry)

  return (
    <div className="app">
      <Home
        day={day}
        onDayChange={setDay}
        entries={store.entries}
        name={store.name}
        hidden={hidden}
        onToggleHidden={() => setHidden((h) => !h)}
        onOpenAssistant={(opts) => setAssistant(opts ?? {})}
        onOpenEntry={setOpenEntry}
        onSummary={() => setSummary(true)}
      />
      {assistant && (
        <Assistant
          name={store.name}
          defaultDay={day}
          entries={store.entries}
          opts={assistant}
          onClose={closeAssistant}
          onSave={store.addEntries}
          onUndo={store.removeNote}
          onOpenDay={setDay}
        />
      )}
      {entry && (
        <EntrySheet
          key={entry.id}
          entry={entry}
          onClose={closeEntry}
          onSave={(patch) => store.updateEntry(entry.id, patch)}
          onDelete={() => {
            store.removeEntry(entry.id)
            setOpenEntry(null)
          }}
        />
      )}
      {summary && <SummarySheet day={day} entries={store.entries} onClose={closeSummary} />}
    </div>
  )
}
