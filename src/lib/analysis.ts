import type { IconName } from "../components/Icon"
import { addDays, addMonthsYm, daysIn, pad } from "./format"
import type { Entry } from "./store"

/* View Analysis (port of the iOS AnalyticsView, AnalysisChart, SpendNeed and SavingGoal).
   Everything is worked out on the device from the lines the user wrote. */

export type Period = "day" | "week" | "month" | "year" | "all"
export const PERIODS: { value: Period; label: string }[] = [
  { value: "day", label: "D" },
  { value: "week", label: "W" },
  { value: "month", label: "M" },
  { value: "year", label: "Y" },
  { value: "all", label: "All" },
]

const MS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const ML = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
export const monthsShort = MS
export const monthsLong = ML

const parts = (iso: string) => iso.split("-").map(Number) as [number, number, number]
const full = (iso: string) => {
  const [y, m, d] = parts(iso)
  return `${d} ${MS[m - 1]} ${y}`
}
export const monday = (iso: string) => {
  const [y, m, d] = parts(iso)
  const wd = new Date(y, m - 1, d).getDay() // 0 = Sunday
  return addDays(iso, -((wd + 6) % 7))
}

export type Bar = { label: string; title: string; out: number; incoming: number }
export type Span = { from: string; to: string }

/** "16 – 22 Nov 2026", "November 2026", "2026", "All time". */
export function periodTitle(p: Period, anchor: string) {
  if (p === "day") return full(anchor)
  if (p === "week") {
    const a = monday(anchor)
    const b = addDays(a, 6)
    const [, am, ad] = parts(a)
    const [, bm] = parts(b)
    return am === bm ? `${ad} – ${full(b)}` : `${ad} ${MS[am - 1]} – ${full(b)}`
  }
  if (p === "month") {
    const [y, m] = parts(anchor)
    return `${ML[m - 1]} ${y}`
  }
  if (p === "year") return anchor.slice(0, 4)
  return "All time"
}

export function periodRange(p: Period, anchor: string, all: Span): Span {
  if (p === "day") return { from: anchor, to: anchor }
  if (p === "week") {
    const a = monday(anchor)
    return { from: a, to: addDays(a, 6) }
  }
  if (p === "month") return { from: `${anchor.slice(0, 7)}-01`, to: `${anchor.slice(0, 7)}-${pad(daysIn(anchor.slice(0, 7)))}` }
  if (p === "year") return { from: `${anchor.slice(0, 4)}-01-01`, to: `${anchor.slice(0, 4)}-12-31` }
  return all
}

const dayCount = (a: string, b: string) => Math.round((Date.parse(b) - Date.parse(a)) / 86_400_000)

/** The bars for a period around a day: 3-hour slots, week days, month days, months. */
export function makeBars(p: Period, anchor: string, all: Span, entries: Entry[]): Bar[] {
  const byDay = new Map<string, { out: number; incoming: number }>()
  for (const e of entries) {
    const s = byDay.get(e.date) ?? { out: 0, incoming: 0 }
    if (e.flow === "out") s.out += e.amount
    else s.incoming += e.amount
    byDay.set(e.date, s)
  }
  const day = (iso: string, label: string): Bar => ({ label, title: full(iso), ...(byDay.get(iso) ?? { out: 0, incoming: 0 }) })
  const monthBar = (m: string, label: string): Bar => {
    let out = 0
    let incoming = 0
    for (const [k, v] of byDay)
      if (k.startsWith(m)) {
        out += v.out
        incoming += v.incoming
      }
    return { label, title: `${ML[Number(m.slice(5, 7)) - 1]} ${m.slice(0, 4)}`, out, incoming }
  }
  const days = (from: string, to: string) => {
    const out: Bar[] = []
    for (let d = from; d <= to; d = addDays(d, 1)) out.push(day(d, String(Number(d.slice(8, 10)))))
    return out
  }
  if (p === "day") {
    const lines = entries.filter((e) => e.date === anchor)
    return Array.from({ length: 8 }, (_, k) => {
      const slot = lines.filter((e) => Math.floor(new Date(e.createdAt).getHours() / 3) === k)
      return {
        label: `${k * 3}h`,
        title: `${full(anchor)}, ${k * 3}:00–${k * 3 + 3}:00`,
        out: slot.filter((e) => e.flow === "out").reduce((t, e) => t + e.amount, 0),
        incoming: slot.filter((e) => e.flow === "in").reduce((t, e) => t + e.amount, 0),
      }
    })
  }
  if (p === "week") {
    const names = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    const start = monday(anchor)
    return names.map((n, i) => day(addDays(start, i), n))
  }
  if (p === "month") {
    const r = periodRange("month", anchor, all)
    return days(r.from, r.to)
  }
  if (p === "year") return MS.map((n, i) => monthBar(`${anchor.slice(0, 4)}-${pad(i + 1)}`, n))
  if (dayCount(all.from, all.to) <= 31) return days(all.from, all.to)
  const bars: Bar[] = []
  for (let m = all.from.slice(0, 7); m <= all.to.slice(0, 7); m = addMonthsYm(m, 1)) bars.push(monthBar(m, MS[Number(m.slice(5, 7)) - 1]))
  return bars
}

