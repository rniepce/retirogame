import SwiftUI

/// Gol de falta: deslize o dedo para chutar. A velocidade do gesto dá a força
/// e a curvatura do traço faz a bola contornar a barreira. 5 cobranças.
final class FreeKickEngine: MiniEngine {
    static let total = 5
    static let flightTime = 0.85

    struct Shot {
        var t: Double = 0
        let targetX: Double
        let curve: Double
        let power: Double
        let outcome: Outcome
    }
    enum Outcome { case goal(Int), saved, blocked, out, over, post }

    private(set) var kick = 0
    private(set) var score = 0
    private(set) var shot: Shot?
    private(set) var trail: [CGPoint] = []
    private(set) var keeperDive: Double = 0   // -1..1 lado do mergulho
    private var nextReady = 0.0

    var ballStart: CGPoint { CGPoint(x: viewSize.width / 2, y: viewSize.height * 0.82) }
    var goalLineY: Double { viewSize.height * 0.24 }
    var goalHalf: Double { viewSize.width * 0.31 }
    var wallY: Double { viewSize.height * 0.52 }

    override func didStart() {
        setHUD("⚽ 1/\(Self.total) · 0 pts")
        say("Deslize para chutar — curve o traço!", for: 2.2)
    }

    override func tick(dt: Double) {
        guard var s = shot else { return }
        s.t += dt / Self.flightTime
        if s.t >= 1 {
            shot = nil
            resolve(s)
        } else {
            shot = s
        }
    }

    override func dragChanged(start: CGPoint, current: CGPoint) {
        guard shot == nil, kick < Self.total, elapsed >= nextReady else { return }
        trail.append(current)
        if trail.count > 40 { trail.removeFirst() }
    }

    override func dragEnded(start: CGPoint, current: CGPoint) {
        defer { trail = [] }
        guard shot == nil, kick < Self.total, elapsed >= nextReady, viewSize != .zero else { return }
        let dx = current.x - start.x, dy = current.y - start.y
        guard dy < -40 else { return }
        let h = viewSize.height, w = viewSize.width
        let length = hypot(dx, dy)
        let power = min(max(length / (h * 0.5), 0.25), 1.0)

        // curvatura: desvio lateral do meio do traço em relação à corda
        var curve: Double = 0
        if trail.count > 4 {
            let mid = trail[trail.count / 2]
            let mx = Double(mid.x - start.x)
            let my = Double(mid.y - start.y)
            let ddx = Double(dx)
            let ddy = Double(dy)
            let len2 = max(Double(length * length), 1)
            let t = (mx * ddx + my * ddy) / len2
            let offX = mx - ddx * t
            let offY = my - ddy * t
            let cross = offX * ddy - offY * ddx
            let side: Double = cross >= 0 ? 1 : -1
            let amount = min(1, hypot(offX, offY) / (Double(w) * 0.18))
            curve = amount * side
        }

        let baseX = Double(ballStart.x) + Double(dx) * 1.6
        let curveShift = curve * Double(w) * 0.30
        let targetX = baseX + curveShift
        let outcome = judge(targetX: targetX, curve: curve, power: Double(power))
        kick += 1
        keeperDive = targetX < viewSize.width / 2 ? -1 : 1
        shot = Shot(targetX: targetX, curve: curve, power: power, outcome: outcome)
        Haptics.tap()
    }

    private func judge(targetX: Double, curve: Double, power: Double) -> Outcome {
        let w = viewSize.width
        let center = w / 2
        if power > 0.92 { return .over }
        // barreira pega bola baixa e sem curva pelo meio
        let wallHalf = Double(w) * 0.14
        let straightX = Double(ballStart.x) + (targetX - Double(ballStart.x)) * 0.45
        let bendAtWall = curve * Double(w) * 0.30 * sin(Double.pi * 0.45)
        let xAtWall = straightX - bendAtWall
        if abs(xAtWall - Double(center)) < wallHalf && power < 0.58 && abs(curve) < 0.35 {
            return .blocked
        }
        let off = abs(targetX - center)
        if abs(off - goalHalf) < 9 { return .post }
        if off > goalHalf { return .out }
        // goleiro: chute forte no canto é indefensável
        let reach = goalHalf * (1.18 - power)
        if off < reach { return .saved }
        return .goal(off > goalHalf * 0.55 ? 10 : 8)
    }

    private func resolve(_ s: Shot) {
        switch s.outcome {
        case .goal(let pts):
            score += pts
            say(pts == 10 ? "⚽ GOLAÇO NO CANTO! +10" : "⚽ GOL! +8", for: 1.2)
            Haptics.success()
        case .saved: say("🧤 Defendeu!"); Haptics.error()
        case .blocked: say("🧱 Na barreira!"); Haptics.error()
        case .out: say("Pra fora…"); Haptics.error()
        case .over: say("Por cima do gol!"); Haptics.error()
        case .post:
            score += 2
            say("💥 NA TRAVE! +2", for: 1.2)
            Haptics.tap()
        }
        keeperDive = 0
        nextReady = elapsed + 0.7
        setHUD("⚽ \(min(kick + 1, Self.total))/\(Self.total) · \(score) pts")
        if kick >= Self.total {
            let final = score
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
                self?.finish(points: final, maxPoints: Self.total * 10)
            }
        }
    }

    func ballPosition(size: CGSize) -> (CGPoint, Double)? {
        guard let s = shot else { return nil }
        let t = min(s.t, 1)
        let ease = 1 - (1 - t) * (1 - t)
        let startX = Double(ballStart.x)
        let straight = startX + (s.targetX - startX) * ease
        let bend = s.curve * Double(size.width) * 0.30 * sin(Double.pi * t)
        let y = Double(ballStart.y) + (goalLineY - Double(ballStart.y)) * ease
        return (CGPoint(x: straight - bend, y: y), 1 - ease * 0.55)
    }
}

