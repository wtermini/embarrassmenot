import Foundation

/// The sounds the app makes itself, from noise, with no recordings: the App
/// Store build's own background sounds.
public enum Ambience: String, CaseIterable, Identifiable, Sendable {
    case balanced, bright, dark, ocean, rain

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .balanced: "Balanced Noise"
        case .bright: "Bright Noise"
        case .dark: "Dark Noise"
        case .ocean: "Ocean"
        case .rain: "Rain"
        }
    }
}

/// Makes an ambience, a stereo frame at a time. Each ear gets its own noise,
/// which sounds wider than one noise in both; the swell of the ocean and the
/// drops of rain are shared, so they come from somewhere.
public struct AmbienceGenerator: Sendable {
    public let ambience: Ambience
    let sampleRate: Double
    var rng: SplitMix
    var left = Noise()
    var right = Noise()

    // Ocean: a wave's progress, and how long this wave lasts.
    var wave: Double = 0
    var waveSeconds: Double = 9
    // Rain: the drop that is falling, as a decaying burst.
    var drop: Float = 0
    var dropPan: Float = 0.5

    public init(_ ambience: Ambience, sampleRate: Double, seed: UInt64 = 0x5eed) {
        self.ambience = ambience
        self.sampleRate = sampleRate
        self.rng = SplitMix(seed)
    }

    public mutating func next() -> (left: Float, right: Float) {
        let a = rng.white(), b = rng.white()
        var l: Float, r: Float
        switch ambience {
        case .bright:
            l = a * 0.25
            r = b * 0.25
        case .balanced:
            l = left.pink(a) * 0.9
            r = right.pink(b) * 0.9
        case .dark:
            l = left.brown(a) * 0.9
            r = right.brown(b) * 0.9
        case .ocean:
            wave += 1 / (waveSeconds * sampleRate)
            if wave >= 1 {
                wave = 0
                waveSeconds = 7 + Double(rng.unit()) * 5
            }
            // Slow to rise, quicker to fall back, never quite silent.
            let shape = wave < 0.6 ? wave / 0.6 : (1 - wave) / 0.4
            let swell = Float(0.25 + 0.75 * shape * shape)
            l = (left.brown(a) * 0.7 + left.pink(a) * 0.3) * swell
            r = (right.brown(b) * 0.7 + right.pink(b) * 0.3) * swell
        case .rain:
            if drop < 0.01, rng.unit() < Float(40 / sampleRate) {
                drop = 0.4 + rng.unit() * 0.6
                dropPan = rng.unit()
            }
            let patter = rng.white() * drop
            drop *= Float(exp(-1 / (0.012 * sampleRate)))
            l = left.highpass(left.pink(a)) * 0.8 + patter * (1 - dropPan) * 0.35
            r = right.highpass(right.pink(b)) * 0.8 + patter * dropPan * 0.35
        }
        return (min(max(l, -1), 1), min(max(r, -1), 1))
    }
}

/// One ear's filter memory.
struct Noise: Sendable {
    var b0: Float = 0, b1: Float = 0, b2: Float = 0, b3: Float = 0, b4: Float = 0, b5: Float = 0, b6: Float = 0
    var walk: Float = 0
    var hpIn: Float = 0, hpOut: Float = 0

    /// Paul Kellet's pink noise filter.
    mutating func pink(_ w: Float) -> Float {
        b0 = 0.99886 * b0 + w * 0.0555179
        b1 = 0.99332 * b1 + w * 0.0750759
        b2 = 0.96900 * b2 + w * 0.1538520
        b3 = 0.86650 * b3 + w * 0.3104856
        b4 = 0.55000 * b4 + w * 0.5329522
        b5 = -0.7616 * b5 - w * 0.0168980
        let out = b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362
        b6 = w * 0.115926
        return out * 0.11
    }

    /// A random walk that leans back to the middle: brown noise.
    mutating func brown(_ w: Float) -> Float {
        walk = (walk + 0.02 * w) / 1.02
        return walk * 3.5
    }

    /// Takes the rumble out, which leaves the hiss of rain.
    mutating func highpass(_ x: Float) -> Float {
        hpOut = 0.97 * (hpOut + x - hpIn)
        hpIn = x
        return hpOut
    }
}

/// A small, fast random number generator that needs no locking.
struct SplitMix: Sendable {
    var state: UInt64

    init(_ seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0 up to 1.
    mutating func unit() -> Float { Float(next() >> 40) / Float(1 << 24) }

    /// -1 up to 1.
    mutating func white() -> Float { unit() * 2 - 1 }
}
