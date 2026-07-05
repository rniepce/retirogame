import SpriteKit

/// Mapa do condomínio em SpriteKit: cenário procedural inspirado na vista
/// de satélite (serra a oeste, ruas sinuosas, casas de terracota, clube).
/// Coordenadas de mundo 800×1060, origem embaixo à esquerda (padrão SpriteKit).
final class CondoMapScene: SKScene {

    var onArrive: ((POI) -> Void)?

    private var avatar = AvatarConfig()
    private var starsByGame: [String: Int] = [:]
    private var built = false
    private var player: SKNode?
    private var playerBody: SKNode?
    private var legL: SKShapeNode?
    private var legR: SKShapeNode?
    private var pinNodes: [String: SKNode] = [:]
    private var net = RoadNet()

    private let walkSpeed: CGFloat = 190 // unidades de mundo por segundo

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .aspectFit
        backgroundColor = UIColor(hex: 0x142A1C)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) não suportado") }

    func configure(avatar: AvatarConfig, stars: [String: Int], onArrive: @escaping (POI) -> Void) {
        self.avatar = avatar
        self.starsByGame = stars
        self.onArrive = onArrive
        if built {
            rebuildPlayer()
            refreshPins(stars: stars)
        }
    }

    func refreshPins(stars: [String: Int]) {
        starsByGame = stars
        for poi in World.pois {
            guard let pin = pinNodes[poi.id] else { continue }
            let earned = poi.minigame.map { (stars[$0.rawValue] ?? 0) > 0 } ?? false
            pin.childNode(withName: "star")?.isHidden = !earned
        }
    }

    override func didMove(to view: SKView) {
        guard !built else { return }
        built = true
        buildScenery()
        buildPins()
        rebuildPlayer()
    }

    // Converte coordenadas do desenho original (y para baixo) para SpriteKit (y para cima).
    private func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: World.size.height - y) }
    private func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: x, y: World.size.height - y - h, width: w, height: h)
    }

    // MARK: - Cenário

    private func buildScenery() {
        // grama base
        let grass = SKSpriteNode(color: UIColor(hex: 0x8FB569), size: World.size)
        grass.position = CGPoint(x: World.size.width / 2, y: World.size.height / 2)
        grass.zPosition = 0
        addChild(grass)

        // manchas de grama
        var rng = SeededRNG(seed: 7)
        for _ in 0..<70 {
            let node = SKShapeNode(ellipseOf: CGSize(width: (20 + rng.cg() * 45) * 2,
                                                     height: (12 + rng.cg() * 26) * 2))
            node.fillColor = UIColor(red: 110/255, green: 150/255, blue: 80/255, alpha: 0.5)
            node.strokeColor = .clear
            node.position = P(rng.cg() * 800, rng.cg() * 1060)
            node.zRotation = rng.cg() * 3
            node.zPosition = 0.5
            addChild(node)
        }

        // serra a oeste
        let serraPath = CGMutablePath()
        serraPath.move(to: P(0, 0))
        serraPath.addLine(to: P(190, 0))
        serraPath.addCurve(to: P(110, 420), control1: P(120, 180), control2: P(170, 300))
        serraPath.addCurve(to: P(90, 800), control1: P(60, 540), control2: P(150, 660))
        serraPath.addCurve(to: P(80, 1060), control1: P(50, 900), control2: P(120, 980))
        serraPath.addLine(to: P(0, 1060))
        serraPath.closeSubpath()
        let serra = SKShapeNode(path: serraPath)
        serra.fillColor = UIColor(hex: 0x1E3A28)
        serra.strokeColor = .clear
        serra.zPosition = 1
        addChild(serra)

        // pedras da serra
        for (px, py, pr) in [(40.0, 180.0, 26.0), (80, 340, 20), (30, 520, 30),
                             (70, 700, 22), (35, 880, 26), (100, 120, 16)] {
            let rock = SKShapeNode(ellipseOf: CGSize(width: pr * 2, height: pr * 1.24))
            rock.fillColor = UIColor(hex: 0x57636B)
            rock.strokeColor = .clear
            rock.position = P(px, py)
            rock.zRotation = -0.4
            rock.zPosition = 1.2
            addChild(rock)
            let shine = SKShapeNode(ellipseOf: CGSize(width: pr * 1.1, height: pr * 0.68))
            shine.fillColor = UIColor(hex: 0x6E7A82)
            shine.strokeColor = .clear
            shine.position = P(px - 4, py - 4)
            shine.zRotation = -0.4
            shine.zPosition = 1.3
            addChild(shine)
        }

        // ruas
        let roads: [[CGPoint]] = [
            [P(400, 0), P(380, 140), P(400, 280), P(430, 420), P(400, 560),
             P(370, 700), P(420, 840), P(400, 940), P(330, 1010)],
            [P(620, 0), P(600, 160), P(630, 320), P(660, 480), P(620, 640),
             P(600, 800), P(640, 940)],
            [P(400, 280), P(510, 260), P(620, 300)],
            [P(430, 420), P(540, 440), P(650, 470)],
            [P(400, 560), P(520, 600), P(620, 630)],
            [P(370, 700), P(500, 740), P(610, 790)],
            [P(400, 560), P(300, 600), P(240, 660)],
            [P(420, 840), P(440, 860), P(460, 880)],
        ]
        for pts in roads {
            let road = SKShapeNode(path: quadPath(pts))
            road.strokeColor = UIColor(hex: 0xEFE3C8)
            road.lineWidth = 30
            road.lineCap = .round
            road.lineJoin = .round
            road.zPosition = 2
            addChild(road)
        }
        // malha de caminhada: as mesmas ruas viram um grafo para o pathfinding
        for pts in roads { net.addPolyline(RoadNet.flattenQuads(pts)) }
        // faixa tracejada da rua principal
        let dashed = quadPath(roads[0]).copy(dashingWithPhase: 0, lengths: [10, 14])
        let dash = SKShapeNode(path: dashed)
        dash.strokeColor = UIColor(red: 180/255, green: 150/255, blue: 100/255, alpha: 0.35)
        dash.lineWidth = 2
        dash.zPosition = 2.1
        addChild(dash)

        buildClub()
        buildQuadra()
        buildCapela()
        buildCampinho()
        buildBMX()
        buildArena()
        buildLago()
        buildLadeira()
        buildBasquete()
        buildRampa()
        buildMirante()
        buildPracinha()
        buildHouses()
        buildTrees()
    }

    private func quadPath(_ pts: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        path.move(to: pts[0])
        var i = 1
        while i + 1 < pts.count {
            path.addQuadCurve(to: pts[i + 1], control: pts[i])
            i += 2
        }
        return path
    }

    private func buildClub() {
        // plataforma do clube
        addShape(rounded: R(140, 540, 220, 210), radius: 26, fill: UIColor(hex: 0xDCEFD2),
                 stroke: UIColor(hex: 0x5B7A54, alpha: 0.5), lineWidth: 3, z: 2.5)
        // piscina com raias
        addShape(rounded: R(160, 570, 110, 52), radius: 16, fill: UIColor(hex: 0x3FA9C9), z: 3)
        for i in 0..<3 {
            addShape(rounded: R(170, 582 + CGFloat(i) * 13, 90, 4), radius: 2,
                     fill: UIColor(hex: 0x7CCBE2), z: 3.1)
        }
        // sede
        addShape(rounded: R(285, 560, 62, 26), radius: 6, fill: UIColor(hex: 0xFFF8EA), z: 3)
        addShape(rounded: R(285, 586, 62, 7), radius: 3, fill: UIColor(hex: 0xDECFA9), z: 3)
        // quadras de tênis
        for qx: CGFloat in [165, 235] {
            addShape(rounded: R(qx, 648, 58, 34), radius: 4, fill: UIColor(hex: 0x4E8F5C), z: 3)
            let lines = SKShapeNode(rect: R(qx + 6, 652, 46, 26))
            lines.strokeColor = UIColor(hex: 0xDCEFD2)
            lines.lineWidth = 2
            lines.fillColor = .clear
            lines.zPosition = 3.1
            addChild(lines)
            addLine(from: P(qx + 29, 652), to: P(qx + 29, 678),
                    color: UIColor(hex: 0xDCEFD2), width: 2, z: 3.1)
        }
        // campo de arco e flecha com alvo
        addShape(rounded: R(200, 700, 120, 36), radius: 10, fill: UIColor(hex: 0xC9B091), z: 3)
        for (r, hex) in [(11.0, UInt32(0xFFF8EA)), (7.5, 0xC8552F), (4, 0xFFF8EA), (1.8, 0xC8552F)] {
            let ring = SKShapeNode(circleOfRadius: r)
            ring.fillColor = UIColor(hex: hex)
            ring.strokeColor = .clear
            ring.position = P(300, 718)
            ring.zPosition = 3.2
            addChild(ring)
        }
    }

    private func buildQuadra() {
        addShape(rounded: R(415, 838, 86, 52), radius: 8, fill: UIColor(hex: 0xF2F0E8), z: 3)
        for i in 1..<4 {
            addLine(from: P(415, 838 + CGFloat(i) * 13), to: P(501, 838 + CGFloat(i) * 13),
                    color: UIColor(hex: 0xC9C4B2), width: 2, z: 3.1)
        }
        addShape(rounded: R(512, 858, 52, 30), radius: 4, fill: UIColor(hex: 0x4E8F5C), z: 3)
    }

    private func buildCapela() {
        addShape(rounded: R(310, 982, 42, 32), radius: 5, fill: UIColor(hex: 0xFFF8EA), z: 3)
        let roof = SKShapeNode(path: {
            let p = CGMutablePath()
            p.move(to: P(305, 984)); p.addLine(to: P(331, 964)); p.addLine(to: P(357, 984))
            p.closeSubpath(); return p
        }())
        roof.fillColor = UIColor(hex: 0xC8552F)
        roof.strokeColor = .clear
        roof.zPosition = 3.1
        addChild(roof)
        addLine(from: P(331, 962), to: P(331, 950), color: UIColor(hex: 0x6B5B44), width: 3, z: 3.2)
        addLine(from: P(325, 956), to: P(337, 956), color: UIColor(hex: 0x6B5B44), width: 3, z: 3.2)
    }

    /// Campinho de futebol (POI "campinho").
    private func buildCampinho() {
        addShape(rounded: R(200, 805, 90, 60), radius: 8, fill: UIColor(hex: 0x5FA054), z: 3)
        let outline = SKShapeNode(rect: R(206, 811, 78, 48))
        outline.strokeColor = UIColor(hex: 0xFFF8EA, alpha: 0.85)
        outline.lineWidth = 2
        outline.fillColor = .clear
        outline.zPosition = 3.1
        addChild(outline)
        addLine(from: P(245, 811), to: P(245, 859),
                color: UIColor(hex: 0xFFF8EA, alpha: 0.85), width: 2, z: 3.1)
        let circle = SKShapeNode(circleOfRadius: 7)
        circle.strokeColor = UIColor(hex: 0xFFF8EA, alpha: 0.85)
        circle.lineWidth = 2
        circle.fillColor = .clear
        circle.position = P(245, 835)
        circle.zPosition = 3.1
        addChild(circle)
        for areaX: CGFloat in [206, 274] {
            let area = SKShapeNode(rect: R(areaX, 825, 10, 20))
            area.strokeColor = UIColor(hex: 0xFFF8EA, alpha: 0.85)
            area.lineWidth = 2
            area.fillColor = .clear
            area.zPosition = 3.1
            addChild(area)
        }
    }

    /// Pista de BMX na beira da serra (POI "bmx").
    private func buildBMX() {
        let track = SKShapeNode(ellipseIn: R(195, 218, 90, 64))
        track.strokeColor = UIColor(hex: 0xA8814F)
        track.lineWidth = 14
        track.fillColor = .clear
        track.zPosition = 3
        addChild(track)
        for (bx, by, br) in [(222.0, 250.0, 6.0), (262, 244, 5)] {
            let bump = SKShapeNode(circleOfRadius: br)
            bump.fillColor = UIColor(hex: 0x8A6238)
            bump.strokeColor = .clear
            bump.position = P(bx, by)
            bump.zPosition = 3.1
            addChild(bump)
        }
    }

    /// Arena laser (POI "arena").
    private func buildArena() {
        addShape(rounded: R(670, 928, 60, 42), radius: 8, fill: UIColor(hex: 0x2E3550), z: 3)
        addShape(rounded: R(676, 946, 48, 6), radius: 3, fill: UIColor(hex: 0x7CE0D6), z: 3.1)
        addShape(rounded: R(692, 956, 16, 14), radius: 3, fill: UIColor(hex: 0x1B2038), z: 3.1)
    }

    /// Lago no pé da serra (POI "lago").
    private func buildLago() {
        let pond = SKShapeNode(ellipseIn: R(138, 452, 76, 56))
        pond.fillColor = UIColor(hex: 0x2F7FA3)
        pond.strokeColor = UIColor(hex: 0x5B7A54, alpha: 0.6)
        pond.lineWidth = 3
        pond.zPosition = 3
        addChild(pond)
        let shine = SKShapeNode(ellipseIn: R(150, 462, 44, 28))
        shine.fillColor = UIColor(hex: 0x4FA7C9)
        shine.strokeColor = .clear
        shine.zPosition = 3.1
        addChild(shine)
        for (lx, ly) in [(155.0, 490.0), (192, 468)] {
            let pad = SKShapeNode(ellipseIn: R(lx, ly, 12, 8))
            pad.fillColor = UIColor(hex: 0x4E8F5C)
            pad.strokeColor = .clear
            pad.zPosition = 3.2
            addChild(pad)
        }
        addShape(rounded: R(206, 472, 22, 8), radius: 3, fill: UIColor(hex: 0x8A6238), z: 3.2)
    }

    /// Faixa de largada da rolimã na rua principal (POI "ladeira").
    private func buildLadeira() {
        addLine(from: P(358, 118), to: P(412, 112), color: UIColor(hex: 0xF2B23E), width: 6, z: 2.3)
        for px: CGFloat in [358, 412] {
            let post = SKShapeNode(circleOfRadius: 4)
            post.fillColor = UIColor(hex: 0x6B4A2B)
            post.strokeColor = .clear
            post.position = P(px, px == 358 ? 118 : 112)
            post.zPosition = 2.4
            addChild(post)
        }
    }

    /// Quadra de basquete no clube (POI "basquete").
    private func buildBasquete() {
        addShape(rounded: R(300, 648, 50, 34), radius: 4, fill: UIColor(hex: 0xB8794A), z: 3)
        let circle = SKShapeNode(circleOfRadius: 6)
        circle.strokeColor = UIColor(hex: 0xFFF8EA, alpha: 0.8)
        circle.lineWidth = 2
        circle.fillColor = .clear
        circle.position = P(325, 665)
        circle.zPosition = 3.1
        addChild(circle)
    }

    /// Half-pipe de skate (POI "rampa").
    private func buildRampa() {
        addShape(rounded: R(425, 690, 50, 26), radius: 6, fill: UIColor(hex: 0xB9BEC4), z: 3)
        addShape(rounded: R(425, 690, 8, 26), radius: 3, fill: UIColor(hex: 0x8E959D), z: 3.1)
        addShape(rounded: R(467, 690, 8, 26), radius: 3, fill: UIColor(hex: 0x8E959D), z: 3.1)
    }

    /// Deque do mirante na beira da serra (POI "mirante").
    private func buildMirante() {
        addShape(rounded: R(160, 118, 40, 28), radius: 4, fill: UIColor(hex: 0x8A6238), z: 3)
        for i in 1..<4 {
            addLine(from: P(160, 118 + CGFloat(i) * 7), to: P(200, 118 + CGFloat(i) * 7),
                    color: UIColor(hex: 0x6B4A2B, alpha: 0.6), width: 1.5, z: 3.1)
        }
        addLine(from: P(196, 118), to: P(196, 102), color: UIColor(hex: 0x6B4A2B), width: 3, z: 3.2)
        let flag = SKShapeNode(path: {
            let p = CGMutablePath()
            p.move(to: P(196, 102)); p.addLine(to: P(210, 106)); p.addLine(to: P(196, 110))
            p.closeSubpath(); return p
        }())
        flag.fillColor = UIColor(hex: 0xF2B23E)
        flag.strokeColor = .clear
        flag.zPosition = 3.2
        addChild(flag)
    }

    /// Pracinha com caixa de areia e balanço (POI "pracinha").
    private func buildPracinha() {
        let sand = SKShapeNode(ellipseIn: R(456, 462, 48, 40))
        sand.fillColor = UIColor(hex: 0xE4D5A8)
        sand.strokeColor = UIColor(hex: 0xC9B091)
        sand.lineWidth = 2
        sand.zPosition = 3
        addChild(sand)
        addLine(from: P(464, 470), to: P(464, 456), color: UIColor(hex: 0x6B4A2B), width: 3, z: 3.1)
        addLine(from: P(494, 470), to: P(494, 456), color: UIColor(hex: 0x6B4A2B), width: 3, z: 3.1)
        addLine(from: P(464, 456), to: P(494, 456), color: UIColor(hex: 0x6B4A2B), width: 3, z: 3.1)
        for sx: CGFloat in [472, 486] {
            addLine(from: P(sx, 456), to: P(sx, 466), color: UIColor(hex: 0x57636B), width: 2, z: 3.2)
        }
    }

    private func buildHouses() {
        let spots: [(CGFloat, CGFloat)] = [
            (300, 80), (480, 90), (540, 170), (300, 200), (330, 330), (520, 330),
            (700, 200), (720, 360), (300, 460), (530, 500), (710, 520), (460, 640),
            (720, 700), (320, 762), (520, 800), (700, 860), (480, 950), (560, 980),
            (240, 340), (250, 180), (680, 80), (240, 900),
            (560, 270), (660, 640), // casas sob os pinos "Casa da Colina" e "Casa do Ipê"
        ]
        let roofs: [UInt32] = [0xC8552F, 0xD96E3B, 0xA03E1F, 0xB85C33, 0xC97B45]
        var rng = SeededRNG(seed: 13)
        for (hx, hy) in spots {
            let w = 40 + rng.cg() * 18
            let h = 28 + rng.cg() * 10
            let rot = (rng.cg() - 0.5) * 0.25
            let house = SKNode()
            house.position = P(hx, hy)
            house.zRotation = rot
            house.zPosition = 3

            let shadow = SKShapeNode(rect: CGRect(x: -w / 2 + 3, y: -h / 2 - 4, width: w, height: h),
                                     cornerRadius: 5)
            shadow.fillColor = UIColor(hex: 0x241F17, alpha: 0.14)
            shadow.strokeColor = .clear
            house.addChild(shadow)

            let roof = SKShapeNode(rect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h),
                                   cornerRadius: 5)
            roof.fillColor = UIColor(hex: roofs[Int(rng.cg() * CGFloat(roofs.count)) % roofs.count])
            roof.strokeColor = .clear
            house.addChild(roof)

            let ridge = SKShapeNode(path: {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: -w / 2 + 3, y: 0)); p.addLine(to: CGPoint(x: w / 2 - 3, y: 0))
                return p
            }())
            ridge.strokeColor = UIColor(hex: 0xFFF8EA, alpha: 0.45)
            ridge.lineWidth = 2
            house.addChild(ridge)

            addChild(house)
        }
    }

    private func buildTrees() {
        let crowns: [UInt32] = [0x2C5A3C, 0x3C6B48, 0x24492F]
        var rng = SeededRNG(seed: 29)
        for _ in 0..<46 {
            let pos = P(130 + rng.cg() * 640, rng.cg() * 1040)
            let r = 9 + rng.cg() * 10

            let shadow = SKShapeNode(circleOfRadius: r)
            shadow.fillColor = UIColor(hex: 0x241F17, alpha: 0.15)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: pos.x + 2, y: pos.y - 3)
            shadow.zPosition = 4
            addChild(shadow)

            let crown = SKShapeNode(circleOfRadius: r)
            crown.fillColor = UIColor(hex: crowns[Int(rng.cg() * 3) % 3])
            crown.strokeColor = .clear
            crown.position = pos
            crown.zPosition = 4.1
            addChild(crown)

            let shine = SKShapeNode(circleOfRadius: r * 0.5)
            shine.fillColor = UIColor(white: 1, alpha: 0.12)
            shine.strokeColor = .clear
            shine.position = CGPoint(x: pos.x - r * 0.3, y: pos.y + r * 0.3)
            shine.zPosition = 4.2
            addChild(shine)
        }
    }

    private func addShape(rounded rect: CGRect, radius: CGFloat, fill: UIColor,
                          stroke: UIColor = .clear, lineWidth: CGFloat = 0, z: CGFloat) {
        let node = SKShapeNode(rect: rect, cornerRadius: radius)
        node.fillColor = fill
        node.strokeColor = stroke
        node.lineWidth = lineWidth
        node.zPosition = z
        addChild(node)
    }

    private func addLine(from a: CGPoint, to b: CGPoint, color: UIColor, width: CGFloat, z: CGFloat) {
        let path = CGMutablePath()
        path.move(to: a); path.addLine(to: b)
        let node = SKShapeNode(path: path)
        node.strokeColor = color
        node.lineWidth = width
        node.lineCap = .round
        node.zPosition = z
        addChild(node)
    }

    // MARK: - Pinos dos locais

    private func buildPins() {
        for poi in World.pois {
            let pin = SKNode()
            pin.position = CGPoint(x: poi.position.x, y: poi.position.y + 26)
            pin.zPosition = 10
            pin.setScale(1.25)

            let shadow = SKShapeNode(ellipseOf: CGSize(width: 24, height: 10))
            shadow.fillColor = UIColor(hex: 0x241F17, alpha: 0.25)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: 0, y: -30)
            pin.addChild(shadow)

            let body = SKShapeNode(path: {
                let p = CGMutablePath()
                p.addArc(center: .zero, radius: 17, startAngle: 0, endAngle: .pi * 2, clockwise: false)
                p.move(to: CGPoint(x: -9, y: -12))
                p.addLine(to: CGPoint(x: 0, y: -27))
                p.addLine(to: CGPoint(x: 9, y: -12))
                p.closeSubpath()
                return p
            }())
            body.fillColor = poi.minigame != nil ? UIColor(hex: 0xC8552F) : UIColor(hex: 0x8A8272)
            body.strokeColor = .clear
            pin.addChild(body)

            let inner = SKShapeNode(circleOfRadius: 12.5)
            inner.fillColor = UIColor(hex: 0xFFF8EA)
            inner.strokeColor = .clear
            pin.addChild(inner)

            let icon = SKLabelNode(text: poi.minigame != nil ? poi.icon : "🔒")
            icon.fontSize = 15
            icon.verticalAlignmentMode = .center
            icon.horizontalAlignmentMode = .center
            icon.position = CGPoint(x: 0, y: 0.5)
            pin.addChild(icon)

            let star = SKLabelNode(text: "⭐")
            star.name = "star"
            star.fontSize = 12
            star.verticalAlignmentMode = .center
            star.position = CGPoint(x: 13, y: 14)
            star.isHidden = !(poi.minigame.map { (starsByGame[$0.rawValue] ?? 0) > 0 } ?? false)
            pin.addChild(star)

            let up = SKAction.scale(to: 1.32, duration: 0.6)
            up.timingMode = .easeInEaseOut
            let down = SKAction.scale(to: 1.18, duration: 0.6)
            down.timingMode = .easeInEaseOut
            pin.run(.repeatForever(.sequence([up, down])))

            pinNodes[poi.id] = pin
            addChild(pin)
        }
    }

    // MARK: - Jogador

    private func rebuildPlayer() {
        let fallback = net.points.isEmpty ? World.playerStart : net.points[net.nearest(World.playerStart)]
        let position = player?.position ?? fallback
        player?.removeFromParent()

        let node = SKNode()
        node.position = position
        node.zPosition = 8

        let shadow = SKShapeNode(ellipseOf: CGSize(width: 22, height: 9))
        shadow.fillColor = UIColor(hex: 0x241F17, alpha: 0.28)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -16)
        node.addChild(shadow)

        let body = SKNode()
        node.addChild(body)

        // perninhas (animadas no ciclo de caminhada)
        let legColor = avatar.gender == .fem ? avatar.skinUIColor : UIColor(hex: 0x40474F)
        let left = SKShapeNode(rect: CGRect(x: -6, y: 0, width: 4.5, height: 9), cornerRadius: 2)
        left.fillColor = legColor
        left.strokeColor = .clear
        left.position = CGPoint(x: 0, y: -24)
        body.addChild(left)
        let right = SKShapeNode(rect: CGRect(x: 1.5, y: 0, width: 4.5, height: 9), cornerRadius: 2)
        right.fillColor = legColor
        right.strokeColor = .clear
        right.position = CGPoint(x: 0, y: -24)
        body.addChild(right)
        legL = left
        legR = right

        // corpo
        if avatar.gender == .fem {
            let dress = SKShapeNode(path: {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: -7, y: 4)); p.addLine(to: CGPoint(x: 7, y: 4))
                p.addLine(to: CGPoint(x: 10, y: -14)); p.addLine(to: CGPoint(x: -10, y: -14))
                p.closeSubpath(); return p
            }())
            dress.fillColor = avatar.clothesUIColor
            dress.strokeColor = .clear
            body.addChild(dress)
        } else {
            let shirt = SKShapeNode(rect: CGRect(x: -8, y: -13, width: 16, height: 18), cornerRadius: 5)
            shirt.fillColor = avatar.clothesUIColor
            shirt.strokeColor = .clear
            body.addChild(shirt)
        }

        // cabeça
        let head = SKShapeNode(circleOfRadius: 10.5)
        head.fillColor = avatar.skinUIColor
        head.strokeColor = .clear
        head.position = CGPoint(x: 0, y: 15)
        body.addChild(head)

        // cabelo: calota superior + mechas laterais conforme o tamanho
        let cap = SKShapeNode(path: {
            let p = CGMutablePath()
            p.addArc(center: CGPoint(x: 0, y: 18), radius: 10.5,
                     startAngle: .pi * 0.05, endAngle: .pi * 0.95, clockwise: false)
            p.closeSubpath()
            return p
        }())
        cap.fillColor = avatar.hairUIColor
        cap.strokeColor = .clear
        body.addChild(cap)

        if avatar.hairSize != .curto {
            let len: CGFloat = avatar.hairSize == .longo ? 22 : 12
            let yBase: CGFloat = avatar.hairSize == .longo ? -2 : 8
            for x: CGFloat in [-12, 7.5] {
                let lock = SKShapeNode(rect: CGRect(x: x, y: yBase, width: 4.5, height: len),
                                       cornerRadius: 2.2)
                lock.fillColor = avatar.hairUIColor
                lock.strokeColor = .clear
                body.addChild(lock)
            }
        }

        // olhos
        for x: CGFloat in [-3.5, 3.5] {
            let eye = SKShapeNode(circleOfRadius: 1.4)
            eye.fillColor = UIColor(hex: 0x241F17)
            eye.strokeColor = .clear
            eye.position = CGPoint(x: x, y: 14)
            body.addChild(eye)
        }

        // balanço suave constante
        let upA = SKAction.moveBy(x: 0, y: 1.5, duration: 0.5)
        upA.timingMode = .easeInEaseOut
        let downA = SKAction.moveBy(x: 0, y: -1.5, duration: 0.5)
        downA.timingMode = .easeInEaseOut
        body.run(.repeatForever(.sequence([upA, downA])))

        player = node
        playerBody = body
        addChild(node)
    }

    // MARK: - Toques e caminhada (sempre pelas ruas)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)

        if let poi = World.pois.first(where: {
            hypot(loc.x - $0.position.x, loc.y - ($0.position.y + 26)) < 46
        }) {
            walk(to: CGPoint(x: poi.position.x + 26, y: poi.position.y - 8), poi: poi)
        } else {
            walk(to: loc, poi: nil)
        }
    }

    /// Caminha pela malha de ruas até o ponto de rua mais próximo do destino.
    /// Se for um POI, dá o último passo fora da rua até a "porta" do lugar.
    private func walk(to dest: CGPoint, poi: POI?) {
        guard let player, !net.points.isEmpty else { return }
        player.removeAction(forKey: "walk")

        let startIdx = net.nearest(player.position)
        let endIdx = net.nearest(dest)
        var waypoints = net.path(from: startIdx, to: endIdx)
        if let poi {
            waypoints.append(CGPoint(x: poi.position.x + 26, y: poi.position.y - 8))
        }

        var actions: [SKAction] = []
        var cursor = player.position
        for wp in waypoints {
            let d = hypot(wp.x - cursor.x, wp.y - cursor.y)
            guard d > 2 else { continue }
            let from = cursor
            actions.append(SKAction.run { [weak self] in
                self?.playerBody?.xScale = wp.x < from.x ? -1 : 1
            })
            actions.append(SKAction.move(to: wp, duration: d / walkSpeed))
            cursor = wp
        }
        actions.append(SKAction.run { [weak self] in
            self?.stopWalkCycle()
            if let poi { self?.onArrive?(poi) }
        })
        guard actions.count > 1 else {
            if let poi { onArrive?(poi) }
            return
        }
        startWalkCycle()
        player.run(.sequence(actions), withKey: "walk")
    }

    // MARK: - Ciclo de caminhada (perninhas + passada)

    private func startWalkCycle() {
        guard let body = playerBody else { return }
        body.removeAction(forKey: "bob")
        let up = SKAction.moveBy(x: 0, y: 2.2, duration: 0.11)
        up.timingMode = .easeInEaseOut
        body.run(.repeatForever(.sequence([up, up.reversed()])), withKey: "walkBob")

        let stepUp = SKAction.moveBy(x: 0, y: 3, duration: 0.11)
        let stepDown = stepUp.reversed()
        legL?.run(.repeatForever(.sequence([stepUp, stepDown])), withKey: "step")
        legR?.run(.repeatForever(.sequence([stepDown, stepUp])), withKey: "step")
    }

    private func stopWalkCycle() {
        guard let body = playerBody else { return }
        body.removeAction(forKey: "walkBob")
        legL?.removeAction(forKey: "step")
        legR?.removeAction(forKey: "step")
        legL?.position.y = -24
        legR?.position.y = -24
        let up = SKAction.moveBy(x: 0, y: 1.5, duration: 0.5)
        up.timingMode = .easeInEaseOut
        body.run(.repeatForever(.sequence([up, up.reversed()])), withKey: "bob")
    }
}

