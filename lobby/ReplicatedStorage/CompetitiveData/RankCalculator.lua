local module = {}

function module.getRankAndDivision(elo)
	if elo < 100 then
		return "Unranked", 0
	elseif elo <= 300 then
		return "Initiate", math.ceil((elo - 100) / 100) + 1
	elseif elo <= 600 then
		return "Youngling", math.ceil((elo - 400) / 100) + 1
	elseif elo <= 900 then
		return "Padawan", math.ceil((elo - 700) / 100) + 1
	elseif elo <= 1200 then
		return "Knight", math.ceil((elo - 1000) / 100) + 1
	elseif elo <= 1500 then
		return "Master", math.ceil((elo - 1300) / 100) + 1 
	elseif elo <= 1800 then
		return "Sentinel", math.ceil((elo - 1600) / 100) + 1 
	elseif elo <= 2100 then
		return "Guardian", math.ceil((elo - 1900) / 100) + 1
	elseif elo <= 2400 then
		return "Battle Master", math.ceil((elo - 2200) / 100) + 1
	elseif elo <= 2700 then
		return 'Grand Master', 1
	end
	
	return 'Grand Master', 0
end

--[[
Initiate 
Youngling 
Padawan
Knight
Master
Sentinel
Guardian
Battle Master
Grand Master

--]]


return module
