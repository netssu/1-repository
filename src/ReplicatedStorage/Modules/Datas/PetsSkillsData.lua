------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS

------------------//VARIABLES
export type SkillData = {
	Type: string, -- "Passive" ou "Active"
	Name: string,
	Description: string,
	Value: number?,
	Cooldown: number?,
	Icon: string
}

local SkillsConfig: {[string]: SkillData} = {
	-- PASSIVAS
	["JumpBoost_Weak"] = { Type = "Passive", Name = "Strong Jump", Description = "Slightly increases jump power.", Value = 30, Icon = "rbxassetid://82346463581106" },
	["JumpBoost_Strong"] = { Type = "Passive", Name = "Titanic Jump", Description = "Drastically increases jump power.", Value = 80, Icon = "rbxassetid://82346463581106" },
	
	["CoinDrop_Weak"] = { Type = "Passive", Name = "Miner", Description = "Generates 100 coins every 15 seconds.", Value = 100, Cooldown = 15, Icon = "rbxassetid://82346463581106" },
	["CoinDrop_Strong"] = { Type = "Passive", Name = "Treasure", Description = "Generates 250 coins every 10 seconds.", Value = 250, Cooldown = 10, Icon = "rbxassetid://82346463581106" },
	
	["SecondChance"] = { Type = "Passive", Name = "Lifesaver", Description = "Grants an auto-jump when missing a landing. Recharges in 60s.", Cooldown = 60, Icon = "rbxassetid://82346463581106" },

	-- ATIVAS
	["Dash"] = { Type = "Active", Name = "Dash", Description = "Dashes forward while in the air.", Cooldown = 5, Value = 250, Icon = "rbxassetid://82346463581106" },
	["DoubleJump"] = { Type = "Active", Name = "Double Jump", Description = "Allows you to jump again while in the air.", Cooldown = 8, Icon = "rbxassetid://82346463581106" },
	["SuperJump"] = { Type = "Active", Name = "Super Jump", Description = "Your next jump will be 2.5x stronger.", Value = 2.5, Cooldown = 30, Icon = "rbxassetid://82346463581106" },
	["TempAutoJump"] = { Type = "Active", Name = "Frenzy", Description = "Activates Auto-Jump for free for 8 seconds.", Value = 8, Cooldown = 45, Icon = "rbxassetid://82346463581106" }
}

local DataSkills = {}

------------------//FUNCTIONS
function DataSkills.GetSkillData(skillName: string): SkillData?
	return SkillsConfig[skillName]
end

------------------//INIT
return DataSkills