import SwiftUI
import UIKit

// MARK: - Motor do arqueiro
// Arraste para trás para puxar a corda: a mira sobe na direção oposta.
// Solte para atirar. O vento desvia a flecha; puxada fraca treme mais.

final class ArcherEngine: NSObject, ObservableObject {
    static let totalArrows = 5
    static let flightDuration = 0.55

    struct Flight {
        var t: Double
        let from: CGPoint
        let to: CGPoint
    }
    struct Notice {
        let text: String
        let until: TimeInterval
    }
    struct Aim {
        let point: CGPoint
        let power: Double
    }

    @Published private(set) var arrows = ArcherEngine.totalArrows
    @Published private(set) var points = 0

    private(set) var wind = Double.random(in: -2.4...2.4)
    private(set) var flight: Flight?
    private(set) var marks: [CGVector] = []   // deslocamentos em relação ao centro do alvo
    private(set) var notice: Notice?
    private(set) var finished = false
    var drag: (start: CGPoint, current: CGPoint)?
    var viewSize: CGSize = .zero

    var onFinish: ((MinigameResult) -> Void)?

    private var displayLink: CADisplayLink?
    private var lastTime: CFTimeInterval = 0
    private var endAt: TimeInterval = 0
    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let outcome = UINotificationFeedbackGenerator()

    // MARK: geometria (no espaço da view)

    var targetCenter: CGPoint {
        CGPoint(x: viewSize.width / 2, y: viewSize.height * 0.34)
    }
    var targetRadius: CGFloat {
        min(viewSize.width, viewSize.height) * 0.16
    }
    var aim: Aim? {
        guard let drag, viewSize != .zero else { return nil }
        let dx = drag.current.x - drag.start.x
        let dy = drag.current.y - drag.start.y
        let power = min(max(hypot(dx, dy) / (viewSize.height * 0.28), 0), 1)
        return Aim(point: CGPoint(x: viewSize.width / 2 - dx * 0.7,
                                  y: viewSize.height * 0.42 - max(0, dy) * 0.5),
                   power: power)
    }

    // MARK: ciclo de vida

    func start() {
        guard displayLink == nil else { return }
        lastTime = CACurrentMediaTime()
        notice = Notice(text: "Arraste para trás e solte!", until: lastTime + 2.2)
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        impact.prepare()
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        let now = CACurrentMediaTime()
        let dt = min(now - lastTime, 0.05)
        lastTime = now

        if var f = flight {
            f.t += dt / Self.flightDuration
            if f.t >= 1 {
                flight = nil
                resolveImpact(at: f.to, now: now)
            } else {
                flight = f
            }
        }
        if endAt > 0, now > endAt, flight == nil, !finished {
            finish()
        }
    }

    // MARK: entrada

    func dragChanged(start: CGPoint, current: CGPoint) {
        guard flight == nil, !finished, arrows > 0 else { return }
        drag = (start, current)
    }

    func dragEnded() {
        guard drag != nil else { return }
        shoot()
        drag = nil
    }

    private func shoot() {
        guard let aim, flight == nil, arrows > 0 else { return }
        guard aim.power >= 0.15 else {
            notice = Notice(text: "Puxe mais a corda!", until: CACurrentMediaTime() + 0.9)
            return
        }
        impact.impactOccurred()
        arrows -= 1

        let r = targetRadius
        let jitter = (1.05 - aim.power) * r * 0.30
        let hit = CGPoint(
            x: aim.point.x + wind * r * 0.18 + .random(in: -jitter...jitter),
            y: aim.point.y - r * 0.12 + .random(in: -(jitter * 0.8)...(jitter * 0.8))
        )
        flight = Flight(t: 0,
                        from: CGPoint(x: viewSize.width / 2, y: viewSize.height * 0.95),
                        to: hit)
    }

