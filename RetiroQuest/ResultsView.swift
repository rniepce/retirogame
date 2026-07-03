import SwiftUI

struct ResultsView: View {
    let poi: POI
    let result: MinigameResult

    @EnvironmentObject private var app: AppState

    private var title: String {
        switch result.stars {
        case 3: return "Na mosca!"
        case 1, 2: return "Muito bem!"
        default: return "Quase lá…"
        }
    }

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: 0x2C5A3C), Theme.serraDark],
                           center: .init(x: 0.5, y: 0.3),
                           startRadius: 40, endRadius: 500)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                if let id = poi.minigame {
                    Text("\(poi.name) — \(MinigameCatalog.info(id).title)".uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .kerning(2)
                        .foregroundStyle(Theme.grama)
                }
                Text(title)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.creme)

                Text(starsText(result.stars))
                    .font(.system(size: 52))
                    .kerning(8)
                    .foregroundStyle(Theme.ouro)
                    .padding(.vertical, 8)

                Text(result.phrase)
                    .font(.system(size: 17, design: .rounded))
                    .foregroundStyle(Theme.creme.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .padding(.bottom, 26)

                VStack(spacing: 12) {
                    Button("Jogar de novo") { app.route = .minigame(poi) }
                        .buttonStyle(GameButtonStyle())
                    Button("Voltar ao mapa") { app.route = .map }
                        .buttonStyle(GhostButtonStyle())
                }
                .frame(maxWidth: 300)
            }
            .padding(.horizontal, 30)
        }
    }
}
