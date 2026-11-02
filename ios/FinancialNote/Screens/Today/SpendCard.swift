import SwiftUI

/// Which lines Recent shows: all of them, only money out, or only money in.
enum FlowFilter: Hashable { case all, out, `in` }

/// The dark "Total Amount" card (Figma __card-transaction 1116:35317): what's left after money
/// in and out (in − out), the eye to hide amounts, "9 notes • updated 21:14", then a filter
/// row — All, money out (−), money in (+) — that picks what Recent lists.
struct SpendCard: View {
    var label: String = "Total Amount"
    var out: Int
    var incoming: Int
    var notes: Int
    var updated: String
    @Binding var hidden: Bool
    @Binding var filter: FlowFilter
    @Namespace private var pill
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var net: Int { incoming - out }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(AppFont.body(.medium))
                .foregroundStyle(.white.opacity(0.8))
            HStack(alignment: .center) {
                HStack(alignment: .firstTextBaseline, spacing: Space.s4) {
                    Text(hidden ? "••••••" : (net < 0 ? "-" : "") + Money.format(abs(net)))
                        .font(AppFont.heading(40, .medium, relativeTo: .largeTitle))
                        .monospacedDigit()
                        // White fading to 24% at the foot of the digits, as in Figma.
                        .foregroundStyle(LinearGradient(
                            stops: [.init(color: .white, location: 0.3), .init(color: .white.opacity(0.24), location: 1)],
                            startPoint: .top, endPoint: .bottom))
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("đ")
                        .font(AppFont.heading(28, .regular, relativeTo: .title))
                        .foregroundStyle(.white.opacity(0.48))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(hidden ? "\(label), hidden" : "\(label), \(net < 0 ? "minus " : "")\(Money.format(abs(net))) dong")
                Spacer(minLength: Space.s8)
                Button {
                    hidden.toggle()
                } label: {
                    Group {
                        if hidden {
                            Image(systemName: "eye").font(.system(size: 14, weight: .semibold))
                        } else {
                            AppIcon(.eyeSlash, size: 16)
                        }
                    }
                    .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.08), in: .circle)
                        .frame(width: 44, height: 44)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hidden ? "Show amounts" : "Hide amounts")
            }
            HStack(spacing: Space.s8) {
                Text("\(notes) \(notes == 1 ? "note" : "notes")")
                Circle().fill(.white.opacity(0.64)).frame(width: 4, height: 4).accessibilityHidden(true)
                Text("updated \(updated)")
            }
            .font(AppFont.capture())
            .foregroundStyle(.white.opacity(0.72))
            .accessibilityElement(children: .combine)

            // [All]  [− out | + in] — All sits in its own box (Figma 1124:37861).
            HStack(spacing: Space.s4) {
                chip(.all) {
                    Text("All").font(AppFont.heading(16, .medium, relativeTo: .body))
                }
                .frame(width: 43)
                .padding(Space.s4)
                .frame(minHeight: 44)
                .background(.black.opacity(0.36), in: .rect(cornerRadius: Corner.c14))
                .innerEdge(cornerRadius: Corner.c14, top: 0.14, bottom: 0.06)

                HStack(spacing: 0) {
                    chip(.out) { amount(out, sign: .minusCircle, tint: Color(hex: 0xE5562A)) }
                    chip(.in) { amount(incoming, sign: .plusCircle, tint: Tokens.brand400) }
                }
                .padding(Space.s4)
                .frame(minHeight: 44)
                .background(.black.opacity(0.36), in: .rect(cornerRadius: Corner.c14))
                .innerEdge(cornerRadius: Corner.c14, top: 0.14, bottom: 0.06)
            }
            .padding(.top, Space.s12)
        }
        .padding(.top, 20.5)
        .padding(.horizontal, 16.5)
        .padding(.bottom, 12.5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: Corner.c24)
        .shadow(color: .black.opacity(0.16), radius: 9, y: 6)
    }

    private func chip<Label: View>(_ f: FlowFilter, @ViewBuilder label: () -> Label) -> some View {
        Button {
            // Slides like the system segmented control: a spring, not a jump.
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) { filter = f }
        } label: {
            label()
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 36)
                .padding(.horizontal, f == .all ? 0 : Space.s8)
                .background {
                    if filter == f {
                        RoundedRectangle(cornerRadius: Corner.c12, style: .continuous)
                            .fill(.white.opacity(0.16))
                            .innerEdge(cornerRadius: Corner.c12, top: 0.35, bottom: 0.12)
                            .matchedGeometryEffect(id: "pill", in: pill)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(f == .all ? "All lines" : f == .out
            ? "Money out, \(hidden ? "hidden" : "\(Money.format(out)) dong")"
            : "Money in, \(hidden ? "hidden" : "\(Money.format(incoming)) dong")")
        .accessibilityAddTraits(filter == f ? .isSelected : [])
    }

    /// From a million up, thousands with K ("1,900K"), so the chips don't fill with zeros.
    static func short(_ v: Int) -> String {
        v >= 1_000_000 ? "\(Money.format(v / 1000))K" : Money.format(v)
    }

    private func amount(_ v: Int, sign: Icon, tint: Color) -> some View {
        HStack(spacing: Space.s6) {
            // Coloured disc with a white − / + (the icon's sign is cut out, white shows through).
            AppIcon(sign, size: 18)
                .foregroundStyle(tint)
                .background(Circle().fill(.white).padding(4))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(hidden ? "••••" : Self.short(v))
                    .font(AppFont.heading(16, .medium, relativeTo: .body))
                    .monospacedDigit()
                Text("đ")
                    .font(AppFont.heading(14, .regular, relativeTo: .body))
                    .foregroundStyle(.white.opacity(0.64))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }
}
