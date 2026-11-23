/**
 * VietQR / EMVCo payment codes (port of the iOS VietQR.swift). Tags read: 38 › 01 › 00 bank BIN and
 * 01 account, 54 amount, 59 receiver name, 62 › 08 transfer note.
 */
export type PayCode = {
  bin?: string
  account?: string
  amount?: number
  name?: string
  note?: string
}

function tlv(s: string): Map<string, string> {
  const out = new Map<string, string>()
  let i = 0
  while (i + 4 <= s.length) {
    const tag = s.slice(i, i + 2)
    const len = Number(s.slice(i + 2, i + 4))
    if (!Number.isFinite(len)) break
    out.set(tag, s.slice(i + 4, i + 4 + len))
    i += 4 + len
  }
  return out
}

/** Null when the text isn't an EMVCo payment code. */
export function parsePayCode(raw: string): PayCode | null {
  const s = raw.trim()
  if (!s.startsWith("000201")) return null
  const top = tlv(s)
  const code: PayCode = {}
  const acct = top.get("38")
  if (acct) {
    const inner = tlv(tlv(acct).get("01") ?? "")
    code.bin = inner.get("00")
    code.account = inner.get("01")
  }
  const amount = Number(top.get("54"))
  if (amount > 0) code.amount = Math.round(amount)
  code.name = top.get("59")?.trim() || undefined
  code.note = tlv(top.get("62") ?? "").get("08")?.trim() || undefined
  return code
}

/** Banks by BIN, with their VietQR deep-link app id. */
export const BANKS: { bin: string; app: string; name: string }[] = [
  { bin: "970436", app: "vcb", name: "Vietcombank" },
  { bin: "970415", app: "icb", name: "VietinBank" },
  { bin: "970418", app: "bidv", name: "BIDV" },
  { bin: "970405", app: "vba", name: "Agribank" },
  { bin: "970422", app: "mb", name: "MB Bank" },
  { bin: "970407", app: "tcb", name: "Techcombank" },
  { bin: "970416", app: "acb", name: "ACB" },
  { bin: "970432", app: "vpb", name: "VPBank" },
  { bin: "970423", app: "tpb", name: "TPBank" },
  { bin: "970403", app: "stb", name: "Sacombank" },
  { bin: "970437", app: "hdb", name: "HDBank" },
  { bin: "970441", app: "vib", name: "VIB" },
  { bin: "970443", app: "shb", name: "SHB" },
  { bin: "970448", app: "ocb", name: "OCB" },
  { bin: "970426", app: "msb", name: "MSB" },
  { bin: "970454", app: "vccb", name: "Ban Viet" },
  { bin: "963388", app: "timo", name: "Timo" },
  { bin: "970449", app: "lpb", name: "LPBank" },
]
export const bankByBin = (bin?: string) => BANKS.find((b) => b.bin === bin)

/** The VietQR hand-off link: opens the bank app with the transfer filled in. */
export function payLink(app: string, code: PayCode) {
  const q = new URLSearchParams({ app, ba: `${code.account}@${code.bin}` })
  if (code.amount) q.set("am", String(code.amount))
  if (code.note) q.set("tn", code.note)
  return `https://dl.vietqr.io/pay?${q}`
}
