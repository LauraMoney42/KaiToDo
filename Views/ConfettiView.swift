// ConfettiView.swift — powered by ConfettiSwiftUI (MIT) https://github.com/simibac/ConfettiSwiftUI
// Manually integrated as a single file to avoid SPM dependency

import SwiftUI

// MARK: - Shapes

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return path
    }
}

struct SlimRectangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: 4*rect.maxY/5))
        path.addLine(to: CGPoint(x: rect.maxX, y: 4*rect.maxY/5))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

struct RoundedCross: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY/3))
        path.addQuadCurve(to: CGPoint(x: rect.maxX/3, y: rect.minY), control: CGPoint(x: rect.maxX/3, y: rect.maxY/3))
        path.addLine(to: CGPoint(x: 2*rect.maxX/3, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY/3), control: CGPoint(x: 2*rect.maxX/3, y: rect.maxY/3))
        path.addLine(to: CGPoint(x: rect.maxX, y: 2*rect.maxY/3))
        path.addQuadCurve(to: CGPoint(x: 2*rect.maxX/3, y: rect.maxY), control: CGPoint(x: 2*rect.maxX/3, y: 2*rect.maxY/3))
        path.addLine(to: CGPoint(x: rect.maxX/3, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: 2*rect.minX/3, y: 2*rect.maxY/3), control: CGPoint(x: rect.maxX/3, y: 2*rect.maxY/3))
        return path
    }
}

// MARK: - Confetti Type

enum ConfettiType: CaseIterable, Hashable {
    enum Shape { case circle, triangle, square, slimRectangle, roundedCross }
    case shape(Shape)
    case text(String)
    case sfSymbol(symbolName: String)

    var view: AnyView {
        switch self {
        case .shape(.square):        return AnyView(Rectangle())
        case .shape(.triangle):      return AnyView(Triangle())
        case .shape(.slimRectangle): return AnyView(SlimRectangle())
        case .shape(.roundedCross):  return AnyView(RoundedCross())
        case let .text(t):           return AnyView(Text(t))
        case .sfSymbol(let n):       return AnyView(Image(systemName: n))
        default:                     return AnyView(Circle())
        }
    }

    static var allCases: [ConfettiType] {
        [.shape(.circle), .shape(.triangle), .shape(.square), .shape(.slimRectangle), .shape(.roundedCross)]
    }
}

// MARK: - Config

class ConfettiConfig: ObservableObject {
    @Published var num: Int
    @Published var shapes: [AnyView]
    @Published var colors: [Color]
    @Published var confettiSize: CGFloat
    @Published var rainHeight: CGFloat
    @Published var fadesOut: Bool
    @Published var opacity: Double
    @Published var openingAngle: Angle
    @Published var closingAngle: Angle
    @Published var radius: CGFloat
    @Published var repetitions: Int
    @Published var repetitionInterval: Double
    @Published var explosionAnimationDuration: Double
    @Published var rainAnimationDuration: Double
    @Published var hapticFeedback: Bool

    init(num: Int, shapes: [AnyView], colors: [Color], confettiSize: CGFloat,
         rainHeight: CGFloat, fadesOut: Bool, opacity: Double,
         openingAngle: Angle, closingAngle: Angle, radius: CGFloat,
         repetitions: Int, repetitionInterval: Double, hapticFeedback: Bool,
         spinSpeedMultiplier: Double = 1.0) {
        self.num = num; self.shapes = shapes; self.colors = colors
        self.confettiSize = confettiSize; self.rainHeight = rainHeight
        self.fadesOut = fadesOut; self.opacity = opacity
        self.openingAngle = openingAngle; self.closingAngle = closingAngle
        self.radius = radius; self.repetitions = repetitions
        self.repetitionInterval = repetitionInterval
        self.explosionAnimationDuration = Double(radius / 1300)
        // Divide by spinSpeedMultiplier so higher value = shorter duration = faster spin/fall
        self.rainAnimationDuration = Double((rainHeight + radius) / 200) / max(spinSpeedMultiplier, 0.1)
        self.hapticFeedback = hapticFeedback
    }

    var animationDuration: Double { explosionAnimationDuration + rainAnimationDuration }
}

// MARK: - Spin ViewModifiers
// Each modifier owns its own .animation() so neither overrides the other.

private struct SpinX: ViewModifier {
    let move: Bool
    let dir: CGFloat
    let speed: Double

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(move ? 360 : 0), axis: (x: dir, y: 0, z: 0))
            .animation(.linear(duration: speed).repeatForever(autoreverses: false), value: move)
    }
}

