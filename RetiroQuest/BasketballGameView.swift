import SwiftUI

/// Basquete: arraste para cima para arremessar. A força certa acerta a
/// distância; o desvio lateral do gesto define a mira. 5 bolas.
final class BasketballEngine: MiniEngine {
    static let total = 5
    static let flightTime = 0.9
    static let sweetPower = 0.72

    struct Shot {
        var t: Double = 0
        let targetX: Double
        let depth: Double     // erro de profundidade (força)
    }
    enum Outcome { case swish, bucket, rim, miss }

    private(set) var ball = 0
    private(set) var score = 0
    private(set) var shot: Shot?
    private var nextReady = 0.0
    private var driftPhase = 0.0

    var ballStart: CGPoint { CGPoint(x: viewSize.width / 2, y: viewSize.height * 0.85) }
    /// A partir da 4ª bola a cesta desliza de um lado para o outro.
    var rimCenter: CGPoint {
        let drift = ball >= 3 ? sin(driftPhase) * viewSize.width * 0.16 : 0
        return CGPoint(x: viewSize.width / 2 + drift, y: viewSize.height * 0.27)
    }

    override func didStart() {
        setHUD("🏀 1/\(Self.total) · 0 pts")
        say("Arraste para cima para arremessar!", for: 2.2)
    }

    override func tick(dt: Double) {
        if ball >= 3 { driftPhase += dt * 1.5 }
        guard var s = shot else { return }
        s.t += dt / Self.flightTime
        if s.t >= 1 {
            shot = nil
            resolve(s)
        } else {
            shot = s
        }
    }

    override func dragEnded(start: CGPoint, current: CGPoint) {
        guard shot == nil, ball < Self.total, elapsed >= nextReady, viewSize != .zero else { return }
        let dx = current.x - start.x, dy = current.y - start.y
        guard dy < -50 else { return }
        let h = viewSize.height
        let power = min(max(hypot(dx, dy) / (h * 0.55), 0.2), 1.2)
        let targetX = ballStart.x + dx * 1.15
        let depth = (power - Self.sweetPower) * h * 0.4
        ball += 1
        shot = Shot(targetX: targetX, depth: depth)
        Haptics.tap()
    }

    private func resolve(_ s: Shot) {
        // resultado julgado na chegada — com a cesta onde ela ESTÁ agora
        let h = viewSize.height
        let offX = abs(s.targetX - rimCenter.x)
        let offD = abs(s.depth)
        let outcome: Outcome
        if offX < 14 && offD < h * 0.045 { outcome = .swish }
        else if offX < 30 && offD < h * 0.09 { outcome = .bucket }
        else if offX < 48 && offD < h * 0.13 { outcome = .rim }
        else { outcome = .miss }
        switch outcome {
        case .swish: score += 10; say("🔥 SÓ REDE! +10", for: 1.1); Haptics.success()
        case .bucket: score += 6; say("🏀 Cesta! +6", for: 1.1); Haptics.success()
        case .rim: score += 2; say("No aro… +2"); Haptics.tap()
        case .miss: say("Errou tudo!"); Haptics.error()
        }
        nextReady = elapsed + 0.6
        if ball == 3 { say("🏀 A CESTA VAI ANDAR!", for: 1.4) }
        setHUD("🏀 \(min(ball + 1, Self.total))/\(Self.total) · \(score) pts")
        if ball >= Self.total {
            let final = score
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.finish(points: final, maxPoints: Self.total * 10)
            }
        }
    }

    func ballPose(size: CGSize) -> (CGPoint, Double)? {
        guard let s = shot else { return nil }
        let t = min(s.t, 1)
        let endY = rimCenter.y + s.depth * 0.3
        let x = ballStart.x + (s.targetX - ballStart.x) * t
        let y = ballStart.y + (endY - ballStart.y) * t - sin(t * .pi) * size.height * 0.34
        return (CGPoint(x: x, y: y), 1 - t * 0.45)
    }
}

