import SwiftUI

/// Pipa no Mirante: guie a pipa com o dedo, resista às rajadas de vento
/// e colete as estrelas. Não deixe a pipa cair!
final class KiteEngine: MiniEngine {
    static let duration = 60.0
    static let maxStars = 8
    let avatar: AvatarConfig
    init(avatar: AvatarConfig) { self.avatar = avatar }

    private(set) var kite = CGPoint.zero
    private(set) var velocity = CGVector.zero
    private(set) var starPos: CGPoint?
    private(set) var starsCollected = 0
    private(set) var crashed = false
    private var finger: CGPoint?
    private var gustAt = 5.0
    private var gustUntil = -1.0
    private var gustForce = 0.0
    private var nextStarAt = 1.5
    private var started = false

    var gustWarning: Bool { elapsed > gustAt - 0.7 && elapsed < gustAt }
    var gustActive: Bool { elapsed < gustUntil }
    var gustDirection: Double { gustForce > 0 ? 1 : -1 }

    override func didStart() {
        setHUD("🪁 ⭐0 · 60s")
        say("Guie a pipa com o dedo!", for: 2.2)
    }

    override func tick(dt: Double) {
        if viewSize == .zero { return }
        if !started {
            started = true
            kite = CGPoint(x: viewSize.width / 2, y: viewSize.height * 0.3)
        }
        let remaining = Self.duration - elapsed
        if remaining <= 0 {
            finish(points: starsCollected * 10 + 20, maxPoints: Self.maxStars * 10 + 20)
            return
        }

        // vento base + rajadas
        var windX = sin(elapsed * 0.5) * 26 + sin(elapsed * 1.3) * 12
        if gustActive { windX += gustForce }
        if elapsed >= gustAt && gustUntil < elapsed {
            gustUntil = elapsed + 1.2
            gustForce = (Bool.random() ? 1 : -1) * Double.random(in: 130...210)
            gustAt = elapsed + Double.random(in: 3.5...6.5)
            say("💨 Rajada!", for: 0.8)
            Haptics.tap()
        }

        // controle: acelera em direção ao dedo; sem dedo, afunda
        if let f = finger {
            velocity.dx += (f.x - kite.x) * 4.2 * dt
            velocity.dy += (f.y - kite.y) * 4.2 * dt
        } else {
            velocity.dy += 55 * dt
        }
        velocity.dx += windX * dt
        velocity.dx *= pow(0.42, dt)
        velocity.dy *= pow(0.42, dt)
        kite.x += velocity.dx * dt
        kite.y += velocity.dy * dt

        // limites laterais e teto: quica de leve
        if kite.x < 24 { kite.x = 24; velocity.dx = abs(velocity.dx) * 0.4 }
        if kite.x > viewSize.width - 24 { kite.x = viewSize.width - 24; velocity.dx = -abs(velocity.dx) * 0.4 }
        if kite.y < 70 { kite.y = 70; velocity.dy = abs(velocity.dy) * 0.4 }
        // chão: caiu
        if kite.y > viewSize.height * 0.72 {
            crashed = true
            finish(points: starsCollected * 10, maxPoints: Self.maxStars * 10 + 20,
                   phrases: ["A pipa caiu no mato!", "Bom começo!", "Mandou muito bem!", "Dono do céu!"])
            Haptics.error()
            return
        }

        // estrelas
        if starPos == nil && starsCollected < Self.maxStars && elapsed >= nextStarAt {
            starPos = CGPoint(x: Double.random(in: viewSize.width * 0.15...viewSize.width * 0.85),
                              y: Double.random(in: 90...viewSize.height * 0.5))
        }
        if let s = starPos, hypot(s.x - kite.x, s.y - kite.y) < 42 {
            starPos = nil
            starsCollected += 1
            nextStarAt = elapsed + 1.2
            say("⭐ +10", for: 0.6)
            Haptics.success()
        }

        setHUD("🪁 ⭐\(starsCollected) · \(Int(remaining))s")
    }

    override func dragChanged(start: CGPoint, current: CGPoint) { finger = current }
    override func dragEnded(start: CGPoint, current: CGPoint) { finger = nil }
    override func tap(at p: CGPoint) { finger = nil }
}

