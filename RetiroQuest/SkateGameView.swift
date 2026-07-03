import SwiftUI

/// Skate no half-pipe: toque no FUNDO da rampa para embalar;
/// quando voar acima da borda, toque no ar para fazer manobras.
final class SkateEngine: MiniEngine {
    static let duration = 45.0
    let avatar: AvatarConfig
    init(avatar: AvatarConfig) { self.avatar = avatar }

    private(set) var phase = 0.0        // oscilação do pêndulo
    private(set) var amp = 0.4          // amplitude (1 = borda)
    private(set) var airborne = false
    private(set) var airStart = 0.0
    private(set) var airTime = 0.0
    private(set) var airSide = 1.0
    private(set) var tricksInAir = 0
    private(set) var score = 0
    private var lastS = 0.0

    var s: Double { airborne ? airSide : -cos(phase) * amp }

    override func didStart() {
        setHUD("🛹 45s · 0 pts")
        say("Toque no FUNDO da rampa para embalar!", for: 2.4)
    }

    override func tick(dt: Double) {
        let remaining = Self.duration - elapsed
        if remaining <= 0 {
            finish(points: score, maxPoints: 120)
            return
        }
        if airborne {
            if elapsed - airStart >= airTime {
                airborne = false
                phase = airSide > 0 ? .pi : 0   // volta descendo do mesmo lado
                if tricksInAir > 0 { Haptics.light() }
            }
        } else {
            phase += dt * (2 * .pi / 1.7)
            let current = -cos(phase) * amp
            // lançou da borda?
            if amp > 0.92 && abs(current) > 0.9 && abs(current) > abs(lastS) {
                airborne = true
                airSide = current > 0 ? 1 : -1
                airStart = elapsed
                airTime = 0.55 + amp * 0.35
                tricksInAir = 0
                amp = max(amp - 0.06, 0.85)   // perde um pouco a cada voo
            }
            lastS = current
        }
        setHUD("🛹 \(Int(remaining))s · \(score) pts")
    }

    override func tap(at p: CGPoint) {
        guard !finished else { return }
        if airborne {
            let left = airTime - (elapsed - airStart)
            if left < 0.12 {
                amp = 0.5
                say("Quase caiu! Equilibrou…")
                Haptics.error()
            } else if tricksInAir < 3 {
                tricksInAir += 1
                score += 4
                say(["🛹 Ollie! +4", "🔥 Kickflip! +4", "⚡ 360! +4"][tricksInAir - 1], for: 0.7)
                Haptics.light()
            }
        } else if abs(s) < 0.35 {
            amp = min(amp + 0.17, 1.05)
            say("Embalou!", for: 0.5)
            Haptics.light()
        }
    }

    /// Posição e inclinação do skatista no pipe (espaço da tela).
    func skaterPose(size: CGSize) -> (CGPoint, Double) {
        let cx = size.width / 2
        let cy = size.height * 0.42
        let radius = min(size.width * 0.42, size.height * 0.34)
        if airborne {
            let t = min((elapsed - airStart) / max(airTime, 0.01), 1)
            let lipX = cx + airSide * radius
            let x = lipX + airSide * 26 * sin(t * .pi)
            let y = cy - sin(t * .pi) * 120
            let spin = Double(tricksInAir) * 0.9 * sin(t * .pi)
            return (CGPoint(x: x, y: y), -airSide * (0.4 + spin))
        }
        let theta = s * .pi / 2
        return (CGPoint(x: cx + sin(theta) * radius, y: cy + cos(theta) * radius - 14),
                -theta)
    }

    func pipeGeometry(size: CGSize) -> (CGPoint, Double) {
        (CGPoint(x: size.width / 2, y: size.height * 0.42),
         min(size.width * 0.42, size.height * 0.34))
    }
}

