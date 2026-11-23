import { useState, type ReactNode } from "react"
import { Amount, Button, ChatBubble, IconButton, LogoMark, MonthCard, Switch } from "../components/ui"
import { AddingLead, AmountPad, AssetTile, HistoryLink, JoinedCard, Legend, ListCard, ListRow, Pie, PieCard, QuickPickCard, Segmented, StatCard, TickMark, Tile } from "../components/kit"
import { Icon } from "../components/Icon"
import { applyAppearance } from "../lib/theme"
import "./design-system.css"

/*
 * #/design-system — the web app's design system as it is now: the tokens in styles/tokens.css
 * (the same names and values as ios/FinancialNote/Design/Tokens.swift) and the shared parts in
 * components/kit.tsx and components/ui.tsx. Change a value in Figma first, then tokens.css, then
 * Tokens.swift; every screen follows.
 */

const swatch = (names: string[]) => names.map((n) => ({ name: n, v: `var(--${n})` }))
const COLOURS: { group: string; items: { name: string; v: string }[] }[] = [
  { group: "Lớp nền (ios/DESIGN.md §1)", items: swatch(["canvas", "card", "bg-4", "segment-on", "keypad-tray", "keypad-key", "keypad-delete"]) },
  { group: "Brand", items: swatch(["brand-50", "brand-100", "brand-200", "brand-300", "brand-400", "brand-500", "brand-600", "brand-700", "brand-800", "brand-900", "action"]) },
  { group: "Chữ", items: swatch(["text-900", "text-700", "grey-400", "grey-300", "on-dark", "on-dark-muted"]) },
  { group: "Viền", items: swatch(["bd-0", "bd-1", "bd-2"]) },
  { group: "Ý nghĩa", items: swatch(["success", "today-red", "danger", "flow-out", "warn-ink", "category-food", "category-transport", "category-received"]) },
]
const PALETTES: { group: string; items: { name: string; v: string }[] }[] = [
  { group: "Ô bill", items: swatch(["bill-house", "bill-drop", "bill-gas-pump", "bill-lightning", "bill-phone", "bill-student", "bill-monitor", "bill-bell"]) },
  { group: "Nhóm tài sản", items: swatch(["asset-available", "asset-growing", "asset-aside", "asset-owed"]) },
  { group: "Ô tài sản", items: swatch(["asset-gold", "asset-fund", "asset-bank", "asset-cash", "asset-lent", "asset-usd", "asset-stock", "asset-coin", "asset-piggy"]) },
  { group: "Chi tiêu (Analytics)", items: swatch(["kind-housing", "kind-health", "kind-education", "kind-technology", "kind-hobbies", "kind-shopping", "kind-travel", "kind-social", "kind-subscriptions", "need-worthwhile", "need-optional"]) },
  { group: "Biểu đồ & nợ", items: swatch(["chart-orange", "chart-blue", "chart-gold", "chart-teal", "debt-1", "debt-2", "debt-3", "debt-4", "debt-5", "debt-6"]) },
  { group: "Người thân & bản thân", items: swatch(["life-family", "life-self", "loan-received", "self-learning", "self-moving", "self-health"]) },
]
const TYPE = [
  [44, "Ngày và tháng ở đầu trang", "heading"],
  [36, "Số tiền lớn", "heading"],
  [28, "Số tiền trên thẻ nhỏ", "heading"],
  [24, "Tiêu đề trang, lời chào", "heading"],
  [22, "Tiêu đề mục: Recent, Shortcuts", "heading"],
  [18, "Tiêu đề trên thẻ: Assets, Family loans", "heading"],
  [16, "Chữ thân lớn, số tiền trên dòng", "main"],
  [15, "Tên dòng trong danh sách", "main"],
  [14, "Chữ thân: dòng, nút, nhãn", "main"],
  [13, "Chú thích, chip", "main"],
  [12, "Capture: ngày, số đếm, gợi ý", "main"],
  [11, "Nhãn tab, chú thích nhỏ", "main"],
] as const

