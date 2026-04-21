local Prestige = {}

Prestige.PrestigeRequirements = {
	[1] = 50,
	[2] = 100,
	[3] = 150,
	[4] = 200,
	[5] = 250,
	[6] = 300,
	[7] = 350,
	[8] = 400,
	[9] = 450,
	[10] = 500
}
-- whats up :)
-- <3
-- <3
Prestige.PrestigeRewards = {
	[1] = 3,
	[2] = 6,
	[3] = 9,
	[4] = 12,
	[5] = 15,
	[6] = 18,
	[7] = 21,
	[8] = 24,
	[9] = 27,
	[10] = 30
}

Prestige.XPMultiplier = {
	[1] = 1.1,
	[2] = 1.2,
	[3] = 1.3,
	[4] = 1.4,
	[5] = 1.5,
	[6] = 1.6,
	[7] = 1.7,
	[8] = 1.8,
	[9] = 1.9,
	[10] = 2.0
}


Prestige.Badges = {
	[1] = 0,
	[2] = 0,
	[3] = 0,
	[4] = 0,
	[5] = 0,
	[6] = 0,
	[7] = 0,
	[8] = 1085788293954005,
	[9] = 0,
	[10] = 0,
}

function Prestige.GivePrestigeBadge(player : Player)
	local PrestigeValue = player.Prestige.Value
	local BadgeService = game:GetService("BadgeService")
	if PrestigeValue > 10 or PrestigeValue < 0 then return end
	BadgeService:AwardBadge(player.UserId, Prestige.Badges[PrestigeValue])
end


function Prestige.CalculatePrestige(player)
	if player and player.Parent then
		if player:FindFirstChild("DataLoaded") then
			local currentPrestige = player.Prestige.Value
			local PrestigeReq = Prestige.PrestigeRequirements[currentPrestige + 1]
			if PrestigeReq then
				if player.PlayerLevel.Value >= PrestigeReq then
					player.Prestige.Value = currentPrestige + 1
					player.PlayerLevel.Value -= PrestigeReq
					if player.PlayerLevel.Value < 1 then
						player.PlayerLevel.Value = 1
					end
					player.PlayerExp.Value = 0
					player.PrestigeTokens.Value += Prestige.PrestigeRewards[currentPrestige + 1] -- currentPrestige = 0 ???
					player.LevelRewards.Value = player:FindFirstChild("PlayerLevel").Value / 10
					Prestige.GivePrestigeBadge(player)

				end
			end
		end
	end
end


function Prestige.CanPrestige(player)
	if player and player.Parent then
		if player:FindFirstChild("DataLoaded") then
			local currentPrestige = player.Prestige.Value
			local requiredLevel = Prestige.PrestigeRequirements[currentPrestige + 1]
			if requiredLevel and player.PlayerLevel.Value >= requiredLevel then
				return true
			end
		end
	end
	return false
end


function Prestige.Reset(character, level, prestige)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ImageModule = require(ReplicatedStorage.Prestige.Main.Images)
	local Billboard = character:FindFirstChild("Head"):FindFirstChild("_overhead")
	local LevelText = Billboard:FindFirstChild("Frame"):FindFirstChild("Level_Frame"):FindFirstChild("LevelText")
	LevelText.Text = level
	local Prestige = Billboard:FindFirstChild("Frame"):FindFirstChild("Prestige")
	if Prestige.Visible == false then
		Prestige.Visible = true
	end

	local Image = Prestige:FindFirstChild("PrestigeImage")
	local ImageID = ImageModule[prestige]
	Image.Image = ImageID
end



function Prestige.CalculatePrestigeCurrency(label, value)
	label.Text = value
end

return Prestige
