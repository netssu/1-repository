local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local ClanLib = require(ServerScriptService.ClanService.ClansHandler.ClanLib)

local module = {}
local ClanLeaderboardQueue = require(ServerScriptService.ClanService.ClanLoader.ClanLeaderboardQueue)

if not workspace:GetAttribute('Lobby') then
	local ClanKills = {}

	repeat task.wait() until workspace.Info.GameOver.Value

	for i,v in Players:GetChildren() do
		local plrClan = v.ClanData.CurrentClan.Value
		if v:FindFirstChild('ClansLoaded') and plrClan ~= 'None' then
			--v.Kills.Value 
			local clanData = nil
			

			pcall(function()
				print('Granting kills')
				clanData = ClanLib.giveStat(plrClan, v.UserId, 'Kills', v.Kills.Value)
				clanData = clanData and clanData.Message
			end)
			
			if clanData then
				pcall(function()
					ClanLeaderboardQueue.addToQueue(plrClan, "Kills", clanData.Stats['Kills'] - clanData.PreviousStats['Kills'])
				end)
			end
			
			if workspace.Info.Victory.Value then
				local amount = math.round((workspace.Info.World.Value/2) * 60)
				if not amount then continue end
				
				local clanData = nil
				
				pcall(function()
					print('Granting XP')
					clanData = ClanLib.giveStat(plrClan, v.UserId, 'XP', amount)
					clanData = clanData and clanData.Message
				end)
				
				if clanData then
					pcall(function()
						ClanLeaderboardQueue.addToQueue(plrClan, "XP", clanData.Stats['XP'] - clanData.PreviousStats['XP'])
					end)
				end
			elseif workspace.Info.Infinity.Value and workspace.Info.Wave.Value > 50 then
				local amount = math.round((workspace.Info.World.Value/2) * workspace.Info.Wave.Value)
				if not amount then continue end
				local clanData = nil

				pcall(function()
					print('Granting XP')
					clanData = ClanLib.giveStat(plrClan, v.UserId, 'XP', amount)
					clanData = clanData and clanData.Message
				end)

				if clanData then
					pcall(function()
						ClanLeaderboardQueue.addToQueue(plrClan, "XP", clanData.Stats['XP'] - clanData.PreviousStats['XP'])
					end)
				end
			end
		end
	end
end


return module