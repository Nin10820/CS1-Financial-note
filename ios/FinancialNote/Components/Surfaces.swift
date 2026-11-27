import SwiftUI

// The layers every screen and sheet is made of. The rules are in ios/DESIGN.md.

extension Tokens {
    /// Layer 0: under everything — pages, sheets, lists and forms.
    static let canvas = bgGrouped
    /// Layer 1: cards, list rows and form rows on the canvas.
    static let card = bgWhite
}

extension View {
    /// Every sheet and full-screen cover: the app canvas behind it instead of the system grey.
    func sheetSurface() -> some View {
        presentationBackground(Tokens.canvas)
    }

    /// A List or Form: the app canvas behind it, so it matches the rest of the app. Give each
    /// Section (or ForEach of rows) `.listRowBackground(Tokens.card)` too.
    func appListSurface() -> some View {
        scrollContentBackground(.hidden)
            .background(Tokens.canvas)
    }
}