/// Grafo das ruas: pontos amostrados das curvas + Dijkstra para achar o caminho.
struct RoadNet {
    private(set) var points: [CGPoint] = []
    private var adjacency: [[Int]] = []

    /// Amostra uma polilinha de curvas quadráticas (mesmo formato do desenho).
    static func flattenQuads(_ pts: [CGPoint]) -> [CGPoint] {
        guard !pts.isEmpty else { return [] }
        var out: [CGPoint] = [pts[0]]
        var i = 1
        while i + 1 < pts.count {
            let p0 = out.last!, c = pts[i], p1 = pts[i + 1]
            for step in 1...6 {
                let t = CGFloat(step) / 6
                let mt = 1 - t
                out.append(CGPoint(x: mt * mt * p0.x + 2 * mt * t * c.x + t * t * p1.x,
                                   y: mt * mt * p0.y + 2 * mt * t * c.y + t * t * p1.y))
            }
            i += 2
        }
        return out
    }

    mutating func addPolyline(_ pts: [CGPoint]) {
        var prev: Int?
        for p in pts {
            let idx = indexFor(p)
            if let pr = prev, pr != idx, !adjacency[pr].contains(idx) {
                adjacency[pr].append(idx)
                adjacency[idx].append(pr)
            }
            prev = idx
        }
    }

