# Desenvolvimento

## Ferramentas

As versões do projeto estão em `rokit.toml`:

- Rojo 7.7.0
- Lune 0.10.4

Instale o Rokit e execute `rokit install` na raiz quando as ferramentas não estiverem no `PATH`.

## Rotina local

1. Abra o place correspondente no Studio.
2. Execute `rojo serve lobby.project.json` para o Lobby ou `rojo serve partida.project.json` para a Partida.
3. Conecte o plugin Rojo e teste no Studio.

Use `rojo sourcemap lobby.project.json --output artifacts/lobby.sourcemap.json` ou `rojo sourcemap partida.project.json --output artifacts/partida.sourcemap.json` para inspecionar as árvores. Para validar builds limpas, use `rojo build lobby.project.json --output build/Lobby.rbxlx` e `rojo build partida.project.json --output build/Partida.rbxlx`.

## Organização do código

| Quando criar ou alterar | Local |
| --- | --- |
| Regra que o cliente não pode autorizar | `src/ServerScriptService/` |
| Persistência, templates e módulos não replicados | `src/ServerStorage/` |
| Módulo utilizado por servidor e cliente | `src/ReplicatedStorage/Modules/` |
| Interface, áudio ou comportamento global do jogador | `src/StarterPlayer/StarterPlayerScripts/` |
| Comportamento criado por personagem | `src/StarterPlayer/StarterCharacterScripts/` |
| Dependência de terceiro | `src/<serviço>/Packages/` |

Mantenha as categorias de runtime claras. Crie uma pasta somente quando ela representar uma responsabilidade distinta, como `Audio`, `Interface` ou `Effects`.

## Validação mínima

1. Gere o sourcemap do Rojo.
2. Confirme que todo LocalScript está em `StarterPlayerScripts` ou `StarterCharacterScripts`.
3. Confirme que mudanças de dados continuam iniciadas pelo servidor.
4. Teste no Studio quando a mudança tocar personagem, remotes, áudio, interface ou assets do place.
