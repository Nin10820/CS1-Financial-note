import SwiftData
import SwiftUI
import UIKit

@main
struct FinancialNoteApp: App {
    /// Everything lives in SwiftData stores on this phone (Nin, Empty, Example; Profile › Data).
    /// Nothing is synced or sent anywhere.
    @State private var sets = DataSets.shared
    @Environment(\.scenePhase) private var scenePhase

    private var container: ModelContainer { sets.container }

    init() {
        let container = DataSets.shared.container
        #if DEBUG
        // For trying the app: `-reloadSample` puts in a fresh copy of the made-up data.
        if ProcessInfo.processInfo.arguments.contains("-reloadSample") {
            LocalStore(context: container.mainContext).loadSample()
        }
        // `-topUpSample` adds the newer sample bills and "paid from" without reloading anything.
        if ProcessInfo.processInfo.arguments.contains("-topUpSample") {
            LocalStore(context: container.mainContext).topUpSample()
        }
        #endif
        Self.styleNavigationTitles()
        // System alerts draw their main button (e.g. Save) in the UIKit tint, which is blue
        // unless set: make it the app's green.
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor(Tokens.brand500)
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
                // Another data set is another app state: the screens start over on it.
                .id(sets.current)
                // The backup folder (Profile › Backup & restore) follows every saved change to
                // Nin's own data (never the Empty or Example sets)…
                .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave).receive(on: RunLoop.main)) { _ in
                    if sets.current == .nin { BackupFolder.shared.changed(container: container) }
                }
        }
        .modelContainer(container)
        // …and settings too, once the app goes to the background.
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                try? container.mainContext.save()
                if sets.current == .nin, BackupFolder.shared.isOn { BackupFolder.shared.saveNow(container: container) }
            }
            // Gold, dollars and coins follow today's price when the phone is online.
            if phase == .active {
                MarketSync.start(container)
                Task { await MarketSync.run(container.mainContext, force: false) }
            }
        }
    }
}
