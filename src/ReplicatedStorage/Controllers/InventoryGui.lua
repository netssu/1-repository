--!strict
------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

------------------//CONSTANTS
local LocalPlayer = Players.LocalPlayer
local Packets = require(ReplicatedStorage.Modules.Game.Packets) :: any
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager) :: any
local CosmeticsData = require(ReplicatedStorage.Modules.Data.CosmeticsData) :: any
local EmotesData = require(ReplicatedStorage.Modules.Data.EmotesData) :: any
local PlayerCardsData = require(ReplicatedStorage.Modules.Data.PlayerCardsData) :: any
local GuiController = require(ReplicatedStorage.Controllers.GuiController) :: any
local CAMERA_OFFSET = CFrame.new(-3.5, 0, -9.0)
local LOOK_AT_OFFSET = Vector3.new(-3.5, 0, 0)
local CAMERA_FOLLOW_LERP_SPEED = 10
type CategoryConfig = { Title: string, DataKey: string, Id: number }
local CATEGORIES: { [string]: CategoryConfig } = {
	Cosmetics = { Title = "Cosmetics", DataKey = "Cosmetics", Id = 1 },
	PlayerCards = { Title = "PlayerCards", DataKey = "Cards", Id = 2 },
	Emotes = { Title = "Emotes", DataKey = "Emotes", Id = 3 }
}

------------------//VARIABLES
local InventoryGui = {}
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local MainGui = PlayerGui:WaitForChild("Main")
local InventoryFrame = MainGui:WaitForChild("Inventory")
local ViewCard = InventoryFrame:WaitForChild("ViewCard") :: ImageLabel
local MainContainer = InventoryFrame:WaitForChild("Main")
local SlotsContainer = MainContainer:WaitForChild("Slots"):WaitForChild("Contents")
local CategoryContainer = MainContainer:WaitForChild("Category")
local CategoryOptions = CategoryContainer:WaitForChild("Options")
local DropDown = CategoryOptions:WaitForChild("DropDown")
local DropDownOptions = DropDown:WaitForChild("Options")
local CategoryBtn = CategoryContainer:WaitForChild("Options"):WaitForChild("Btn"):WaitForChild("Btn") :: GuiButton
local CategoryText = CategoryOptions:WaitForChild("Tex"):WaitForChild("Category") :: TextLabel
local SelectorFrame = InventoryFrame:WaitForChild("Selector")
local SpinIndicator = SelectorFrame:WaitForChild("Spin") :: GuiObject
local WheelFrame = InventoryFrame:WaitForChild("Wheel"):WaitForChild("Bg")
local HeaderTabs = InventoryFrame:WaitForChild("Header"):WaitForChild("Tabs"):WaitForChild("Contents")
local CurrentCategory: string = CATEGORIES.Cosmetics.Title
local IsDropDownOpen: boolean = false
local CameraConnection: RBXScriptConnection? = nil
local PreviewCameraCFrame: CFrame? = nil
local WheelConnections: {RBXScriptConnection} = {}

local ViewCardScale: UIScale = (ViewCard:FindFirstChild("UIScale") or Instance.new("UIScale")) :: UIScale
ViewCardScale.Parent = ViewCard
local CardTween: Tween? = nil

------------------//FUNCTIONS
local function getCameraBasisCFrame(rootPart: BasePart): CFrame
	local lookVector = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
	if lookVector.Magnitude < 1e-4 then
		lookVector = Vector3.new(0, 0, -1)
	else
		lookVector = lookVector.Unit
	end
	return CFrame.lookAt(rootPart.Position, rootPart.Position + lookVector, Vector3.yAxis)
end

local function SetupLiveCamera()
	local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart") :: BasePart
	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	PreviewCameraCFrame = workspace.CurrentCamera.CFrame
	if not CameraConnection then
		CameraConnection = RunService.RenderStepped:Connect(function(deltaTime: number)
			if char and hrp and char.Parent then
				local basisCFrame = getCameraBasisCFrame(hrp)
				local targetCamPos = basisCFrame:ToWorldSpace(CAMERA_OFFSET)
				local targetLookAt = basisCFrame:PointToWorldSpace(LOOK_AT_OFFSET)
				local targetCFrame = CFrame.lookAt(targetCamPos.Position, targetLookAt, Vector3.yAxis)
				local alpha = 1 - math.exp(-CAMERA_FOLLOW_LERP_SPEED * math.clamp(deltaTime, 0, 0.1))
				PreviewCameraCFrame = PreviewCameraCFrame and PreviewCameraCFrame:Lerp(targetCFrame, alpha) or targetCFrame
				workspace.CurrentCamera.CFrame = PreviewCameraCFrame
			end
		end)
	end
