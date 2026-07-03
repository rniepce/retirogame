import SwiftUI

/// BMX da Serra: pista lateral com rampas. Segure para acelerar;
/// no ar, continue segurando para girar o backflip e solte para nivelar.
/// Pouse alinhado ou capota!
final class BMXEngine: MiniEngine {
    static let trackLength = 2200.0
    let avatar: AvatarConfig
    init(avatar: AvatarConfig) { self.avatar = avatar }

    private(set) var x = 30.0            // posição no mundo (px)
    private(set) var speed = 90.0
    private(set) var altitude = 0.0      // altura absoluta do piloto
    private(set) var vy = 0.0
    private(set) var airborne = false
    private(set) var angle = 0.0         // rotação acumulada no ar
    private(set) var flips = 0
    private(set) var crashes = 0
    private var stunnedUntil = -1.0
    private var reachedEnd = false

    static let ramps = [500.0, 1050.0, 1600.0]

    func elevation(_ wx: Double) -> Double {
        var e = 12 * sin(wx / 80) + 7 * sin(wx / 37)
        for r in Self.ramps where wx >= r && wx < r + 130 {
            e += (wx - r) / 130 * 80
        }
        return max(e, -10)
    }

    override func didStart() {
        setHUD("🚴 0%")
        say("Segure para acelerar!", for: 2)
        altitude = elevation(x)
    }

    override func tick(dt: Double) {
        guard !reachedEnd else { return }
        let stunned = elapsed < stunnedUntil

        // velocidade
        if holding && !stunned && !airborne {
            speed = min(speed + 240 * dt, 260)
        } else if !airborne {
            speed = max(speed - 110 * dt, stunned ? 0 : 90)
        }
        x += speed * dt

        let ground = elevation(x)
        if airborne {
            vy -= 900 * dt
            altitude += vy * dt
            if holding { angle += 6.8 * dt }   // backflip
            if altitude <= ground {
                altitude = ground
                airborne = false
                vy = 0
                let spin = angle.truncatingRemainder(dividingBy: 2 * .pi)
                let offset = min(spin, 2 * .pi - spin)
                let fullFlips = Int((angle / (2 * .pi)).rounded())
                if offset < 0.8 {
                    if fullFlips > 0 {
                        flips += fullFlips
                        say(fullFlips > 1 ? "🔥 DUPLO BACKFLIP!" : "🔥 BACKFLIP!", for: 1.1)
                        Haptics.success()
                    }
                } else {
                    crashes += 1
                    speed = 30
                    stunnedUntil = elapsed + 1.2
                    say("💥 Capotou!", for: 1.1)
                    Haptics.error()
                }
                angle = 0
            }
        } else {
            // decolagem: o chão sumiu debaixo da roda (fim de rampa)
            if ground < altitude - 12 {
                airborne = true
                vy = min(speed * 0.55, 330)
            } else {
                altitude = ground
            }
        }

        if x >= Self.trackLength {
            reachedEnd = true
            let timeBonus = max(0, 30 - Int(elapsed))
            let points = flips * 20 + timeBonus + (crashes == 0 ? 20 : 0)
            let final = points
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.finish(points: final, maxPoints: 100)
            }
            say("🏁 Chegou!", for: 1.5)
            Haptics.success()
        }
        setHUD("🚴 \(Int(x / Self.trackLength * 100))% · \(flips) flips")
    }
}

