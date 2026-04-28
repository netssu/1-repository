local selectedUnit = script.Parent.SelectedUnitValue
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Upgrades = require(ReplicatedStorage.Upgrades)
local Items = require(ReplicatedStorage.ItemStats)
local ViewModule = require(ReplicatedStorage.Modules.ViewModule)
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Traits = require(ReplicatedStorage.Modules.Traits)
local MainFrame = script.Parent

local UIHandler = require(ReplicatedStorage.Modules.Client.UIHandler)
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)
local GetUnitModel = require(ReplicatedStorage.Modules.GetUnitModel)
local ButtonCreationModule = require(ReplicatedStorage.Modules.ButtonCreationModule)

local player = game.Players.LocalPlayer
local Inventory = player.PlayerGui:WaitForChild('UnitsGui').Inventory.Units
local Scroll = Inventory.Frame.Left_Panel.Contents.Act.UnitsScroll
local SecondInventory = ReplicatedStorage.Cache.Inventory
local DEBUG_EVOLVE = true

local function debugEvolve(...)
	if not DEBUG_EVOLVE then
		return
	end

--	warn("[EvolveDebug]", ...)
end

if _G.evolveTowerSelection == nil then
	_G.evolveTowerSelection = false
	debugEvolve("initialized_evolveTowerSelection", "value=false")
end


local CS = ColorSequence.new
local CSK = ColorSequenceKeypoint.new
local C3 = Color3.new
local open = false
local lastManualZoneState = nil
local lastZoneDebugAt = 0
local evolveZoneOccupied = false



local gui = script.Parent.Parent

debugEvolve("handler_loaded", "gui=" .. gui:GetFullName(), "main=" .. MainFrame:GetFullName())

TweenService:Create(gui.PatternPreview, TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false, 0), {Position = UDim2.fromScale(0,1)}):Play()

-- set default unit displays
MainFrame.SelectedUnit:ClearAllChildren()
MainFrame.ResultUnit:ClearAllChildren()

local selectedUnitFrame = ButtonCreationModule.createButton() :: TextButton
selectedUnitFrame.Instance.Size = UDim2.fromScale(0.8,0.8)
selectedUnitFrame.Instance.Parent = MainFrame.SelectedUnit

local resultUnitFrame = ButtonCreationModule.createButton() :: TextButton
resultUnitFrame.Instance.Size = UDim2.fromScale(0.8,0.8)
resultUnitFrame.Instance.Parent = MainFrame.ResultUnit

