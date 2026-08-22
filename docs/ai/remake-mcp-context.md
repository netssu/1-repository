# Contexto do Remake e das Places

## Objetivo do projeto

Este repositório é o remake do jogo original de Formula E. O objetivo é reconstruir os sistemas do jogo com código novo, organizado e mais seguro, preservando o resultado visual e as mecânicas importantes quando isso fizer sentido.

O jogo original continua sendo uma referência de comportamento, assets, nomes de inventário, fluxo de corrida e posicionamento. Ele não deve ser tratado como a implementação final do remake: o código novo deve respeitar a arquitetura deste repositório e evitar copiar dependências, estado global ou padrões legados sem necessidade.

## Places conhecidas

As places podem estar abertas simultaneamente no Roblox Studio e podem estar conectadas por teleporte:

| Papel | Place | PlaceId | Studio MCP |
| --- | --- | ---: | --- |
| Jogo original usado como referência | Mexico City Freeroam | `120178402747177` | `22fc69c6-a97b-41ed-aa0d-7a34762a5400` |
| Partida nova do remake | Race | `128336905370673` | `d245cb95-bf06-45d3-b424-99cda282d50b` (confirmar a cada chat) |
| Lobby novo do remake | Remake - Formula E | `107449022053400` | `a9d9b2be-d2d1-488f-8093-d81452180ec1` |

Os IDs e estados devem ser confirmados com `list_roblox_studios` e `get_studio_state` no início de cada novo chat. O nome da janela pode mudar, então não se deve assumir que o primeiro Studio listado é o Lobby ou a Partida.

## Como usar o MCP

O MCP permite inspecionar e editar diretamente o DataModel do Studio conectado. Sempre diferencie:

- `Edit`: árvore persistente da place e fonte sincronizada;
- `Server`: execução server-side durante o Play Test;
- `Client`: execução do jogador durante o Play Test.

Antes de alterar código:

1. Leia `AGENTS.md`, `docs/ai/guide.md`, `docs/architecture.md` e `docs/development.md`.
2. Confirme qual Studio corresponde ao Lobby, à Partida nova e à place antiga.
3. Use a place antiga para descobrir o comportamento esperado e os assets equivalentes.
4. Inspecione a árvore e os scripts da place nova antes de criar qualquer sistema.
5. Sincronize a alteração tanto no arquivo do repositório quanto no Studio quando o fluxo conectado exigir isso.

## Organização do remake

O código do remake é dividido por place:

- `places/src - Lobby/`: UI, inventário, seleção de mapa e teleporte para a partida;
- `places/src - Partida/`: sessão da partida, carregamento de mapa, personagens, carros e regras de corrida;
- `ReplicatedStorage/Modules/`: dados e módulos compartilhados entre servidor e cliente;
- `ServerScriptService/`: regras autoritativas e validação server-side;
- `StarterPlayer/StarterPlayerScripts/`: interface, áudio e comportamento local.

O servidor continua sendo a autoridade para perfil, inventário, moeda, mapa efetivamente carregado e carro que pode ser usado. O cliente pode solicitar ou apresentar dados, mas não deve autorizar a si mesmo.

## Integração entre Lobby e Partida

O Lobby Remake escolhe o mapa e envia o jogador para o place `128336905370673` usando `TeleportService`. A Partida nova lê `Player:GetJoinData().TeleportData` no servidor.

O fluxo atual já possui:

- `places/src - Lobby/ReplicatedStorage/Modules/Data/MapsData.lua` com a lista de mapas do Lobby;
- `places/src - Lobby/ServerScriptService/MatchTeleportActions.server.lua` para validar a solicitação e fazer o teleporte;
- `places/src - Partida/ReplicatedStorage/Modules/Data/MatchTeleportData.lua` para normalizar os dados recebidos;
- `places/src - Partida/ServerScriptService/MatchSession.server.lua` para publicar `ReplicatedStorage.MatchState` e atributos do jogador.

