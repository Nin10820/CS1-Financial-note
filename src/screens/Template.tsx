import { useState } from "react"
import { IconButton } from "../components/ui"
import { Icon } from "../components/Icon"
import { longDate, money, today } from "../lib/format"
import { CATEGORIES, uid, type CategoryName, type Entry } from "../lib/store"
import { DEFAULT_TAGS, suggestTag, tagInfo } from "../lib/tags"
import { guessIcon, ym, type Bill } from "../lib/bills"
import ModalSheet, { ModalHeader } from "./ModalSheet"
import type { ScanPrefill } from "./Scan"
import "./template.css"

type Kind = "expense" | "receive" | "bill" | "monthly"
const KINDS: { kind: Kind; label: string }[] = [
  { kind: "expense", label: "Expense" },
  { kind: "receive", label: "Receive" },
  { kind: "bill", label: "Bill" },
  { kind: "monthly", label: "Monthly bill" },
]

/**
 * Template / edit — iOS EntrySheet: the amount with its own keypad, the name and category, the
 * details (date, kind, currency, from), tags and a comment. "Monthly bill" also adds a bill to Due,
 * already paid for this month.
 */
export default function Template({
  entry,
  prefill,
  day,
  sources,
  customTags,
  onCustomTags,
  onClose,
  onSave,
  onMonthly,
  onDelete,
}: {
  /** Set when editing a line. */
  entry?: Entry
  prefill?: ScanPrefill
  day: string
  /** Asset names the money can come from. */
  sources: string[]
  customTags: string[]
  onCustomTags: (tags: string[]) => void
  onClose: () => void
  onSave: (e: Entry) => void
  onMonthly: (bill: Bill, entryDate: string, amount: number) => void
  onDelete?: () => void
}) {
  const [amount, setAmount] = useState(entry?.amount ?? prefill?.amount ?? 0)
  const [title, setTitle] = useState(entry?.title ?? prefill?.title ?? "")
  const [category, setCategory] = useState<CategoryName>(entry?.category ?? "Food")
  const [date, setDate] = useState(entry?.date ?? day)
  const [kind, setKind] = useState<Kind>(entry ? (entry.flow === "in" ? "receive" : entry.category === "Bills" ? "bill" : "expense") : "expense")
  const [from, setFrom] = useState(entry?.paidFrom ?? "")
  const [tags, setTags] = useState<string[]>(entry?.tags ?? [])
  const [comment, setComment] = useState(entry?.comment ?? prefill?.comment ?? "")
  const [pad, setPad] = useState(!entry)
  const [picking, setPicking] = useState(false)
  const [catMenu, setCatMenu] = useState(false)
  const [deleting, setDeleting] = useState(false)

  const suggestion = suggestTag(title, category)
  const valid = amount > 0 && title.trim().length > 0

  const press = (k: string) => {
    if (k === "⌫") return setAmount((a) => Math.floor(a / 10))
    setAmount((a) => {
      const next = Number(`${a || ""}${k}`)
      return next < 1e12 ? next : a
    })
  }

  const save = () => {
    if (!valid) return
    const flow = kind === "receive" ? "in" : "out"
    const cat: CategoryName = kind === "receive" ? "Received" : kind === "bill" || kind === "monthly" ? "Bills" : category === "Received" ? "Other" : category
    if (kind === "monthly" && !entry) {
      const bill: Bill = {
        id: uid(),
        kind: "recurring",
        name: title.trim(),
        icon: guessIcon(title, "recurring"),
        amount,
        varies: false,
        start: date,
        payWith: from || undefined,
        paid: {},
        createdAt: Date.now(),
      }
      onMonthly(bill, date, amount)
      onClose()
      return
    }
    const noteId = entry?.noteId ?? uid()
    onSave({
      ...(entry ?? { id: uid(), noteId, source: title.trim(), createdAt: Date.now() }),
      date,
      title: title.trim(),
      amount,
      flow,
      category: cat,
      tags: tags.length ? tags : undefined,
      comment: comment.trim() || undefined,
      paidFrom: from || undefined,
    } as Entry)
    onClose()
  }

  return (
    <ModalSheet
      label={entry ? "Edit line" : "Template"}
      onClose={onClose}
      header={
        <ModalHeader
          title={entry ? "Edit" : "Template"}
          left={<IconButton icon="close" label="Close" variant="glass-strong" onClick={onClose} />}
          right={
            <button type="button" className="tpl__save" aria-label="Save" disabled={!valid} onClick={save}>
              <Icon name="check" size={22} />
            </button>
          }
        />
      }
      footer={
        pad ? (
          <div className="tpl__pad" role="group" aria-label="Amount keypad">
            {["1", "2", "3", "4", "5", "6", "7", "8", "9", "000", "0", "⌫"].map((k) => (
              <button key={k} type="button" className="tpl__key" aria-label={k === "⌫" ? "Delete digit" : k} onClick={() => press(k)}>
                {k}
              </button>
            ))}
            <button type="button" className="tpl__done" onClick={() => setPad(false)}>
              Done
            </button>
          </div>
        ) : null
      }
    >
      <div className="tpl">
        <button type="button" className={`tpl__amount${pad ? " is-on" : ""}`} onClick={() => setPad(true)} aria-label={`Amount ${money(amount)} dong. Change`}>
          <span className="tnum">{money(amount)}</span>
          <small>đ</small>
        </button>

        <div className="tpl__card">
          <input
            className="tpl__name"
            value={title}
            placeholder="What was it?"
            aria-label="Name"
            onFocus={() => setPad(false)}
            onChange={(e) => setTitle(e.target.value)}
          />
          {kind !== "receive" && kind !== "bill" && kind !== "monthly" && (
            <div className="tpl__cat">
              <button type="button" className="tpl__cat-btn" aria-haspopup="menu" aria-expanded={catMenu} onClick={() => setCatMenu((m) => !m)}>
                {category}
                <Icon name="caret-up-down" size={14} />
              </button>
              {catMenu && (
                <div className="tpl__menu" role="menu">
                  {CATEGORIES.filter((c) => c !== "Received").map((c) => (
                    <button
                      key={c}
                      type="button"
                      role="menuitemradio"
                      aria-checked={c === category}
                      onClick={() => {
                        setCategory(c)
                        setCatMenu(false)
                      }}
                    >
                      {c}
                      {c === category && <Icon name="check" size={16} />}
                    </button>
                  ))}
                </div>
              )}
            </div>
          )}
        </div>

        <div className="tpl__card tpl__rows">
          <label className="tpl__row">
            <span>Date</span>
            <span className="tpl__value">{date === today() ? "Today" : longDate(date)}</span>
            <input type="date" value={date} max={today()} onChange={(e) => e.target.value && setDate(e.target.value)} />
          </label>
          <label className="tpl__row">
            <span>Kind of</span>
            <span className="tpl__value">
              {KINDS.find((k) => k.kind === kind)!.label}
              <Icon name="caret-up-down" size={14} />
            </span>
            <select value={kind} onChange={(e) => setKind(e.target.value as Kind)} aria-label="Kind of">
              {KINDS.filter((k) => !entry || k.kind !== "monthly").map((k) => (
                <option key={k.kind} value={k.kind}>
                  {k.label}
                </option>
              ))}
            </select>
          </label>
          <div className="tpl__row">
            <span>Currency</span>
            <span className="tpl__value">VND</span>
          </div>
          <label className="tpl__row">
            <span>{kind === "receive" ? "To" : "From"}</span>
            <span className="tpl__value">
              {from || "Not set"}
              <Icon name="caret-up-down" size={14} />
            </span>
            <select value={from} onChange={(e) => setFrom(e.target.value)} aria-label={kind === "receive" ? "To" : "From"}>
              <option value="">Not set</option>
              {["Cash", "Card", "Transfer", ...sources].map((s) => (
                <option key={s} value={s}>
                  {s}
                </option>
              ))}
            </select>
          </label>
        </div>
        {kind === "monthly" && <p className="tpl__hint">Adds “{title.trim() || "this"}” to Due every month on day {Number(date.slice(8))}, paid for {ym(date)}.</p>}

        <div className="tpl__section">
          <div className="tpl__section-head">
            <span>Category tags</span>
            <button type="button" className="tpl__link" onClick={() => setPicking(true)}>
              Edit
            </button>
          </div>
          <div className="tpl__tags">
            {tags.map((t) => (
              <TagChip key={t} name={t} on onClick={() => setTags(tags.filter((x) => x !== t))} />
            ))}
            {suggestion && !tags.includes(suggestion) && (
              <button type="button" className="tpl__suggest" onClick={() => setTags([...tags, suggestion])}>
                <Icon name="plus" size={14} />
                Suggest tag: {suggestion}
              </button>
            )}
            {!tags.length && !suggestion && (
              <button type="button" className="tpl__suggest" onClick={() => setPicking(true)}>
                <Icon name="plus" size={14} />
                Add a tag
              </button>
            )}
          </div>
        </div>

        <div className="tpl__section">
          <div className="tpl__section-head">
            <span>Comment</span>
          </div>
          <textarea className="tpl__comment" rows={3} value={comment} placeholder="Anything to remember about it" onFocus={() => setPad(false)} onChange={(e) => setComment(e.target.value)} />
        </div>

        {entry && onDelete && (
          <button type="button" className="tpl__delete" onClick={() => setDeleting(true)}>
            <Icon name="trash" size={18} />
            Delete this line
          </button>
        )}
      </div>

      {picking && <TagPicker picked={tags} custom={customTags} onCustom={onCustomTags} onPick={setTags} onClose={() => setPicking(false)} />}

      {deleting && (
        <div className="confirm" role="alertdialog" aria-label={`Delete “${title}”?`}>
          <div className="confirm__scrim" onClick={() => setDeleting(false)} />
          <div className="confirm__box">
            <p className="confirm__title">Delete “{title}”?</p>
            <button type="button" className="confirm__btn is-danger" onClick={onDelete}>
              Yes, delete
            </button>
            <button type="button" className="confirm__btn" onClick={() => setDeleting(false)}>
              Keep it
            </button>
          </div>
        </div>
      )}
    </ModalSheet>
  )
}

