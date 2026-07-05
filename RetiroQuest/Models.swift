import SwiftUI

// MARK: - Avatar

enum Palette {
    static let skins   = ["F5D0A9", "E3B181", "C68863", "9C6644", "6E4326"]
    static let hairs   = ["1C1712", "3B2A1E", "7A4A21", "C98A3D", "D9C08A", "B03A2E"]
    static let clothes = ["C8552F", "3FA9C9", "5B7A54", "8E5BA6", "F2B23E", "2E4057"]
}

struct AvatarConfig: Codable, Equatable {
    enum Gender: String, Codable, CaseIterable, Identifiable {
        case masc, fem
        var id: String { rawValue }
        var label: String { self == .masc ? "Menino" : "Menina" }
    }
    enum HairSize: String, Codable, CaseIterable, Identifiable {
        case curto, medio, longo
        var id: String { rawValue }
        var label: String {
            switch self {
            case .curto: return "Curto"
            case .medio: return "Médio"
            case .longo: return "Longo"
            }
        }
    }

    var gender: Gender = .fem
    var skin: String = "C68863"
    var hairColor: String = "3B2A1E"
    var hairSize: HairSize = .medio
    var clothes: String = "C8552F"

    var skinColor: Color { Color(hexString: skin) }
    var hairSwiftColor: Color { Color(hexString: hairColor) }
    var clothesColor: Color { Color(hexString: clothes) }
    var skinUIColor: UIColor { UIColor(hexString: skin) }
    var hairUIColor: UIColor { UIColor(hexString: hairColor) }
    var clothesUIColor: UIColor { UIColor(hexString: clothes) }

    static func random() -> AvatarConfig {
        AvatarConfig(gender: Gender.allCases.randomElement()!,
                     skin: Palette.skins.randomElement()!,
                     hairColor: Palette.hairs.randomElement()!,
                     hairSize: HairSize.allCases.randomElement()!,
                     clothes: Palette.clothes.randomElement()!)
    }
}

// MARK: - Minigames (registro extensível)

enum MinigameID: String, Codable, CaseIterable {
    case archer = "arqueiro"
    case laser = "laser"
    case freekick = "falta"
    case bmx = "bmx"
    case volley = "volei"
    case memory = "memoria"
    case findcat = "gato"
    case harvest = "colheita"
    case fishing = "pesca"
    case soapbox = "rolima"
    case basketball = "basquete"
    case kite = "pipa"
    case skate = "skate"
    case treasure = "tesouro"
    case dodgeball = "queimada"
    case swim = "natacao"
}

struct MinigameInfo {
    let id: MinigameID
    let title: String
    let icon: String
    let description: String
}

