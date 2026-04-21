local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Variables = require(ServerScriptService.Main.Round.Variables)
local TerrainSaveLoad = require(ServerStorage.ServerModules.TerrainSaveLoad)
local StoryModeStats = require(ReplicatedStorage.StoryModeStats)
local Lighting = game:GetService("Lighting")
local Teams = game:GetService("Teams")


local LightingPropertyMappings = {
	ClockTime = 'ClockTime',
	Ambient = 'Ambient',
	Brightness = 'Brightness',
	ColorShift_Top = 'ColorShift_Top',
	EnvironmentSpecularScale = 'EnvironmentSpecularScale',
	ShadowSoftness = 'ShadowSoftness',
	OutdoorAmbient = 'OutdoorAmbient',
}

local info = workspace.Info

local module = {}

function module.LoadMap()
	if info.Versus.Value or info.Competitive.Value then
		return module.loadCompMap()
	else
		return module.loadMainMap()
	end
end

local RunService = game:GetService("RunService")


function module.loadCompMap()
	local SelectedMap = nil

	if RunService:IsStudio() then	
		SelectedMap = 'Naboo Planet'
		info.WorldString.Value = 'Naboo Planet'
	else
		SelectedMap = info.WorldString.Value
	end

	-- Offset the position(Z axis) by 208 studs if gamemode is versus
	--[[
	Rename platform to RedPlatform and BluePlatform
	
	Make spawn points equal to the position and set the values to the team colours
	--]]

	-- Disable Wind
	workspace.GlobalWind = Vector3.new(0,0,0)

	local RedTeam = Instance.new('Team', Teams)
	RedTeam.Name = 'Red'
	RedTeam.TeamColor = BrickColor.new('Really red')
	RedTeam.AutoAssignable = false

	local BlueTeam = Instance.new('Team', Teams)
	BlueTeam.Name = 'Blue'
	BlueTeam.TeamColor = BrickColor.new('Really blue')
	BlueTeam.AutoAssignable = false


	print('Detected versus gamemode')

	SelectedMap = ServerStorage.CompetitiveMaps[SelectedMap]:Clone()


	Lighting:ClearAllChildren()
	Lighting.FogEnd = 99999999
	Lighting.ColorShift_Top = Color3.fromRGB(255,255,255)
	Lighting.FogColor = Color3.fromRGB(255,255,255)
	Lighting.EnvironmentDiffuseScale = 0




	--workspace.Terrain:FillBlock(workspace.Waterify.CFrame, workspace.Waterify.Size, Enum.Material.Water) -- Expand the terrain		
	if SelectedMap:FindFirstChild("Lighting") then
		game.Lighting:ClearAllChildren()
		if SelectedMap.Lighting:FindFirstChild("Children") then
			for i, v in SelectedMap.Lighting.Children:GetChildren() do
				v.Parent = game.Lighting
			end
		end
		for i, v in SelectedMap.Lighting:GetChildren() do
			if v:IsA("ValueBase") then
				if game.Lighting[v.Name] then
					game.Lighting[v.Name] = v.Value
				else
					print(v.Name)
				end
			end
		end
		
		SelectedMap.Lighting:Destroy() -- clear
	end
	
	for i,v:BasePart in SelectedMap:GetChildren() do
		if workspace:FindFirstChild(v.Name) then
			for i, obj in v:GetChildren() do
				obj.Parent = workspace[v.Name]
			end
		else
			v.Parent = workspace
		end
	end
	
	for i,x in pairs(SelectedMap:GetChildren()) do -- Load map in (RED)
		if x.Name == 'Lighting' then
			for i,v in pairs(x:GetChildren()) do
				v.Parent = Lighting

				local propertyName = LightingPropertyMappings[v.Name]
				if propertyName then
					Lighting[propertyName] = v.Value
				end
			end
		elseif x.Name == 'RadiusPoint' then
			x.RadiusPart.Parent = workspace.RadiusPoint
		elseif x.Name == 'MapData' then
			x.Parent = workspace.MapData
		elseif x.Name == 'KillPartFolder' then
			x.KillPart.Team.Value = 'Red'
			x.Parent = workspace.KillPartFolder
		else
			local Folder = Instance.new('Folder')
			Folder.Name = 'Red' .. x.Name
			Folder.Parent = workspace

			for i,v in pairs(x:GetChildren()) do
				v.Parent = workspace['Red' .. x.Name]
			end
		end
	end


	workspace.Mobs.Name = 'RedMobs'
	Instance.new('Folder', workspace).Name = 'BlueMobs'

	ServerStorage.Maps:Destroy()
	ServerStorage.CompetitiveMaps:Destroy()
	
	workspace.RedBase.Humanoid:GetPropertyChangedSignal('Health'):Connect(function()
		if workspace.RedBase.Humanoid.Health <= 0 then
			info.WinningTeam.Value = "Blue"
			info.GameRunning.Value = false
			Variables.died = true
			info.GameOver.Value = true
			info.Message.Value = "GAME OVER"
			workspace.RedMobs:ClearAllChildren()
			workspace.BlueMobs:ClearAllChildren()
		end
	end)
	
	workspace.BlueBase.Humanoid:GetPropertyChangedSignal('Health'):Connect(function()
		if workspace.BlueBase.Humanoid.Health <= 0 then
			info.WinningTeam.Value = "Red"
			info.GameRunning.Value = false
			Variables.died = true
			info.GameOver.Value = true
			info.Message.Value = "GAME OVER"
			workspace.RedMobs:ClearAllChildren()
			workspace.BlueMobs:ClearAllChildren()
		end
	end)
	
	return workspace -- i guess?
