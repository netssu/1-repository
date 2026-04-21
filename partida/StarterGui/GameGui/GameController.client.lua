-- SERVICES
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
-- CONSTANTS
local MPS = game:GetService("MarketplaceService")
local Shortner = require(ReplicatedStorage.Modules.NumberFormat)
local itemModule = require(ReplicatedStorage.ItemStats)
local ChallengeModule = require(ReplicatedStorage.Modules.ChallengeModule)
local UIMapLoadingScreenModule = require(ReplicatedStorage.Modules.Client.UIMapLoadingScreen)
local ViewModule = require(ReplicatedStorage.Modules.ViewModule)
local UIHandler = require(ReplicatedStorage.Modules.Client.UIHandler)
local GetPlayerBoost = require(game.ReplicatedStorage.Modules.GetPlayerBoost)
local GetVipsBoost = require(game.ReplicatedStorage.Modules.GetVipsBoost)
local TraitsModule = require(ReplicatedStorage.Modules.Traits)
local modules = ReplicatedStorage:WaitForChild("Modules")
local health = require(modules:WaitForChild("Health"))
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)
local FormatStats = require(ReplicatedStorage.Modules.FormatStats)
local TowerInfo = require(ReplicatedStorage.Modules.Helpers.TowerInfo)
local Format = require(game.ReplicatedStorage.Modules.MathFormat)
local GetUnitModel = require(ReplicatedStorage.Modules.GetUnitModel)
local Traits = require(ReplicatedStorage.Traits)
local VFX_Loader = require(ReplicatedStorage.VFX_Loader)
local ExpModule = require(ReplicatedStorage.Modules.ExpModule)
local StoryModeStats = require(ReplicatedStorage.StoryModeStats)
local RaidModeStats = require(ReplicatedStorage.RaidModeStats)
local upgradesModule = require(ReplicatedStorage.Upgrades)
local TweenModule = require(ReplicatedStorage.AceLib.TweenModule)
local NumberValueConvert = require(ReplicatedStorage.AceLib.NumberValueConvert)
local RankCalculator = require(ReplicatedStorage.CompetitiveData.RankCalculator)
local RomanNumeralsConverter = require(ReplicatedStorage.AceLib.RomanNumeralsConverter)
local EmitModule = require(ReplicatedStorage.Modules:WaitForChild("EmitModule"))
local functions = ReplicatedStorage:WaitForChild("Functions")
local requestTowerFunction = functions:WaitForChild("RequestTower")
local spawnTowerFunction = functions:WaitForChild("SpawnTower")
local UpgradeFunction = functions:WaitForChild("Upgrade")
local sellTowerFunction = functions:WaitForChild("SellTower")
local changeModeFunction = functions:WaitForChild("ChangeTowerMode")
local getDataFunction = functions:WaitForChild("GetData")
local requestAbilityFunction = functions:WaitForChild("RequestAbility")
local events = ReplicatedStorage:WaitForChild("Events")
local fireAbilityEvent = events:WaitForChild("FireAbility")
local ActivateAbility = ReplicatedStorage.Remotes.DestroyerRemotes.CallDestroyer
local possessEvent = events:WaitForChild("PossessTower")
local AbilityStatus = ReplicatedStorage.States.AbilityStatus
local UnitGradients = ReplicatedStorage.Borders
local Click = SoundService.SoundFX.Click
local requiredSlotLevel = {0, 0, 0, 10, 20, 30}
local SelectedTowers = {}
-- VARIABLES
local player = Players.LocalPlayer
local playerMoney = Players.LocalPlayer:WaitForChild("Money")
local playerguix = player.PlayerGui
local IngameHud = playerguix:WaitForChild("NewUI"):WaitForChild("IngameHud")
local FailedScreen = playerguix:WaitForChild("NewUI"):WaitForChild("Failed")
local VictoryScreen = playerguix:WaitForChild("NewUI"):WaitForChild("Victory")
local SpeedButton = IngameHud.Top.Speed
local mouse = game.Players.LocalPlayer:GetMouse()
local camera = workspace.CurrentCamera
local gui = script.Parent
local GlobalGUI = gui.Parent:WaitForChild("GlobalGUI")
local info = workspace:WaitForChild("Info")
local Upgrade = playerguix:WaitForChild("NewUI"):WaitForChild("Scout")
local SkipUI = playerguix:WaitForChild("NewUI"):WaitForChild("Skip")
local selectedTower = nil
local towerToSpawn = nil
local towerToSpawnValue = nil
local IsOwner = nil
local canPlace = false
local rotation = 0
local placedTowers = 0
local maxTowers
local lastTouch = tick()
local spawnCooldown = 0.5
local lastSpawnTime = 0
local lastHighlight = nil
local lastValidResult = nil
local hoveredInstance = nil
local abilityConn = nil :: RBXScriptConnection
local abilityTick = nil
local abilityActivateConn = nil :: RBXScriptConnection
local LevelBar = IngameHud.Bottom.LevelBar.Fill
local LevelNumber = IngameHud.Bottom.LevelBar.Text
local activeEndScreen = nil
local endScreenConnections = {}
-- FUNCTIONS
EmitModule.init()
local function getSlotByIndex(i)
	return IngameHud.Bottom.Slot:FindFirstChild(tostring(i))
end
local function getUnitRarity(unit)
	local rarity = nil
	for i, v in ReplicatedStorage.Towers:GetChildren() do
		if v:IsA("Folder") then
			if v:FindFirstChild(unit) then
				rarity = v.Name
				break
			end
		end
	end
	return rarity
end
local function convertNum(ELO)
	return ELO % 100
end
local function formatTime(seconds)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local seconds = math.floor(seconds % 60)
	return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end
local function CheckIfPc()
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled then
		return false
	elseif not UserInputService.TouchEnabled and UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
		return true
	end
end
local function EndScreenGUIDisable(value)
	IngameHud.Bottom.AmountMoney.Visible = value
	IngameHud.Bottom.Slot.Visible = value
	if info.Versus.Value then
		local vh = IngameHud.Top:FindFirstChild("VersusHealth")
		if vh then
			vh.Visible = value
		end
	else
		IngameHud.Top.HealthBar.Visible = value
	end
end
local function UpdatePlayerLevelBar()
	local playerLevelValue = player.PlayerLevel.Value
	local playerExpValue = player.PlayerExp.Value
	local requireExp = ExpModule.playerExpCalculation(playerLevelValue)
	TweenService:Create(LevelBar, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.fromScale((playerExpValue / requireExp), 1)}):Play()
	LevelNumber.Text = `Level {playerLevelValue} [{playerExpValue}/{requireExp}]`
end
local function updateAbilityStatus()
	local Rightsection = Upgrade:FindFirstChild("Rightsection")
	if Rightsection and Rightsection.Buttons:FindFirstChild("Ability") then
		Rightsection.Buttons.Ability.DisplayBind.TextLabel.Text = AbilityStatus.Value
	end
end
local function MouseRaycast(model)
	local mousePosition = UserInputService:GetMouseLocation()
	local mouseRay = camera:ViewportPointToRay(mousePosition.X, mousePosition.Y)
	local raycastParams = RaycastParams.new()
	local blacklist = camera:GetChildren()
	table.insert(blacklist, model)
	table.insert(blacklist, player.Character)
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = blacklist
	raycastParams.CollisionGroup = "UnitSelection"
	local raycastResult = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 1000, raycastParams)
	for i = 1, 10 do
		if not raycastResult or raycastResult.Instance.CanQuery then break end
		table.insert(blacklist, raycastResult.Instance)
		raycastResult = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 1000, raycastParams)
	end
	return raycastResult
end
local function createplacementbox()
	local e = workspace.Towers:GetChildren()
	for i, tower in e do
		if tower:FindFirstChild("PlacementBox") or tower:GetAttribute("Ignore") then continue end
		local p = Instance.new("Part")
		local w = Instance.new("WeldConstraint")
		p.Name = "PlacementBox"
		p.Parent = tower
		w.Name = "PlacementWeld"
		w.Parent = tower
		w.Part0 = tower.VFXTowerBasePart
		w.Part1 = p
		p.Anchored = true
		p.CanCollide = true
		p.CFrame = tower.VFXTowerBasePart.CFrame
		p.Color = Color3.new(0.988235, 0, 0)
		p.Material = Enum.Material.ForceField
		p.Size = Vector3.new(2.623, 3.256, 3.256)
		p.Orientation = Vector3.new(0, 90, -90)
		p.Shape = Enum.PartType.Cylinder
		PhysicsService:SetPartCollisionGroup(p, "Tower")
	end
	for i, v: BasePart in workspace:WaitForChild("RedZones"):GetChildren() do
		v.Transparency = 0
	end
end
local function CreateRangeCircle(tower: Model, placeholder)
	local HumanoidRootPart = tower:WaitForChild("HumanoidRootPart")
	local rangesize = Vector3.new(0, 0, 0)
	if game.Workspace.Camera:FindFirstChild("Range") then
		rangesize = game.Workspace.Camera.Range.Size
	end
	game.Workspace.Camera:ClearAllChildren()
	local config = if placeholder then upgradesModule[tower.Name].Upgrades[1] else upgradesModule[tower.Name].Upgrades[tower.Config:WaitForChild("Upgrades").Value]
	local range = TowerInfo.GetRange(tower, placeholder)
	local height = (HumanoidRootPart.Size.Y * 2.5) / 2
	local offset = CFrame.new(0, -height, 0)
	local _, YOrientation, _ = HumanoidRootPart.CFrame:ToOrientation()
	local VFXTowerBasePart
	if tower:FindFirstChild("VFXTowerBasePart") then
		VFXTowerBasePart = tower:FindFirstChild("VFXTowerBasePart")
	else
		VFXTowerBasePart = Instance.new("Part")
		VFXTowerBasePart.Name = "VFXTowerBasePart"
		VFXTowerBasePart.CanCollide = false
		VFXTowerBasePart.CanTouch = false
		VFXTowerBasePart.CanQuery = false
		VFXTowerBasePart.Transparency = 1
		VFXTowerBasePart.Anchored = true
		VFXTowerBasePart.Position = HumanoidRootPart.Position
		VFXTowerBasePart.Size = Vector3.new(HumanoidRootPart.Size.Y, HumanoidRootPart.Size.Y, HumanoidRootPart.Size.Y)
		VFXTowerBasePart.Parent = tower
	end
	local TowerBasePart
	if tower:FindFirstChild("TowerBasePart") then
		TowerBasePart = tower:FindFirstChild("TowerBasePart")
	else
		TowerBasePart = Instance.new("Part")
		TowerBasePart.Name = "TowerBasePart"
		TowerBasePart.CanCollide = false
		TowerBasePart.CanTouch = false
		TowerBasePart.CanQuery = false
		TowerBasePart.Transparency = 1
		TowerBasePart.Anchored = true
		TowerBasePart.Position = HumanoidRootPart.Position
		TowerBasePart.Size = Vector3.new(HumanoidRootPart.Size.Y, HumanoidRootPart.Size.Y, HumanoidRootPart.Size.Y)
		TowerBasePart.Parent = tower
	end
	if placeholder then
		local p = ReplicatedStorage.VFX.Range:Clone()
		p.CFrame = VFXTowerBasePart.CFrame * offset
		p.Size = Vector3.new(range * 2, 0.01, range * 2)
		p.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = p
		weld.Part1 = VFXTowerBasePart
		weld.Parent = p
		p.Parent = tower
		local p2 = ReplicatedStorage.VFX.RangeSphere:Clone()
		p2.Name = "Range"
		p2.Size = Vector3.new(range * 2, range * 2, range * 2)
		p2.CFrame = p.CFrame * CFrame.Angles(0, 0, math.rad(-90))
		local weld2 = Instance.new("WeldConstraint")
		weld2.Part0 = p2
		weld2.Part1 = p
		weld2.Parent = p2
		p2.Parent = p
		local att = script.Attachments.PlacementParticles:Clone()
		att.Orientation = Vector3.new(0, 0, 0)
		att.Position = Vector3.new(0, VFXTowerBasePart.Size.Y * -1.45, 0)
		att.Parent = VFXTowerBasePart
		att.Outline:Emit(1)
	else
		tower.VFXTowerBasePart.CFrame = CFrame.new(tower.VFXTowerBasePart.Position) * CFrame.Angles(0, YOrientation, 0)
		local p = ReplicatedStorage.VFX.RangeSphere:Clone()
		p.Name = "Range"
		p.Size = rangesize
		p.CFrame = tower.VFXTowerBasePart.CFrame * offset
		local p2 = ReplicatedStorage.VFX.Range:Clone()
		p2.Name = "Range2"
		p2.Anchored = true
		p2.CFrame = tower.VFXTowerBasePart.CFrame * offset
		p2.Size = Vector3.new(rangesize.X + 0.01, 0.01, rangesize.Z + 0.01)
		p2.Parent = workspace.Camera
		p.Anchored = true
		p.Parent = workspace.Camera
		TweenService:Create(p2, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {Size = Vector3.new(range * 2, 0.01, range * 2)}):Play()
		TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {Size = Vector3.new(range * 2, range * 2, range * 2)}):Play()
	end
	warn("DEBUG XO1")
	if tower.TowerBasePart:FindFirstChild("PlacementParticles") and false then
		warn("wee woo dont execute")
		tower.TowerBasePart.PlacementParticles.Outline.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 0)),
			ColorSequenceKeypoint.new(.649, Color3.fromRGB(255, 170, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 242, 58))
		}
		tower.TowerBasePart.PlacementParticles.RIPPLE.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 0)),
			ColorSequenceKeypoint.new(.649, Color3.fromRGB(255, 170, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 242, 58))
		}
	end
	tower.TowerBasePart.Size = Vector3.new(2, 3, 2)
	tower.TowerBasePart.CanQuery = true
	if config.AOEType then
		if config.AOEType == "Cone" then
			local coneaoe = ReplicatedStorage.VFX.ConeAOE:Clone()
			coneaoe.Anchored = false
			local weld = Instance.new("WeldConstraint")
			coneaoe.Size = Vector3.new((config.AOESize / 45) * range * 2, 0, range)
			coneaoe.CFrame = tower.VFXTowerBasePart.CFrame * CFrame.new(0, VFXTowerBasePart.Size.Y * -1.45, -(coneaoe.Size.Z / 2))
			weld.Part0 = coneaoe
			weld.Part1 = tower.VFXTowerBasePart
			weld.Parent = coneaoe
			coneaoe.Parent = game.Workspace.Camera
		elseif config.AOEType == "Splash" and config.Type.Value ~= "Spawner" then
			local splashaoe = ReplicatedStorage.VFX.SplashPart:Clone()
			splashaoe.Anchored = false
			local weld = Instance.new("WeldConstraint")
			splashaoe.Size = Vector3.new(config.AOESize * 2, 0, config.AOESize * 2)
			if not placeholder then
				splashaoe.CFrame = CFrame.new(tower:WaitForChild("SplashPositionPart").Position)
				weld.Part1 = tower.SplashPositionPart
			else
				local newCFrame = CFrame.new((VFXTowerBasePart.CFrame * CFrame.new(0, 0, -config.AOESize * 1.5)).Position)
				splashaoe.CFrame = newCFrame
				weld.Part1 = VFXTowerBasePart
			end
			weld.Part0 = splashaoe
			weld.Parent = splashaoe
			splashaoe.Parent = game.Workspace.Camera
			TweenService:Create(splashaoe, TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, math.huge, false), {Rotation = Vector3.new(0, 360, 0)}):Play()
			local arrows = script.Arrows:Clone()
			arrows.Parent = splashaoe
			arrows.Part1.Position = tower.VFXTowerBasePart.Position
			if placeholder then
				local weld1 = Instance.new("WeldConstraint")
				weld1.Part0 = arrows.Part1
				weld1.Part1 = tower.VFXTowerBasePart
				weld1.Parent = arrows.Part1
				arrows.Part1.Anchored = false
			end
			arrows.Part2.Position = splashaoe.Position
			arrows.Part2.Anchored = if placeholder then false else true
			local weld2 = Instance.new("WeldConstraint")
			weld2.Part0 = arrows.Part2
			weld2.Part1 = splashaoe
			weld2.Parent = arrows.Part2
		elseif config.AOEType == "AOE" then
			local fullaoe = ReplicatedStorage.VFX.SplashPart:Clone()
			fullaoe.Anchored = false
			fullaoe.Size = Vector3.new(range * 2, 0, range * 2)
			fullaoe.Position = tower.VFXTowerBasePart.Position - Vector3.new(0, VFXTowerBasePart.Size.Y * 1.45, 0)
			local weld1 = Instance.new("WeldConstraint")
			weld1.Part0 = fullaoe
			weld1.Part1 = tower.VFXTowerBasePart
			weld1.Parent = fullaoe
			fullaoe.Parent = game.Workspace.Camera
			TweenService:Create(fullaoe, TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, math.huge, false), {Rotation = Vector3.new(0, 360, 0)}):Play()
		end
	end
