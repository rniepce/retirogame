import SwiftUI

/// Vôlei: a bola vem num arco; toque no momento exato em que ela
/// chega ao anel para fazer o levantamento perfeito. 8 bolas.
final class VolleyEngine: MiniEngine {
    static let total = 8
    static let flight = 1.4

    private(set) var ballIndex = 0
    private(set) var score = 0
    private(set) var ballStart = 1.2
    private(set) var resolved = false
    private var endAt = Double.infinity

    var progress: Double { (elapsed - ballStart) / Self.flight }

    override func didStart() {
        setHUD("🏐 1/\(Self.total) · 0 pts")
        say("Toque quando a bola chegar no anel!", for: 2)
    }

    override func tick(dt: Double) {
        if elapsed > endAt {
            finish(points: score, maxPoints: Self.total * 10)
            return
        }
        guard ballIndex < Self.total else { return }
        if !resolved && progress > 1.15 {
            resolve(gain: 0, message: "Passou direto…")
        }
    }

    override func tap(at p: CGPoint) {
        guard ballIndex < Self.total, !resolved, progress > 0 else { return }
        let error = abs(progress - 1.0)
        if error <= 0.06 { resolve(gain: 10, message: "PERFEITO! +10") }
        else if error <= 0.16 { resolve(gain: 6, message: "Boa! +6") }
        else { resolve(gain: 0, message: progress < 1 ? "Cedo demais!" : "Tarde demais!") }
    }

    private func resolve(gain: Int, message: String) {
        resolved = true
        score += gain
        say(message)
        if gain >= 10 { Haptics.success() } else if gain > 0 { Haptics.light() } else { Haptics.error() }
        ballIndex += 1
        if ballIndex >= Self.total {
            endAt = elapsed + 1.0
        } else {
            ballStart = elapsed + 1.0
            resolved = false
        }
        setHUD("🏐 \(min(ballIndex + 1, Self.total))/\(Self.total) · \(score) pts")
    }

    func contactPoint(size: CGSize) -> CGPoint {
        CGPoint(x: size.width * 0.68, y: size.height * 0.4)
    }
}

enum VolleyPainter {
    static func draw(_ e: VolleyEngine, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height

        // ginásio: parede, telhado e piso de quadra
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0xEFE7D6), Color(hex: 0xDDD2B8)]),
                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
        var beams = Path()
        for i in 0..<5 {
            let y = h * 0.06 + Double(i) * h * 0.045
            beams.move(to: CGPoint(x: 0, y: y)); beams.addLine(to: CGPoint(x: w, y: y))
        }
        ctx.stroke(beams, with: .color(Color(hex: 0xC9B98F)), lineWidth: 3)

        ctx.fill(Path(CGRect(x: 0, y: h * 0.62, width: w, height: h * 0.38)),
                 with: .color(Color(hex: 0xCE9457)))
        ctx.stroke(Path { p in
            p.move(to: CGPoint(x: 0, y: h * 0.62)); p.addLine(to: CGPoint(x: w, y: h * 0.62))
            p.move(to: CGPoint(x: w * 0.15, y: h * 0.62)); p.addLine(to: CGPoint(x: 0, y: h))
            p.move(to: CGPoint(x: w * 0.85, y: h * 0.62)); p.addLine(to: CGPoint(x: w, y: h))
        }, with: .color(Theme.creme.opacity(0.7)), lineWidth: 3)

        // rede à direita
        let netX = w * 0.88
        ctx.stroke(Path { p in
            p.move(to: CGPoint(x: netX, y: h * 0.28)); p.addLine(to: CGPoint(x: netX, y: h * 0.66))
        }, with: .color(Color(hex: 0x6B4A2B)), lineWidth: 5)
        var net = Path()
        for i in 0..<5 {
            let y = h * 0.30 + Double(i) * 0.02 * h
            net.move(to: CGPoint(x: netX - 26, y: y)); net.addLine(to: CGPoint(x: netX + 8, y: y))
        }
        ctx.stroke(net, with: .color(Theme.tinta.opacity(0.5)), lineWidth: 1.5)

        let contact = e.contactPoint(size: size)
        let t = e.progress

        // anel de timing (encolhe conforme a bola chega)
        if t > 0 && t < 1.1 && !e.resolved {
            let r = 18 + max(0, 1 - t) * 60
            ctx.stroke(Path(ellipseIn: CGRect(x: contact.x - r, y: contact.y - r,
                                              width: r * 2, height: r * 2)),
                       with: .color(Theme.terra), style: StrokeStyle(lineWidth: 4))
        }
        ctx.stroke(Path(ellipseIn: CGRect(x: contact.x - 18, y: contact.y - 18, width: 36, height: 36)),
                   with: .color(Theme.tinta.opacity(0.5)), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))

        // bola em voo
        if t > -0.2 && t < 1.15 {
            let tc = max(0, min(1.1, t))
            let x = -30 + (contact.x + 30) * tc
            let y = h * 0.72 + (contact.y - h * 0.72) * tc - sin(min(tc, 1) * .pi) * h * 0.26
            GamePaint.emoji(&ctx, "🏐", at: CGPoint(x: x, y: y), size: 44)
        }
    }
}

struct VolleyGameView: View {
    let onExit: () -> Void
    let onFinish: (MinigameResult) -> Void
    var body: some View {
        MiniGameHost(engine: VolleyEngine(), background: Color(hex: 0xDDD2B8),
                     onExit: onExit, onFinish: onFinish) { e, ctx, size in
            VolleyPainter.draw(e, &ctx, size)
        }
    }
}
