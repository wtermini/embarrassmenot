import Foundation

/// An audio output the Mac has, as much as the guard needs to know about it.
public struct OutputDevice: Equatable, Sendable {
    public var uid: String
    public var name: String
    /// Bluetooth or Bluetooth LE: AirPods, Beats and other wireless headphones.
    public var isWireless: Bool

    public init(uid: String, name: String, isWireless: Bool) {
        self.uid = uid
        self.name = name
        self.isWireless = isWireless
    }
}

/// The Mac's outputs and which one sound goes to, at one moment.
public struct AudioSnapshot: Equatable, Sendable {
    public var outputs: [OutputDevice]
    public var defaultOutput: String?

    public init(outputs: [OutputDevice], defaultOutput: String?) {
        self.outputs = outputs
        self.defaultOutput = defaultOutput
    }

    func device(_ uid: String?) -> OutputDevice? { outputs.first { $0.uid == uid } }
    func has(_ device: OutputDevice) -> Bool { outputs.contains { $0.uid == device.uid } }
}

/// Decides when the Mac's speakers should go quiet: when the wireless
/// headphones sound was going to disconnect (out of the case's range, into
/// the case, over to the iPhone) and the Mac falls back to its speakers.
/// Choosing the speakers yourself while the headphones are still connected
/// never silences them.
///
/// Feed it a snapshot whenever the outputs or the default output change.
/// macOS does not say in which order those two happen, so a move off
/// headphones that are still connected waits `grace` seconds to see whether
/// they disconnect.
public struct SpeakerGuard: Sendable {
    public enum Action: Equatable, Sendable {
        /// Mute this output: `headphones` just disconnected.
        case silence(output: String, headphones: String)
        /// Headphones are back: unmute an output this guard muted.
        case unsilence(output: String)
        /// Sound has moved to these headphones from something else.
        case movedToHeadphones(String)
    }

    public var grace: TimeInterval

    private var lastDefault: OutputDevice?
    private var pending: (headphones: OutputDevice, to: String, at: Date)?
    private var silenced: [String] = []

    public init(grace: TimeInterval = 5) {
        self.grace = grace
    }

    public mutating func update(_ now: AudioSnapshot, at time: Date) -> [Action] {
        guard let current = now.device(now.defaultOutput) else { return [] }
        let previous = lastDefault
        lastDefault = current
        if let p = pending, time.timeIntervalSince(p.at) > grace || p.to != current.uid {
            pending = nil
        }

        if current.isWireless {
            pending = nil
            defer { silenced = [] }
            var actions = silenced.map { Action.unsilence(output: $0) }
            if let previous, previous.uid != current.uid { actions.append(.movedToHeadphones(current.name)) }
            return actions
        }

        var lost: OutputDevice?
        if let previous, previous.uid != current.uid {
            if previous.isWireless {
                if now.has(previous) {
                    pending = (previous, current.uid, time)
                } else {
                    lost = previous
                }
            }
        } else if let p = pending, !now.has(p.headphones) {
            lost = p.headphones
        }

        guard let lost else { return [] }
        pending = nil
        if !silenced.contains(current.uid) { silenced.append(current.uid) }
        return [.silence(output: current.uid, headphones: lost.name)]
    }
}
