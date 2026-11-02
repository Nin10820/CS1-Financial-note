import { useEffect, useRef, useState } from "react"
import jsQR from "jsqr"
import { Button, IconButton } from "../components/ui"
import { Icon } from "../components/Icon"
import { money } from "../lib/format"
import { BANKS, bankByBin, parsePayCode, payLink, type PayCode } from "../lib/vietqr"
import ModalSheet, { ModalHeader } from "./ModalSheet"
import "./scan.css"

export type ScanPrefill = { title?: string; amount?: number; comment?: string }

/**
 * Scan — iOS ScanView. QR Code: read a VietQR code with the camera; a code with a bank account opens
 * the transfer sheet, one without becomes a filled-in Template line. Note: reading a paper list needs
 * the AI reader, which comes later on the web.
 */
export default function Scan({
  banks,
  onBanks,
  onClose,
  onTemplate,
  onWrite,
  onSaveTransfer,
}: {
  banks: string[]
  onBanks: (apps: string[]) => void
  onClose: () => void
  onTemplate: (p: ScanPrefill) => void
  onWrite: () => void
  onSaveTransfer: (title: string, amount: number, note?: string) => void
}) {
  const [mode, setMode] = useState<"qr" | "note">("qr")
  const [code, setCode] = useState<PayCode | null>(null)
  const [problem, setProblem] = useState<string | null>(null)

  const found = (text: string) => {
    const c = parsePayCode(text)
    if (!c) {
      setProblem("That code isn't a bank transfer code.")
      return false
    }
    if (c.account && c.bin) {
      setCode(c)
      return true
    }
    onTemplate({ title: c.name ?? c.note, amount: c.amount, comment: c.note })
    return true
  }

  return (
    <div className="scan2" role="dialog" aria-label="Scan">
      <div className="scan2__top">
        <IconButton icon="close" label="Close" variant="glass" size={44} onClick={onClose} />
        <div className="scan2__modes" role="tablist" aria-label="What to scan">
          {(["qr", "note"] as const).map((m) => (
            <button key={m} type="button" role="tab" aria-selected={mode === m} className={`scan2__mode${mode === m ? " is-on" : ""}`} onClick={() => setMode(m)}>
              {m === "qr" ? "QR Code" : "Note"}
            </button>
          ))}
        </div>
        <span style={{ width: 44 }} />
      </div>

      {mode === "qr" ? (
        <QrReader paused={!!code} onText={found} problem={problem} onProblem={setProblem} />
      ) : (
        <section className="scan2__note">
          <Icon name="tab-scan" size={40} />
          <h2>Scan a paper note</h2>
          <p>Reading a handwritten list comes in a later version. For now, write the list and it&apos;s split the same way.</p>
          <Button variant="primary" size="lg" icon="file-edit" onClick={onWrite}>
            Write it instead
          </Button>
        </section>
      )}

      {code && (
        <TransferSheet
          code={code}
          banks={banks}
          onBanks={onBanks}
          onClose={() => setCode(null)}
          onSaved={(title, amount) => {
            onSaveTransfer(title, amount, code.note)
            onClose()
          }}
        />
      )}
    </div>
  )
}

