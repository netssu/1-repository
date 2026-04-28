local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Variables = require(script.Parent.Parent.Variables)
local Events = ReplicatedStorage.Events
local info = workspace.Info

local module = {}
local function debugSkip(message, source)
	if RunService:IsStudio() then
		warn(string.format(
			"[SkipDebug][Round %s/%s] %s | source=%s skip=%s open=%s votes=%s players=%s",
			tostring(Variables.CurrentRound),
			tostring(Variables.MaxWave),
			message,
			tostring(source or "Unknown"),
			tostring(Variables.Skip),
			tostring(Variables.SkipVoteOpen),
			tostring(Variables.SkipVotes),
			tostring(#Players:GetPlayers())
		))
	end
end

ReplicatedStorage.Functions.VoteForSkip.OnServerInvoke = function(player, source)
	if not Variables.SkipVoteOpen then
		debugSkip("Ignored vote from " .. player.Name .. " because the vote window is closed", source)
		return false
	end

	local totalMobs = 0
	local limit = Variables.mobLimit 

	if info.Versus.Value then
		limit *= 2
		totalMobs = #workspace.BlueMobs:GetChildren() + #workspace.RedMobs:GetChildren() 
	else
		totalMobs = #workspace.Mobs:GetChildren()
	end

	if totalMobs > limit then
		debugSkip(string.format("Denied vote from %s because total mobs is %s/%s", player.Name, totalMobs, limit), source)
		return "Too many enemies to skip wave! "..tostring(totalMobs).."/"..tostring(limit)
	end
	if Variables.CurrentRound >= Variables.MaxWave then
		debugSkip("Denied vote from " .. player.Name .. " on the final wave", source)
		return "Cannot skip on the final wave!"
	end
	if not Variables.Players[player.Name] then		
		Variables.SkipVotes += 1
		Variables.Players[player.Name] = true
		debugSkip("Accepted vote from " .. player.Name, source)

		ReplicatedStorage.Events.SkipGui:FireAllClients(nil, { 
			Yes = Variables.SkipVotes,

		})

		local playerCount = #Players:GetPlayers()
		if playerCount > 0 and Variables.SkipVotes/playerCount >= 0.5 then
			debugSkip("Vote threshold reached, firing skip event", source)
			script.Parent.Parent.Parent.Skip:Fire()
		end
		return true
	end

	debugSkip("Ignored duplicate vote from " .. player.Name, source)
end

script.Parent.Parent.Parent.Skip.Event:Connect(function()
	if Variables.CurrentRound >= Variables.MaxWave then return end
	Variables.Skip = true
	Variables.SkipVoteOpen = false
	debugSkip("Skip event applied to the current round")
end)

Events.Client.VoteStartGame.OnServerEvent:Connect(function(player)
	if Variables.startTime ~= nil then
		debugSkip("Ignored start vote from " .. player.Name .. " because the match has already started", "StartVote")
		return
	end

	if not table.find(Variables.PlayersVotedForStart,player.Name) then
		table.insert(Variables.PlayersVotedForStart,player.Name)
	end

	if #Variables.PlayersVotedForStart/#Players:GetChildren() >= 0.5 then
		Variables.voteStart = true
	end
end)



return module
