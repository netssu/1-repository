# Racing Pass

## Responsabilidades

- `ReplicatedStorage/Modules/Data/RacingPassData.lua` é a fonte compartilhada de temporada, níveis, requisitos, recompensas e produtos.
- `ServerStorage/Modules/ProfileData.lua` define o contrato persistente, normaliza dados antigos e mantém a temporada do perfil alinhada à configuração.
- `ServerScriptService/RacingPassActions.server.lua` é autoritativo para XP, desbloqueios, reivindicações, inventário, moeda e recibos de produtos.
- `ReplicatedStorage/Modules/Interface/RacingPassController.lua` apenas monta a interface, abre prompts de compra e envia solicitações de reivindicação.

## Contrato de dados

O passe usa os seguintes caminhos:

- `Currency.RacePassXP`: XP acumulado dentro do nível atual.
- `Profile.RacingPass.RacingpassLevel`: nível atual, entre `MIN_LEVEL` e `MAX_LEVEL`.
- `Profile.RacingPass.RacingpassOwned`: acesso ao trilho Premium.
- `Profile.RacingPass.NormalClaim` e `PremiumClaim`: mapas de níveis já reivindicados.
- `Profile.RacingPass.ProcessedReceipts`: mapa persistente de `PurchaseId` para ação processada.

Para subir do nível atual, o servidor usa `LEVEL_REQUIREMENTS[currentLevel]`. O XP excedente é carregado para o próximo nível.

## Reivindicação

1. O cliente envia o nível e o tipo do trilho pelo `RacingPassAction`.
2. O servidor valida tipo, nível, acesso Premium, nível desbloqueado e estado de reivindicação.
3. A recompensa e o registro de reivindicação são alterados na mesma atualização do perfil.
4. O cliente recebe o resultado e atualiza os cards.

Recompensas de moeda precisam ter valor positivo. Recompensas de item precisam existir nos catálogos de inventário e só podem escrever nos caminhos de inventário explicitamente permitidos.

## Compras

O cliente abre o prompt de produto diretamente. O servidor identifica a compra por `ProductId` em `MarketplaceService.ProcessReceipt`, aplica o produto e registra o `PurchaseId` em `ProcessedReceipts` na mesma atualização persistente.

Se o Roblox reenviar o mesmo recibo, o registro existente evita aplicar o benefício novamente e o recibo pode ser confirmado com segurança. Se o perfil ainda não estiver disponível, o servidor retorna `NotProcessedYet`.

## Temporada e migração

Ao alterar `CURRENT_SEASON`, atualize também as recompensas e, se necessário, crie uma migração explícita para redefinir níveis e reivindicações da temporada anterior. A normalização atual garante os campos mínimos e limita o nível ao intervalo configurado.

## Validação mínima

- Abrir e fechar o Racing Pass repetidamente sem duplicar cards ou conexões.
- Confirmar que níveis sem recompensa usam cards menores e permanecem centralizados no scrolling.
- Reivindicar uma recompensa normal desbloqueada e rejeitar uma reivindicação repetida.
- Rejeitar Premium sem passe, nível acima do atual e tipos de trilho inválidos.
- Verificar XP de playtime, avanço de nível e carregamento de XP excedente.
- Testar cada produto com um recibo real em ambiente de teste e reenviar o mesmo `PurchaseId` para confirmar idempotência.

