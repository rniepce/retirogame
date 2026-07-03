import SwiftUI
import UIKit

// MARK: - Relógio de jogo (CADisplayLink)

final class GameLoop: NSObject {
    var onTick: ((Double) -> Void)?
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0

    func start() {
        guard link == nil else { return }
        last = CACurrentMediaTime()
        let l = CADisplayLink(target: self, selector: #selector(step))
        l.add(to: .main, forMode: .common)
        link = l
    }
    func stop() {
        link?.invalidate()
        link = nil
    }
    @objc private func step() {
        let now = CACurrentMediaTime()
        let dt = min(now - last, 0.05)
        last = now
        onTick?(dt)
    }
}

// MARK: - Háptica

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

func starsFor(score: Int, max maxScore: Int) -> Int {
    guard maxScore > 0 else { return 0 }
    let f = Double(score) / Double(maxScore)
    if f >= 0.8 { return 3 }
    if f >= 0.55 { return 2 }
    if f >= 0.3 { return 1 }
    return 0
}

struct GameNotice {
    let text: String
    let until: TimeInterval
}

// MARK: - Motor base dos minigames

/// Subclasses sobrescrevem didStart/tick/tap/drag e chamam finish(...).
class MiniEngine: NSObject, ObservableObject {
    @Published var hud = ""
    var viewSize: CGSize = .zero
    var notice: GameNotice?
    var holding = false
    private(set) var finished = false
    private(set) var elapsed: Double = 0
    var onFinish: ((MinigameResult) -> Void)?
    private let loop = GameLoop()

    func start() {
        loop.onTick = { [weak self] dt in
            guard let self, !self.finished else { return }
            self.elapsed += dt
            self.tick(dt: dt)
        }
        didStart()
        loop.start()
    }
    func stop() { loop.stop() }

    // pontos de extensão
    func didStart() {}
    func tick(dt: Double) {}
    func tap(at point: CGPoint) {}
    func dragChanged(start: CGPoint, current: CGPoint) {}
    func dragEnded(start: CGPoint, current: CGPoint) {}

    func setHUD(_ text: String) { if hud != text { hud = text } }
    func say(_ text: String, for duration: Double = 0.9) {
        notice = GameNotice(text: text, until: CACurrentMediaTime() + duration)
    }

    static let defaultPhrases = [
        "Foi por pouco — tente de novo!",
        "Bom começo!",
        "Mandou muito bem!",
        "Perfeito. Lenda do condomínio!",
    ]

    func finish(points: Int, maxPoints: Int, stars: Int? = nil,
                phrases: [String] = MiniEngine.defaultPhrases) {
        guard !finished else { return }
        finished = true
        stop()
        let s = stars ?? starsFor(score: points, max: maxPoints)
        onFinish?(MinigameResult(points: points, stars: s,
                                 phrase: "\(points) de \(maxPoints) pontos. \(phrases[min(max(s, 0), phrases.count - 1)])"))
    }
}

// MARK: - Hospedeiro padrão (canvas + gestos + HUD)

struct MiniGameHost<E: MiniEngine>: View {
    private let background: Color
    private let onExit: () -> Void
    private let onFinish: (MinigameResult) -> Void
    private let draw: (E, inout GraphicsContext, CGSize) -> Void
    @StateObject private var engine: E

    init(engine: @autoclosure @escaping () -> E,
         background: Color,
         onExit: @escaping () -> Void,
         onFinish: @escaping (MinigameResult) -> Void,
         draw: @escaping (E, inout GraphicsContext, CGSize) -> Void) {
        _engine = StateObject(wrappedValue: engine())
        self.background = background
        self.onExit = onExit
        self.onFinish = onFinish
        self.draw = draw
    }

    var body: some View {
        TimelineView(.animation) { _ in
            Canvas { ctx, size in
                engine.viewSize = size
                draw(engine, &ctx, size)
                GamePaint.notice(&ctx, engine: engine, size: size)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    engine.holding = true
                    engine.dragChanged(start: v.startLocation, current: v.location)
                }
                .onEnded { v in
                    engine.holding = false
                    if hypot(v.translation.width, v.translation.height) < 12 {
                        engine.tap(at: v.location)
                    }
                    engine.dragEnded(start: v.startLocation, current: v.location)
                }
        )
        .ignoresSafeArea()
        .background(background)
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
                HUDChip(text: engine.hud)
            }
            .padding(.horizontal, 16)
        }
        .onAppear {
            engine.onFinish = onFinish
            engine.start()
        }
        .onDisappear { engine.stop() }
    }
}

// MARK: - Pinturas compartilhadas

enum GamePaint {
    static func notice(_ ctx: inout GraphicsContext, engine: MiniEngine, size: CGSize) {
        guard let n = engine.notice, CACurrentMediaTime() < n.until else { return }
        let resolved = ctx.resolve(
            Text(n.text)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.creme))
        let t = resolved.measure(in: CGSize(width: 600, height: 100))
        let y = size.height * 0.45
        ctx.fill(Path(roundedRect: CGRect(x: size.width / 2 - t.width / 2 - 18, y: y - 22,
                                          width: t.width + 36, height: 44),
                      cornerRadius: 22),
                 with: .color(Theme.serraDark.opacity(0.85)))
        ctx.draw(resolved, at: CGPoint(x: size.width / 2, y: y), anchor: .center)
    }

    static func timeBar(_ ctx: inout GraphicsContext, size: CGSize, remaining: Double, total: Double) {
        let frac = max(0, min(1, remaining / total))
        ctx.fill(Path(roundedRect: CGRect(x: size.width / 2 - 70, y: size.height - 86,
                                          width: 140, height: 12), cornerRadius: 6),
                 with: .color(Theme.serraDark.opacity(0.78)))
        ctx.fill(Path(roundedRect: CGRect(x: size.width / 2 - 66, y: size.height - 83,
                                          width: 132 * frac, height: 6), cornerRadius: 3),
                 with: .color(frac < 0.25 ? Theme.terra : Theme.grama))
    }

    static func emoji(_ ctx: inout GraphicsContext, _ symbol: String, at p: CGPoint, size: CGFloat) {
        ctx.draw(Text(symbol).font(.system(size: size)), at: p, anchor: .center)
    }
}
