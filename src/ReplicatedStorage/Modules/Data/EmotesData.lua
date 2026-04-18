--!strict

------------------//SERVICES
local Players = game:GetService("Players")

------------------//CONSTANTS
local LocalPlayer = Players.LocalPlayer
local EmotesData = {}

EmotesData.Emotes = {
	["Default Dance"] = {
		Name = "Default Dance",
		Rarity = "Common",
		Weight = 1000,
		ImageId = "",
		AnimationId = "rbxassetid://92621326488754",

	},
	["JOJO POSE"] = {
		Name = "JOJO POSE",
		Rarity = "Exclusive",
		Weight = 0,
		ImageId = "",
		AnimationId = "rbxassetid://94255944463199",
	},
	["TAKE THE L"] = {
		Name = "TAKE THE L",
		Rarity = "Exclusive",
		Weight = 0,
		ImageId = "",
		AnimationId = "rbxassetid://92621326488754",
	},
	["SHUFFLE"] = {
		Name = "SHUFFLE",
		Rarity = "Exclusive",
		Weight = 0,
		ImageId = "",
		AnimationId = "rbxassetid://91319337370874",
	},
}

------------------//VARIABLES

------------------//FUNCTIONS
function EmotesData.GetEmote(emoteName: string)
	return EmotesData.Emotes[emoteName]
end

function EmotesData.GetItemViewport(itemName: string): GuiObject?
	local itemData = EmotesData.Emotes[itemName]
	if not itemData then
		warn("EmotesData: Emote not found - " .. tostring(itemName))
		return nil
	end

	if (not itemData.AnimationId or itemData.AnimationId == "") and itemData.ImageId and itemData.ImageId ~= "" then
		local image = Instance.new("ImageLabel")
		image.Name = "Viewport_" .. itemName
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromScale(1, 1)
		image.Image = itemData.ImageId
		image.ScaleType = Enum.ScaleType.Fit
		return image
	end

	if itemData.AnimationId and itemData.AnimationId ~= "" then
		local char = LocalPlayer.Character
		if not char then
			warn("EmotesData: Character not loaded yet.")
			return nil
		end

		local viewport = Instance.new("ViewportFrame")
		viewport.Name = "Viewport_" .. itemName
		viewport.BackgroundTransparency = 1
		viewport.Size = UDim2.fromScale(1, 1)

		local worldModel = Instance.new("WorldModel")
		worldModel.Parent = viewport

		char.Archivable = true
		local dummy = char:Clone()
		char.Archivable = false

		for _, child in ipairs(dummy:GetDescendants()) do
			if child:IsA("Script") or child:IsA("LocalScript") then
				child:Destroy()
			end
		end

		local centerPos = Vector3.new(0, 0, 0)
		local cameraPos = Vector3.new(0, 1.5, 6)

		if dummy.PrimaryPart then
			dummy:PivotTo(CFrame.lookAt(centerPos, cameraPos))
		else
			local hrp = dummy:FindFirstChild("HumanoidRootPart") :: BasePart
			if hrp then
				dummy:PivotTo(CFrame.lookAt(centerPos, cameraPos))
			end
		end

		dummy.Parent = worldModel

		local camera = Instance.new("Camera")
		camera.CFrame = CFrame.lookAt(cameraPos, centerPos)
		viewport.CurrentCamera = camera
		camera.Parent = viewport

		local humanoid = dummy:FindFirstChild("Humanoid") :: Humanoid
		if humanoid then
			local animator = humanoid:FindFirstChild("Animator") :: Animator
			if not animator then
				animator = Instance.new("Animator")
				animator.Parent = humanoid
			end

			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				track:Stop(0)
			end

			local animation = Instance.new("Animation")
			animation.AnimationId = itemData.AnimationId
			local track = animator:LoadAnimation(animation)
			track.Looped = true
			track:Play()
		end

		return viewport
	end

	return nil
end

------------------//INIT
return EmotesData