/** A round top for the scale: 1, 2, 2.5 or 5 times a power of ten. */
export function niceMax(v: number) {
  if (v <= 0) return 100_000
  const p = 10 ** Math.floor(Math.log10(v))
  for (const f of [1, 2, 2.5, 5, 10]) if (v <= f * p) return f * p
  return 10 * p
}

/* ── What a spend was for ───────────────────────────────── */

/** Lower case, no accents, đ → d, padded with spaces: "Cà phê sữa đá!" → " ca phe sua da ". */
export function fold(s: string) {
  const plain = s
    .toLocaleLowerCase("vi")
    .replace(/đ/g, "d")
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
  return ` ${plain.replace(/[^a-z0-9&+-]+/g, " ").trim()} `
}
const has = (folded: string, word: string) => folded.includes(` ${word.trim()} `)

export type SpendKind =
  | "Food & Drinks"
  | "Housing & Utilities"
  | "Transportation"
  | "Health & Fitness"
  | "Education"
  | "Technology"
  | "Hobbies"
  | "Shopping"
  | "Travel"
  | "Social & Gifts"
  | "Subscriptions"
  | "Other"

export const KIND_LOOK: Record<SpendKind, { icon: IconName; color: string }> = {
  "Food & Drinks": { icon: "fork-knife", color: "var(--category-food)" },
  "Housing & Utilities": { icon: "house", color: "var(--kind-housing)" },
  Transportation: { icon: "motorcycle", color: "var(--category-transport)" },
  "Health & Fitness": { icon: "heartbeat", color: "var(--kind-health)" },
  Education: { icon: "graduation-cap", color: "var(--kind-education)" },
  Technology: { icon: "device-mobile", color: "var(--kind-technology)" },
  Hobbies: { icon: "game-controller", color: "var(--kind-hobbies)" },
  Shopping: { icon: "shopping-bag", color: "var(--kind-shopping)" },
  Travel: { icon: "airplane", color: "var(--kind-travel)" },
  "Social & Gifts": { icon: "gift", color: "var(--kind-social)" },
  Subscriptions: { icon: "repeat", color: "var(--kind-subscriptions)" },
  Other: { icon: "dots-three-circle", color: "var(--grey-400)" },
}

const KIND_NEED: Record<SpendKind, Need> = {
  "Food & Drinks": "Essential",
  "Housing & Utilities": "Essential",
  Transportation: "Essential",
  "Health & Fitness": "Essential",
  Education: "Worthwhile",
  Technology: "Worthwhile",
  Travel: "Worthwhile",
  "Social & Gifts": "Worthwhile",
  Other: "Worthwhile",
  Hobbies: "Optional",
  Shopping: "Optional",
  Subscriptions: "Optional",
}

