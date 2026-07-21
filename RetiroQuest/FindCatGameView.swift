import SwiftUI

/// Ache o Gato: cinco gatos se esconderam no quintal — só as orelhas ou o
/// rabo aparecem. Toque neles antes do tempo acabar; erro custa 3 segundos.
final class FindCatEngine: MiniEngine {
    struct Hideout {
        var rel: CGPoint      // posição relativa na tela (com jitter por partida)
        let hint: Hint        // o que fica visível
        var active = false
        var found = false
        var color = Color.orange
    }
    enum Hint { case ears, tail, paw }

    static let duration = 60.0
    static let catColors = [Color(hex: 0xE8963C), Color(hex: 0x2B2B2B),
                            Color(hex: 0xFFF3E0), Color(hex: 0x8C8C94), Color(hex: 0xB3672B)]

    private(set) var hideouts: [Hideout] = [
        Hideout(rel: CGPoint(x: 0.16, y: 0.60), hint: .ears),   // arbusto esq.
        Hideout(rel: CGPoint(x: 0.44, y: 0.66), hint: .paw),    // arbusto centro
        Hideout(rel: CGPoint(x: 0.72, y: 0.62), hint: .ears),   // arbusto dir.
        Hideout(rel: CGPoint(x: 0.30, y: 0.30), hint: .tail),   // janela
        Hideout(rel: CGPoint(x: 0.83, y: 0.35), hint: .tail),   // árvore
        Hideout(rel: CGPoint(x: 0.10, y: 0.82), hint: .ears),   // vaso
        Hideout(rel: CGPoint(x: 0.58, y: 0.47), hint: .paw),    // muro
        Hideout(rel: CGPoint(x: 0.88, y: 0.80), hint: .tail),   // grama alta
    ]
    private(set) var penalty = 0.0
    private(set) var found = 0
    private(set) var meow: (index: Int, until: Double)?
    private var nextMeow = 6.0

    var remaining: Double { Self.duration - elapsed - penalty }

    override func didStart() {
        // posições variam um pouco a cada partida — decorar não resolve
        for i in hideouts.indices {
            hideouts[i].rel.x = min(max(hideouts[i].rel.x + Double.random(in: -0.035...0.035), 0.05), 0.95)
            hideouts[i].rel.y = min(max(hideouts[i].rel.y + Double.random(in: -0.03...0.03), 0.1), 0.92)
        }
        var picks = Set<Int>()
        while picks.count < 5 { picks.insert(Int.random(in: 0..<hideouts.count)) }
        for (n, i) in picks.enumerated() {
            hideouts[i].active = true
            hideouts[i].color = Self.catColors[n]
        }
        setHUD("🐱 0/5 · 60s")
        say("Ache os 5 gatos escondidos!", for: 2.2)
    }

    override func tick(dt: Double) {
        if remaining <= 0 {
            finish(points: found * 10, maxPoints: 50)
            return
        }
        // de tempos em tempos um gato escondido dá um miado de dica
        if elapsed > nextMeow {
            nextMeow = elapsed + 7
            let hidden = hideouts.indices.filter { hideouts[$0].active && !hideouts[$0].found }
            if let i = hidden.randomElement() {
                meow = (i, elapsed + 1.2)
                Haptics.light()
            }
        }
        if let m = meow, elapsed > m.until { meow = nil }
        setHUD("🐱 \(found)/5 · \(Int(remaining))s")
    }

    override func tap(at p: CGPoint) {
        guard !finished, viewSize != .zero else { return }
        for i in hideouts.indices where hideouts[i].active && !hideouts[i].found {
            let c = CGPoint(x: viewSize.width * hideouts[i].rel.x,
                            y: viewSize.height * hideouts[i].rel.y)
            if hypot(p.x - c.x, p.y - c.y) < 42 {
                hideouts[i].found = true
                found += 1
                say("Miau! 🐱 +10")
                Haptics.success()
                if found == 5 {
                    let final = found * 10
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                        self?.finish(points: final, maxPoints: 50)
                    }
                }
                return
            }
        }
        penalty += 3
        say("Nada aqui… -3s", for: 0.7)
        Haptics.error()
    }
}