end
local function FindEquippedTowerName(towerName)
	local Player = Players.LocalPlayer
	for i, v in Player.OwnedTowers:GetChildren() do
		if v:GetAttribute("Equipped") == true and v.Name == towerName then
			return v
		end
	end
	return false
end
local function findSlotByTowerName(towerName)
	for i = 1, 6 do
		local slot = getSlotByIndex(i)
		if not slot then continue end
		local vp = slot.Placeholder:FindFirstChildWhichIsA("ViewportFrame")
		if vp and vp:FindFirstChild(towerName) then
			return slot
		end
	end
	return nil
end
local function RemovePlaceholderTower()
	if towerToSpawn then
		local UnitSlot = findSlotByTowerName(towerToSpawn.Name)
		if UnitSlot then
			local limitText = UnitSlot:FindFirstChild("LimitText")
			if limitText then
				limitText.Visible = false
			end
		end
		script.Parent.PhoneControls.Visible = false
		towerToSpawn:Destroy()
		towerToSpawn = nil
		rotation = 0
		gui.Controls.Visible = false
		for i, tower in workspace.Towers:GetChildren() do
			if tower:FindFirstChild("PlacementBox") then
				tower.PlacementWeld:Destroy()
				tower.PlacementBox:Destroy()
			end
		end
		game.Workspace.Camera:ClearAllChildren()
		for i, v in workspace:WaitForChild("RedZones"):GetChildren() do
			v.Transparency = 1
		end
	end
end
local function AddPlaceholderTower(name, unit)
	game.Workspace.Camera:ClearAllChildren()
	local towerExists = GetUnitModel[name]
	if towerExists then
		RemovePlaceholderTower()
		towerToSpawn = towerExists:Clone()
		local counter = 0
		local Limit = if not info.Versus.Value and (unit:GetAttribute("Trait") == "Cosmic Crusader" or unit:GetAttribute("Trait") == "Waders Will") then 1 else upgradesModule[towerToSpawn.Name]["Place Limit"]
		for _, u in game.Workspace.Towers:GetChildren() do
			if u.Name == towerToSpawn.Name and u.Config.Owner.Value == player.Name then
				counter = counter + 1
			end
		end
		local UnitSlot = findSlotByTowerName(towerToSpawn.Name)
		if UnitSlot then
			local limitText = UnitSlot:FindFirstChild("LimitText")
			if limitText then
				limitText.Visible = true
				limitText.Text = counter .. "/" .. Limit
			end
		end
		local result = MouseRaycast(towerToSpawn)
		if result and result.Instance then
			local height = towerToSpawn:WaitForChild("HumanoidRootPart").Size.Y * 1.5
			local x = result.Position.X
			local y = result.Position.Y + height
			local z = result.Position.Z
			local cframe = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(rotation), 0)
			towerToSpawn:SetPrimaryPartCFrame(cframe)
			if towerToSpawn:FindFirstChild("VFXTowerBasePart", true) then
				towerToSpawn:FindFirstChild("VFXTowerBasePart", true).CFrame = cframe
			end
		end
		towerToSpawn.Parent = workspace
		if towerToSpawn:FindFirstChild("Animations") then
			if towerToSpawn.Animations:FindFirstChild("Idle") then
				towerToSpawn.Humanoid:LoadAnimation(towerToSpawn.Animations.Idle):Play()
			end
		end
		CreateRangeCircle(towerToSpawn, true)
		createplacementbox(towerToSpawn, true)
		local equippedTower = FindEquippedTowerName(name)
		if equippedTower then
			Traits.AddVisualAura(towerToSpawn, equippedTower:GetAttribute("Trait"))
		end
		for i, object in towerToSpawn:GetDescendants() do
			if object:IsA("BasePart") then
				PhysicsService:SetPartCollisionGroup(object, "Tower")
			end
		end
		if UserInputService.TouchEnabled then
			script.Parent.PhoneControls.Visible = true
		else
			gui.Controls.Visible = true
			local connection
			local function UpdateControlPosition()
				if not gui.Controls.Visible then connection:Disconnect() end
				if UserInputService.GamepadEnabled then
					gui.Controls.Position = UDim2.new(0.075, mouse.X, 0, mouse.Y)
				else
					gui.Controls.Position = UDim2.new(0.0125, mouse.X, 0, mouse.Y)
				end
			end
			UpdateControlPosition()
			connection = mouse.Move:Connect(UpdateControlPosition)
		end
	end