enum KitePainter {
    static func draw(_ e: KiteEngine, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height

        // céu
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0x6FB6D8), Color(hex: 0xC9E6EC)]),
                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.75)))
        GamePaint.emoji(&ctx, "☀️", at: CGPoint(x: w * 0.85, y: h * 0.1), size: 46)
        for (i, cy) in [0.16, 0.3, 0.44].enumerated() {
            let drift = (e.elapsed * (10 + Double(i) * 6)).truncatingRemainder(dividingBy: w + 160) - 80
            GamePaint.emoji(&ctx, "☁️", at: CGPoint(x: drift, y: h * cy), size: 40 + Double(i) * 10)
        }

        // serra e mirante
        var serra = Path()
        serra.move(to: CGPoint(x: 0, y: h * 0.78))
        serra.addQuadCurve(to: CGPoint(x: w * 0.55, y: h * 0.8), control: CGPoint(x: w * 0.3, y: h * 0.7))
        serra.addQuadCurve(to: CGPoint(x: w, y: h * 0.76), control: CGPoint(x: w * 0.8, y: h * 0.72))
        serra.addLine(to: CGPoint(x: w, y: h)); serra.addLine(to: CGPoint(x: 0, y: h))
        serra.closeSubpath()
        ctx.fill(serra, with: .color(Color(hex: 0x2C5A3C)))
        ctx.fill(Path(roundedRect: CGRect(x: w * 0.08, y: h * 0.74, width: 90, height: 14),
                      cornerRadius: 4),
                 with: .color(Color(hex: 0x8A6238)))

        // aviso de rajada
        if e.gustWarning || e.gustActive {
            let dir = e.gustDirection
            let baseX = dir > 0 ? w * 0.12 : w * 0.88
            for i in 0..<3 {
                let off = Double(i) * 26 * dir + sin(e.elapsed * 10) * 5
                ctx.draw(Text("〰️").font(.system(size: 26)),
                         at: CGPoint(x: baseX + off, y: h * 0.22 + Double(i) * 20), anchor: .center)
            }
        }

        // estrela
        if let s = e.starPos {
            let pulse = 1 + sin(e.elapsed * 5) * 0.15
            GamePaint.emoji(&ctx, "⭐", at: s, size: 36 * pulse)
        }

        // linha do mirante até a pipa (com barriga)
        let anchor = CGPoint(x: w * 0.14, y: h * 0.74)
        ctx.stroke(Path { p in
            p.move(to: anchor)
            p.addQuadCurve(to: e.kite, control: CGPoint(x: (anchor.x + e.kite.x) / 2,
                                                        y: max(anchor.y, e.kite.y) + 40))
        }, with: .color(.white.opacity(0.7)), lineWidth: 1.5)

        // pipa (losango na cor da roupa) com rabiola
        let tiltK = max(-0.5, min(0.5, e.velocity.dx / 220))
        var c = ctx
        c.translateBy(x: e.kite.x, y: e.kite.y)
        c.rotate(by: .radians(tiltK))
        var tail = Path()
        tail.move(to: CGPoint(x: 0, y: 26))
        for i in 1...4 {
            let ty = 26 + Double(i) * 18
            tail.addQuadCurve(to: CGPoint(x: 0, y: ty),
                              control: CGPoint(x: sin(e.elapsed * 6 + Double(i)) * 14, y: ty - 9))
        }
        c.stroke(tail, with: .color(.white.opacity(0.8)), lineWidth: 2)
        for (i, ty) in [40.0, 66.0].enumerated() {
            GamePaint.emoji(&c, "🎀", at: CGPoint(x: sin(e.elapsed * 6 + Double(i + 1)) * 10, y: ty), size: 12)
        }
        c.fill(Path { p in
            p.move(to: CGPoint(x: 0, y: -30)); p.addLine(to: CGPoint(x: 22, y: 0))
            p.addLine(to: CGPoint(x: 0, y: 26)); p.addLine(to: CGPoint(x: -22, y: 0))
            p.closeSubpath()
        }, with: .color(e.avatar.clothesColor))
        c.stroke(Path { p in
            p.move(to: CGPoint(x: 0, y: -30)); p.addLine(to: CGPoint(x: 0, y: 26))
            p.move(to: CGPoint(x: -22, y: 0)); p.addLine(to: CGPoint(x: 22, y: 0))
        }, with: .color(.white.opacity(0.6)), lineWidth: 2)
    }
}

struct KiteGameView: View {
    let avatar: AvatarConfig
    let onExit: () -> Void
    let onFinish: (MinigameResult) -> Void
    var body: some View {
        MiniGameHost(engine: KiteEngine(avatar: avatar), background: Color(hex: 0x6FB6D8),
                     onExit: onExit, onFinish: onFinish) { e, ctx, size in
            KitePainter.draw(e, &ctx, size)
        }
    }
}
