import Foundation
import Testing
@testable import EmbarrassMeNotCore

let speakers = OutputDevice(uid: "BuiltInSpeakerDevice", name: "MacBook Pro Speakers", isWireless: false)
let airPods = OutputDevice(uid: "AA-BB:output", name: "AirPods Pro", isWireless: true)
let display = OutputDevice(uid: "HDMI", name: "LG Display", isWireless: false)
let t0 = Date(timeIntervalSince1970: 1_000_000)

func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

@Test func headphonesDisconnectingSilencesTheSpeakers() {
    var guard_ = SpeakerGuard()
    #expect(guard_.update(.init(outputs: [speakers, airPods], defaultOutput: airPods.uid), at: at(0)) == [])
    #expect(guard_.update(.init(outputs: [speakers], defaultOutput: speakers.uid), at: at(60))
        == [.silence(output: speakers.uid, headphones: airPods.name)])
}

@Test func theOutputMovingBeforeTheHeadphonesGoStillSilences() {
    var guard_ = SpeakerGuard()
    _ = guard_.update(.init(outputs: [speakers, airPods], defaultOutput: airPods.uid), at: at(0))
    #expect(guard_.update(.init(outputs: [speakers, airPods], defaultOutput: speakers.uid), at: at(60)) == [])
    #expect(guard_.update(.init(outputs: [speakers], defaultOutput: speakers.uid), at: at(61))
        == [.silence(output: speakers.uid, headphones: airPods.name)])
}

@Test func choosingTheSpeakersYourselfLeavesThemAlone() {
    var guard_ = SpeakerGuard()
    _ = guard_.update(.init(outputs: [speakers, airPods], defaultOutput: airPods.uid), at: at(0))
    #expect(guard_.update(.init(outputs: [speakers, airPods], defaultOutput: speakers.uid), at: at(60)) == [])
    // The AirPods go back in their case long after.
    #expect(guard_.update(.init(outputs: [speakers], defaultOutput: speakers.uid), at: at(600)) == [])
}

@Test func movingOnToSomethingElseCancelsTheWait() {
    var guard_ = SpeakerGuard()
    _ = guard_.update(.init(outputs: [speakers, airPods, display], defaultOutput: airPods.uid), at: at(0))
    _ = guard_.update(.init(outputs: [speakers, airPods, display], defaultOutput: speakers.uid), at: at(1))
    _ = guard_.update(.init(outputs: [speakers, airPods, display], defaultOutput: display.uid), at: at(2))
    #expect(guard_.update(.init(outputs: [speakers, display], defaultOutput: display.uid), at: at(3)) == [])
}

@Test func whateverTakesOverIsSilencedNotOnlyTheSpeakers() {
    var guard_ = SpeakerGuard()
    _ = guard_.update(.init(outputs: [display, airPods], defaultOutput: airPods.uid), at: at(0))
    #expect(guard_.update(.init(outputs: [display], defaultOutput: display.uid), at: at(1))
        == [.silence(output: display.uid, headphones: airPods.name)])
}

@Test func aMomentWithNoOutputDoesNotLoseTheHeadphones() {
    var guard_ = SpeakerGuard()
    _ = guard_.update(.init(outputs: [speakers, airPods], defaultOutput: airPods.uid), at: at(0))
    #expect(guard_.update(.init(outputs: [speakers], defaultOutput: nil), at: at(1)) == [])
    #expect(guard_.update(.init(outputs: [speakers], defaultOutput: speakers.uid), at: at(2))
        == [.silence(output: speakers.uid, headphones: airPods.name)])
}

@Test func headphonesComingBackUnmuteWhatWasMuted() {
    var guard_ = SpeakerGuard()
    _ = guard_.update(.init(outputs: [speakers, airPods], defaultOutput: airPods.uid), at: at(0))
    _ = guard_.update(.init(outputs: [speakers], defaultOutput: speakers.uid), at: at(1))
    #expect(guard_.update(.init(outputs: [speakers, airPods], defaultOutput: airPods.uid), at: at(100))
        == [.unsilence(output: speakers.uid), .movedToHeadphones(airPods.name)])
    // Only once.
    _ = guard_.update(.init(outputs: [speakers, airPods], defaultOutput: speakers.uid), at: at(200))
    #expect(guard_.update(.init(outputs: [speakers, airPods], defaultOutput: airPods.uid), at: at(300))
        == [.movedToHeadphones(airPods.name)])
}

@Test func nothingHappensOnTheFirstLook() {
    var guard_ = SpeakerGuard()
    #expect(guard_.update(.init(outputs: [speakers], defaultOutput: speakers.uid), at: at(0)) == [])
    #expect(guard_.update(.init(outputs: [speakers], defaultOutput: speakers.uid), at: at(1)) == [])
}

@Test func soundMovingToHeadphonesIsToldButNotStayingThere() {
    var guard_ = SpeakerGuard()
    _ = guard_.update(.init(outputs: [speakers], defaultOutput: speakers.uid), at: at(0))
    #expect(guard_.update(.init(outputs: [speakers, airPods], defaultOutput: airPods.uid), at: at(1))
        == [.movedToHeadphones(airPods.name)])
    #expect(guard_.update(.init(outputs: [speakers, airPods, display], defaultOutput: airPods.uid), at: at(2)) == [])
}