end
local function toggleTowerInfo()
	abilityTick = tick()
	if abilityConn then
		abilityConn:Disconnect()
		abilityConn = nil
		abilityActivateConn:Disconnect()
		abilityActivateConn = nil
	end
	local newHighlight = Instance.new("Highlight")
	newHighlight.FillTransparency = 1
	if selectedTower then
		local towerName = type(selectedTower) == "string" and selectedTower or selectedTower.Name
		local towerUpgrades = upgradesModule[towerName]
		if not towerUpgrades then return end
		local hasMoneyUpgrade = false
		if towerUpgrades.Upgrades then
			for _, upgrade in towerUpgrades.Upgrades do
				if upgrade.Money then
					hasMoneyUpgrade = true
					break
				end
			end
		end
		for i, v: Model in workspace:WaitForChild("Spawnables"):GetChildren() do
			if v:FindFirstChild("Radius") then
				TweenModule.tween(v.Radius, 0.3, {Transparency = 1})
			end
		end
		for i, v: Model in workspace:WaitForChild("Spawnables"):GetChildren() do
			if v:IsA("Model") then
				if v:FindFirstChild("OwnedBy") and v.OwnedBy.Value == selectedTower then
					if v:FindFirstChild("Radius") then
						TweenModule.tween(v.Radius, 0.3, {Transparency = 0.7})
					end
				end
			end
		end
		Click:Play()
		local Rightsection = Upgrade:WaitForChild("Rightsection")
		local Leftsection = Upgrade:WaitForChild("Leftsection")
		local Middle = Leftsection:WaitForChild("Middle")
		local Buttons = Rightsection:WaitForChild("Buttons")
		local Profile = Rightsection:WaitForChild("Profile")
		if not hasMoneyUpgrade then
			Middle.Damage.Icon.Image = `rbxassetid://{93635387578503}`
			Middle.Damage.Visible = true
			Middle.Cooldown.Visible = true
			Middle.Range.Visible = true
			Upgrade.VFXText.Visible = true
		else
			Middle.Damage.Icon.Image = `rbxassetid://{132305833180435}`
			Middle.Damage.Visible = true
			Middle.Cooldown.Visible = false
			Middle.Range.Visible = false
			Upgrade.VFXText.Visible = true
		end
		local towername = selectedTower.Name
		local sameTower = false
		for i, v in Profile.Placeholder:GetChildren() do
			if v:IsA("ViewportFrame") and v.Name ~= towername then
				v:Destroy()
			elseif v:IsA("ViewportFrame") then
				sameTower = true
			end
		end
		CreateRangeCircle(selectedTower)
		newHighlight.Parent = selectedTower
		Upgrade.Visible = true
		local config = selectedTower.Config
		Profile.NamePerson.Text = selectedTower.Name
		Rightsection.Texto.Text = config.Owner.Value .. ""
		local buffs = {}
		local TraitBuff = config.Trait
		local TraitValue = Traits.Traits[TraitBuff.Value]
		local TraitImage = Profile:FindFirstChild("TraitIcon")
		if TraitImage then
			if TraitValue and TraitBuff.Value ~= "" and not info.Versus.Value then
				TraitImage.Visible = true
				TraitImage.Image = TraitValue.ImageID
				TraitImage.UIGradient.Color = Traits.TraitColors[TraitValue.Rarity].Gradient
			else
				TraitImage.Visible = false
			end
		end
		local buffstring = ""
		local index = 0
		for i, v in buffs do
			index += 1
			if index == 1 then
				buffstring = "Buffs: " .. i .. " " .. tostring(v) .. "%"
			else
				buffstring ..= ", " .. i .. " " .. tostring(v) .. "%"
			end
		end
		if not sameTower then
			local vp = ViewPortModule.CreateViewPort(towername, config.Shiny.Value)
			vp.Parent = Profile.Placeholder
		end
		if config.Shiny.Value and Profile:FindFirstChild("Shiny") then
			Profile.Shiny.Visible = true
		elseif Profile:FindFirstChild("Shiny") then
			Profile.Shiny.Visible = false
		end
		local TowerRarity = upgradesModule[towername].Rarity
		if TowerRarity then
			if Profile.Bg:FindFirstChild("UIGradient") then
				Profile.Bg.UIGradient.Color = UnitGradients[TowerRarity].Color
			end
			if Profile.Shadow:FindFirstChild("UIGradient") then
				Profile.Shadow.UIGradient.Color = UnitGradients[TowerRarity].Color
			end
		end
		Buttons.Target.Text.Text = config.TargetMode.Value
		Buttons.Upgrade.Visible = true
		Buttons.Target.Visible = true
		Buttons.Sell.Visible = true

		local upgradeTower = config:FindFirstChild("Upgrades")
		local UpgradeModule = require(ReplicatedStorage.Upgrades)
		local UnitStats = UpgradeModule[selectedTower.Name].Upgrades
		local CurrentData = UnitStats[upgradeTower.Value]
		if Buttons:FindFirstChild("Ability") then
			Buttons.Ability.Visible = if CurrentData.AbilityCooldown then true else false
		end
		if CurrentData.AbilityCooldown then
			abilityConn = UserInputService.InputBegan:Connect(function(key, gp)
				if not gp then
					if (key.KeyCode == Enum.KeyCode.G or key.KeyCode == Enum.KeyCode.ButtonB) and AbilityStatus.Value == "G" then
						ActivateAbility:FireServer(selectedTower)
					end
				end
			end)
			if Buttons:FindFirstChild("Ability") then
				abilityActivateConn = Buttons.Ability.Activated:Connect(function()
					ActivateAbility:FireServer(selectedTower)
				end)
			end
		end
		if upgradeTower then
			local UpgradeData = UnitStats[upgradeTower.Value + 1]
			local priceMultiplier = 1
			if Traits.Traits[config.Trait.Value] and not info.Versus.Value then
				if Traits.Traits[config.Trait.Value]["Money"] then
					priceMultiplier = (1 - (Traits.Traits[config.Trait.Value]["Money"] / 100))
				end
			end
			if workspace.Info.ChallengeNumber.Value ~= -1 then
				local challengeData = ChallengeModule.Data[workspace.Info.ChallengeNumber.Value]
				if challengeData and challengeData.UnitStats ~= nil then
					priceMultiplier += (challengeData.UnitStats.Price / 100)
				end
			end
			if UpgradeData then
				if UnitStats[upgradeTower.Value].AttackName ~= UpgradeData.AttackName then
					Upgrade.VFXText.Text = "+" .. UpgradeData.AttackName
				else
					Upgrade.VFXText.Text = ""
				end
			else
				Upgrade.VFXText.Text = ""
			end
			local levelboost = 1 + config.Level.Value * (1 / 50)
			local UpgradeStats = {Damage = nil, Range = nil, Cooldown = nil}
			for _, stat in (hasMoneyUpgrade and {"Damage"}) or {"Damage", "Range", "Cooldown"} do
				if UpgradeData ~= nil then
					UpgradeStats[stat] = UpgradeData[stat]
				end
			end
			if UpgradeStats.Damage ~= nil then
				UpgradeStats.Damage = math.round(UpgradeStats.Damage * levelboost) > 100 and (UpgradeStats.Damage * levelboost) or ((UpgradeStats.Damage * levelboost) * 10) / 10
			end
			local sellPrice = math.round(selectedTower.Config.Worth.Value / 2)
			Buttons.Sell.Text.Text = "Sell: " .. math.round(sellPrice) .. "$"
			for _, stat in (hasMoneyUpgrade and {"Damage"}) or {"Damage", "Range", "Cooldown"} do
				if not UpgradeData then
					Leftsection.Upgrade.Text = "Upgrade [Max]"
					Buttons.Upgrade.Text.Text = "Upgrade [Max]"
					Buttons.Upgrade.Visible = false
					Middle[stat]["Arrow"].Visible = false
					Middle[stat]["Value1"].Visible = false
				else
					Leftsection.Upgrade.Text = "Upgrade [" .. config.Upgrades.Value - 1 .. "]"
					Buttons.Upgrade.Visible = true
					Buttons.Upgrade.Text.Text = "Upgrade: " .. math.round(UpgradeData.Price * priceMultiplier) .. "$"
					Middle[stat]["Arrow"].Visible = true
					Middle[stat]["Value1"].Visible = true
				end
				local Value
				if hasMoneyUpgrade then
					Value = config["Money"].Value
				else
					Value = TowerInfo["Get" .. stat](selectedTower)
				end
				if not info.Versus.Value and stat == "Cooldown" and workspace:GetAttribute("CosmicCrusader") then
					Value *= Traits.Traits["Cosmic Crusader"].TowerBuffs.Cooldown
				end
				Middle[stat]["value"].Text = Format.Format(Value, 1)
				if UpgradeData then
					local Value2
					if hasMoneyUpgrade then
						Value2 = UpgradeData["Money"]
					else
						Value2 = UpgradeData[stat]
					end
					if not info.Versus.Value and stat == "Damage" then
						Value2 *= levelboost
					end
					if not info.Versus.Value and stat == "Cooldown" and workspace:GetAttribute("CosmicCrusader") then
						Value2 *= Traits.Traits["Cosmic Crusader"].TowerBuffs.Cooldown
					end
					Middle[stat]["Value1"].Text = Format.Format(Value2, 1)
				end
			end
		else
			Buttons.Upgrade.Visible = false
		end
		if config.Owner.Value == Players.LocalPlayer.Name then
			IsOwner = true
			Buttons.Upgrade.Visible = true
			Buttons.Target.Visible = true
			Buttons.Sell.Visible = true
		else
			IsOwner = false
			Buttons.Upgrade.Visible = false
			Buttons.Target.Visible = false
			Buttons.Sell.Visible = false
		end
		local originalTower = selectedTower
		local function updateTotalDamage()
			local newTotalDamage = originalTower.Config.TotalDamage.Value
			Upgrade.TotalDamage.Text = `Total Damage: {Shortner.ShortenNum(newTotalDamage)}`
		end
		updateTotalDamage()
		local connection; connection = selectedTower.Config.TotalDamage:GetPropertyChangedSignal("Value"):Connect(function()
			if selectedTower == nil or selectedTower ~= originalTower then connection:Disconnect() return end
			updateTotalDamage()
		end)
	else
		workspace.Camera:ClearAllChildren()
		Upgrade.Visible = false
		for i, v: Model in workspace:WaitForChild("Spawnables"):GetChildren() do
			if v:FindFirstChild("Radius") then
				TweenModule.tween(v.Radius, 0.3, {Transparency = 1})
			end
		end
	end
	coroutine.wrap(function()
		repeat wait(0.01) until selectedTower == nil
		newHighlight:Destroy()
	end)()
end
local function SpawnNewTower()
	local currentTime = tick()
	if canPlace and currentTime - lastSpawnTime >= spawnCooldown then
		lastSpawnTime = currentTime
		if towerToSpawn.HumanoidRootPart.CFrame == GetUnitModel[towerToSpawn.Name].HumanoidRootPart.CFrame then
			return
		end
		local placedTower = spawnTowerFunction:InvokeServer(towerToSpawnValue, towerToSpawn:WaitForChild("HumanoidRootPart").CFrame, false, true)
		if placedTower then
			placedTowers += 1
			selectedTower = placedTower
			local placeanimation = script.PlaceAnimation:Clone()
			placeanimation.Parent = placedTower
			placedTower:WaitForChild("Humanoid"):LoadAnimation(placeanimation):Play()
			local effect = script.PlacementEffect:Clone()
			effect.Position = placedTower:WaitForChild("HumanoidRootPart").Position - Vector3.new(0, 1, 0)
			effect.Parent = game.Workspace.VFX
			VFX_Loader.EmitAllParticles(effect)
			Debris:AddItem(effect, 2)
			Debris:AddItem(placeanimation, 2)
			local att = script.Attachments.PlacementParticles:Clone()
			att.Outline.LockedToPart = false
			att.RIPPLE.LockedToPart = false
			att.Position = Vector3.new(0, selectedTower:WaitForChild("HumanoidRootPart").Size.Y * -1.45, 0)
			att.Orientation = Vector3.new(0, 0, 0)
			att.Parent = selectedTower:WaitForChild("TowerBasePart")
			att.Outline:Emit(1)
			RemovePlaceholderTower()
			selectedTower = nil
			toggleTowerInfo()
		else
			warn("Bro Cant Spawn")
		end
	end
end
local function UpgradeFunc()
	if selectedTower and IsOwner then
		local upgradeTower = selectedTower:WaitForChild("Config").Upgrades.Value
		local upgradeSuccess = UpgradeFunction:InvokeServer(selectedTower)
		if typeof(upgradeSuccess) == "string" then
			_G.Message(upgradeSuccess, Color3.fromRGB(221, 0, 0))
		elseif upgradeSuccess then
			local effect = script.UpgradeEffect:Clone()
			effect.Position = selectedTower.PrimaryPart.Position - Vector3.new(0, 1, 0)
			effect.Parent = game.Workspace.VFX
			VFX_Loader.EmitAllParticles(effect)
			events.Client.TowerUpgrade:Fire(selectedTower)
			Debris:AddItem(effect, 2)
			toggleTowerInfo()
		end
	end
end
local function SellFunc()
	if selectedTower and IsOwner then
		local soldTower = sellTowerFunction:InvokeServer(selectedTower)
		if soldTower then
			selectedTower = nil
			placedTowers -= 1
			toggleTowerInfo()
		end
	end
end
local function TargetFunc()
	if selectedTower and IsOwner then
		local modeChangeSuccess = changeModeFunction:InvokeServer(selectedTower)
		if modeChangeSuccess then
			toggleTowerInfo()
		end
	end
end
local function SpectateFunc()
	if IsOwner then
		local unitHum = selectedTower:FindFirstChild("Humanoid", true)
		local cameraPartTransparencies = {}
		if unitHum then
			game.Workspace.CurrentCamera.CameraSubject = selectedTower:FindFirstChild("HumanoidRootPart", true)
			for i, v in game.Workspace.CurrentCamera:GetDescendants() do
				if v:IsA("BasePart") then
					cameraPartTransparencies[v] = v.Transparency
					v.Transparency = 1
				elseif v:IsA("ImageLabel") then
					cameraPartTransparencies[v] = v.ImageTransparency
					v.ImageTransparency = 1
				elseif v:IsA("Beam") then
					cameraPartTransparencies[v] = v.Enabled
					v.Enabled = false
				end
			end
			IngameHud.Bottom.AmountMoney.Visible = false
			Upgrade.Visible = false
			IngameHud.Bottom.Slot.Visible = false
			local StopButton = playerguix:WaitForChild("NewUI"):WaitForChild("StopButton")
			StopButton.Visible = true
			StopButton.MouseButton1Click:Once(function()
				for i, v in cameraPartTransparencies do
					if i:IsA("BasePart") then
						i.Transparency = v
					elseif i:IsA("ImageLabel") then
						i.ImageTransparency = v
					elseif i:IsA("Beam") then
						i.Enabled = v
					end
				end
				IngameHud.Bottom.AmountMoney.Visible = true
				StopButton.Visible = false
				Upgrade.Visible = true
				IngameHud.Bottom.Slot.Visible = true
				local playerChr = player.Character or player.CharacterAdded:Wait()
				game.Workspace.CurrentCamera.CameraSubject = playerChr:WaitForChild("Humanoid")
			end)
		end
	end
end
local KeyBinds = {
	F = UpgradeFunc,
	X = SellFunc,
	R = TargetFunc,
	V = SpectateFunc,
	ButtonY = UpgradeFunc,
	DPadLeft = TargetFunc,
	DPadRight = SellFunc
}
local actions = {
	Upgrade = UpgradeFunc,
	Sell = SellFunc,
	Target = TargetFunc,
	Spectate = SpectateFunc,
}
local function setPlacementVFXEnabled(tower: Model, state)
	if state then
	else
	end
end
local function createHoverHighlight()
	lastHighlight = Instance.new("Highlight")
	lastHighlight.FillTransparency = 1
	lastHighlight.OutlineTransparency = 1
	lastHighlight.Parent = hoveredInstance.Parent
	TweenService:Create(lastHighlight, TweenInfo.new(1, Enum.EasingStyle.Exponential), {OutlineTransparency = 0.25}):Play()
	if hoveredInstance.Parent.Config.Type.Value == "Spawner" then
		for i, v in workspace:WaitForChild("Spawnables"):GetChildren() do
			if v:IsA("Model") then
				if v.OwnedBy.Value == hoveredInstance.Parent then
					local tempHighlight = Instance.new("Highlight")
					tempHighlight.FillTransparency = 1
					tempHighlight.OutlineTransparency = 1
					tempHighlight.Parent = v
					TweenService:Create(tempHighlight, TweenInfo.new(1, Enum.EasingStyle.Exponential), {OutlineTransparency = 0.25}):Play()
					lastHighlight:GetPropertyChangedSignal("Parent"):Once(function()
						tempHighlight:Destroy()
					end)
				end
			end
		end
	end
end
local function getAncestor(model, ancestor)
	local anc = model:FindFirstAncestor(ancestor)
	if anc then
		for _, child in ipairs(anc:GetChildren()) do
			if hoveredInstance:IsDescendantOf(child) then
				return child
			end
		end
	end
end
local function onKeyBindPress(input, processed)
	if processed or not Upgrade.Visible then return end
	for key, action in KeyBinds do
		if input.KeyCode == Enum.KeyCode[key] then
			action()
		end
	end
end
local function disconnectEndScreenConnections()
	for i = 1, #endScreenConnections do
		endScreenConnections[i]:Disconnect()
	end
	table.clear(endScreenConnections)
end
local function hideAllEndScreens()
	FailedScreen.Visible = false
	VictoryScreen.Visible = false
	activeEndScreen = nil
end
local function getNumberFromSources(sources, names)
	for _, source in sources do
		if source then
			for _, name in names do
				local attr = source:GetAttribute(name)
				if typeof(attr) == "number" then
					return attr
				end
				local child = source:FindFirstChild(name)
				if child and child:IsA("ValueBase") and typeof(child.Value) == "number" then
					return child.Value
				end
			end
		end
	end
	return 0
end
local function getEndScreenTitle()
	local worldValue = StoryModeStats.Worlds[info.World.Value]
	if info.Raid.Value then
		worldValue = info.WorldString.Value
	end
	if worldValue and worldValue ~= "" then
		return worldValue
	end
	if info:FindFirstChild("WorldString") and info.WorldString.Value ~= "" then
		return info.WorldString.Value
	end
	return "Destroyed Kamino"
