local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Towers = require(ReplicatedStorage.Modules.Towers)
local Players = game:GetService("Players")


local player = Players.LocalPlayer
repeat task.wait() until player:FindFirstChild('DataLoaded')
local storeAllPlayersTowerEquips = {}

function TrackPlayerTowers(player)
	repeat task.wait() until not player.Parent or player:FindFirstChild('DataLoaded')
	if not player.Parent then return end

	local currentEquips = {}
	local totalEquip = 0
	
	local function GetDisplayPriorityEquips() --will return the first 3
		local displayGamePass = player.OwnGamePasses["Display 3 Units"].Value
		local allEquipUnit = {}
		local priorityList = {}
		
		local function GetDisplayPriorityTowerFromList(list)
			local lowestEquippedSlot, lowestTower = nil
			for _, tower in list do
				if lowestEquippedSlot ~= nil then
					local currentEquippedSlot = tower:GetAttribute("EquippedSlot")
					if currentEquippedSlot > lowestEquippedSlot then continue end
					lowestEquippedSlot = currentEquippedSlot
					lowestTower = tower
				else
					lowestEquippedSlot = tower:GetAttribute("EquippedSlot")
					lowestTower = tower
				end
			end
			
			return lowestTower
		end
		
		for _, tower in player.OwnedTowers:GetChildren() do
			if tower:GetAttribute("Equipped") then
				table.insert(allEquipUnit, tower)
			end
		end
		
		if #allEquipUnit == 0 then return nil end
		
		local equipList = {}
		for i = 1, #allEquipUnit do
			if (not displayGamePass and #equipList >= 1) or #equipList >= 3 then break end
			local lowestTower = GetDisplayPriorityTowerFromList(allEquipUnit)
			table.insert(equipList, lowestTower)
			
			local towerIndex = table.find(allEquipUnit, lowestTower)
			table.remove(allEquipUnit, towerIndex)
		end
		
		
		if not displayGamePass then
			equipList = {}
		end
		
		return equipList
	end
	
	local function UpdateDisplay()
		local newPriorityEquips = GetDisplayPriorityEquips()
		local newEquips = {}
		if newPriorityEquips then
			for index, tower in newPriorityEquips do
				local oldInfo = nil
				for _, info in currentEquips do
					if info.TowerValue == tower then
						oldInfo = info
					end
				end
				if oldInfo then
					table.insert(newEquips, oldInfo)
				else
					table.insert(newEquips, {
						TowerValue = tower,
						Module = Towers.new(tower, player, index,tower:GetAttribute("Trait"),tower:GetAttribute("Shiny"))
					})
				end
			end
		else
			for _, info in currentEquips do
				info.Module:Destroy()
			end
			
		end
		
		for _, info in currentEquips do
			if not table.find(newEquips, info) then
				info.Module:Destroy()
			end
		end
		
		currentEquips = newEquips
		
		storeAllPlayersTowerEquips[player] = currentEquips
	end
	
	local function TrackEquipped(towerValue)

		UpdateDisplay()
		towerValue:GetAttributeChangedSignal("Equipped"):Connect(function()
			UpdateDisplay()
		end)
		
		towerValue:GetPropertyChangedSignal("Parent"):Connect(function()	--assumes the parent is nil
			pcall(UpdateDisplay)	--to stop error if player leaving
		end)
		
	end




	player.OwnedTowers.ChildAdded:Connect(TrackEquipped)
	for _,tower in player.OwnedTowers:GetChildren() do
		TrackEquipped(tower)
	end

end

function RemovePlayerTowers(player)
	if not storeAllPlayersTowerEquips[player] then return end
	for _,data in storeAllPlayersTowerEquips[player] do
		pcall(function()
			data.Module:Destroy()
		end)
	end
	storeAllPlayersTowerEquips[player] = nil
end
game.Players.PlayerRemoving:Connect(RemovePlayerTowers)
game.Players.PlayerAdded:Connect(TrackPlayerTowers)

for _,player in game.Players:GetPlayers() do
	pcall(function()
		task.spawn(function()
			TrackPlayerTowers(player)
		end)
	end)
end



