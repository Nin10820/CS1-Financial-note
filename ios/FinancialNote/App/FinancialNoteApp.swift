import SwiftData
import SwiftUI
import UIKit

@main
struct FinancialNoteApp: App {
    let container: ModelContainer

    init() {
        // Everything lives in one SwiftData store on this phone. Nothing is synced or sent anywhere.
        let inMemory = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        do {
            container = try ModelContainer(for: Schema(AppSchema.models), configurations: config)
        } catch {
            fatalError("Couldn't open the on-device store: \(error)")
        }
        LocalStore(context: container.mainContext).prepareOnLaunch()
        Self.styleNavigationTitles()
    }

    /// Page names in Bricolage Grotesque (High Fi 2). SwiftUI has no API for the navigation
    /// bar's title font, so this one setting goes through UIKit; it still scales with Dynamic Type.
    private static func styleNavigationTitles() {
        func bricolage(_ size: CGFloat, _ weight: UIFont.Weight, _ style: UIFont.TextStyle) -> UIFont {
            let d = UIFontDescriptor(fontAttributes: [
                .family: AppFont.heading,
                .traits: [UIFontDescriptor.TraitKey.weight: weight],
            ])
            return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: d, size: size))
        }
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: bricolage(32, .semibold, .largeTitle)]
        bar.titleTextAttributes = [.font: bricolage(17, .semibold, .headline)]
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