end
local function getEndScreenActText()
	if info.Infinity.Value then
		return "Infinity / Hard"
	end
	if info.Raid.Value then
		return "Act " .. info.Level.Value .. " / Raid"
	end
	if info.Event.Value then
		return "Event"
	end
	if info.ChallengeNumber.Value > 0 then
		local challengeData = ChallengeModule.Data[info.ChallengeNumber.Value]
		local challengeName = if challengeData then challengeData.Name else "Challenge"
		return "Act " .. info.Level.Value .. " / " .. challengeName
	end
	local modeName = "Normal"
	if info.Mode.Value == 2 then
		modeName = "Hard"
	end
	return "Act " .. info.Level.Value .. " / " .. modeName
end
local function updateWaveDisplays(currentWave)
	local waveText = "Wave " .. tostring(currentWave)
	local waveLabel = IngameHud.Top:FindFirstChild("WaveLabel")
	if waveLabel then
		waveLabel.Text = waveText
	end
	local versusHealth = IngameHud.Top:FindFirstChild("VersusHealth")
	if versusHealth and versusHealth:FindFirstChild("Wave") then
		versusHealth.Wave.Text = waveText
	end
	local textWave = IngameHud.Top:FindFirstChild("TextWave")
	if textWave then
		textWave.Text = waveText
	end
end
local function getResultScreen(status)
	local isVictory = info.Victory.Value or status == "VICTORY"
	if info.Versus.Value and player.Team then
		isVictory = player.Team.Name == info.WinningTeam.Value
	end
	return if isVictory then VictoryScreen else FailedScreen, isVictory
end
local function getActiveEndScreen()
	if activeEndScreen then
		return activeEndScreen
	end
	return if info.Victory.Value then VictoryScreen else FailedScreen
end
local function setEndScreenDetail(slot, labelText, amountText)
	if not slot then return end
	local textLabel = slot:FindFirstChild("Text")
	local amountLabel = slot:FindFirstChild("Amount")
	if textLabel and textLabel:IsA("TextLabel") then
		textLabel.Text = labelText
	end
	if amountLabel and amountLabel:IsA("TextLabel") then
		amountLabel.Text = amountText
	end
end
local function setEndScreenButtonText(buttonFrame, value)
	if not buttonFrame then return end
	local textLabel = buttonFrame:FindFirstChild("Text")
	if textLabel and textLabel:IsA("TextLabel") then
		textLabel.Text = value
	end
end
local function setEndScreenButtonVisible(buttonFrame, value)
	if not buttonFrame then return end
	if buttonFrame:IsA("GuiObject") then
		buttonFrame.Visible = value
	end
end
local function connectEndScreenButton(buttonFrame, callback)
	if not buttonFrame then return end
	local button = buttonFrame:FindFirstChild("Btn")
	if button and button:IsA("GuiButton") then
		endScreenConnections[#endScreenConnections + 1] = button.Activated:Connect(callback)
	elseif buttonFrame:IsA("GuiButton") then
		endScreenConnections[#endScreenConnections + 1] = buttonFrame.Activated:Connect(callback)
	end
end
local function createFlatNumberSequence(value)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, value),
		NumberSequenceKeypoint.new(1, value)
	})
end
local function tweenGradientTransparency(gradient, fromValue, toValue, duration)
	if not gradient or not gradient:IsA("UIGradient") then
		return
	end
	local proxy = Instance.new("NumberValue")
	local connection
	gradient.Transparency = createFlatNumberSequence(fromValue)
	connection = proxy:GetPropertyChangedSignal("Value"):Connect(function()
		gradient.Transparency = createFlatNumberSequence(proxy.Value)
	end)
	proxy.Value = fromValue
	local tween = TweenService:Create(proxy, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Value = toValue
	})
	tween.Completed:Once(function()
		if connection then
			connection:Disconnect()
		end
		proxy:Destroy()
		gradient.Transparency = createFlatNumberSequence(toValue)
	end)
	tween:Play()
