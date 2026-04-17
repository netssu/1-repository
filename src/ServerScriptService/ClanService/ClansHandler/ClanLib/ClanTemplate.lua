export type ClanData = {
	Name: StringValue,
	Description: StringValue,
	Emblem: StringValue,
	Stats: {
		Kills: NumberValue,
		Vault: NumberValue,
		XP: NumberValue
	},
	Quests: {any},
	Members: {any},
	QuestIndex: NumberValue
}

local function calendarMonthsSinceEpoch()
	local now = os.date("*t", tick())
	return (now.year - 1970) * 12 + (now.month - 1)
end

return {
	Name = 'N/A',
	Description = 'None',
	Emblem = 'rbxassetid://000000',
	Stats = {
		Kills = 0,
		Vault = 0,
		XP = 0,
		StaticVault = 0,
	},
	PreviousStats = { -- offset that is calculated on a monthly basis(allows for monthly leaderboard rewards basically)
		Kills = 0,
		Vault = 0,
		XP = 0,
		StaticVault = 0
	},
	LastClanNumber = calendarMonthsSinceEpoch(),
	
	Quests = {
		
	},
	QuestIndex = 0,
	QuestLogs = {
		
	},
	
	Members = {
		--[[
		Example:
	
		['7707'] = {
			Rank = 'Emperor',
			Contributions = {
				Kills = 0,
				Vault = 0,
				XP = 0,
			}
			Username = 'x_x6n'
			DisplayName = 'Ace'
		}
		--]]
	},
	Upgrades = {
		UpgradeSlotLevel = 0,
	},
	ActiveAura = 'None',
	AurasOwned = {

	},
	PendingRewards = {

	},
	ActiveColor = 'Default',
	ClanColors = {
		'Default'
	},

	ChatIndex = 0,
	ChatBox = {
		--[[
		Example:
		[1] = {
			Message = `<font color="#FFFFFF"><b>[System]:</b></font> X has purchased %TOWER% and rewards have been distributed!`,
			Index = 1
		}
		--]]
	},
	AuditIndex = 0,
	AuditLogs = {
		--[[
		[1] = {
			Message = "",
			Index = 0
		}
		--]]
	},
	Deleted = false,
}
