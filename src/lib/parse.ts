import type { Flow } from "../components/ui"
import { addDays } from "./format"
import type { CategoryName } from "./store"

/** A line the reader pulled out of a note, before the user confirms it. */
export type Draft = {
  key: string
  title: string
  /** null when no amount could be read — the user fills it in before saving. */
  amount: number | null
  flow: Flow
  category: CategoryName
  date: string
  /** A bare number like "45" was read as 45,000. */
  assumedThousands?: boolean
}

/*
 * A local, rule-based reader so the app works with no API key and no network.
 * It understands the shorthand people actually type: 24k, 35.000, 1tr2, 2tr5, 1.5tr, 100k,
 * Vietnamese and English words, "hôm qua"/"yesterday". When Claude is connected later,
 * it replaces this function but keeps the same Draft shape and the same confirm step.
 */

const AMOUNT =
  /(\d+(?:[.,]\d+)*)\s*(k|nghìn|nghin|ngàn|ngan|tr|triệu|trieu|m|đ|vnd|vnđ|d)?(\d)?(?![\p{L}\d])/giu

function readAmount(raw: string, unit: string | undefined, tail: string | undefined) {
  const u = (unit || "").toLowerCase()
  const isMillion = ["tr", "triệu", "trieu", "m"].includes(u)
  const isThousand = ["k", "nghìn", "nghin", "ngàn", "ngan"].includes(u)
  // "1tr2" → 1.2 million, "2tr5" → 2.5 million
  if (isMillion && tail) return { value: (Number(raw.replace(",", ".")) + Number(tail) / 10) * 1e6, assumed: false }
  if (isMillion) return { value: Number(raw.replace(",", ".")) * 1e6, assumed: false }
  if (isThousand) return { value: Number(raw.replace(",", ".")) * 1e3, assumed: false }
  // "35.000" or "35,000" → 35000
  const digits = Number(raw.replace(/[.,]/g, ""))
  if (/[.,]\d{3}$/.test(raw) || u.startsWith("đ") || u.startsWith("vnd") || u === "d") return { value: digits, assumed: false }
  // A bare small number almost always means thousands ("cafe 45").
  if (digits > 0 && digits < 1000) return { value: digits * 1000, assumed: true }
  return { value: digits, assumed: false }
}

const INCOME = /paid me back|trả lại|tra lai|trả mình|nhận|nhan duoc|received|lương|luong|salary|thưởng|bonus|refund|hoàn tiền|hoan tien|got paid/i

const RULES: [CategoryName, RegExp][] = [
  ["Transport", /xăng|xang|petrol|gas\b|grab|\bbe\b|taxi|xe ôm|gửi xe|gui xe|parking|bus|uber|vé xe|tàu|train/i],
  ["Bills", /điện|tiền nước|internet|wifi|\bbills?\b|hoá đơn|hóa đơn|phí|\bfees?\b|\brent\b|tiền nhà|trả góp|installment/i],
  ["Shopping", /mua|shopee|lazada|tiki|quần|áo|giày|dép|shirt|shoes|clothes|shopping/i],
  [
    "Food",
    /cà phê|ca phe|cafe|\bcf\b|coffee|cơm|com tam|phở|pho|bún|bun|bánh|banh|ăn|an sang|trà sữa|tra sua|milk tea|lunch|breakfast|dinner|rice|sandwich|thịt|đậu|đậu hũ|rau|chợ|tofu|snack|nước|drink|tea|bia|beer|food|pizza|mì|noodle/i,
  ],
]

const DAY_WORDS = /\b(hôm nay|hom nay|today|hôm qua|hom qua|yesterday)\b/giu

/** How it was paid, written at the end: "· cash", "· transfer", "tiền mặt", "chuyển khoản". */
const PAID_WITH = /\s*[·\-–]?\s*(cash|transfer|card|tiền mặt|tien mat|chuyển khoản|chuyen khoan|\bck\b|thẻ)\s*$/iu

function tidyTitle(s: string) {
  const t = s
    .replace(DAY_WORDS, " ")
    .replace(PAID_WITH, "")
    .replace(/\s*[-–—:·]\s*$/u, "")
    .replace(/^\s*[-–—:·]\s*/u, "")
    .replace(/\s{2,}/g, " ")
    .trim()
  return t ? t[0].toLocaleUpperCase("vi") + t.slice(1) : ""
}

const isDayWord = (s: string) => /^(hôm nay|hom nay|today|hôm qua|hom qua|yesterday)$/iu.test(s)
const hasAmount = (s: string) => {
  AMOUNT.lastIndex = 0
  return AMOUNT.test(s)
}

export function parseNote(text: string, day: string): Draft[] {
  const base = /hôm qua|hom qua|yesterday/i.test(text) ? addDays(day, -1) : day
  // Each line (or ";") is read on its own; inside a line, split on "và/and/+" and on commas that
  // aren't inside a number ("35,000", "1,5tr").
  const segments = text
    .split(/[\n;]+/)
    .flatMap((line) => {
      const parts = line
        .split(/(?<!\d),|,(?!\d)|\s+(?:và|va|and|\+)\s+/iu)
        .map((s) => s.trim())
        .filter((s) => s && !isDayWord(s))
      // "Lunch, broken rice 40k" is one thing: a part with no amount joins the next part that has one.
      const merged: string[] = []
      let carry = ""
      for (const p of parts) {
        if (!hasAmount(p)) {
          carry = carry ? `${carry}, ${p}` : p
          continue
        }
        merged.push(carry ? `${carry}, ${p}` : p)
        carry = ""
      }
      if (carry) merged.push(carry)
      return merged
    })

  return segments.map((segment, i) => {
    AMOUNT.lastIndex = 0
    const match = AMOUNT.exec(segment)
    const read = match ? readAmount(match[1], match[2], match[3]) : null
    const rest = match ? segment.replace(match[0], " ") : segment
    const flow: Flow = INCOME.test(segment) ? "in" : "out"
    const category: CategoryName = flow === "in" ? "Received" : (RULES.find(([, re]) => re.test(segment))?.[0] ?? "Other")
    return {
      key: `${Date.now()}-${i}`,
      title: tidyTitle(rest) || category,
      amount: read && read.value > 0 ? read.value : null,
      flow,
      category,
      date: base,
      assumedThousands: read?.assumed || undefined,
    }
  })
}
