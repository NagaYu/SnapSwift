import SwiftUI

@main
struct SnapSwiftApp: App {
    var body: some Scene {
        WindowGroup("SnapSwift") {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {} // no "New" menu — single-window tool
        }
    }
}
