local module = {}

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RaidModeStats = require(ReplicatedStorage.RaidModeStats)
local resetTimeInterval = 14400 --6 hour

function module.checkIfReset(plr)
	local oldResetTime = plr.RaidLimitData.OldReset
    local nextTickReset = plr.RaidLimitData.NextReset
    local currentUtc = os.date("!*t")

    local function utcToTick(utcTable)
        local localOffset = os.difftime(os.time(os.date("*t")), os.time(os.date("!*t")))
        return os.time(utcTable) - localOffset
    end

    local currentTick = utcToTick(currentUtc)
	--local isReset = nextTickReset.Value == '' or tonumber(currentTick) >= tonumber(nextTickReset.Value)
	local isReset = (os.time() - oldResetTime.Value) >= resetTimeInterval
	
    if isReset then
		plr.RaidLimitData.Attempts.Value = 10
		
        --local nextResetUtc = {
        --    year = currentUtc.year,
        --    month = currentUtc.month,
        --    day = currentUtc.day,
        --    hour = 0,
        --    min = 0,
        --    sec = 0
        --}
        --local currentHour = currentUtc.hour
        --local nextHour = math.ceil(currentHour / 6) * 6
        --if nextHour >= 24 then
        --    nextHour = 0
        --    -- Move to the next day
        --    local time = os.time({
        --        year = currentUtc.year,
        --        month = currentUtc.month,
        --        day = currentUtc.day
        --    }) + 86400 -- add one day
        --    local newDate = os.date("!*t", time)
        --    nextResetUtc.year = newDate.year
        --    nextResetUtc.month = newDate.month
        --    nextResetUtc.day = newDate.day
        --end
		
		--plr.RaidLimitData.OldReset.Value = tonumber(nextTickReset.Value)
		plr.RaidLimitData.OldReset.Value = os.time()
		nextTickReset.Value = os.time() + resetTimeInterval
        --nextResetUtc.hour = nextHour
        --nextTickReset.Value = tonumber(utcToTick(nextResetUtc))
    end

    return currentTick
end

function module.init(plr)
	for i,v in pairs(RaidModeStats.Worlds) do
		if not plr.RaidActData:FindFirstChild(v) then
			-- need to load a map
			local Map = script.Map:Clone()
			Map.Name = v
			
			Map.Parent = plr.RaidActData
		end
	end
end

--[[
-- Raids Data
	RaidActData = {},
	RaidLimitData = {
		Attempts = 5,
		NextReset = tick(),
	}
	
	
	--[[
	['Map'] = {
		['Act1'] = {
			Completed = false,
			
			
		}
	}
--]]


return module