function TagChip({ name, on, onClick }: { name: string; on?: boolean; onClick: () => void }) {
  const info = tagInfo(name)
  return (
    <button
      type="button"
      className={`tag-chip${on ? " is-on" : ""}`}
      aria-pressed={on}
      style={on ? { background: info?.fill ?? "var(--brand-100)", color: info?.whiteText ? "#fff" : undefined } : undefined}
      onClick={onClick}
    >
      <span aria-hidden="true">{info?.mark ?? "#"}</span>
      {name}
    </button>
  )
}

/** Select tag — Default and Custom lists, plus "New tag". */
function TagPicker({
  picked,
  custom,
  onCustom,
  onPick,
  onClose,
}: {
  picked: string[]
  custom: string[]
  onCustom: (t: string[]) => void
  onPick: (t: string[]) => void
  onClose: () => void
}) {
  const [adding, setAdding] = useState("")
  const toggle = (t: string) => onPick(picked.includes(t) ? picked.filter((x) => x !== t) : [...picked, t])
  return (
    <ModalSheet
      label="Select tag"
      size="auto"
      onClose={onClose}
      header={<ModalHeader title="Select tag" right={<IconButton icon="close" label="Done" variant="glass-strong" onClick={onClose} />} />}
    >
      <div className="tags-pick">
        <p className="tpl__label">Default</p>
        <div className="tpl__tags">
          {DEFAULT_TAGS.map((t) => (
            <TagChip key={t.name} name={t.name} on={picked.includes(t.name)} onClick={() => toggle(t.name)} />
          ))}
        </div>
        <p className="tpl__label">Custom</p>
        <div className="tpl__tags">
          {custom.map((t) => (
            <TagChip key={t} name={t} on={picked.includes(t)} onClick={() => toggle(t)} />
          ))}
          {!custom.length && <span className="tpl__hint">Tags you make show up here.</span>}
        </div>
        <form
          className="tags-pick__new"
          onSubmit={(e) => {
            e.preventDefault()
            const t = adding.trim()
            if (!t) return
            if (!custom.includes(t) && !tagInfo(t)) onCustom([...custom, t])
            if (!picked.includes(t)) onPick([...picked, t])
            setAdding("")
          }}
        >
          <input value={adding} placeholder="New tag" aria-label="New tag" onChange={(e) => setAdding(e.target.value)} />
          <button type="submit" disabled={!adding.trim()}>
            Add
          </button>
        </form>
      </div>
    </ModalSheet>
  )
}
