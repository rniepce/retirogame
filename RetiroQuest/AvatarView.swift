import SwiftUI

/// Avatar desenhado proceduralmente num Canvas, no espaço de projeto 130×150.
struct AvatarView: View {
    let config: AvatarConfig
    var includeBody = true

    var body: some View {
        Canvas { ctx, size in
            AvatarPainter.draw(config, in: &ctx, size: size, includeBody: includeBody)
        }
        .aspectRatio(130.0 / 150.0, contentMode: .fit)
    }
}

enum AvatarPainter {
    static func draw(_ cfg: AvatarConfig, in ctx: inout GraphicsContext, size: CGSize, includeBody: Bool) {
        let s = min(size.width / 130, size.height / 150)
        ctx.translateBy(x: (size.width - 130 * s) / 2, y: (size.height - 150 * s) / 2)
        ctx.scaleBy(x: s, y: s)

        let skin = cfg.skinColor
        let hair = cfg.hairSwiftColor
        let cloth = cfg.clothesColor

        // cabelo atrás da cabeça (comprimento)
        if cfg.hairSize == .longo {
            ctx.fill(Path { p in
                p.move(to: CGPoint(x: 28, y: 34))
                p.addQuadCurve(to: CGPoint(x: 34, y: 100), control: CGPoint(x: 26, y: 88))
                p.addLine(to: CGPoint(x: 96, y: 100))
                p.addQuadCurve(to: CGPoint(x: 102, y: 34), control: CGPoint(x: 104, y: 88))
                p.addQuadCurve(to: CGPoint(x: 65, y: 10), control: CGPoint(x: 100, y: 10))
                p.addQuadCurve(to: CGPoint(x: 28, y: 34), control: CGPoint(x: 30, y: 10))
                p.closeSubpath()
            }, with: .color(hair))
        } else if cfg.hairSize == .medio {
            ctx.fill(Path { p in
                p.move(to: CGPoint(x: 30, y: 34))
                p.addQuadCurve(to: CGPoint(x: 35, y: 72), control: CGPoint(x: 27, y: 64))
                p.addLine(to: CGPoint(x: 95, y: 72))
                p.addQuadCurve(to: CGPoint(x: 100, y: 34), control: CGPoint(x: 103, y: 64))
                p.addQuadCurve(to: CGPoint(x: 65, y: 10), control: CGPoint(x: 98, y: 10))
                p.addQuadCurve(to: CGPoint(x: 30, y: 34), control: CGPoint(x: 32, y: 10))
                p.closeSubpath()
            }, with: .color(hair))
        }

        // corpo
        if includeBody {
            if cfg.gender == .fem {
                ctx.fill(Path { p in
                    p.move(to: CGPoint(x: 45, y: 92))
                    p.addLine(to: CGPoint(x: 85, y: 92))
                    p.addLine(to: CGPoint(x: 96, y: 148))
                    p.addLine(to: CGPoint(x: 34, y: 148))
                    p.closeSubpath()
                }, with: .color(cloth))
                ctx.fill(Path(roundedRect: CGRect(x: 36, y: 92, width: 12, height: 34), cornerRadius: 6), with: .color(skin))
                ctx.fill(Path(roundedRect: CGRect(x: 82, y: 92, width: 12, height: 34), cornerRadius: 6), with: .color(skin))
            } else {
                ctx.fill(Path(roundedRect: CGRect(x: 40, y: 92, width: 50, height: 46), cornerRadius: 12), with: .color(cloth))
                ctx.fill(Path(roundedRect: CGRect(x: 46, y: 136, width: 16, height: 14), cornerRadius: 5), with: .color(Color(hex: 0x40474F)))
                ctx.fill(Path(roundedRect: CGRect(x: 68, y: 136, width: 16, height: 14), cornerRadius: 5), with: .color(Color(hex: 0x40474F)))
                ctx.fill(Path(roundedRect: CGRect(x: 33, y: 94, width: 12, height: 34), cornerRadius: 6), with: .color(skin))
                ctx.fill(Path(roundedRect: CGRect(x: 85, y: 94, width: 12, height: 34), cornerRadius: 6), with: .color(skin))
            }
        }

        // cabeça
        ctx.fill(Path(ellipseIn: CGRect(x: 31, y: 18, width: 68, height: 68)), with: .color(skin))

        // franja / topo do cabelo
        let fringe: Path
        if cfg.gender == .fem {
            fringe = Path { p in
                p.move(to: CGPoint(x: 33, y: 40))
                p.addQuadCurve(to: CGPoint(x: 65, y: 13), control: CGPoint(x: 32, y: 14))
                p.addQuadCurve(to: CGPoint(x: 97, y: 40), control: CGPoint(x: 98, y: 14))
                p.addQuadCurve(to: CGPoint(x: 82, y: 24), control: CGPoint(x: 97, y: 26))
                p.addQuadCurve(to: CGPoint(x: 80, y: 33), control: CGPoint(x: 88, y: 34))
                p.addQuadCurve(to: CGPoint(x: 44, y: 30), control: CGPoint(x: 60, y: 16))
                p.addQuadCurve(to: CGPoint(x: 33, y: 40), control: CGPoint(x: 38, y: 32))
                p.closeSubpath()
            }
        } else if cfg.hairSize == .curto {
            fringe = Path { p in
                p.move(to: CGPoint(x: 33, y: 36))
                p.addQuadCurve(to: CGPoint(x: 65, y: 13), control: CGPoint(x: 33, y: 13))
                p.addQuadCurve(to: CGPoint(x: 97, y: 36), control: CGPoint(x: 97, y: 13))
                p.addQuadCurve(to: CGPoint(x: 65, y: 22), control: CGPoint(x: 90, y: 22))
                p.addQuadCurve(to: CGPoint(x: 33, y: 36), control: CGPoint(x: 40, y: 22))
                p.closeSubpath()
            }
        } else {
            fringe = Path { p in
                p.move(to: CGPoint(x: 32, y: 38))
                p.addQuadCurve(to: CGPoint(x: 65, y: 12), control: CGPoint(x: 32, y: 12))
                p.addQuadCurve(to: CGPoint(x: 98, y: 38), control: CGPoint(x: 98, y: 12))
                p.addQuadCurve(to: CGPoint(x: 70, y: 21), control: CGPoint(x: 92, y: 20))
                p.addQuadCurve(to: CGPoint(x: 38, y: 30), control: CGPoint(x: 46, y: 20))
                p.addQuadCurve(to: CGPoint(x: 32, y: 38), control: CGPoint(x: 34, y: 33))
                p.closeSubpath()
            }
        }
        ctx.fill(fringe, with: .color(hair))

        // rosto
        ctx.fill(Path(ellipseIn: CGRect(x: 49.4, y: 52.4, width: 7.2, height: 7.2)), with: .color(Theme.tinta))
        ctx.fill(Path(ellipseIn: CGRect(x: 73.4, y: 52.4, width: 7.2, height: 7.2)), with: .color(Theme.tinta))
        ctx.stroke(Path { p in
            p.move(to: CGPoint(x: 55, y: 70))
            p.addQuadCurve(to: CGPoint(x: 75, y: 70), control: CGPoint(x: 65, y: 78))
        }, with: .color(Theme.tinta), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        ctx.fill(Path(ellipseIn: CGRect(x: 41.5, y: 59.5, width: 9, height: 9)), with: .color(Theme.terra.opacity(0.35)))
        ctx.fill(Path(ellipseIn: CGRect(x: 79.5, y: 59.5, width: 9, height: 9)), with: .color(Theme.terra.opacity(0.35)))
    }
}
