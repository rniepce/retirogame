import SwiftUI

struct TitleView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var progress: GameProgress

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(hex: 0x2C5A3C), location: 0),
                    .init(color: Theme.serra, location: 0.55),
                    .init(color: Theme.serraDark, location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                TitleArt()
                    .frame(maxWidth: 320)
                    .padding(.bottom, 6)

                Text("AVENTURA NO CONDOMÍNIO")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .kerning(2.2)
                    .foregroundStyle(Theme.grama)

                (Text("Retiro\n") + Text("Quest").foregroundColor(Theme.ouro))
                    .font(.system(size: 54, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.creme)
                    .multilineTextAlignment(.center)
                    .lineSpacing(-8)

                Text("Explore as ruas da serra, visite as casas e o clube — e vença os desafios de cada canto.")
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(Theme.creme.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .padding(.bottom, 22)

                Button(progress.avatarReady ? "Continuar" : "Jogar") {
                    app.route = progress.avatarReady ? .map : .avatarCreator
                }
                .buttonStyle(GameButtonStyle())

                if progress.avatarReady {
                    Button("Editar avatar") { app.route = .avatarCreator }
                        .buttonStyle(GhostButtonStyle())
                }
            }
            .padding(.horizontal, 30)
        }
    }
}

/// Vinheta do condomínio: serra, casinhas de terracota, piscina e o alvo.
private struct TitleArt: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 320
            ctx.scaleBy(x: s, y: s)

            let frame = Path(roundedRect: CGRect(x: 10, y: 10, width: 300, height: 170), cornerRadius: 18)
            ctx.fill(frame, with: .linearGradient(
                Gradient(colors: [Color(hex: 0x9AD0E8), Color(hex: 0xD8ECDC)]),
                startPoint: CGPoint(x: 0, y: 10), endPoint: CGPoint(x: 0, y: 180)))
            ctx.clip(to: frame)

            // morros
            ctx.fill(Path { p in
                p.move(to: CGPoint(x: 10, y: 120))
                p.addQuadCurve(to: CGPoint(x: 110, y: 108), control: CGPoint(x: 60, y: 70))
                p.addQuadCurve(to: CGPoint(x: 210, y: 100), control: CGPoint(x: 160, y: 108))
                p.addQuadCurve(to: CGPoint(x: 310, y: 112), control: CGPoint(x: 260, y: 100))
                p.addLine(to: CGPoint(x: 310, y: 180)); p.addLine(to: CGPoint(x: 10, y: 180))
                p.closeSubpath()
            }, with: .color(Color(hex: 0x2C5A3C)))
            ctx.fill(Path { p in
                p.move(to: CGPoint(x: 10, y: 138))
                p.addQuadCurve(to: CGPoint(x: 160, y: 132), control: CGPoint(x: 80, y: 108))
                p.addQuadCurve(to: CGPoint(x: 310, y: 130), control: CGPoint(x: 235, y: 132))
                p.addLine(to: CGPoint(x: 310, y: 180)); p.addLine(to: CGPoint(x: 10, y: 180))
                p.closeSubpath()
            }, with: .color(Theme.grama))
            ctx.fill(Path { p in
                p.move(to: CGPoint(x: 40, y: 96))
                p.addQuadCurve(to: CGPoint(x: 84, y: 92), control: CGPoint(x: 58, y: 60))
                p.closeSubpath()
            }, with: .color(Theme.serra))

            // casinhas
            let houses: [(CGFloat, CGFloat, CGFloat, CGFloat, Color)] = [
                (120, 118, 34, 24, Theme.terra),
                (185, 122, 30, 21, Color(hex: 0xD96E3B)),
                (243, 118, 34, 25, Theme.terraDark),
            ]
            for (hx, hy, hw, hh, roof) in houses {
                ctx.fill(Path(roundedRect: CGRect(x: hx, y: hy, width: hw, height: hh), cornerRadius: 3),
                         with: .color(Theme.creme))
                ctx.fill(Path { p in
                    p.move(to: CGPoint(x: hx - 4, y: hy + 2))
                    p.addLine(to: CGPoint(x: hx + hw / 2, y: hy - 16))
                    p.addLine(to: CGPoint(x: hx + hw + 4, y: hy + 2))
                    p.closeSubpath()
                }, with: .color(roof))
            }

            // piscina
            ctx.fill(Path(roundedRect: CGRect(x: 52, y: 140, width: 46, height: 20), cornerRadius: 9),
                     with: .color(Theme.piscina))
            ctx.fill(Path(roundedRect: CGRect(x: 58, y: 145, width: 34, height: 3.5), cornerRadius: 1.7),
                     with: .color(Color(hex: 0x7CCBE2)))

            // alvo com flecha
            var t = ctx
            t.translateBy(x: 160, y: 158)
            for (r, cor) in [(17.0, Theme.creme), (12.5, Theme.terra), (8.0, Theme.creme), (3.6, Theme.terra)] {
                t.fill(Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)), with: .color(cor))
            }
            let wood = Color(hex: 0x6B4A2B)
            t.stroke(Path { p in
                p.move(to: CGPoint(x: 2, y: -2)); p.addLine(to: CGPoint(x: 34, y: -34))
            }, with: .color(wood), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            t.stroke(Path { p in
                p.move(to: CGPoint(x: 34, y: -34)); p.addLine(to: CGPoint(x: 31, y: -24))
                p.move(to: CGPoint(x: 34, y: -34)); p.addLine(to: CGPoint(x: 24, y: -31))
            }, with: .color(wood), style: StrokeStyle(lineWidth: 3, lineCap: .round))

            ctx.stroke(frame, with: .color(Theme.creme), lineWidth: 5)
        }
        .aspectRatio(320.0 / 190.0, contentMode: .fit)
    }
}
