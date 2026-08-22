# Challenges

## Estrutura

Os desafios normais ficam em `Profile.Quests`. Os desafios Premium ficam em `Profile.RacingPass.Quests` e só avançam ou entregam recompensas quando `Profile.RacingPass.RacingpassOwned` é verdadeiro.

Cada categoria possui quatro slots:

- `Daily`: refresh de 24 horas.
- `Weekly`: refresh de 7 dias.
- `Monthly`: refresh de 30 dias.
- `VIP`: desafios Premium com refresh semanal.

Cada slot guarda `QuestId`, `QuestType`, `QuestProgress`, `QuestGoal`, `RewardCash`, `RewardXP`, recompensa opcional de inventário e `Completed`.

## Responsabilidades

- `ReplicatedStorage/Modules/Data/ChallengesData.lua` contém definições, objetivos, refresh, normalização e eventos suportados.
- `ServerStorage/Modules/ChallengesService.lua` é a API autoritativa para refresh, progresso e entrega de recompensas.
- `ServerScriptService/ChallengesActions.server.lua` inicializa o serviço e acompanha jogadores.
- `ReplicatedStorage/Modules/Interface/ChallengesController.lua` renderiza cards, timers e a animação de flip usando o `DataUtility`.

O cliente não altera progresso nem recompensa. As atualizações são publicadas pelos caminhos do perfil usando `DataUtility.server.update`.

## API para a partida

A partida deve requerer `ServerStorage.Modules.ChallengesService` e chamar:

- `record_event(player, eventName, amount, context)` para um único evento.
- `record_events(player, events)` para agrupar eventos de uma mesma ação.
- `record_race_result(player, result)` para registrar um resultado completo.

Exemplo de resultado:

```lua
challengesService.record_race_result(player, {
    Position = 1,
    Track = "Sao Paulo",
    Livery = "Default",
    FastestLap = true,
    PersonalBest = true,
    Overtakes = 3,
    AttackModeUses = 2,
})
```

Esse resultado registra corrida concluída, Top 3, pódio, vitória, volta rápida, recorde pessoal, ultrapassagens e usos de Attack Mode. O serviço limita valores, valida eventos e grava progresso e recompensas na mesma atualização do perfil.

## Recompensas

Desafios normais entregam `Currency.XP` e desafios Premium entregam `Currency.RacePassXP`. Ambos podem entregar Cash e itens de inventário. Itens são aceitos somente quando existem nos catálogos de `Suit`, `Helmets` ou `Livery`.

Quando um desafio alcança a meta, ele é marcado como concluído e a recompensa é entregue automaticamente uma única vez. O refresh reinicia progresso e estado de conclusão da categoria expirada.

