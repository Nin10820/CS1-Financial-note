import SwiftData
import SwiftUI

/// Milestone 1 check screen: fonts, colours, the on-device data and the note reader.
/// The real tab bar and Today screen replace it in milestone 2.
struct FoundationView: View {
    @Environment(\.modelContext) private var context
    @Query private var entries: [Entry]
    @Query private var bills: [Bill]
    @Query private var assets: [Asset]
    @Query private var care: [CareGift]
    @Query private var notes: [DayNote]
    @State private var note = "cơm tấm 35k, cafe 40k · cash"

    private var drafts: [Draft] { NoteParser.parse(note, day: Day.today()) }

    var body: some View {
        NavigationStack {
            List {
                Section("Type") {
                    Text(Day.greeting()).font(AppFont.title(28, .bold, relativeTo: .largeTitle))
                    Text("Today").font(AppFont.heading(24, .semibold, relativeTo: .title2))
                    Text("Cơm tấm 35,000 · Montserrat body").font(AppFont.main(16, .medium))
                }

                Section("Colours") {
                    HStack(spacing: Space.s8) {
                        ForEach(Array(swatches.enumerated()), id: \.offset) { _, c in
                            RoundedRectangle(cornerRadius: Corner.c8).fill(c).frame(height: 36)
                        }
                    }
                    .accessibilityLabel("Brand, category and surface colours")
                    VStack(alignment: .leading, spacing: Space.s4) {
                        Text("Spent today").font(AppFont.main(14, .medium)).foregroundStyle(.white.opacity(0.8))
                        Text("\(Money.format(spentToday)) đ").font(AppFont.main(28, .bold)).foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Space.s16)
                    .background(Tokens.cardGradient, in: .rect(cornerRadius: Corner.c14))
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section {
                    LabeledContent("Entries", value: "\(entries.count)")
                    LabeledContent("Day notes", value: "\(notes.count)")
                    LabeledContent("Bills", value: "\(bills.count)")
                    LabeledContent("Assets", value: "\(assets.count)")
                    LabeledContent("Taken care of", value: "\(care.count)")
                } header: {
                    Text("On this phone")
                } footer: {
                    Text("Sample data loaded on first launch. Everything stays on this phone.")
                }
                .font(AppFont.main(15))

                Section("Note reader") {
                    TextField("What did you spend?", text: $note, axis: .vertical)
                        .font(AppFont.main(16))
                    ForEach(drafts) { d in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(d.title).font(AppFont.main(15, .semibold))
                                Text(d.category.rawValue).font(AppFont.main(12, .medium))
                                    .foregroundStyle(Tokens.category(d.category))
                            }
                            Spacer()
                            Text(d.amount.map { (d.flow == .in ? "+" : "−") + Money.format($0) } ?? "—")
                                .font(AppFont.main(15, .semibold))
                                .foregroundStyle(d.flow == .in ? Tokens.brand700 : Tokens.text900)
                        }
                    }
                }
            }
            .navigationTitle("Financial Note")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Load sample again", systemImage: "arrow.clockwise") {
                            LocalStore(context: context).loadSample()
                        }
                        Button("Remove sample", systemImage: "trash") {
                            LocalStore(context: context).clearSample()
                        }
                    } label: {
                        Label("Sample data", systemImage: "ellipsis")
                    }
                }
            }
        }
        .tint(Tokens.brand500)
    }

    private var spentToday: Int {
        let today = Day.today()
        return entries.filter { $0.date == today && $0.flow == .out }.reduce(0) { $0 + $1.amount }
    }

    private var swatches: [Color] {
        [Tokens.brand500, Tokens.brand700, Tokens.categoryFood, Tokens.categoryTransport,
         Tokens.categoryReceived, Tokens.bg4, Tokens.text900]
    }
}

#Preview {
    FoundationView()
        .modelContainer(for: AppSchema.models, inMemory: true)
}
