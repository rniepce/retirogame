import SwiftUI

/// Memória dos Vitrais: encontre os 8 pares no menor número de jogadas.
/// (Jogo em SwiftUI puro — cartas com animação de flip.)
struct MemoryGameView: View {
    let onExit: () -> Void
    let onFinish: (MinigameResult) -> Void

    struct Card: Identifiable {
        let id: Int
        let symbol: String
        var up = false
        var matched = false
    }

    @State private var cards: [Card] = {
        let symbols = ["🕊️", "✝️", "🌹", "👼", "🔔", "🐟", "☀️", "🍇"]
        return (symbols + symbols).shuffled().enumerated().map {
            Card(id: $0.offset, symbol: $0.element, up: true)   // espiada inicial
        }
    }()
    @State private var faceUp: [Int] = []
    @State private var moves = 0
    @State private var locked = false
    @State private var won = false
    @State private var peeking = true

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        ZStack {
            // interior da capela (faixas chapadas)
            VStack(spacing: 0) {
                Color(hex: 0x3A2E4F)
                Color(hex: 0x2F2740)
                Color(hex: 0x241F30)
            }
            .ignoresSafeArea()
            // rosácea da capela ao fundo
            VitralArch()
                .allowsHitTesting(false)
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xF2B23E).opacity(0.25), .clear],
                                     center: .center, startRadius: 10, endRadius: 170))
                .frame(width: 320, height: 320)
                .offset(y: -180)
                .allowsHitTesting(false)
            // velas tremulando nos cantos
            CandleGlow().offset(x: -150, y: 330)
            CandleGlow().offset(x: 150, y: 330)

            VStack(spacing: 14) {
                Text(peeking ? "MEMORIZE OS VITRAIS!" : "MEMÓRIA DOS VITRAIS")
                    .font(Theme.px(10))
                    .foregroundStyle(Theme.ouro)
                    .padding(.top, 60)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(cards) { card in
                        CardView(card: card)
                            .onTapGesture { flip(card) }
                    }
                }
                .padding(.horizontal, 22)
                Spacer()
            }
        }
        .overlay(alignment: .top) {
            HStack {
                ExitButton(action: onExit)
                Spacer()
                HUDChip(text: "🪟 \(moves) jogadas")
            }
            .padding(.horizontal, 16)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                withAnimation(.spring(duration: 0.4)) {
                    for i in cards.indices { cards[i].up = false }
                }
                peeking = false
            }
        }
    }

    private func flip(_ card: Card) {
        guard !peeking, !locked, !card.up, !card.matched, !won,
              let idx = cards.firstIndex(where: { $0.id == card.id }) else { return }
        withAnimation(.spring(duration: 0.35)) { cards[idx].up = true }
        faceUp.append(idx)
        Haptics.light()

        guard faceUp.count == 2 else { return }
        moves += 1
        let (a, b) = (faceUp[0], faceUp[1])
        faceUp = []
        if cards[a].symbol == cards[b].symbol {
            cards[a].matched = true
            cards[b].matched = true
            Haptics.success()
            if cards.allSatisfy(\.matched) {
                won = true
                let points = max(0, 80 - max(0, moves - 8) * 4)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    onFinish(MinigameResult(
                        points: points, stars: starsFor(score: points, max: 80),
                        phrase: "Fechou em \(moves) jogadas. " +
                            (points >= 64 ? "Memória de elefante!" :
                                points >= 44 ? "Muito bem!" : "Os vitrais confundem mesmo…")))
                }
            }
        } else {
            locked = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(duration: 0.35)) {
                    cards[a].up = false
                    cards[b].up = false
                }
                locked = false
            }
        }
    }

    /// Janela em arco com vitrais coloridos, atrás do tabuleiro.
    private struct VitralArch: View {
        var body: some View {
            Canvas { ctx, size in
                let cx = size.width / 2
                let archW: CGFloat = 190, archTop: CGFloat = 26
                var arch = Path()
                arch.move(to: CGPoint(x: cx - archW / 2, y: archTop + 320))
                arch.addLine(to: CGPoint(x: cx - archW / 2, y: archTop + 90))
                arch.addQuadCurve(to: CGPoint(x: cx + archW / 2, y: archTop + 90),
                                  control: CGPoint(x: cx, y: archTop - 40))
                arch.addLine(to: CGPoint(x: cx + archW / 2, y: archTop + 320))
                arch.closeSubpath()
                ctx.stroke(arch, with: .color(Color(hex: 0xF2B23E).opacity(0.3)), lineWidth: 3)
                // caixilhos com vitrais translúcidos
                let panes: [Color] = [Color(hex: 0xC8552F), Color(hex: 0x3FA9C9),
                                      Color(hex: 0xF2B23E), Color(hex: 0x8E5BA6)]
                for (i, pane) in panes.enumerated() {
                    let px = cx - archW / 2 + 12 + CGFloat(i) * (archW - 24) / 4
                    ctx.fill(Path(roundedRect: CGRect(x: px, y: archTop + 100,
                                                      width: (archW - 24) / 4 - 6, height: 200),
                                  cornerRadius: 3),
                             with: .color(pane.opacity(0.1)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Brilho de vela tremulando.
    private struct CandleGlow: View {
        var body: some View {
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                let flicker = 0.16 + 0.07 * sin(t * 7) + 0.04 * sin(t * 13)
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xF2B23E).opacity(flicker), .clear],
                                         center: .center, startRadius: 2, endRadius: 60))
                    .frame(width: 120, height: 120)
            }
            .allowsHitTesting(false)
        }
    }

    private struct CardView: View {
        let card: Card
        var body: some View {
            ZStack {
                // verso: rosácea de vitral
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: 0x5B4A8A))
                    .overlay(
                        Circle().stroke(Theme.ouro.opacity(0.7), lineWidth: 2)
                            .padding(10)
                            .overlay(Circle().stroke(Theme.ouro.opacity(0.4), lineWidth: 1.5).padding(18))
                    )
                    .opacity(card.up || card.matched ? 0 : 1)

                // frente: vitral colorido com o símbolo
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.creme)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(card.matched ? Theme.ouro : Color(hex: 0xB59A66), lineWidth: 3)
                    )
                    .overlay(Text(card.symbol).font(.system(size: 34)))
                    .opacity(card.up || card.matched ? 1 : 0)
            }
            .aspectRatio(0.78, contentMode: .fit)
            .rotation3DEffect(.degrees(card.up || card.matched ? 0 : 180),
                              axis: (x: 0, y: 1, z: 0))
            .opacity(card.matched ? 0.75 : 1)
        }
    }
}