private struct SpinZ: ViewModifier {
    let move: Bool
    let dir: CGFloat
    let speed: Double
    let anchor: CGFloat

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(move ? 360 : 0), axis: (x: 0, y: 0, z: dir),
                              anchor: UnitPoint(x: anchor, y: anchor))
            .animation(.linear(duration: speed).repeatForever(autoreverses: false), value: move)
    }
}

// MARK: - Animation Views

struct ConfettiAnimationView: View {
    let shape: AnyView
    let color: Color
    let spinDirX: CGFloat
    let spinDirZ: CGFloat
    let spinDuration: Double
    @State var move = false
    // Bug fix: moved out of body into @State so values are stable across re-renders
    @State private var xSpeed: Double
    @State private var zSpeed: Double
    @State private var anchor: CGFloat

    init(shape: AnyView, color: Color, spinDirX: CGFloat, spinDirZ: CGFloat, spinDuration: Double) {
        self.shape = shape; self.color = color
        self.spinDirX = spinDirX; self.spinDirZ = spinDirZ; self.spinDuration = spinDuration
        _xSpeed = State(initialValue: spinDuration * Double.random(in: 0.5...1.0))
        _zSpeed = State(initialValue: spinDuration * Double.random(in: 0.5...1.0))
        _anchor = State(initialValue: CGFloat.random(in: 0...1).rounded())
    }

    var body: some View {
        shape.foregroundColor(color)
            .modifier(SpinX(move: move, dir: spinDirX, speed: xSpeed))
            .modifier(SpinZ(move: move, dir: spinDirZ, speed: zSpeed, anchor: anchor))
            .onAppear { move = true }
    }
}

struct ConfettiPiece: View {
    @State var location: CGPoint = .zero
    @State var opacity: Double = 0
    @ObservedObject var config: ConfettiConfig
    // Fixed: use State(initialValue:) in init so shape/color/dir are stable from
    // the very first render. The previous nil→shape transition caused AnyView to
    // wrap different underlying types across renders, which made SwiftUI destroy
    // and recreate ConfettiAnimationView, resetting `move` and killing spin.
    @State private var pieceShape: AnyView
    @State private var pieceColor: Color
    @State private var spinDirX: CGFloat
    @State private var spinDirZ: CGFloat

    init(config: ConfettiConfig) {
        self._config = ObservedObject(wrappedValue: config)
        _pieceShape = State(initialValue: config.shapes.randomElement() ?? AnyView(Circle()))
        _pieceColor = State(initialValue: config.colors.randomElement() ?? .blue)
        _spinDirX   = State(initialValue: [-1.0, 1.0].randomElement()!)
        _spinDirZ   = State(initialValue: [-1.0, 1.0].randomElement()!)
    }

    func randomVariation() -> CGFloat { CGFloat((0...999).randomElement()!) / 2100 }
    func animDuration() -> CGFloat { 0.2 + config.explosionAnimationDuration + randomVariation() }
    func getAnimation() -> Animation { .timingCurve(0.1, 0.8, 0, 1, duration: animDuration()) }
    func getDistance() -> CGFloat { pow(CGFloat.random(in: 0.01...1), 2.0/7.0) * config.radius }
    func delayBeforeRain() -> TimeInterval { config.explosionAnimationDuration * 0.1 }

    var body: some View {
        ConfettiAnimationView(
            shape: pieceShape,
            color: pieceColor,
            spinDirX: spinDirX,
            spinDirZ: spinDirZ,
            spinDuration: config.rainAnimationDuration * 0.4
        )
        .offset(x: location.x, y: location.y)
        .opacity(opacity)
        .onAppear {
            withAnimation(getAnimation()) {
                opacity = config.opacity
                let lo = config.openingAngle.degrees
                let hi = config.closingAngle.degrees
                let angle: CGFloat = lo <= hi
                    ? CGFloat.random(in: CGFloat(lo)...CGFloat(hi))
                    : CGFloat.random(in: CGFloat(lo)...CGFloat(hi + 360)).truncatingRemainder(dividingBy: 360)
                let d = getDistance()
                location.x = d * cos(angle * .pi / 180)
                location.y = -d * sin(angle * .pi / 180)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delayBeforeRain()) {
                withAnimation(.timingCurve(0.12, 0, 0.39, 0, duration: config.rainAnimationDuration)) {
                    location.y += config.rainHeight
                    opacity = config.fadesOut ? 0 : config.opacity
                }
            }
        }
    }
}

struct ConfettiContainer: View {
    @Binding var finishedAnimationCounter: Int
    @ObservedObject var config: ConfettiConfig
    @State var firstAppear = true