local function update()
	debugEvolve(
		"update_called",
		"selected=" .. tostring(selectedUnit.Value),
		"guiVisible=" .. tostring(gui.Visible),
		"mainVisible=" .. tostring(MainFrame.Visible)
	)

	for i, v in MainFrame.InformationBox.UnitsNeed:GetChildren() do
		if v:IsA("ImageLabel") then
			v:Destroy()
		end
	end

	MainFrame.SelectedUnit:ClearAllChildren()
	MainFrame.ResultUnit:ClearAllChildren()

	local selectedUnitFrame = ButtonCreationModule.createButton() :: TextButton
	selectedUnitFrame.Instance.Size = UDim2.fromScale(0.8,0.8)
	selectedUnitFrame.Instance.Parent = MainFrame.SelectedUnit

	local resultUnitFrame = ButtonCreationModule.createButton() :: TextButton
	resultUnitFrame.Instance.Size = UDim2.fromScale(0.8,0.8)
	resultUnitFrame.Instance.Parent = MainFrame.ResultUnit

	if selectedUnit.Value then
		debugEvolve(
			"selected_unit_present",
			"name=" .. tostring(selectedUnit.Value.Name),
			"parent=" .. tostring(selectedUnit.Value.Parent)
		)
		_G.CloseAll("Evolve")
		script.Parent.Visible = true
		gui.Visible = true

		local unit = Upgrades[selectedUnit.Value.Name]

		if unit and selectedUnit.Value.Parent == game.Players.LocalPlayer.OwnedTowers then
			local data = game.Players.LocalPlayer

			if unit["Evolve"] then
				if selectedUnit.Value:GetAttribute("Equipped") then
					game.ReplicatedStorage.Events.InteractItem:FireServer(selectedUnit.Value,false)
				end

				local resultUnitName = unit.Evolve.EvolvedUnit
				for i, v in unit["Evolve"]["EvolutionRequirement"] do
					local template = script.TemplateContainer:Clone()
					local icon = ButtonCreationModule.createButton(i)
					icon.Instance.Parent = template

					local requiredUnit = Upgrades[tostring(i)]
					local item = false
					if requiredUnit == nil then
						requiredUnit = Items[tostring(i)]
						item = true
					end
					icon.Name = tostring(i)

					if MainFrame.InformationBox.UnitsNeed:FindFirstChild(tostring(i)) then
						continue
					end

					if not item then
						local unitQuantity = 0
						for _, x in data.OwnedTowers:GetChildren() do
							if x.Name == i then
								unitQuantity += 1
							end
						end

						icon:setAmount(unitQuantity.."/"..tostring(v))
						if unitQuantity >= v then
							icon:setAmountColor()
						else
							icon:setAmountColor(Color3.new(1,0,0))
						end
						--icon.ImageGrad.UIGradient.Color = ReplicatedStorage.Borders[requiredUnit.Rarity].Color
						--icon.Glow.UIGradient.Color = ReplicatedStorage.Borders[requiredUnit.Rarity].Color

						template.Parent = MainFrame.UnitsNeed
						local vp = ViewPortModule.CreateViewPort(requiredUnit.Name)
						--if vp then
						--	vp.ZIndex = 2
						--	vp.Parent = icon


						--end
					else
						local unitQuantity = 0
						for _, x in data.Items:GetChildren() do
							if x.Name == i then
								unitQuantity = x.Value
							end
						end
						--icon.TextLabel.Text = unitQuantity.."/"..tostring(v)
						icon:setAmount(unitQuantity.."/"..tostring(v))

						if unitQuantity >= v then
							icon:setAmountColor()
						else
							icon:setAmountColor(Color3.new(1,0,0))
						end

						--icon.ImageGrad.UIGradient.Color = ReplicatedStorage.Borders[requiredUnit.Rarity].Color
						--icon.Glow.UIGradient.Color = ReplicatedStorage.Borders[requiredUnit.Rarity].Color

						--local vp = ViewPortModule.CreateViewPort(i)
						--if vp then
						--vp.ZIndex = 3
						--vp.Parent = icon
						--end

						template.Parent = MainFrame.InformationBox.UnitsNeed
					end
				end
				local realUnit = GetUnitModel[selectedUnit.Value.Name]

				MainFrame.SelectedUnit:ClearAllChildren()
				MainFrame.ResultUnit:ClearAllChildren()

				-- create our own frames
				-- selectedUnit.Value -- selected unit
				-- resultUnitName -- result unit(copy over the level stat) and trait
				local selectedUnitFrame = ButtonCreationModule.createButton(selectedUnit.Value) :: TextButton
				selectedUnitFrame.Instance.Size = UDim2.fromScale(0.8,0.8)
				selectedUnitFrame.Instance.Parent = MainFrame.SelectedUnit

				local resultUnitFrame = ButtonCreationModule.createButton(resultUnitName) 
				resultUnitFrame.Instance.Size = UDim2.fromScale(0.8,0.8)
				resultUnitFrame.Instance.Parent = MainFrame.ResultUnit

				resultUnitFrame:setShiny(selectedUnit.Value:GetAttribute('Shiny'))
				resultUnitFrame:setAmount('LVL ' .. selectedUnit.Value:GetAttribute('Level'))
				resultUnitFrame:setTrait(selectedUnit.Value:GetAttribute('Trait'))
			end

			local cancraft = true
			for i, v in MainFrame.InformationBox.UnitsNeed:GetChildren() do
				if v:IsA("ImageButton") then
					if v.Quantity.TextColor3 == Color3.new(1,0,0) then
						cancraft = false
					end
				end
			end
		end
	end
	if not MainFrame.SelectedUnit.Button:FindFirstChildOfClass("ViewportFrame") and not MainFrame.ResultUnit.Button:FindFirstChildOfClass("ViewportFrame") then
		local Empty = ViewPortModule.CreateEmptyPort()
		Empty.ZIndex = 8
		if not MainFrame.SelectedUnit:FindFirstChild("Empty_Slot") then
			Empty:Clone().Parent = MainFrame.SelectedUnit
		end
		if not MainFrame.ResultUnit:FindFirstChild("Empty_Slot") then
			Empty:Clone().Parent = MainFrame.ResultUnit
		end
		MainFrame.SelectedUnit.Image.UIGradient.Color = CS{CSK(0,C3(1,1,1)),CSK(1,C3(1,1,1))}
		MainFrame.SelectedUnit.GlowEffect.UIGradient.Color = CS{CSK(0,C3(1,1,1)),CSK(1,C3(1,1,1))}
		MainFrame.SelectedUnit.Mark.Visible = true
		MainFrame.ResultUnit.Image.UIGradient.Color = CS{CSK(0,C3(1,1,1)),CSK(1,C3(1,1,1))}
		MainFrame.ResultUnit.GlowEffect.UIGradient.Color = CS{CSK(0,C3(1,1,1)),CSK(1,C3(1,1,1))}
		MainFrame.ResultUnit.Mark.Visible = true
	end
