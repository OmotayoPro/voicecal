import SwiftUI

@main
struct VoicecalApp: App {
    var body: some Scene {
        WindowGroup {
            CalculatorView()
                .preferredColorScheme(.dark)
        }
    }
}
