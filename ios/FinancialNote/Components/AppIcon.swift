import SwiftUI

/// Icons from the Figma file (Hugeicons Pro and Phosphor, both licensed by the owner), kept as
/// vector template images in Assets › Icons so they take the colour around them and work in
/// dark mode. System controls (close, chevrons in lists, share) stay SF Symbols.
enum Icon: String {
    case today = "icon-today"            // Hugeicons calendar-01, fill
    case due = "icon-due"                // Hugeicons bill, solid
    case finance = "icon-finance"        // Hugeicons chart-rose, fill
    case ai = "icon-ai"                  // the app's AI sparkle
    case plus = "icon-plus"              // Phosphor Plus, bold
    case template = "icon-template"      // Hugeicons file-01, stroke
    case scan = "icon-scan"              // Hugeicons scan, stroke
    case mic = "icon-mic"                // Phosphor Microphone
    case trash = "icon-trash"            // Phosphor Trash
    case pencil = "icon-pencil"          // Phosphor PencilSimple
    case minusCircle = "icon-minus-circle"   // Phosphor MinusCircle, fill
    case plusCircle = "icon-plus-circle"     // Phosphor PlusCircle, fill
    case arrowUpRight = "icon-arrow-up-right"     // Phosphor ArrowUpRight, bold
    case arrowDownRight = "icon-arrow-down-right" // Phosphor ArrowDownRight, bold
    case caretUpDown = "icon-caret-up-down"  // Phosphor CaretUpDown
    case eyeSlash = "icon-eye-slash"         // Phosphor EyeSlash
    case user = "icon-user"                  // Phosphor User
}

/// One icon at its Figma size, growing with Dynamic Type like the text beside it.
/// Decorative by default; give the surrounding button its label.
struct AppIcon: View {
    var icon: Icon
    var size: CGFloat = 20
    var relativeTo: Font.TextStyle = .body
    @ScaledMetric private var scale: CGFloat = 1

    init(_ icon: Icon, size: CGFloat = 20, relativeTo: Font.TextStyle = .body) {
        self.icon = icon
        self.size = size
        self.relativeTo = relativeTo
        _scale = ScaledMetric(wrappedValue: 1, relativeTo: relativeTo)
    }

    var body: some View {
        Image(icon.rawValue)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size * min(scale, 1.6), height: size * min(scale, 1.6))
            .accessibilityHidden(true)
    }
}