/** Words for each kind, without accents, checked in this order (the more specific lists first). */
const WORDS: [SpendKind, string[]][] = [
  ["Subscriptions", ["netflix", "spotify", "youtube premium", "youtube", "icloud", "google one", "google drive", "apple music", "apple tv", "apple one", "disney", "fpt play", "vieon", "k+", "chatgpt", "claude", "canva", "notion", "adobe", "figma", "office 365", "microsoft 365", "zing mp3", "nhaccuatui", "tiktok", "subscription", "goi thang", "phi thanh vien", "membership", "thue bao", "premium"]],
  ["Travel", ["du lich", "travel", "trip", "khach san", "hotel", "homestay", "resort", "airbnb", "booking", "ve may bay", "may bay", "flight", "vietjet", "vietnam airlines", "bamboo", "ve tau", "tau hoa", "xe khach", "ve xe", "limousine", "da lat", "vung tau", "nha trang", "phu quoc", "sapa", "ha long", "hoi an", "da nang", "tour", "visa", "ho chieu", "passport", "vali", "phong khach san", "cam trai", "camping"]],
  ["Social & Gifts", ["qua", "gift", "sinh nhat", "birthday", "mung cuoi", "dam cuoi", "dam hoi", "wedding", "dam tang", "phung vieng", "li xi", "mung tuoi", "tet", "an voi ny", "voi ny", "ny", "nguoi yeu", "hen ho", "date", "di an voi", "an voi ban", "nhau", "bia", "beer", "lau voi", "hop lop", "hop mat", "party", "tiec", "moi ban", "bao ban", "chia tien", "dong gop", "quyen gop", "tu thien", "donate", "hoa tang", "bo hoa", "flowers", "thiep"]],
  ["Education", ["hoc phi", "tuition", "khoa hoc", "course", "lop hoc", "hoc them", "hoc tieng", "ielts", "toeic", "english", "tieng anh", "tieng nhat", "tieng han", "sach", "book", "giao trinh", "tai lieu", "van phong pham", "but", "vo viet", "workshop", "seminar", "udemy", "coursera", "duolingo", "chung chi", "thi", "le phi thi", "gia su", "tutor", "truong", "school", "dai hoc"]],
  ["Health & Fitness", ["thuoc", "medicine", "nha thuoc", "pharmacy", "kham", "doctor", "benh vien", "hospital", "phong kham", "clinic", "nha khoa", "nho rang", "tram rang", "dau rang", "dentist", "xet nghiem", "vitamin", "thuc pham chuc nang", "bao hiem y te", "gym", "yoga", "pilates", "boi", "swim", "chay bo", "running", "the thao", "sport", "fitness", "whey", "protein", "massage", "spa", "vat ly tri lieu", "kinh mat", "kinh can", "cat toc", "haircut", "goi dau"]],
  ["Technology", ["dien thoai", "iphone", "samsung", "xiaomi", "oppo", "laptop", "macbook", "may tinh", "pc", "ipad", "tablet", "tai nghe", "airpods", "headphone", "sac", "charger", "cap sac", "cable", "op lung", "op dien thoai", "case", "ban phim", "keyboard", "chuot", "mouse", "man hinh", "monitor", "o cung", "ssd", "usb", "loa", "speaker", "dong ho thong minh", "apple watch", "camera", "sua dien thoai", "thay pin", "phan mem", "software", "app", "game key", "the nho", "router", "wifi"]],
  ["Hobbies", ["game", "steam", "playstation", "nintendo", "nap game", "guitar", "dan", "piano", "ukulele", "ve tranh", "mau ve", "painting", "cau ca", "fishing", "board game", "lego", "mo hinh", "figure", "suu tam", "trong cay", "cay canh", "hat giong", "nhiep anh", "film", "phim", "movie", "cgv", "lotte cinema", "rap", "karaoke", "concert", "nhac hoi", "bida", "bowling", "tennis", "cau long", "badminton", "pickleball", "da banh", "san bong", "len", "thu cong", "craft", "anime", "manga", "truyen"]],
  ["Housing & Utilities", ["tien nha", "thue nha", "rent", "phong tro", "nha tro", "dien", "electric", "electricity", "evn", "tien nuoc", "nuoc sinh hoat", "water bill", "water", "internet", "wifi nha", "fpt", "viettel", "vnpt", "gas", "binh gas", "phi quan ly", "chung cu", "rac", "ve sinh", "giat ui", "giat say", "laundry", "nuoc giat", "giay ve sinh", "do gia dung", "noi chao", "chen bat", "ga giuong", "chan goi", "sua nha", "tho dien", "tho nuoc", "noi that", "furniture", "ikea", "bong den", "cay lau nha", "chat tay rua", "do dung nha"]],
  ["Transportation", ["xang", "do xang", "petrol", "fuel", "grab", "be", "xanh sm", "gojek", "taxi", "uber", "xe om", "gui xe", "parking", "phi do xe", "ve gui xe", "rua xe", "sua xe", "bao duong", "thay nhot", "lop xe", "vo xe", "bus", "xe buyt", "metro", "tau dien", "phi cau duong", "bot", "etc", "dang kiem", "bao hiem xe", "bang lai", "mu bao hiem"]],
  ["Shopping", ["shopee", "lazada", "tiki", "tiktok shop", "sendo", "dat do", "order", "ao", "quan", "jean", "vay", "dam", "giay", "dep", "sandal", "tui", "balo", "vi", "wallet", "dong ho", "trang suc", "nhan", "day chuyen", "my pham", "son", "kem chong nang", "skincare", "sua rua mat", "nuoc hoa", "perfume", "uniqlo", "zara", "h&m", "muji", "decathlon", "mall", "trung tam thuong mai", "do choi", "phu kien", "mua sam", "shopping"]],
  ["Food & Drinks", ["com", "pho", "bun", "mi", "mien", "hu tieu", "banh mi", "banh cuon", "banh xeo", "xoi", "chao", "lau", "nuong", "ga", "bo", "heo", "ca", "tom", "hai san", "an sang", "an trua", "an toi", "breakfast", "lunch", "dinner", "ca phe", "cafe", "coffee", "tra", "tea", "tra sua", "milk tea", "sinh to", "nuoc ep", "juice", "nuoc ngot", "nuoc suoi", "banh", "che", "kem", "an vat", "snack", "trai cay", "hoa qua", "di cho", "sieu thi", "bach hoa xanh", "winmart", "coopmart", "circle k", "gs25", "7-eleven", "thuc pham", "grocer", "gao", "rau", "thit", "trung", "sua", "pizza", "burger", "kfc", "lotteria", "jollibee", "highlands", "phuc long", "starbucks", "the coffee house", "katinat", "gong cha", "shopeefood", "grabfood", "baemin", "do an", "food"]],
]