enum FindCatPainter {
    static func draw(_ e: FindCatEngine, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height

        // céu e casa ao fundo
        ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: h * 0.45)),
                 with: .color(Color(hex: 0xA8D4E4)))
        ctx.fill(Path(CGRect(x: 0, y: h * 0.14, width: w * 0.55, height: h * 0.31)),
                 with: .color(Theme.creme))
        ctx.fill(Path { p in
            p.move(to: CGPoint(x: -10, y: h * 0.15)); p.addLine(to: CGPoint(x: w * 0.28, y: h * 0.04))
            p.addLine(to: CGPoint(x: w * 0.57, y: h * 0.15)); p.closeSubpath()
        }, with: .color(Theme.terra))
        // janela (esconderijo do rabo)
        ctx.fill(Path(roundedRect: CGRect(x: w * 0.22, y: h * 0.22, width: w * 0.16, height: h * 0.13),
                      cornerRadius: 6),
                 with: .color(Color(hex: 0x7A6845)))
        ctx.fill(Path(roundedRect: CGRect(x: w * 0.235, y: h * 0.235, width: w * 0.13, height: h * 0.1),
                      cornerRadius: 4),
                 with: .color(Color(hex: 0xB4D2DE)))

        // muro
        ctx.fill(Path(roundedRect: CGRect(x: w * 0.5, y: h * 0.40, width: w * 0.5, height: h * 0.09),
                      cornerRadius: 4),
                 with: .color(Color(hex: 0xC9B091)))
        // árvore
        ctx.fill(Path(roundedRect: CGRect(x: w * 0.80, y: h * 0.26, width: 18, height: h * 0.2),
                      cornerRadius: 8),
                 with: .color(Color(hex: 0x6B4A2B)))
        ctx.fill(Path(ellipseIn: CGRect(x: w * 0.70, y: h * 0.08, width: w * 0.26, height: h * 0.22)),
                 with: .color(Color(hex: 0x3C6B48)))

        // varal entre a casa e a árvore, com roupas balançando
        let lineStart = CGPoint(x: w * 0.5, y: h * 0.2)
        let lineEnd = CGPoint(x: w * 0.81, y: h * 0.26)
        ctx.stroke(Path { p in
            p.move(to: lineStart)
            p.addQuadCurve(to: lineEnd, control: CGPoint(x: w * 0.65, y: h * 0.24))
        }, with: .color(Theme.tinta.opacity(0.5)), lineWidth: 1.5)
        let clothes: [Color] = [Theme.terra, Theme.piscina, Theme.ouro]
        for (i, cor) in clothes.enumerated() {
            let t = 0.22 + Double(i) * 0.28
            let cx = lineStart.x + (lineEnd.x - lineStart.x) * t
            let cy = lineStart.y + (lineEnd.y - lineStart.y) * t + 14 * 4 * t * (1 - t) * 0.4
            let sway = sin(e.elapsed * 1.8 + Double(i) * 2) * 3
            ctx.fill(Path(roundedRect: CGRect(x: cx - 8 + sway, y: cy, width: 16, height: 20),
                          cornerRadius: 2),
                     with: .color(cor))
        }

        // gramado
        ctx.fill(Path(CGRect(x: 0, y: h * 0.45, width: w, height: h * 0.55)),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0x8FB569), Color(hex: 0x6D9450)]),
                                       startPoint: CGPoint(x: 0, y: h * 0.45), endPoint: CGPoint(x: 0, y: h)))
        // canteiros de flores
        for (fx, fy) in [(0.3, 0.52), (0.62, 0.78), (0.08, 0.68)] {
            for i in 0..<4 {
                let px2 = w * fx + Double(i) * 9
                ctx.fill(Path(ellipseIn: CGRect(x: px2, y: h * fy, width: 4, height: 4)),
                         with: .color([Theme.ouro, Color(hex: 0xE86FA0), Theme.creme][i % 3]))
            }
        }
        // borboletas voando
        for i in 0..<2 {
            let seed = Double(i) * 3.7
            let bx = w * (0.5 + 0.38 * sin(e.elapsed * 0.35 + seed))
            let by = h * (0.55 + 0.16 * sin(e.elapsed * 0.5 + seed * 2))
            let flap = abs(sin(e.elapsed * 9 + seed)) * 4
            let cor = i == 0 ? Theme.ouro : Color(hex: 0xE86FA0)
            ctx.fill(Path(ellipseIn: CGRect(x: bx - 4 - flap / 2, y: by - 3, width: 4 + flap / 2, height: 6)),
                     with: .color(cor))
            ctx.fill(Path(ellipseIn: CGRect(x: bx, y: by - 3, width: 4 + flap / 2, height: 6)),
                     with: .color(cor))
        }

        // dicas dos gatos ATRÁS dos esconderijos (orelhas/rabo aparecem por cima depois)
        for hideout in e.hideouts where hideout.active {
            let c = CGPoint(x: w * hideout.rel.x, y: h * hideout.rel.y)
            if hideout.found {
                drawCatHead(&ctx, at: c, color: hideout.color)
            } else {
                drawHint(&ctx, hideout.hint, at: c, color: hideout.color, t: e.elapsed)
            }
        }

        // esconderijos por cima (arbustos, vaso, grama alta)
        for (bx, by, bw) in [(0.16, 0.66, 0.24), (0.44, 0.72, 0.26), (0.72, 0.68, 0.24)] {
            ctx.fill(Path(ellipseIn: CGRect(x: w * bx - w * bw / 2, y: h * by - 34,
                                            width: w * bw, height: 70)),
                     with: .color(Color(hex: 0x2C5A3C)))
            ctx.fill(Path(ellipseIn: CGRect(x: w * bx - w * bw * 0.3, y: h * by - 40,
                                            width: w * bw * 0.6, height: 46)),
                     with: .color(Color(hex: 0x3C6B48)))
        }
        // vaso
        ctx.fill(Path { p in
            p.move(to: CGPoint(x: w * 0.05, y: h * 0.84))
            p.addLine(to: CGPoint(x: w * 0.17, y: h * 0.84))
            p.addLine(to: CGPoint(x: w * 0.15, y: h * 0.94))
            p.addLine(to: CGPoint(x: w * 0.07, y: h * 0.94))
            p.closeSubpath()
        }, with: .color(Theme.terraDark))
        // grama alta
        var tufts = Path()
        for i in 0..<7 {
            let x = w * 0.82 + Double(i) * 9
            tufts.move(to: CGPoint(x: x, y: h * 0.87))
            tufts.addQuadCurve(to: CGPoint(x: x + 4, y: h * 0.79),
                               control: CGPoint(x: x - 3, y: h * 0.82))
        }
        ctx.stroke(tufts, with: .color(Color(hex: 0x4E8F5C)), style: StrokeStyle(lineWidth: 4, lineCap: .round))

        // balãozinho de miado (dica)
        if let m = e.meow, m.index < e.hideouts.count {
            let spot = e.hideouts[m.index].rel
            let c = CGPoint(x: w * spot.x + 26, y: h * spot.y - 34)
            let box = CGRect(x: c.x - 26, y: c.y - 12, width: 52, height: 24)
            ctx.fill(Path(roundedRect: box, cornerRadius: 3), with: .color(Theme.creme))
            ctx.stroke(Path(roundedRect: box, cornerRadius: 3), with: .color(Theme.tinta), lineWidth: 2)
            ctx.fill(Path { p in
                p.move(to: CGPoint(x: c.x - 12, y: box.maxY))
                p.addLine(to: CGPoint(x: c.x - 18, y: box.maxY + 8))
                p.addLine(to: CGPoint(x: c.x - 4, y: box.maxY))
                p.closeSubpath()
            }, with: .color(Theme.creme))
            ctx.draw(Text("MIAU!").font(Theme.px(8)).foregroundColor(Theme.tinta),
                     at: c, anchor: .center)
        }

        GamePaint.timeBar(&ctx, size: size, remaining: e.remaining, total: FindCatEngine.duration)
    }

    private static func drawHint(_ ctx: inout GraphicsContext, _ hint: FindCatEngine.Hint,
                                 at c: CGPoint, color: Color, t: Double) {
        let sway = sin(t * 2 + c.x) * 2
        switch hint {
        case .ears:
            for side in [-1.0, 1.0] {
                ctx.fill(Path { p in
                    p.move(to: CGPoint(x: c.x + side * 4 - 6, y: c.y - 18))
                    p.addLine(to: CGPoint(x: c.x + side * 8, y: c.y - 32 + sway))
                    p.addLine(to: CGPoint(x: c.x + side * 12 + 2, y: c.y - 18))
                    p.closeSubpath()
                }, with: .color(color))
            }
        case .tail:
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: c.x, y: c.y))
                p.addQuadCurve(to: CGPoint(x: c.x + 8, y: c.y - 34 + sway),
                               control: CGPoint(x: c.x + 22, y: c.y - 16))
            }, with: .color(color), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        case .paw:
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 8, y: c.y - 6, width: 16, height: 12)),
                     with: .color(color))
            for i in 0..<3 {
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 8 + Double(i) * 6, y: c.y - 12,
                                                width: 5, height: 6)),
                         with: .color(color))
            }
        }
    }

    private static func drawCatHead(_ ctx: inout GraphicsContext, at c: CGPoint, color: Color) {
        for side in [-1.0, 1.0] {
            ctx.fill(Path { p in
                p.move(to: CGPoint(x: c.x + side * 4 - 7, y: c.y - 12))
                p.addLine(to: CGPoint(x: c.x + side * 10, y: c.y - 26))
                p.addLine(to: CGPoint(x: c.x + side * 14 + 2, y: c.y - 10))
                p.closeSubpath()
            }, with: .color(color))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - 15, y: c.y - 15, width: 30, height: 28)),
                 with: .color(color))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - 8, y: c.y - 6, width: 5, height: 6)),
                 with: .color(.white))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x + 3, y: c.y - 6, width: 5, height: 6)),
                 with: .color(.white))
        Px.draw(&ctx, Px.sparkle, at: CGPoint(x: c.x + 18, y: c.y - 22), pixel: 3,
                colors: Px.tinted(["W": Theme.ouro]))
    }
}

struct FindCatGameView: View {
    let onExit: () -> Void
    let onFinish: (MinigameResult) -> Void
    var body: some View {
        MiniGameHost(engine: FindCatEngine(), background: Color(hex: 0x6D9450),
                     onExit: onExit, onFinish: onFinish) { e, ctx, size in
            FindCatPainter.draw(e, &ctx, size)
        }
    }
}
