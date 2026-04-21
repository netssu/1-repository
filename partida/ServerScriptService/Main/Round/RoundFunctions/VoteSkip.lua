local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Variables = require(script.Parent.Parent.Variables)
local Events = ReplicatedStorage.Events
local info = workspace.Info

local module = {}
ReplicatedStorage.Functions.VoteForSkip.OnServerInvoke = function(player)
	
	local totalMobs = 0
	local limit = Variables.mobLimit 
	
	if info.Versus.Value then
		limit *= 2
		totalMobs = #workspace.BlueMobs:GetChildren() + #workspace.RedMobs:GetChildren() 
	else
		totalMobs = #workspace.Mobs:GetChildren()
	end

	if totalMobs > limit then
		return "Too many enemies to skip wave! "..tostring(totalMobs).."/"..tostring(limit)
	end
	if Variables.CurrentRound >= Variables.MaxWave then
		return "Cannot skip on the final wave!"
	end
	if not Variables.Players[player.Name] then		
		Variables.SkipVotes += 1

		ReplicatedStorage.Events.SkipGui:FireAllClients(nil, { 
			Yes = Variables.SkipVotes,

		})
		table.insert(Variables.Players,#Variables.Players+1)

		if Variables.SkipVotes/#Variables.Players >= 0.5 then
			script.Parent.Parent.Parent.Skip:Fire()
		end
		return true
	end
end

script.Parent.Parent.Parent.Skip.Event:Connect(function()
	if Variables.CurrentRound >= Variables.MaxWave then return end
	Variables.Skip = true
end)

Events.Client.VoteStartGame.OnServerEvent:Connect(function(player)
	if not table.find(Variables.PlayersVotedForStart,player.Name) then
		table.insert(Variables.PlayersVotedForStart,player.Name)
	end

	if #Variables.PlayersVotedForStart/#Players:GetChildren() >= 0.5 then
		Variables.voteStart = true
	end
end)



return module