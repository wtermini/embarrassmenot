import SwiftUI

@main
struct EmbarrassMeNotApp: App {
    @State private var model = AppModel()

    init() {
        #if DEBUG
        DebugSnapshot.writeIfAsked(model)
        #endif
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView(model: model)
        } label: {
            // Barking while background sounds play, good while all is quiet.
            Image(model.soundsPlaying ? "MenuBarking" : "MenuGood")
        }
        .menuBarExtraStyle(.window)
    }
}