    private func resolveImpact(at point: CGPoint, now: TimeInterval) {
        let c = targetCenter
        let d = hypot(point.x - c.x, point.y - c.y) / targetRadius
        let gained: Int
        switch d {
        case ...0.14: gained = 10
        case ...0.35: gained = 8
        case ...0.60: gained = 6
        case ...0.82: gained = 4
        case ...1.00: gained = 2
        default:      gained = 0
        }
        if gained > 0 {
            points += gained
            marks.append(CGVector(dx: point.x - c.x, dy: point.y - c.y))
            outcome.notificationOccurred(.success)
            notice = Notice(text: gained == 10 ? "🎯 NA MOSCA! +10" : "+\(gained)", until: now + 0.9)
        } else {
            outcome.notificationOccurred(.error)
            notice = Notice(text: "Errou o alvo…", until: now + 0.9)
        }
        wind = .random(in: -2.4...2.4)
        if arrows <= 0 { endAt = now + 1.1 }
    }

    private func finish() {
        finished = true
        stop()
        let max = Self.totalArrows * 10
        let stars: Int
        switch Double(points) / Double(max) {
        case 0.8...: stars = 3
        case 0.55...: stars = 2
        case 0.3...: stars = 1
        default: stars = 0
        }
        let phrases = [
            "O alvo venceu dessa vez. Treine a força da puxada!",
            "Bom olho! Continue treinando no clube.",
            "Quase um arqueiro profissional!",
            "Pontaria de elite — a serra inteira ouviu os aplausos!",
        ]
        onFinish?(MinigameResult(points: points, stars: stars,
                                 phrase: "\(points) de \(max) pontos. \(phrases[stars])"))
    }
}

// MARK: - View

struct ArcherGameView: View {
    let avatar: AvatarConfig
    let onExit: () -> Void
    let onFinish: (MinigameResult) -> Void

