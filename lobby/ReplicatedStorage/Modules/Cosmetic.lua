local Cosmetic = {}

local RS = game:GetService("ReplicatedStorage")

function Cosmetic.Apply(equip, Player, CosmeticName, CosmeticUniqueID, Shiny)
	local connections = {}
	local function Remove()
		local Character = Player.Character
		if not Character then return end
		
		local oldCosmeticFolder = Character:FindFirstChild("Cosmetic")
		local oldOriginalClothingFolder = Character:FindFirstChild("OriginalClothing")
		local oldOriginalAnimationFolder = Character:FindFirstChild("OriginalAnimation")
		if oldCosmeticFolder then
			oldCosmeticFolder:Destroy()
		end
		if oldOriginalClothingFolder then
			for _,object in oldOriginalClothingFolder:GetChildren() do
				local cosmeticClothing = Character:FindFirstChild(object.Name)
				if cosmeticClothing then
					cosmeticClothing:Destroy()
				end
				object.Parent = Character
			end
			oldOriginalClothingFolder:Destroy()
		end

		if oldOriginalAnimationFolder then
			local Animate = Character:FindFirstChild("Animate")
			for _, animationFolder in oldOriginalAnimationFolder:GetChildren() do
				for _, animation in animationFolder:GetChildren() do
					local characterAnimation = Animate[animationFolder.Name]:FindFirstChild(animation.Name)
					if not characterAnimation then continue end
					characterAnimation.AnimationId = animation.AnimationId
				end
			end
			oldOriginalAnimationFolder:Destroy()
		end
	end

	local function Add()
		local Character = Player.Character or Player.CharacterAdded:Wait()
		local cosmeticFolder = nil
		if Shiny then
			cosmeticFolder = CosmeticName and RS.Cosmetics.Shiny:FindFirstChild(CosmeticName) or nil
		else
			cosmeticFolder = CosmeticName and RS.Cosmetics:FindFirstChild(CosmeticName) or nil
		end
		
		if cosmeticFolder then
			local newCosmeticFolderFolder = cosmeticFolder:Clone()
			newCosmeticFolderFolder.Name = "Cosmetic"
			newCosmeticFolderFolder.Parent = Character

			--Clothing
			local cosmeticClothing = newCosmeticFolderFolder:FindFirstChild("Clothing")
			if cosmeticClothing then
				local originalClothingFolder = Instance.new("Folder")
				originalClothingFolder.Name = "OriginalClothing"
				originalClothingFolder.Parent = Character

				for _, object in cosmeticClothing:GetChildren() do
					local originalClothing = Character:FindFirstChild(object.Name)
					if originalClothing then
						originalClothing.Parent = originalClothingFolder
					end
					object.Parent = Character
				end
			end

			--//Welding//--
			for _,partClone in newCosmeticFolderFolder:GetChildren() do
				local weldToPart = Character:FindFirstChild(partClone.Name)
				if weldToPart == nil then continue end
				--local partClone = bodyPart:Clone()
				local weld = Instance.new("Weld")
				weld.Part0 = partClone
				weld.Part1 = weldToPart
				weld.Parent = partClone
			end

			if newCosmeticFolderFolder:FindFirstChild("Animation") then
				local Animate = Character:FindFirstChild("Animate")

				local originalAnimationFolder = newCosmeticFolderFolder.Animation
				originalAnimationFolder.Name = "OriginalAnimation"
				originalAnimationFolder.Parent = Character
				
				for _, animationFolder in originalAnimationFolder:GetChildren() do
					for _, animation in animationFolder:GetChildren() do
						local originalAnimation = Animate[animationFolder.Name]:FindFirstChild(animation.Name)
						
						if not originalAnimation then continue end

						local originalAnimationId = originalAnimation.AnimationId
						originalAnimation.AnimationId = animation.AnimationId

						animation.AnimationId = originalAnimationId


					end
				end

			end


			--//Enabling Scripts//--
			for _,object in newCosmeticFolderFolder:GetDescendants() do
				if not object:IsA("LocalScript") and not object:IsA("Script") then continue end
				object.Enabled = true
			end


			return true
		else
			warn(`Does not have a cosmetic for {CosmeticName}`)
			return false
		end
	end
	
	local function LocatePlayerTowerWithUniqueID()
		for _, tower in Player.OwnedTowers:GetChildren() do
			if tower:GetAttribute("UniqueID") == CosmeticUniqueID then
				return tower
			end
		end
		return false
	end
	
	local function ListenForTowerDeletion()
		Remove()
		Player.CosmeticEquipped.Value = ""
		Player.CosmeticUniqueID.Value = ""
		
		for _, connection in connections do
			connection:Disconnect()
		end
		connections = {}
	end
	local function CosmeticUniqueIDChanged()
		if Player.CosmeticUniqueID.Value == CosmeticUniqueID then return end
		for _, connection in connections do
			connection:Disconnect()
		end
		connections = {}
	end
	
	
	Remove()
	if not equip then return end
	
	
	local playerTowerValue = LocatePlayerTowerWithUniqueID()
	
	if not playerTowerValue then return end
	connections["TowerDestroying"] = playerTowerValue:GetPropertyChangedSignal("Parent"):Connect(ListenForTowerDeletion)
	connections["CosmeticUniqueIDChange"] = Player.CosmeticUniqueID:GetPropertyChangedSignal("Value"):Connect(CosmeticUniqueIDChanged)
	
	Add()
	return true
end

return Cosmetic
