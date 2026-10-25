import { useState } from "react"
import { Amount, Button, IconButton } from "../components/ui"
import { Icon } from "../components/Icon"
import { money, today } from "../lib/format"
import { addMonths, dueIn, installmentStep, lastDue, ym, type Bill } from "../lib/bills"
import ModalSheet, { ModalHeader } from "./ModalSheet"
import { BillTile, ddmmyyyy, dueLabel, monthLabel } from "./Due"

/** Figma Final › Due › Bill / Installment detail (765:20172 …): what it is, this month, history, Check. */
export default function BillSheet({
  bill,
  month,
  onClose,
  onCheck,
  onDelete,
}: {
  bill: Bill
  month: string
  onClose: () => void
  onCheck: (paid: boolean, amount?: number) => void
  onDelete: () => void
}) {
  const due = dueIn(bill, month)
  const paid = bill.paid[month]
  const [amount, setAmount] = useState(String(paid?.amount ?? bill.amount))
  const [confirmDelete, setConfirmDelete] = useState(false)
  const step = bill.kind === "installment" ? installmentStep(bill, month) : null
  const history = Object.entries(bill.paid).sort((a, b) => b[0].localeCompare(a[0]))
  // No "overdue" alarms (product rule): a past date just reads as when it was due.
  const status = paid ? "Done" : due ? (due < today() ? `Was due ${dueLabel(due)}` : `Due ${dueLabel(due)}`) : "Not due this month"

  const facts: [string, string][] =
    bill.kind === "installment"
      ? [
          ["Amount borrowed", `${money(bill.principal ?? 0)} đ`],
          ["Pay with", bill.lender || bill.payWith || "—"],
          ["Starting from", ddmmyyyy(bill.start)],
          ["Last payment", ddmmyyyy(lastDue(bill))],
          ["Number of payments", `${bill.payments ?? 1} payments`],
          ["Amount each time", `${money(bill.amount)} đ`],
          ["Monthly interest", `${bill.rate ?? 0}%`],
          ["Conversion fee", `${bill.fee ?? 0}%`],
        ]
      : [
          ...(bill.code ? ([["Bill code", bill.code]] as [string, string][]) : []),
          ["Amount each time", bill.varies ? "Changes" : "Fixed"],
          [bill.varies ? "Roughly how much" : "Amount", `${bill.varies ? "~" : ""}${money(bill.amount)} đ`],
          ["Repeats", bill.kind === "recurring" ? "Monthly" : "Just once"],
          ["Due", ddmmyyyy(due ?? bill.start)],
          ["Pay with", bill.payWith || "—"],
        ]

  return (
    <ModalSheet
      label={bill.name}
      onClose={onClose}
      header={
        <ModalHeader
          title={bill.kind === "installment" ? "Installment" : "Bill"}
          right={<IconButton icon="close" label="Close" variant="glass-strong" onClick={onClose} />}
        />
      }
      footer={
        <div className="bill-sheet__foot">
          {confirmDelete ? (
            <>
              <Button variant="outline" size="lg" onClick={() => setConfirmDelete(false)}>
                Keep it
              </Button>
              <Button variant="primary" size="lg" className="is-danger" onClick={onDelete}>
                Delete bill
              </Button>
            </>
          ) : (
            <>
              <IconButton icon="trash" label="Delete bill" variant="white" size={48} iconSize={24} style={{ color: "var(--text-error)" }} onClick={() => setConfirmDelete(true)} />
              {due ? (
                paid ? (
                  <Button variant="outline" size="lg" className="bill-sheet__main" onClick={() => onCheck(false)}>
                    Undo check
                  </Button>
                ) : (
                  <Button
                    variant="confirm"
                    size="lg"
                    className="bill-sheet__main"
                    disabled={!(Number(amount.replace(/[^\d]/g, "")) > 0)}
                    onClick={() => onCheck(true, Number(amount.replace(/[^\d]/g, "")))}
                  >
                    Check
                  </Button>
                )
              ) : (
                <span className="t-body-14-r bill-sheet__nodue">Nothing to pay in {monthLabel(month).split(",")[0]}</span>
              )}
            </>
          )}
        </div>
      }
    >
      <div className="bill-sheet">
        <div className="bill-sheet__head">
          <BillTile bill={bill} size={40} />
          <h3 className="bill-sheet__name">{bill.name}</h3>
          <p className="t-capture-12-m bill-sheet__status">
            Status: <span className={paid ? "is-done" : ""}>{paid && <Icon name="check-circle-done" size={14} />}{status}</span>
            {step && ` · ${step.paidCount}/${step.total} paid`}
          </p>
          {step && (
            <span className="bill-sheet__progress" aria-hidden="true">
              <span style={{ width: `${(step.paidCount / step.total) * 100}%` }} />
            </span>
          )}
        </div>

        <div className="bill-sheet__month">
          <span className="t-capture-12-m">This month</span>
          {due && !paid && bill.varies ? (
            <label className="bill-sheet__amount-input">
              <input
                className="tnum"
                inputMode="numeric"
                value={Number(amount.replace(/[^\d]/g, "") || 0).toLocaleString("en-US")}
                aria-label="Amount paid this month"
                onChange={(e) => setAmount(e.target.value)}
              />
              <span className="fn-amount__cur">đ</span>
            </label>
          ) : (
            <Amount value={due ? money(paid?.amount ?? bill.amount) : "0"} size={28} />
          )}
          {due && !paid && bill.varies && <span className="t-capture-12-r bill-sheet__hint">Changes each month — type what you actually paid</span>}
        </div>

        <dl className="entry__facts bill-sheet__facts">
          {facts.map(([k, v]) => (
            <div key={k}>
              <dt>{k}</dt>
              <dd>{v}</dd>
            </div>
          ))}
        </dl>

        <section className="bill-sheet__history" aria-label="History">
          <h4 className="t-body-14-s">History</h4>
          {history.length ? (
            <ul>
              {history.map(([m, p]) => (
                <li key={m}>
                  <span>{monthLabel(m)}</span>
                  <Amount value={money(p.amount)} />
                </li>
              ))}
            </ul>
          ) : (
            <p className="t-capture-12-r bill-sheet__none">No payments checked off yet.</p>
          )}
          {bill.kind !== "oneoff" && (
            <p className="t-capture-12-r bill-sheet__next">
              Next: {(() => {
                for (let i = 0; i < 24; i++) {
                  const m = addMonths(ym(today()), i)
                  const d = dueIn(bill, m)
                  if (d && !bill.paid[m]) return ddmmyyyy(d)
                }
                return "nothing left"
              })()}
            </p>
          )}
        </section>
      </div>
    </ModalSheet>
  )
}