export function spendKind(e: Entry): SpendKind {
  const t = fold(e.title)
  for (const [kind, list] of WORDS) if (list.some((w) => has(t, w))) return kind
  if (e.category === "Food") return "Food & Drinks"
  if (e.category === "Transport") return "Transportation"
  if (e.category === "Shopping") return "Shopping"
  if (e.category === "Bills") return "Housing & Utilities"
  return "Other"
}

/** How needed a spend is — a soft read for the user, never a judgement shown in red. */
export type Need = "Essential" | "Worthwhile" | "Optional"
export const NEEDS: Need[] = ["Essential", "Worthwhile", "Optional"]
export const NEED_COLOR: Record<Need, string> = { Essential: "var(--brand-500)", Worthwhile: "var(--need-worthwhile)", Optional: "var(--need-optional)" }
export const NEED_HINT: Record<Need, string> = {
  Essential: "Home, meals, getting around and health — the things that keep the month running.",
  Worthwhile: "Things that make life better: learning, people, trips, tools. Worth it, and easy to trim a little.",
  Optional: "Treats, hobbies, extra shopping and subscriptions. The easiest place to keep more money.",
}
export function spendNeed(e: Entry): Need {
  const kind = spendKind(e)
  const t = fold(e.title)
  const any = (ws: string[]) => ws.some((w) => has(t, w))
  if (any(["tra sua", "milk tea", "an vat", "snack", "banh trang", "nhau", "bia", "beer", "ruou"])) return "Optional"
  if (any(["ca phe", "cafe", "coffee", "grab", "taxi", "gym", "yoga", "ny", "nguoi yeu", "date"])) return "Worthwhile"
  if (e.category === "Bills") return kind === "Subscriptions" ? "Optional" : "Essential"
  return KIND_NEED[kind]
}