    @StateObject private var engine = ArcherEngine()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { _ in
                Canvas { ctx, size in
                    engine.viewSize = size
                    ArcherPainter.draw(engine: engine, avatar: avatar, in: &ctx, size: size)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in engine.dragChanged(start: v.startLocation, current: v.location) }
                    .onEnded { _ in engine.dragEnded() }
            )
            .onAppear {
                engine.viewSize = geo.size
                engine.onFinish = onFinish
                engine.start()
            }
            .onDisappear { engine.stop() }
        }
        .ignoresSafeArea()
        .background(Color(hex: 0x8FC4DB))
        .overlay(alignment: .top) {
            HStack {
                Button {
                    engine.stop()
                    onExit()
                } label: {
                    Text("✕ Sair")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.creme)
                        .padding(.vertical, 9)
                        .padding(.horizontal, 16)
                        .background(Capsule().fill(Theme.serraDark.opacity(0.78)))
                }
                Spacer()
                HUDChip(text: "🏹 \(engine.arrows)  ·  \(engine.points) pts")
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Desenho (Canvas, espaço da tela com y para baixo)

enum ArcherPainter {
    static func draw(engine: ArcherEngine, avatar: AvatarConfig, in ctx: inout GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        let now = CACurrentMediaTime()
        let center = engine.targetCenter
        let radius = engine.targetRadius
        let aim = engine.aim

        drawBackground(&ctx, w: w, h: h)
        drawTarget(&ctx, center: center, radius: radius, marks: engine.marks)
        drawWindFlag(&ctx, w: w, h: h, wind: engine.wind, now: now)

        if let f = engine.flight {
            drawFlight(&ctx, flight: f, h: h)
        }

        drawBow(&ctx, w: w, h: h, aim: aim, hasNockedArrow: engine.flight == nil && !engine.finished && engine.arrows > 0,
                avatar: avatar, now: now)

        if let aim {
            drawReticle(&ctx, aim: aim, w: w, h: h)
        }

        if let notice = engine.notice, now < notice.until {
            drawNotice(&ctx, text: notice.text, w: w, h: h)
        }
    }

    private static func drawBackground(_ ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        // céu
        ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: h * 0.62)),
                 with: .linearGradient(
                    Gradient(colors: [Color(hex: 0x8FC4DB), Color(hex: 0xD7EBDF)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.62)))
        // serra ao fundo
        ctx.fill(Path { p in
            p.move(to: CGPoint(x: 0, y: h * 0.52))
            p.addQuadCurve(to: CGPoint(x: w * 0.42, y: h * 0.50),
                           control: CGPoint(x: w * 0.2, y: h * 0.40))
            p.addQuadCurve(to: CGPoint(x: w, y: h * 0.46),
                           control: CGPoint(x: w * 0.65, y: h * 0.58))
            p.addLine(to: CGPoint(x: w, y: h * 0.62))
            p.addLine(to: CGPoint(x: 0, y: h * 0.62))
            p.closeSubpath()
        }, with: .color(Color(hex: 0x2C5A3C)))
        // gramado em perspectiva
        ctx.fill(Path(CGRect(x: 0, y: h * 0.58, width: w, height: h * 0.42)),
                 with: .linearGradient(
                    Gradient(colors: [Color(hex: 0x7FA85E), Color(hex: 0x5E874A)]),
                    startPoint: CGPoint(x: 0, y: h * 0.58), endPoint: CGPoint(x: 0, y: h)))
        for i in 1..<5 {
            let yy = h * 0.58 + h * 0.42 * pow(CGFloat(i) / 5, 1.6)
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: 0, y: yy)); p.addLine(to: CGPoint(x: w, y: yy))
            }, with: .color(Theme.creme.opacity(0.25)), lineWidth: 1.5)
        }
    }

    private static func drawTarget(_ ctx: inout GraphicsContext, center: CGPoint, radius: CGFloat, marks: [CGVector]) {
        // suporte de madeira
        ctx.stroke(Path { p in
            p.move(to: CGPoint(x: center.x - radius * 0.7, y: center.y + radius * 1.8))
            p.addLine(to: CGPoint(x: center.x, y: center.y + radius * 0.5))
            p.addLine(to: CGPoint(x: center.x + radius * 0.7, y: center.y + radius * 1.8))
        }, with: .color(Color(hex: 0x6B4A2B)),
           style: StrokeStyle(lineWidth: radius * 0.14, lineCap: .round))

        // anéis
        let rings: [(CGFloat, Color)] = [
            (1.0, Theme.creme), (0.82, Theme.tinta), (0.60, Theme.piscina),
            (0.35, Theme.terra), (0.14, Theme.ouro),
        ]
        for (rr, cor) in rings {
            let r = radius * rr
            ctx.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                     with: .color(cor))
        }
        ctx.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                          width: radius * 2, height: radius * 2)),
                   with: .color(Theme.tinta.opacity(0.3)), lineWidth: 1.5)

        // flechas cravadas
        for mk in marks {
            let fx = center.x + mk.dx, fy = center.y + mk.dy
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: fx, y: fy)); p.addLine(to: CGPoint(x: fx + 9, y: fy + 16))
            }, with: .color(Color(hex: 0x4A3524)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            ctx.fill(Path { p in
                p.move(to: CGPoint(x: fx + 9, y: fy + 16))
                p.addLine(to: CGPoint(x: fx + 15, y: fy + 18))
                p.addLine(to: CGPoint(x: fx + 11, y: fy + 22))
                p.closeSubpath()
            }, with: .color(Theme.terra))
            ctx.fill(Path(ellipseIn: CGRect(x: fx - 2.6, y: fy - 2.6, width: 5.2, height: 5.2)),
                     with: .color(Theme.tinta))
        }
    }

    private static func drawWindFlag(_ ctx: inout GraphicsContext, w: CGFloat, h: CGFloat,
                                     wind: Double, now: TimeInterval) {
        let vx = w - 58, vy = h * 0.20
        ctx.stroke(Path { p in
            p.move(to: CGPoint(x: vx, y: vy + 34)); p.addLine(to: CGPoint(x: vx, y: vy - 6))
        }, with: .color(Color(hex: 0x6B4A2B)), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        let ripple = sin(now * 5.5) * 3
        ctx.fill(Path { p in
            p.move(to: CGPoint(x: vx, y: vy - 6))
            p.addQuadCurve(to: CGPoint(x: vx + wind * 13, y: vy + 2),
                           control: CGPoint(x: vx + wind * 8, y: vy - 2 + ripple))
            p.addLine(to: CGPoint(x: vx + wind * 13, y: vy + 8))
            p.addQuadCurve(to: CGPoint(x: vx, y: vy + 6),
                           control: CGPoint(x: vx + wind * 8, y: vy + 6 + ripple))
            p.closeSubpath()
        }, with: .color(Theme.ouro))

        ctx.fill(Path(roundedRect: CGRect(x: vx - 34, y: vy + 40, width: 72, height: 22),
                      cornerRadius: 11),
                 with: .color(Theme.serraDark.opacity(0.78)))
        let dir = wind < -0.3 ? "←" : (wind > 0.3 ? "→" : "·")
        ctx.draw(
            Text("vento \(dir) \(String(format: "%.1f", abs(wind)))")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Theme.creme),
            at: CGPoint(x: vx + 2, y: vy + 51), anchor: .center)
    }

    private static func drawFlight(_ ctx: inout GraphicsContext, flight: ArcherEngine.Flight, h: CGFloat) {
        let t = min(flight.t, 1)
        let ease = 1 - (1 - t) * (1 - t)
        let fx = flight.from.x + (flight.to.x - flight.from.x) * ease
        let fy = flight.from.y + (flight.to.y - flight.from.y) * ease - sin(t * .pi) * h * 0.06
        let scale = 1 + (0.28 - 1) * ease
        let angle = atan2(flight.to.y - flight.from.y, flight.to.x - flight.from.x)

        var c = ctx
        c.translateBy(x: fx, y: fy)
        c.rotate(by: .radians(angle))
        c.scaleBy(x: scale, y: scale)
        c.stroke(Path { p in
            p.move(to: CGPoint(x: -34, y: 0)); p.addLine(to: CGPoint(x: 20, y: 0))
        }, with: .color(Color(hex: 0x4A3524)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        c.fill(Path { p in
            p.move(to: CGPoint(x: 20, y: 0)); p.addLine(to: CGPoint(x: 8, y: -6))
            p.addLine(to: CGPoint(x: 8, y: 6)); p.closeSubpath()
        }, with: .color(Color(hex: 0x57636B)))
        c.fill(Path { p in
            p.move(to: CGPoint(x: -34, y: 0)); p.addLine(to: CGPoint(x: -26, y: -7))
            p.addLine(to: CGPoint(x: -20, y: 0)); p.addLine(to: CGPoint(x: -26, y: 7))
            p.closeSubpath()
        }, with: .color(Theme.terra))
    }

    private static func drawBow(_ ctx: inout GraphicsContext, w: CGFloat, h: CGFloat,
                                aim: ArcherEngine.Aim?, hasNockedArrow: Bool,
                                avatar: AvatarConfig, now: TimeInterval) {
        let pull = aim?.power ?? 0
        let sway = sin(now * 1.1) * 2
        let reach = h * 0.30

        var c = ctx
        c.translateBy(x: w * 0.5 + (aim.map { ($0.point.x - w / 2) * 0.12 } ?? 0), y: h * 0.98)
        c.rotate(by: .radians((aim.map { ($0.point.x - w / 2) / w * 0.5 } ?? 0) + sway * 0.004))

        // corpo do arco (madeira em duas camadas)
        let bowPath = Path { p in
            p.move(to: CGPoint(x: -reach * 0.42, y: -reach * 0.55))
            p.addQuadCurve(to: CGPoint(x: reach * 0.42, y: -reach * 0.55),
                           control: CGPoint(x: reach * 0.20, y: -reach * 0.95))
        }
        c.stroke(bowPath, with: .color(Color(hex: 0x6B4A2B)),
                 style: StrokeStyle(lineWidth: 11, lineCap: .round))
        c.stroke(bowPath, with: .color(Color(hex: 0x8A6238)),
                 style: StrokeStyle(lineWidth: 5, lineCap: .round))

        // corda, recuando com a puxada
        let stringY = -reach * 0.30 + pull * reach * 0.34
        c.stroke(Path { p in
            p.move(to: CGPoint(x: -reach * 0.42, y: -reach * 0.55))
            p.addLine(to: CGPoint(x: 0, y: stringY))
            p.addLine(to: CGPoint(x: reach * 0.42, y: -reach * 0.55))
        }, with: .color(Theme.creme.opacity(0.9)), lineWidth: 2)

        // flecha nocada
        if hasNockedArrow {
            c.stroke(Path { p in
                p.move(to: CGPoint(x: 0, y: stringY))
                p.addLine(to: CGPoint(x: 0, y: stringY - reach * 0.72))
            }, with: .color(Color(hex: 0x4A3524)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            c.fill(Path { p in
                p.move(to: CGPoint(x: 0, y: stringY - reach * 0.72))
                p.addLine(to: CGPoint(x: -6, y: stringY - reach * 0.60))
                p.addLine(to: CGPoint(x: 6, y: stringY - reach * 0.60))
                p.closeSubpath()
            }, with: .color(Color(hex: 0x57636B)))
        }

        // mão na corda e manga — com as cores do avatar
        c.fill(Path(ellipseIn: CGRect(x: -13, y: stringY - 13, width: 26, height: 26)),
               with: .color(avatar.skinColor))
        c.fill(Path(roundedRect: CGRect(x: -16, y: stringY + 8, width: 32, height: 60),
                    cornerRadius: 14),
               with: .color(avatar.clothesColor))
    }

    private static func drawReticle(_ ctx: inout GraphicsContext, aim: ArcherEngine.Aim,
                                    w: CGFloat, h: CGFloat) {
        let m = aim.point
        let r = 16 + (1 - aim.power) * 10
        let color = Theme.tinta.opacity(0.85)

        ctx.stroke(Path(ellipseIn: CGRect(x: m.x - r, y: m.y - r, width: r * 2, height: r * 2)),
                   with: .color(color), lineWidth: 2.5)
        ctx.stroke(Path { p in
            p.move(to: CGPoint(x: m.x - r - 8, y: m.y)); p.addLine(to: CGPoint(x: m.x - r + 4, y: m.y))
            p.move(to: CGPoint(x: m.x + r + 8, y: m.y)); p.addLine(to: CGPoint(x: m.x + r - 4, y: m.y))
            p.move(to: CGPoint(x: m.x, y: m.y - r - 8)); p.addLine(to: CGPoint(x: m.x, y: m.y - r + 4))
            p.move(to: CGPoint(x: m.x, y: m.y + r + 8)); p.addLine(to: CGPoint(x: m.x, y: m.y + r - 4))
        }, with: .color(color), lineWidth: 2.5)
        ctx.fill(Path(ellipseIn: CGRect(x: m.x - 3, y: m.y - 3, width: 6, height: 6)),
                 with: .color(Theme.terra))

        // barra de força
        ctx.fill(Path(roundedRect: CGRect(x: w / 2 - 70, y: h - 86, width: 140, height: 14),
                      cornerRadius: 7),
                 with: .color(Theme.serraDark.opacity(0.78)))
        ctx.fill(Path(roundedRect: CGRect(x: w / 2 - 66, y: h - 83, width: 132 * aim.power, height: 8),
                      cornerRadius: 4),
                 with: .color(aim.power > 0.95 ? Theme.ouro : Theme.terra))
    }

    private static func drawNotice(_ ctx: inout GraphicsContext, text: String, w: CGFloat, h: CGFloat) {
        let resolved = ctx.resolve(
            Text(text)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.creme))
        let tSize = resolved.measure(in: CGSize(width: 600, height: 100))
        ctx.fill(Path(roundedRect: CGRect(x: w / 2 - tSize.width / 2 - 20, y: h * 0.47 - 23,
                                          width: tSize.width + 40, height: 46),
                      cornerRadius: 23),
                 with: .color(Theme.serraDark.opacity(0.85)))
        ctx.draw(resolved, at: CGPoint(x: w / 2, y: h * 0.47), anchor: .center)
    }
}
