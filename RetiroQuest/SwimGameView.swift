import SwiftUI

/// Natação: prova de 2 piscinas (ida e volta) contra dois adversários.
/// Toque ALTERNANDO os lados da tela para dar braçadas; mesmo lado repetido
/// quase não move. Na parede, toque na janela certa para a virada perfeita.
final class SwimEngine: MiniEngine {
    static let raceLength = 2.0     // ida (0→1) e volta (1→2)
    static let timeLimit = 40.0
    let avatar: AvatarConfig
    init(avatar: AvatarConfig) { self.avatar = avatar }

    struct CPU {
        var progress = 0.0
        var pace: Double
        var wobble: Double
        var finishTime: Double?
    }

    // jogador
    private(set) var progress = 0.0
    private(set) var speed = 0.0
    private(set) var strokes = 0
    private(set) var lastSide = 0          // 0 nenhum, 1 esquerda, 2 direita
    private(set) var turnBoosted = false
    private var turnHandled = false
    private(set) var finishTime: Double?
    private(set) var cpus = [
        CPU(pace: 0.112, wobble: 0.9),
        CPU(pace: 0.122, wobble: 1.7),
    ]

    var nearWall: Bool { progress > 0.86 && progress < 1.0 && !turnHandled }
    var rank: Int { 1 + cpus.filter { $0.progress > progress }.count }

    override func didStart() {
        setHUD("🏊 3º · 0.0s")
        say("Toque ALTERNANDO os lados!", for: 2.2)
    }

    override func tick(dt: Double) {
        if elapsed > Self.timeLimit {
            end()
            return
        }
        // arrasto da água: sem braçada, o nadador para rápido
        speed *= pow(0.25, dt)
        let before = progress
        if finishTime == nil { progress = min(progress + speed * dt, Self.raceLength) }

        // virada na parede: sem o toque certo, perde metade do embalo
        if before < 1.0 && progress >= 1.0 {
            turnHandled = true
            if !turnBoosted {
                speed *= 0.45
                say("Virada lenta…", for: 0.8)
            }
        }

        // adversários (com elástico leve para a prova ficar disputada)
        for i in cpus.indices where cpus[i].finishTime == nil {
            let band = 1 + (progress - cpus[i].progress) * 0.25
            let wave = 1 + sin(elapsed * cpus[i].wobble) * 0.12
            cpus[i].progress += cpus[i].pace * band * wave * dt
            if cpus[i].progress >= Self.raceLength {
                cpus[i].progress = Self.raceLength
                cpus[i].finishTime = elapsed
            }
        }

        if progress >= Self.raceLength && finishTime == nil {
            finishTime = elapsed
            let place = 1 + cpus.filter { $0.finishTime != nil }.count
            say(["🥇 1º LUGAR!", "🥈 2º lugar!", "🥉 3º lugar…"][min(place, 3) - 1], for: 1.4)
            if place == 1 { Haptics.success() } else { Haptics.tap() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.end()
            }
        }

        let t = finishTime ?? elapsed
        setHUD("🏊 \(rank)º · \(String(format: "%.1f", t))s")
    }

    override func tap(at p: CGPoint) {
        guard !finished, finishTime == nil, viewSize != .zero else { return }
        let side = p.x < viewSize.width / 2 ? 1 : 2

        // virada perfeita: toque com o corpo colado na parede do fundo
        if nearWall && progress > 0.93 {
            turnBoosted = true
            turnHandled = true
            speed = min(speed + 0.22, 0.4)
            say("🌀 VIRADA PERFEITA! +5", for: 1)
            Haptics.success()
            return
        }

        if side != lastSide {
            speed = min(speed + 0.095, 0.34)
            strokes += 1
            Haptics.light()
        } else {
            speed = min(speed + 0.02, 0.34)
            if strokes % 4 == 0 { say("ALTERNE OS LADOS!", for: 0.6) }
        }
        lastSide = side
    }

    private func end() {
        guard !finished else { return }
        let place = finishTime == nil ? 3 : rankAtFinish()
        var points: Int
        switch place {
        case 1: points = 42
        case 2: points = 24
        default: points = finishTime == nil ? 4 : 10
        }
        if turnBoosted { points += 5 }
        if let t = finishTime, t < 16 { points += 3 }
        finish(points: min(points, 50), maxPoints: 50,
               phrases: ["A piscina venceu — treine o ritmo!", "Pódio! Continue treinando.",
                         "Prata brilhando!", "Campeão da piscina do clube!"])
    }

    private func rankAtFinish() -> Int {
        guard let t = finishTime else { return 3 }
        return 1 + cpus.filter { ($0.finishTime ?? .infinity) < t }.count
    }
}

