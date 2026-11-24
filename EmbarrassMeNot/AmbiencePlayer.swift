import AVFoundation
import EmbarrassMeNotCore
import Observation

/// Plays the app's own ambiences, made as they play: the App Store build's
/// background sounds, where Apple's own can't be reached.
@Observable @MainActor
final class AmbiencePlayer {
    private(set) var isPlaying = false
    var ambience: Ambience {
        didSet {
            UserDefaults.standard.set(ambience.rawValue, forKey: "ambience")
            if isPlaying, oldValue != ambience { start() }
        }
    }
    var volume: Double {
        didSet {
            UserDefaults.standard.set(volume, forKey: "ambienceVolume")
            shared.target = Float(volume)
        }
    }

    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var shared = Shared()
    @ObservationIgnored private var configurationChanges: NSObjectProtocol?

    init() {
        ambience = Ambience(rawValue: UserDefaults.standard.string(forKey: "ambience") ?? "") ?? .balanced
        volume = UserDefaults.standard.object(forKey: "ambienceVolume") as? Double ?? 0.5
    }

    func play() {
        guard !isPlaying else { return }
        start()
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        shared.target = 0
        let engine = self.engine
        self.engine = nil
        configurationChanges.map(NotificationCenter.default.removeObserver)
        configurationChanges = nil
        // Let it fade out first.
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            engine?.stop()
        }
    }

    /// Starts, or starts again on whatever output sound goes to now.
    private func start() {
        engine?.stop()
        let engine = AVAudioEngine()
        let rate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        guard rate > 0, let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2) else { return }
        // Each engine its own, so one still fading out is never shared.
        let shared = Shared(AmbienceGenerator(ambience, sampleRate: rate, seed: UInt64.random(in: 1...UInt64.max)))
        shared.target = Float(volume)
        self.shared = shared
        let source = AVAudioSourceNode(format: format) { _, _, frames, buffers in
            shared.render(Int(frames), UnsafeMutableAudioBufferListPointer(buffers))
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
        } catch {
            return
        }
        self.engine = engine
        isPlaying = true
        configurationChanges.map(NotificationCenter.default.removeObserver)
        // The output changed under it (another device, another rate): the
        // engine has stopped, so start again there.
        configurationChanges = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isPlaying else { return }
                self.start()
            }
        }
    }
}

/// What the audio thread reads: the generator, and the volume it eases
/// towards so that nothing clicks.
private final class Shared: @unchecked Sendable {
    var generator: AmbienceGenerator
    var gain: Float = 0
    var target: Float = 0

    init(_ generator: AmbienceGenerator = AmbienceGenerator(.balanced, sampleRate: 48_000)) {
        self.generator = generator
    }

    func render(_ frames: Int, _ buffers: UnsafeMutableAudioBufferListPointer) {
        guard buffers.count >= 2,
              let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
              let right = buffers[1].mData?.assumingMemoryBound(to: Float.self)
        else { return }
        // Squared, so the slider's lower half isn't all loud.
        let goal = target * target
        for i in 0..<frames {
            gain += (goal - gain) * 0.0002
            let (l, r) = generator.next()
            left[i] = l * gain
            right[i] = r * gain
        }
    }
}
