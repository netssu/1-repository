# Roblox Game Template

Base neutra para projetos Roblox, organizada com Rojo. Ela oferece persistência de dados de jogador, preparação de personagens, sons de personagem, animações de interface e prompts de proximidade. Não inclui mecânicas ou conteúdo de um jogo específico.

## Início rápido

1. Instale as ferramentas declaradas em `rokit.toml`.
2. Abra o place correspondente no Roblox Studio.
3. Execute um dos projetos Rojo e conecte o plugin ao servidor local:

```powershell
rojo serve lobby.project.json
rojo serve partida.project.json
```

Para gerar um place a partir do código:

```powershell
New-Item -ItemType Directory -Force build
rojo build lobby.project.json --output build/Lobby.rbxlx
rojo build partida.project.json --output build/Partida.rbxlx
```

Cada projeto aponta para sua própria árvore em `places/` e preserva instâncias que ainda existam apenas no place.

## Documentação

- [Arquitetura](docs/architecture.md)
- [Desenvolvimento](docs/development.md)
- [Pacotes](docs/packages.md)
- [Guia para IA](docs/ai/guide.md)