enum SwimPainter {
    static func draw(_ e: SwimEngine, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height

        // deque do clube
        GamePaint.bands(&ctx, rect: CGRect(origin: .zero, size: size),
                        colors: [Theme.areia, Theme.areiaDark])

        // piscina com faixas de água
        let pool = CGRect(x: w * 0.12, y: h * 0.14, width: w * 0.76, height: h * 0.72)
        GamePaint.bands(&ctx, rect: pool,
                        colors: [Color(hex: 0x4FA7C9), Color(hex: 0x3F97B9),
                                 Color(hex: 0x4FA7C9), Color(hex: 0x3F97B9)])
        ctx.stroke(Path(pool), with: .color(Theme.creme), lineWidth: 5)

        // paredes de virada/chegada
        ctx.fill(Path(CGRect(x: pool.minX, y: pool.minY, width: pool.width, height: 8)),
                 with: .color(Theme.creme.opacity(0.85)))
        ctx.fill(Path(CGRect(x: pool.minX, y: pool.maxY - 8, width: pool.width, height: 8)),
                 with: .color(Theme.creme.opacity(0.85)))

        // raias
        let laneW = pool.width / 3
        for i in 1..<3 {
            let x = pool.minX + laneW * Double(i)
            var rope = Path()
            var y = pool.minY
            while y < pool.maxY {
                rope.move(to: CGPoint(x: x, y: y))
                rope.addLine(to: CGPoint(x: x, y: min(y + 8, pool.maxY)))
                y += 14
            }
            ctx.stroke(rope, with: .color(Theme.creme.opacity(0.6)), lineWidth: 3)
        }

        // zona de virada piscando quando o jogador se aproxima
        if e.nearWall {
            let pulse = 0.25 + 0.2 * sin(e.elapsed * 10)
            ctx.fill(Path(CGRect(x: pool.minX, y: pool.minY, width: pool.width, height: 26)),
                     with: .color(Theme.ouro.opacity(pulse)))
            ctx.draw(Text("TOQUE NA PAREDE!").font(Theme.px(9)).foregroundColor(Theme.tinta),
                     at: CGPoint(x: w / 2, y: pool.minY + 40), anchor: .center)
        }

        // nadadores: CPUs nas raias 1 e 3, jogador no meio
        drawSwimmer(&ctx, pool: pool, lane: 0, progress: e.cpus[0].progress,
                    skin: Color(hex: 0x9C6644), cap: Color(hex: 0x2E4057),
                    strokePhase: e.elapsed * 6)
        drawSwimmer(&ctx, pool: pool, lane: 2, progress: e.cpus[1].progress,
                    skin: Color(hex: 0xF5D0A9), cap: Color(hex: 0x8E5BA6),
                    strokePhase: e.elapsed * 7)
        drawSwimmer(&ctx, pool: pool, lane: 1, progress: e.progress,
                    skin: e.avatar.skinColor, cap: e.avatar.clothesColor,
                    strokePhase: Double(e.strokes) * 1.6)

        // dicas de lado: a próxima braçada acende
        let nextLeft = e.lastSide != 1
        ctx.draw(Text("◀ E").font(Theme.px(nextLeft ? 14 : 10))
            .foregroundColor(Theme.tinta.opacity(nextLeft ? 0.8 : 0.3)),
                 at: CGPoint(x: w * 0.14, y: h * 0.93), anchor: .center)
        ctx.draw(Text("D ▶").font(Theme.px(nextLeft ? 10 : 14))
            .foregroundColor(Theme.tinta.opacity(nextLeft ? 0.3 : 0.8)),
                 at: CGPoint(x: w * 0.86, y: h * 0.93), anchor: .center)
    }

    /// Nadador visto de cima: ida sobe, volta desce; braços alternam.
    private static func drawSwimmer(_ ctx: inout GraphicsContext, pool: CGRect, lane: Int,
                                    progress: Double, skin: Color, cap: Color,
                                    strokePhase: Double) {
        let laneX = pool.minX + pool.width / 3 * (Double(lane) + 0.5)
        let going = progress <= 1.0
        let frac = going ? progress : 2.0 - progress
        let y = pool.maxY - 30 - (pool.height - 60) * frac
        let dir: Double = going ? -1 : 1   // -1 = nadando para cima

        var c = ctx
        c.translateBy(x: laneX, y: y)
        if dir > 0 { c.scaleBy(x: 1, y: -1) }   // volta: de cabeça para baixo

        // esteira de espuma
        for i in 1...3 {
            let off = Double(i) * 10
            c.fill(Path(ellipseIn: CGRect(x: -7 + sin(strokePhase - Double(i)) * 4,
                                          y: off + 8, width: 14, height: 5)),
                   with: .color(.white.opacity(0.35 - Double(i) * 0.09)))
        }
        // pernas batendo
        let kick = sin(strokePhase * 2) * 3
        c.fill(Path(roundedRect: CGRect(x: -5 + kick, y: 8, width: 4, height: 10), cornerRadius: 2),
               with: .color(skin))
        c.fill(Path(roundedRect: CGRect(x: 1 - kick, y: 8, width: 4, height: 10), cornerRadius: 2),
               with: .color(skin))
        // corpo
        c.fill(Path(roundedRect: CGRect(x: -7, y: -8, width: 14, height: 18), cornerRadius: 6),
               with: .color(skin))
        // braços alternando braçadas
        let reachL = sin(strokePhase) * 7
        let reachR = sin(strokePhase + .pi) * 7
        c.fill(Path(roundedRect: CGRect(x: -13, y: -6 - max(reachL, 0), width: 5, height: 12), cornerRadius: 2.5),
               with: .color(skin))
        c.fill(Path(roundedRect: CGRect(x: 8, y: -6 - max(reachR, 0), width: 5, height: 12), cornerRadius: 2.5),
               with: .color(skin))
        // touca de natação (vista de cima só se vê a touca)
        c.fill(Path(ellipseIn: CGRect(x: -6, y: -16, width: 12, height: 12)),
               with: .color(cap))
        c.fill(Path(ellipseIn: CGRect(x: -3, y: -14, width: 4, height: 4)),
               with: .color(.white.opacity(0.3)))
    }
}

struct SwimGameView: View {
    let avatar: AvatarConfig
    let onExit: () -> Void
    let onFinish: (MinigameResult) -> Void
    var body: some View {
        MiniGameHost(engine: SwimEngine(avatar: avatar), background: Theme.areiaDark,
                     onExit: onExit, onFinish: onFinish) { e, ctx, size in
            SwimPainter.draw(e, &ctx, size)
        }
    }
}