    var body: some View {
        ZStack {
            ForEach(0..<config.num, id: \.self) { _ in ConfettiPiece(config: config) }
        }
        .onAppear {
            guard firstAppear else { return }
            firstAppear = false
            DispatchQueue.main.asyncAfter(deadline: .now() + config.animationDuration) {
                finishedAnimationCounter += 1
            }
        }
    }
}

// MARK: - Cannon

struct ConfettiCannon<T: Equatable>: View {
    @Binding var trigger: T
    @ObservedObject private var config: ConfettiConfig
    @State var animate: [Bool] = []
    @State var finishedAnimationCounter = 0
    @State var firstAppear = false

    init(trigger: Binding<T>,
         num: Int = 20,
         confettis: [ConfettiType] = ConfettiType.allCases,
         colors: [Color] = [.blue, .red, .green, .yellow, .pink, .purple, .orange],
         confettiSize: CGFloat = 10,
         rainHeight: CGFloat = 600,
         fadesOut: Bool = true,
         opacity: Double = 1.0,
         openingAngle: Angle = .degrees(60),
         closingAngle: Angle = .degrees(120),
         radius: CGFloat = 300,
         repetitions: Int = 1,
         repetitionInterval: Double = 1.0,
         hapticFeedback: Bool = true,
         spinSpeedMultiplier: Double = 1.0) {
        self._trigger = trigger
        var shapes = [AnyView]()
        for confetti in confettis {
            for color in colors {
                switch confetti {
                case .shape:
                    shapes.append(AnyView(confetti.view.foregroundColor(color)
                        .frame(width: confettiSize, height: confettiSize)))
                default:
                    shapes.append(AnyView(confetti.view.foregroundColor(color)
                        .font(.system(size: confettiSize))))
                }
            }
        }
        _config = ObservedObject(wrappedValue: ConfettiConfig(
            num: num, shapes: shapes, colors: colors, confettiSize: confettiSize,
            rainHeight: rainHeight, fadesOut: fadesOut, opacity: opacity,
            openingAngle: openingAngle, closingAngle: closingAngle,
            radius: radius, repetitions: repetitions,
            repetitionInterval: repetitionInterval, hapticFeedback: hapticFeedback,
            spinSpeedMultiplier: spinSpeedMultiplier
        ))
    }

    var body: some View {
        ZStack {
            ForEach(finishedAnimationCounter..<animate.count, id: \.self) { i in
                ConfettiContainer(finishedAnimationCounter: $finishedAnimationCounter, config: config)
            }
        }
        .onAppear { firstAppear = true }
        .onChange(of: trigger) { _ in
            guard firstAppear else { return }
            for i in 0..<config.repetitions {
                DispatchQueue.main.asyncAfter(deadline: .now() + config.repetitionInterval * Double(i)) {
                    animate.append(false)
                    if config.hapticFeedback {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    }
                }
            }
        }
    }
}

// MARK: - View Modifier

extension View {
    func confettiCannon<T: Equatable>(
        trigger: Binding<T>,
        num: Int = 20,
        confettis: [ConfettiType] = ConfettiType.allCases,
        colors: [Color] = [.blue, .red, .green, .yellow, .pink, .purple, .orange],
        confettiSize: CGFloat = 10,
        rainHeight: CGFloat = 600,
        fadesOut: Bool = true,
        opacity: Double = 1.0,
        openingAngle: Angle = .degrees(60),
        closingAngle: Angle = .degrees(120),
        radius: CGFloat = 300,
        repetitions: Int = 1,
        repetitionInterval: Double = 1.0,
        hapticFeedback: Bool = true,
        spinSpeedMultiplier: Double = 1.0
    ) -> some View {
        ZStack {
            self.layoutPriority(1)
            ConfettiCannon(
                trigger: trigger, num: num, confettis: confettis, colors: colors,
                confettiSize: confettiSize, rainHeight: rainHeight, fadesOut: fadesOut,
                opacity: opacity, openingAngle: openingAngle, closingAngle: closingAngle,
                radius: radius, repetitions: repetitions,
                repetitionInterval: repetitionInterval, hapticFeedback: hapticFeedback,
                spinSpeedMultiplier: spinSpeedMultiplier
            )
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var trigger = 0
        var body: some View {
            Button("Fire!") { trigger += 1 }
                .confettiCannon(trigger: $trigger, num: 40,
                    colors: [.purple, .red, .teal, .yellow, .orange, .pink],
                    openingAngle: .degrees(60), closingAngle: .degrees(120), radius: 300)
        }
    }
    return PreviewWrapper()
}