enum FreeKickPainter {
    static func draw(_ e: FreeKickEngine, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height

        // gramado em perspectiva com faixas
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0x5E874A), Color(hex: 0x7FA85E)]),
                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
        for i in 0..<6 {
            let y0 = h * (0.1 + 0.15 * Double(i))
            ctx.fill(Path(CGRect(x: 0, y: y0, width: w, height: h * 0.075)),
                     with: .color(.white.opacity(0.045)))
        }
        // céu atrás do gol
        ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: h * 0.13)),
                 with: .color(Color(hex: 0xA8D4E4)))

        // gol
        let gy = e.goalLineY, gHalf = e.goalHalf
        let postL = w / 2 - gHalf, postR = w / 2 + gHalf
        let barY = gy - h * 0.11
        var net = Path()
        for i in 0...8 {
            let x = postL + (postR - postL) * Double(i) / 8
            net.move(to: CGPoint(x: x, y: barY)); net.addLine(to: CGPoint(x: x, y: gy))
        }
        for i in 0...4 {
            let y = barY + (gy - barY) * Double(i) / 4
            net.move(to: CGPoint(x: postL, y: y)); net.addLine(to: CGPoint(x: postR, y: y))
        }
        ctx.stroke(net, with: .color(.white.opacity(0.5)), lineWidth: 1)
        ctx.stroke(Path { p in
            p.move(to: CGPoint(x: postL, y: gy)); p.addLine(to: CGPoint(x: postL, y: barY))
            p.addLine(to: CGPoint(x: postR, y: barY)); p.addLine(to: CGPoint(x: postR, y: gy))
        }, with: .color(.white), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))

        // goleiro
        let keeperX = w / 2 + e.keeperDive * gHalf * 0.5 * (e.shot.map { min($0.t * 1.6, 1) } ?? 0)
        drawPlayer(&ctx, at: CGPoint(x: keeperX, y: gy - 4), shirt: Color(hex: 0xF2B23E),
                   lean: e.keeperDive * (e.shot.map { min($0.t * 1.4, 1) } ?? 0) * 0.8, scale: 1)

        // barreira (pula durante o voo)
        let jump: Double
        if let s = e.shot, s.t > 0.25 && s.t < 0.65 {
            jump = -sin((s.t - 0.25) / 0.4 * .pi) * 26
        } else { jump = 0 }
        for i in -1...1 {
            drawPlayer(&ctx, at: CGPoint(x: w / 2 + Double(i) * 40, y: e.wallY + jump),
                       shirt: Color(hex: 0x2E4057), lean: 0, scale: 1.25)
        }

        // rastro do dedo
        if e.trail.count > 2 {
            var path = Path()
            path.move(to: e.trail[0])
            for p in e.trail.dropFirst() { path.addLine(to: p) }
            ctx.stroke(path, with: .color(Theme.creme.opacity(0.7)),
                       style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        }

        // bola
        if let (pos, scale) = e.ballPosition(size: size) {
            GamePaint.emoji(&ctx, "⚽", at: pos, size: 46 * scale)
        } else {
            ctx.fill(Path(ellipseIn: CGRect(x: e.ballStart.x - 20, y: e.ballStart.y + 16, width: 40, height: 10)),
                     with: .color(.black.opacity(0.2)))
            GamePaint.emoji(&ctx, "⚽", at: e.ballStart, size: 46)
        }
    }

    private static func drawPlayer(_ ctx: inout GraphicsContext, at p: CGPoint,
                                   shirt: Color, lean: Double, scale: Double) {
        var c = ctx
        c.translateBy(x: p.x, y: p.y)
        c.rotate(by: .radians(lean))
        c.scaleBy(x: scale, y: scale)
        c.fill(Path(roundedRect: CGRect(x: -9, y: -34, width: 18, height: 24), cornerRadius: 6),
               with: .color(shirt))
        c.fill(Path(ellipseIn: CGRect(x: -7, y: -50, width: 14, height: 14)),
               with: .color(Color(hex: 0xE3B181)))
        c.fill(Path(roundedRect: CGRect(x: -8, y: -12, width: 6, height: 12), cornerRadius: 3),
               with: .color(Theme.tinta))
        c.fill(Path(roundedRect: CGRect(x: 2, y: -12, width: 6, height: 12), cornerRadius: 3),
               with: .color(Theme.tinta))
    }
}

struct FreeKickGameView: View {
    let onExit: () -> Void
    let onFinish: (MinigameResult) -> Void
    var body: some View {
        MiniGameHost(engine: FreeKickEngine(), background: Color(hex: 0x5E874A),
                     onExit: onExit, onFinish: onFinish) { e, ctx, size in
            FreeKickPainter.draw(e, &ctx, size)
        }
    }
}