end

selectedUnit.Changed:Connect(update)

MainFrame.EvolveButton.Activated:Connect(function()
	debugEvolve("evolve_button_activated", "selected=" .. tostring(selectedUnit.Value))

	for i,v in MainFrame.SelectedUnit:GetChildren() do
		if v.Name == "Empty_Slot" then
			warn("Wrong One No Unit")
			debugEvolve("evolve_button_blocked", "reason=no_unit")
			return
		end
	end


	local cancraft = true
	for i, v in MainFrame.InformationBox.UnitsNeed:GetChildren() do
		if v:IsA("ImageButton") then

			if v.Quantity.TextColor3 == Color3.new(1,0,0) then
				cancraft = false
			end
		end
	end

	if not cancraft then
		debugEvolve("evolve_button_blocked", "reason=missing_requirements")
		return
	end

	MainFrame.SelectedUnit:ClearAllChildren()
	MainFrame.ResultUnit:ClearAllChildren()
	warn(selectedUnit.Value)
	local result = ReplicatedStorage.Functions.EvolveUnit:InvokeServer(selectedUnit.Value)
	debugEvolve("evolve_result", "resultType=" .. typeof(result), "result=" .. tostring(result))
	if typeof(result) == "Instance" then
		update()
		_G.CloseAll()
		UIHandler.PlaySound("Redeem")
		ViewModule.EvolveHatch({
			Upgrades[result.Name],
			result
		})
	end
end)


MainFrame.SelectUnit.Activated:Connect(function()
	warn("Opening Frame")
	debugEvolve(
		"select_unit_activated",
		"evolveTowerSelection=" .. tostring(_G.evolveTowerSelection),
		"guiVisible=" .. tostring(gui.Visible),
		"mainVisible=" .. tostring(MainFrame.Visible)
	)
	selectedUnit.Value = nil

	if _G.evolveTowerSelection == false then
		warn("Opening xo2")
		script.Parent.Visible = false


		_G.CloseAll("Units")

		Inventory.Visible = true

		if not Inventory.Visible then
			warn("Not Opened")
			Inventory.Visible = true
		end


		_G.evolveTowerSelection = true

		local units = {}

		for i,v in Scroll:GetChildren() do
			table.insert(units, v)
		end

		for i,v in SecondInventory:GetChildren() do
			table.insert(units, v)
		end


		for _, v in pairs(units) do
			if v:IsA("ImageButton") and v:FindFirstChild("TowerValue") then
				local towerVal = v.TowerValue.Value
				if towerVal and typeof(towerVal) == "Instance" then
					local unitName = towerVal.Name
					local config = Upgrades[unitName]
					if config then
						local hasEvolve = config["Evolve"] ~= nil
						v.Visible = hasEvolve
					else
						v.Visible = false
					end
				end
			end
		end

		warn(selectedUnit.Value)
	end
end)

local Zone = require(ReplicatedStorage.Modules.Zone)
local evolutionBox = workspace:FindFirstChild('EvolutionBox')
local evolutionHitbox = evolutionBox and evolutionBox:FindFirstChild('EvolutionHitbox')

if not evolutionBox then
	warn("[EvolveDebug] EvolutionBox not found in workspace")
elseif not evolutionHitbox then
	warn("[EvolveDebug] EvolutionHitbox not found inside EvolutionBox")
else
	debugEvolve("zone_initialized", "hitbox=" .. evolutionHitbox:GetFullName())
end

local Container = evolutionHitbox and Zone.new(evolutionHitbox)