end
local function getRewardSlots(screen)
	local rewardsFrame = screen.Main.Content:FindFirstChild("Rewards")
	if not rewardsFrame then
		return nil, {}
	end
	local slotsFolder = rewardsFrame:FindFirstChild("Slots")
	if not slotsFolder then
		return rewardsFrame, {}
	end
	local slots = {}
	for _, child in slotsFolder:GetChildren() do
		if child:IsA("GuiObject") and tonumber(child.Name) then
			slots[#slots + 1] = child
		end
	end
	table.sort(slots, function(a, b)
		return (tonumber(a.Name) or 0) < (tonumber(b.Name) or 0)
	end)
	return rewardsFrame, slots
end
local function getProgressSlots(screen)
	local progressFrame = screen.Main.Content:FindFirstChild("Progress")
	if not progressFrame then
		return nil, {}
	end
	local content = progressFrame:FindFirstChild("Content")
	if not content then
		return progressFrame, {}
	end
	local slots = {}
	for _, child in content:GetChildren() do
		if child:IsA("GuiObject") and tonumber(child.Name) then
			slots[#slots + 1] = child
		end
	end
	table.sort(slots, function(a, b)
		return (tonumber(a.Name) or 0) < (tonumber(b.Name) or 0)
	end)
	return progressFrame, slots
end
local function applyGradientSequence(target, colorSequence)
	if not target or not colorSequence then
		return
	end
	local gradient = target:FindFirstChild("UIGradient")
	if gradient and gradient:IsA("UIGradient") then
		gradient.Color = colorSequence
	end
	local stroke = target:FindFirstChildWhichIsA("UIStroke")
	if stroke then
		local strokeGradient = stroke:FindFirstChild("UIGradient")
		if strokeGradient and strokeGradient:IsA("UIGradient") then
			strokeGradient.Color = colorSequence
		else
			stroke.Color = colorSequence.Keypoints[1].Value
		end
	end
end
local function applyCardRarity(card, rarity)
	local gradientObject = rarity and UnitGradients:FindFirstChild(rarity)
	if not gradientObject then
		return
	end
	applyGradientSequence(card, gradientObject.Color)
	local bg = card:FindFirstChild("Bg")
	if bg then
		applyGradientSequence(bg, gradientObject.Color)
	end
	local profile = card:FindFirstChild("Profile")
	if profile then
		local profileBg = profile:FindFirstChild("Bg")
		local profileShadow = profile:FindFirstChild("Shadow")
		if profileBg then
			applyGradientSequence(profileBg, gradientObject.Color)
		end
		if profileShadow then
			applyGradientSequence(profileShadow, gradientObject.Color)
		end
	end
	local bar = card:FindFirstChild("Bar")
	if bar then
		local fill = bar:FindFirstChild("Fill")
		if fill then
			applyGradientSequence(fill, gradientObject.Color)
		end
	end
end
local function getTableField(tbl, names)
	if type(tbl) ~= "table" then
		return nil
	end
	for _, name in names do
		local value = tbl[name]
		if value ~= nil then
			return value
		end
	end
	return nil
end
local function getTableNumber(tbl, names)
	local value = getTableField(tbl, names)
	if type(value) == "number" then
		return value
	end
	return nil
end
local function getTableString(tbl, names)
	local value = getTableField(tbl, names)
	if type(value) == "string" then
		return value
	end
	return nil
end
local function getTableBoolean(tbl, names)
	local value = getTableField(tbl, names)
	if type(value) == "boolean" then
		return value
	end
	return nil
end
local function getValueFromInstance(source, names)
	if not source or typeof(source) ~= "Instance" then
		return nil
	end
	for _, name in names do
		local attr = source:GetAttribute(name)
		if attr ~= nil then
			return attr
		end
		local child = source:FindFirstChild(name)
		if child and child:IsA("ValueBase") then
			return child.Value
		end
	end
	return nil
end
local function getNumberFromInstance(source, names)
	local value = getValueFromInstance(source, names)
	if type(value) == "number" then
		return value
	end
	return nil
end
local function getBooleanFromInstance(source, names)
	local value = getValueFromInstance(source, names)
	if type(value) == "boolean" then
		return value
	end
	return nil
end
local function getStringFromInstance(source, names)
	local value = getValueFromInstance(source, names)
	if type(value) == "string" then
		return value
	end
	return nil
end
local function findOwnedTowerByName(towerName)
	if not towerName or towerName == "" then
		return nil
	end
	for _, ownedTower in player.OwnedTowers:GetChildren() do
		if ownedTower.Name == towerName then
			return ownedTower
		end
	end
	return nil
end
local function getRewardItemImage(itemStats)
	if type(itemStats) ~= "table" then
		return nil
	end
	for _, fieldName in {"Image", "ImageId", "ImageID", "Icon", "IconId", "IconID", "AssetId", "AssetID"} do
		local value = itemStats[fieldName]
		if type(value) == "number" then
			return "rbxassetid://" .. tostring(value)
		elseif type(value) == "string" then
			if string.find(value, "rbxassetid://") then
				return value
			end
			if tonumber(value) then
				return "rbxassetid://" .. value
			end
			return value
		end
	end
	return nil
end
local function getRewardSlotText(slot)
	local nameLabel = slot:FindFirstChild("Name", true)
	local amountLabel = slot:FindFirstChild("Amount", true) or slot:FindFirstChild("Price", true) or slot:FindFirstChild("Cost", true)
	return nameLabel, amountLabel
end
local function getRewardSlotVisuals(slot)
	local placeholder = slot:FindFirstChild("Placeholder", true)
	local imageLabel = slot:FindFirstChild("ImageLabel", true)
	return placeholder, imageLabel
end
local function clearRewardSlot(slot)
	local nameLabel, amountLabel = getRewardSlotText(slot)
	local placeholder, imageLabel = getRewardSlotVisuals(slot)
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = ""
	end
	if amountLabel and amountLabel:IsA("TextLabel") then
		amountLabel.Text = ""
	end
	if placeholder then
		for _, child in placeholder:GetChildren() do
			if child:IsA("ViewportFrame") then
				child:Destroy()
			end
		end
	end
	if imageLabel and imageLabel:IsA("ImageLabel") then
		imageLabel.Image = ""
		imageLabel.Visible = false
	end
	slot.Visible = false
end
local function buildRewardEntries(rewards)
	local entries = {}
	if not rewards then
		return entries
	end
	if rewards.OwnedTowers then
		for _, tower in rewards.OwnedTowers do
			local towerStats = upgradesModule[tower.Name]
			local baseCost = 0
			if towerStats and towerStats.Upgrades and towerStats.Upgrades[1] then
				baseCost = towerStats.Upgrades[1].Price
			end
			entries[#entries + 1] = {
				kind = "Tower",
				name = tower.Name,
				secondaryText = "$" .. tostring(baseCost),
				rarity = getUnitRarity(tower.Name),
				shiny = tower:GetAttribute("Shiny") == true
			}
		end
	end
	if rewards.Tower and rewards.Tower.unit then
		local tower = rewards.Tower.unit
		local towerStats = upgradesModule[tower.Name]
		local baseCost = 0
		if towerStats and towerStats.Upgrades and towerStats.Upgrades[1] then
			baseCost = towerStats.Upgrades[1].Price
		end
		entries[#entries + 1] = {
			kind = "Tower",
			name = tower.Name,
			secondaryText = "$" .. tostring(baseCost),
			rarity = getUnitRarity(tower.Name),
			shiny = tower:GetAttribute("Shiny") == true
		}
	end
	if rewards.Items then
		for itemName, quantity in rewards.Items do
			if quantity > 0 then
				local itemStats = itemModule[itemName]
				local rarity = if itemStats and itemStats.Rarity then itemStats.Rarity else nil
				entries[#entries + 1] = {
					kind = "Item",
					name = itemName,
					secondaryText = "x" .. tostring(quantity),
					rarity = rarity,
					image = getRewardItemImage(itemStats)
				}
			end
		end
	end
	for rewardName, amount in rewards do
		if rewardName ~= "Items" and rewardName ~= "OwnedTowers" and rewardName ~= "Tower" and rewardName ~= "CompReward" and rewardName ~= "TowerXP" and rewardName ~= "TowerExp" and rewardName ~= "UnitXP" and rewardName ~= "UnitExp" and rewardName ~= "XPProgress" and rewardName ~= "PlacedTowerXP" and rewardName ~= "PlacedUnitXP" and rewardName ~= "Progress" and rewardName ~= "PlayerXP" and rewardName ~= "PlayerExp" and rewardName ~= "XP" and rewardName ~= "Exp" and rewardName ~= "Experience" then
			if type(amount) == "number" and amount > 0 then
				entries[#entries + 1] = {
					kind = "Currency",
					name = rewardName,
					secondaryText = "x" .. tostring(amount)
				}
			end
		end
	end
	return entries
end
local function configureRewardSlot(slot, entry)
	clearRewardSlot(slot)
	local nameLabel, amountLabel = getRewardSlotText(slot)
	local placeholder, imageLabel = getRewardSlotVisuals(slot)
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = entry.name or ""
	end
	if amountLabel and amountLabel:IsA("TextLabel") then
		amountLabel.Text = entry.secondaryText or ""
	end
	if entry.rarity then
		applyCardRarity(slot, entry.rarity)
	end
	if entry.kind == "Tower" and entry.name and placeholder then
		local viewport = ViewPortModule.CreateViewPort(entry.name, entry.shiny == true)
		viewport.Size = UDim2.fromScale(1, 1)
		viewport.Name = entry.name
		viewport.Parent = placeholder
	elseif entry.image and imageLabel and imageLabel:IsA("ImageLabel") then
		imageLabel.Image = tostring(entry.image)
		imageLabel.Visible = true
	end
	slot.Visible = true
end
local function clearEndScreenRewards(screen)
	local _, slots = getRewardSlots(screen)
	for _, slot in slots do
		clearRewardSlot(slot)
	end
end
local function updateEndScreenRewards(screen, rewards)
	local _, slots = getRewardSlots(screen)
	local entries = buildRewardEntries(rewards)
	for _, slot in slots do
		clearRewardSlot(slot)
	end
	if #entries <= 0 then
		return
	end
	for index = 1, math.min(#slots, #entries) do
		configureRewardSlot(slots[index], entries[index])
	end
end
local function normalizeProgressEntry(rawEntry, fallbackName)
	local tower = nil
	if typeof(rawEntry) == "Instance" then
		tower = rawEntry
	elseif type(rawEntry) == "table" then
		for _, fieldName in {"Tower", "Unit", "TowerInstance", "UnitInstance", "OwnedTower", "Instance", "Object"} do
			local candidate = rawEntry[fieldName]
			if typeof(candidate) == "Instance" then
				tower = candidate
				break
			end
		end
	end
	local towerName = fallbackName
	if not towerName and type(rawEntry) == "table" then
		towerName = getTableString(rawEntry, {"TowerName", "UnitName", "Name", "Class"})
	end
	if not towerName and tower then
		towerName = tower.Name
	end
	if not towerName or towerName == "" then
		return nil
	end
	local ownedTower = tower or findOwnedTowerByName(towerName)
	local rarity = if type(rawEntry) == "table" then getTableString(rawEntry, {"Rarity"}) else nil
	local gainedXP = if type(rawEntry) == "table" then getTableNumber(rawEntry, {"GainedXP", "RewardedXP", "AddedXP", "XP", "Exp", "Amount"}) else nil
	local currentLevel = if type(rawEntry) == "table" then getTableNumber(rawEntry, {"Level", "TowerLevel", "CurrentLevel"}) else nil
	local currentXP = if type(rawEntry) == "table" then getTableNumber(rawEntry, {"CurrentXP", "CurrentExp", "XPNow", "ExpNow"}) else nil
	local requiredXP = if type(rawEntry) == "table" then getTableNumber(rawEntry, {"RequiredXP", "NeededXP", "NextLevelXP", "MaxXP", "GoalXP"}) else nil
	local shiny = if type(rawEntry) == "table" then getTableBoolean(rawEntry, {"Shiny"}) else nil
	if not rarity then
		rarity = getUnitRarity(towerName)
	end
	if currentLevel == nil and ownedTower then
		currentLevel = getNumberFromInstance(ownedTower, {"Level", "TowerLevel", "CurrentLevel"})
	end
	if currentXP == nil and ownedTower then
		currentXP = getNumberFromInstance(ownedTower, {"CurrentXP", "CurrentExp", "XP", "Exp", "Experience"})
	end
	if requiredXP == nil and ownedTower then
		requiredXP = getNumberFromInstance(ownedTower, {"RequiredXP", "NeededXP", "NextLevelXP", "MaxXP"})
	end
	if shiny == nil and ownedTower then
		shiny = getBooleanFromInstance(ownedTower, {"Shiny"})
	end
	if currentLevel == nil then
		currentLevel = 1
	end
	if currentXP == nil then
		currentXP = 0
	end
	if requiredXP == nil or requiredXP <= 0 then
		requiredXP = math.max(currentXP, 1)
	end
	if gainedXP == nil then
		gainedXP = 0
	end
	return {
		name = towerName,
		rarity = rarity or "Common",
		level = currentLevel,
		currentXP = currentXP,
		requiredXP = requiredXP,
		gainedXP = gainedXP,
		shiny = shiny == true
	}
end
local function appendProgressEntries(source, entries)
	if not source then
		return
	end
	if typeof(source) == "Instance" then
		local normalized = normalizeProgressEntry(source)
		if normalized then
			entries[#entries + 1] = normalized
		end
		return
	end
	if type(source) ~= "table" then
		return
	end
	local singleEntry = normalizeProgressEntry(source)
	if singleEntry and source.Name then
		entries[#entries + 1] = singleEntry
		return
	end
	for key, value in source do
		if typeof(value) == "Instance" or type(value) == "table" then
			local fallbackName = if type(key) == "string" then key else nil
			local normalized = normalizeProgressEntry(value, fallbackName)
			if normalized then
				entries[#entries + 1] = normalized
			end
		elseif type(value) == "number" and type(key) == "string" then
			local normalized = normalizeProgressEntry({
				Name = key,
				GainedXP = value
			})
			if normalized then
				entries[#entries + 1] = normalized
			end
		end
	end
end
local function getPlayerProgressGainedXP(rewards)
	local gainedXP = nil
	if type(rewards) == "table" then
		gainedXP = getTableNumber(rewards, {"PlayerXP", "PlayerExp", "XP", "Exp", "Experience", "XPGained"})
	end
	if gainedXP == nil then
		local playerXPAttribute = player:GetAttribute("PlayerXP")
		if type(playerXPAttribute) == "number" then
			gainedXP = playerXPAttribute
		end
	end
	if gainedXP == nil then
		gainedXP = 0
	end
	return gainedXP
end

local function getPlayerProgressImage()
	local success, image = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	end)
	if success and type(image) == "string" then
		return image
	end
	return ""
end

local function getPlayerProgressStartState(currentLevel, currentXP, gainedXP)
	local previousLevel = currentLevel
	local previousXP = currentXP
	local remainingXP = math.max(math.floor(gainedXP or 0), 0)
	while remainingXP > 0 do
		if previousXP >= remainingXP then
			previousXP -= remainingXP
			remainingXP = 0
		elseif previousLevel > 1 then
			remainingXP -= previousXP
			previousLevel -= 1
			local previousRequiredXP = ExpModule.playerExpCalculation(previousLevel)
			if type(previousRequiredXP) ~= "number" or previousRequiredXP < 0 then
				previousRequiredXP = 0
			end
			previousXP = previousRequiredXP
		else
			previousXP = 0
			remainingXP = 0
		end
	end
	return previousLevel, previousXP
end

local function getProgressBarObjects(slot)
	local barFrame = slot:FindFirstChild("Bar")
	if not barFrame then
		return nil, nil, nil, nil, nil
	end
	local nestedBar = barFrame:FindFirstChild("Bar")
	local targetBar = nil
	local fill = nil
	local textLabel = nil
	local levelGainLabel = nil
	if nestedBar and nestedBar:IsA("GuiObject") then
		fill = nestedBar:FindFirstChild("Fill")
		textLabel = nestedBar:FindFirstChild("Text")
		levelGainLabel = nestedBar:FindFirstChild("Lvl")
		if fill and fill:IsA("GuiObject") then
			targetBar = nestedBar
		end
	end
	if not targetBar then
		fill = barFrame:FindFirstChild("Fill")
		textLabel = barFrame:FindFirstChild("Text")
		levelGainLabel = barFrame:FindFirstChild("Lvl")
		if fill and fill:IsA("GuiObject") then
			targetBar = barFrame
		end
	end
	local gradient = nil
	if fill and fill:IsA("GuiObject") then
		gradient = fill:FindFirstChild("UIGradient")
		if not gradient and targetBar then
			gradient = targetBar:FindFirstChild("UIGradient")
		end
	end
	return barFrame, targetBar, fill, textLabel, levelGainLabel, gradient
end

local function buildProgressEntries(rewards)
	local playerLevelValue = player:FindFirstChild("PlayerLevel")
	local playerExpValue = player:FindFirstChild("PlayerExp")
	if not playerLevelValue or not playerExpValue then
		return {}
	end
	local currentLevel = playerLevelValue.Value
	local currentXP = playerExpValue.Value
	local requiredXP = ExpModule.playerExpCalculation(currentLevel)
	if type(requiredXP) ~= "number" or requiredXP <= 0 then
		requiredXP = math.max(currentXP, 1)
	end
	local gainedXP = getPlayerProgressGainedXP(rewards)
	local previousLevel = getPlayerProgressStartState(currentLevel, currentXP, gainedXP)
	local levelGain = math.max(currentLevel - previousLevel, 0)
	return {{
		name = if player.DisplayName ~= "" then player.DisplayName else player.Name,
		rarity = "Player XP",
		level = currentLevel,
		currentXP = currentXP,
		requiredXP = requiredXP,
		gainedXP = gainedXP,
		levelGain = levelGain,
		image = getPlayerProgressImage()
	}}
end

local function clearProgressSlot(slot)
	if not slot then
		return
	end
	local profile = slot:FindFirstChild("Profile")
	if profile then
		if profile:FindFirstChild("Lvl") then
			profile.Lvl.Text = ""
		end
		local imageLabel = profile:FindFirstChild("ImageLabel")
		if imageLabel and imageLabel:IsA("ImageLabel") then
			imageLabel.Image = ""
			imageLabel.Visible = false
		end
	end
	local classLabel = slot:FindFirstChild("Class")
	if classLabel and classLabel:IsA("TextLabel") then
		classLabel.Text = ""
	end
	local rarityLabel = slot:FindFirstChild("Rarity")
	if rarityLabel and rarityLabel:IsA("TextLabel") then
		rarityLabel.Text = ""
	end
	local _, _, fill, textLabel, levelGainLabel, gradient = getProgressBarObjects(slot)
	if textLabel and textLabel:IsA("TextLabel") then
		textLabel.Text = ""
	end
	if levelGainLabel and levelGainLabel:IsA("TextLabel") then
		levelGainLabel.Text = ""
		levelGainLabel.Visible = false
	end
	if fill and fill:IsA("GuiObject") then
		fill.Size = UDim2.fromScale(0, 1)
	end
	if gradient and gradient:IsA("UIGradient") then
		gradient.Transparency = createFlatNumberSequence(1)
	end
	slot.Visible = false
end

local function animateProgressSlot(slot, entry, order)
	local _, _, fill, _, _, gradient = getProgressBarObjects(slot)
	if not fill or not fill:IsA("GuiObject") then
		return
	end
	local ratio = math.clamp(entry.currentXP / math.max(entry.requiredXP, 1), 0, 1)
	fill.Size = UDim2.fromScale(0, 1)
	if gradient and gradient:IsA("UIGradient") then
		tweenGradientTransparency(gradient, 1, 0, 0.45)
	end
	task.delay(0.08 * (order - 1), function()
		TweenService:Create(fill, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(ratio, 1)
		}):Play()
	end)
end

local function updateEndScreenProgress(screen, rewards)
	local _, slots = getProgressSlots(screen)
	local entries = buildProgressEntries(rewards)
	for _, slot in slots do
		clearProgressSlot(slot)
	end
	if #entries <= 0 then
		return
	end
	for index = 1, math.min(#slots, #entries) do
		local slot = slots[index]
		local entry = entries[index]
		local profile = slot:FindFirstChild("Profile")
		local classLabel = slot:FindFirstChild("Class")
		local rarityLabel = slot:FindFirstChild("Rarity")
		local _, _, _, textLabel, levelGainLabel = getProgressBarObjects(slot)
		if profile then
			if profile:FindFirstChild("Lvl") then
				profile.Lvl.Text = "Level " .. tostring(entry.level)
			end
			local imageLabel = profile:FindFirstChild("ImageLabel")
			if imageLabel and imageLabel:IsA("ImageLabel") then
				imageLabel.Image = entry.image or ""
				imageLabel.Visible = (entry.image or "") ~= ""
			end
		end
		if classLabel and classLabel:IsA("TextLabel") then
			classLabel.Text = entry.name
		end
		if rarityLabel and rarityLabel:IsA("TextLabel") then
			rarityLabel.Text = entry.rarity
		end
		if textLabel and textLabel:IsA("TextLabel") then
			textLabel.Text = "Level " .. tostring(entry.level) .. " (" .. tostring(entry.currentXP) .. "/" .. tostring(entry.requiredXP) .. ")"
		end
		if levelGainLabel and levelGainLabel:IsA("TextLabel") then
			if entry.levelGain > 0 then
				levelGainLabel.Text = "+" .. tostring(entry.levelGain)
				levelGainLabel.Visible = true
			else
				levelGainLabel.Text = ""
				levelGainLabel.Visible = false
			end
		end
		slot.Visible = true
		animateProgressSlot(slot, entry, index)
	end
end

local function playEndScreenOpenAnimation(screen)

	local main = screen:FindFirstChild("Main")
	local header = screen:FindFirstChild("Header")
	if main then
		local mainScale = main:FindFirstChild("OpenScale")
		if not mainScale then
			mainScale = Instance.new("UIScale")
			mainScale.Name = "OpenScale"
			mainScale.Parent = main
		end
		local mainPosition = main.Position
		mainScale.Scale = 0.9
		main.Position = mainPosition + UDim2.fromScale(0, 0.04)
		TweenService:Create(mainScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1
		}):Play()
		TweenService:Create(main, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = mainPosition
		}):Play()
	end
	if header then
		local headerScale = header:FindFirstChild("OpenScale")
		if not headerScale then
			headerScale = Instance.new("UIScale")
			headerScale.Name = "OpenScale"
			headerScale.Parent = header
		end
		local headerPosition = header.Position
		headerScale.Scale = 0.92
		header.Position = headerPosition + UDim2.fromScale(0, -0.025)
		TweenService:Create(headerScale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1
		}):Play()
		TweenService:Create(header, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = headerPosition
		}):Play()
	end
end
local function showEndScreen(screen)
	EndScreenGUIDisable(false)
	if workspace.CurrentCamera:FindFirstChild("Blur") then
		workspace.CurrentCamera.Blur:Destroy()
	end
	local blurEffect = Instance.new("BlurEffect")
	blurEffect.Name = "Blur"
	blurEffect.Parent = workspace.CurrentCamera
	blurEffect.Size = 0
	blurEffect.Enabled = true
	TweenService:Create(blurEffect, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = 16
	}):Play()
	screen.Visible = true
	playEndScreenOpenAnimation(screen)
end
local function setupEndScreen(screen, status, rewards)
	disconnectEndScreenConnections()
	hideAllEndScreens()
	activeEndScreen = screen
	local leftInfo = screen.Main.Content:FindFirstChild("Leftinfo")
	if leftInfo then
		if leftInfo:FindFirstChild("Title") then
			leftInfo.Title.Text = getEndScreenTitle()
		end
		if leftInfo:FindFirstChild("Act") then
			leftInfo.Act.Text = getEndScreenActText()
		end
		local details = leftInfo:FindFirstChild("Details")
		if details then
			local takedowns = getNumberFromSources({player, info}, {"Takedowns", "TakeDowns", "Kills", "Eliminations"})
			local moneyEarned = getNumberFromSources({player, info}, {"MoneyEarned", "EarnedMoney", "TotalMoneyEarned", "CashEarned"})
			if moneyEarned <= 0 then
				moneyEarned = playerMoney.Value
			end
			setEndScreenDetail(details:FindFirstChild("1"), "Units Placed:", tostring(placedTowers))
			setEndScreenDetail(details:FindFirstChild("2"), "Total Damage:", tostring(player.Damage.Value))
			setEndScreenDetail(details:FindFirstChild("3"), "Play Time:", formatTime(tick() - _G.Timestarted))
			setEndScreenDetail(details:FindFirstChild("4"), "Takedowns:", tostring(takedowns))
			setEndScreenDetail(details:FindFirstChild("5"), "Money Earned:", tostring(moneyEarned))
		end
	end
	updateEndScreenRewards(screen, rewards)
	updateEndScreenProgress(screen, rewards)
	local buttons = screen.Main.Content:FindFirstChild("Buttons")
	local nextButton = if buttons then buttons:FindFirstChild("1") else nil
	local replayButton = if buttons then buttons:FindFirstChild("2") else nil
	local lobbyButton = if buttons then buttons:FindFirstChild("3") else nil
	setEndScreenButtonText(nextButton, "Next")
	setEndScreenButtonText(replayButton, "Replay")
	setEndScreenButtonText(lobbyButton, "Back To Lobby")
	local canShowNext = status ~= "GAME OVER" and not info.Event.Value and not info.Versus.Value and info.ChallengeNumber.Value < 0
	local canShowReplay = not info.Versus.Value
	if info.ChallengeNumber.Value > 0 then
		canShowNext = false
		canShowReplay = true
	end
	setEndScreenButtonVisible(nextButton, canShowNext)
	setEndScreenButtonVisible(replayButton, canShowReplay)
	setEndScreenButtonVisible(lobbyButton, true)
	local eventsLocal = ReplicatedStorage:WaitForChild("Events")
	local exitEvent = eventsLocal:WaitForChild("ExitGame")
	local clicked = false
	connectEndScreenButton(lobbyButton, function()
		if clicked then
			return
		end
		clicked = true
		exitEvent:FireServer("Return")
		if workspace.CurrentCamera:FindFirstChild("Blur") then
			workspace.CurrentCamera.Blur:Destroy()
		end
		hideAllEndScreens()
		EndScreenGUIDisable(true)
	end)
	connectEndScreenButton(replayButton, function()
		if clicked then
			return
		end
		clicked = true
		exitEvent:FireServer("Replay")
		if workspace.CurrentCamera:FindFirstChild("Blur") then
			workspace.CurrentCamera.Blur:Destroy()
		end
		hideAllEndScreens()
		EndScreenGUIDisable(true)
	end)
	if canShowNext then
		connectEndScreenButton(nextButton, function()
			if clicked then
				return
			end
			clicked = true
			exitEvent:FireServer("Next")
			if workspace.CurrentCamera:FindFirstChild("Blur") then
				workspace.CurrentCamera.Blur:Destroy()
			end
			hideAllEndScreens()
			EndScreenGUIDisable(true)
		end)
	end
	if screen:FindFirstChild("Closebtn") and screen.Closebtn:IsA("GuiButton") then
		endScreenConnections[#endScreenConnections + 1] = screen.Closebtn.Activated:Connect(function()
			if workspace.CurrentCamera:FindFirstChild("Blur") then
				workspace.CurrentCamera.Blur:Destroy()
			end
			hideAllEndScreens()
			EndScreenGUIDisable(true)
		end)
	end
end
local function DisplayEndScreen(status)
	local endScreen = getResultScreen(status)
	setupEndScreen(endScreen, status, nil)
	task.wait(1)
	if gui.Parent:FindFirstChild("HatchInfo") then
		return
	end
	showEndScreen(endScreen)
end
local function SetupGameGui()
	if not info.GameRunning.Value then return end
	task.spawn(function()
		TweenService:Create(SkipUI, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Position = UDim2.fromScale(0.5, -0.5)}):Play()
		task.wait(0.2)
		SkipUI.Visible = false
	end)
	local map = workspace.Map:FindFirstChildOfClass("Folder") or workspace
	local HealthFrame = IngameHud.Top.HealthBar
	local VersusHealth = IngameHud.Top:FindFirstChild("VersusHealth")
	local SpeedBtn = IngameHud.Top.Speed
	if not info.Versus.Value and not info.Competitive.Value then
		HealthFrame.Visible = true
		SpeedBtn.Visible = true
		if VersusHealth then VersusHealth.Visible = false end
		map:WaitForChild("Base").Humanoid.HealthChanged:Connect(function()
			HealthFrame.TextHealth.Text = "Health: " .. tostring(map:WaitForChild("Base").Humanoid.Health .. "/" .. map:WaitForChild("Base").Humanoid.MaxHealth)
			TweenService:Create(HealthFrame.Fill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.fromScale(math.clamp(map:WaitForChild("Base").Humanoid.Health / map:WaitForChild("Base").Humanoid.MaxHealth, 0, 1), 1)}):Play()
		end)
		HealthFrame.TextHealth.Text = "Health: " .. tostring(map:WaitForChild("Base").Humanoid.Health .. "/" .. map:WaitForChild("Base").Humanoid.MaxHealth)
		TweenService:Create(HealthFrame.Fill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.fromScale(math.clamp(map:WaitForChild("Base").Humanoid.Health / map:WaitForChild("Base").Humanoid.MaxHealth, 0, 1), 1)}):Play()
	else
		warn("[Game Controller] Awaiting for versus UI to be scripted sir")
		HealthFrame.Visible = false
		SpeedBtn.Visible = false
		if VersusHealth then
			VersusHealth.Visible = true
			local RedBase = map:WaitForChild("RedBase") :: Model
			local BlueBase = map:WaitForChild("BlueBase") :: Model
			local RedHumanoid = RedBase:WaitForChild("Humanoid") :: Humanoid
			local BlueHumanoid = BlueBase:WaitForChild("Humanoid") :: Humanoid
			local function updateRedHealth()
				VersusHealth["Red"].Bar.Front.Size = UDim2.fromScale(math.clamp(RedHumanoid.Health / RedHumanoid.MaxHealth, 0, 1), 1)
				VersusHealth["Red"].Bar.NumberDisplay.Text = `Health: {RedHumanoid.Health}/{RedHumanoid.MaxHealth}`
			end
			local function updateBlueHealth()
				VersusHealth["Blue"].Bar.Front.Size = UDim2.fromScale(math.clamp(BlueHumanoid.Health / BlueHumanoid.MaxHealth, 0, 1), 1)
				VersusHealth["Blue"].Bar.NumberDisplay.Text = `Health: {BlueHumanoid.Health}/{BlueHumanoid.MaxHealth}`
			end
			RedHumanoid.HealthChanged:Connect(updateRedHealth)
			BlueHumanoid.HealthChanged:Connect(updateBlueHealth)
			updateRedHealth()
			updateBlueHealth()
		end
	end
	if workspace.Info.ChallengeNumber.Value == 9 then
		HealthFrame.TextHealth.Text = "Health: 1/100"
		HealthFrame.Fill.Size = UDim2.fromScale(1 / 100, 1)
	end
	UpdatePlayerLevelBar()
	playerMoney.Changed:Connect(function()
		IngameHud.Bottom.AmountMoney.Text = playerMoney.Value .. "$"
	end)
	IngameHud.Bottom.AmountMoney.Text = playerMoney.Value .. "$"
	for Key, _ in KeyBinds do
		for _, button in Upgrade:GetDescendants() do
			if button.Name == "InfoText" then
				if CheckIfPc() then
					button.TextXAlignment = "Left"
				else
					button.TextXAlignment = "Center"
				end
			end
			if button:FindFirstChild(Key) then
				if not CheckIfPc() then
					button[Key].Visible = false
				else
					button[Key].Visible = true
				end
			end
		end
	end
	local function stringToKeyCode(keyCodeString)
		local keyCode = Enum.KeyCode[keyCodeString]
		if keyCode then return keyCode end
		return nil
	end
	local function setupConsoleButton(consoleButton, imageLabel)
		if consoleButton:GetAttribute("Input") then
			local enumKeyCode = stringToKeyCode(consoleButton:GetAttribute("Input"))
			if not enumKeyCode then return end
			local mappedIcon = UserInputService:GetImageForKeyCode(enumKeyCode)
			if not mappedIcon then return end
			if imageLabel then
				imageLabel.Image = mappedIcon
				imageLabel.Visible = true
			else
				consoleButton.Image = mappedIcon
				if consoleButton:FindFirstChildOfClass("TextLabel") then
					consoleButton:FindFirstChildOfClass("TextLabel").Visible = false
				elseif consoleButton:FindFirstChildWhichIsA("ImageLabel") then
					consoleButton:FindFirstChildOfClass("ImageLabel").Visible = false
				end
			end
		end
	end
	if UserInputService.GamepadEnabled then
		for _, consoleButton in pairs(CollectionService:GetTagged("Controller")) do
			if consoleButton:FindFirstChild("TOOLBAR") then
				consoleButton.TOOLBAR.Visible = false
				local imageLabel = consoleButton:FindFirstChildWhichIsA("ImageLabel")
				if imageLabel then setupConsoleButton(consoleButton, imageLabel) end
			elseif consoleButton:FindFirstChild("DisplayBind") then
				consoleButton.DisplayBind.Visible = false
				local imageLabel = consoleButton:FindFirstChild("Controller")
				if imageLabel then setupConsoleButton(consoleButton, imageLabel) end
			else
				if consoleButton:IsA("ImageLabel") or consoleButton:IsA("ImageButton") then
					setupConsoleButton(consoleButton)
				end
			end
		end
	end
	task.delay(2, function()
		local EquippedTowers = {}
		for i, v in player.OwnedTowers:GetChildren() do
			if v:GetAttribute("Equipped") == true then
				if table.find(EquippedTowers, v) then continue end
				table.insert(EquippedTowers, v)
			end
		end
		for i = 1, 6 do
			local tower = EquippedTowers[i]
			local slot = getSlotByIndex(i)
			if not slot then continue end
			if tower then
				local rarity = getUnitRarity(tower.Name)
				if rarity == "Mythical" or rarity == "Secret" then
					slot:SetAttribute("Spinning", true)
				else
					slot:SetAttribute("Spinning", false)
				end
				local UnitRarity = upgradesModule[tower.Name].Rarity
				slot.Visible = true
				print(tower, rarity)
				local gradientRarity = ReplicatedStorage.Borders:FindFirstChild(rarity)
				if gradientRarity then
					if slot:FindFirstChild("Bg") then
						if slot.Bg:FindFirstChild("UIGradient") then
							slot.Bg.UIGradient.Color = gradientRarity.Color
						else
							slot.Bg.BackgroundColor3 = gradientRarity.Color.Keypoints[1].Value
						end
						local bgStroke = slot.Bg:FindFirstChildWhichIsA("UIStroke")
						if bgStroke then
							if bgStroke:FindFirstChild("UIGradient") then
								bgStroke.UIGradient.Color = gradientRarity.Color
							else
								bgStroke.Color = gradientRarity.Color.Keypoints[1].Value
							end
						end
					end
					local slotStroke = slot:FindFirstChildWhichIsA("UIStroke")
					if slotStroke then
						if slotStroke:FindFirstChild("UIGradient") then
							slotStroke.UIGradient.Color = gradientRarity.Color
						else
							slotStroke.Color = gradientRarity.Color.Keypoints[1].Value
						end
					end
				end
				if tower:GetAttribute("Trait") == "" or info.Versus.Value then
					if slot:FindFirstChild("TraitIcon") then
						slot.TraitIcon.Visible = false
					end
				else
					if slot:FindFirstChild("TraitIcon") then
						slot.TraitIcon.Visible = true
						slot.TraitIcon.Image = TraitsModule.Traits[tower:GetAttribute("Trait")].ImageID
						slot.TraitIcon.UIGradient.Color = TraitsModule.TraitColors[TraitsModule.Traits[tower:GetAttribute("Trait")].Rarity].Gradient
						slot.TraitIcon.UIGradient.Rotation = TraitsModule.TraitColors[TraitsModule.Traits[tower:GetAttribute("Trait")].Rarity].GradientAngle
					end
				end
				local priceMultiplier = 1
				if Traits.Traits[tower:GetAttribute("Trait")] and not info.Versus.Value then
					if Traits.Traits[tower:GetAttribute("Trait")]["Money"] then
						priceMultiplier = (1 - (Traits.Traits[tower:GetAttribute("Trait")]["Money"] / 100))
					end
				end
				if workspace.Info.ChallengeNumber.Value ~= -1 then
					local challengeData = ChallengeModule.Data[workspace.Info.ChallengeNumber.Value]
					if challengeData and challengeData.UnitStats ~= nil then
						priceMultiplier += (challengeData.UnitStats.Price / 100)
					end
				end
				slot.AmountCost.Text = math.round(upgradesModule[tower.Name].Upgrades[1].Price * priceMultiplier) .. "$"
				if info.Versus.Value then
					tower:SetAttribute("Level", 1)
				end
				local nameLabel = slot:FindFirstChild("Name")
				if nameLabel then
					nameLabel.Text = tower.Name
				end
				for _, child in slot.Placeholder:GetChildren() do
					if child:IsA("ViewportFrame") then child:Destroy() end
				end
				local vp = ViewPortModule.CreateViewPort(tower.Name, tower:GetAttribute("Shiny"))
				vp.Size = UDim2.fromScale(1, 1)
				vp.Name = tower.Name
				vp.Parent = slot.Placeholder
				slot.Activated:Connect(function()
					local allowedToSpawn = requestTowerFunction:InvokeServer(tower)
					if allowedToSpawn then
						createplacementbox()
						towerToSpawnValue = tower
						AddPlaceholderTower(tower.Name, tower)
					end
				end)
			else
				if slot:FindFirstChild("Backend") and slot.Backend:FindFirstChild("valEnabled") then
					slot.Backend.valEnabled.Value = false
				end
				local gray = Color3.fromRGB(100, 100, 100)
				local graySequence = ColorSequence.new{ColorSequenceKeypoint.new(0, gray), ColorSequenceKeypoint.new(1, gray)}
				if slot:FindFirstChild("Bg") then
					if slot.Bg:FindFirstChild("UIGradient") then
						slot.Bg.UIGradient.Color = graySequence
					else
						slot.Bg.BackgroundColor3 = gray
					end
					local bgStroke = slot.Bg:FindFirstChildWhichIsA("UIStroke")
					if bgStroke then
						if bgStroke:FindFirstChild("UIGradient") then
							bgStroke.UIGradient.Color = graySequence
						else
							bgStroke.Color = gray
						end
					end
				end
				local slotStroke = slot:FindFirstChildWhichIsA("UIStroke")
				if slotStroke then
					if slotStroke:FindFirstChild("UIGradient") then
						slotStroke.UIGradient.Color = graySequence
					else
						slotStroke.Color = gray
					end
				end
				if slot:FindFirstChild("TraitIcon") then
					slot.TraitIcon.Visible = false
				end
				if slot:FindFirstChild("Locked") then
					slot.Locked.Visible = false
				end
				local nameLabel = slot:FindFirstChild("Name")
				if nameLabel then nameLabel.Text = "" end
				slot.AmountCost.Text = ""
				if player.PlayerLevel.Value < requiredSlotLevel[i] then
					if slot:FindFirstChild("Locked") then
						slot.Locked.Visible = true
					end
				end
				local Empty = ViewPortModule.CreateEmptyPort()
				local existingVP = slot.Placeholder:FindFirstChildWhichIsA("ViewportFrame")
				if not existingVP then
					Empty:Clone().Parent = slot.Placeholder
				end
			end
		end
	end)
