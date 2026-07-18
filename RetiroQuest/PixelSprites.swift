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
    static let bee = [
        "..K..K..", "...KK...", ".KYKYKW.", "KYKYKYWW",
        ".KYKYKW.", "...KK...",
    ]
    static let coin = [
        "..KKKK..", ".KYYYYK.", "KYWYYYYK", "KYWYYYYK",
        "KYYYYYYK", "KYYYYYYK", ".KYYYYK.", "..KKKK..",
    ]
    static let bird = [
        "KK...KK.", "..K.K...", ".KWBWK..", "KBBBBBK.",
        ".KKKKK..",
    ]
    static let heart = [
        ".KK.KK..", "KRRKRRK.", "KRRRRRK.", ".KRRRK..",
        "..KRK...", "...K....",
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

    /// Vinheta de tubo de CRT: moldura escura em degraus nas bordas.
    static func vignette(_ ctx: inout GraphicsContext, size: CGSize) {
        for (inset, alpha) in [(1.5, 0.14), (5.0, 0.07), (9.0, 0.035)] {
            ctx.stroke(Path(CGRect(x: inset, y: inset,
                                   width: size.width - inset * 2,
                                   height: size.height - inset * 2)),
                       with: .color(.black.opacity(alpha)), lineWidth: 3.5)
        }
    }

    /// Partículas de pixel flutuando (pólen, poeira, bolhas) — determinísticas.
    static func motes(_ ctx: inout GraphicsContext, size: CGSize, now: Double,
                      count: Int = 12, color: Color, rise: Bool = false) {
        let w = Double(size.width), h = Double(size.height)
        for i in 0..<count {
            let seed = Double(i) * 127.31 + 17
            var x = (seed * 3.7).truncatingRemainder(dividingBy: w) + sin(now * 0.6 + seed) * 14
            var y = (seed * 7.9).truncatingRemainder(dividingBy: h)
                + (rise ? -1 : 1) * now * (8 + seed.truncatingRemainder(dividingBy: 7))
            y = y.truncatingRemainder(dividingBy: h)
            if y < 0 { y += h }
            if x < 0 { x += w }
            let s = 1.5 + seed.truncatingRemainder(dividingBy: 2)
            ctx.fill(Path(CGRect(x: x, y: y, width: s, height: s)),
                     with: .color(color))
        }
    }

    /// Arquibancada com torcida de pixels fazendo "ola".
    static func crowd(_ ctx: inout GraphicsContext, rect: CGRect, now: Double) {
        ctx.fill(Path(rect), with: .color(Color(hex: 0x3A3F52)))
        let shirts: [Color] = [Color(hex: 0xC8552F), Color(hex: 0x3FA9C9), Color(hex: 0xF2B23E),
                               Color(hex: 0x8E5BA6), Color(hex: 0xFFF8EA), Color(hex: 0x5B7A54)]
        let cols = max(1, Int(rect.width / 13))
        let rows = max(1, Int(rect.height / 13))
        for r in 0..<rows {
            for c in 0..<cols {
                let wave = sin(now * 2.4 + Double(c) * 0.55 + Double(r) * 0.8) * 2.5
                let x = rect.minX + 7 + Double(c) * 13
                let y = rect.minY + 8 + Double(r) * 13 + wave
                ctx.fill(Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)),
                         with: .color(shirts[(c * 7 + r * 3) % shirts.count]))
            }
        }
    }

    /// Reflexos de luz tremulando na água.
    static func shimmer(_ ctx: inout GraphicsContext, rect: CGRect, now: Double, count: Int = 10) {
        for i in 0..<count {
            let seed = Double(i) * 91.7 + 5
            let x = Double(rect.minX) + (seed * 5.3).truncatingRemainder(dividingBy: Double(rect.width))
            let y = Double(rect.minY) + (seed * 9.1).truncatingRemainder(dividingBy: Double(rect.height))
            let len = 10 + seed.truncatingRemainder(dividingBy: 16)
            let alpha = max(0, 0.09 + 0.09 * sin(now * 1.8 + seed))
            ctx.fill(Path(roundedRect: CGRect(x: x + sin(now + seed) * 6, y: y,
                                              width: len, height: 2.5),
                          cornerRadius: 1.2),
                     with: .color(.white.opacity(alpha)))
        }
    }
}
