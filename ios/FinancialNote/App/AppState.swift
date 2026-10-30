import Foundation
import Observation

/// What the screens share: the open tab, the picked day, and what is open on top.
@Observable
final class AppState {
    /// The four tabs of Navigation Bar (Figma 2026-10-30).
    enum TabID: Hashable { case today, due, finance, ai }

    var tab: TabID = .today
    /// Today's date, refreshed when the clock passes midnight.
    var today = Day.today()
    /// The day Today shows, "YYYY-MM-DD".
    var day = Day.today()
    var range: DayRange = .day
    /// The month Due shows, "YYYY-MM".
    var dueMonth = Month.of(Day.today())
    /// Amounts shown as "••••••". Starts hidden when Profile › Display says so.
    var hidden = false
    /// Finance totals hidden; starts hidden when Profile › Display says so for assets or for all amounts.
    var assetsHidden = false
    /// Something for the AI tab to start with (a day's note, a notice). Taken once by the tab.
    var assistant: AssistantSeed?
    var dayNoteOpen = false
    /// The + menu: Talk With AI, Template, Scan.
    var actionsOpen = false
    /// A blank entry sheet with a composer (Template).
    var templateOpen = false
    /// What a scanned QR code filled in, for the Template sheet.
    var templatePrefill: EntryEdit?
    var scanOpen = false
    var profileOpen = false
    /// The AI tab has a conversation on screen: the tab bar steps aside for its composer.
    var aiChatting = false

    /// Called when the calendar day changes: if Today was showing today, it moves along.
    func dayChanged() {
        let old = today
        today = Day.today()
        if day == old { day = today }
    }

    /// Goes to the AI tab on the picked day, optionally with a day's note already read.
    func openAssistant(date: String? = nil, noteLines: [String]? = nil, notice: String? = nil) {
        assistant = AssistantSeed(date: date ?? day, noteLines: noteLines, notice: notice)
        actionsOpen = false
        tab = .ai
    }
}

/// The span the card and list on Today cover.
enum DayRange: String, CaseIterable, Identifiable {
    case day, week, month
    var id: String { rawValue }

    var label: String {
        switch self {
        case .day: "Daily"
        case .week: "Weekly"
        case .month: "Monthly"
        }
    }

    /// First and last day covered, as ISO strings (compared as text, like the web app).
    func bounds(for day: String) -> (from: String, to: String) {
        switch self {
        case .day: (day, day)
        case .week: (Day.monday(of: day), Day.addDays(Day.monday(of: day), 6))
        case .month: ("\(Month.of(day))-01", "\(Month.of(day))-31")
        }
    }
}

struct AssistantSeed: Identifiable {
    let id = UUID()
    var date: String
    /// Lines from Notes of the day, read as soon as the Assistant opens.
    var noteLines: [String]?
    /// A plain message to show first ("… comes later").
    var notice: String?
}
