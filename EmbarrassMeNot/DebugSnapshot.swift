#if DEBUG
import AppKit
import SwiftUI

/// Debug builds only: `EMBARRASSMENOT_SNAPSHOT=menu.png` draws the menu into
/// that file and quits, for looking at it without clicking the menu bar.
enum DebugSnapshot {
    @MainActor static func writeIfAsked(_ model: AppModel) {
        guard let path = ProcessInfo.processInfo.environment["EMBARRASSMENOT_SNAPSHOT"] else { return }
        let dark = ProcessInfo.processInfo.environment["EMBARRASSMENOT_DARK"] != nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let view = NSHostingView(rootView: MenuView(model: model).background(.windowBackground))
            view.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            let window = NSWindow(contentRect: .init(origin: .zero, size: view.fittingSize), styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = view
            window.setContentSize(view.fittingSize)
            view.layoutSubtreeIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                    view.cacheDisplay(in: view.bounds, to: rep)
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
                }
                exit(0)
            }
        }
    }
}
#endif
