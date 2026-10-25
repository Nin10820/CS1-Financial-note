import { useState } from "react"
import { Amount, Button, IconButton } from "../components/ui"
import { clock, longDate, money, shortDate, toISODate, today } from "../lib/format"
import { CATEGORIES, categoryTone, type CategoryName, type Entry } from "../lib/store"
import ModalSheet, { ModalHeader } from "./ModalSheet"

/** High Fi "Expense" detail (584:6591): category tag, the amount, the facts, then Delete / Edit. */
export default function EntrySheet({
  entry,
  onClose,
  onSave,
  onDelete,
}: {
  entry: Entry
  onClose: () => void
  onSave: (patch: Partial<Entry>) => void
  onDelete: () => void
}) {
  const [editing, setEditing] = useState(false)
  const [draft, setDraft] = useState(entry)
  const [confirmDelete, setConfirmDelete] = useState(false)
  const valid = draft.title.trim() && draft.amount > 0

  return (
    <ModalSheet
      label={entry.title}
      onClose={onClose}
      size="auto"
      header={
        <ModalHeader
          title={entry.flow === "out" ? "Expense" : "Received"}
          right={<IconButton icon="close" label="Close" variant="glass-strong" onClick={onClose} />}
        />
      }
      footer={
        <div className="entry__foot">
          {editing ? (
            <>
              <Button
                variant="outline"
                size="lg"
                onClick={() => {
                  setDraft(entry)
                  setEditing(false)
                }}
              >
                Cancel
              </Button>
              <Button
                variant="primary"
                size="lg"
                disabled={!valid}
                onClick={() => {
                  onSave({ ...draft, title: draft.title.trim() })
                  setEditing(false)
                }}
              >
                Save
              </Button>
            </>
          ) : confirmDelete ? (
            <>
              <Button variant="outline" size="lg" onClick={() => setConfirmDelete(false)}>
                Keep it
              </Button>
              <Button variant="primary" size="lg" className="is-danger" onClick={onDelete}>
                Delete for good
              </Button>
            </>
          ) : (
            <>
              <Button variant="outline" size="lg" onClick={() => setConfirmDelete(true)}>
                Delete
              </Button>
              <Button variant="primary" size="lg" onClick={() => setEditing(true)}>
                Edit
              </Button>
            </>
          )}
        </div>
      }
    >
      {editing ? (
        <div className="entry__form">
          <label className="entry__field">
            <span className="t-capture-12-m">What it was</span>
            <input className="field" value={draft.title} onChange={(e) => setDraft({ ...draft, title: e.target.value })} />
          </label>
          <label className="entry__field">
            <span className="t-capture-12-m">Amount (đ)</span>
            <input
              className="field tnum"
              inputMode="numeric"
              value={draft.amount ? draft.amount.toLocaleString("en-US") : ""}
              onChange={(e) => setDraft({ ...draft, amount: Number(e.target.value.replace(/[^\d]/g, "")) || 0 })}
            />
          </label>
          <div className="entry__field">
            <span className="t-capture-12-m">Type</span>
            <div className="segmented" role="group" aria-label="Money out or in">
              {(["out", "in"] as const).map((f) => (
                <button
                  key={f}
                  type="button"
                  className={draft.flow === f ? "is-active" : ""}
                  aria-pressed={draft.flow === f}
                  onClick={() =>
                    setDraft({
                      ...draft,
                      flow: f,
                      category: f === "in" ? "Received" : draft.category === "Received" ? "Other" : draft.category,
                    })
                  }
                >
                  {f === "out" ? "Expense" : "Receive"}
                </button>
              ))}
            </div>
          </div>
          <label className="entry__field">
            <span className="t-capture-12-m">Category</span>
            <select
              className="field"
              value={draft.category}
              onChange={(e) => setDraft({ ...draft, category: e.target.value as CategoryName })}
            >
              {CATEGORIES.map((c) => (
                <option key={c}>{c}</option>
              ))}
            </select>
          </label>
          <label className="entry__field">
            <span className="t-capture-12-m">Day</span>
            <input
              className="field"
              type="date"
              value={draft.date}
              max={today()}
              onChange={(e) => e.target.value && setDraft({ ...draft, date: e.target.value })}
            />
          </label>
        </div>
      ) : (
        <div className="entry">
          <span className={`entry__tag is-${categoryTone(entry.category)}`}>{entry.category}</span>
          <Amount value={money(entry.amount)} size={28} sign={entry.flow === "out" ? "-" : "+"} />
          <p className="t-body-14-m entry__title">{entry.title}</p>
          <dl className="entry__facts">
            <div>
              <dt>Day</dt>
              <dd>{longDate(entry.date)}</dd>
            </div>
            <div>
              <dt>Category</dt>
              <dd>{entry.category}</dd>
            </div>
            <div>
              <dt>Saved</dt>
              <dd>
                {shortDate(toISODate(new Date(entry.createdAt)))} · {clock(entry.createdAt)}
              </dd>
            </div>
            <div>
              <dt>From your note</dt>
              <dd className="entry__source">“{entry.source}”</dd>
            </div>
          </dl>
        </div>
      )}
    </ModalSheet>
  )
}

/** "Summary" on the green card: where the day's money went, biggest first. */
export function SummarySheet({ day, entries, onClose }: { day: string; entries: Entry[]; onClose: () => void }) {
  const list = entries.filter((e) => e.date === day)
  const out = list.filter((e) => e.flow === "out")
  const total = out.reduce((s, e) => s + e.amount, 0)
  const byCat = new Map<CategoryName, { sum: number; n: number }>()
  for (const e of out) {
    const v = byCat.get(e.category) ?? { sum: 0, n: 0 }
    byCat.set(e.category, { sum: v.sum + e.amount, n: v.n + 1 })
  }
  const rows = [...byCat].sort((a, b) => b[1].sum - a[1].sum)
  const received = list.filter((e) => e.flow === "in").reduce((s, e) => s + e.amount, 0)

  return (
    <ModalSheet
      label="Summary"
      onClose={onClose}
      size="auto"
      header={
        <ModalHeader
          title={`Summary · ${shortDate(day)}`}
          right={<IconButton icon="close" label="Close" variant="glass-strong" onClick={onClose} />}
        />
      }
    >
      <div className="summary">
        <div className="summary__totals">
          <div>
            <span className="t-capture-12-m">Out</span>
            <Amount value={money(total)} size={18} />
          </div>
          <div>
            <span className="t-capture-12-m">In</span>
            <Amount value={money(received)} size={18} />
          </div>
        </div>
        {rows.length ? (
          <ul className="summary__rows">
            {rows.map(([cat, v]) => (
              <li key={cat}>
                <div className="summary__row-head">
                  <span className={`t-body-14-m summary__cat is-${categoryTone(cat)}`}>{cat}</span>
                  <span className="t-capture-12-r summary__count">
                    {v.n} {v.n === 1 ? "item" : "items"}
                  </span>
                  <Amount value={money(v.sum)} />
                </div>
                <span className="summary__track">
                  <span
                    className={`summary__bar is-${categoryTone(cat)}`}
                    style={{ width: `${Math.max(4, (v.sum / total) * 100)}%` }}
                  />
                </span>
              </li>
            ))}
          </ul>
        ) : (
          <p className="t-body-14-r summary__none">No spending on this day.</p>
        )}
      </div>
    </ModalSheet>
  )
}
