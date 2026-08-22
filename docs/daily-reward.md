# Daily Reward

O Daily Reward do Remake usa a place principal apenas como fonte da tabela de recompensas. A interface e o fluxo foram refeitos no Remake usando a hierarquia existente em `StarterGui.MainUI.Canvas.DailyReward`.

## Recompensas

| Dia | Tipo | Recompensa | Desbloqueio |
| --- | --- | --- | --- |
| 1 | Cash | 500 | imediato |
| 2 | XP | 150 | 24 horas |
| 3 | Cash | 1.000 | 48 horas |
| 4 | RacePassXP | 250 | 72 horas |
| 5 | Helmets | Green | 96 horas |
| 6 | Cash | 2.500 | 120 horas |
| 7 | XP | 750 | 144 horas |
| 8 | Livery | Dark Blue | 168 horas |

O ciclo dura oito intervalos de 24 horas. Cada recompensa desbloqueada pode ser resgatada uma vez. Se Green ou Dark Blue já estiver no inventário, o valor de duplicata original é concedido em Cash: 750 para Green e 1.500 para Dark Blue.

## Organização

- `ReplicatedStorage.Modules.Data.DailyRewardData`: contrato, tabela de recompensas, normalização e cálculo de desbloqueio.
- `ServerStorage.Modules.DailyRewardService`: validação autoritativa, concessão e persistência do claim.
- `ServerScriptService.DailyRewardActions.server.lua`: boot do serviço e RemoteEvent `ProfileRemotes.DailyRewardAction`.
- `ReplicatedStorage.Modules.Interface.DailyRewardController`: usa a UI persistida como base, instancia os oito cards a partir do template antigo `Rewards.Reward`, controla a contagem regressiva e processa a interação.
- `ServerStorage.Modules.ProfileData`: estado persistente em `Profile.DailyReward` e migração para a versão 5.

## Estado persistente

```lua
Profile.DailyReward = {
    CycleStart = number,
    Claimed = {
        ["1"] = true,
    },
}
```

O cliente solicita apenas o índice da recompensa. O servidor recalcula o estado usando `os.time()`, verifica o desbloqueio, impede duplicidade e só então atualiza Currency ou Inventory junto com `Claimed`.