local function onEvolveZoneEntered(source)
	if evolveZoneOccupied then
		debugEvolve("zone_entered_ignored", "source=" .. tostring(source), "reason=already_inside")
		return
	end

	evolveZoneOccupied = true
	debugEvolve(
		"zone_entered",
		"source=" .. tostring(source),
		"guiVisibleBefore=" .. tostring(gui.Visible),
		"mainVisibleBefore=" .. tostring(MainFrame.Visible),
		"closeAllExists=" .. tostring(typeof(_G.CloseAll) == "function")
	)
	_G.CloseAll('Evolve')
	_G.CanSummon = false
	if _G.evolveTowerSelection == false then
		script.Parent.Visible = true
		gui.Visible = true
	end
	debugEvolve(
		"zone_entered_after_open",
		"source=" .. tostring(source),
		"guiVisibleAfter=" .. tostring(gui.Visible),
		"mainVisibleAfter=" .. tostring(MainFrame.Visible),
		"canSummon=" .. tostring(_G.CanSummon)
	)
end

local function onEvolveZoneExited(source)
	if not evolveZoneOccupied then
		debugEvolve("zone_exited_ignored", "source=" .. tostring(source), "reason=already_outside")
		return
	end

	evolveZoneOccupied = false
	debugEvolve(
		"zone_exited",
		"source=" .. tostring(source),
		"guiVisibleBefore=" .. tostring(gui.Visible),
		"mainVisibleBefore=" .. tostring(MainFrame.Visible)
	)
	_G.CloseAll()
	_G.CanSummon = true
	selectedUnit.Value = nil
	_G.evolveTowerSelection = false
	Inventory.Visible = false

	local units = {}

	for i,v in Scroll:GetChildren() do
		table.insert(units, v)
	end

	for i,v in SecondInventory:GetChildren() do
		table.insert(units, v)
	end

	for _, v in pairs(units) do
		if v:IsA("ImageButton") and v:FindFirstChild("TowerValue") then
			local towerVal = v.TowerValue.Value
			if towerVal and typeof(towerVal) == "Instance" then
				v.Visible = true
			end
		end
	end

	debugEvolve(
		"zone_exited_after_reset",
		"source=" .. tostring(source),
		"guiVisibleAfter=" .. tostring(gui.Visible),
		"mainVisibleAfter=" .. tostring(MainFrame.Visible),
		"canSummon=" .. tostring(_G.CanSummon)
	)
end

if Container then
	Container.playerEntered:Connect(function(plr)
		if plr == player then
			onEvolveZoneEntered("playerEntered")
		end
	end)

	Container.playerExited:Connect(function(plr)
		if plr == player then
			onEvolveZoneExited("playerExited")
		end
	end)

	Container.localPlayerEntered:Connect(function()
		onEvolveZoneEntered("localPlayerEntered")
	end)

	Container.localPlayerExited:Connect(function()
		onEvolveZoneExited("localPlayerExited")
	end)
end

if evolutionHitbox then
	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			return
		end

		local distance = (rootPart.Position - evolutionHitbox.Position).Magnitude
		local localPosition = evolutionHitbox.CFrame:PointToObjectSpace(rootPart.Position)
		local halfSize = evolutionHitbox.Size * 0.5
		local isInsideBox = math.abs(localPosition.X) <= halfSize.X
			and math.abs(localPosition.Y) <= halfSize.Y
			and math.abs(localPosition.Z) <= halfSize.Z

		local shouldLog = false
		if lastManualZoneState == nil or lastManualZoneState ~= isInsideBox then
			shouldLog = true
			lastManualZoneState = isInsideBox
		elseif distance <= 35 and (os.clock() - lastZoneDebugAt) >= 1 then
			shouldLog = true
		end

		if shouldLog then
			lastZoneDebugAt = os.clock()
			debugEvolve(
				"manual_hitbox_check",
				"distance=" .. string.format("%.2f", distance),
				"insideBox=" .. tostring(isInsideBox),
				"rootPos=" .. tostring(rootPart.Position),
				"hitboxPos=" .. tostring(evolutionHitbox.Position),
				"hitboxSize=" .. tostring(evolutionHitbox.Size)
			)
		end
	end)
end

MainFrame.Parent.CloseButton.Activated:Connect(function()
	debugEvolve("close_button_activated")
	_G.CloseAll()
end)
