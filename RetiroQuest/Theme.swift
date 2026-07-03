import SwiftUI
import UIKit

// Paleta extraída da imagem de satélite do condomínio:
// telhados terracota, mata da serra, piscina do clube, ruas de areia.
enum Theme {
    static let terra      = Color(hex: 0xC8552F)
    static let terraDark  = Color(hex: 0xA03E1F)
    static let serra      = Color(hex: 0x1E3A28)
    static let serraDark  = Color(hex: 0x142A1C)
    static let grama      = Color(hex: 0x8FB569)
    static let piscina    = Color(hex: 0x3FA9C9)
    static let areia      = Color(hex: 0xEFE3C8)
    static let areiaDark  = Color(hex: 0xDECFA9)
    static let tinta      = Color(hex: 0x241F17)
    static let creme      = Color(hex: 0xFFF8EA)
    static let ouro       = Color(hex: 0xF2B23E)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
    init(hexString: String) {
        self.init(hex: UInt32(hexString, radix: 16) ?? 0)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
    convenience init(hexString: String, alpha: CGFloat = 1) {
        self.init(hex: UInt32(hexString, radix: 16) ?? 0, alpha: alpha)
    }
}

/// Botão-cápsula do jogo: cor cheia com "degrau" de sombra que afunda ao tocar.
struct GameButtonStyle: ButtonStyle {
    var background: Color = Theme.terra
    var shadow: Color = Theme.terraDark

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 19, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .padding(.horizontal, 30)
            .background(
                ZStack {
                    Capsule().fill(shadow).offset(y: configuration.isPressed ? 1 : 4)
                    Capsule().fill(background)
                }
            )
            .offset(y: configuration.isPressed ? 3 : 0)
    }
}

/// Botão "fantasma" com contorno creme, para fundos escuros.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 19, weight: .heavy, design: .rounded))
            .foregroundStyle(Theme.creme)
            .padding(.vertical, 15)
            .padding(.horizontal, 30)
            .background(Capsule().strokeBorder(Theme.creme.opacity(0.55), lineWidth: 2.5))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Chip de HUD (fundo escuro translúcido, texto creme).
struct HUDChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Theme.creme)
            .padding(.vertical, 9)
            .padding(.horizontal, 15)
            .background(Capsule().fill(Theme.serraDark.opacity(0.78)))
    }
}
