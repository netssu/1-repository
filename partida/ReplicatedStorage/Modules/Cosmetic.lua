local Cosmetic = {}

function Cosmetic.Apply(equip, Character, CosmeticName)
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
	
	if not equip then return end
	
	local cosmeticFolder = CosmeticName and game.ReplicatedStorage.Cosmetics:FindFirstChild(CosmeticName) or nil
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
		--warn(`Does not have a cosmetic for {CosmeticName}`)
		return false
	end
end

return Cosmetic