end
local function LoadGui()
	local gameOverd = false
	info.GameOver.Changed:Connect(function(val)
		if val and not gameOverd then
			gameOverd = true
			local change = "GAME OVER"
			if info.Victory.Value then
				change = "VICTORY"
			end
			DisplayEndScreen(change)
		end
	end)
	info.Message.Changed:Connect(function(change)
		if change ~= "" then
			if not string.find(change, "Wave") and not string.find(change, "Waiting") and not gameOverd then
				DisplayEndScreen(change)
			end
		end
	end)
	SetupGameGui()
	info.GameRunning.Changed:Connect(SetupGameGui)
end
-- INIT
repeat task.wait() until player:FindFirstChild("DataLoaded")
updateAbilityStatus()
AbilityStatus.Changed:Connect(updateAbilityStatus)
player.PlayerLevel.Changed:Connect(UpdatePlayerLevelBar)
player.PlayerExp.Changed:Connect(UpdatePlayerLevelBar)
updateWaveDisplays(info.Wave.Value)
info.Wave.Changed:Connect(updateWaveDisplays)
Upgrade:WaitForChild("Rightsection").Buttons.Upgrade.Btn.Activated:Connect(UpgradeFunc)
Upgrade:WaitForChild("Rightsection").Buttons.Sell.Btn.Activated:Connect(SellFunc)
Upgrade:WaitForChild("Rightsection").Buttons.Target.Btn.Activated:Connect(TargetFunc)
if Upgrade:FindFirstChild("Spectate") then
	Upgrade.Spectate.Activated:Connect(SpectateFunc)
