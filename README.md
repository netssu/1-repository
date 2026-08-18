# Roblox Game Template

Base neutra para projetos Roblox, organizada com Rojo. Ela oferece persistência de dados de jogador, preparação de personagens, sons de personagem, animações de interface e prompts de proximidade. Não inclui mecânicas ou conteúdo de um jogo específico.

## Início rápido

1. Instale as ferramentas declaradas em `rokit.toml`.
2. Abra `place/GameTemplate.rbxlx` no Roblox Studio.
3. Execute `rojo serve default.project.json` e conecte o plugin Rojo ao servidor local.

Para gerar um place a partir do código:

```powershell
New-Item -ItemType Directory -Force build
rojo build default.project.json --output build/GameTemplate.rbxlx
```

O place é preservado pelo Rojo para manter objetos que ainda não foram exportados para `src/`.

## Documentação

- [Arquitetura](docs/architecture.md)
- [Desenvolvimento](docs/development.md)
- [Pacotes](docs/packages.md)
- [Guia para IA](docs/ai/guide.md)
