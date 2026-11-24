#if BACKGROUND_SOUNDS
import Foundation
import Observation

/// Apple's own Background Sounds (System Settings ▸ Accessibility ▸ Audio),
/// set the way Control Center sets them: through `HUComfortSoundsSettings`
/// in the private HearingUtilities framework, which `heard` watches and plays
/// from. Private, so never in the App Store build (`BACKGROUND_SOUNDS` is set
/// in Debug and Release only); and a macOS update may break it, in which case
/// `isAvailable` is false and the menu leaves it out.
@Observable @MainActor
final class BackgroundSounds {
    struct Sound: Identifiable, Hashable {
        let group: Int
        let name: String
        var id: Int { group }
    }

    private(set) var isAvailable = false
    private(set) var isOn = false
    private(set) var sounds: [Sound] = []
    private(set) var selected = 0
    private(set) var volume = 0.5
    private(set) var mixesWithMedia = true
    private(set) var mediaVolume = 0.2
    private(set) var stopsOnLock = false

    @ObservationIgnored private let settings: NSObject?
    @ObservationIgnored private let soundClass: NSObject.Type?

    init() {
        let framework = "/System/Library/PrivateFrameworks/HearingUtilities.framework/HearingUtilities"
        let loaded = dlopen(framework, RTLD_LAZY) != nil
        let settingsClass = loaded ? NSClassFromString("HUComfortSoundsSettings") as? NSObject.Type : nil
        let shared = NSSelectorFromString("sharedInstance")
        settings = settingsClass?.responds(to: shared) == true
            ? settingsClass?.perform(shared)?.takeUnretainedValue() as? NSObject : nil
        soundClass = loaded ? NSClassFromString("HUComfortSound") as? NSObject.Type : nil
        sounds = (1...40).compactMap { group in
            sound(group).map { Sound(group: group, name: ($0.value(forKey: "localizedName") as? String) ?? "Sound \(group)") }
        }
        isAvailable = settings != nil && !sounds.isEmpty && (settings?.value(forKey: "comfortSoundsAvailable") as? Bool ?? true)
        refresh()
    }

    /// Reads them again: Control Center or System Settings may have changed them.
    func refresh() {
        guard isAvailable, let settings else { return }
        isOn = settings.value(forKey: "comfortSoundsEnabled") as? Bool ?? false
        volume = settings.value(forKey: "relativeVolume") as? Double ?? volume
        mixesWithMedia = settings.value(forKey: "mixesWithMedia") as? Bool ?? mixesWithMedia
        mediaVolume = settings.value(forKey: "mediaVolume") as? Double ?? mediaVolume
        stopsOnLock = settings.value(forKey: "stopsOnLock") as? Bool ?? stopsOnLock
        if let current = settings.value(forKey: "selectedComfortSound") as? NSObject,
           let name = current.value(forKey: "name") as? String,
           let match = sounds.first(where: { sound($0.group)?.value(forKey: "name") as? String == name }) {
            selected = match.group
        }
    }

    func setOn(_ on: Bool) { write(on, "comfortSoundsEnabled") }
    func setVolume(_ v: Double) { write(v, "relativeVolume") }
    func setMixesWithMedia(_ on: Bool) { write(on, "mixesWithMedia") }
    func setMediaVolume(_ v: Double) { write(v, "mediaVolume") }
    func setStopsOnLock(_ on: Bool) { write(on, "stopsOnLock") }

    func select(_ group: Int) {
        guard let s = sound(group) else { return }
        write(s, "selectedComfortSound")
    }

    private func write(_ value: Any, _ key: String) {
        guard isAvailable, let settings else { return }
        settings.setValue(value, forKey: key)
        refresh()
    }

    /// `+[HUComfortSound defaultComfortSoundForGroup:]`: groups run from 1
    /// (Balanced Noise) to 16 (Quiet Night) in macOS 27.
    private func sound(_ group: Int) -> NSObject? {
        typealias Factory = @convention(c) (AnyClass, Selector, Int) -> NSObject?
        let selector = NSSelectorFromString("defaultComfortSoundForGroup:")
        guard let soundClass, let meta = object_getClass(soundClass), soundClass.responds(to: selector) else { return nil }
        let factory = unsafeBitCast(class_getMethodImplementation(meta, selector), to: Factory.self)
        return factory(soundClass, selector, group)
    }
}
#endif
