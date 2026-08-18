# Arquitetura

O template usa Rojo para definir a árvore do DataModel. O servidor mantém a autoridade sobre os dados persistentes e a configuração de personagens; o cliente inicializa interface, prompts e comportamentos locais.

O repositório suporta dois places com os mesmos módulos compartilhados. `lobby.project.json` monta o lobby e `race.project.json` monta a corrida. Os dois projetos reutilizam `src/ReplicatedFirst`, `src/ReplicatedStorage`, `src/ServerScriptService`, `src/ServerStorage` e `src/StarterPlayer`; código exclusivo deve ficar em `src/Places/Lobby/` ou `src/Places/Race/`.

```mermaid
flowchart LR
    RF["ReplicatedFirst\nPackages (ExpressivePrompts)"] --> CL["StarterPlayerScripts\nBootstrap local"]
    RS["ReplicatedStorage\nMódulos compartilhados"] --> CL
    SS["ServerScriptService\nServiços autoritativos"] --> RS
    ST["ServerStorage\nDados e módulos privados"] --> SS
```

## Mapeamento Rojo

| Diretório | Destino Roblox | Conteúdo |
| --- | --- | --- |
| `src/ReplicatedFirst/` | `ReplicatedFirst` | dependências necessárias antes do restante do cliente |
| `src/ReplicatedStorage/` | `ReplicatedStorage` | módulos compartilhados e remotes criados em execução |
| `src/StarterPlayer/StarterPlayerScripts/` | `StarterPlayer.StarterPlayerScripts` | LocalScripts globais do jogador |
| `src/StarterPlayer/StarterCharacterScripts/` | `StarterPlayer.StarterCharacterScripts` | LocalScripts para cada personagem |
| `src/ServerScriptService/` | `ServerScriptService` | serviços e regras autoritativas |
| `src/ServerStorage/` | `ServerStorage` | módulos e dependências privadas do servidor |

`default.project.json` preserva instâncias desconhecidas nos serviços principais. Isso permite usar Rojo sobre `place/GameTemplate.rbxlx` sem apagar assets que ainda existam apenas no place.

## Fluxos de execução

### Servidor

- `PlayerData.server.lua` abre e encerra sessões ProfileStore e conecta perfis ao `DataUtility`.
- `CharacterSetup.server.lua` cria `Workspace.Characters` e aplica o grupo de colisão dos jogadores.

### Cliente

- `Audio/CharacterSounds.client.lua` reproduz sons locais associados ao personagem.
- `Interface/Bootstrap.client.lua` inicializa as animações de interface e os prompts de proximidade.

## Dados e rede

`PlayerData.server.lua` é o único ponto que inicia sessões de perfil. `DataUtility` cria os remotes de dados no servidor e oferece leitura e observação no cliente. Código cliente nunca grava o perfil diretamente.
