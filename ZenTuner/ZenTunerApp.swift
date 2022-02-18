import SwiftUI

@main
struct ZenTunerApp: App {
    var body: some Scene {
        WindowGroup {
            TunerScreen()
                .onAppear {
                    #if os(iOS)
                        UIApplication.shared.isIdleTimerDisabled = true
                    #endif
                }
        }
    }
}
