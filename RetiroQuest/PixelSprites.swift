import SwiftUI

/// Motor de sprites pixel: cada sprite é uma grade de caracteres em que
/// cada letra vira um quadradinho chapado ('.' = transparente).
enum Px {
    static let palette: [Character: Color] = [
        "K": Theme.tinta,             // contorno
        "W": Theme.creme,             // branco
        "R": Theme.terra,             // terracota
        "O": Color(hex: 0xF08A24),    // laranja
        "Y": Theme.ouro,              // ouro
        "G": Color(hex: 0x4E8F5C),    // verde
        "E": Color(hex: 0x2C5A3C),    // verde escuro
        "B": Theme.piscina,           // azul
        "N": Color(hex: 0x8A6238),    // madeira
        "S": Color(hex: 0x57636B),    // pedra
        "L": Color(hex: 0xB9BEC4),    // cinza claro
        "P": Color(hex: 0xE86FA0),    // rosa
        "D": Theme.serraDark,         // sombra
    ]

    static func draw(_ ctx: inout GraphicsContext, _ rows: [String], at center: CGPoint,
                     pixel: CGFloat, colors: [Character: Color] = Px.palette,
                     flipX: Bool = false) {
        let hgt = CGFloat(rows.count) * pixel
        let wid = CGFloat(rows[0].count) * pixel
        let origin = CGPoint(x: center.x - wid / 2, y: center.y - hgt / 2)
        for (ry, rowStr) in rows.enumerated() {
            let row = flipX ? String(rowStr.reversed()) : rowStr
            for (rx, ch) in row.enumerated() {
                guard ch != ".", let color = colors[ch] else { continue }
                ctx.fill(Path(CGRect(x: origin.x + CGFloat(rx) * pixel,
                                     y: origin.y + CGFloat(ry) * pixel,
                                     width: pixel + 0.4, height: pixel + 0.4)),
                         with: .color(color))
            }
        }
    }

    static func tinted(_ overrides: [Character: Color]) -> [Character: Color] {
        palette.merging(overrides) { _, new in new }
    }

    // MARK: - Bolas

    static let soccer = [
        "..KKKK..", ".KWWWWK.", "KWWKKWWK", "KWKWWKWK",
        "KWKWWKWK", "KWWKKWWK", ".KWWWWK.", "..KKKK..",
    ]
    static let basketball = [
        "..KKKK..", ".KOKKOK.", "KOOKKOOK", "KOOKKOOK",
        "KKKKKKKK", "KOOKKOOK", ".KOKKOK.", "..KKKK..",
    ]
    static let volleyball = [
        "..KKKK..", ".KWWWBK.", "KWWWBWWK", "KWBBWWWK",
        "KWWWBBWK", "KWWBWWWK", ".KBWWWK.", "..KKKK..",
    ]
    static let softball = [
        "..KKKK..", ".KYYYYK.", "KYWYYWYK", "KYWYYWYK",
        "KYWYYWYK", "KYWYYWYK", ".KYYYYK.", "..KKKK..",
    ]

    // MARK: - Bichos e natureza

    static let fish = [
        "...KKKK...", "..KBBBBK.K", ".KBWBBBKKK", ".KBBBBBKKK",
        "..KBBBBK.K", "...KKKK...",
    ]
    static let star = [
        "...YY...", "...YY...", "..YYYY..", "YYYYYYYY",
        ".YYYYYY.", "..YYYY..", ".YY..YY.", "YY....YY",
    ]
    static let cloud = [
        "....WWWW....", "..WWWWWWWW..", ".WWWWWWWWWW.",
        "WWWWWWWWWWWW", "LLLLLLLLLLLL",
    ]
    static let sun = [
        "Y..YY..Y", ".YYYYYY.", ".YOOOOY.", "YYOOOOYY",
        "YYOOOOYY", ".YOOOOY.", ".YYYYYY.", "Y..YY..Y",
    ]
    static let tree = [
        "..GGGG..", ".GGGGGG.", "GEGGGGEG", "GGGGGGGG",
        ".GGEGGG.", "..GGGG..", "...NN...", "...NN...", "...NN...",
    ]
    static let sparkle = [
        "...W...", "..WWW..", ".WWWWW.", "..WWW..", "...W...",
    ]
    static let dog = [
        "KK........", "KNNK...KKK", ".KNNKKKNNK", ".KNNNNNNWK",
        ".KNNNNNNKK", "..KNKKNK..", "..KK..KK..",
    ]

    // MARK: - Objetos

    static let cone = [
        "...KK...", "..KOOK..", "..KOOK..", ".KOWWOK.",
        ".KOOOOK.", "KOWWWWOK", "KKKKKKKK",
    ]
    static let rock = [
        "..KKKK..", ".KSSSSK.", "KSLLSSSK", "KSSSSSSK",
        "KSSSSSK.", ".KKKKK..",
    ]
    static let cart = [
        ".KKKKKKK..", ".KLLLLLK..", ".KLLLLLK..", ".KLLLLLK..",
        ".KKKKKKK..", "...K..K...", "..KSK.KSK.",
    ]
    static let chest = [
        ".KKKKKKKK.", "KNNNNNNNNK", "KNNNNNNNNK", "KKKKKKKKKK",
        "KNNKYYKNNK", "KNNKYYKNNK", "KNNNNNNNNK", ".KKKKKKKK.",
    ]
    static let church = [
        "....K....", "...KKK...", "....K....", "...RRR...",
        "..RRRRR..", ".RRRRRRR.", ".KWWWWWK.", ".KWWKWWK.",
        ".KWWKWWK.", ".KKKKKKK.",
    ]
    static let basket = [
        ".KK....KK.", "K..KKKK..K", ".KNWNWNWK.", ".KWNWNWNK.",
        ".KNWNWNWK.", "..KNWNWK..", "..KKKKKK..",
    ]
    static let compass = [
        "..KKKK..", ".KWWWWK.", "KWWRRWWK", "KWWRRWWK",
        "KWWBBWWK", "KWWBBWWK", ".KWWWWK.", "..KKKK..",
    ]
    static let bow = [
        "PP.PP", "PPPPP", "PP.PP",
    ]
    static let windChevrons = [
        "W..W..", ".W..W.", "..W..W", ".W..W.", "W..W..",
    ]

    // MARK: - Símbolos de alvo (lasershot)

    static let plus = [
        "...WW...", "...WW...", "...WW...", "WWWWWWWW",
        "WWWWWWWW", "...WW...", "...WW...", "...WW...",
    ]
    static let cross = [
        "WW....WW", ".WW..WW.", "..WWWW..", "...WW...",
        "..WWWW..", ".WW..WW.", "WW....WW",
    ]
}

// MARK: - Faixas chapadas (paleta indexada, sem gradientes)

extension GamePaint {
    /// Preenche o retângulo com faixas horizontais chapadas — o "gradiente"
    /// dos consoles de 16 bits.
    static func bands(_ ctx: inout GraphicsContext, rect: CGRect, colors: [Color]) {
        let bandH = rect.height / CGFloat(colors.count)
        for (i, color) in colors.enumerated() {
            ctx.fill(Path(CGRect(x: rect.minX, y: rect.minY + CGFloat(i) * bandH,
                                 width: rect.width, height: bandH + 0.5)),
                     with: .color(color))
        }
    }
}
