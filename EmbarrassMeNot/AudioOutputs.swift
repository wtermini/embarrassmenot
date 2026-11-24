import CoreAudio
import EmbarrassMeNotCore

/// The Mac's audio outputs, through Core Audio.
enum AudioOutputs {
    static let system = AudioObjectID(kAudioObjectSystemObject)

    /// Every output, and which one sound goes to now.
    static func snapshot() -> AudioSnapshot {
        let outputs = deviceIDs().filter(hasOutput).compactMap { id -> OutputDevice? in
            guard let uid = string(id, kAudioDevicePropertyDeviceUID) else { return nil }
            let transport = scalar(id, address(kAudioDevicePropertyTransportType), UInt32(0)) ?? 0
            return OutputDevice(
                uid: uid,
                name: string(id, kAudioObjectPropertyName) ?? uid,
                isWireless: transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE)
        }
        let current = scalar(system, address(kAudioHardwarePropertyDefaultOutputDevice), AudioObjectID(0))
        return AudioSnapshot(outputs: outputs, defaultOutput: current.flatMap { string($0, kAudioDevicePropertyDeviceUID) })
    }

    /// Mutes or unmutes an output. One with no mute of its own is turned
    /// right down instead (and left down when unmuted).
    @discardableResult
    static func setMuted(_ uid: String, _ muted: Bool) -> Bool {
        guard let id = deviceIDs().first(where: { string($0, kAudioDevicePropertyDeviceUID) == uid }) else { return false }
        var mute: UInt32 = muted ? 1 : 0
        if set(id, kAudioDevicePropertyMute, &mute) { return true }
        guard muted else { return false }
        var silent: Float32 = 0
        return set(id, kAudioDevicePropertyVolumeScalar, &silent)
    }

    /// Sets a property on the output's main element, or else on each of its
    /// first two channels.
    private static func set<T: BitwiseCopyable>(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, _ value: inout T) -> Bool {
        func set(_ element: AudioObjectPropertyElement) -> Bool {
            var a = address(selector, kAudioObjectPropertyScopeOutput, element)
            var settable: DarwinBoolean = false
            return AudioObjectHasProperty(id, &a)
                && AudioObjectIsPropertySettable(id, &a, &settable) == noErr && settable.boolValue
                && AudioObjectSetPropertyData(id, &a, 0, nil, UInt32(MemoryLayout<T>.size), &value) == noErr
        }
        if set(kAudioObjectPropertyElementMain) { return true }
        let left = set(1), right = set(2)
        return left || right
    }

    static func deviceIDs() -> [AudioObjectID] {
        var a = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &a, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &a, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    static func hasOutput(_ id: AudioObjectID) -> Bool {
        var a = address(kAudioDevicePropertyStreams, kAudioObjectPropertyScopeOutput)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &a, 0, nil, &size) == noErr && size > 0
    }

    static func address(_ selector: AudioObjectPropertySelector,
                        _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                        _ element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    static func scalar<T: BitwiseCopyable>(_ id: AudioObjectID, _ address: AudioObjectPropertyAddress, _ initial: T) -> T? {
        var a = address, value = initial
        var size = UInt32(MemoryLayout<T>.size)
        return AudioObjectGetPropertyData(id, &a, 0, nil, &size, &value) == noErr ? value : nil
    }

    static func string(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var a = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &a, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }
}

/// Calls back on the main thread whenever an output comes or goes, or sound
/// moves to another one.
final class AudioOutputWatcher {
    private let block: AudioObjectPropertyListenerBlock
    private static let selectors = [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultOutputDevice]

    init(_ changed: @escaping @MainActor @Sendable () -> Void) {
        block = { _, _ in MainActor.assumeIsolated { changed() } }
        for selector in Self.selectors {
            var a = AudioOutputs.address(selector)
            AudioObjectAddPropertyListenerBlock(AudioOutputs.system, &a, .main, block)
        }
    }

    deinit {
        for selector in Self.selectors {
            var a = AudioOutputs.address(selector)
            AudioObjectRemovePropertyListenerBlock(AudioOutputs.system, &a, .main, block)
        }
    }
}
