import { useEffect, useMemo, useRef, useState, type KeyboardEvent } from "react"
import { Button, ChatBubble, IconButton, LogoMark, TransItem } from "../components/ui"
import { Icon } from "../components/Icon"
import { greeting, longDate, money, shortDate, today } from "../lib/format"
import { parseNote, type Draft } from "../lib/parse"
import { CATEGORIES, categoryTone, uid, type CategoryName, type Entry } from "../lib/store"
import ModalSheet, { ModalHeader } from "./ModalSheet"
import DayPicker from "./DayPicker"

export type AssistantOpen = { notice?: string; note?: { date: string; lines: string[] } }

type Turn =
  | {
      id: string
      kind: "note"
      text: string
      drafts: Draft[]
      status: "review" | "saved" | "discarded"
      noteId?: string
      /** Set when the note came from the Note editor: shown as an attached card. */
      attached?: { date: string; count: number }
    }
  | { id: string; kind: "notice"; text: string }

const DEFAULT_CHIPS = ["thịt xay 50k", "đậu hũ 15k"]

/** Figma Final › Chat with AI (765:19553–765:24439) and High Fi "Assistant" confirm card (584:5640). */
export default function Assistant({
  name,
  defaultDay,
  entries,
  opts,
  onClose,
  onSave,
  onUndo,
  onOpenDay,
}: {
  name: string
  defaultDay: string
  entries: Entry[]
  opts?: AssistantOpen
  onClose: () => void
  onSave: (list: Entry[]) => void
  onUndo: (noteId: string) => void
  onOpenDay: (day: string) => void
}) {
  const [day, setDay] = useState(defaultDay)
  const [text, setText] = useState("")
  const [turns, setTurns] = useState<Turn[]>(() => {
    if (opts?.note) {
      const text = opts.note.lines.join("\n")
      return [
        {
          id: uid(),
          kind: "note",
          text,
          drafts: parseNote(text, opts.note.date),
          status: "review",
          attached: { date: opts.note.date, count: opts.note.lines.length },
        },
      ]
    }
    return opts?.notice ? [{ id: uid(), kind: "notice", text: opts.notice }] : []
  })
  const [editing, setEditing] = useState<string | null>(null)
  const [history, setHistory] = useState(false)
  const input = useRef<HTMLTextAreaElement>(null)
  const [picking, setPicking] = useState(false)
  const log = useRef<HTMLDivElement>(null)

  useEffect(() => {
    input.current?.focus({ preventScroll: true })
  }, [])
  useEffect(() => {
    log.current?.scrollTo({ top: log.current.scrollHeight, behavior: "smooth" })
  }, [turns])

  // Quick chips: the user's own recent lines first, so the common ones are one tap away.
  const chips = useMemo(() => {
    const seen = new Set<string>()
    const recent: string[] = []
    for (const e of [...entries].sort((a, b) => b.createdAt - a.createdAt)) {
      if (e.flow !== "out") continue
      const chip = `${e.title.toLocaleLowerCase("vi")} ${Math.round(e.amount / 1000)}k`
      if (!seen.has(chip)) {
        seen.add(chip)
        recent.push(chip)
      }
      if (recent.length === 2) break
    }
    return recent.length ? recent : DEFAULT_CHIPS
  }, [entries])

  const send = () => {
    const note = text.trim()
    if (!note) return
    setText("")
    setEditing(null)
    setTurns((t) => [
      // An unfinished review is dropped when a new note is sent; nothing from it was saved.
      ...t.map((x) => (x.kind === "note" && x.status === "review" ? { ...x, status: "discarded" as const } : x)),
      { id: uid(), kind: "note", text: note, drafts: parseNote(note, day), status: "review" },
    ])
  }

  const onKeyDown = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    // Vietnamese IMEs (Telex/VNI) hold Enter while composing — never send mid-word.
    if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing) {
      e.preventDefault()
      send()
    }
  }

  const patchDraft = (turnId: string, key: string, patch: Partial<Draft>) =>
    setTurns((t) =>
      t.map((x) =>
        x.id === turnId && x.kind === "note"
          ? { ...x, drafts: x.drafts.map((d) => (d.key === key ? { ...d, ...patch, assumedThousands: undefined } : d)) }
          : x,
      ),
    )
  const removeDraft = (turnId: string, key: string) =>
    setTurns((t) =>
      t.map((x) => (x.id === turnId && x.kind === "note" ? { ...x, drafts: x.drafts.filter((d) => d.key !== key) } : x)),
    )
  const setStatus = (turnId: string, status: "saved" | "discarded", noteId?: string) =>
    setTurns((t) => t.map((x) => (x.id === turnId && x.kind === "note" ? { ...x, status, noteId } : x)))

  const confirm = (turn: Extract<Turn, { kind: "note" }>) => {
    const noteId = uid()
    const now = Date.now()
    onSave(
      turn.drafts.map((d, i) => ({
        id: uid(),
        date: d.date,
        title: d.title,
        amount: d.amount ?? 0,
        flow: d.flow,
        category: d.category,
        noteId,
        source: turn.text,
        createdAt: now + i,
      })),
    )
    setEditing(null)
    setStatus(turn.id, "saved", noteId)
  }


  const notes = useMemo(() => {
    const map = new Map<string, Entry[]>()
    for (const e of entries) map.set(e.noteId, [...(map.get(e.noteId) ?? []), e])
    return [...map.values()].sort((a, b) => b[0].createdAt - a[0].createdAt)
  }, [entries])

  const empty = turns.length === 0

  return (
    <ModalSheet
      label="Assistant"
      onClose={onClose}
      header={
        <ModalHeader
          title={history ? "History" : "Assistant"}
          left={
            <IconButton
              icon="history"
              label={history ? "Back to chat" : "Note history"}
              variant="glass-strong"
              aria-pressed={history}
              onClick={() => setHistory(!history)}
            />
          }
          right={<IconButton icon="close" label="Close" variant="glass-strong" onClick={onClose} />}
        />
      }
      footer={
        history ? null : (
          <form
            className="composer"
            onSubmit={(e) => {
              e.preventDefault()
              send()
            }}
          >
            <div className="composer__date">
              <button type="button" className="composer__day" onClick={() => setPicking(true)} aria-label={`Note for ${longDate(day)}. Change day`}>
                <span>{longDate(day)}</span>
                <Icon name="caret-down" size={16} />
              </button>
              {picking && (
                <DayPicker
                  value={day}
                  marked={new Set(entries.map((e) => e.date))}
                  onPick={setDay}
                  onClose={() => {
                    setPicking(false)
                    input.current?.focus({ preventScroll: true })
                  }}
                />
              )}
            </div>
            <textarea
              ref={input}
              className="composer__input"
              rows={2}
              value={text}
              placeholder="e.g. coffee 24k, breakfast 35k…"
              aria-label="Write what you spent"
              onChange={(e) => setText(e.target.value)}
              onKeyDown={onKeyDown}
            />
            <div className="composer__actions">
              <div className="composer__chips">
                <IconButton icon="plus" label="Attach (coming soon)" variant="soft" iconSize={20} disabled />
                {chips.map((c) => (
                  <button
                    key={c}
                    type="button"
                    className="composer__chip"
                    onClick={() => {
                      setText((t) => (t.trim() ? `${t.trim().replace(/,$/, "")}, ${c}` : c))
                      input.current?.focus()
                    }}
                  >
                    {c}
                  </button>
                ))}
              </div>
              {text.trim() ? (
                <IconButton icon="send-up" label="Send" variant="dark" iconSize={20} type="submit" />
              ) : (
                <IconButton icon="waveform" label="Voice note (coming soon)" variant="dark" iconSize={20} disabled />
              )}
            </div>
          </form>
        )
      }
    >
      {history ? (
        <div className="history">
          {notes.length === 0 && <p className="t-body-14-r history__none">Notes you save will show up here.</p>}
          {notes.map((list) => {
            const first = list[0]
            return (
              <button
                key={first.noteId}
                type="button"
                className="history__item"
                onClick={() => {
                  onOpenDay(first.date)
                  onClose()
                }}
              >
                <span className="t-body-14-m history__text">{first.source}</span>
                <span className="t-capture-12-r history__meta">
                  {shortDate(first.date)} · {list.length} {list.length === 1 ? "item" : "items"}
                </span>
              </button>
            )
          })}
        </div>
      ) : (
        <div ref={log} className={`chat${empty ? " chat--empty" : ""}`}>
          {empty && (
            <div className="chat__hello">
              <LogoMark size={64} />
              <div>
                <h3 className="chat__hello-title">
                  {greeting()}, {name}
                </h3>
                <p className="t-body-14-m chat__hello-sub">What did you spend today?</p>
              </div>
            </div>
          )}
          {turns.map((turn) =>
            turn.kind === "notice" ? (
              <p key={turn.id} className="t-body-14-r chat__bot">
                {turn.text}
              </p>
            ) : (
              <div key={turn.id} className="chat__turn">
                {turn.attached ? (
                  <div className="attached">
                    <div className="attached__card">
                      <span className="attached__title">Note · {longDate(turn.attached.date)}</span>
                      <span className="attached__lines" aria-hidden="true">
                        <i />
                        <i />
                        <i />
                      </span>
                      <span className="attached__tag">{turn.attached.count} {turn.attached.count === 1 ? "line" : "lines"}</span>
                    </div>
                    <span className="attached__caption">{turn.attached.date === today() ? "My note today" : `My note for ${shortDate(turn.attached.date)}`}</span>
                  </div>
                ) : (
                  <ChatBubble>{turn.text}</ChatBubble>
                )}
                <Reply
                  turn={turn}
                  editing={editing}
                  onEdit={setEditing}
                  onPatch={(key, patch) => patchDraft(turn.id, key, patch)}
                  onRemove={(key) => removeDraft(turn.id, key)}
                  onDiscard={() => {
                    setEditing(null)
                    setStatus(turn.id, "discarded")
                  }}
                  onConfirm={() => confirm(turn)}
                  onUndo={() => {
                    if (turn.noteId) onUndo(turn.noteId)
                    setStatus(turn.id, "discarded")
                  }}
                  onView={() => {
                    onOpenDay(turn.drafts[0]?.date ?? day)
                    onClose()
                  }}
                />
              </div>
            ),
          )}
        </div>
      )}
    </ModalSheet>
  )
}