    private mutating func indexFor(_ p: CGPoint) -> Int {
        for (i, q) in points.enumerated() where hypot(q.x - p.x, q.y - p.y) < 14 { return i }
        points.append(p)
        adjacency.append([])
        return points.count - 1
    }

    func nearest(_ p: CGPoint) -> Int {
        var best = 0
        var bestDist = CGFloat.infinity
        for (i, q) in points.enumerated() {
            let d = hypot(q.x - p.x, q.y - p.y)
            if d < bestDist { bestDist = d; best = i }
        }
        return best
    }

    func path(from a: Int, to b: Int) -> [CGPoint] {
        guard a != b else { return [points[b]] }
        var dist = Array(repeating: CGFloat.infinity, count: points.count)
        var previous = Array(repeating: -1, count: points.count)
        var visited = Array(repeating: false, count: points.count)
        dist[a] = 0
        for _ in 0..<points.count {
            var u = -1
            var du = CGFloat.infinity
            for i in 0..<points.count where !visited[i] && dist[i] < du {
                u = i; du = dist[i]
            }
            if u == -1 || u == b { break }
            visited[u] = true
            for v in adjacency[u] {
                let nd = du + hypot(points[u].x - points[v].x, points[u].y - points[v].y)
                if nd < dist[v] { dist[v] = nd; previous[v] = u }
            }
        }
        guard dist[b] < .infinity else { return [points[b]] }
        var out: [CGPoint] = []
        var cur = b
        while cur != -1 {
            out.append(points[cur])
            cur = previous[cur]
        }
        return out.reversed()
    }
}

/// Gerador determinístico (SplitMix64) para o cenário ser sempre o mesmo.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Valor uniforme em [0, 1).
    mutating func cg() -> CGFloat {
        CGFloat(next() >> 11) / CGFloat(1 << 53)
    }
}
