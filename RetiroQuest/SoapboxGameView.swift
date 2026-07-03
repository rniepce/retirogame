import SwiftUI
import CoreMotion

/// Rolimã: desça a ladeira desviando de cones, pedras e cachorros.
/// Incline o iPhone (ou arraste o dedo) para dirigir. 3 vidas, 40 segundos.
final class SoapboxEngine: MiniEngine {
    struct Obstacle {
        let emoji: String
        let laneX: Double     // 0..1 posição lateral no fim da pista
        var z: Double         // 1 = horizonte, 0 = jogador
        var resolved = false
    }
    static let duration = 40.0
    let avatar: AvatarConfig
    init(avatar: AvatarConfig) { self.avatar = avatar }

    private(set) var obstacles: [Obstacle] = []
    private(set) var lives = 3
    private(set) var passed = 0
    private(set) var playerX = 0.5        // 0..1
    private var targetX = 0.5
    private var tiltX = 0.0
    private var nextSpawn = 1.0
    private var invulnUntil = -1.0
    private let motion = CMMotionManager()

    var isInvulnerable: Bool { elapsed < invulnUntil }

    override func didStart() {
        setHUD("🛞 ❤️❤️❤️ · 40s")
        say("Incline o iPhone ou arraste!", for: 2.4)
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 1.0 / 30.0
            motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
                if let g = data?.gravity { self?.tiltX = g.x }
            }
        }
    }

    override func stop() {
        super.stop()
        motion.stopDeviceMotionUpdates()
    }

    override func tick(dt: Double) {
        let remaining = Self.duration - elapsed
        if remaining <= 0 {
            finishRun(survived: true)
            return
        }
        // direção: inclinação tem prioridade se for significativa
        if abs(tiltX) > 0.04 {
            targetX = min(max(0.5 + tiltX * 2.2, 0.06), 0.94)
        }
        playerX += (targetX - playerX) * min(9 * dt, 1)

        // obstáculos avançam
        let zSpeed = 0.5 + elapsed * 0.012
        for i in obstacles.indices {
            obstacles[i].z -= zSpeed * dt
            if obstacles[i].z <= 0.05 && !obstacles[i].resolved {
                obstacles[i].resolved = true
                if abs(obstacles[i].laneX - playerX) < 0.11 && !isInvulnerable {
                    lives -= 1
                    invulnUntil = elapsed + 1.5
                    say("💥 Bateu!", for: 0.9)
                    Haptics.error()
                    if lives <= 0 {
                        finishRun(survived: false)
                        return
                    }
                } else {
                    passed += 1
                }
            }
        }
        obstacles.removeAll { $0.z <= -0.05 }

        if elapsed >= nextSpawn {
            nextSpawn = elapsed + max(0.65, 1.3 - elapsed * 0.015)
            obstacles.append(Obstacle(emoji: ["🚧", "🪨", "🐕", "🛒"].randomElement()!,
                                      laneX: Double.random(in: 0.12...0.88), z: 1))
        }
        setHUD("🛞 \(String(repeating: "❤️", count: max(lives, 0))) · \(Int(remaining))s")
    }

    override func dragChanged(start: CGPoint, current: CGPoint) {
        guard viewSize.width > 0 else { return }
        targetX = min(max(current.x / viewSize.width, 0.06), 0.94)
    }

    private func finishRun(survived: Bool) {
        let points = passed * 2 + lives * 8
        finish(points: points, maxPoints: (passed + obstacles.count) * 2 + 24,
               phrases: survived ? MiniEngine.defaultPhrases :
                ["A ladeira venceu dessa vez!", "Bom começo!", "Mandou muito bem!", "Perfeito!"])
    }

    /// Projeção pseudo-3D de um obstáculo.
    func project(_ o: Obstacle, size: CGSize) -> (CGPoint, Double) {
        let spread = 1 - o.z * 0.85
        let x = size.width / 2 + (o.laneX - 0.5) * size.width * spread
        let y = size.height * 0.30 + pow(1 - o.z, 1.7) * size.height * 0.52
        return (CGPoint(x: x, y: y), spread)
    }
}