enum MinigameCatalog {
    static let all: [MinigameID: MinigameInfo] = [
        .archer: .init(id: .archer, title: "Tiro com Arco", icon: "🏹",
                       description: "Puxe a corda, mire no alvo e solte. 5 flechas — quanto mais perto do centro, mais pontos."),
        .laser: .init(id: .laser, title: "Lasershot", icon: "👾",
                      description: "Alvos acendem cada vez mais rápido. Toque nos verdes — e nunca nos vermelhos!"),
        .freekick: .init(id: .freekick, title: "Gol de Falta", icon: "⚽",
                         description: "Deslize o dedo para chutar. Curve o traço para a bola contornar a barreira!"),
        .bmx: .init(id: .bmx, title: "BMX da Serra", icon: "🚴",
                    description: "Segure para acelerar e, no ar, segure para dar backflip. Chegue inteiro na linha final!"),
        .volley: .init(id: .volley, title: "Vôlei", icon: "🏐",
                       description: "Toque na hora exata em que a bola chega no anel. 8 bolas — ritmo é tudo."),
        .memory: .init(id: .memory, title: "Memória dos Vitrais", icon: "🪟",
                       description: "Encontre os pares dos vitrais da capela no menor número de jogadas."),
        .findcat: .init(id: .findcat, title: "Ache o Gato", icon: "🐱",
                        description: "Cinco gatos se esconderam no quintal. Ache todos antes do tempo acabar!"),
        .harvest: .init(id: .harvest, title: "Colheita", icon: "🍊",
                        description: "Colha as laranjas maduras antes que estraguem — e deixe as verdes no pé."),
        .fishing: .init(id: .fishing, title: "Pescaria", icon: "🎣",
                        description: "Espere a boia afundar de verdade e fisgue na hora. Dizem que tem peixe lendário…"),
        .soapbox: .init(id: .soapbox, title: "Rolimã", icon: "🛞",
                        description: "Desça a ladeira desviando de tudo. Incline o iPhone ou arraste o dedo."),
        .basketball: .init(id: .basketball, title: "Basquete", icon: "🏀",
                           description: "Arraste para cima para arremessar. Força certa + mira = só rede. 5 bolas."),
        .kite: .init(id: .kite, title: "Pipa no Mirante", icon: "🪁",
                     description: "Guie a pipa com o dedo, aguente as rajadas e colete as estrelas do céu."),
        .skate: .init(id: .skate, title: "Skate", icon: "🛹",
                      description: "Embale tocando no fundo da rampa e faça manobras no ar, tocando antes de cair."),
        .treasure: .init(id: .treasure, title: "Caça ao Tesouro", icon: "🗺️",
                         description: "O tesouro está enterrado no condomínio. Cave e siga o quente-e-frio!"),
        .dodgeball: .init(id: .dodgeball, title: "Queimada", icon: "🥎",
                          description: "Arraste para correr e desvie das bolas até o apito final!"),
        .swim: .init(id: .swim, title: "Natação", icon: "🏊",
                     description: "Toque alternando os lados para nadar. Vire na parede na hora certa e vença a prova!"),
    ]
    static func info(_ id: MinigameID) -> MinigameInfo { all[id]! }
}

struct MinigameResult: Equatable {
    let points: Int
    let stars: Int
    let phrase: String
}

// MARK: - Mapa (coordenadas de mundo do SpriteKit, origem embaixo à esquerda)

struct POI: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String
    let position: CGPoint
    let minigame: MinigameID?
    let blurb: String

    static func == (lhs: POI, rhs: POI) -> Bool { lhs.id == rhs.id }
}

enum World {
    static let size = CGSize(width: 800, height: 1060)
    static let playerStart = CGPoint(x: 400, y: 630)

    static let pois: [POI] = [
        POI(id: "clube", name: "Clube", icon: "🏹",
            position: CGPoint(x: 225, y: 420), minigame: .archer,
            blurb: "O campo de tiro com arco fica ao lado da piscina."),
        POI(id: "quadra", name: "Quadra Coberta", icon: "🏐",
            position: CGPoint(x: 452, y: 192), minigame: .volley,
            blurb: "Saque e recepção na quadra coberta."),
        POI(id: "capela", name: "Capela", icon: "⛪",
            position: CGPoint(x: 330, y: 60), minigame: .memory,
            blurb: "Os vitrais guardam pares escondidos."),
        POI(id: "colina", name: "Casa da Colina", icon: "🏠",
            position: CGPoint(x: 560, y: 790), minigame: .findcat,
            blurb: "Os gatos da vizinha fugiram para este quintal."),
        POI(id: "ipe", name: "Casa do Ipê", icon: "🏡",
            position: CGPoint(x: 660, y: 420), minigame: .harvest,
            blurb: "A horta está carregada de laranjas."),
        POI(id: "bmx", name: "Pista de BMX", icon: "🚴",
            position: CGPoint(x: 240, y: 810), minigame: .bmx,
            blurb: "A trilha de terra desce a serra inteira."),
        POI(id: "campinho", name: "Campinho", icon: "⚽",
            position: CGPoint(x: 245, y: 225), minigame: .freekick,
            blurb: "Falta perigosa na entrada da área!"),
        POI(id: "arena", name: "Arena Laser", icon: "👾",
            position: CGPoint(x: 700, y: 110), minigame: .laser,
            blurb: "O salão de jogos mais moderno da serra."),
        POI(id: "lago", name: "Lago", icon: "🎣",
            position: CGPoint(x: 175, y: 580), minigame: .fishing,
            blurb: "O lago escondido no pé da serra."),
        POI(id: "ladeira", name: "Ladeira", icon: "🛞",
            position: CGPoint(x: 390, y: 940), minigame: .soapbox,
            blurb: "A descida mais famosa do condomínio."),
        POI(id: "basquete", name: "Quadra de Basquete", icon: "🏀",
            position: CGPoint(x: 325, y: 395), minigame: .basketball,
            blurb: "A cesta do clube, palco dos desafios."),
        POI(id: "mirante", name: "Mirante", icon: "🪁",
            position: CGPoint(x: 183, y: 930), minigame: .kite,
            blurb: "Lá em cima o vento nunca para."),
        POI(id: "rampa", name: "Rampa de Skate", icon: "🛹",
            position: CGPoint(x: 450, y: 357), minigame: .skate,
            blurb: "O half-pipe atrás do clube."),
        POI(id: "pracinha", name: "Pracinha", icon: "🛝",
            position: CGPoint(x: 480, y: 575), minigame: .treasure,
            blurb: "Dizem que enterraram um tesouro por aqui…"),
        POI(id: "queimada", name: "Quadra Descoberta", icon: "🥎",
            position: CGPoint(x: 538, y: 187), minigame: .dodgeball,
            blurb: "A molecada já escolheu os times."),
        POI(id: "piscina", name: "Piscina", icon: "🏊",
            position: CGPoint(x: 170, y: 470), minigame: .swim,
            blurb: "A raia do meio é sua. Valendo!"),
    ]
}

