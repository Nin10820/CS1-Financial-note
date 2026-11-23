import { useState } from "react"
import { Icon } from "../components/Icon"
import { AmountPad } from "../components/kit"
import { money } from "../lib/format"
import ModalSheet, { ModalHeader } from "./ModalSheet"

/** A number on the pad: the saving goal, or an amount put aside. */
export default function NumberSheet({ title, prompt, start, note, onClose, onSave }: { title: string; prompt: string; start: number; note?: string; onClose: () => void; onSave: (v: number) => void }) {
  const [value, setValue] = useState<number | null>(null)
  const v = value ?? 0
  return (
    <ModalSheet
      label={title}
      onClose={onClose}
      header={
        <ModalHeader
          title={title}
          left={
            <button type="button" className="k-iconbtn" aria-label="Cancel" onClick={onClose}>
              <Icon name="close" size={18} />
            </button>
          }
          right={
            <button
              type="button"
              className="tpl__save"
              aria-label="Save"
              disabled={v <= 0}
              onClick={() => {
                onSave(v)
                onClose()
              }}
            >
              <Icon name="check" size={22} />
            </button>
          }
        />
      }
      footer={<AmountPad onChange={(f) => setValue((x) => f(x ?? 0))} />}
    >
      <div className="num-sheet">
        <p>{prompt}</p>
        <span className={`tnum${value == null ? " is-ghost" : ""}`}>
          {money(value ?? start)}
          <small>đ</small>
        </span>
        {note && <p className="k-note">{note}</p>}
      </div>
    </ModalSheet>
  )
}
