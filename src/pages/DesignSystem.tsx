import { useState, type ReactNode } from "react"
import {
  Amount,
  BottomBar,
  Button,
  ChatBubble,
  DatePill,
  FilterChips,
  IconButton,
  LogoMark,
  MonthCard,
  PageTitle,
  SegmentedTabs,
  Sheet,
  SpendCard,
  TransItem,
} from "../components/ui"
import "./design-system.css"

/* Living reference for the Financial Note design system.
   Left: tokens and components one by one. Right: the Final "Transaction" screen (Figma 765:19666)
   rebuilt only from those components, to check the pieces add up to the design. */

const COLORS: { group: string; items: [string, string][] }[] = [
  {
    group: "Brand",
    items: [
      ["brand-50", "#f2faeb"],
      ["brand-100", "#e2f4d3"],
      ["brand-200", "#c8e9ad"],
      ["brand-300", "#a4da7c"],
      ["brand-400", "#83c853"],
      ["brand-500", "#5fa82f"],
      ["brand-700", "#3b6922"],
      ["brand-800", "#2c481f"],
    ],
  },
  {
    group: "Grey",
    items: [
      ["grey-200", "#e3e8ef"],
      ["grey-300", "#9aa4b2"],
      ["grey-400", "#697586"],
      ["grey-500", "#364152"],
      ["grey-700", "#202939"],
      ["grey-800", "#121926"],
      ["grey-900", "#0d121c"],
    ],
  },
  {
    group: "Surfaces & borders",
    items: [
      ["bg-1", "#fcfcfd"],
      ["bg-2", "#f9fafb"],
      ["bg-3", "#f3f4f6"],
      ["bg-4", "#eaecf0"],
      ["bd-0", "#eef2f6"],
      ["bd-1", "#e3e8ef"],
      ["bd-3", "#cdd5df"],
    ],
  },
  {
    group: "Secondary & categories",
    items: [
      ["secondary-100", "#f8eadc"],
      ["secondary-300", "#e5b28c"],
      ["category-food", "#c85a34"],
      ["category-transport", "#1570ef"],
      ["category-received", "#4a1fb8"],
      ["text-error", "#f04438"],
    ],
  },
]

const TYPE: [string, string, string][] = [
  ["t-title", "Merriweather Bold 32 / 1.3", "Transaction"],
  ["t-title-sub", "Merriweather Regular 20 / 32", "Note"],
  ["t-amount-32", "Montserrat SemiBold 32", "547,000"],
  ["t-body-18-s", "Text-body/18px/[S] · 18 / 26", "List"],
  ["t-body-16-m", "Montserrat Medium 16", "Total Spend"],
  ["t-body-14-s", "Text-body/14px/[S] · 14 / 20", "Today"],
  ["t-body-14-m", "Text-body/14px/[M] · 14 / 20", "grab 42k to work"],
  ["t-body-14-r", "Text-body/14px/[R] · 14 / 20", "e.g. coffee 24k, breakfast 35k…"],
  ["t-capture-12-m", "Capture/12px/[M] · 12 / 16", "Food"],
  ["t-capture-12-r", "Capture/12px/[R] · 12 / 16", "9 notes · updated 21:14"],
  ["t-micro-10-s", "10 / 14 · 550", "3 statements"],
]

const SPACING = [2, 4, 6, 8, 12, 16, 20, 24, 32]
const CORNERS = [2, 4, 6, 8, 12, 16, 20]

