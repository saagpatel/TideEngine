import SwiftUI

@main
struct TideEngineApp: App {
#if DEBUG
    init() {
        if AppStoreScreenshot.number != nil {
            NSTimeZone.default = TimeZone(secondsFromGMT: 0)!
        }
    }
#endif
    var body: some Scene {
        WindowGroup {
            ContentView()
#if DEBUG
                .modifier(AppStoreScreenshotAppearance())
#endif
        }
    }
}

#if DEBUG
private struct AppStoreScreenshotAppearance: ViewModifier {
    func body(content: Content) -> some View {
        if AppStoreScreenshot.number != nil {
            content
                .environment(\.locale, Locale(identifier: "en_US"))
                .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                .dynamicTypeSize(.large)
                .preferredColorScheme(.dark)
                .transaction { $0.disablesAnimations = true }
        } else {
            content
        }
    }
}
#endif