enum BMXPainter {
    static func draw(_ e: BMXEngine, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height
        let baseY = h * 0.72
        let camX = e.x - w * 0.3

        // céu e serra em parallax
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0x8FC4DB), Color(hex: 0xD7EBDF)]),
                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.7)))
        var hills = Path()
        hills.move(to: CGPoint(x: 0, y: h * 0.55))
        for sx in stride(from: 0.0, through: Double(w), by: 24) {
            let wx = (camX * 0.25 + sx)
            hills.addLine(to: CGPoint(x: sx, y: h * 0.5 + 30 * sin(wx / 180) + 14 * sin(wx / 71)))
        }
        hills.addLine(to: CGPoint(x: w, y: h)); hills.addLine(to: CGPoint(x: 0, y: h))
        hills.closeSubpath()
        ctx.fill(hills, with: .color(Color(hex: 0x2C5A3C)))

        // chão da pista
        var ground = Path()
        ground.move(to: CGPoint(x: 0, y: baseY - e.elevation(camX)))
        for sx in stride(from: 0.0, through: Double(w), by: 10) {
            ground.addLine(to: CGPoint(x: sx, y: baseY - e.elevation(camX + sx)))
        }
        var fill = ground
        fill.addLine(to: CGPoint(x: w, y: h)); fill.addLine(to: CGPoint(x: 0, y: h))
        fill.closeSubpath()
        ctx.fill(fill, with: .color(Color(hex: 0x7FA85E)))
        ctx.stroke(ground, with: .color(Color(hex: 0xA8814F)), lineWidth: 7)

        // linha de chegada
        let finishSX = BMXEngine.trackLength - camX
        if finishSX > -20 && finishSX < w + 20 {
            let gy = baseY - e.elevation(BMXEngine.trackLength)
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: finishSX, y: gy)); p.addLine(to: CGPoint(x: finishSX, y: gy - 70))
            }, with: .color(Color(hex: 0x6B4A2B)), lineWidth: 4)
            GamePaint.emoji(&ctx, "🏁", at: CGPoint(x: finishSX + 12, y: gy - 74), size: 30)
        }

        // piloto
        let px = w * 0.3
        let py = baseY - e.altitude
        let slope = e.airborne ? 0 : atan2(e.elevation(e.x + 14) - e.elevation(e.x - 14), 28)
        var c = ctx
        c.translateBy(x: px, y: py - 16)
        c.rotate(by: .radians(-slope - e.angle))
        // rodas
        for wx in [-16.0, 16.0] {
            c.stroke(Path(ellipseIn: CGRect(x: wx - 9, y: 5, width: 18, height: 18)),
                     with: .color(Theme.tinta), lineWidth: 3.5)
        }
        // quadro
        c.stroke(Path { p in
            p.move(to: CGPoint(x: -16, y: 14)); p.addLine(to: CGPoint(x: 0, y: 8))
            p.addLine(to: CGPoint(x: 16, y: 14))
            p.move(to: CGPoint(x: 0, y: 8)); p.addLine(to: CGPoint(x: -4, y: -2))
            p.move(to: CGPoint(x: 16, y: 14)); p.addLine(to: CGPoint(x: 12, y: 0))
        }, with: .color(Theme.terra), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        // piloto (cores do avatar)
        c.fill(Path(roundedRect: CGRect(x: -10, y: -16, width: 14, height: 18), cornerRadius: 5),
               with: .color(e.avatar.clothesColor))
        c.fill(Path(ellipseIn: CGRect(x: -9, y: -30, width: 14, height: 14)),
               with: .color(e.avatar.skinColor))
        c.fill(Path(roundedRect: CGRect(x: -10, y: -32, width: 16, height: 8), cornerRadius: 4),
               with: .color(Theme.terra))   // capacete

        // instrução de flip quando no ar
        if e.airborne {
            ctx.draw(Text(e.holding ? "🔄 girando…" : "segure p/ girar")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(Theme.creme),
                     at: CGPoint(x: px, y: py - 70), anchor: .center)
        }
    }
}

struct BMXGameView: View {
    let avatar: AvatarConfig
    let onExit: () -> Void
    let onFinish: (MinigameResult) -> Void
    var body: some View {
        MiniGameHost(engine: BMXEngine(avatar: avatar), background: Color(hex: 0x8FC4DB),
                     onExit: onExit, onFinish: onFinish) { e, ctx, size in
            BMXPainter.draw(e, &ctx, size)
        }
    }
}