end
UserInputService.InputBegan:Connect(onKeyBindPress)
SkipUI.Button.Yes.Btn.Activated:Connect(function()
	UIHandler.PlaySound("Skip")
	if not SkipUI.Visible then return end
	events.Client.VoteStartGame:FireServer()
	task.spawn(function()
		TweenService:Create(SkipUI, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Position = UDim2.new(0.438, 0, -0.5, 0)}):Play()
		task.wait(0.2)
		SkipUI.Visible = false
	end)
end)
SkipUI.Button.No.Btn.Activated:Connect(function()
	TweenService:Create(SkipUI, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Position = UDim2.new(0.438, 0, -0.5, 0)}):Play()
	task.wait(0.2)
	SkipUI.Visible = false
end)
local function updateSpeedText()
	local gamSped = workspace.Info.GameSpeed
	SpeedButton.TextSpeed.Text = "Speed: " .. gamSped.Value .. "x"
end
local function startCooldown()
	SpeedButton.Interactable = false
	for i = 3.2, 0, -0.1 do
		SpeedButton.TextSpeed.Text = string.format("Cooldown: %.1f", i)
		task.wait(0.1)
	end
	SpeedButton.Interactable = true
	updateSpeedText()
end
updateSpeedText()
workspace.Info.GameSpeed.Changed:Connect(startCooldown)
SpeedButton.Activated:Connect(function()
	if workspace.Info.SpeedCD.Value == true then
		_G.Message("Please Wait Before Changing Speed!", Color3.fromRGB(255, 0, 0))
		return
	end
	local changeSuccess, failReason = game.ReplicatedStorage.Functions.SpeedRemote:InvokeServer()
	if not changeSuccess then
		_G.Message(failReason, Color3.fromRGB(255, 0, 0))
	end
end)
events.Client.StartGUI.OnClientEvent:Connect(function(Bool)
	local WorldValue = StoryModeStats.Worlds[info.World.Value]
	if info.Raid.Value then
		warn(info.WorldString.Value)
		WorldValue = info.WorldString.Value
	end
	local Frame = script.Parent.Start.StartFrame
	Frame.Visible = true
	if info.ChallengeNumber.Value > 0 then
		Frame.InformationFrame.ModeText.Text = ChallengeModule.Data[info.ChallengeNumber.Value].Name
		Frame.InformationFrame.ModeText.ChallangeGradient.Enabled = true
		Frame.InformationFrame.ModeText.HardGradient.Enabled = false
		Frame.InformationFrame.ModeText.NormalGradient.Enabled = false
	end
	if game.Workspace.Info.Event.Value then
		warn("Event Textttttt")
		Frame.InformationFrame.ModeText.Text = "Event"
		Frame.InformationFrame.ModeText.ChallangeGradient.Enabled = true
		Frame.InformationFrame.ModeText.HardGradient.Enabled = false
		Frame.InformationFrame.ModeText.NormalGradient.Enabled = false
	else
		if info.Infinity.Value then
			Frame.InformationFrame.ModeText.Text = "Hard"
			Frame.InformationFrame.ModeText.HardGradient.Enabled = true
			Frame.InformationFrame.ModeText.ChallangeGradient.Enabled = false
			Frame.InformationFrame.ModeText.NormalGradient.Enabled = false
		else
			if game.Workspace.Info.Mode.Value == 2 and not game.Workspace.Info.Event.Value then
				Frame.InformationFrame.ModeText.Text = "Hard"
				Frame.InformationFrame.ModeText.HardGradient.Enabled = true
				Frame.InformationFrame.ModeText.ChallangeGradient.Enabled = false
				Frame.InformationFrame.ModeText.NormalGradient.Enabled = false
			else
				Frame.InformationFrame.ModeText.Text = "Normal"
				Frame.InformationFrame.ModeText.HardGradient.Enabled = false
				Frame.InformationFrame.ModeText.ChallangeGradient.Enabled = false
				Frame.InformationFrame.ModeText.NormalGradient.Enabled = true
			end
		end
	end
	if WorldValue then
		Frame.InformationFrame.StoryName.Text = WorldValue
	else
		Frame.InformationFrame.StoryName.Text = "Destroyed Kamino"
	end
	if info.Infinity.Value then
		Frame.InformationFrame.ActName.Text = "Infinity Mode"
	elseif info.Raid.Value then
		Frame.InformationFrame.ActName.Text = "Act " .. info.Level.Value .. " - " .. RaidModeStats.LevelName[WorldValue][info.Level.Value]
	elseif info.Event.Value then
		Frame.InformationFrame.ActName.Text = "Best Of Luck In Defeating This Foe."
	else
		Frame.InformationFrame.ActName.Text = "Act " .. info.Level.Value .. " - " .. StoryModeStats.LevelName[WorldValue][info.Level.Value]
	end
	TweenService:Create(Frame.InformationFrame.StoryName, TweenInfo.new(0.25, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
	TweenService:Create(Frame.InformationFrame.StoryName.UIStroke, TweenInfo.new(0.25, Enum.EasingStyle.Exponential), {Transparency = 0.18}):Play()
	task.wait(0.5)
	TweenService:Create(Frame.InformationFrame.Separation, TweenInfo.new(0.75, Enum.EasingStyle.Linear), {ImageTransparency = 0}):Play()
	task.wait(0.5)
	TweenService:Create(Frame.InformationFrame.ActName, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
	TweenService:Create(Frame.InformationFrame.ActName.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Transparency = 0.18}):Play()
	task.wait(0.5)
	TweenService:Create(Frame.InformationFrame.ModeText, TweenInfo.new(0.8, Enum.EasingStyle.Linear), {TextTransparency = 0}):Play()
	TweenService:Create(Frame.InformationFrame.ModeText.UIStroke, TweenInfo.new(0.8, Enum.EasingStyle.Linear), {Transparency = 0.18}):Play()
	task.wait(4)
	TweenService:Create(Frame.InformationFrame.StoryName, TweenInfo.new(0.85, Enum.EasingStyle.Linear), {TextTransparency = 1}):Play()
	TweenService:Create(Frame.InformationFrame.StoryName.UIStroke, TweenInfo.new(0.85, Enum.EasingStyle.Linear), {Transparency = 1}):Play()
	TweenService:Create(Frame.InformationFrame.Separation, TweenInfo.new(0.85, Enum.EasingStyle.Linear), {ImageTransparency = 1}):Play()
	TweenService:Create(Frame.InformationFrame.ActName, TweenInfo.new(0.85, Enum.EasingStyle.Linear), {TextTransparency = 1}):Play()
	TweenService:Create(Frame.InformationFrame.ActName.UIStroke, TweenInfo.new(0.85, Enum.EasingStyle.Linear), {Transparency = 1}):Play()
	TweenService:Create(Frame.InformationFrame.ModeText, TweenInfo.new(0.85, Enum.EasingStyle.Linear), {TextTransparency = 1}):Play()
	TweenService:Create(Frame.InformationFrame.ModeText.UIStroke, TweenInfo.new(0.85, Enum.EasingStyle.Linear), {Transparency = 1}):Play()
end)
local arrowCoroutine = coroutine.create(function()
	local mapFolder = workspace:WaitForChild("Map")
	local mainMap
	while mainMap == nil do
		mainMap = mapFolder:GetChildren()[1]
		task.wait()
	end
	while true do
		for i = 1, 5 do
			local arrow = game.ReplicatedStorage:WaitForChild("VFX"):WaitForChild("Arrow"):Clone()
			arrow.Parent = mainMap
			arrow.ArrowScript.Enabled = true
			task.wait(0.5)
		end
		task.wait(2)
	end
end)
coroutine.resume(arrowCoroutine)
_G.Timestarted = tick()
events.Client.VoteStartGame.OnClientEvent:Connect(function(secondsLeft, YesVote, lastCall, UpdatedArgument)
	if UpdatedArgument then
		SkipUI.Visible = true
		TweenService:Create(SkipUI, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Position = UDim2.fromScale(0.5, 0.35)}):Play()
		return
	end
	if lastCall then
		coroutine.close(arrowCoroutine)
		_G.Message("Game has started!", Color3.fromRGB(255, 170, 0), nil, true)
		UIHandler.PlaySound("WaveComplete")
		task.spawn(function()
			TweenService:Create(SkipUI, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Position = UDim2.fromScale(0.5, -0.5)}):Play()
			task.wait(0.2)
			SkipUI.Visible = false
		end)
	end
end)
if not info.Versus.Value and not info.Competitive.Value then
	task.spawn(function()
		for i, v in game.Workspace.Mobs:GetChildren() do
			health.Setup(v)
		end
	end)
	workspace.Mobs.ChildAdded:Connect(function(mob)
		health.Setup(mob)
	end)
