import SwiftUI

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var color: Color
    var rotation: Double
    var scale: Double
    var velocity: CGPoint
    var rotationSpeed: Double
    var waveAmplitude: CGFloat  // horizontal wave width
    var waveFrequency: Double   // how fast the wave oscillates
    var wavePhase: Double       // per-particle phase offset for staggered waves
    var age: Double             // time elapsed, drives wave calculation
}

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var animationTimer: Timer?

    private let colors: [Color] = [
        .kaiPurple, .kaiRed, .kaiTeal, .kaiYellow,
        .kaiOrange, .kaiMint, .kaiPink, .kaiBlue
    ]

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                for particle in particles {
                    let rect = CGRect(
                        x: particle.position.x - 4 * particle.scale,
                        y: particle.position.y - 6 * particle.scale,
                        width: 8 * particle.scale,
                        height: 12 * particle.scale
                    )

                    context.rotate(by: .degrees(particle.rotation))
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 2),
                        with: .color(particle.color)
                    )
                    context.rotate(by: .degrees(-particle.rotation))
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
                startAnimation()
            }
            .onDisappear {
                animationTimer?.invalidate()
            }
        }
        .ignoresSafeArea()
    }

    private func createParticles(in size: CGSize) {
        // Launch from center — like throwing confetti straight up
        // Particles shoot upward, spread slightly left/right, then gravity pulls them down
        let originX = size.width / 2
        let originY = size.height / 2

        particles = (0..<200).map { _ in
            return ConfettiParticle(
                position: CGPoint(
                    x: originX + CGFloat.random(in: -30...30),
                    y: originY + CGFloat.random(in: -10...10)
                ),
                color: colors.randomElement()!,
                rotation: Double.random(in: 0...360),
                scale: Double.random(in: 0.5...1.5),
                velocity: CGPoint(
                    x: CGFloat.random(in: -6...6),      // slight horizontal spread
                    y: CGFloat.random(in: -22 ... -8)   // strong upward launch (negative = up in iOS)
                ),
                rotationSpeed: Double.random(in: -18...18),
                waveAmplitude: 0,   // no sinusoidal drift
                waveFrequency: 0,
                wavePhase: 0,
                age: 0
            )
        }
    }

    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in
            updateParticles()
        }
    }

    private func updateParticles() {
        for i in particles.indices {
            particles[i].age += 1.0 / 60.0

            particles[i].position.x += particles[i].velocity.x
            particles[i].position.y += particles[i].velocity.y
            particles[i].velocity.y += 0.45          // gravity — pulls confetti back down
            particles[i].velocity.x *= 0.99          // tiny air resistance on horizontal
            particles[i].rotation += particles[i].rotationSpeed
        }
    }
}

#Preview {
    ZStack {
        Color.white
        ConfettiView()
    }
}
