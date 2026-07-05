import SwiftUI

/// Queimada: três arremessadores tentam te acertar. Arraste para correr
/// e desvie das bolas até o apito final. 3 vidas.
final class DodgeballEngine: MiniEngine {
    struct Ball {
        let fromX: Double
        let targetX: Double
        var t: Double = 0
        let flight: Double
        var resolved = false
    }
    static let duration = 45.0
    let avatar: AvatarConfig
    init(avatar: AvatarConfig) { self.avatar = avatar }

    private(set) var balls: [Ball] = []
    private(set) var lives = 3
    private(set) var nearMisses = 0
    private(set) var playerX = 0.5
    private(set) var heart: (x: Double, t: Double)?   // coração desce; pegue para +1 vida
    private var nextHeart = 12.0
    private var targetX = 0.5
    private var nextThrow = 1.4
    private var invulnUntil = -1.0
    private(set) var throwerWindup = -1   // qual arremessador está armando

    var isInvulnerable: Bool { elapsed < invulnUntil }
    static let throwers = [0.25, 0.5, 0.75]

    override func didStart() {
        setHUD("🥎 ❤️❤️❤️ · 45s")
        say("Arraste para desviar!", for: 2)
    }

    override func tick(dt: Double) {
        let remaining = Self.duration - elapsed
        if remaining <= 0 {
            endGame(survived: true)
            return
        }
        playerX += (targetX - playerX) * min(10 * dt, 1)

        for i in balls.indices {
            balls[i].t += dt / balls[i].flight
            if balls[i].t >= 1 && !balls[i].resolved {
                balls[i].resolved = true
                let dist = abs(balls[i].targetX - playerX)
                if dist < 0.09 && !isInvulnerable {
                    lives -= 1
                    invulnUntil = elapsed + 1.2
                    say("💥 QUEIMOU!", for: 0.9)
                    Haptics.error()
                    if lives <= 0 {
                        endGame(survived: false)
                        return
                    }
                } else if dist < 0.2 {
                    nearMisses += 1
                    say("Uau, de raspão! +2", for: 0.6)
                    Haptics.light()
                }
            }
        }
        balls.removeAll { $0.t > 1.15 }

        // coração recuperador (só quando falta vida)
        if heart == nil, elapsed > nextHeart, lives < 3 {
            heart = (x: Double.random(in: 0.15...0.85), t: 0)
            say("❤️ VIDA EXTRA CAINDO!", for: 1)
        }
        if var hh = heart {
            hh.t += dt / 3.2
            heart = hh
            if hh.t >= 0.97 {
                if abs(hh.x - playerX) < 0.1 {
                    lives = min(3, lives + 1)
                    say("+1 ❤️")
                    Haptics.success()
                }
                heart = nil
                nextHeart = elapsed + 12
            }
        }

        if elapsed >= nextThrow {
            let interval = max(0.75, 1.5 - elapsed * 0.016)
            nextThrow = elapsed + interval
            let from = Self.throwers.randomElement()!
            throwerWindup = Self.throwers.firstIndex(of: from) ?? 0
            let lead = playerX + Double.random(in: -0.12...0.12)
            balls.append(Ball(fromX: from, targetX: min(max(lead, 0.08), 0.92),
                              flight: max(0.65, 1.1 - elapsed * 0.01)))
        }
        setHUD("🥎 \(String(repeating: "❤️", count: max(lives, 0))) · \(Int(remaining))s")
    }

    override func dragChanged(start: CGPoint, current: CGPoint) {
        guard viewSize.width > 0 else { return }
        targetX = min(max(current.x / viewSize.width, 0.08), 0.92)
    }

    private func endGame(survived: Bool) {
        let points = Int(min(elapsed, Self.duration)) + nearMisses * 2 + lives * 5
        let maxPts = Int(Self.duration) + nearMisses * 2 + 15
        finish(points: points, maxPoints: maxPts,
               phrases: survived ? MiniEngine.defaultPhrases :
                ["Queimaram você! Treine a esquiva.", "Bom começo!", "Mandou muito bem!", "Rei da quadra!"])
    }
}

