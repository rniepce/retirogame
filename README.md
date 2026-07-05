# Retiro Quest 🏹

Jogo de iPhone em Swift (SwiftUI + SpriteKit): explore um condomínio de serra
inspirado no Retiro das Pedras, crie seu avatar e vença minigames em cada canto.

## Como rodar

1. Abra `RetiroQuest.xcodeproj` no Xcode.
2. Para rodar **no seu iPhone**: selecione o target *RetiroQuest* → aba
   *Signing & Capabilities* → escolha seu *Team* (Apple ID pessoal funciona).
3. Escolha o destino (seu iPhone ou um simulador) e aperte **⌘R**.

Se mudar a estrutura de arquivos, regenere o projeto com
[XcodeGen](https://github.com/yonaskolb/XcodeGen): `xcodegen generate`.

## Estrutura

| Arquivo | Papel |
|---|---|
| `RetiroQuestApp.swift` | Entrada do app, roteamento entre telas e despacho de minigames |
| `Models.swift` | Avatar, progresso persistente (UserDefaults), POIs do mapa, registro de minigames |
| `Theme.swift` | Paleta (extraída da vista de satélite) e componentes de UI |
| `AvatarView.swift` | Avatar procedural (Canvas) usado no criador |
| `AvatarCreatorView.swift` | Tela de personalização (estilo, pele, cabelo, roupa) |
| `MapView.swift` + `CondoMapScene.swift` | Mapa do condomínio em SpriteKit: serra, ruas, casas, clube; avatar caminha até os pinos |
| `ArcherGameView.swift` | Minigame do arqueiro em primeira pessoa (Canvas + CADisplayLink) |
| `ResultsView.swift` | Tela de estrelas ao fim de um minigame |

## Os 14 minigames

| Lugar no mapa | Minigame | Mecânica |
|---|---|---|
| Clube 🏹 | Tiro com Arco | arraste para trás: força + mira, com vento |
| Arena Laser 👾 | Lasershot | reflexo — toque nos alvos verdes, nunca nos vermelhos |
| Campinho ⚽ | Gol de Falta | swipe curvo: força + efeito por cima da barreira |
| Pista de BMX 🚴 | BMX da Serra | segure p/ acelerar; no ar, segure p/ backflip |
| Quadra Coberta 🏐 | Vôlei | timing — toque quando a bola chega no anel |
| Capela ⛪ | Memória dos Vitrais | pares de cartas em poucas jogadas |
| Casa da Colina 🏠 | Ache o Gato | observação — 5 gatos escondidos, erro custa tempo |
| Casa do Ipê 🏡 | Colheita | colha as maduras, ignore as verdes, antes de apodrecer |
| Lago 🎣 | Pescaria | fisgue quando a boia afundar (beliscadas enganam) |
| Ladeira 🛞 | Rolimã | pseudo-3D — incline o iPhone ou arraste p/ desviar |
| Quadra de Basquete 🏀 | Basquete | arremesso com força na medida (só rede = 10) |
| Mirante 🪁 | Pipa | guie com o dedo, aguente rajadas, colete estrelas |
| Rampa de Skate 🛹 | Skate | embale no ritmo e faça manobras no ar |
| Pracinha 🛝 | Caça ao Tesouro | quente-e-frio num mapa antigo do condomínio |
| Quadra Descoberta 🥎 | Queimada | corra e desvie das bolas — 3 vidas |
| Piscina 🏊 | Natação | toque alternando os lados; virada perfeita na parede dá impulso |

Infra comum em `GameKitCommon.swift`: `MiniEngine` (relógio CADisplayLink,
HUD, avisos, pontuação→estrelas) + `MiniGameHost` (canvas, gestos, botão sair).
Atalho de teste: `SIMCTL_CHILD_RQ_ROUTE=game:<id> xcrun simctl launch ...`
(ids: arqueiro, laser, falta, bmx, volei, memoria, gato, colheita, pesca,
rolima, basquete, pipa, skate, tesouro, queimada).

## Como adicionar um minigame

1. Adicione um caso em `MinigameID` e a entrada em `MinigameCatalog.all`.
2. Aponte um `POI` em `World.pois` para o novo id (os locais "Em breve" já existem).
3. Crie a View do jogo e registre-a no `switch` de `RootView.minigame(for:)`.
   Ao terminar, chame `onFinish(MinigameResult(...))` — as estrelas são salvas
   e somadas no HUD automaticamente.