enum BasketballPainter {
    static func draw(_ e: BasketballEngine, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height

        // quadra ao entardecer (faixas chapadas)
        GamePaint.bands(&ctx, rect: CGRect(x: 0, y: 0, width: w, height: h * 0.5),
                        colors: [Color(hex: 0xA8D4E4), Color(hex: 0xC0E0E2), Color(hex: 0xD7EBDF)])
        GamePaint.bands(&ctx, rect: CGRect(x: 0, y: h * 0.5, width: w, height: h * 0.5),
                        colors: [Color(hex: 0xC28352), Color(hex: 0xBD7E4E), Color(hex: 0xB8794A)])
        // nuvens do entardecer e alambrado atrás da quadra
        Px.draw(&ctx, Px.cloud, at: CGPoint(x: w * 0.2 + sin(e.elapsed * 0.2) * 10, y: h * 0.09), pixel: 3.5)
        Px.draw(&ctx, Px.cloud, at: CGPoint(x: w * 0.75 + sin(e.elapsed * 0.15) * 12, y: h * 0.16), pixel: 4.5)
        var fence = Path()
        let fenceTop = h * 0.34, fenceBottom = h * 0.5
        for i in 0...12 {
            let x = w * Double(i) / 12
            fence.move(to: CGPoint(x: x - 20, y: fenceTop))
            fence.addLine(to: CGPoint(x: x + 20, y: fenceBottom))
            fence.move(to: CGPoint(x: x + 20, y: fenceTop))
            fence.addLine(to: CGPoint(x: x - 20, y: fenceBottom))
        }
        ctx.stroke(fence, with: .color(Color(hex: 0x57636B).opacity(0.35)), lineWidth: 1.5)
        ctx.stroke(Path { p in
            p.move(to: CGPoint(x: 0, y: fenceTop)); p.addLine(to: CGPoint(x: w, y: fenceTop))
        }, with: .color(Color(hex: 0x57636B).opacity(0.6)), lineWidth: 3)

        // linhas da quadra
        var lines = Path()
        lines.move(to: CGPoint(x: w * 0.1, y: h)); lines.addLine(to: CGPoint(x: w * 0.35, y: h * 0.52))
        lines.move(to: CGPoint(x: w * 0.9, y: h)); lines.addLine(to: CGPoint(x: w * 0.65, y: h * 0.52))
        ctx.stroke(lines, with: .color(Theme.creme.opacity(0.6)), lineWidth: 3)

        // poste, tabela e aro
        let rim = e.rimCenter
        ctx.stroke(Path { p in
            p.move(to: CGPoint(x: rim.x, y: h * 0.52)); p.addLine(to: CGPoint(x: rim.x, y: rim.y - 74))
        }, with: .color(Color(hex: 0x57636B)), lineWidth: 8)
        ctx.fill(Path(roundedRect: CGRect(x: rim.x - 55, y: rim.y - 84, width: 110, height: 70),
                      cornerRadius: 8),
                 with: .color(Theme.creme))
        ctx.stroke(Path(roundedRect: CGRect(x: rim.x - 22, y: rim.y - 46, width: 44, height: 32),
                        cornerRadius: 4),
                   with: .color(Theme.terra), lineWidth: 3)
        // aro
        ctx.stroke(Path(ellipseIn: CGRect(x: rim.x - 30, y: rim.y - 7, width: 60, height: 16)),
                   with: .color(Color(hex: 0xE8671B)), lineWidth: 5)
        // rede
        var net = Path()
        for i in 0...5 {
            let x0 = rim.x - 26 + Double(i) * 10.4
            net.move(to: CGPoint(x: x0, y: rim.y + 4))
            net.addLine(to: CGPoint(x: rim.x - 14 + Double(i) * 5.6, y: rim.y + 42))
        }
        ctx.stroke(net, with: .color(.white.opacity(0.75)), lineWidth: 1.5)

        // bola
        if let (pos, scale) = e.ballPose(size: size) {
            let floorY = h * 0.9
            let airFrac = max(0.2, 1 - (floorY - pos.y) / (h * 0.6))
            ctx.fill(Path(ellipseIn: CGRect(x: pos.x - 16 * airFrac, y: floorY,
                                            width: 32 * airFrac, height: 8 * airFrac)),
                     with: .color(.black.opacity(0.15)))
            Px.draw(&ctx, Px.basketball, at: pos, pixel: 6.5 * scale)
        } else {
            ctx.fill(Path(ellipseIn: CGRect(x: e.ballStart.x - 22, y: e.ballStart.y + 20,
                                            width: 44, height: 10)),
                     with: .color(.black.opacity(0.2)))
            Px.draw(&ctx, Px.basketball, at: e.ballStart, pixel: 6.5)
            // guia de força
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: e.ballStart.x, y: e.ballStart.y - 34))
                p.addLine(to: CGPoint(x: e.ballStart.x, y: e.ballStart.y - 70))
            }, with: .color(Theme.creme.opacity(0.5)), style: StrokeStyle(lineWidth: 3, dash: [6, 8]))
        }
    }
}

struct BasketballGameView: View {
    let onExit: () -> Void
    let onFinish: (MinigameResult) -> Void
    var body: some View {
        MiniGameHost(engine: BasketballEngine(), background: Color(hex: 0xB8794A),
                     onExit: onExit, onFinish: onFinish) { e, ctx, size in
            BasketballPainter.draw(e, &ctx, size)
        }
    }
}
