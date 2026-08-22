# Zonas da Partida

## Start Race

O controlador `places/src - Partida/ServerScriptService/StartRaceZone.server.lua` cria uma zona usando `workspace.FESystem.Play.Hit` no mapa carregado.

O módulo Zone foi copiado para `places/src - Partida/ReplicatedStorage/Modules/Zone`, como módulo compartilhado entre servidor e cliente. A zona é recriada quando `MatchState.LoadedMap` muda e só fica pronta depois de `MapLoadStatus = "Loaded"`.

Durante esta etapa, a zona apenas publica estado:

- `Player.InStartRaceZone`: indica se o jogador está dentro da área;
- `MatchState.StartRaceZoneReady`: indica que a zona foi configurada;
- `MatchState.StartRaceZoneMap`: mapa ao qual a zona pertence.

A entrada ainda não inicia corrida nem solicita carro. Essa integração será feita quando o sistema de carro e o fluxo de corrida forem portados.

## Spectate

A área `workspace.FESystem.Spectate.Hit` foi identificada e será configurada em uma etapa posterior, junto com o fluxo de espectador.

