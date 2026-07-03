import SwiftUI

/// Pescaria no lago: toque para lançar, espere a boia AFUNDAR de verdade
/// (as beliscadas enganam!) e toque na hora para fisgar. 8 lançamentos.
final class FishingEngine: MiniEngine {
    enum Phase { case idle, waiting, bite, showing }
    static let total = 8

    private(set) var phase = Phase.idle
    private(set) var castsLeft = FishingEngine.total
    private(set) var score = 0
    private(set) var caught: (String, Int)?    // (emoji, pontos) do último peixe
    private var biteAt = 0.0
    private var biteUntil = 0.0
    private var fakes: [Double] = []
    private var showUntil = 0.0

    var bobber: CGPoint { CGPoint(x: viewSize.width * 0.45, y: viewSize.height * 0.52) }
    var isFakeNow: Bool { fakes.contains { abs(elapsed - $0) < 0.25 } }
    var isBiting: Bool { phase == .bite }

    override func didStart() {
        setHUD("🎣 \(castsLeft) · 0 pts")
        say("Toque para lançar a linha!", for: 2)
    }

    override func tick(dt: Double) {
        switch phase {
        case .waiting:
            if elapsed >= biteAt {
                phase = .bite
                biteUntil = elapsed + 0.7
                Haptics.tap()
            }
        case .bite:
            if elapsed > biteUntil {
                phase = .showing
                showUntil = elapsed + 0.9
                say("Escapou…")
                Haptics.error()
                consumeCast()
            }
        case .showing:
            if elapsed > showUntil {
                caught = nil
                phase = castsLeft > 0 ? .idle : .showing
                if castsLeft == 0 { finish(points: score, maxPoints: 80) }
            }
        case .idle: break
        }
    }

    override func tap(at p: CGPoint) {
        switch phase {
        case .idle:
            guard castsLeft > 0 else { return }
            phase = .waiting
            biteAt = elapsed + Double.random(in: 1.5...4.0)
            fakes = (0..<Int.random(in: 0...2)).map { _ in
                Double.random(in: elapsed + 0.8...max(biteAt - 0.5, elapsed + 0.9))
            }
            say("Espera…", for: 0.8)
            Haptics.light()
        case .waiting:
            phase = .showing
            showUntil = elapsed + 0.9
            say("Puxou cedo — assustou o peixe!")
            Haptics.error()
            consumeCast()
        case .bite:
            let roll = Double.random(in: 0...1)
            let fish: (String, Int) = roll < 0.1 ? ("🐡", 16) : (roll < 0.4 ? ("🐠", 10) : ("🐟", 6))
            caught = fish
            score += fish.1
            phase = .showing
            showUntil = elapsed + 1.1
            say(fish.1 >= 16 ? "🐡 LENDÁRIO! +16" : "Fisgou! +\(fish.1)", for: 1.1)
            Haptics.success()
            consumeCast()
        case .showing: break
        }
    }

    private func consumeCast() {
        castsLeft -= 1
        setHUD("🎣 \(castsLeft) · \(score) pts")
    }
}

enum FishingPainter {
    static func draw(_ e: FishingEngine, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height

        // amanhecer na serra
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0xFAD9A0), Color(hex: 0xD7EBDF)]),
                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.4)))
        var serra = Path()
        serra.move(to: CGPoint(x: 0, y: h * 0.38))
        serra.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.34), control: CGPoint(x: w * 0.25, y: h * 0.24))
        serra.addQuadCurve(to: CGPoint(x: w, y: h * 0.37), control: CGPoint(x: w * 0.75, y: h * 0.28))
        serra.addLine(to: CGPoint(x: w, y: h * 0.42)); serra.addLine(to: CGPoint(x: 0, y: h * 0.42))
        serra.closeSubpath()
        ctx.fill(serra, with: .color(Color(hex: 0x2C5A3C)))

        // lago
        ctx.fill(Path(CGRect(x: 0, y: h * 0.4, width: w, height: h * 0.6)),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0x4FA7C9), Color(hex: 0x2F7FA3)]),
                                       startPoint: CGPoint(x: 0, y: h * 0.4), endPoint: CGPoint(x: 0, y: h)))
        for i in 0..<5 {
            let y = h * (0.48 + 0.1 * Double(i))
            let drift = sin(e.elapsed * 0.8 + Double(i)) * 14
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: w * 0.1 + drift, y: y))
                p.addLine(to: CGPoint(x: w * 0.32 + drift, y: y))
            }, with: .color(.white.opacity(0.12)), lineWidth: 2.5)
        }
        // vitórias-régias
        for (lx, ly, ls) in [(0.14, 0.62, 46.0), (0.8, 0.5, 34.0)] {
            ctx.fill(Path(ellipseIn: CGRect(x: w * lx, y: h * ly, width: ls, height: ls * 0.4)),
                     with: .color(Color(hex: 0x4E8F5C)))
        }

        // píer e vara
        ctx.fill(Path(roundedRect: CGRect(x: w * 0.62, y: h * 0.86, width: w * 0.38, height: 26),
                      cornerRadius: 6),
                 with: .color(Color(hex: 0x8A6238)))
        let rodTip = CGPoint(x: w * 0.6, y: h * 0.6)
        ctx.stroke(Path { p in
            p.move(to: CGPoint(x: w * 0.88, y: h * 0.88)); p.addLine(to: rodTip)
        }, with: .color(Color(hex: 0x6B4A2B)), style: StrokeStyle(lineWidth: 5, lineCap: .round))

        // boia (mexe nas beliscadas, afunda na fisgada)
        var b = e.bobber
        if e.isFakeNow { b.x += sin(e.elapsed * 40) * 3 }
        if e.isBiting { b.y += 12 }
        ctx.stroke(Path { p in
            p.move(to: rodTip)
            p.addQuadCurve(to: b, control: CGPoint(x: (rodTip.x + b.x) / 2, y: min(rodTip.y, b.y) - 10))
        }, with: .color(.white.opacity(0.6)), lineWidth: 1.5)
        if e.phase != .idle {
            if e.isBiting {
                for r in [16.0, 26.0] {
                    ctx.stroke(Path(ellipseIn: CGRect(x: b.x - r, y: b.y - r * 0.4,
                                                      width: r * 2, height: r * 0.8)),
                               with: .color(.white.opacity(0.5)), lineWidth: 2)
                }
            }
            ctx.fill(Path(ellipseIn: CGRect(x: b.x - 9, y: b.y - 9, width: 18, height: 18)),
                     with: .color(.white))
            ctx.fill(Path { p in
                p.addArc(center: CGPoint(x: b.x, y: b.y), radius: 9,
                         startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                p.closeSubpath()
            }, with: .color(Theme.terra))
        } else {
            ctx.draw(Text("toque para lançar 🎯")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.85)),
                     at: CGPoint(x: e.bobber.x, y: e.bobber.y), anchor: .center)
        }

        // peixe fisgado subindo
        if let (emoji, _) = e.caught {
            GamePaint.emoji(&ctx, emoji, at: CGPoint(x: b.x, y: b.y - 50), size: 46)
        }
    }
}

struct FishingGameView: View {
    let onExit: () -> Void
    let onFinish: (MinigameResult) -> Void
    var body: some View {
        MiniGameHost(engine: FishingEngine(), background: Color(hex: 0x2F7FA3),
                     onExit: onExit, onFinish: onFinish) { e, ctx, size in
            FishingPainter.draw(e, &ctx, size)
        }
    }
}