function Reply({
  turn,
  editing,
  onEdit,
  onPatch,
  onRemove,
  onDiscard,
  onConfirm,
  onUndo,
  onView,
}: {
  turn: Extract<Turn, { kind: "note" }>
  editing: string | null
  onEdit: (key: string | null) => void
  onPatch: (key: string, patch: Partial<Draft>) => void
  onRemove: (key: string) => void
  onDiscard: () => void
  onConfirm: () => void
  onUndo: () => void
  onView: () => void
}) {
  const { drafts, status } = turn
  const missing = drafts.filter((d) => !d.amount).length
  const total = drafts.filter((d) => d.flow === "out").reduce((s, d) => s + (d.amount ?? 0), 0)

  if (status === "discarded")
    return <p className="t-body-14-r chat__bot chat__bot--quiet">Nothing from this note was saved.</p>

  if (status === "saved")
    return (
      <div className="chat__reply">
        <p className="t-body-14-r chat__bot">
          Saved {drafts.length} {drafts.length === 1 ? "item" : "items"} to {shortDate(drafts[0].date)}
          {total ? (
            <>
              {" "}
              · spent <b>{money(total)}đ</b>
            </>
          ) : null}
          .
        </p>
        <div className="chat__actions">
          <Button variant="outline" size="sm" onClick={onUndo}>
            Undo
          </Button>
          <Button variant="confirm" size="sm" onClick={onView}>
            View list
          </Button>
        </div>
      </div>
    )

  if (!drafts.length)
    return (
      <div className="chat__reply">
        <p className="t-body-14-r chat__bot">I couldn't find anything to save. Try a line with an amount, like “coffee 24k”.</p>
      </div>
    )

  return (
    <div className="chat__reply">
      <div className="chat__bot">
        <p className="t-body-14-r">Here's what I got — nothing is saved until you confirm:</p>
        <ul className="chat__summary">
          {drafts.map((d) => (
            <li key={d.key} className="t-body-14-r">
              {d.title}: <b>{d.amount ? `${money(d.amount)}đ` : "no amount"}</b>
            </li>
          ))}
        </ul>
      </div>
      <div className="confirm-card">
        {drafts.map((d) =>
          editing === d.key ? (
            <DraftEditor key={d.key} draft={d} onPatch={(p) => onPatch(d.key, p)} onDone={() => onEdit(null)} onRemove={() => onRemove(d.key)} />
          ) : d.amount ? (
            <TransItem
              key={d.key}
              title={d.title}
              category={d.assumedThousands ? `${d.category} · read as ${money(d.amount)}` : d.category}
              categoryTone={categoryTone(d.category)}
              amount={money(d.amount)}
              flow={d.flow}
              onEdit={() => onEdit(d.key)}
            />
          ) : (
            <div key={d.key} className="fn-trans fn-trans--confirm confirm-card__missing">
              <span className="fn-trans__text">
                <span className="fn-trans__title t-body-14-m">{d.title}</span>
                <span className="t-capture-12-m confirm-card__hint">Couldn't read an amount</span>
              </span>
              <Button variant="outline" size="sm" onClick={() => onEdit(d.key)}>
                Add amount
              </Button>
            </div>
          ),
        )}
      </div>
      <div className="chat__actions">
        {missing > 0 && (
          <span className="t-capture-12-r chat__blocker">
            {missing} {missing === 1 ? "line needs" : "lines need"} an amount
          </span>
        )}
        <Button variant="outline" size="sm" onClick={onDiscard}>
          Discard
        </Button>
        <Button variant="confirm" size="sm" onClick={onConfirm} disabled={missing > 0}>
          Confirm
        </Button>
      </div>
    </div>
  )
}