O payload deve permanecer versionado e pequeno. O mapa deve vir como um identificador validado. Roupa, capacete e carro equipado devem ser resolvidos a partir do perfil autoritativo da Partida sempre que possível, pois as duas places podem compartilhar a mesma estrutura de dados. Se uma seleção temporária precisar ser enviada pelo teleporte, o destino deve validar novamente o item, a posse e a compatibilidade antes de usar.

## Estado descoberto dos mapas

Os mapas da Partida nova estão em `ReplicatedStorage.Assets.Maps`. O nome apresentado ao jogador não é sempre igual ao nome da pasta interna:

| Nome do payload | Caminho do asset na Partida |
| --- | --- |
| `Tempelhof` | `Assets.Maps.Tempelhof` |
| `São Paulo` | `Assets.Maps.SãoPaulo` |
| `Mexico City` | `Assets.Maps.Mexico` |
| `Miami` | `Assets.Maps.Miami.USA_HardRockStadium` |
| `Brainrot` | `Assets.Maps.Brainrot` |
| `Intergalatic` | `Assets.Maps.Intergalatic` |
| `Shanghai` | `Assets.Maps.Shangai` |
| `Tokyo` | `Assets.Maps.Tokyo` |
| `Madrid` | ainda sem asset correspondente confirmado |

As pastas contêm estruturas diferentes. Algumas possuem `Map`, outras possuem uma pasta com o nome completo da cidade, mas todas as estruturas destinadas ao carregamento devem ser clonadas para o `Workspace` da Partida. O carregador deve manter os nomes de runtime esperados pelo jogo antigo, como `workspace.FESystem`, quando esses objetos existirem.

Na place antiga, o mapa ativo fica em `Workspace.Map` e a lógica antiga usa `Workspace.FESystem`. O carro é resolvido pelo valor legado `Inventory.Equipped.Livery`, com fallback para `Assets.Vehicles.Default`; roupa e capacete seguem os valores equipados do inventário. Essa lógica é referência para o resultado, não código para copiar diretamente.

## Próximas etapas

1. Garantir que o carregador da Partida use o mapa validado pelo `MatchState` e tenha fallback seguro.
2. Expandir o contrato apenas se necessário para escolhas temporárias de partida.
3. Resolver a roupa, as cores, o rosto e o capacete com os dados autoritativos do jogador.
4. Resolver o carro/livery equipado e instanciá-lo no mapa carregado — concluído em `VehicleSetup.server.lua`.
5. Recriar a entrada na corrida e os sistemas da place antiga em módulos novos.
6. Testar sem TeleportData, com mapa inválido, com item inexistente e com teleporte real entre as places.

## Assets e dados compartilhados

Os assets do Lobby Remake foram colocados na Partida em `ReplicatedStorage.Assets.InventoryAssets.Items`, preservando as pastas `Livery`, `Suits` e `Helmets`, além dos modelos de veículos especiais. Os catálogos de inventário foram copiados para `places/src - Partida/ReplicatedStorage/Modules/Data/Inventory/`.

`places/src - Partida/ServerStorage/Modules/InventoryAssetResolver.lua` valida o nome equipado contra o catálogo e contra o asset disponível, aplica aliases conhecidos e usa `Default` como fallback. `CharacterSetup.server.lua` aplica roupa e capacete ao personagem. `VehicleSetup.server.lua` clona a livery equipada para `workspace.FESystem.Vehicles` e reserva uma vaga em `GridSpawns`.

A Partida usa o mesmo store/key do Lobby (`FormulaE` e `<UserId>~PlayerProfile`) e o mesmo `ProfileData`, permitindo que o equipamento salvo no Lobby seja resolvido no destino sem enviar modelos pelo TeleportData.

Um novo chat deve ler este arquivo antes de continuar e registrar qualquer alteração de contrato ou de caminho de asset aqui e em `docs/match-teleport.md`.
