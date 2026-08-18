# Guia para IA

## Antes de editar

1. Leia `AGENTS.md`, `docs/architecture.md` e `docs/development.md`.
2. Localize consumidores com `rg` antes de renomear, mover ou remover um módulo.
3. Verifique se a mudança depende de um asset que ainda vive em `place/GameTemplate.rbxlx`.
4. Não trate `src/ReplicatedFirst/Packages/` ou `src/ServerStorage/Packages/ProfileStore.lua` como código de produto.

## Decisão de localização

| Tipo de alteração | Local correto |
| --- | --- |
| Cálculo ou constante usado pelos dois lados | `ReplicatedStorage/Modules` |
| Estado persistente ou validação de requisição | `ServerScriptService` ou `ServerStorage` |
| Interface, áudio e efeitos locais | `StarterPlayerScripts` |
| Lógica vinculada ao ciclo de vida do personagem | `StarterCharacterScripts` |
| Carregamento indispensável antes do restante do cliente | `ReplicatedFirst` |

## Regras de implementação

- Preserve o servidor como autoridade para dados persistentes, moeda, inventário, dano e progressão.
- Use `DataUtility` para observar dados no cliente; não replique tabelas de perfil manualmente.
- Ao criar um remote, valide argumentos, estado e intervalo no servidor.
- Reaproveite `Modules/Utility` e `Modules/Interface/HudAnim` antes de criar outro helper.
- Use tipos Luau em APIs públicas e nomes descritivos.
- Siga os padrões de nomeação, comentários, seções e iteração definidos em `AGENTS.md`.
- Crie ou reutilize `Modules/Utility/Dictionary.lua` quando precisar acessar ou alterar tabelas por caminho.
- Declare constantes para tempos, limites e identificadores repetidos.
- Não acrescente comentários ao código sem pedido explícito.

## Ao mover arquivos

Atualize `default.project.json` se o destino no DataModel mudar e pesquise todos os `require`, `WaitForChild`, referências a `script` e caminhos de instância. Depois, gere o sourcemap e teste no Studio.

## Definição de pronto

Uma mudança está pronta quando a árvore Rojo é válida, não quebra a separação cliente-servidor, não altera pacotes gerados manualmente e sua documentação acompanha uma mudança estrutural.
