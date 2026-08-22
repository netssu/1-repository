# Fluxo Play e teleporte para partida

O Remake usa a UI existente em `StarterGui.MainUI.Canvas.Play` e `StarterGui.MainUI.Canvas.Maps`.

## Fluxo

1. O jogador abre `Home.Play`.
2. O botão `Play.Maps.Maps` abre a aba `Maps` mantendo `Play` como raiz de navegação.
3. O jogador seleciona um mapa no `Mapcard.ScrollingFrame`.
4. `Travel.TravelBttn` envia apenas o nome do mapa para o servidor.
5. O servidor valida o mapa e usa `TeleportService:TeleportAsync` para o place `128336905370673`.

## TeleportData

O destino recebe em `Player:GetJoinData().TeleportData` e o script `places/src - Partida/ServerScriptService/MatchSession.server.lua` publica o estado em `ReplicatedStorage.MatchState`:

```lua
{
    Version = 1,
    MatchType = "FreeRoam",
    Map = "Intergalatic",
    SourcePlaceId = number,
    SourceJobId = string,
    RequestedAt = number,
    RequestedByUserId = number,
}
```

O carregador da partida lê `ReplicatedStorage.MatchState:GetAttribute("Map")` e carrega o mapa correspondente antes de iniciar a corrida. A Partida nova está conectada no Studio pelo place `128336905370673`.

## Estado inicial do carregamento

`places/src - Partida/ServerScriptService/MapLoader.server.lua` usa o `MatchState` como fonte do mapa e clona os filhos do asset correspondente em `ReplicatedStorage.Assets.Maps` para o `Workspace`. Os clones recebem o atributo interno `RemakeMapClone`, permitindo limpar um mapa anterior sem remover objetos permanentes da place.

O carregador também publica:

- `MatchState.LoadedMap`;
- `MatchState.MapLoadStatus`;
- `MatchState.MapAssetPath`.

Os assets existentes possuem nomes internos diferentes dos nomes do payload. O mapeamento fica centralizado no carregador, incluindo `Shanghai -> Assets.Maps.Shangai`, `São Paulo -> Assets.Maps.SãoPaulo` e `Miami -> Assets.Maps.Miami.USA_HardRockStadium`. Quando o asset solicitado não existe, o carregador usa `Mexico City` como mapa padrão seguro e registra um aviso no servidor.

## Equipamento do jogador

Os assets do Lobby Remake ficam em `ReplicatedStorage.Assets.InventoryAssets.Items`. Os catálogos `Helmets`, `Livery`, `Suit` e `Upgrades` ficam em `ReplicatedStorage.Modules.Data.Inventory` na fonte da Partida.

O destino abre o mesmo perfil persistente do Lobby (`FormulaE`, chave `<UserId>~PlayerProfile`) e resolve `Inventory.Equipped.Suit`, `Inventory.Equipped.Helmets` e `Inventory.Equipped.Livery` no servidor. A roupa e o capacete são aplicados ao personagem por `CharacterSetup.server.lua`; o carro é clonado por `VehicleSetup.server.lua` em `workspace.FESystem.Vehicles`, usando a primeira vaga livre de `GridSpawns`. Seleções inexistentes ou assets ausentes caem para `Default`.
