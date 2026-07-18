import SwiftUI

/// Lasershot: alvos acendem na parede da arena em ritmo crescente.
/// Verde = atire (toque). Vermelho = não toque!
final class LaserEngine: MiniEngine {
    struct Target {
        let spot: Int
        let isRed: Bool
        let isGold: Bool
        let born: Double
        let life: Double
    }
    static let duration = 45.0

    private(set) var targets: [Target] = []
    private(set) var score = 0
    private(set) var streak = 0
    private var maxPossible = 0
    private var nextSpawn = 1.2

    override func didStart() {
        setHUD("👾 45s · 0 pts")
        say("Toque nos alvos VERDES!", for: 2)
    }

    func spotCenter(_ i: Int, size: CGSize) -> CGPoint {
        let col = i % 4, row = i / 4
        return CGPoint(x: size.width * (0.16 + 0.2267 * Double(col)),
                       y: size.height * (0.24 + 0.16 * Double(row)))
    }

    override func tick(dt: Double) {
        let remaining = Self.duration - elapsed
        if remaining <= 0 {
            finish(points: score, maxPoints: max(maxPossible, 10))
            return
        }
        // alvo verde que apagou sozinho quebra o combo
        let expired = targets.filter { elapsed - $0.born > $0.life }
        if expired.contains(where: { !$0.isRed }) { streak = 0 }
        targets.removeAll { elapsed - $0.born > $0.life }

        if elapsed >= nextSpawn {
            let difficulty = elapsed / Self.duration
            nextSpawn = elapsed + (1.1 - 0.62 * difficulty)
            let occupied = Set(targets.map(\.spot))
            let free = (0..<12).filter { !occupied.contains($0) }
            if let spot = free.randomElement() {
                let isRed = Double.random(in: 0...1) < 0.25
                let isGold = !isRed && Double.random(in: 0...1) < 0.09
                if !isRed { maxPossible += isGold ? 25 : 10 }
                targets.append(Target(spot: spot, isRed: isRed, isGold: isGold, born: elapsed,
                                      life: (1.6 - 0.85 * difficulty) * (isGold ? 0.55 : 1)))
            }
        }
        let comboTxt = streak >= 3 ? " x\(streak)" : ""
        setHUD("👾 \(Int(remaining))s · \(score)\(comboTxt)")
    }

    override func tap(at p: CGPoint) {
        guard !finished, viewSize != .zero else { return }
        let radius = min(viewSize.width, viewSize.height) * 0.09
        for (i, t) in targets.enumerated() {
            let c = spotCenter(t.spot, size: viewSize)
            if hypot(p.x - c.x, p.y - c.y) < radius * 1.35 {
                targets.remove(at: i)
                if t.isRed {
                    score = max(0, score - 10)
                    streak = 0
                    say("🔴 Alvo proibido! -10")
                    Haptics.error()
                } else if t.isGold {
                    streak += 1
                    score += 25
                    say("⭐ DOURADO! +25")
                    Haptics.success()
                } else {
                    streak += 1
                    let bonus = min(streak - 1, 5) * 2
                    score += 10 + bonus
                    say(streak >= 3 ? "+\(10 + bonus) COMBO x\(streak)!" : "+\(10 + bonus)")
                    Haptics.light()
                }
                return
            }
        }
    }
}

