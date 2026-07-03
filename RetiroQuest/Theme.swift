import SwiftUI
import UIKit
import CoreText

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

    /// Fonte pixel do jogo (Press Start 2P, licença OFL — registrada em runtime).
    static func px(_ size: CGFloat) -> Font { .custom("PressStart2P-Regular", size: size) }
}

/// Registra a fonte pixel embarcada no bundle (dispensa Info.plist).
enum PixelFont {
    static func register() {
        guard let url = Bundle.main.url(forResource: "PressStart2P-Regular", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

/// Scanlines de CRT — véu retrô aplicado por cima das telas.
struct Scanlines: View {
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1.4)),
                         with: .color(.black.opacity(0.07)))
                y += 4
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

extension View {
    /// Acabamento vintage: scanlines por cima de tudo.
    func crt() -> some View { overlay(Scanlines()) }
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

/// Botão "cartucho" vintage: retângulo chapado, borda grossa de tinta e
/// sombra dura em degrau que afunda ao tocar.
struct GameButtonStyle: ButtonStyle {
    var background: Color = Theme.terra
    var shadow: Color = Theme.terraDark

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.px(13))
            .textCase(.uppercase)
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .padding(.horizontal, 22)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.tinta)
                        .offset(x: configuration.isPressed ? 1 : 4,
                                y: configuration.isPressed ? 1 : 4)
                    RoundedRectangle(cornerRadius: 3).fill(background)
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Theme.tinta, lineWidth: 3)
                }
            )
            .offset(x: configuration.isPressed ? 3 : 0,
                    y: configuration.isPressed ? 3 : 0)
    }
}

/// Botão secundário vintage: contorno duplo creme sobre fundo escuro.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.px(12))
            .textCase(.uppercase)
            .foregroundStyle(Theme.creme)
            .padding(.vertical, 14)
            .padding(.horizontal, 22)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Theme.creme.opacity(0.8), lineWidth: 3)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(Theme.creme.opacity(0.35), lineWidth: 2)
                            .padding(4)
                    )
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Placar de HUD estilo fliperama: caixa quadrada com borda e dígitos pixel.
struct HUDChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.px(10))
            .monospacedDigit()
            .foregroundStyle(Theme.creme)
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.serraDark.opacity(0.88))
                    .overlay(RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Theme.creme.opacity(0.7), lineWidth: 2))
            )
    }
}