else
	task.spawn(function()
		for i, v in workspace:WaitForChild("RedMobs"):GetChildren() do health.Setup(v) end
		for i, v in workspace:WaitForChild("BlueMobs"):GetChildren() do health.Setup(v) end
	end)
	workspace:WaitForChild("RedMobs").ChildAdded:Connect(function(mob) health.Setup(mob) end)
	workspace:WaitForChild("BlueMobs").ChildAdded:Connect(function(mob) health.Setup(mob) end)
end
function InputBegan(input, processed)
	if processed then return end
	if player:GetAttribute("PossessingTower") ~= nil then return end
	if towerToSpawn then
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonX then
			SpawnNewTower()
		elseif input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.ButtonY then
			rotation += 90
		elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonB then
			RemovePlaceholderTower()
		end
	elseif hoveredInstance and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonX) then
		local model = hoveredInstance and hoveredInstance:FindFirstAncestorOfClass("Model")
		while model and model.Parent ~= workspace.Towers do
			model = model.Parent:FindFirstAncestorOfClass("Model")
		end
		if model and model.Parent == workspace.Towers then
			if model == selectedTower then
				selectedTower = nil
			else
				selectedTower = model
			end
		else
			selectedTower = nil
		end
		toggleTowerInfo()
	end
	local Player = Players.LocalPlayer
	for i, v in Player.OwnedTowers:GetChildren() do
		if v:GetAttribute("Equipped") == true then
			if table.find(SelectedTowers, v) then continue end
			table.insert(SelectedTowers, v)
		end
	end
	local keys = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six}
	for i, v in keys do
		if input.KeyCode == v then
			local towerselected = SelectedTowers[i]
			if towerselected == nil then continue end
			local tower = GetUnitModel[towerselected.Name]
			if tower == nil then continue end
			local allowedToSpawn = true
			if allowedToSpawn then
				towerToSpawnValue = towerselected
				AddPlaceholderTower(tower.Name, towerselected)
			end
		end
	end
end
UserInputService.InputBegan:Connect(InputBegan)
script.Parent.PhoneControls.Place.TouchTap:Connect(function()
	InputBegan({UserInputType = Enum.UserInputType.MouseButton1})
end)
script.Parent.PhoneControls.Rotate.TouchTap:Connect(function()
	InputBegan({KeyCode = Enum.KeyCode.R})
end)
script.Parent.PhoneControls.Cancel.TouchTap:Connect(function()
	InputBegan({KeyCode = Enum.KeyCode.Q})
end)
RunService.Heartbeat:Connect(function()
	local MousePos = game:GetService("UserInputService"):GetMouseLocation() - game:GetService("GuiService"):GetGuiInset()
	local getGUI = player:WaitForChild("PlayerGui"):GetGuiObjectsAtPosition(MousePos.X, MousePos.Y)
	local result = MouseRaycast(towerToSpawn)
	for _, ui in getGUI do
		if ui:IsA("GuiButton") then
			result = lastValidResult
		end
	end
	if result and result.Instance then
		lastValidResult = result
		if towerToSpawn then
			hoveredInstance = nil
			local parentName = result.Instance.Parent.Name
			if parentName == "GroundPlace" or (player.Team and parentName == player.Team.Name .. "GroundPlace") then
				setPlacementVFXEnabled(towerToSpawn, true)
				canPlace = true
			elseif parentName == "AirPlace" and upgradesModule[towerToSpawn.Name].Upgrades[1].Type == "Air" then
				setPlacementVFXEnabled(towerToSpawn, true)
				canPlace = true
			else
				setPlacementVFXEnabled(towerToSpawn, false)
				canPlace = false
			end
			local height = towerToSpawn:WaitForChild("HumanoidRootPart").Size.Y * 1.5
			local x = result.Position.X
			local y = result.Position.Y + height
			local z = result.Position.Z
			local cframe = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(rotation), 0)
			towerToSpawn:SetPrimaryPartCFrame(cframe)
			if towerToSpawn:FindFirstChild("VFXTowerBasePart", true) then
				towerToSpawn:FindFirstChild("VFXTowerBasePart", true).CFrame = cframe
			end
		else
			hoveredInstance = result.Instance :: Model
			if hoveredInstance:FindFirstAncestor("Towers") then
				local topModel = getAncestor(hoveredInstance, "Towers")
				if topModel then
					if not lastHighlight then
						hoveredInstance = topModel:GetChildren()[1]
						createHoverHighlight()
					end
				else
					if lastHighlight then
						lastHighlight:Destroy()
						lastHighlight = nil
					end
				end
			elseif hoveredInstance:FindFirstAncestor("Spawnables") then
				local success = false
				local topModel = getAncestor(hoveredInstance, "Spawnables")
				if topModel then
					success = true
					if topModel:FindFirstChild("OwnedBy") then
						hoveredInstance = topModel.OwnedBy.Value:GetChildren()[1]
					end
					if not lastHighlight then
						createHoverHighlight()
					end
				end
				if not success then
					if lastHighlight then
						lastHighlight:Destroy()
						lastHighlight = nil
					end
				end
			else
				if lastHighlight then
					lastHighlight:Destroy()
					lastHighlight = nil
				end
			end
		end
	else
		hoveredInstance = nil
	end
end)
ReplicatedStorage.Events.Client.Timer.OnClientEvent:Connect(function(round, restTime)
	local gameSpeed = workspace.Info.GameSpeed.Value
	if round ~= 1 then
		_G.Message("Wave Completed!", Color3.fromRGB(255, 170, 0), nil, true)
		UIHandler.PlaySound("WaveComplete")
	end
	updateWaveDisplays(round)
	IngameHud.Top.TextWave.Visible = true
	for _ = restTime, 1, -1 do
		IngameHud.Top.TextWave.Text = "Wave " .. round
		TweenService:Create(IngameHud.Top.TextWave, TweenInfo.new(0.25 / gameSpeed, Enum.EasingStyle.Exponential), {TextColor3 = Color3.new(1, 0, 0)}):Play()
		task.wait(0.25 / gameSpeed)
		TweenService:Create(IngameHud.Top.TextWave, TweenInfo.new(0.25 / gameSpeed, Enum.EasingStyle.Exponential), {TextColor3 = Color3.new(1, 1, 1)}):Play()
		task.wait(0.75 / gameSpeed)
	end
	IngameHud.Top.TextWave.Visible = false
	updateWaveDisplays(round)
	_G.Message("Wave " .. round .. " Begins!", Color3.fromRGB(255, 170, 0), nil, true)
	UIHandler.PlaySound("WaveStart")
	if round == info.MaxWaves.Value and not info.Versus.Value then
		task.delay(1 / gameSpeed, function()
			_G.Message("FINAL WAVE!", Color3.fromRGB(255, 170, 0), nil, true)
			UIHandler.PlaySound("WaveStart")
		end)
	end
end)
events.Client.Teleporting.OnClientEvent:Connect(function(...)
	TeleportService:SetTeleportGui(UIMapLoadingScreenModule.CreateLoadingGui(...))
end)
ReplicatedStorage.Events.Client.ReceiveRewards.OnClientEvent:Connect(function(rewards, dontShowGui, isFirstTime)
	task.spawn(function()
		local infoLocal = workspace:FindFirstChild("Info")
		if not infoLocal then return end
		local unit = infoLocal:FindFirstChild("DisplayingUnit")
		if unit and unit.Value then
			task.delay(7, function()
				local delayedUnit = workspace:FindFirstChild("Info") and workspace.Info:FindFirstChild("DisplayingUnit")
				if delayedUnit then delayedUnit.Value = false end
			end)
			repeat task.wait(0.1) until not (unit and unit.Value)
		end
	end)
	local EndScreen = getActiveEndScreen()
	local status = if info.Victory.Value then "VICTORY" else "GAME OVER"
	setupEndScreen(EndScreen, status, rewards)
	local function EndScreenGUIDisableLocal(value)
		EndScreenGUIDisable(value)
	end
	if not dontShowGui then
		showEndScreen(EndScreen)
	end
	local RewardsFrame = EndScreen.Main.Content:FindFirstChild("Rewards")
	local isHidden = true
	for reward, amount in rewards do
		if reward == "Items" then
			for item, quantity in amount do
				if quantity <= 0 then continue end
				for _ = 1, quantity do
					local nextItem = false
					if isHidden then
						EndScreen.Visible = false
						isHidden = false
					end
					local itemStats = itemModule[item]
					if workspace.CurrentCamera:FindFirstChild("Blur") then
						workspace.CurrentCamera.Blur:Destroy()
					end
					EndScreenGUIDisableLocal(true)
					ViewModule.Item({itemStats, nil, function() nextItem = true end})
					repeat task.wait() until nextItem
				end
			end
		elseif reward == "OwnedTowers" then
			for _, tower in amount do
				local goNext = false
				local success = pcall(function()
					local unitStats = upgradesModule[tower.Name]
					ViewModule.Hatch({unitStats, tower, function() goNext = true end})
				end)
				if not success then goNext = true end
				repeat task.wait() until goNext
			end
		elseif reward == "Tower" then
			local tower = amount.unit
			local goNext = false
			if workspace.CurrentCamera:FindFirstChild("Blur") then
				workspace.CurrentCamera.Blur:Destroy()
			end
			EndScreen.Visible = false
			EndScreenGUIDisableLocal(true)
			local success, err = pcall(function()
				local unitStats = upgradesModule[tower.Name]
				ViewModule.Hatch({unitStats, tower, function() goNext = true end})
			end)
			if not success then
				warn(err)
				goNext = true
			end
			repeat task.wait() until goNext
			_G.Message("A mysterious unit has been added to your collection", Color3.fromRGB(255, 46, 46), "Mystery")
		elseif reward == "CompReward" then
			local compFrame = EndScreen:FindFirstChild("InformationFrame", true)
			if compFrame and compFrame:FindFirstChild("Comp") then
				local EPChanged = amount["ELO"] - amount["oldELO"]
				local nowRank, division = RankCalculator.getRankAndDivision(amount["ELO"])
				local CompRankConfig = ReplicatedStorage.CompetitiveData.CompetitiveRankConfigurations[nowRank]
				local InformationFrame = compFrame.Comp
				InformationFrame.Rank.Text = nowRank .. " " .. RomanNumeralsConverter.toRoman(division)
				InformationFrame.Bar.UIGradient.Color = CompRankConfig.UIGradient.Color
				InformationFrame.Bar.TextLabel.Text = convertNum(amount["ELO"]) .. "/100 EP"
				InformationFrame.Bar.Front.UIGradient.Color = CompRankConfig.UIGradient.Color
				InformationFrame.Bar.Front.Size = UDim2.fromScale(convertNum(amount["ELO"]) / 100, 1)
				InformationFrame.Icon.Image = CompRankConfig.Image
				if EPChanged < 0 then
					InformationFrame.EPAmount.Text = "-" .. tostring(EPChanged)
				else
					InformationFrame.EPAmount.Text = EPChanged
				end
			end
		else
			if amount <= 0 then continue end
			if reward == "fdasfasfsafsd" then
				local itemStats = itemModule.Star
				for _ = 1, amount do
					local nextItem = false
					ViewModule.Item({itemStats, nil, function() nextItem = true end})
					repeat task.wait() until nextItem
				end
			elseif RewardsFrame and RewardsFrame:FindFirstChild(reward) then
				local icon = RewardsFrame[reward]
				local displayNameLabel = icon:FindFirstChild("Button", true) and icon.Button:FindFirstChild("DisplayNameLabel", true)
				local countLabel = icon:FindFirstChild("Button", true) and icon.Button:FindFirstChild("ItemCount", true) and icon.Button.ItemCount:FindFirstChild("CountLabel")
				if displayNameLabel and displayNameLabel:IsA("TextLabel") then
					displayNameLabel.Text = reward
				end
				if countLabel and countLabel:IsA("TextLabel") then
					countLabel.Text = amount .. "x"
				end
				icon.Visible = true
			end
		end
	end
	if workspace.Info.Infinity.Value then
		print("MEDAL_CLIP_TRIGGER_GAMEOVER:{INFINITY}")
	else
		print("MEDAL_CLIP_TRIGGER_GAMEOVER:{STORY}")
	end
	showEndScreen(EndScreen)
end)
player:GetAttributeChangedSignal("PossessingTower"):Connect(function()
	if player:GetAttribute("PossessingTower") ~= nil then
		if towerToSpawn then RemovePlaceholderTower() end
		selectedTower = nil
		toggleTowerInfo()
	end
end)
LoadGui()