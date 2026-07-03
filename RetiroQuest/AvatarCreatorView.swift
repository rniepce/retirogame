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
                VStack(spacing: 8) {
                    Text("SEU PERSONAGEM")
                        .font(Theme.px(8))
                        .foregroundStyle(Theme.terra)
                    Text("MONTE SEU\nEXPLORADOR")
                        .font(Theme.px(16))
                        .foregroundStyle(Theme.tinta)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .shadow(color: Theme.areiaDark, radius: 0, x: 2, y: 2)
                }
                .padding(.top, 18)
                .padding(.bottom, 8)

                ZStack {
                    Circle().fill(Theme.creme)
                    AvatarView(config: draft)
                        .frame(width: 128, height: 148)
                        .offset(y: 14)
                }
                .frame(width: 172, height: 172)
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.tinta, lineWidth: 4))
                .background(Circle().fill(Theme.tinta).offset(x: 4, y: 6))
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
                .font(Theme.px(8))
                .foregroundStyle(Color(hex: 0x6B5B44))
            content()
        }
    }

    private func segmented(_ items: [(label: String, selected: Bool)], action: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 10) {
            ForEach(items.indices, id: \.self) { i in
                Button { action(i) } label: {
                    Text(items[i].label.uppercased())
                        .font(Theme.px(9))
                        .foregroundStyle(items[i].selected ? Theme.terraDark : Theme.tinta)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(items[i].selected ? Color(hex: 0xFBE3D3) : Theme.creme)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(items[i].selected ? Theme.terra : Color(hex: 0xD8C79E), lineWidth: 3)
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