end

local function ResetCamera()
	if CameraConnection then
		CameraConnection:Disconnect()
		CameraConnection = nil
	end
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	PreviewCameraCFrame = nil
end

local function ClearSlots()
	for _, child in ipairs(SlotsContainer:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "Common" and child.Name ~= "Rare" and child.Name ~= "Epic" and child.Name ~= "Legendary" then
			child:Destroy()
		end
	end
end

local function GetEquippedData(categoryDataKey: string): {string}
	if categoryDataKey == "Cosmetics" then
		return PlayerDataManager:Get(LocalPlayer, { "EquippedCosmetics" }) or {}
	elseif categoryDataKey == "Emotes" then
		return PlayerDataManager:Get(LocalPlayer, { "EquippedEmotes" }) or {}
	elseif categoryDataKey == "Cards" then
		local eq = PlayerDataManager:Get(LocalPlayer, { "EquippedCard" })
		return eq ~= "" and {eq} or {}
	end
	return {}
end

local function IsItemEquipped(itemName: string, equippedList: {string}): boolean
	for _, eqItem in ipairs(equippedList) do
		if eqItem == itemName then return true end
	end
	return false
end

local function PointSpinToMouse()
	if not SpinIndicator then return end
	local mouse = LocalPlayer:GetMouse()
	local center = SelectorFrame.AbsolutePosition + (SelectorFrame.AbsoluteSize / 2)
	local angle = math.atan2(mouse.Y - center.Y, mouse.X - center.X)
	SpinIndicator.Rotation = math.deg(angle) + 90
end

local function PlayEmoteOnLocalPlayer(emoteName: string)
	local emoteData = EmotesData.Emotes[emoteName]
	if not emoteData or not emoteData.AnimationId or emoteData.AnimationId == "" then return end
	local char = LocalPlayer.Character
	if not char then return end
	local humanoid = char:FindFirstChild("Humanoid") :: Humanoid
	local animator = humanoid and humanoid:FindFirstChild("Animator") :: Animator
	if not animator then return end
	for _, playingTrack in ipairs(animator:GetPlayingAnimationTracks()) do
		playingTrack:Stop(0.5) 
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = emoteData.AnimationId
	local track = animator:LoadAnimation(animation)
	track:Play(0.5)
	task.delay(5, function()
		if track and track.IsPlaying then
			track:Stop(1) 
		end
	end)
end

local function StopAllEmotes()
	local char = LocalPlayer.Character
	if not char then return end
	local humanoid = char:FindFirstChild("Humanoid") :: Humanoid
	local animator = humanoid and humanoid:FindFirstChild("Animator") :: Animator
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			track:Stop(0.3)
		end
	end
end

local function PlayCardAnimation()
	if not CardTween then
		local tweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		CardTween = TweenService:Create(ViewCardScale, tweenInfo, {Scale = 1.05})
	end
	CardTween:Play()
end

local function StopCardAnimation()
	if CardTween then
		CardTween:Cancel()
	end
	ViewCardScale.Scale = 1
end

local function PopulateWheel(customList: {string}?)
	local equippedEmotes = customList or GetEquippedData("Emotes")
	local slotIndex = 1
	for _, conn in ipairs(WheelConnections) do
		conn:Disconnect()
	end
	table.clear(WheelConnections)
	for i = 1, 8 do
		local textureSlot = WheelFrame:FindFirstChild("Texture" .. i)
		if textureSlot then
			local itemContainer = textureSlot:FindFirstChild("ITEM")
			if itemContainer then
				for _, child in ipairs(itemContainer:GetChildren()) do
					if child:IsA("ViewportFrame") or child:IsA("ImageLabel") then
						child:Destroy()
					end
				end
			end
		end
	end
	for _, emoteName in ipairs(equippedEmotes) do
		if slotIndex > 8 then break end
		local emoteData = EmotesData.Emotes[emoteName]
		if emoteData then
			local textureSlot = WheelFrame:FindFirstChild("Texture" .. slotIndex)
			if textureSlot then
				local itemContainer = textureSlot:FindFirstChild("ITEM")
				local clickBtn = textureSlot:FindFirstChild("Btn") :: GuiButton 
				if itemContainer then
					local visualItem = EmotesData.GetItemViewport(emoteName)
					if visualItem then
						visualItem.Parent = itemContainer
					end
				end
				if clickBtn then
					local conn = clickBtn.MouseButton1Click:Connect(function()
						PlayEmoteOnLocalPlayer(emoteName)
						PointSpinToMouse()
					end)
					table.insert(WheelConnections, conn)
				end
			end
			slotIndex += 1
		end
	end
end

local function CreateSlot(itemName: string, itemData: any, categoryTitle: string, isEquipped: boolean)
	local rarity = itemData.Rarity or "Common"
	local template = SlotsContainer:FindFirstChild(rarity) :: GuiObject?
	if not template then template = SlotsContainer:FindFirstChild("Common") :: GuiObject? end
	if not template then return end
	local slot = template:Clone()
	slot.Name = itemName
	slot.Visible = true
	local placeholder = slot:FindFirstChild("Placeholder")
	if placeholder then
		placeholder:ClearAllChildren()
		local visualItem: GuiObject? = nil
		if categoryTitle == "Cosmetics" then
			visualItem = CosmeticsData.GetItemViewport(itemName)
		elseif categoryTitle == "Emotes" then
			visualItem = EmotesData.GetItemViewport(itemName)
		elseif categoryTitle == "PlayerCards" then
			visualItem = PlayerCardsData.GetCardImage(itemName)
		end
		if visualItem then
			visualItem.Parent = placeholder
		end
	end
	local nameTemplate = slot:FindFirstChild("NameTemplate") :: TextLabel?
	if nameTemplate then
		nameTemplate.Text = itemData.Name or itemName
	end
	local check = slot:FindFirstChild("Check") :: GuiObject?
	if check then
		check.Visible = isEquipped
	end
	local btn = slot:FindFirstChild("Btn") :: GuiButton?
	if btn and check then
		btn.MouseButton1Click:Connect(function()
			local currentlyEquipped = check.Visible
			local equippedList = GetEquippedData(CATEGORIES[categoryTitle].DataKey)
			if categoryTitle == "Emotes" then
				if not currentlyEquipped and #equippedList >= 8 then
					return
				end
				check.Visible = not currentlyEquipped
				Packets.RequestEquipEmote:Fire(itemName)
				PointSpinToMouse()
				local optimisticList = {}
				for _, eqItem in ipairs(equippedList) do
					if eqItem ~= itemName then
						table.insert(optimisticList, eqItem)
					end
				end
				if check.Visible then
					table.insert(optimisticList, itemName)
				end
				PopulateWheel(optimisticList)
			elseif categoryTitle == "Cosmetics" then
				check.Visible = not currentlyEquipped
				Packets.RequestEquipCosmetic:Fire(itemName)
			elseif categoryTitle == "PlayerCards" then
				check.Visible = not currentlyEquipped
				Packets.RequestEquipCard:Fire(itemName)
				if ViewCard then
					if check.Visible then
						local cardData = PlayerCardsData.Cards[itemName]
						if cardData and cardData.Image then
							ViewCard.Image = cardData.Image
							PlayCardAnimation()
						end
					else
						ViewCard.Image = ""
						StopCardAnimation()
					end
				end
			end
		end)
	end
	slot.Parent = SlotsContainer
end

local function LoadCategory(categoryName: string)
	ClearSlots()
	CurrentCategory = categoryName
	CategoryText.Text = categoryName
	local categoryConfig = CATEGORIES[categoryName]
	local ownedKey = "Owned" .. categoryConfig.DataKey
	local ownedItems = PlayerDataManager:Get(LocalPlayer, { ownedKey }) or {}
	local equippedItems = GetEquippedData(categoryConfig.DataKey)
	for _, itemName in ipairs(ownedItems) do
		local itemData: any = nil
		if categoryName == "Cosmetics" then
			itemData = CosmeticsData.Items[itemName]
		elseif categoryName == "Emotes" then
			itemData = EmotesData.Emotes[itemName]
		elseif categoryName == "PlayerCards" then
			itemData = PlayerCardsData.Cards[itemName]
		end
		if itemData then
			CreateSlot(itemName, itemData, categoryName, IsItemEquipped(itemName, equippedItems))
		end
	end
	if categoryName == "Emotes" then
		SelectorFrame.Visible = true
		WheelFrame.Visible = true
		PopulateWheel()
	else
		SelectorFrame.Visible = false
		WheelFrame.Visible = false
	end
	if categoryName == "PlayerCards" then
		if ViewCard then
			ViewCard.Visible = true
			if #equippedItems > 0 then
				local cardData = PlayerCardsData.Cards[equippedItems[1]]
				if cardData and cardData.Image then
					ViewCard.Image = cardData.Image
					PlayCardAnimation()
				else
					ViewCard.Image = ""
					StopCardAnimation()
				end
			else
				ViewCard.Image = ""
				StopCardAnimation()
			end
		end
	else
		if ViewCard then
			ViewCard.Visible = false
			StopCardAnimation()
		end
	end
end

local function ToggleDropDown()
	IsDropDownOpen = not IsDropDownOpen
	if DropDown then
		DropDown.Visible = IsDropDownOpen
	end
end

local function SetupCategoryDropDown()
	local template = DropDownOptions:FindFirstChild("templete") :: GuiObject?
	if template then template.Visible = false end
	for _, child in ipairs(DropDownOptions:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "templete" then
			child:Destroy()
		end
	end
	for key, config in pairs(CATEGORIES) do
		if template then
			local option = template:Clone()
			option.Name = key
			option.Visible = true
			local bg1 = option:FindFirstChild("Bg")
			if bg1 then
				local bg2 = bg1:FindFirstChild("Bg")
				if bg2 then
					local namesText = bg2:FindFirstChild("Names") :: TextLabel?
					if namesText then
						namesText.Text = config.Title
					end
				end
			end
			local btn = option:FindFirstChild("Btn") :: GuiButton?
			if btn then
				btn.MouseButton1Click:Connect(function()
					ToggleDropDown()
					LoadCategory(config.Title)
				end)
			end
			option.Parent = DropDownOptions
		end
	end
end

local function SetupHeaderTabs()
	for _, tabFrame in ipairs(HeaderTabs:GetChildren()) do
		if not tabFrame:IsA("Frame") then continue end
		local targetGuiName = tabFrame.Name
		local btn = tabFrame:FindFirstChild("Btn") :: GuiButton?
		if not btn then continue end
		btn.MouseButton1Click:Connect(function()
			GuiController:Open(targetGuiName)
		end)
	end
end

------------------//INIT
function InventoryGui.Init(): ()
	if DropDown then DropDown.Visible = false end
	if SelectorFrame then SelectorFrame.Visible = false end
	if WheelFrame then WheelFrame.Visible = false end
	if ViewCard then ViewCard.Visible = false end
	local common = SlotsContainer:FindFirstChild("Common") :: GuiObject?
	local rare = SlotsContainer:FindFirstChild("Rare") :: GuiObject?
	local epic = SlotsContainer:FindFirstChild("Epic") :: GuiObject?
	local legendary = SlotsContainer:FindFirstChild("Legendary") :: GuiObject?
	if common then common.Visible = false end
	if rare then rare.Visible = false end
	if epic then epic.Visible = false end
	if legendary then legendary.Visible = false end
end

function InventoryGui.Start(): ()
	CategoryBtn.MouseButton1Click:Connect(ToggleDropDown)
	SetupHeaderTabs()
	InventoryFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if InventoryFrame.Visible then
			SetupLiveCamera()
			SetupCategoryDropDown()
			LoadCategory("Cosmetics")
		else
			StopAllEmotes() 
			ResetCamera()
			IsDropDownOpen = false
			if DropDown then
				DropDown.Visible = false
			end
			if ViewCard then
				ViewCard.Visible = false
				StopCardAnimation()
			end
		end
	end)
end

return InventoryGui