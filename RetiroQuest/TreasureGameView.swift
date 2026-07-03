import SwiftUI

/// Caça ao Tesouro: um mapa antigo do condomínio, 7 pás e o quente-e-frio.
/// Toque no mapa para cavar; a cor da marca mostra se está perto.
final class TreasureEngine: MiniEngine {
    struct Dig {
        let point: CGPoint    // no espaço do mapa (relativo 0..1)
        let heat: Heat
    }
    enum Heat { case hot, warm, cold, found }

    private(set) var treasure = CGPoint(x: 0.5, y: 0.5)
    private(set) var digs: [Dig] = []
    private(set) var digsLeft = 7
    private(set) var found = false
    private var done = false

    override func didStart() {
        treasure = CGPoint(x: Double.random(in: 0.3...0.92),
                           y: Double.random(in: 0.08...0.92))
        setHUD("⛏️ 7 pás")
        say("Toque no mapa para cavar!", for: 2.2)
    }

    /// Retângulo do mapa na tela (proporção 800×1060, com margens).
    func mapRect(size: CGSize) -> CGRect {
        let inset: CGFloat = 24
        let availW = size.width - inset * 2
        let availH = size.height - 170
        let scale = min(availW / 800, availH / 1060)
        let mw = 800 * scale, mh = 1060 * scale
        return CGRect(x: (size.width - mw) / 2, y: 110, width: mw, height: mh)
    }

    override func tap(at p: CGPoint) {
        guard !done, digsLeft > 0, viewSize != .zero else { return }
        let rect = mapRect(size: viewSize)
        guard rect.contains(p) else { return }
        let rel = CGPoint(x: (p.x - rect.minX) / rect.width,
                          y: (p.y - rect.minY) / rect.height)
        // não deixa cavar na serra (faixa oeste)
        guard rel.x > 0.2 else {
            say("Só pedra na serra!", for: 0.8)
            return
        }
        digsLeft -= 1
        let dist = hypot((rel.x - treasure.x) * 800, (rel.y - treasure.y) * 1060)
        let heat: Heat
        if dist < 55 {
            heat = .found
            found = true
        } else if dist < 130 {
            heat = .hot
            say("🔥 QUENTE!", for: 0.9)
            Haptics.tap()
        } else if dist < 280 {
            heat = .warm
            say("🌤️ Morno…", for: 0.9)
            Haptics.light()
        } else {
            heat = .cold
            say("🧊 Frio!", for: 0.9)
            Haptics.light()
        }
        digs.append(Dig(point: rel, heat: heat))
        setHUD("⛏️ \(digsLeft) pás")

        if found {
            done = true
            say("💰 ACHOU O TESOURO!", for: 1.4)
            Haptics.success()
            let used = 7 - digsLeft
            let stars = used <= 3 ? 3 : (used <= 5 ? 2 : 1)
            let points = digsLeft * 10 + 10
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { [weak self] in
                self?.finish(points: points, maxPoints: 70, stars: stars,
                             phrases: ["", "Achou por um triz!", "Bom faro de pirata!",
                                       "Direto ao ponto — pirata lendário!"])
            }
        } else if digsLeft == 0 {
            done = true
            say("Acabaram as pás…", for: 1.2)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.finish(points: 0, maxPoints: 70, stars: 0,
                             phrases: ["O tesouro continua enterrado!", "", "", ""])
            }
        }
    }
}

