import SwiftUI

/// Lets users tune the task-completion confetti cannon.
/// All values are persisted via @AppStorage and read live by ListView.
struct ConfettiSettingsView: View {
    // MARK: - Persisted settings (same keys read by ListView)
    @AppStorage("confetti_num") private var num: Int = 80
    @AppStorage("confetti_size") private var confettiSize: Double = 11.0
    @AppStorage("confetti_rainHeight") private var rainHeight: Double = 700.0
    @AppStorage("confetti_opacity") private var opacity: Double = 1.0
    @AppStorage("confetti_fadesOut") private var fadesOut: Bool = true
    @AppStorage("confetti_openingAngle") private var openingAngle: Double = 60.0
    @AppStorage("confetti_closingAngle") private var closingAngle: Double = 120.0
    @AppStorage("confetti_radius") private var radius: Double = 520.0
    @AppStorage("confetti_repetitions") private var repetitions: Int = 1
    @AppStorage("confetti_repetitionInterval") private var repetitionInterval: Double = 1.0
    @AppStorage("confetti_spinSpeed") private var spinSpeedMultiplier: Double = 1.0

    @State private var testTrigger = 0

    var body: some View {
        Form {
            // MARK: - Confetti section
            Section("Confetti") {
                Stepper("Count: \(num)", value: $num, in: 1...200, step: 5)
                Stepper("Size: \(String(format: "%.0f", confettiSize))",
                        value: $confettiSize, in: 1...50, step: 1)
                Stepper("Rain Height: \(String(format: "%.0f", rainHeight))",
                        value: $rainHeight, in: 0...1000, step: 50)
                Stepper("Opacity: \(String(format: "%.1f", opacity))",
                        value: $opacity, in: 0...1, step: 0.1)
            }

            // MARK: - Animation section
            Section("Animation") {
                Toggle("Fades Out", isOn: $fadesOut)
                Stepper("Opening Angle: \(String(format: "%.0f", openingAngle))°",
                        value: $openingAngle, in: 0...360, step: 10)
                Stepper("Closing Angle: \(String(format: "%.0f", closingAngle))°",
                        value: $closingAngle, in: 0...360, step: 10)
                Stepper("Radius: \(String(format: "%.0f", radius))",
                        value: $radius, in: 1...1000, step: 20)
                Stepper("Repetitions: \(repetitions)", value: $repetitions, in: 1...20, step: 1)
                Stepper("Interval: \(String(format: "%.1f", repetitionInterval))s",
                        value: $repetitionInterval, in: 0.1...10, step: 0.1)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Spin Speed")
                        Spacer()
                        Text(String(format: "%.1fx", spinSpeedMultiplier))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $spinSpeedMultiplier, in: 0.5...3.0, step: 0.1)
                        .tint(.kaiPurple)
                }
                .padding(.vertical, 2)
            }

            // MARK: - Test button
            Section {
                Button {
                    testTrigger += 1
                } label: {
                    Label("Test Confetti", systemImage: "party.popper.fill")
                        .foregroundStyle(Color.kaiPurple)
                }
            } footer: {
                Text("Changes apply immediately to the task completion animation.")
            }

            // MARK: - Reset to defaults
            Section {
                Button(role: .destructive) {
                    resetToDefaults()
                } label: {
                    Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .navigationTitle("Confetti")
        .navigationBarTitleDisplayMode(.inline)
        // Live preview cannon fires when Test button tapped
        .confettiCannon(
            trigger: $testTrigger,
            num: num,
            colors: [.kaiPurple, .kaiRed, .kaiTeal, .kaiYellow, .kaiOrange, .kaiMint, .kaiPink, .kaiBlue],
            confettiSize: CGFloat(confettiSize),
            rainHeight: CGFloat(rainHeight),
            fadesOut: fadesOut,
            opacity: opacity,
            openingAngle: .degrees(openingAngle),
            closingAngle: .degrees(closingAngle),
            radius: CGFloat(radius),
            repetitions: repetitions,
            repetitionInterval: repetitionInterval,
            spinSpeedMultiplier: spinSpeedMultiplier
        )
    }

    private func resetToDefaults() {
        num = 80
        confettiSize = 11.0
        rainHeight = 700.0
        opacity = 1.0
        fadesOut = true
        openingAngle = 60.0
        closingAngle = 120.0
        radius = 520.0
        repetitions = 1
        repetitionInterval = 1.0
        spinSpeedMultiplier = 1.0
    }
}

#Preview {
    NavigationStack {
        ConfettiSettingsView()
    }
}
