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
        // Burst from a tight cluster near top-center of screen
        let centerX = size.width / 2
        particles = (0..<200).map { _ in
            let spawnX = centerX + CGFloat.random(in: -40...40)
            let spawnY = CGFloat.random(in: -20...50) // near top

            // Explosive outward spread biased downward
            let horizontalSpeed = CGFloat.random(in: -9...9)
            let verticalSpeed = CGFloat.random(in: 2...11)

            return ConfettiParticle(
                position: CGPoint(x: spawnX, y: spawnY),
                color: colors.randomElement()!,
                rotation: Double.random(in: 0...360),
                scale: Double.random(in: 0.5...1.5),
                velocity: CGPoint(x: horizontalSpeed, y: verticalSpeed),
                rotationSpeed: Double.random(in: -15...15),
                waveAmplitude: CGFloat.random(in: 0.8...2.5), // side-to-side wave width
                waveFrequency: Double.random(in: 1.5...3.5),  // oscillation speed
                wavePhase: Double.random(in: 0...(2 * .pi)),  // stagger so not all in sync
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

            // Sinusoidal wave drift — particles sway left/right as they fall
            let waveX = particles[i].waveAmplitude *
                CGFloat(cos(particles[i].waveFrequency * particles[i].age + particles[i].wavePhase))

            particles[i].position.x += particles[i].velocity.x + waveX
            particles[i].position.y += particles[i].velocity.y
            particles[i].velocity.y += 0.12               // gravity
            particles[i].velocity.x *= 0.98               // initial burst momentum decays
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