enum DodgeballPainter {
    static func draw(_ e: DodgeballEngine, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height

        // quadra descoberta (faixas chapadas)
        GamePaint.bands(&ctx, rect: CGRect(origin: .zero, size: size),
                        colors: [Color(hex: 0x4E8F5C), Color(hex: 0x478554), Color(hex: 0x3F7A4C)])
        var lines = Path()
        lines.addRect(CGRect(x: w * 0.06, y: h * 0.1, width: w * 0.88, height: h * 0.82))
        lines.move(to: CGPoint(x: w * 0.06, y: h * 0.5)); lines.addLine(to: CGPoint(x: w * 0.94, y: h * 0.5))
        ctx.stroke(lines, with: .color(Theme.creme.opacity(0.7)), lineWidth: 3)

        // arremessadores
        for (i, tx) in DodgeballEngine.throwers.enumerated() {
            let bob = sin(e.elapsed * 3 + Double(i) * 2) * 3
            let windup = e.throwerWindup == i ? -6.0 : 0
            var c = ctx
            c.translateBy(x: w * tx, y: h * 0.18 + bob + windup)
            c.fill(Path(roundedRect: CGRect(x: -11, y: -8, width: 22, height: 28), cornerRadius: 8),
                   with: .color([Color(hex: 0x2E4057), Color(hex: 0x8E5BA6), Color(hex: 0x3FA9C9)][i]))
            c.fill(Path(ellipseIn: CGRect(x: -9, y: -26, width: 18, height: 18)),
                   with: .color(Color(hex: 0xE3B181)))
        }

        // coração descendo
        if let hh = e.heart {
            let y = h * 0.15 + (h * 0.78 - h * 0.15) * hh.t
            Px.draw(&ctx, Px.heart, at: CGPoint(x: w * hh.x, y: y), pixel: 4)
        }

        // bolas em voo
        for b in e.balls where b.t <= 1 {
            let x = w * (b.fromX + (b.targetX - b.fromX) * b.t)
            let y = h * 0.22 + (h * 0.8 - h * 0.22) * b.t - sin(b.t * .pi) * h * 0.1
            Px.draw(&ctx, Px.softball, at: CGPoint(x: x, y: y), pixel: (18 + b.t * 26) / 8)
        }

        // jogador (pisca quando invulnerável)
        if !e.isInvulnerable || Int(e.elapsed * 8) % 2 == 0 {
            var c = ctx
            c.translateBy(x: w * e.playerX, y: h * 0.8)
            c.fill(Path(ellipseIn: CGRect(x: -16, y: 26, width: 32, height: 9)),
                   with: .color(.black.opacity(0.25)))
            if e.avatar.gender == .fem {
                c.fill(Path { p in
                    p.move(to: CGPoint(x: -10, y: -6)); p.addLine(to: CGPoint(x: 10, y: -6))
                    p.addLine(to: CGPoint(x: 14, y: 22)); p.addLine(to: CGPoint(x: -14, y: 22))
                    p.closeSubpath()
                }, with: .color(e.avatar.clothesColor))
            } else {
                c.fill(Path(roundedRect: CGRect(x: -12, y: -6, width: 24, height: 28), cornerRadius: 8),
                       with: .color(e.avatar.clothesColor))
            }
            c.fill(Path(ellipseIn: CGRect(x: -11, y: -28, width: 22, height: 22)),
                   with: .color(e.avatar.skinColor))
            c.fill(Path { p in
                p.addArc(center: CGPoint(x: 0, y: -20), radius: 11,
                         startAngle: .radians(.pi * 1.05), endAngle: .radians(.pi * 1.95),
                         clockwise: false)
                p.closeSubpath()
            }, with: .color(e.avatar.hairSwiftColor))
        }

        GamePaint.timeBar(&ctx, size: size, remaining: DodgeballEngine.duration - e.elapsed,
                          total: DodgeballEngine.duration)
    }
}

struct DodgeballGameView: View {
    let avatar: AvatarConfig
    let onExit: () -> Void
    let onFinish: (MinigameResult) -> Void
    var body: some View {
        MiniGameHost(engine: DodgeballEngine(avatar: avatar), background: Color(hex: 0x3F7A4C),
                     onExit: onExit, onFinish: onFinish) { e, ctx, size in
            DodgeballPainter.draw(e, &ctx, size)
        }
    }
}
