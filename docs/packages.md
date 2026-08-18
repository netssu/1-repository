# Pacotes

## Estrutura

Pacotes ficam dentro da pasta `Packages` do serviço Roblox em que precisam existir no runtime:

| Origem | Destino Roblox | Uso atual |
| --- | --- | --- |
| `src/ReplicatedFirst/Packages/` | `ReplicatedFirst.Packages` | prompts de proximidade no cliente |
| `src/ServerStorage/Packages/ProfileStore.lua` | `ServerStorage.Packages.ProfileStore` | sessões de dados no servidor |

Os arquivos do ExpressivePrompts ficam diretamente em `ReplicatedFirst.Packages`, com `Main.lua` como ponto de entrada. As dependências internas permanecem na pasta filha `Dependencies/`.

Não altere arquivos de pacote manualmente. Atualize uma dependência substituindo o pacote inteiro e valide a árvore Rojo em seguida.

## Adicionar um pacote

1. Escolha o serviço em que o pacote precisa existir no runtime.
2. Coloque-o dentro da pasta `Packages` daquele serviço em `src/`.
3. Gere o sourcemap com `rojo sourcemap default.project.json --output artifacts/sourcemap.json`.
4. Requeira-o pelo ponto de entrada em `Packages`, sem acessar pastas internas ou `_Index`.