export default function DesignSystem() {
  return (
    <div className="ds">
      <header className="ds-head">
        <LogoMark size={28} />
        <div>
          <h1 className="t-body-18-s">Financial Note — Design system</h1>
          <p className="t-capture-12-r ds-muted">
            Tokens và component lấy từ Figma “Finance App” (trang Final). Màn bên phải chỉ ghép từ các component này.
          </p>
        </div>
      </header>

      <div className="ds-layout">
        <main className="ds-main">
          <Section title="Màu" note="Tên theo biến Figma, ví dụ Base/--grey/500-Main → --grey-500">
            {COLORS.map((g) => (
              <div key={g.group} className="ds-swatch-group">
                <h3 className="t-capture-12-m ds-muted">{g.group}</h3>
                <div className="ds-swatches">
                  {g.items.map(([name, hex]) => (
                    <div key={name} className="ds-swatch">
                      <span className="ds-swatch__chip" style={{ background: `var(--${name})` }} />
                      <span className="t-capture-12-m">--{name}</span>
                      <span className="t-capture-12-r ds-muted">{hex}</span>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </Section>

          <Section title="Chữ" note="Montserrat cho mọi thứ, Merriweather chỉ cho tiêu đề trang và tên tháng">
            <div className="ds-type">
              {TYPE.map(([cls, spec, sample]) => (
                <div key={cls} className="ds-type__row">
                  <span className={cls} style={{ color: "var(--text-900)" }}>
                    {sample}
                  </span>
                  <span className="t-capture-12-r ds-muted">
                    .{cls} · {spec}
                  </span>
                </div>
              ))}
            </div>
          </Section>

          <Section title="Khoảng cách & bo góc" note="sp-* và Corner-* trong Figma">
            <div className="ds-scale">
              {SPACING.map((s) => (
                <div key={s} className="ds-scale__item">
                  <span className="ds-scale__bar" style={{ width: s * 2 }} />
                  <span className="t-capture-12-r ds-muted">sp-{s}</span>
                </div>
              ))}
            </div>
            <div className="ds-corners">
              {CORNERS.map((c) => (
                <div key={c} className="ds-corner" style={{ borderRadius: c }}>
                  <span className="t-capture-12-r ds-muted">{c}</span>
                </div>
              ))}
              <div className="ds-corner" style={{ borderRadius: 999 }}>
                <span className="t-capture-12-r ds-muted">full</span>
              </div>
            </div>
          </Section>

          <Section title="Nút" note="Button và Button--Icon">
            <div className="ds-row">
              <Button variant="confirm" size="sm">
                Confirm
              </Button>
              <Button variant="outline" size="sm">
                Discard
              </Button>
              <Button variant="primary" size="lg">
                Done
              </Button>
              <div className="ds-on-dark">
                <Button variant="on-dark" icon="chart-pie">
                  Summary
                </Button>
                <IconButton icon="eye-slash" label="Ẩn số tiền" variant="on-dark" size={32} iconSize={16} />
              </div>
            </div>
            <div className="ds-row ds-row--tinted">
              <IconButton icon="calendar" label="Lịch" variant="glass" />
              <IconButton icon="user" label="Tài khoản" variant="glass" iconSize={24} />
              <IconButton icon="history" label="Lịch sử" variant="glass-strong" />
              <IconButton icon="close" label="Đóng" variant="glass-strong" />
              <IconButton icon="plus" label="Thêm" variant="soft" iconSize={20} />
              <IconButton icon="send-up" label="Gửi" variant="dark" iconSize={24} />
              <IconButton icon="wallet" label="Ví" variant="glass-80" size={48} />
              <IconButton icon="file-edit" label="Ghi chú" variant="white" size={48} />
              <DatePill label="August 07, 2026" />
            </div>
          </Section>

          <Section title="Lựa chọn" note="Chip lọc danh sách và tabs">
            <ChipDemo />
            <TabsDemo />
          </Section>

          <Section title="Dòng giao dịch" note="__trans-item: ra, vào, và dạng trong thẻ xác nhận">
            <div className="ds-card ds-narrow">
              <TransItem title="grab 42k to work" category="Food" categoryTone="food" amount="42,000" />
              <TransItem title="Transaction" category="Transport" categoryTone="transport" amount="45,000" />
              <TransItem title="Peter paid me back 45k" category="Received" categoryTone="received" amount="45,000" flow="in" />
            </div>
            <div className="ds-card ds-narrow ds-confirm">
              <TransItem title="Cơm tấm" category="Food" amount="35.000" onEdit={() => {}} />
              <TransItem title="Cafe" category="Food" amount="40.000" onEdit={() => {}} />
            </div>
          </Section>

          <Section title="Thẻ tháng" note="__inner-month: đang chọn · thường · trống · đã đánh dấu">
            <div className="ds-row">
              <MonthCard month="Jan" amount="367,000" count="3 statements" state="selected" />
              <MonthCard month="Jan" amount="367,000" count="3 statements" state="idle" />
              <MonthCard month="Jan" state="empty" />
              <MonthCard month="Jan" amount="367,000" count="3 statements" state="picked" />
            </div>
          </Section>

          <Section title="Tin nhắn" note="__chat-send">
            <div className="ds-narrow">
              <ChatBubble>Hôm nay ăn sáng cơm tấm 35k, cafe 40k, ăn trưa với team 58k/1ng</ChatBubble>
            </div>
          </Section>

          <Section title="Số tiền" note="__amount ở các cỡ">
            <div className="ds-row">
              <Amount value="42,000" />
              <Amount value="367,000" size={18} />
              <Amount value="2,647,000" size={28} />
            </div>
          </Section>
        </main>

        <aside className="ds-phone-wrap" aria-label="Màn Transaction ghép từ component">
          <p className="t-capture-12-m ds-muted">Transaction · Final (765:19666) · 402px</p>
          <TransactionScreen />
        </aside>
      </div>
    </div>
  )
}

function Section({ title, note, children }: { title: string; note?: string; children: ReactNode }) {
  return (
    <section className="ds-section">
      <div className="ds-section__head">
        <h2 className="t-body-18-s">{title}</h2>
        {note && <p className="t-capture-12-r ds-muted">{note}</p>}
      </div>
      <div className="ds-section__body">{children}</div>
    </section>
  )
}

function ChipDemo() {
  const [v, setV] = useState<"all" | "expense" | "receive">("all")
  return (
    <FilterChips
      label="Lọc"
      value={v}
      onChange={setV}
      options={[
        { value: "all", label: "All" },
        { value: "expense", label: "Expense" },
        { value: "receive", label: "Receive" },
      ]}
    />
  )
}

function TabsDemo() {
  const [v, setV] = useState<"card" | "month">("card")
  return (
    <div className="ds-narrow ds-tinted-box">
      <SegmentedTabs
        label="Kiểu xem"
        value={v}
        onChange={setV}
        options={[
          { value: "card", label: "Card", icon: "align-left" },
          { value: "month", label: "Month", icon: "squares-four" },
        ]}
      />
    </div>
  )
}

/** Figma 765:19666 rebuilt from the components above (sample data copied from the design). */
function TransactionScreen() {
  const [filter, setFilter] = useState<"all" | "expense" | "receive">("all")
  const [hidden, setHidden] = useState(false)
  const rows = [
    { title: "grab 42k to work", category: "Food", tone: "food" as const, amount: "42,000", flow: "out" as const },
    { title: "coffee 24k, sandwich 25k", category: "Food", tone: "food" as const, amount: "50,000", flow: "out" as const },
    { title: "Transaction", category: "Transport", tone: "transport" as const, amount: "-45,000", flow: "out" as const },
    {
      title: "Peter paid me back 45k for lunch yesterday",
      category: "Received",
      tone: "received" as const,
      amount: "45,000",
      flow: "in" as const,
    },
  ].filter((r) => filter === "all" || (filter === "expense" ? r.flow === "out" : r.flow === "in"))

  return (
    <div className="phone">
      <span className="phone__glow" aria-hidden="true" />
      <div className="phone__header">
        <IconButton icon="calendar" label="Lịch" variant="glass" />
        <DatePill label="August 07, 2026" />
        <IconButton icon="user" label="Tài khoản" variant="glass" iconSize={24} style={{ color: "var(--brand-500)" }} />
      </div>
      <PageTitle title="Transaction" sub="Note" />
      <div className="phone__card">
        <SpendCard
          label="Spent on 07 Aug"
          amount="547,000"
          meta="9 notes · updated 21:14"
          out="547,000"
          in="45,000"
          hidden={hidden}
          onToggleHidden={() => setHidden(!hidden)}
        />
      </div>
      <Sheet className="phone__sheet">
        <div className="phone__list-head">
          <h2 className="t-body-18-s" style={{ color: "var(--text-900)", lineHeight: 1.4 }}>
            List
          </h2>
          <FilterChips
            label="Lọc danh sách"
            value={filter}
            onChange={setFilter}
            options={[
              { value: "all", label: "All" },
              { value: "expense", label: "Expense" },
              { value: "receive", label: "Receive" },
            ]}
          />
        </div>
        <div>
          {rows.map((r) => (
            <TransItem key={r.title} title={r.title} category={r.category} categoryTone={r.tone} amount={r.amount} flow={r.flow} />
          ))}
        </div>
      </Sheet>
      <div className="phone__bottom">
        <BottomBar />
      </div>
    </div>
  )
}
