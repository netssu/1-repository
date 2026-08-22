# Arquitetura de corrida da Partida

## Estado atual

A place `Race` usa uma sessão autoritativa no servidor. O mapa é carregado por `MapLoader`, interpretado por `MapRuntime` e a entrada em `FESystem.Play.Hit` é detectada por `StartRaceZone`. O pacote Zone fica em `ReplicatedFirst/Packages/Zone`, pois é uma dependência carregada cedo no cliente e no servidor.

O fluxo atual é:

```text
MapLoader
  → MapRuntime valida FESystem
  → StartRaceZone detecta o jogador
  → RaceSessionService registra o participante
  → VehicleService resolve o Livery e cria o carro
  → VehicleController/Viewmodel assume a câmera cockpit e primeira pessoa no cliente
  → grid e luzes de largada
  → TrackProgressionService valida voltas e checkpoints
```

## Responsabilidades

- `MapRuntime`: resolve o mapa carregado e suas marcações.
- `ParticipantRegistry`: mantém um registro por `UserId` durante a sessão.
- `VehicleService`: cria, posiciona, controla, ocupa e remove carros.
- `RaceStateService`: publica estado, countdown e sessão no `MatchState` e nos atributos dos participantes.
- `RaceGridService`: posiciona carros e aplica a ordem de qualifying no grid.
- `RaceRewardService`: calcula e grava recompensas idempotentes ao final da sessão.
- `RaceSessionService`: controla o estado e as transições da corrida.
- `TrackProgressionService`: valida Start, End, setores, checkpoints e corner cuts.
- `StartRaceZone`: apenas detecta a entrada na zona; não decide posições nem recompensas.
- `Modules/Interface/VehicleController`: integra animação, câmera cockpit e primeira pessoa.

## Estados

```text
WaitingForMap
  → WaitingForPlayers
  → Countdown
  → Grid
  → RaceLights
  → Racing
  → Results
  → WaitingForPlayers
```

Somente `RaceSessionService` altera `MatchState.RaceState`. O cliente recebe atributos replicados e não pode informar checkpoint, volta, posição ou recompensa.

## Compatibilidade de assets

O A-Chassis continua sendo utilizado como física do veículo. O `VehicleService` somente adapta o modelo ao ciclo de vida da sessão e mantém a estrutura `DriveSeat`, `Body`, `Wheels`, `VehicleInfo` e `A-Chassis Tune`.

Os arquivos em `ReplicatedStorage/ClientFunctions` são apenas adapters mínimos para os `require` hardcoded dos assets A-Chassis antigos. A implementação real fica em `ReplicatedStorage/Modules/Interface` e `ReplicatedStorage/Modules/VehicleConfig`.

O inventário é resolvido pelo perfil do jogador através de `DataUtility` e `InventoryAssetResolver`. TeleportData define o mapa e a sessão, mas não substitui a validação de posse do item no servidor.

## Próximas etapas

1. Conectar o HUD da corrida aos atributos de sessão e progressão.
2. Adicionar resultados visuais e recompensas idempotentes por sessão.
3. Migrar dano, pit stop e Attack Mode para serviços separados.
4. Adicionar testes de saída, respawn, troca de mapa e múltiplos jogadores.
