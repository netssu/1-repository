# Roblox Game Template

Base neutra para projetos Roblox, organizada com Rojo. Ela oferece persistência de dados de jogador, preparação de personagens, sons de personagem, animações de interface e prompts de proximidade. Não inclui mecânicas ou conteúdo de um jogo específico.

## Início rápido

1. Instale as ferramentas declaradas em `rokit.toml`.
2. Abra o place correspondente no Roblox Studio.
3. Execute `rojo serve lobby.project.json` para o lobby ou `rojo serve race.project.json` para a corrida e conecte o plugin Rojo ao servidor local.

Para gerar um place a partir do código:

```powershell
New-Item -ItemType Directory -Force build
rojo build lobby.project.json --output build/Lobby.rbxlx
rojo build race.project.json --output build/Race.rbxlx
```

O código compartilhado continua em `src/`. Código específico fica em `src/Places/Lobby/` ou `src/Places/Race/`. Os arquivos `.project.json` montam o mesmo código compartilhado em dois DataModels diferentes. Places abertos no Studio são preservados pelo Rojo para manter objetos que ainda não foram exportados para `src/`.

## Documentação

- [Arquitetura](docs/architecture.md)
- [Desenvolvimento](docs/development.md)
- [Pacotes](docs/packages.md)
- [Guia para IA](docs/ai/guide.md)
