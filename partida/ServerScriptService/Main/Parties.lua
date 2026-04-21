local module = {}

local Players = game:GetService('Players')
local Teams = game:GetService('Teams')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local setTeam = 'Red'

function module.generateTeams()	
	local RedTeam = 0
	local BlueTeam = 0
	
	local PlayersLeftToTeam = Players:GetChildren()
	local PlayersTeamed = {}
			
	if RedTeam < BlueTeam then -- Red less than blue
		setTeam = 'Red'
		for i,v in pairs(PlayersLeftToTeam) do
			v.Team = Teams[setTeam]
			table.remove(PlayersLeftToTeam, table.find(PlayersLeftToTeam, v)) 
			
			if BlueTeam == RedTeam then break end
		end
		
		setTeam = 'Blue'
		
	elseif BlueTeam < RedTeam then
		setTeam = 'Blue'
		for i,v in pairs(PlayersLeftToTeam) do
			v.Team = Teams[setTeam]
			
			table.remove(PlayersLeftToTeam, table.find(PlayersLeftToTeam, v)) 

			if BlueTeam == RedTeam then break end
		end
		
		setTeam = 'Red'
	end
	
	if #PlayersLeftToTeam ~= 0 then
		-- Still some players left
		for i,v: Player in pairs(PlayersLeftToTeam) do
			v.Team = Teams[setTeam]
			
			if setTeam == 'Red' then
				RedTeam += 1
				setTeam = 'Blue'
			else
				BlueTeam += 1
				setTeam = 'Red'
			end
		end
	end	
end


function module.putIntoTeam(plr)
	plr.Team = Teams[setTeam]
		
	if setTeam == 'Red' then
		setTeam = 'Blue'
	else
		setTeam = 'Red'
	end
end

function module.putBackIntoTeam(plr)
	local plrData = ReplicatedStorage.Players:FindFirstChild(plr.Name)
	
	if plrData then
		if plrData.Team.Value ~= '' then
			plr.Team = Teams[plrData.Team.Value]
		else
			module.putIntoTeam(plr)
		end
	else
		plr:Kick('Unknown Data Error')
	end
	
	plr:LoadCharacter() -- respawn
end


return module