// MARK: - Progresso persistente

final class GameProgress: ObservableObject {
    @Published var avatar: AvatarConfig { didSet { save() } }
    @Published var avatarReady: Bool { didSet { save() } }
    @Published var stars: [String: Int] { didSet { save() } }

    private static let key = "rq.progress.v1"
    private struct Snapshot: Codable {
        var avatar: AvatarConfig
        var avatarReady: Bool
        var stars: [String: Int]
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: data) {
            avatar = snap.avatar
            avatarReady = snap.avatarReady
            stars = snap.stars
        } else {
            avatar = AvatarConfig()
            avatarReady = false
            stars = [:]
        }
    }

    private func save() {
        let snap = Snapshot(avatar: avatar, avatarReady: avatarReady, stars: stars)
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    var totalStars: Int { stars.values.reduce(0, +) }
    func stars(for id: MinigameID?) -> Int {
        guard let id else { return 0 }
        return stars[id.rawValue] ?? 0
    }
    func record(_ id: MinigameID, stars newStars: Int) {
        stars[id.rawValue] = max(stars[id.rawValue] ?? 0, newStars)
    }
}

// MARK: - Navegação

enum Route: Equatable {
    case title
    case avatarCreator
    case map
    case minigame(POI)
    case results(POI, MinigameResult)
}

final class AppState: ObservableObject {
    @Published var route: Route = AppState.initialRoute()

    /// A cena do mapa vive aqui (e não num @State do MapView) para que a
    /// posição do jogador sobreviva às idas e voltas de minigames.
    let mapScene = CondoMapScene(size: World.size)
    var mapHintShown = false

    private static func initialRoute() -> Route {
        #if DEBUG
        // Atalho de depuração: RQ_ROUTE=avatar|map|archer|game:<id> pula a navegação.
        switch ProcessInfo.processInfo.environment["RQ_ROUTE"] {
        case "avatar": return .avatarCreator
        case "map": return .map
        case "archer": return .minigame(World.pois[0])
        case let value? where value.hasPrefix("game:"):
            if let id = MinigameID(rawValue: String(value.dropFirst(5))),
               let poi = World.pois.first(where: { $0.minigame == id }) {
                return .minigame(poi)
            }
        default: break
        }
        #endif
        return .title
    }
}

func starsText(_ n: Int) -> String {
    String(repeating: "⭐", count: n) + String(repeating: "☆", count: max(0, 3 - n))
}
