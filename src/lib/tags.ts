/** Tags from Figma High Fi 2 › Select tag (1052:6578), same list as the iOS app (Logic/Tags.swift).
    A line keeps its category (for colours and the reader) and can carry any number of tags on top. */
import type { CategoryName } from "./store"

export type TagInfo = {
  name: string
  /** emoji stands in for the SF Symbol the iOS app uses */
  mark: string
  /** fill when picked, and whether its text should be white */
  fill: string
  whiteText?: boolean
}

export const DEFAULT_TAGS: TagInfo[] = [
  { name: "Food", mark: "🍴", fill: "#F8EADC" },
  { name: "Drinks", mark: "☕", fill: "#BDE7FA" },
  { name: "Public Transit", mark: "🚌", fill: "#CCFBEF" },
  { name: "Health", mark: "♥", fill: "#C11574", whiteText: true },
  { name: "Housing", mark: "🏠", fill: "#E0EAFF" },
  { name: "Education", mark: "🎓", fill: "#C7D7FE" },
  { name: "Snacks", mark: "🧁", fill: "#B42318", whiteText: true },
  { name: "Gas", mark: "⛽", fill: "#FFE6D5" },
  { name: "Shopping", mark: "🛍", fill: "#FCE7F6" },
  { name: "Internet & Phone", mark: "📶", fill: "#E2F4D3" },
  { name: "Clothing", mark: "👕", fill: "#FEF0C7" },
  { name: "Medical", mark: "✚", fill: "#FEE4E2" },
]

export const tagInfo = (name: string) => DEFAULT_TAGS.find((t) => t.name === name)

/** A sensible tag for a line, from its category and the words in its name. */
export function suggestTag(title: string, category: CategoryName): string | null {
  const t = title.toLocaleLowerCase("vi")
  const has = (re: RegExp) => re.test(t)
  switch (category) {
    case "Food":
      if (has(/cà phê|ca phe|cafe|coffee|\bcf\b|trà|tra sua|milk tea|tea|bia|beer|nước|drink|juice|sinh tố/)) return "Drinks"
      if (has(/snack|bánh|banh|kẹo|chips|cake/)) return "Snacks"
      return "Food"
    case "Transport":
      if (has(/bus|xe buýt|train|tàu|metro/)) return "Public Transit"
      if (has(/xăng|xang|petrol|gas/)) return "Gas"
      return null
    case "Shopping":
      if (has(/áo|quần|giày|dép|shirt|t-shirt|shoes|clothes|váy/)) return "Clothing"
      return "Shopping"
    case "Bills":
      if (has(/internet|wifi|phone|điện thoại|sim|4g|mạng/)) return "Internet & Phone"
      if (has(/điện|nước|water|electric|rent|tiền nhà|nhà/)) return "Housing"
      if (has(/học|course|school|tuition/)) return "Education"
      return null
    case "Other":
      if (has(/thuốc|medicine|doctor|bác sĩ|hospital|bệnh viện|khám/)) return "Medical"
      if (has(/gym|haircut|cắt tóc|spa/)) return "Health"
      return null
    default:
      return null
  }
}

/** "Cash", "Transfer" or "Card" from how a note said it was paid ("· cash", "chuyển khoản"…). */
export function paidFromWords(said: string): string | null {
  const s = said.toLocaleLowerCase("vi")
  if (/cash|tiền mặt|tien mat/.test(s)) return "Cash"
  if (/transfer|chuyển khoản|chuyen khoan|\bck\b/.test(s)) return "Transfer"
  if (/card|thẻ/.test(s)) return "Card"
  return null
}