export default function DesignSystem() {
  const [dark, setDark] = useState(document.documentElement.dataset.theme === "dark")
  const [seg, setSeg] = useState<"overview" | "total" | "debt">("overview")
  const [picked, setPicked] = useState<string | null>(null)
  const [on, setOn] = useState(true)
  return (
    <div className="ds">
      <header className="ds-head">
        <div>
          <h1>Financial Note — Design system</h1>
          <p className="ds-muted">styles/tokens.css · components/kit.tsx · cùng tên và giá trị với ios/FinancialNote/Design/Tokens.swift</p>
        </div>
        <label className="ds-theme">
          Tối
          <Switch
            label="Dark mode"
            checked={dark}
            onChange={(v) => {
              setDark(v)
              applyAppearance(v ? "dark" : "light")
            }}
          />
        </label>
      </header>

      <main className="ds-main">
        <Section title="Màu" note="Mỗi màu là một biến trong tokens.css, có bản sáng và bản tối.">
          {COLOURS.map((g) => (
            <Swatches key={g.group} title={g.group} items={g.items} />
          ))}
        </Section>

        <Section title="Bảng màu" note="Chọn từ các bảng này; màn hình không tự đặt màu mới.">
          {PALETTES.map((g) => (
            <Swatches key={g.group} title={g.group} items={g.items} />
          ))}
        </Section>

        <Section title="Chữ" note="Một thang cỡ chữ --fs-*, như Fonts.swift. Bricolage cho số và tiêu đề, Montserrat cho chữ thân.">
          <div className="ds-type">
            {TYPE.map(([size, use, font]) => (
              <div key={size} className="ds-type__row">
                <code>--fs-{size}</code>
                <span style={{ fontSize: `var(--fs-${size})`, fontFamily: font === "heading" ? "var(--font-heading)" : "var(--font-main)", color: "var(--text-900)", fontWeight: 500 }}>{use}</span>
              </div>
            ))}
          </div>
        </Section>

        <Section title="Khoảng cách & bo góc" note="--sp-* và --corner-*">
          <div className="ds-scale">
            {[4, 6, 8, 12, 16, 20, 24, 32].map((n) => (
              <div key={n} className="ds-scale__item">
                <span className="ds-scale__bar" style={{ width: `var(--sp-${n})` }} />
                <code>--sp-{n}</code>
              </div>
            ))}
          </div>
          <div className="ds-corners">
            {[8, 12, 14, 16, 20].map((n) => (
              <div key={n} className="ds-corner" style={{ borderRadius: `var(--corner-${n})` }}>
                <code>--corner-{n}</code>
              </div>
            ))}
          </div>
        </Section>

        <Section title="Thẻ lớn & thẻ số liệu" note="JoinedCard + StatCard + PieCard (Finance › Total Asset)">
          <div className="ds-narrow">
            <JoinedCard
              top={
                <StatCard
                  label="Total asset"
                  amount={287_804_500}
                  stats={[
                    { label: "Put in", value: "264M" },
                    { label: "Gain", value: "+23.9M", gain: true },
                    { label: "Change", value: "+9.0%", gain: true },
                  ]}
                />
              }
              bottom={
                <PieCard
                  title="Where your money is"
                  chart={
                    <Pie
                      picked={picked}
                      slices={[
                        { id: "a", value: 24, color: "var(--asset-available)" },
                        { id: "g", value: 250, color: "var(--asset-growing)" },
                        { id: "s", value: 13, color: "var(--asset-aside)" },
                        { id: "o", value: 12, color: "var(--asset-owed)" },
                      ]}
                    >
                      <b style={{ color: "var(--asset-growing)" }}>84%</b>
                      <small>growing</small>
                    </Pie>
                  }
                  legend={[
                    ["a", "Available", "var(--asset-available)", "8%"],
                    ["g", "Growing", "var(--asset-growing)", "84%"],
                    ["s", "Set aside", "var(--asset-aside)", "4%"],
                    ["o", "Owed", "var(--asset-owed)", "4%"],
                  ].map(([id, name, color, p]) => (
                    <Legend key={id} color={color} name={name} pct={p} on={picked === id} onClick={() => setPicked(picked === id ? null : id)} />
                  ))}
                />
              }
            />
          </div>
        </Section>

        <Section title="Dòng danh sách" note="ListRow: ô tròn 40, tên trên dòng xám, số tiền bên phải (ios/DESIGN.md §6b)">
          <div className="ds-narrow">
            <ListCard>
              <ListRow tile={<AssetTile icon="gold" />} title="Vàng" sub="10 chỉ · in 121M · 23 Nov" amount="129,844,994đ" amountSub="+8.5M · +7%" amountSubTone="gain" />
              <ListRow tile={<Tile bg="var(--bill-house)" icon="house" />} title="Rent" sub="Nov 5" amount="2,500,000đ" trailing={<span className="due2-tick"><TickMark on={on} /></span>} onClick={() => setOn(!on)} done={on} />
              <ListRow tile={<Tile bg="var(--debt-1)" mark="M" />} title="Mom" sub="got 40M · 6% a year" amount="41,093,151đ" amountSub="+1.1M interest" />
            </ListCard>
            <HistoryLink sub="17 changes · last 20 Nov" onClick={() => {}} />
          </div>
        </Section>

        <Section title="Lựa chọn" note="Segmented (iOS segmented control) và thẻ tháng">
          <div className="ds-narrow">
            <Segmented
              label="Finance view"
              value={seg}
              onChange={setSeg}
              options={[
                { value: "overview", label: "Overview" },
                { value: "total", label: "Total Asset" },
                { value: "debt", label: "Debt" },
              ]}
            />
            <div className="ds-row">
              <MonthCard month="Nov" amount="4,715K" count="6 bills" state="selected" onClick={() => {}} />
              <MonthCard month="Dec" amount="4,360K" count="5 bills" state="idle" onClick={() => {}} />
              <MonthCard month="Jan" amount="—" count="0 bills" state="empty" onClick={() => {}} />
            </div>
          </div>
        </Section>

        <Section title="Chọn nhanh" note="AddingLead + QuickPickCard (New bill, New asset)">
          <div className="ds-narrow ds-canvas">
            <AddingLead label="kind of" chosen={false} />
            <QuickPickCard
              title="What kind is this?"
              options={[
                { id: "recurring", title: "Recurring bill", hint: "Electricity, water, internet — every month" },
                { id: "installment", title: "Installment", hint: "Fixed parts until it's paid off" },
              ]}
              placeholder="e.g. Internet 250k every month on the 5th"
              onPick={() => {}}
              onSay={() => {}}
            />
          </div>
        </Section>

        <Section title="Bàn phím số" note="AmountPad: khay, phím và phím ⌫ dùng --keypad-*">
          <div className="ds-narrow">
            <AmountPad onChange={() => {}} onDone={() => {}} />
          </div>
        </Section>

        <Section title="Nút & ký hiệu" note="Button, IconButton, Tile, TickMark, Amount, ChatBubble">
          <div className="ds-row">
            <Button variant="primary">Save</Button>
            <Button variant="outline">Not yet</Button>
            <IconButton icon="user" label="Profile" variant="glass" size={44} />
            <IconButton icon="close" label="Close" variant="glass-strong" />
            <span className="k-btn">
              <Icon name="plus" size={16} /> Add money
            </span>
            <span className="k-btn k-btn--soft">Take out</span>
          </div>
          <div className="ds-row">
            <Tile bg="var(--asset-gold)" mark="Au" />
            <Tile bg="var(--asset-coin)" mark="₿" />
            <Tile bg="var(--self-learning)" icon="graduation-cap" />
            <TickMark on={false} />
            <TickMark on />
            <LogoMark size={28} />
            <Amount value="1,250,000" />
          </div>
          <ChatBubble>Coffee 25k, grab 42k</ChatBubble>
        </Section>
      </main>
    </div>
  )
}

function Section({ title, note, children }: { title: string; note?: string; children: ReactNode }) {
  return (
    <section className="ds-section">
      <div className="ds-section__head">
        <h2>{title}</h2>
        {note && <p className="ds-muted">{note}</p>}
      </div>
      <div className="ds-section__body">{children}</div>
    </section>
  )
}

function Swatches({ title, items }: { title: string; items: { name: string; v: string }[] }) {
  return (
    <div className="ds-swatch-group">
      <h3>{title}</h3>
      <div className="ds-swatches">
        {items.map((c) => (
          <div key={c.name} className="ds-swatch">
            <span className="ds-swatch__chip" style={{ background: c.v }} />
            <code>--{c.name}</code>
          </div>
        ))}
      </div>
    </div>
  )
}