end

function module.loadMainMap()
	Variables.votedMap = nil
	if info.TestingMode.Value and game:GetService('RunService'):IsStudio() then
		--votedMap = "TestMap"
		Variables.votedMap = 'Bespin' 
		for i, player in Players:GetPlayers() do
			player:WaitForChild("Money").Value += 5000000
		end
	else
		if info.Raid.Value then
			Variables.votedMap = ReplicatedStorage.CurrentRaidEventMap.Value
		else
			Variables.votedMap = StoryModeStats.Maps[StoryModeStats.Worlds[info.World.Value]]
		end
	end

	if info.EventMap.Value ~= "" then
		Variables.votedMap = info.EventMap.Value
	end

	local mapFolder = ServerStorage.Maps:FindFirstChild(Variables.votedMap)
	local newMap = mapFolder:Clone()
	if newMap:FindFirstChild("Lighting") then
		game.Lighting:ClearAllChildren()
		if newMap.Lighting:FindFirstChild("Children") then
			for i, v in newMap.Lighting.Children:GetChildren() do
				v.Parent = game.Lighting
			end
		end
		for i, v in newMap.Lighting:GetChildren() do
			if v:IsA("ValueBase") then
				if game.Lighting[v.Name] then
					game.Lighting[v.Name] = v.Value
				else
					print(v.Name)
				end
			end
		end
	end

	if newMap:FindFirstChild('LoadTerrain') then -- terain loading
		for i,v in newMap.LoadTerrain:GetChildren() do
			TerrainSaveLoad.Load(v)
		end
	end

	newMap.Parent = workspace.Map

	newMap.Base.Humanoid:GetPropertyChangedSignal('Health'):Connect(function()
		if newMap.Base.Humanoid.Health <= 0 then
			info.GameRunning.Value = false
			Variables.died = true
			info.GameOver.Value = true
			info.Message.Value = "GAME OVER"
			game.Workspace.Mobs:ClearAllChildren()
		end
	end)

	local spawnCFrame = newMap:FindFirstChildOfClass('SpawnLocation')

	if spawnCFrame then
		for i,v in pairs(Players:GetChildren()) do
			task.spawn(function()
				local s,e = nil,nil
				repeat 
					s,e = pcall(function()
						v.Character:PivotTo(spawnCFrame.CFrame + CFrame.new(Vector3.new(0,5,0)))
					end)
					task.wait(0.1)
				until s
			end)
		end
	end
	return newMap
end

return module