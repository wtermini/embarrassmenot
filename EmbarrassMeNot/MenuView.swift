import EmbarrassMeNotCore
import SwiftUI

/// The window under the menu bar icon.
struct MenuView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.vertical, 8)
            headphones
            Divider().padding(.vertical, 8)
            sounds
            Divider().padding(.vertical, 8)
            footer
        }
        .padding(14)
        .frame(width: 300)
        .toggleStyle(.switch)
        .controlSize(.small)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        #if BACKGROUND_SOUNDS
        model.backgroundSounds.refresh()
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Embarrass Me Not").font(.headline)
            if !model.outputName.isEmpty {
                Text("Playing through \(model.outputName)").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var headphones: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("When headphones disconnect").font(.subheadline.weight(.semibold))
            row("Mute the speakers", $model.muteSpeakers)
            row("Stop background sounds", $model.stopSounds)
            if let last = model.lastSilenced {
                Text(last).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private var sounds: some View {
        VStack(alignment: .leading, spacing: 6) {
            row("Background Sounds", Binding(get: { model.soundsPlaying }, set: model.setSoundsPlaying), bold: true)
            #if BACKGROUND_SOUNDS
            if model.backgroundSounds.isAvailable {
                appleSounds(model.backgroundSounds)
            } else {
                ownSounds
            }
            #else
            ownSounds
            #endif
            timer
            row("Start when headphones connect", $model.startSounds)
        }
    }

    #if BACKGROUND_SOUNDS
    @ViewBuilder private func appleSounds(_ s: BackgroundSounds) -> some View {
        Picker("Sound", selection: Binding(get: { s.selected }, set: s.select)) {
            ForEach(s.sounds) { Text($0.name).tag($0.group) }
        }
        slider("Volume", Binding(get: { s.volume }, set: s.setVolume))
        row("Stop when the Mac locks", Binding(get: { s.stopsOnLock }, set: s.setStopsOnLock))
    }
    #endif

    @ViewBuilder private var ownSounds: some View {
        @Bindable var player = model.ambience
        Picker("Sound", selection: $player.ambience) {
            ForEach(Ambience.allCases) { Text($0.name).tag($0) }
        }
        slider("Volume", $player.volume)
    }

    private var timer: some View {
        HStack {
            Picker("Stop after", selection: Binding(get: { -1 }, set: { model.setTimer($0 < 0 ? nil : $0) })) {
                Text(model.stopAt.map { "At \($0.formatted(date: .omitted, time: .shortened))" } ?? "Never").tag(-1)
                Divider()
                ForEach([15, 30, 60, 120, 480], id: \.self) { minutes in
                    Text(Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .wide))).tag(minutes)
                }
            }
            if model.stopAt != nil {
                Button("Cancel") { model.setTimer(nil) }.buttonStyle(.link)
            }
        }
    }

    private var footer: some View {
        HStack {
            Toggle("Open at login", isOn: Binding(get: { model.opensAtLogin }, set: model.setOpensAtLogin))
                .toggleStyle(.checkbox)
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }

    private func row(_ title: String, _ on: Binding<Bool>, bold: Bool = false) -> some View {
        Toggle(isOn: on) {
            Text(title).font(bold ? .subheadline.weight(.semibold) : .body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .toggleStyle(SwitchRightToggleStyle())
    }

    private func slider(_ title: String, _ value: Binding<Double>) -> some View {
        HStack {
            Text(title).font(.body).frame(width: 76, alignment: .leading)
            Slider(value: value, in: 0...1)
        }
    }
}

/// A label on the left and its switch on the right, as in Control Center.
private struct SwitchRightToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Toggle("", isOn: configuration.$isOn).labelsHidden().toggleStyle(.switch)
        }
    }
}