enum LaserPainter {
    static func draw(_ e: LaserEngine, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height

        // parede da arena com grade neon
        GamePaint.bands(&ctx, rect: CGRect(origin: .zero, size: size),
                        colors: [Color(hex: 0x232A47), Color(hex: 0x1C2139), Color(hex: 0x14182B)])
        var grid = Path()
        for i in 1..<8 {
            let x = w * Double(i) / 8
            grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: h))
        }
        for i in 1..<12 {
            let y = h * Double(i) / 12
            grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: w, y: y))
        }
        ctx.stroke(grid, with: .color(Color(hex: 0x7CE0D6).opacity(0.08)), lineWidth: 1)

        // piso com grade em perspectiva
        ctx.fill(Path(CGRect(x: 0, y: h * 0.82, width: w, height: h * 0.18)),
                 with: .color(Color(hex: 0x101425)))
        var floorGrid = Path()
        for i in 0..<7 {
            let t = Double(i) / 6
            floorGrid.move(to: CGPoint(x: w * t, y: h * 0.82))
            floorGrid.addLine(to: CGPoint(x: w * 0.5 + (w * t - w * 0.5) * 2.2, y: h))
        }
        ctx.stroke(floorGrid, with: .color(Color(hex: 0x7CE0D6).opacity(0.15)), lineWidth: 1.5)
        ctx.stroke(Path { p in
            p.move(to: CGPoint(x: 0, y: h * 0.82)); p.addLine(to: CGPoint(x: w, y: h * 0.82))
        }, with: .color(Color(hex: 0x7CE0D6).opacity(0.5)), lineWidth: 2)

        // moldura neon pulsante + poeira ciano subindo
        let pulse = 0.25 + 0.18 * sin(e.elapsed * 3)
        ctx.stroke(Path(CGRect(x: 7, y: 7, width: w - 14, height: h - 14)),
                   with: .color(Color(hex: 0x7CE0D6).opacity(pulse)), lineWidth: 3)
        GamePaint.motes(&ctx, size: size, now: e.elapsed, count: 10,
                        color: Color(hex: 0x7CE0D6).opacity(0.4), rise: true)
        // interferência de CRT ocasional
        if sin(e.elapsed * 7.3) > 0.96 {
            let gy = (e.elapsed * 431).truncatingRemainder(dividingBy: h)
            ctx.fill(Path(CGRect(x: 0, y: gy, width: w, height: 2.5)),
                     with: .color(.white.opacity(0.12)))
        }

        let radius = min(w, h) * 0.09
        // soquetes
        for i in 0..<12 {
            let c = e.spotCenter(i, size: size)
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius,
                                              width: radius * 2, height: radius * 2)),
                       with: .color(Color(hex: 0x39406B)), lineWidth: 2)
        }
        // alvos acesos
        for t in e.targets {
            let c = e.spotCenter(t.spot, size: size)
            let progress = min(1, (e.elapsed - t.born) / t.life)
            let color = t.isRed ? Color(hex: 0xE8503A) : (t.isGold ? Theme.ouro : Color(hex: 0x5BE86E))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius,
                                            width: radius * 2, height: radius * 2)),
                     with: .color(color.opacity(0.25)))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - radius * 0.62, y: c.y - radius * 0.62,
                                            width: radius * 1.24, height: radius * 1.24)),
                     with: .color(color))
            if t.isGold {
                Px.draw(&ctx, Px.star, at: c, pixel: radius * 0.1,
                        colors: Px.tinted(["Y": Theme.tinta]))
            } else {
                Px.draw(&ctx, t.isRed ? Px.cross : Px.plus, at: c, pixel: radius * 0.1,
                        colors: Px.tinted(["W": Theme.tinta]))
            }
            // anel do tempo restante
            var ring = Path()
            ring.addArc(center: c, radius: radius * 0.95,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(-90 + 360 * (1 - progress)), clockwise: false)
            ctx.stroke(ring, with: .color(Theme.creme), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }

        GamePaint.timeBar(&ctx, size: size, remaining: LaserEngine.duration - e.elapsed,
                          total: LaserEngine.duration)
    }
}

struct LaserGameView: View {
    let onExit: () -> Void
    let onFinish: (MinigameResult) -> Void
    var body: some View {
        MiniGameHost(engine: LaserEngine(), background: Color(hex: 0x14182B),
                     onExit: onExit, onFinish: onFinish) { e, ctx, size in
            LaserPainter.draw(e, &ctx, size)
        }
    }
}
