local module = {}

local function numbertotime(number)
    local Hours = math.floor(number / 60 / 60)
    local Mintus = math.floor(number / 60) %60
    local Seconds = math.floor(number % 60)

    if Mintus < 10 and Hours > 0 then
        Mintus = "0"..Mintus
    end

    if Seconds < 10 then
        Seconds = "0"..Seconds
    end

    if Hours > 0 then
        return `{Hours}:{Mintus}:{Seconds}`
    else
        return `{Mintus}:{Seconds}`
    end
end

local function getFormattedUTCTimestamp()
    local months = {
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    }

    local function getDaySuffix(day)
        if day % 10 == 1 and day ~= 11 then
            return "st"
        elseif day % 10 == 2 and day ~= 12 then
            return "nd"
        elseif day % 10 == 3 and day ~= 13 then
            return "rd"
        else
            return "th"
        end
    end

    local utcTime = os.date("!*t")  -- Get UTC time table
    local day = utcTime.day
    local suffix = getDaySuffix(day)
    local month = months[utcTime.month]
    local year = utcTime.year
    local hour = string.format("%02d", utcTime.hour)
    local min = string.format("%02d", utcTime.min)

    return string.format("%d%s %s %d %s:%s", day, suffix, month, year, hour, min)
end

local function getHighestIndex(tbl)
    local maxIndex = 0
    for k, _ in pairs(tbl) do
        local num = tonumber(k)
        if num and num > maxIndex then
            maxIndex = num
        end
    end
    return maxIndex
end

local function getTableLength(tbl)
    local count = 0
    for k, _ in pairs(tbl) do
        if tonumber(k) then
            count += 1
        end
    end
    return count
end

local function shiftLogsDown(tbl)
    for i = 2, getHighestIndex(tbl) do
        tbl[tostring(i - 1)] = tbl[tostring(i)]
    end
    tbl[tostring(getHighestIndex(tbl))] = nil
end

function module.log(profile, joined)
	if profile then
		pcall(function() -- sometimes roblox fails :|
	        local jString = joined and 'Joined: ' or 'Leaving: '
	        local timestamp = getFormattedUTCTimestamp()
	        local GetName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
	        local data = jString .. timestamp .. ' - Gems: ' .. profile.Data.Gems .. ' - Place Name: ' .. GetName.Name

	        if getTableLength(profile.Data.Logs) >= 500 then
	            shiftLogsDown(profile.Data.Logs)
	        end

	        local newIndex = tostring(getHighestIndex(profile.Data.Logs) + 1)
			profile.Data.Logs[newIndex] = data
		end)
    end

    return profile
end
return module