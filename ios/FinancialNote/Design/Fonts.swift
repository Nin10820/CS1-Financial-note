import SwiftUI

/// The bundled families (OFL, from Google Fonts), matching the Figma variables:
/// - Font-body = Montserrat: all body text, labels, buttons, small numbers.
/// - Font-heading = Bricolage Grotesque: big numbers (amounts, the date), section and page titles,
///   the week strip numbers.
/// - Merriweather: only where Figma draws it — the "Good Morning, Nin" greeting and the Due month.
/// Everything scales with Dynamic Type.
///
/// Sizes come from one scale (Figma text styles). Use only these sizes — a test checks it:
/// - Montserrat: 11 (tab), 12 (Capture), 14 (Text-body 14), 16 (Text-body 16), 18 (H6 / Text-body 18)
/// - Bricolage: 12, 18, 20, 22, 24, 26, 32, 36, 40, 44
/// - Merriweather: 24
enum AppFont {
    static let main = "Montserrat"
    static let title = "Merriweather"
    static let heading = "Bricolage Grotesque"

    static func main(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(main, size: size, relativeTo: style).weight(weight)
    }

    static func title(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom(title, size: size, relativeTo: style).weight(weight)
    }

    static func heading(_ size: CGFloat, _ weight: Font.Weight = .semibold, relativeTo style: Font.TextStyle = .headline) -> Font {
        .custom(heading, size: size, relativeTo: style).weight(weight)
    }

    // MARK: - Named styles (Figma names)

    /// Capture/12px — small grey text, dates under titles, counts.
    static func capture(_ weight: Font.Weight = .regular) -> Font { main(12, weight, relativeTo: .caption) }
    /// Text-body/14px — rows, buttons, form labels.
    static func body(_ weight: Font.Weight = .regular) -> Font { main(14, weight) }
    /// Text-body/16px — bigger body text, bill names, card headers.
    static func bodyLarge(_ weight: Font.Weight = .regular) -> Font { main(16, weight) }
    /// Heading/H6 18px.
    static func h6(_ weight: Font.Weight = .semibold) -> Font { main(18, weight, relativeTo: .headline) }
    /// Section titles: "Recent", "Shortcuts", "History".
    static var section: Font { heading(22, .medium, relativeTo: .title2) }
    /// Page titles and the month: "Oct 2026", "Add bill" lead.
    static var page: Font { heading(24, .medium, relativeTo: .title) }
    /// The greeting, "Good Morning, Nin" (Merriweather Bold 24).
    static var greeting: Font { title(24, .bold) }

    /// A big amount and its "đ", both Bricolage like Figma (đ lighter and smaller).
    static func amount(_ size: CGFloat) -> Font { heading(size, size >= 40 ? .medium : .semibold, relativeTo: .largeTitle) }
    static func currency(for amountSize: CGFloat) -> Font { heading(amountSize * 0.8, .regular, relativeTo: .title) }
}
