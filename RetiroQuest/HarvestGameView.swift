import SwiftUI

/// Colheita: as laranjas amadurecem no pé. Toque nas MADURAS (laranja)
/// antes que apodreçam — e não colha as verdes!
final class HarvestEngine: MiniEngine {
    enum FruitState { case empty, green, ripe, rotten }
    struct Fruit {
        var state: FruitState = .empty
        var since: Double = 0
        var stageDuration: Double = 1
    }
    static let duration = 45.0
    static let spots: [CGPoint] = [   // posições relativas dentro da copa
        CGPoint(x: 0.28, y: 0.30), CGPoint(x: 0.5, y: 0.22), CGPoint(x: 0.72, y: 0.30),
        CGPoint(x: 0.2, y: 0.44), CGPoint(x: 0.42, y: 0.40), CGPoint(x: 0.62, y: 0.42),
        CGPoint(x: 0.82, y: 0.46), CGPoint(x: 0.3, y: 0.55), CGPoint(x: 0.52, y: 0.55),
        CGPoint(x: 0.72, y: 0.57),
    ]

    private(set) var fruits = Array(repeating: Fruit(), count: HarvestEngine.spots.count)
    private(set) var picked = 0
    private(set) var ripened = 0
    private(set) var score = 0

    override func didStart() {
        setHUD("🍊 45s · 0")
        say("Colha só as laranjas MADURAS!", for: 2)
        for i in fruits.indices {
            fruits[i].since = -Double.random(in: 0...5)
            fruits[i].stageDuration = Double.random(in: 0.8...2.8)
        }
    }

    override func tick(dt: Double) {
        let remaining = Self.duration - elapsed
        if remaining <= 0 {
            finish(points: score, maxPoints: max(ripened * 10, 10))
            return
        }
        for i in fruits.indices {
            let age = elapsed - fruits[i].since
            switch fruits[i].state {
            case .empty where age > fruits[i].stageDuration:
                fruits[i] = Fruit(state: .green, since: elapsed,
                                  stageDuration: Double.random(in: 1.8...3.0))
            case .green where age > fruits[i].stageDuration:
                fruits[i] = Fruit(state: .ripe, since: elapsed, stageDuration: 2.3)
                ripened += 1
            case .ripe where age > fruits[i].stageDuration:
                fruits[i] = Fruit(state: .rotten, since: elapsed, stageDuration: 1.0)
            case .rotten where age > fruits[i].stageDuration:
                fruits[i] = Fruit(state: .empty, since: elapsed,
                                  stageDuration: Double.random(in: 0.8...2.8))
            default: break
            }
        }
        setHUD("🍊 \(Int(remaining))s · \(score)")
    }

    func fruitCenter(_ i: Int, size: CGSize) -> CGPoint {
        let crown = crownRect(size: size)
        let rel = Self.spots[i]
        return CGPoint(x: crown.minX + crown.width * rel.x,
                       y: crown.minY + crown.height * rel.y)
    }
    func crownRect(size: CGSize) -> CGRect {
        CGRect(x: size.width * 0.08, y: size.height * 0.12,
               width: size.width * 0.84, height: size.height * 0.52)
    }

    override func tap(at p: CGPoint) {
        guard !finished, viewSize != .zero else { return }
        for i in fruits.indices {
            let c = fruitCenter(i, size: viewSize)
            guard hypot(p.x - c.x, p.y - c.y) < 34 else { continue }
            switch fruits[i].state {
            case .ripe:
                score += 10
                picked += 1
                fruits[i] = Fruit(state: .empty, since: elapsed,
                                  stageDuration: Double.random(in: 0.8...2.8))
                say("+10 🧺")
                Haptics.light()
            case .green:
                say("Ainda tá verde!")
                Haptics.error()
            default: break
            }
            return
        }
    }
}

enum HarvestPainter {
    static func draw(_ e: HarvestEngine, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height

        // quintal da casa do ipê (céu em faixas)
        GamePaint.bands(&ctx, rect: CGRect(x: 0, y: 0, width: w, height: h * 0.68),
                        colors: [Color(hex: 0xA8D4E4), Color(hex: 0xC0E0E2), Color(hex: 0xD7EBDF)])
        ctx.fill(Path(CGRect(x: 0, y: h * 0.68, width: w, height: h * 0.32)),
                 with: .color(Color(hex: 0x7FA85E)))

        // tronco e copa
        let crown = e.crownRect(size: size)
        ctx.fill(Path(roundedRect: CGRect(x: w / 2 - 16, y: crown.maxY - 30, width: 32, height: h * 0.72 - crown.maxY + 30),
                      cornerRadius: 10),
                 with: .color(Color(hex: 0x6B4A2B)))
        for blob in [CGRect(x: crown.minX, y: crown.minY + crown.height * 0.18, width: crown.width * 0.55, height: crown.height * 0.75),
                     CGRect(x: crown.minX + crown.width * 0.4, y: crown.minY, width: crown.width * 0.6, height: crown.height * 0.8),
                     CGRect(x: crown.minX + crown.width * 0.15, y: crown.minY + crown.height * 0.05, width: crown.width * 0.6, height: crown.height * 0.7)] {
            ctx.fill(Path(ellipseIn: blob), with: .color(Color(hex: 0x3C6B48)))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: crown.minX + crown.width * 0.2, y: crown.minY + crown.height * 0.1,
                                        width: crown.width * 0.45, height: crown.height * 0.4)),
                 with: .color(Color(hex: 0x4A7D57).opacity(0.8)))

        // frutas
        for i in e.fruits.indices {
            let c = e.fruitCenter(i, size: size)
            switch e.fruits[i].state {
            case .empty: break
            case .green:
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 11, y: c.y - 11, width: 22, height: 22)),
                         with: .color(Color(hex: 0x86A83C)))
            case .ripe:
                let pulse = 1 + sin(e.elapsed * 6) * 0.08
                let r = 14 * pulse
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                         with: .color(Color(hex: 0xF08A24)))
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.4, y: c.y - r * 0.55, width: r * 0.5, height: r * 0.35)),
                         with: .color(.white.opacity(0.35)))
            case .rotten:
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 11, y: c.y - 8, width: 22, height: 20)),
                         with: .color(Color(hex: 0x6E5637)))
            }
        }

        // cesta
        Px.draw(&ctx, Px.basket, at: CGPoint(x: w * 0.82, y: h * 0.8), pixel: 5.4)
        ctx.draw(Text("\(e.picked)").font(Theme.px(12))
            .foregroundColor(Theme.creme),
                 at: CGPoint(x: w * 0.82, y: h * 0.88), anchor: .center)

        GamePaint.timeBar(&ctx, size: size, remaining: HarvestEngine.duration - e.elapsed,
                          total: HarvestEngine.duration)
    }
}

struct HarvestGameView: View {
    let onExit: () -> Void
    let onFinish: (MinigameResult) -> Void
    var body: some View {
        MiniGameHost(engine: HarvestEngine(), background: Color(hex: 0x7FA85E),
                     onExit: onExit, onFinish: onFinish) { e, ctx, size in
            HarvestPainter.draw(e, &ctx, size)
        }
    }
}