/** Where money in came from, guessed from the line's name. */
export type IncomeKind = "Salary" | "Business & selling" | "Rent" | "Freelance" | "Interest & investing" | "Paid back" | "Other"
export const INCOME_COLOR: Record<IncomeKind, string> = {
  Salary: "var(--brand-500)",
  "Business & selling": "var(--chart-orange)",
  Rent: "var(--kind-housing)",
  Freelance: "var(--chart-teal)",
  "Interest & investing": "var(--chart-gold-ink)",
  "Paid back": "var(--chart-blue)",
  Other: "var(--grey-400)",
}
export function incomeKind(e: Entry): IncomeKind {
  const t = e.title.toLocaleLowerCase("vi")
  if (/lương|luong|salary|thưởng|bonus|payroll/.test(t)) return "Salary"
  if (/cho thuê|thuê nhà|tiền nhà|rent|rental/.test(t)) return "Rent"
  if (/freelance|dự án|du an|project|thiết kế|design|job/.test(t)) return "Freelance"
  if (/lãi|lai suat|interest|cổ tức|dividend|chứng khoán|stock|quỹ|fund|crypto/.test(t)) return "Interest & investing"
  if (/trả tiền|trả lại|tra tien|paid back|pay back|hoàn|refund/.test(t)) return "Paid back"
  if (/bán|ban hang|buôn|kinh doanh|shop|order|doanh thu|sale|sell/.test(t)) return "Business & selling"
  return "Other"
}

/* ── Saving goal ─────────────────────────────────────────── */

/**
 * A month's saving plan: the goal, and the daily budget that keeps it in reach —
 * (money in − goal − bills) over the month's days. Bills are left out of the days unless counted.
 */
export function savingPlan(month: string, today: string, entries: Entry[], goalSetting: number, countBills: boolean) {
  const lines = entries.filter((e) => e.date.startsWith(month))
  const income = lines.filter((e) => e.flow === "in").reduce((t, e) => t + e.amount, 0)
  const prev = addMonthsYm(month, -1)
  const planIncome = income > 0 ? income : entries.filter((e) => e.date.startsWith(prev) && e.flow === "in").reduce((t, e) => t + e.amount, 0)
  const out = lines.filter((e) => e.flow === "out")
  const bills = out.filter((e) => e.category === "Bills").reduce((t, e) => t + e.amount, 0)
  const count = daysIn(month)
  const before = entries.filter((e) => e.date.startsWith(prev) && e.flow === "out" && e.category !== "Bills")
  const perDay = before.reduce((t, e) => t + e.amount, 0) / daysIn(prev)
  const room = before.length ? Math.floor((planIncome - bills - perDay * count) * 0.9) : planIncome / 5
  const suggested = Math.max(500_000, Math.floor(room / 500_000) * 500_000)
  const goal = goalSetting > 0 ? goalSetting : suggested
  const dailyBudget = Math.max(0, Math.floor((planIncome - goal - (countBills ? 0 : bills)) / count))
  const days = Array.from({ length: count }, (_, i) => `${month}-${pad(i + 1)}`)
  const byDay: Record<string, number> = {}
  for (const e of out) if (countBills || e.category !== "Bills") byDay[e.date] = (byDay[e.date] ?? 0) + e.amount
  const spent = (d: string) => byDay[d] ?? 0
  /** 0…1, how far under the budget the day stayed (null for days to come). */
  const level = (d: string) => {
    if (d > today) return null
    if (dailyBudget <= 0) return 0.15
    const r = spent(d) / dailyBudget
    return r <= 0.5 ? 1 : r <= 0.8 ? 0.75 : r <= 1 ? 0.5 : 0.15
  }
  return { goal, suggested, dailyBudget, days, spent, level }
}
