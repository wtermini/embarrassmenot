import Foundation
import EmbarrassMeNotCore
import Observation
import ServiceManagement

/// Everything the menu shows, and what happens when headphones come and go.
@Observable @MainActor
final class AppModel {
    var muteSpeakers: Bool { didSet { defaults.set(muteSpeakers, forKey: "muteSpeakers") } }
    var stopSounds: Bool { didSet { defaults.set(stopSounds, forKey: "stopSounds") } }
    var startSounds: Bool { didSet { defaults.set(startSounds, forKey: "startSounds") } }

    /// Where sound goes now.
    private(set) var outputName = ""
    /// The last time the speakers were silenced, said in words.
    private(set) var lastSilenced: String?
    /// When the sounds stop by themselves.
    private(set) var stopAt: Date?

    #if BACKGROUND_SOUNDS
    let backgroundSounds = BackgroundSounds()
    #endif
    let ambience = AmbiencePlayer()

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var speakerGuard = SpeakerGuard()
    @ObservationIgnored private var mutedByUs: Set<String> = []
    @ObservationIgnored private var watcher: AudioOutputWatcher?
    @ObservationIgnored private var timer: Task<Void, Never>?
    @ObservationIgnored private var arrival: Task<Void, Never>?

    init() {
        defaults.register(defaults: ["muteSpeakers": true, "stopSounds": true, "startSounds": false])
        muteSpeakers = defaults.bool(forKey: "muteSpeakers")
        stopSounds = defaults.bool(forKey: "stopSounds")
        startSounds = defaults.bool(forKey: "startSounds")
        watcher = AudioOutputWatcher { [weak self] in self?.outputsChanged() }
        outputsChanged()
    }

    // MARK: Headphones

    func outputsChanged() {
        let snapshot = AudioOutputs.snapshot()
        outputName = snapshot.outputs.first { $0.uid == snapshot.defaultOutput }?.name ?? ""
        var unmute: [String] = []
        for action in speakerGuard.update(snapshot, at: .now) {
            switch action {
            case let .silence(output, headphones):
                arrival?.cancel()
                if muteSpeakers, AudioOutputs.setMuted(output, true) {
                    mutedByUs.insert(output)
                    let name = snapshot.outputs.first { $0.uid == output }?.name ?? output
                    lastSilenced = "Muted \(name) when \(headphones) disconnected, at \(Date.now.formatted(date: .omitted, time: .shortened))."
                }
                if stopSounds { stopAllSounds() }
            case let .unsilence(output):
                unmute.append(output)
            case .movedToHeadphones:
                headphonesArrived(unmute: unmute)
                unmute = []
            }
        }
        for output in unmute where mutedByUs.remove(output) != nil {
            AudioOutputs.setMuted(output, false)
        }
    }

    /// AirPods take a moment after connecting before they can play, and
    /// sound started in that moment goes to the speakers instead. So wait,
    /// check sound still goes to headphones, start the background sounds,
    /// and only then unmute the speakers muted when the headphones left: if
    /// the sounds land on the speakers after all, nobody hears them.
    private func headphonesArrived(unmute: [String]) {
        arrival?.cancel()
        arrival = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, !Task.isCancelled else { return }
            let now = AudioOutputs.snapshot()
            let onHeadphones = now.outputs.first { $0.uid == now.defaultOutput }?.isWireless ?? false
            if onHeadphones, self.startSounds {
                self.startSoundsNow()
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
            }
            for output in unmute where self.mutedByUs.remove(output) != nil {
                AudioOutputs.setMuted(output, false)
            }
        }
    }

    // MARK: Sounds

    var soundsPlaying: Bool {
        #if BACKGROUND_SOUNDS
        if backgroundSounds.isAvailable { return backgroundSounds.isOn }
        #endif
        return ambience.isPlaying
    }

    func setSoundsPlaying(_ on: Bool) {
        on ? startSoundsNow() : stopAllSounds()
    }

    private func startSoundsNow() {
        #if BACKGROUND_SOUNDS
        if backgroundSounds.isAvailable {
            backgroundSounds.setOn(true)
            return
        }
        #endif
        ambience.play()
    }

    func stopAllSounds() {
        #if BACKGROUND_SOUNDS
        backgroundSounds.setOn(false)
        #endif
        ambience.stop()
        setTimer(nil)
    }

    /// Stops the sounds after this long, or never.
    func setTimer(_ minutes: Int?) {
        timer?.cancel()
        guard let minutes else {
            stopAt = nil
            return
        }
        let end = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        stopAt = end
        if !soundsPlaying { startSoundsNow() }
        timer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(end.timeIntervalSinceNow))
            guard !Task.isCancelled, let self else { return }
            self.stopAt = nil
            self.stopAllSounds()
        }
    }

    // MARK: Login

    private(set) var opensAtLogin = SMAppService.mainApp.status == .enabled

    func setOpensAtLogin(_ on: Bool) {
        try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }
}
