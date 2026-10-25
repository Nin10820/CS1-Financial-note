import { useState } from "react"
import { IconButton } from "../components/ui"
import { Icon } from "../components/Icon"
import { money, today } from "../lib/format"
import { guessIcon, installmentPayment, type Bill, type BillKind } from "../lib/bills"
import { uid } from "../lib/store"
import ModalSheet, { ModalHeader } from "./ModalSheet"

const KINDS: { kind: BillKind; label: string; hint: string }[] = [
  { kind: "recurring", label: "Recurring bill", hint: "Electricity, water, internet — every month" },
  { kind: "installment", label: "Installment", hint: "Fixed parts until it's paid off" },
  { kind: "oneoff", label: "One-off", hint: "Just this once, no repeat" },
]

const num = (v: string) => Number(v.replace(/[^\d.]/g, "")) || 0

/** Figma Final › Due › "Ghi khoản mới": pick the kind, then fill a few lines like a sentence. */
export default function AddBill({ month, onClose, onSave }: { month: string; onClose: () => void; onSave: (b: Bill) => void }) {
  const [kind, setKind] = useState<BillKind | null>(null)
  const defaultDue = month === today().slice(0, 7) ? today() : `${month}-15`
  const [f, setF] = useState({
    name: "",
    code: "",
    varies: false,
    amount: "",
    due: defaultDue,
    payWith: "",
    principal: "",
    lender: "",
    payments: "12",
    rate: "0",
    fee: "0",
  })
  const set = (k: keyof typeof f) => (v: string | boolean) => setF((s) => ({ ...s, [k]: v }))

  const each =
    kind === "installment" ? installmentPayment(num(f.principal), Math.max(1, Math.round(num(f.payments))), num(f.rate)) : num(f.amount)
  const valid =
    !!kind &&
    f.name.trim().length > 0 &&
    each > 0 &&
    !!f.due &&
    (kind !== "installment" || Math.round(num(f.payments)) >= 1)

  const save = () => {
    if (!valid || !kind) return
    onSave({
      id: uid(),
      kind,
      name: f.name.trim(),
      icon: guessIcon(f.name, kind),
      amount: each,
      varies: kind === "recurring" && f.varies,
      start: f.due,
      code: f.code.trim() || undefined,
      payWith: f.payWith.trim() || undefined,
      lender: kind === "installment" ? f.lender.trim() || undefined : undefined,
      principal: kind === "installment" ? num(f.principal) : undefined,
      payments: kind === "installment" ? Math.round(num(f.payments)) : undefined,
      rate: kind === "installment" ? num(f.rate) : undefined,
      fee: kind === "installment" ? num(f.fee) : undefined,
      paid: {},
      createdAt: Date.now(),
    })
  }

  const label = KINDS.find((k) => k.kind === kind)?.label

  return (
    <ModalSheet
      label="New bill"
      onClose={onClose}
      header={
        <ModalHeader
          title="New bill"
          left={kind ? <IconButton icon="arrow-left" label="Change kind" variant="glass-strong" onClick={() => setKind(null)} /> : undefined}
          right={
            kind ? (
              <button type="button" className="note-save" aria-label="Save bill" disabled={!valid} onClick={save}>
                <Icon name="check-circle" size={20} />
              </button>
            ) : (
              <IconButton icon="close" label="Close" variant="glass-strong" onClick={onClose} />
            )
          }
        />
      }
    >
      <div className="add-bill">
        <h3 className="add-bill__lead">
          Adding new <span className={kind ? "is-kind" : "is-placeholder"}>{label?.toLocaleLowerCase() ?? "kind of"}</span>
          <br />— tell us what you know:
        </h3>

        {!kind ? (
          <div className="add-bill__kinds">
            <p className="t-capture-12-r add-bill__step">Step 1 of 2</p>
            <p className="t-body-14-s add-bill__ask">What kind is this?</p>
            {KINDS.map((k) => (
              <button key={k.kind} type="button" className="add-bill__kind" onClick={() => setKind(k.kind)}>
                <span>
                  <span className="t-body-14-m">{k.label}</span>
                  <span className="t-capture-12-r add-bill__kind-hint">{k.hint}</span>
                </span>
                <Icon name="caret-right-sm" size={14} />
              </button>
            ))}
          </div>
        ) : (
          <div className="add-bill__form">
            <Line label="What's it for?" value={f.name} onChange={set("name")} placeholder={kind === "installment" ? "iPhone 15 Pro" : "Water"} autoFocus />
            {kind === "recurring" && <Line label="Bill code" value={f.code} onChange={set("code")} placeholder="(optional)" />}
            {kind === "recurring" && (
              <div className="add-bill__line">
                <span className="add-bill__label">Amount each time:</span>
                <span className="add-bill__choices" role="group" aria-label="Amount each time">
                  {[
                    [false, "Fixed"],
                    [true, "Changes"],
                  ].map(([v, t]) => (
                    <button key={String(t)} type="button" className={f.varies === v ? "is-on" : ""} aria-pressed={f.varies === v} onClick={() => set("varies")(v as boolean)}>
                      {t as string}
                    </button>
                  ))}
                </span>
              </div>
            )}
            {kind === "installment" ? (
              <>
                <Line label="Amount borrowed" value={f.principal} onChange={set("principal")} placeholder="12,120,000" money />
                <Line label="Lender / bank" value={f.lender} onChange={set("lender")} placeholder="(optional)" />
                <Line label="Starting from" value={f.due} onChange={set("due")} type="date" />
                <Line label="Number of payments" value={f.payments} onChange={set("payments")} placeholder="12" suffix="payments" numeric />
                <Line label="Monthly interest rate" value={f.rate} onChange={set("rate")} placeholder="0" suffix="%" numeric />
                <Line label="Conversion fee" value={f.fee} onChange={set("fee")} placeholder="0" suffix="%" numeric />
                {each > 0 && (
                  <p className="add-bill__preview">
                    ≈ <b>{money(each)} đ</b> each month for {Math.round(num(f.payments))} months
                  </p>
                )}
              </>
            ) : (
              <>
                <Line
                  label={kind === "recurring" && f.varies ? "Roughly how much?" : "Amount"}
                  value={f.amount}
                  onChange={set("amount")}
                  placeholder="340,000"
                  money
                />
                <Line label="Due" value={f.due} onChange={set("due")} type="date" />
                {kind === "recurring" && <p className="t-capture-12-r add-bill__note">Repeats monthly on day {Number(f.due.slice(8, 10)) || 15}.</p>}
                <Line label="Pay with" value={f.payWith} onChange={set("payWith")} placeholder="(optional)" />
              </>
            )}
          </div>
        )}
      </div>
    </ModalSheet>
  )
}

/** One "label: value" line — the sentence-like form from the Figma flow. */
function Line({
  label,
  value,
  onChange,
  placeholder,
  type = "text",
  money: isMoney,
  numeric,
  suffix,
  autoFocus,
}: {
  label: string
  value: string
  onChange: (v: string) => void
  placeholder?: string
  type?: "text" | "date"
  money?: boolean
  numeric?: boolean
  suffix?: string
  autoFocus?: boolean
}) {
  const shown = isMoney && value ? Number(value.replace(/[^\d]/g, "") || 0).toLocaleString("en-US") : value
  return (
    <label className="add-bill__line">
      <span className="add-bill__label">{label}:</span>
      <input
        className="add-bill__input"
        type={type}
        value={shown}
        placeholder={placeholder}
        inputMode={isMoney || numeric ? "decimal" : undefined}
        autoFocus={autoFocus}
        onChange={(e) => onChange(isMoney ? e.target.value.replace(/[^\d]/g, "") : e.target.value)}
      />
      {isMoney && value ? <span className="add-bill__suffix">đ</span> : suffix && value ? <span className="add-bill__suffix">{suffix}</span> : null}
    </label>
  )
}
