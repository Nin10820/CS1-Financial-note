import SwiftUI
import UIKit

// Colours from `src/styles/tokens.css` (itself from the Figma variables). Each one has a dark-mode
// variant: greys and surfaces flip, brand and category colours lift a step so they read on dark.
// Change a value in Figma first, then in tokens.css, then here.

// `nonisolated`: SwiftUI resolves colours on its render thread, not only on the main actor.
nonisolated extension Color {
    /// A colour that follows light / dark mode.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { @Sendable traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    init(hex: UInt32) { self.init(uiColor: UIColor(hex: hex)) }
}

nonisolated extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
    }
}

/// Named design tokens. Use these instead of hex values in views.
enum Tokens {
    // Brand (green)
    static let brand25 = Color(light: 0xFDFEFB, dark: 0x0F1A09)
    static let brand50 = Color(light: 0xF2FAEB, dark: 0x142410)
    static let brand100 = Color(light: 0xE2F4D3, dark: 0x1C3314)
    static let brand200 = Color(light: 0xC8E9AD, dark: 0x2C481F)
    static let brand300 = Color(light: 0xA4DA7C, dark: 0x3B6922)
    static let brand400 = Color(light: 0x83C853, dark: 0x4C8A26)
    static let brand500 = Color(light: 0x5FA82F, dark: 0x6DB83B)
    static let brand600 = Color(light: 0x4C8A26, dark: 0x83C853)
    static let brand700 = Color(light: 0x3B6922, dark: 0x9CD472)
    static let brand800 = Color(light: 0x2C481F, dark: 0xC8E9AD)

    // Greys and text
    static let text900 = Color(light: 0x0D121C, dark: 0xF3F4F6)
    static let text700 = Color(light: 0x364152, dark: 0xCDD5DF)
    static let grey400 = Color(light: 0x697586, dark: 0x9AA4B2)
    static let grey300 = Color(light: 0x9AA4B2, dark: 0x697586)
    static let textDisabled = Color(light: 0x9AA4B2, dark: 0x697586)

    // Surfaces
    static let bg1 = Color(light: 0xFCFCFD, dark: 0x1A1F29) // sheets
    static let bg2 = Color(light: 0xF9FAFB, dark: 0x141922) // list sheet
    static let bg3 = Color(light: 0xF3F4F6, dark: 0x0D121C) // app canvas
    static let bg4 = Color(light: 0xEAECF0, dark: 0x202939) // idle chips
    static let bgWhite = Color(light: 0xFFFFFF, dark: 0x1A1F29)

    // Borders
    static let bd0 = Color(light: 0xEEF2F6, dark: 0x202939) // row dividers
    static let bd1 = Color(light: 0xE3E8EF, dark: 0x2A3343)
    static let bd2 = Color(light: 0xCDD5DF, dark: 0x364152)

    // Category labels on entry rows
    static let categoryFood = Color(light: 0xC85A34, dark: 0xE5875F)
    static let categoryTransport = Color(light: 0x1570EF, dark: 0x5B9BF5)
    static let categoryReceived = Color(light: 0x4A1FB8, dark: 0x9B7BF0)

    // Secondary (peach)
    static let secondary25 = Color(light: 0xFCF6F0, dark: 0x2A1B12)
    static let secondary100 = Color(light: 0xF8EADC, dark: 0x3D2618) // outgoing icon tile
    static let secondary300 = Color(light: 0xE5B28C, dark: 0x8A5636)
    static let secondary500 = Color(light: 0xC85A34, dark: 0xE5875F) // outgoing arrow

    // Accents used by Due
    static let blue100 = Color(light: 0xDFF2FF, dark: 0x0B2C40)
    static let blue700 = Color(light: 0x0085CA, dark: 0x4FB8F0)
    static let teal200 = Color(light: 0xCCFBEF, dark: 0x0E3B33)
    static let teal500 = Color(light: 0x15B79E, dark: 0x2ED3B7)
    static let lime500 = Color(light: 0x669F2A, dark: 0x85C443)

