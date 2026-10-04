import SwiftUI

@main
struct LumenMacApp: App {
    @StateObject private var recorder = RecorderController()

    var body: some Scene {
        WindowGroup("Lumen for Mac") {
            ContentView(controller: recorder)
        }
        .windowResizability(.contentSize)
    }
}