enum SkatePainter {
    static func draw(_ e: SkateEngine, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height
        let (center, radius) = e.pipeGeometry(size: size)

        // fundo: tarde no clube (faixas chapadas)
        GamePaint.bands(&ctx, rect: CGRect(x: 0, y: 0, width: w, height: h * 0.58),
                        colors: [Color(hex: 0xF3C583), Color(hex: 0xEDB277), Color(hex: 0xE8A06A)])
        ctx.fill(Path(CGRect(x: 0, y: h * 0.58, width: w, height: h * 0.42)),
                 with: .color(Color(hex: 0x7FA85E)))
        Px.draw(&ctx, Px.sun, at: CGPoint(x: w * 0.5, y: h * 0.13), pixel: 5)

        // half-pipe: semicírculo interno
        var pipe = Path()
        pipe.addArc(center: center, radius: radius,
                    startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        var wall = pipe
        wall.addLine(to: CGPoint(x: center.x - radius - 22, y: center.y))
        wall.addLine(to: CGPoint(x: center.x - radius - 22, y: center.y + radius + 30))
        wall.addLine(to: CGPoint(x: center.x + radius + 22, y: center.y + radius + 30))
        wall.addLine(to: CGPoint(x: center.x + radius + 22, y: center.y))
        wall.closeSubpath()
        ctx.fill(wall, with: .color(Color(hex: 0xB9BEC4)))
        ctx.stroke(pipe, with: .color(Color(hex: 0x8E959D)), lineWidth: 6)
        // bordas (coping)
        for sideX in [center.x - radius, center.x + radius] {
            ctx.fill(Path(ellipseIn: CGRect(x: sideX - 6, y: center.y - 6, width: 12, height: 12)),
                     with: .color(Theme.terra))
        }
        // zona de embalo
        ctx.stroke(Path(ellipseIn: CGRect(x: center.x - 40, y: center.y + radius - 26,
                                          width: 80, height: 24)),
                   with: .color(Theme.creme.opacity(0.6)), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))

        // medidor de embalo
        ctx.fill(Path(roundedRect: CGRect(x: w / 2 - 60, y: h * 0.9, width: 120, height: 10),
                      cornerRadius: 5),
                 with: .color(Theme.serraDark.opacity(0.7)))
        ctx.fill(Path(roundedRect: CGRect(x: w / 2 - 57, y: h * 0.9 + 2.5,
                                          width: 114 * min(e.amp, 1), height: 5),
                      cornerRadius: 2.5),
                 with: .color(e.amp > 0.92 ? Theme.ouro : Theme.grama))

        // skatista
        let (pos, tilt) = e.skaterPose(size: size)
        var c = ctx
        c.translateBy(x: pos.x, y: pos.y)
        c.rotate(by: .radians(tilt))
        c.fill(Path(roundedRect: CGRect(x: -16, y: 8, width: 32, height: 5), cornerRadius: 2.5),
               with: .color(Theme.tinta))                       // shape
        c.fill(Path(ellipseIn: CGRect(x: -13, y: 12, width: 7, height: 7)), with: .color(Theme.terra))
        c.fill(Path(ellipseIn: CGRect(x: 6, y: 12, width: 7, height: 7)), with: .color(Theme.terra))
        c.fill(Path(roundedRect: CGRect(x: -8, y: -14, width: 16, height: 22), cornerRadius: 6),
               with: .color(e.avatar.clothesColor))             // corpo
        c.fill(Path(ellipseIn: CGRect(x: -7, y: -29, width: 14, height: 14)),
               with: .color(e.avatar.skinColor))                // cabeça
        c.fill(Path(roundedRect: CGRect(x: -8, y: -31, width: 16, height: 7), cornerRadius: 3.5),
               with: .color(Color(hex: 0x2E4057)))              // capacete

        if e.airborne {
            ctx.draw(Text("TOQUE P/ MANOBRAR!")
                .font(Theme.px(10))
                .foregroundColor(Theme.tinta),
                     at: CGPoint(x: w / 2, y: h * 0.22), anchor: .center)
        }
    }
}

struct SkateGameView: View {
    let avatar: AvatarConfig
    let onExit: () -> Void
    let onFinish: (MinigameResult) -> Void
    var body: some View {
        MiniGameHost(engine: SkateEngine(avatar: avatar), background: Color(hex: 0xE8A06A),
                     onExit: onExit, onFinish: onFinish) { e, ctx, size in
            SkatePainter.draw(e, &ctx, size)
        }
    }
}