/** Camera preview with a frame; every few frames the picture is checked for a QR code. */
function QrReader({
  paused,
  onText,
  problem,
  onProblem,
}: {
  paused: boolean
  onText: (text: string) => boolean
  problem: string | null
  onProblem: (p: string | null) => void
}) {
  const video = useRef<HTMLVideoElement>(null)
  const canvas = useRef<HTMLCanvasElement | null>(null)
  const [camera, setCamera] = useState<"starting" | "on" | "blocked">("starting")
  const pausedRef = useRef(paused)
  pausedRef.current = paused
  const last = useRef("")

  useEffect(() => {
    let stream: MediaStream | null = null
    let raf = 0
    let alive = true
    const tick = () => {
      if (!alive) return
      const v = video.current
      if (v && v.readyState >= 2 && !pausedRef.current) {
        const c = (canvas.current ??= document.createElement("canvas"))
        const w = 480
        const h = Math.round((v.videoHeight / v.videoWidth) * w) || 480
        c.width = w
        c.height = h
        const ctx = c.getContext("2d", { willReadFrequently: true })
        if (ctx) {
          ctx.drawImage(v, 0, 0, w, h)
          const hit = jsQR(ctx.getImageData(0, 0, w, h).data, w, h, { inversionAttempts: "dontInvert" })
          if (hit?.data && hit.data !== last.current) {
            last.current = hit.data
            navigator.vibrate?.(30)
            onText(hit.data)
          }
        }
      }
      raf = window.setTimeout(() => requestAnimationFrame(tick), 200)
    }
    navigator.mediaDevices
      ?.getUserMedia({ video: { facingMode: "environment" }, audio: false })
      .then((s) => {
        if (!alive) return s.getTracks().forEach((t) => t.stop())
        stream = s
        if (video.current) {
          video.current.srcObject = s
          void video.current.play()
        }
        setCamera("on")
        tick()
      })
      .catch(() => setCamera("blocked"))
    if (!navigator.mediaDevices) setCamera("blocked")
    return () => {
      alive = false
      clearTimeout(raf)
      stream?.getTracks().forEach((t) => t.stop())
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // A photo of a code works too (and is the way in when the camera is blocked).
  const fromPhoto = (file: File) => {
    const img = new Image()
    img.onload = () => {
      const c = document.createElement("canvas")
      const scale = Math.min(1, 1000 / Math.max(img.width, img.height))
      c.width = Math.round(img.width * scale)
      c.height = Math.round(img.height * scale)
      const ctx = c.getContext("2d")
      if (!ctx) return
      ctx.drawImage(img, 0, 0, c.width, c.height)
      const hit = jsQR(ctx.getImageData(0, 0, c.width, c.height).data, c.width, c.height)
      if (hit?.data) onText(hit.data)
      else onProblem("No QR code found in that photo.")
      URL.revokeObjectURL(img.src)
    }
    img.src = URL.createObjectURL(file)
  }

  return (
    <section className="scan2__qr">
      <div className="scan2__view">
        <video ref={video} playsInline muted aria-hidden="true" />
        <div className="scan__frame scan2__frame" aria-hidden="true">
          <i />
          <i />
          <i />
          <i />
        </div>
        {camera === "blocked" && <p className="scan2__blocked">The camera isn&apos;t available. Pick a photo of the code instead.</p>}
      </div>
      <p className="scan2__hint" role="status">
        {problem ?? "Point at a bank QR code"}
      </p>
      <label className="scan2__photo">
        <Icon name="plus" size={18} />
        Pick a photo
        <input
          type="file"
          accept="image/*"
          onChange={(e) => {
            onProblem(null)
            const f = e.target.files?.[0]
            if (f) fromPhoto(f)
            e.target.value = ""
          }}
        />
      </label>
    </section>
  )
}

/**
 * Who it goes to, how much, then which bank app to pay with. The bank app opens with the transfer
 * filled in; when the user comes back, ask whether it went through before saving the line.
 */
function TransferSheet({
  code,
  banks,
  onBanks,
  onClose,
  onSaved,
}: {
  code: PayCode
  banks: string[]
  onBanks: (apps: string[]) => void
  onClose: () => void
  onSaved: (title: string, amount: number) => void
}) {
  const [amount, setAmount] = useState(code.amount ?? 0)
  const [opened, setOpened] = useState<string | null>(null)
  const [all, setAll] = useState(banks.length === 0)
  const to = bankByBin(code.bin)
  const title = code.name ? `Transfer to ${code.name}` : "Transfer"
  const shown = all ? BANKS : BANKS.filter((b) => banks.includes(b.app))

  const open = (app: string) => {
    if (!banks.includes(app)) onBanks([app, ...banks].slice(0, 6))
    setOpened(app)
    window.location.href = payLink(app, { ...code, amount: amount || undefined })
  }

  return (
    <ModalSheet
      label="Transfer"
      size="auto"
      onClose={onClose}
      header={<ModalHeader title="Transfer" right={<IconButton icon="close" label="Close" variant="glass-strong" onClick={onClose} />} />}
    >
      <div className="transfer">
        <div className="transfer__to">
          <span className="transfer__name">{code.name ?? "Receiver"}</span>
          <span className="transfer__acct tnum">
            {to?.name ?? `Bank ${code.bin}`} · {code.account}
          </span>
          {code.note && <span className="transfer__note">“{code.note}”</span>}
        </div>
        <label className="transfer__amount">
          <span>Amount</span>
          <input
            inputMode="numeric"
            value={amount ? money(amount) : ""}
            placeholder="0"
            onChange={(e) => setAmount(Number(e.target.value.replace(/\D/g, "")) || 0)}
          />
          <small>đ</small>
        </label>

        {opened ? (
          <div className="transfer__ask">
            <p>
              Did you send {amount ? `${money(amount)}đ` : "it"} to {code.name ?? "them"}?
            </p>
            <Button variant="primary" size="lg" disabled={!amount} onClick={() => onSaved(title, amount)}>
              Yes, save it
            </Button>
            <Button variant="outline" size="lg" onClick={() => setOpened(null)}>
              Not yet
            </Button>
          </div>
        ) : (
          <>
            <p className="transfer__label">Pay with</p>
            <div className="transfer__banks">
              {shown.map((b) => (
                <button key={b.app} type="button" className="transfer__bank" onClick={() => open(b.app)}>
                  {b.name}
                </button>
              ))}
              {!all && (
                <button type="button" className="transfer__bank is-more" onClick={() => setAll(true)}>
                  Other bank…
                </button>
              )}
            </div>
          </>
        )}
      </div>
    </ModalSheet>
  )
}