    /// Dark green hero card (Spent today, Remaining, Taken care of): light from the top-left corner.
    /// Same in both modes — it is already dark.
    static let cardGradient = RadialGradient(
        colors: [Color(hex: 0x2C4D17), Color(hex: 0x142A0B), Color(hex: 0x0D1F07)],
        center: .topLeading, startRadius: 0, endRadius: 420)

    static func category(_ c: Category) -> Color {
        switch c {
        case .food: categoryFood
        case .transport: categoryTransport
        case .received: categoryReceived
        default: grey400
        }
    }

    static func assetKind(_ k: AssetKind) -> Color {
        switch k {
        case .available: brand600
        case .growing: Color(light: 0xEAAA08, dark: 0xFAC515)
        case .aside: Color(light: 0x5D65EF, dark: 0x8B91F5)
        case .owed: Color(light: 0xE5562A, dark: 0xF07A55)
        }
    }

    /// Solid bill tile colours from the Figma bill list.
    static func billTile(_ icon: BillIcon) -> Color {
        switch icon {
        case .house: Color(hex: 0x3538CD)
        case .drop: Color(hex: 0x1BACEE)
        case .gasPump: Color(hex: 0x15B79E)
        case .lightning: Color(hex: 0xFF4405)
        case .phone: Color(hex: 0x5FA82F)
        case .student: Color(hex: 0x1570EF)
        case .monitor: Color(hex: 0xC85A34)
        case .bell: Color(hex: 0x364152)
        }
    }

    /// Soft tile (background, ink) from the Figma statement list.
    static func billTileSoft(_ icon: BillIcon) -> (bg: Color, ink: Color) {
        switch icon {
        case .house: (Color(light: 0xE0EAFF, dark: 0x1E2250), Color(light: 0x3538CD, dark: 0x8B91F5))
        case .drop: (Color(light: 0xDFF2FF, dark: 0x0B2C40), Color(light: 0x0085CA, dark: 0x4FB8F0))
        case .gasPump: (Color(light: 0xCCFBEF, dark: 0x0E3B33), Color(light: 0x107569, dark: 0x2ED3B7))
        case .lightning: (Color(light: 0xFFE6D5, dark: 0x4A1E0A), Color(light: 0xC4320A, dark: 0xFF8A5C))
        case .phone: (Color(light: 0xE2F4D3, dark: 0x1C3314), Color(light: 0x3B6922, dark: 0x9CD472))
        case .student: (Color(light: 0xD1E9FF, dark: 0x0F2A4D), Color(light: 0x1570EF, dark: 0x5B9BF5))
        case .monitor: (Color(light: 0xF8EADC, dark: 0x3D2618), Color(light: 0xC85A34, dark: 0xE5875F))
        case .bell: (Color(light: 0xEAECF0, dark: 0x202939), Color(light: 0x364152, dark: 0xCDD5DF))
        }
    }

    static func assetTile(_ icon: AssetIcon) -> Color {
        switch icon {
        case .gold: Color(hex: 0xF4B400)
        case .fund: Color(hex: 0x1570EF)
        case .bank: Color(hex: 0x6927DA)
        case .cash: Color(hex: 0x4C8A26)
        case .lent: Color(hex: 0xE5562A)
        }
    }
}

/// Spacing (sp-*) and corners (Corner-*) from tokens.css.
enum Space {
    static let s2: CGFloat = 2, s4: CGFloat = 4, s6: CGFloat = 6, s8: CGFloat = 8, s12: CGFloat = 12
    static let s16: CGFloat = 16, s20: CGFloat = 20, s24: CGFloat = 24, s32: CGFloat = 32
}

enum Corner {
    static let c4: CGFloat = 4, c6: CGFloat = 6, c8: CGFloat = 8, c12: CGFloat = 12, c14: CGFloat = 14
    static let c16: CGFloat = 16, c20: CGFloat = 20
}
