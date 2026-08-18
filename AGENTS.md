# Roblox Game Template – instruções para agentes

Leia [`docs/ai/guide.md`](docs/ai/guide.md) antes de alterar código. A arquitetura e o fluxo de desenvolvimento estão em [`docs/architecture.md`](docs/architecture.md) e [`docs/development.md`](docs/development.md).

## Regras de código

- Para campos privados, use o prefixo `_`.
- Dê nomes descritivos a funções, variáveis e módulos.
- Substitua números mágicos por constantes nomeadas.
- Use APIs Luau e Roblox atuais; não introduza APIs depreciadas.
- Use `PascalCase` para classes e APIs do Roblox, `camelCase` para variáveis locais e propriedades de instância, `LOUD_SNAKE_CASE` para constantes e `snake_case` para funções.
- Use tipagem Luau sempre que ela acrescentar clareza, sem casts redundantes ou `any` desnecessário.
- Use apenas os comentários de seção `------------------//`; não adicione comentários explicativos ao código sem pedido.
- Organize scripts pelas seções `SERVICES`, `VARIABLES`, `FUNCTIONS`, `MAIN FUNCTIONS` e `INIT`. `CONSTANTS` e `DEPENDENCIES` podem ser incluídas entre `SERVICES` e `VARIABLES` quando necessárias.
- Scripts devem ser autocontidos. Não crie `Init()` ou `Start()` por padrão; use uma rotina de boot explícita apenas quando ela for necessária.
- Use `ModuleScript` somente para utilidades ou serviços compartilhados e mantenha-os dentro de `Modules` em `ReplicatedStorage` ou `ServerStorage`. Scripts de fluxo ficam em `StarterPlayerScripts`, `StarterCharacterScripts` ou `ServerScriptService`.
- Requeira cada módulo uma única vez, armazene-o em uma variável local e reutilize essa referência.
- Para iterar tabelas, use a iteração direta de Luau, como `for _, value in values do`; não use `pairs`, `ipairs` nem índices numéricos manuais.
- Nunca declare o serviço `Workspace`; use o global `workspace`.
- Antes de criar um utilitário compartilhado, procure em `src/ReplicatedStorage/Modules/Utility/`.
- Para leitura e escrita por caminho em tabelas, crie ou reutilize `Modules/Utility/Dictionary.lua`.
- Antes de criar comportamento de interface, verifique `src/ReplicatedStorage/Modules/Interface/HudAnim/`.
- Para dados persistentes, use `DataUtility` no cliente e mantenha escrita e sessões no servidor.
- Não altere arquivos em `src/ReplicatedFirst/Packages/` ou `src/ServerStorage/Packages/ProfileStore.lua` manualmente. Veja `docs/packages.md`.

## Limites de responsabilidade

- Código compartilhado pertence a `src/ReplicatedStorage/Modules/`.
- LocalScripts pertencem a `src/StarterPlayer/StarterPlayerScripts/` ou `src/StarterPlayer/StarterCharacterScripts/`.
- Scripts autoritativos pertencem a `src/ServerScriptService/`.
- Módulos e dados exclusivos do servidor pertencem a `src/ServerStorage/Modules/`.
- Efeitos visuais do cliente pertencem a `VisualEffectsService`, dentro da pasta `Effects`.
