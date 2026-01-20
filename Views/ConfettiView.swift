import SwiftUI

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var color: Color
    var rotation: Double
    var scale: Double
    var velocity: CGPoint
    var rotationSpeed: Double
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
        particles = (0..<200).map { _ in
            ConfettiParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: -20
                ),
                color: colors.randomElement()!,
                rotation: Double.random(in: 0...360),
                scale: Double.random(in: 0.5...1.5),
                velocity: CGPoint(
                    x: CGFloat.random(in: -2...2),
                    y: CGFloat.random(in: 3...8)
                ),
                rotationSpeed: Double.random(in: -10...10)
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
            particles[i].position.x += particles[i].velocity.x
            particles[i].position.y += particles[i].velocity.y
            particles[i].velocity.y += 0.1 // gravity
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
