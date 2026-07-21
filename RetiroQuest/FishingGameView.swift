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
    /// A sombra do peixe aparece rondando a boia pouco antes da fisgada real.
    var biteSoon: Bool {
        phase == .waiting && biteAt - elapsed < 1.3 && biteAt - elapsed > 0
    }

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
                // máx 68: fisgar as 8 (mesmo só comuns, 56 pts) já garante 3 estrelas
                if castsLeft == 0 { finish(points: min(score, 68), maxPoints: 68) }
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
            // beliscadas falsas nunca coexistem com a sombra: a sombra é sinal confiável
            fakes = (0..<Int.random(in: 0...2)).map { _ in
                Double.random(in: elapsed + 0.8...max(biteAt - 1.5, elapsed + 0.9))
            }.filter { $0 < biteAt - 1.3 }
            say("Espera…", for: 0.8)
            Haptics.light()
        case .waiting:
            phase = .showing
            showUntil = elapsed + 0.9
            say("Puxou cedo — assustou o peixe!")
            Haptics.error()
            consumeCast()
        case .bite:
            // reflexo rápido (< 0,45 s) é a única chance de peixe lendário
            let reaction = elapsed - biteAt
            let legendaryChance = reaction < 0.45 ? 0.2 : 0.0
            let roll = Double.random(in: 0...1)
            let fish: (String, Int) = roll < legendaryChance
                ? ("🐡", 16)
                : (roll < legendaryChance + 0.3 ? ("🐠", 10) : ("🐟", 7))
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

        // amanhecer na serra (faixas chapadas)
        GamePaint.bands(&ctx, rect: CGRect(x: 0, y: 0, width: w, height: h * 0.4),
                        colors: [Color(hex: 0xFAD9A0), Color(hex: 0xE9E2C0), Color(hex: 0xD7EBDF)])
        var serra = Path()
        serra.move(to: CGPoint(x: 0, y: h * 0.38))
        serra.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.34), control: CGPoint(x: w * 0.25, y: h * 0.24))
        serra.addQuadCurve(to: CGPoint(x: w, y: h * 0.37), control: CGPoint(x: w * 0.75, y: h * 0.28))
        serra.addLine(to: CGPoint(x: w, y: h * 0.42)); serra.addLine(to: CGPoint(x: 0, y: h * 0.42))
        serra.closeSubpath()
        ctx.fill(serra, with: .color(Color(hex: 0x2C5A3C)))

        // lago em faixas
        GamePaint.bands(&ctx, rect: CGRect(x: 0, y: h * 0.4, width: w, height: h * 0.6),
                        colors: [Color(hex: 0x4FA7C9), Color(hex: 0x4497BA),
                                 Color(hex: 0x3A8BAC), Color(hex: 0x2F7FA3)])
        for i in 0..<5 {
            let y = h * (0.48 + 0.1 * Double(i))
            let drift = sin(e.elapsed * 0.8 + Double(i)) * 14
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: w * 0.1 + drift, y: y))
                p.addLine(to: CGPoint(x: w * 0.32 + drift, y: y))
            }, with: .color(.white.opacity(0.12)), lineWidth: 2.5)
        }
        // reflexos do sol na água
        GamePaint.shimmer(&ctx, rect: CGRect(x: 0, y: h * 0.44, width: w, height: h * 0.5),
                          now: e.elapsed)
        // ondulações ambientes que se expandem e somem
        for k in 0..<3 {
            let cycle = (e.elapsed * 0.35 + Double(k) * 0.33).truncatingRemainder(dividingBy: 1)
            let (rx, ry) = [(0.22, 0.56), (0.68, 0.7), (0.4, 0.85)][k]
            let radius = 6 + cycle * 26
            ctx.stroke(Path(ellipseIn: CGRect(x: w * rx - radius, y: h * ry - radius * 0.4,
                                              width: radius * 2, height: radius * 0.8)),
                       with: .color(.white.opacity(0.25 * (1 - cycle))), lineWidth: 1.5)
        }
        // vitórias-régias
        for (lx, ly, ls) in [(0.14, 0.62, 46.0), (0.8, 0.5, 34.0)] {
            ctx.fill(Path(ellipseIn: CGRect(x: w * lx, y: h * ly, width: ls, height: ls * 0.4)),
                     with: .color(Color(hex: 0x4E8F5C)))
        }
        // libélula passeando
        let dfx = w * (0.5 + 0.4 * sin(e.elapsed * 0.3))
        let dfy = h * (0.46 + 0.05 * sin(e.elapsed * 1.1))
        ctx.fill(Path(roundedRect: CGRect(x: dfx - 6, y: dfy - 1.5, width: 12, height: 3),
                      cornerRadius: 1.5),
                 with: .color(Color(hex: 0x3FA9C9)))
        let wing = abs(sin(e.elapsed * 14)) * 5
        ctx.fill(Path(ellipseIn: CGRect(x: dfx - 3, y: dfy - 3 - wing, width: 6, height: wing + 2)),
                 with: .color(.white.opacity(0.5)))

        // píer e vara
        ctx.fill(Path(roundedRect: CGRect(x: w * 0.62, y: h * 0.86, width: w * 0.38, height: 26),
                      cornerRadius: 6),
                 with: .color(Color(hex: 0x8A6238)))
        let rodTip = CGPoint(x: w * 0.6, y: h * 0.6)
        ctx.stroke(Path { p in
            p.move(to: CGPoint(x: w * 0.88, y: h * 0.88)); p.addLine(to: rodTip)
        }, with: .color(Color(hex: 0x6B4A2B)), style: StrokeStyle(lineWidth: 5, lineCap: .round))

        // sombra do peixe rondando a boia (aviso de que vem fisgada)
        if e.biteSoon {
            let ang = e.elapsed * 3
            let sc = CGPoint(x: e.bobber.x + cos(ang) * 26, y: e.bobber.y + 14 + sin(ang) * 8)
            ctx.fill(Path(ellipseIn: CGRect(x: sc.x - 14, y: sc.y - 5, width: 28, height: 10)),
                     with: .color(.black.opacity(0.22)))
        }

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
            ctx.draw(Text("TOQUE PARA LANÇAR")
                .font(Theme.px(9))
                .foregroundColor(.white.opacity(0.85)),
                     at: CGPoint(x: e.bobber.x, y: e.bobber.y), anchor: .center)
        }

        // juncos balançando no canto
        for i in 0..<5 {
            let rx = w * 0.03 + Double(i) * 11
            let sway = sin(e.elapsed * 1.4 + Double(i)) * 4
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: rx, y: h * 0.98))
                p.addQuadCurve(to: CGPoint(x: rx + sway, y: h * 0.8),
                               control: CGPoint(x: rx - 2, y: h * 0.89))
            }, with: .color(Color(hex: 0x4E8F5C)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            ctx.fill(Path(roundedRect: CGRect(x: rx + sway - 2.5, y: h * 0.76, width: 5, height: 14),
                          cornerRadius: 2.5),
                     with: .color(Color(hex: 0x8A6238)))
        }

        // peixe fisgado subindo (sprite recolorido por raridade)
        if let (emoji, _) = e.caught {
            let tint: [Character: Color]
            switch emoji {
            case "🐡": tint = Px.tinted(["B": Theme.ouro])
            case "🐠": tint = Px.tinted(["B": Color(hex: 0xF08A24)])
            default: tint = Px.palette
            }
            Px.draw(&ctx, Px.fish, at: CGPoint(x: b.x, y: b.y - 50), pixel: 5.5, colors: tint)
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
