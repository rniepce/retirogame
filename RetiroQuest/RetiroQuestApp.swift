import SwiftUI

@main
struct RetiroQuestApp: App {
    @StateObject private var app = AppState()
    @StateObject private var progress = GameProgress()

    init() { PixelFont.register() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(progress)
                .preferredColorScheme(.light)
                .crt()
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var progress: GameProgress

    var body: some View {
        ZStack {
            switch app.route {
            case .title:
                TitleView()
            case .avatarCreator:
                AvatarCreatorView()
            case .map:
                MapView()
            case .minigame(let poi):
                minigame(for: poi)
            case .results(let poi, let result):
                ResultsView(poi: poi, result: result)
            }
        }
    }

    /// Despacho do registro de minigames — para adicionar um novo,
    /// crie o caso em MinigameID, a entrada no MinigameCatalog e a View aqui.
    @ViewBuilder
    private func minigame(for poi: POI) -> some View {
        let exit: () -> Void = { app.route = .map }
        let done: (MinigameResult) -> Void = { result in
            if let id = poi.minigame { progress.record(id, stars: result.stars) }
            app.route = .results(poi, result)
        }
        switch poi.minigame {
        case .archer:
            ArcherGameView(avatar: progress.avatar, onExit: exit, onFinish: done)
        case .laser:
            LaserGameView(onExit: exit, onFinish: done)
        case .freekick:
            FreeKickGameView(onExit: exit, onFinish: done)
        case .bmx:
            BMXGameView(avatar: progress.avatar, onExit: exit, onFinish: done)
        case .volley:
            VolleyGameView(onExit: exit, onFinish: done)
        case .memory:
            MemoryGameView(onExit: exit, onFinish: done)
        case .findcat:
            FindCatGameView(onExit: exit, onFinish: done)
        case .harvest:
            HarvestGameView(onExit: exit, onFinish: done)
        case .fishing:
            FishingGameView(onExit: exit, onFinish: done)
        case .soapbox:
            SoapboxGameView(avatar: progress.avatar, onExit: exit, onFinish: done)
        case .basketball:
            BasketballGameView(onExit: exit, onFinish: done)
        case .kite:
            KiteGameView(avatar: progress.avatar, onExit: exit, onFinish: done)
        case .skate:
            SkateGameView(avatar: progress.avatar, onExit: exit, onFinish: done)
        case .treasure:
            TreasureGameView(onExit: exit, onFinish: done)
        case .dodgeball:
            DodgeballGameView(avatar: progress.avatar, onExit: exit, onFinish: done)
        case nil:
            MapView() // local sem minigame não chega aqui pela interface
        }
    }
}