enum TreasurePainter {
    static func draw(_ e: TreasureEngine, _ ctx: inout GraphicsContext, _ size: CGSize) {
        // mesa de madeira
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0x8A6238), Color(hex: 0x6B4A2B)]),
                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))

        let rect = e.mapRect(size: size)
        // pergaminho
        ctx.fill(Path(roundedRect: rect.insetBy(dx: -12, dy: -12), cornerRadius: 10),
                 with: .color(Color(hex: 0xE8D9B5)))
        ctx.stroke(Path(roundedRect: rect.insetBy(dx: -12, dy: -12), cornerRadius: 10),
                   with: .color(Color(hex: 0xB59A66)), lineWidth: 3)

        // mapa simplificado do condomínio
        func mp(_ x: Double, _ y: Double) -> CGPoint {   // coords originais 800×1060
            CGPoint(x: rect.minX + x / 800 * rect.width,
                    y: rect.minY + y / 1060 * rect.height)
        }
        ctx.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(Color(hex: 0xD9E4C0)))
        // serra
        var serra = Path()
        serra.move(to: mp(0, 0)); serra.addLine(to: mp(190, 0))
        serra.addQuadCurve(to: mp(90, 800), control: mp(90, 400))
        serra.addQuadCurve(to: mp(80, 1060), control: mp(60, 950))
        serra.addLine(to: mp(0, 1060)); serra.closeSubpath()
        ctx.fill(serra, with: .color(Color(hex: 0x9DB380)))
        // ruas
        var roads = Path()
        roads.move(to: mp(400, 0))
        for (cx, cy, ex, ey) in [(380.0, 140.0, 400.0, 280.0), (430, 420, 400, 560),
                                 (370, 700, 420, 840), (400, 940, 330, 1010)] {
            roads.addQuadCurve(to: mp(ex, ey), control: mp(cx, cy))
        }
        roads.move(to: mp(620, 0))
        for (cx, cy, ex, ey) in [(600.0, 160.0, 630.0, 320.0), (660, 480, 620, 640), (600, 800, 640, 940)] {
            roads.addQuadCurve(to: mp(ex, ey), control: mp(cx, cy))
        }
        ctx.stroke(roads, with: .color(Color(hex: 0xC9B58A)), lineWidth: 5)
        // marcos
        ctx.fill(Path(roundedRect: CGRect(origin: mp(150, 545), size: CGSize(width: rect.width * 0.25, height: rect.height * 0.18)), cornerRadius: 6),
                 with: .color(Color(hex: 0xBBD3AC)))
        ctx.fill(Path(roundedRect: CGRect(origin: mp(165, 565), size: CGSize(width: rect.width * 0.12, height: rect.height * 0.05)), cornerRadius: 4),
                 with: .color(Color(hex: 0x9CC4D4)))
        GamePaint.emoji(&ctx, "⛪", at: mp(331, 985), size: rect.width * 0.06)
        GamePaint.emoji(&ctx, "🌲", at: mp(140, 260), size: rect.width * 0.06)
        GamePaint.emoji(&ctx, "🌲", at: mp(700, 750), size: rect.width * 0.06)
        // rosa dos ventos
        GamePaint.emoji(&ctx, "🧭", at: CGPoint(x: rect.maxX - 26, y: rect.minY + 26), size: 30)

        // escavações
        for dig in e.digs {
            let p = CGPoint(x: rect.minX + dig.point.x * rect.width,
                            y: rect.minY + dig.point.y * rect.height)
            let color: Color
            switch dig.heat {
            case .hot: color = Color(hex: 0xE8503A)
            case .warm: color = Theme.ouro
            case .cold: color = Color(hex: 0x6FB6D8)
            case .found: color = Theme.ouro
            }
            if dig.heat == .found {
                GamePaint.emoji(&ctx, "💰", at: p, size: 40)
            } else {
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)),
                         with: .color(color.opacity(0.35)))
                var xMark = Path()
                xMark.move(to: CGPoint(x: p.x - 6, y: p.y - 6)); xMark.addLine(to: CGPoint(x: p.x + 6, y: p.y + 6))
                xMark.move(to: CGPoint(x: p.x + 6, y: p.y - 6)); xMark.addLine(to: CGPoint(x: p.x - 6, y: p.y + 6))
                ctx.stroke(xMark, with: .color(color), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
        }

        // legenda
        ctx.draw(Text("🔥 perto  ·  🌤️ morno  ·  🧊 longe")
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundColor(Color(hex: 0xE8D9B5)),
                 at: CGPoint(x: size.width / 2, y: rect.maxY + 32), anchor: .center)
    }
}

struct TreasureGameView: View {
    let onExit: () -> Void
    let onFinish: (MinigameResult) -> Void
    var body: some View {
        MiniGameHost(engine: TreasureEngine(), background: Color(hex: 0x6B4A2B),
                     onExit: onExit, onFinish: onFinish) { e, ctx, size in
            TreasurePainter.draw(e, &ctx, size)
        }
    }
}
