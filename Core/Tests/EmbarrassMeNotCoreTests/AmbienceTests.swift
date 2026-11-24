import Testing
@testable import EmbarrassMeNotCore

func render(_ ambience: Ambience, seconds: Double = 20, seed: UInt64 = 1) -> [Float] {
    var g = AmbienceGenerator(ambience, sampleRate: 48_000, seed: seed)
    return (0..<Int(seconds * 48_000)).map { _ in g.next().left }
}

func rms(_ x: [Float]) -> Float { (x.reduce(0) { $0 + $1 * $1 } / Float(x.count)).squareRoot() }

/// How much each sample differs from the last, against how loud it is: high
/// for hiss, low for rumble.
func roughness(_ x: [Float]) -> Float {
    let d = zip(x.dropFirst(), x).map { $0 - $1 }
    return rms(d) / rms(x)
}

@Test(arguments: Ambience.allCases)
func everyAmbienceIsAudibleAndNeverClips(_ ambience: Ambience) {
    let x = render(ambience)
    #expect(x.allSatisfy { abs($0) < 1 })
    #expect(rms(x) > 0.02, "too quiet")
    #expect(rms(x) < 0.35, "too loud")
}

@Test func theSameSeedMakesTheSameSound() {
    #expect(render(.rain, seconds: 1) == render(.rain, seconds: 1))
    #expect(render(.rain, seconds: 1) != render(.rain, seconds: 1, seed: 2))
}

@Test func brightIsHissierThanBalancedWhichIsHissierThanDark() {
    let bright = roughness(render(.bright)), balanced = roughness(render(.balanced)), dark = roughness(render(.dark))
    #expect(bright > balanced)
    #expect(balanced > dark)
}

@Test func theOceanSwells() {
    let x = render(.ocean, seconds: 30)
    let seconds = stride(from: 0, to: x.count, by: 48_000).map { rms(Array(x[$0..<min($0 + 48_000, x.count)])) }
    #expect(seconds.max()! > seconds.min()! * 2)
}
