import SwiftUI

/// The three bundled families (OFL, from Google Fonts). All scale with Dynamic Type.
/// - Montserrat: body text, numbers, buttons.
/// - Merriweather: greeting and big titles.
/// - Bricolage Grotesque: page names and the week strip.
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
}
