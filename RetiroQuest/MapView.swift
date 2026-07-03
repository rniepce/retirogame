import SwiftUI
import SpriteKit

struct MapView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var progress: GameProgress
    @State private var selectedPOI: POI?
    @State private var showHint = false

    var body: some View {
        ZStack {
            Theme.serraDark.ignoresSafeArea()
            SpriteView(scene: app.mapScene)
                .ignoresSafeArea()

            VStack {
                HStack {
                    HUDChip(text: "🗺️ Retiro das Pedras")
                    Spacer()
                    HUDChip(text: "⭐ \(progress.totalStars)")
                }
                .padding(.horizontal, 16)
                Spacer()
                if showHint {
                    Text("TOQUE NUM LUGAR DO MAPA\nPARA CAMINHAR ATÉ LÁ")
                        .font(Theme.px(8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .foregroundStyle(Theme.creme)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Theme.serraDark.opacity(0.88))
                                .overlay(RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(Theme.creme.opacity(0.7), lineWidth: 2))
                        )
                        .padding(.bottom, 16)
                        .transition(.opacity)
                }
            }

            if let poi = selectedPOI {
                POICard(poi: poi, earnedStars: progress.stars(for: poi.minigame)) {
                    withAnimation(.spring(duration: 0.3)) { selectedPOI = nil }
                } onPlay: {
                    selectedPOI = nil
                    app.route = .minigame(poi)
                }
            }
        }
        .onAppear {
            app.mapScene.configure(avatar: progress.avatar, stars: progress.stars) { poi in
                withAnimation(.spring(duration: 0.3)) { selectedPOI = poi }
            }
            if !app.mapHintShown {
                app.mapHintShown = true
                showHint = true
            }
        }
        .onChange(of: progress.stars) { _, new in
            app.mapScene.refreshPins(stars: new)
        }
        .task {
            guard showHint else { return }
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            withAnimation(.easeOut(duration: 0.4)) { showHint = false }
        }
    }
}

/// Cartão inferior de um ponto do mapa.
struct POICard: View {
    let poi: POI
    let earnedStars: Int
    let onClose: () -> Void
    let onPlay: () -> Void

    private var info: MinigameInfo? { poi.minigame.map(MinigameCatalog.info) }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 10) {
                Text(poi.icon).font(.system(size: 44))
                Text((info.map { "\(poi.name) — \($0.title)" } ?? poi.name).uppercased())
                    .font(Theme.px(12))
                    .foregroundStyle(Theme.tinta)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                Text(info?.description ?? poi.blurb)
                    .font(Theme.px(8))
                    .foregroundStyle(Color(hex: 0x6B5B44))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                Text(info != nil ? starsText(earnedStars) : "🔒")
                    .font(.system(size: 22))
                    .padding(.bottom, 8)

                HStack(spacing: 12) {
                    Button("Voltar", action: onClose)
                        .buttonStyle(GameButtonStyle(background: Color(hex: 0xB9A778), shadow: Color(hex: 0x94845B)))
                        .frame(maxWidth: .infinity)
                    Button(info == nil ? "Em breve" : (earnedStars > 0 ? "Jogar de novo" : "Jogar"), action: onPlay)
                        .buttonStyle(GameButtonStyle())
                        .frame(maxWidth: .infinity)
                        .disabled(info == nil)
                        .opacity(info == nil ? 0.45 : 1)
                }
            }
            .padding(26)
            .frame(maxWidth: 440)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8)
                    .fill(Theme.creme)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Theme.tinta).frame(height: 4)
                    }
                    .ignoresSafeArea(edges: .bottom)
            )
            .transition(.move(edge: .bottom))
        }
        .animation(.spring(duration: 0.3), value: poi.id)
    }
}
