if not workspace:GetAttribute('Lobby') then return end

local DataStoreService = game:GetService("DataStoreService")

local function calendarMonthsSinceEpoch()
	local now = os.date("*t", tick())
	return (now.year - 1970) * 12 + (now.month - 1)
end

-- LBs
local GemsLBDS = DataStoreService:GetOrderedDataStore('ClanVault' .. calendarMonthsSinceEpoch())
local KillsLBDS = DataStoreService:GetOrderedDataStore('ClanKills' .. calendarMonthsSinceEpoch())
local XPLBDS = DataStoreService:GetOrderedDataStore('ClanXP' .. calendarMonthsSinceEpoch())

local ClansDatastore = DataStoreService:GetDataStore('Clans')

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetLeaderboard = ReplicatedStorage.Remotes.Clans.GetLeaderboard

local GemsLeaderboard = {}
local KillsLeaderboard = {}
local XPLeaderboard = {}

local function returnLeaderBoard(player, LB)
	local returningData = {}
	
	if LB == 'Gems' then
		returningData = GemsLeaderboard
	elseif LB == 'Kills' then
		returningData = KillsLeaderboard
	else
		returningData = XPLeaderboard
	end
	
	return returningData
end

GetLeaderboard.OnServerInvoke = returnLeaderBoard

local smallestFirst = false
local numberToShow = 100
local minValue = 1 
local maxValue = 10e30

local function setTopGems()
	local pages = GemsLBDS:GetSortedAsync(smallestFirst, numberToShow, minValue, maxValue)

	--Get data
	local top = pages:GetCurrentPage()--Get the first page

	if #top == 0 then GemsLeaderboard = {} return end

	for _,v in ipairs(top) do--Loop through data
		task.wait(1.5)
		local clan_id = v.key--ClanName

		local value = v.value

		local image = ''
		local description = ''

		pcall(function()
			local clanInfo = ClansDatastore:GetAsync(clan_id)
			image = clanInfo['Emblem'] -- numbers
			description = clanInfo['Description']
		end)

		GemsLeaderboard[_] = {Clan = clan_id,Value = value,Image = image, Description = description}
	end
end

local function setTopKills()
	local pages = KillsLBDS:GetSortedAsync(smallestFirst, numberToShow, minValue, maxValue)

	--Get data
	local top = pages:GetCurrentPage()--Get the first page

	if #top == 0 then KillsLeaderboard = {} return end

	for _,v in ipairs(top) do--Loop through data
		task.wait(1.5)
		local clan_id = v.key--ClanName

		local value = v.value

		local image = ''
		local description = ''

		pcall(function()
			local clanInfo = ClansDatastore:GetAsync(clan_id)
			image = clanInfo['Emblem'] -- numbers
			description = clanInfo['Description']
		end)

		KillsLeaderboard[_] = {Clan = clan_id,Value = value,Image = image, Description = description}
	end
end

local function setTopXP()
	local pages = XPLBDS:GetSortedAsync(smallestFirst, numberToShow, minValue, maxValue)

	--Get data
	local top = pages:GetCurrentPage()--Get the first page

	if #top == 0 then XPLeaderboard = {} return end

	for _,v in ipairs(top) do--Loop through data
		task.wait(1.5)
		local clan_id = v.key--ClanName

		local value = v.value

		local image = ''
		local description = ''

		pcall(function()
			local clanInfo = ClansDatastore:GetAsync(clan_id)
			image = clanInfo['Emblem'] -- numbers
			description = clanInfo['Description']
		end)

		XPLeaderboard[_] = {Clan = clan_id,Value = value,Image = image, Description = description}
	end
end


local function returnLeaderboardData(LBtype)
	if LBtype == 'Kills' then
		return KillsLeaderboard
	elseif LBtype == 'XP' then
		return XPLeaderboard
	else
		return GemsLeaderboard
	end	
end

for i,v in script:GetChildren() do
	task.spawn(require, v)
end


while true do

	setTopGems()
	setTopKills()
	setTopXP()

	task.wait(300)
end