function DraftEditor({
  draft,
  onPatch,
  onDone,
  onRemove,
}: {
  draft: Draft
  onPatch: (p: Partial<Draft>) => void
  onDone: () => void
  onRemove: () => void
}) {
  const [amount, setAmount] = useState(draft.amount ? String(draft.amount) : "")
  const commitAmount = (v: string) => {
    setAmount(v)
    const n = Number(v.replace(/[^\d]/g, ""))
    onPatch({ amount: n > 0 ? n : null })
  }
  return (
    <div className="draft-editor">
      <div className="draft-editor__line">
        <input
          className="field"
          value={draft.title}
          aria-label="What it was"
          onChange={(e) => onPatch({ title: e.target.value })}
        />
        <span className="draft-editor__amount">
          <input
            className="field tnum"
            inputMode="numeric"
            value={amount ? Number(amount.replace(/[^\d]/g, "")).toLocaleString("en-US") : ""}
            placeholder="0"
            aria-label="Amount in đồng"
            autoFocus={!draft.amount}
            onChange={(e) => commitAmount(e.target.value)}
          />
          <span className="fn-amount__cur">đ</span>
        </span>
      </div>
      <div className="draft-editor__line">
        <div className="segmented" role="group" aria-label="Money out or in">
          {(["out", "in"] as const).map((f) => (
            <button
              key={f}
              type="button"
              className={draft.flow === f ? "is-active" : ""}
              aria-pressed={draft.flow === f}
              onClick={() => onPatch({ flow: f, category: f === "in" ? "Received" : draft.category === "Received" ? "Other" : draft.category })}
            >
              {f === "out" ? "Expense" : "Receive"}
            </button>
          ))}
        </div>
        <select
          className="field"
          value={draft.category}
          aria-label="Category"
          onChange={(e) => onPatch({ category: e.target.value as CategoryName })}
        >
          {CATEGORIES.map((c) => (
            <option key={c}>{c}</option>
          ))}
        </select>
      </div>
      <div className="draft-editor__foot">
        <button type="button" className="link-danger" onClick={onRemove}>
          Remove line
        </button>
        <Button variant="primary" size="sm" onClick={onDone} disabled={!draft.amount || !draft.title.trim()}>
          Done
        </Button>
      </div>
    </div>
  )
}
