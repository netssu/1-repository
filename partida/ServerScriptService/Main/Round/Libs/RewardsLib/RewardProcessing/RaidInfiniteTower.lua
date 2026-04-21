local ServerScriptService = game:GetService("ServerScriptService")
local Variables = require(ServerScriptService.Main.Round.Variables)

local chances = {
	[0] = 0,
	[50] = 0.5,
	[100] = 1,
	[150] = 2,
	[200] = 4,
	[250] = 6,
	[300] = 10,
	[350] = 20,
	[400] = 100,
	[450] = 100,
}	

local function getClosestChance(value)
	local closestKey = nil
	for key in pairs(chances) do
		if key <= value and (closestKey == nil or key > closestKey) then
			closestKey = key
		end
	end
	return chances[closestKey]
end

return function(player, amount)
	local unitName = amount['unit']

	--Variables.CurrentRound -- round
	local chance = getClosestChance(Variables.CurrentRound)


	local roll = math.random() * 100 
	local luckBoost = 1

	if player.ActiveBoosts:FindFirstChild('RaidLuck3x') then
		luckBoost = 3
	elseif player.ActiveBoosts:FindFirstChild('RaidLuck2x') then
		luckBoost = 2
	end

	if player.OwnGamePasses['x2 Raid Luck'].Value then
		luckBoost += 1
	end

	luckBoost += Variables.raidLuckIncrease/100

	if roll < (chance * luckBoost) or game.PlaceId == 77187363960578 then -- or game.PlaceId == 77187363960578 or forceUnit then
		_G.createTower(player.OwnedTowers, unitName)
	else
		Variables.ActStats.Rewards['Tower'] = nil
	end
end