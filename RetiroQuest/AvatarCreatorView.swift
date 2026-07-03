import SwiftUI

struct AvatarCreatorView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var progress: GameProgress
    @State private var draft = AvatarConfig()
    @State private var loaded = false

    var body: some View {
        ZStack {
            Theme.areia.ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("SEU PERSONAGEM")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .kerning(2.2)
                        .foregroundStyle(Theme.terra)
                    Text("Monte seu explorador")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.tinta)
                }
                .padding(.top, 18)
                .padding(.bottom, 8)

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(colors: [Theme.creme, Color(hex: 0xE8D8B0)],
                                           center: .init(x: 0.5, y: 0.38),
                                           startRadius: 10, endRadius: 110)
                        )
                    AvatarView(config: draft)
                        .frame(width: 128, height: 148)
                        .offset(y: 14)
                }
                .frame(width: 172, height: 172)
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.creme, lineWidth: 5))
                .shadow(color: Theme.tinta.opacity(0.18), radius: 12, y: 8)
                .padding(.bottom, 6)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        optionGroup("Estilo") {
                            segmented(AvatarConfig.Gender.allCases.map { ($0.label, $0 == draft.gender) }) { i in
                                draft.gender = AvatarConfig.Gender.allCases[i]
                            }
                        }
                        optionGroup("Cor da pele") {
                            colorRow(Palette.skins, selected: draft.skin) { draft.skin = $0 }
                        }
                        optionGroup("Tamanho do cabelo") {
                            segmented(AvatarConfig.HairSize.allCases.map { ($0.label, $0 == draft.hairSize) }) { i in
                                draft.hairSize = AvatarConfig.HairSize.allCases[i]
                            }
                        }
                        optionGroup("Cor do cabelo") {
                            colorRow(Palette.hairs, selected: draft.hairColor) { draft.hairColor = $0 }
                        }
                        optionGroup("Cor da roupa") {
                            colorRow(Palette.clothes, selected: draft.clothes) { draft.clothes = $0 }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                }

                HStack(spacing: 12) {
                    Button("🎲 Sortear") { draft = .random() }
                        .buttonStyle(GameButtonStyle(background: Color(hex: 0x5B7A54), shadow: Color(hex: 0x40593B)))
                        .frame(maxWidth: .infinity)
                    Button("Pronto!") {
                        progress.avatar = draft
                        progress.avatarReady = true
                        app.route = .map
                    }
                    .buttonStyle(GameButtonStyle())
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
            }
        }
        .onAppear {
            if !loaded { draft = progress.avatar; loaded = true }
        }
    }

    // MARK: componentes

    private func optionGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .kerning(1.5)
                .foregroundStyle(Color(hex: 0x6B5B44))
            content()
        }
    }

    private func segmented(_ items: [(label: String, selected: Bool)], action: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 10) {
            ForEach(items.indices, id: \.self) { i in
                Button { action(i) } label: {
                    Text(items[i].label)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(items[i].selected ? Theme.terraDark : Theme.tinta)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(items[i].selected ? Color(hex: 0xFBE3D3) : Theme.creme)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(items[i].selected ? Theme.terra : Color(hex: 0xD8C79E), lineWidth: 2.5)
                        )
                }
            }
        }
    }

    private func colorRow(_ hexes: [String], selected: String, action: @escaping (String) -> Void) -> some View {
        HStack(spacing: 12) {
            ForEach(hexes, id: \.self) { hex in
                Button { action(hex) } label: {
                    Circle()
                        .fill(Color(hexString: hex))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle().strokeBorder(
                                hex == selected ? Theme.tinta : Theme.tinta.opacity(0.12),
                                lineWidth: 3)
                        )
                        .overlay(
                            Circle()
                                .stroke(Theme.terra, lineWidth: hex == selected ? 2.5 : 0)
                                .padding(-5)
                        )
                }
                .accessibilityLabel("Cor \(hex)")
            }
        }
    }
}