enum SoapboxPainter {
    static func draw(_ e: SoapboxEngine, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height

        // céu e serra no horizonte
        ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: h * 0.30)),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0x8FC4DB), Color(hex: 0xD7EBDF)]),
                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.3)))
        ctx.fill(Path { p in
            p.move(to: CGPoint(x: 0, y: h * 0.30))
            p.addQuadCurve(to: CGPoint(x: w, y: h * 0.30), control: CGPoint(x: w * 0.4, y: h * 0.2))
            p.closeSubpath()
        }, with: .color(Color(hex: 0x2C5A3C)))

        // gramado e pista em trapézio
        ctx.fill(Path(CGRect(x: 0, y: h * 0.30, width: w, height: h * 0.7)),
                 with: .color(Color(hex: 0x7FA85E)))
        var road = Path()
        road.move(to: CGPoint(x: w * 0.42, y: h * 0.30))
        road.addLine(to: CGPoint(x: w * 0.58, y: h * 0.30))
        road.addLine(to: CGPoint(x: w * 1.02, y: h))
        road.addLine(to: CGPoint(x: -w * 0.02, y: h))
        road.closeSubpath()
        ctx.fill(road, with: .color(Theme.areia))
        // faixas centrais rolando
        let scroll = (e.elapsed * 2).truncatingRemainder(dividingBy: 1)
        for i in 0..<6 {
            let f = (Double(i) + scroll) / 6
            let y = h * 0.30 + pow(f, 1.7) * h * 0.7
            let dashW = 4 + f * 14
            ctx.fill(Path(roundedRect: CGRect(x: w / 2 - dashW / 2, y: y, width: dashW, height: 8 + f * 18),
                          cornerRadius: 4),
                     with: .color(Color(hex: 0xC9B091)))
        }

        // obstáculos (de trás para frente)
        for o in e.obstacles.sorted(by: { $0.z > $1.z }) where o.z > 0 {
            let (p, s) = e.project(o, size: size)
            GamePaint.emoji(&ctx, o.emoji, at: p, size: 20 + s * 40)
        }

        // carrinho do jogador
        let px = w / 2 + (e.playerX - 0.5) * w
        let py = h * 0.82
        if !e.isInvulnerable || Int(e.elapsed * 8) % 2 == 0 {
            var c = ctx
            c.translateBy(x: px, y: py)
            c.fill(Path(ellipseIn: CGRect(x: -30, y: 26, width: 60, height: 12)),
                   with: .color(.black.opacity(0.2)))
            c.fill(Path(roundedRect: CGRect(x: -26, y: -6, width: 52, height: 30), cornerRadius: 9),
                   with: .color(e.avatar.clothesColor))
            c.fill(Path(ellipseIn: CGRect(x: -30, y: 16, width: 18, height: 18)), with: .color(Theme.tinta))
            c.fill(Path(ellipseIn: CGRect(x: 12, y: 16, width: 18, height: 18)), with: .color(Theme.tinta))
            c.fill(Path(ellipseIn: CGRect(x: -12, y: -28, width: 24, height: 24)),
                   with: .color(e.avatar.skinColor))
            c.fill(Path(roundedRect: CGRect(x: -14, y: -32, width: 28, height: 11), cornerRadius: 5),
                   with: .color(Theme.terra))   // capacete
        }
    }
}

struct SoapboxGameView: View {
    let avatar: AvatarConfig
    let onExit: () -> Void
    let onFinish: (MinigameResult) -> Void
    var body: some View {
        MiniGameHost(engine: SoapboxEngine(avatar: avatar), background: Color(hex: 0x7FA85E),
                     onExit: onExit, onFinish: onFinish) { e, ctx, size in
            SoapboxPainter.draw(e, &ctx, size)
        }
    }
}
