-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")

-- CONSTANTS
local wait = task.wait

-- VARIABLES
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local UIHandlerModule = require(ReplicatedStorage.Modules.Client.UIHandler)
local Simplebar = require(ReplicatedStorage.Modules.Client.Simplebar)

local NewUI = PlayerGui:WaitForChild("NewUI")

local GroupRewardsFrame = NewUI:WaitForChild("Reward")
local LvlUpFrame = NewUI:WaitForChild("RewardPopUp")
local DailyRewardFrame = NewUI:WaitForChild("Daily")
local IndexFrame = NewUI:WaitForChild("IndexFrame")
local TraitFrame = NewUI:WaitForChild("WillPower")
local sideMenu = NewUI:FindFirstChild("sideMenu") or NewUI:FindFirstChild("HUDButtons") or NewUI:WaitForChild("sideMenu")
local CoreGameUI = PlayerGui:WaitForChild("CoreGameUI")

if sideMenu.Name == "sideMenu" then
	local legacyHud = CoreGameUI:FindFirstChild("HUD")
	if legacyHud and legacyHud:IsA("GuiObject") then
		legacyHud.Visible = false
	end

	local legacyButtons = CoreGameUI:FindFirstChild("Buttons")
	if legacyButtons then
		if legacyButtons:IsA("GuiObject") then
			legacyButtons.Visible = false
		elseif legacyButtons:FindFirstChild("Buttons") and legacyButtons.Buttons:IsA("GuiObject") then
			legacyButtons.Buttons.Visible = false
		end
	end
end

local buttons = {}
local buttonTargets = {}
local buttonVisuals = {}
local buttonguis = {}
local persistentNewUIChildren = {
	sideMenu = true,
	HUDButtons = true,
	IngameHud = true,
	Values = true,
}
local othermenus = { IndexFrame, TraitFrame, DailyRewardFrame, GroupRewardsFrame }
local openuionstart = { DailyRewardFrame }
local buttonguistatus = {}
local onCooldown = {
	SummonDetection = false
}
local prev = nil

-- FUNCTIONS
function CanClaim()
	if not player:FindFirstChild("DataLoaded") then
		repeat task.wait() until player:FindFirstChild("DataLoaded")
	end

	local lastClaim = player.DailyRewards.LastClaimTime.Value
	local secondsSinceLastClaim = os.clock() - lastClaim

	return secondsSinceLastClaim >= (3600 * 24)
end

local function blur(blurState: boolean, otherVisible: boolean)
	if blurState then
		Lighting.UIBlur.Enabled = true
		TweenService:Create(Lighting.UIBlur, TweenInfo.new(.3), { Size = 60 }):Play()
		TweenService:Create(Lighting, TweenInfo.new(.3), { ExposureCompensation = -1 }):Play()
	else
		if not otherVisible then
			local tweenObj = TweenService:Create(Lighting.UIBlur, TweenInfo.new(.3), { Size = 0 })
			TweenService:Create(Lighting, TweenInfo.new(.5), { ExposureCompensation = -.2 }):Play()
			tweenObj:Play()
			tweenObj.Completed:Connect(function()
				Lighting.UIBlur.Enabled = false
				tweenObj:Destroy()
			end)
		end
	end
end

local function toggleRobloxHud(state: boolean)
	if _G.PlayerlistEnabled then
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, state)
	end

	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, state)
end

local function tween(obj, length, details)
	TweenService:Create(obj, TweenInfo.new(length), details):Play()
end

local function normalizeName(name)
	return typeof(name) == "string" and string.lower(name) or name
end

local function debugSummonMenu(...)
	warn("[SummonOpenDebug]", ...)
end

local function getSummonMenuTarget()
	local newSummons = NewUI:FindFirstChild("Summons")
	debugSummonMenu(
		"getSummonMenuTarget",
		"hasNewSummons=" .. tostring(newSummons ~= nil),
		"class=" .. tostring(newSummons and newSummons.ClassName),
		"visible=" .. tostring(newSummons and newSummons.Visible)
	)
	return newSummons and "Summons" or "SummonFrame"
end

local function getJunkTraderMenuTarget()
	local newJunkTrader = NewUI:FindFirstChild("JunkTrader")
	return newJunkTrader and "JunkTrader" or "JunkTraderFrame"
end

local closeAllAliases = {
	areasframe = "Areas",
	area = "Areas",
	battlepass = "BattlepassFrame",
	battlepassframe = "BattlepassFrame",
	code = "Codes",
	codes = "Codes",
	inventory = "Units",
	quest = "Quests",
	questframe = "Quests",
	questframeew = "Quests",
	shopframe = "Shop",
	unit = "Units",
	units = "Units",
}

local sideMenuActions = {
	areas = "Areas",
	battlepass = "BattlepassFrame",
	codes = "Codes",
	inventory = "Units",
	play = "Play",
	quest = "Quests",
	shop = "Shop",
	summon = "Summon",
}

local function normalizeCloseAllTarget(name)
	if not name then return nil end

	local normalizedName = normalizeName(name)
	if normalizedName == "summon" or normalizedName == "summonframe" or normalizedName == "summons" then
		return getSummonMenuTarget()
	end

	if normalizedName == "junktrader" or normalizedName == "junktraderframe" then
		return getJunkTraderMenuTarget()
	end

	return closeAllAliases[normalizedName] or name
end

local function resolveButtonTarget(button)
	local rawTarget = buttonTargets[button] or button.Name
	return sideMenuActions[normalizeName(rawTarget)] or normalizeCloseAllTarget(rawTarget)
end

local function isManagedMenuGuiObject(instance)
	if not instance or persistentNewUIChildren[instance.Name] then
		return false
	end

	return instance:IsA("Frame")
		or instance:IsA("ScrollingFrame")
		or instance:IsA("ImageButton")
		or instance:IsA("TextButton")
end

local function selectInstanceFromString(except)
	if not except then
		return nil
	end

	local foundInstance = nil
	local normalizedExcept = normalizeName(except)

	for i, v in pairs(buttonguis) do
		if v.Name == except or normalizeName(v.Name) == normalizedExcept then
			foundInstance = v
			break
		end
	end

	if not foundInstance then
		for i, v in pairs(othermenus) do
			if v.Name == except or normalizeName(v.Name) == normalizedExcept then
				foundInstance = v
				break
			end
		end
	end

	if not foundInstance then
		local directMatch = NewUI:FindFirstChild(except) or NewUI:FindFirstChild(except, true)
		if directMatch and directMatch:IsA("GuiObject") then
			foundInstance = directMatch
		end
	end

	return foundInstance
end

local function closeall(except, dontOverride)
	local originalExcept = except
	except = normalizeCloseAllTarget(except)

	if not except and not prev then
		toggleRobloxHud(true)

		tween(workspace.Camera, 0.3, { FieldOfView = 70 })
		if Lighting:FindFirstChild("NewUIBlur") then
			tween(Lighting.NewUIBlur, 0.3, { Size = 0 })
		end
		UIHandlerModule.EnableAllButtons()
		Simplebar.toggleSimplebar(true)
		_G.CurrentlyOpen = false
		return
	end

	if normalizeName(originalExcept) == "summon"
		or normalizeName(originalExcept) == "summonframe"
		or normalizeName(originalExcept) == "summons"
		or normalizeName(except) == "summonframe"
		or normalizeName(except) == "summons" then
		debugSummonMenu("closeall:requested", "original=" .. tostring(originalExcept), "normalized=" .. tostring(except))
	end

	if not player:FindFirstChild("TutorialWin") then return end
	if not player.TutorialWin.Value and except and string.find(except, 'DailyReward') then return end

	if _G.Occupied then return end

	if except and not string.find(except, 'Frame') then
		if not (NewUI:FindFirstChild(except) or NewUI:FindFirstChild(except, true)) then
			except ..= 'Frame'
		end
	end

	if prev == except then
		local foundInstance = selectInstanceFromString(prev)

		if foundInstance then
			UIHandlerModule.PlaySound("Close")

			foundInstance.AnchorPoint = Vector2.new(.5, .5)
			foundInstance.Position = UDim2.fromScale(0.5, 0.45)
			foundInstance.Visible = true
			local closeTween = TweenService:Create(foundInstance, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromScale(0.5, 1.5) })
			closeTween:Play()
			closeTween.Completed:Connect(function()
				if prev ~= except then
					foundInstance.Visible = false
				end
			end)
		end

		toggleRobloxHud(true)

		tween(workspace.Camera, 0.3, { FieldOfView = 70 })
		if Lighting:FindFirstChild("NewUIBlur") then
			tween(Lighting.NewUIBlur, 0.3, { Size = 0 })
		end
		UIHandlerModule.EnableAllButtons()

		Simplebar.toggleSimplebar(true)
		_G.CurrentlyOpen = false

		prev = nil
		return
	end

	if prev then
		local foundInstance = selectInstanceFromString(prev)

		if foundInstance then
			foundInstance.AnchorPoint = Vector2.new(.5, .5)
			foundInstance.Position = UDim2.fromScale(0.5, 0.5)
			foundInstance.Visible = true
			local closeTween = TweenService:Create(foundInstance, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromScale(0.5, 1.5) })
			closeTween:Play()
			closeTween.Completed:Connect(function()
				if prev ~= foundInstance.Name then
					foundInstance.Visible = false
				end
			end)
		end
	end

	prev = except

	toggleRobloxHud(not except)
	UIHandlerModule.PlaySound(except and 'Open' or 'Close')

	local foundInstance = selectInstanceFromString(except)

	if normalizeName(except) == "summonframe" or normalizeName(except) == "summons" then
		local newSummons = NewUI:FindFirstChild("Summons")
		local legacySummon = PlayerGui:FindFirstChild("CoreGameUI")
			and PlayerGui.CoreGameUI:FindFirstChild("Summon")
			and PlayerGui.CoreGameUI.Summon:FindFirstChild("SummonFrame")

		debugSummonMenu(
			"closeall:resolved",
			"except=" .. tostring(except),
			"found=" .. tostring(foundInstance and foundInstance:GetFullName()),
			"foundClass=" .. tostring(foundInstance and foundInstance.ClassName),
			"newVisibleBefore=" .. tostring(newSummons and newSummons.Visible),
			"legacyVisibleBefore=" .. tostring(legacySummon and legacySummon.Visible)
		)
	end

	if foundInstance then
		Simplebar.toggleSimplebar(false)
		foundInstance.AnchorPoint = Vector2.new(.5, .5)
		foundInstance.Position = UDim2.fromScale(0.5, -0.5)

		tween(workspace.Camera, 0.3, { FieldOfView = 90 })
		if Lighting:FindFirstChild("NewUIBlur") then
			tween(Lighting.NewUIBlur, 0.3, { Size = 24 })
		end

		if foundInstance.Name == 'Units' then
			UIHandlerModule.DisableAllButtons({ 'Slots' })
		else
			UIHandlerModule.DisableAllButtons()
		end

		foundInstance.Visible = true
		local closeTween = TweenService:Create(foundInstance, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromScale(0.5, 0.5) })
		closeTween:Play()
		_G.CurrentlyOpen = true

		if normalizeName(except) == "summonframe" or normalizeName(except) == "summons" then
			local newSummons = NewUI:FindFirstChild("Summons")
			local legacySummon = PlayerGui:FindFirstChild("CoreGameUI")
				and PlayerGui.CoreGameUI:FindFirstChild("Summon")
				and PlayerGui.CoreGameUI.Summon:FindFirstChild("SummonFrame")

			debugSummonMenu(
				"closeall:after-open",
				"except=" .. tostring(except),
				"foundVisible=" .. tostring(foundInstance.Visible),
				"newVisibleAfter=" .. tostring(newSummons and newSummons.Visible),
				"legacyVisibleAfter=" .. tostring(legacySummon and legacySummon.Visible)
			)
		end
	else
		tween(workspace.Camera, 0.3, { FieldOfView = 70 })
		if Lighting:FindFirstChild("NewUIBlur") then
			tween(Lighting.NewUIBlur, 0.3, { Size = 0 })
		end
		UIHandlerModule.EnableAllButtons()

		Simplebar.toggleSimplebar(true)
		_G.CurrentlyOpen = false
	end
end

-- INIT

ReplicatedStorage.Functions.GetTime.OnClientInvoke = function()
	return os.clock()
end

local function findButtonInMenuItem(menuItem)
	if menuItem:IsA("GuiButton") then
		return menuItem
	end

	local preferredButton = menuItem:FindFirstChild("Btn", true)
		or menuItem:FindFirstChild("Button", true)

	if preferredButton and preferredButton:IsA("GuiButton") then
		return preferredButton
	end

	return menuItem:FindFirstChildWhichIsA("GuiButton", true)
end

local function addMenuButton(button, targetName, visualRoot)
	if not button or table.find(buttons, button) then return end

	table.insert(buttons, button)
	buttonTargets[button] = targetName or button.Name
	buttonVisuals[button] = visualRoot or button
end

local function collectMenuButtons(container)
	for _, item in container:GetChildren() do
		if item:IsA("Folder") then
			collectMenuButtons(item)
		elseif item:IsA("GuiObject") then
			local hasDirectButton = item:IsA("GuiButton")
				or (item:FindFirstChild("Btn") and item.Btn:IsA("GuiButton"))
				or (item:FindFirstChild("Button") and item.Button:IsA("GuiButton"))

			if sideMenuActions[normalizeName(item.Name)] or hasDirectButton then
				addMenuButton(findButtonInMenuItem(item), item.Name, item)
			else
				collectMenuButtons(item)
			end
		end
	end
end

collectMenuButtons(sideMenu)

for _, uiElement in NewUI:GetChildren() do
	if persistentNewUIChildren[uiElement.Name] then continue end

	if isManagedMenuGuiObject(uiElement) then
		table.insert(buttonguis, uiElement)
	elseif uiElement:IsA("Folder") or uiElement:IsA("ScreenGui") then
		for _, frame in uiElement:GetChildren() do
			if isManagedMenuGuiObject(frame) then
				table.insert(buttonguis, frame)
			end
		end
	end
end

local legacyMenuPaths = {
	{ "CoreGameUI", "Areas", "AreasFrame" },
	{ "CoreGameUI", "Battlepass", "BattlepassFrame" },
	{ "CoreGameUI", "Quests", "QuestFrameEW" },
	{ "CoreGameUI", "Shop", "ShopFrame" },
	{ "CoreGameUI", "Summon", "SummonFrame" },
	{ "UnitsGui", "Inventory", "Units" },
}

local function findPlayerGuiPath(path)
	local current = PlayerGui

	for _, name in path do
		current = current and current:FindFirstChild(name)
		if not current then
			return nil
		end
	end

	return current
end

for _, path in legacyMenuPaths do
	local legacyFrame = findPlayerGuiPath(path)

	if legacyFrame and not table.find(buttonguis, legacyFrame) then
		table.insert(buttonguis, legacyFrame)
	end
end

local allFramesToCheck = {}
for _, v in ipairs(buttonguis) do table.insert(allFramesToCheck, v) end
for _, v in ipairs(othermenus) do table.insert(allFramesToCheck, v) end

for _, frame in ipairs(allFramesToCheck) do
	local closeBtnFolder = frame:FindFirstChild("Closebtn", true)

	if closeBtnFolder then
		local btn = closeBtnFolder:FindFirstChild("Btn")
		if btn and btn:IsA("GuiButton") and not btn:GetAttribute("CloseConnected") then
			btn:SetAttribute("CloseConnected", true)

			btn.Activated:Connect(function()
				if _G.Occupied then return end

				if prev then
					closeall(prev)
				else
					closeall()
				end
			end)
		end
	end
end

for i, v in buttonguis do
	v.Visible = false
	buttonguistatus[v.Name] = false

	v:GetPropertyChangedSignal("Visible"):Connect(function()
		if v.Visible then
			blur(false)
		else
			local otherVisible = false
			for i, checkFrame in buttonguis do
				if checkFrame.Visible then
					otherVisible = true
					break
				end
			end
			blur(false, otherVisible)
		end
	end)
end

for i, v in othermenus do
	v.Visible = false
	buttonguistatus[v.Name] = false

	v:GetPropertyChangedSignal("Visible"):Connect(function()
		if v.Visible then
			blur(true)
		else
			local otherVisible = false
			for i, checkFrame in buttonguis do
				if checkFrame.Visible then
					otherVisible = true
					break
				end
			end
			blur(false, otherVisible)
		end
	end)
end

for i, v in buttons do
	if v:IsA('GuiBase2d') then
		v.MouseEnter:Connect(function()
			UIHandlerModule.PlaySound("ButtonSwitch")

			local visualRoot = buttonVisuals[v] or v

			if visualRoot:FindFirstChild('Internal') then
				if visualRoot.Internal:FindFirstChild('Glow') then
					tween(visualRoot.Internal.Glow, 0.1, { ImageTransparency = 0 })
				end
			end
		end)
		v.MouseLeave:Connect(function()
			local visualRoot = buttonVisuals[v] or v

			if visualRoot:FindFirstChild('Internal') then
				if visualRoot.Internal:FindFirstChild("Glow") then
					tween(visualRoot.Internal.Glow, 0.1, { ImageTransparency = 0.5 })
				end
			end
		end)
	end
end

_G.CloseAll = closeall
_G.CloseAllEnabled = true

for _, element in openuionstart do
	if CanClaim() then
		closeall(element.Name)
	end
end

for i, v in buttons do
	if v:IsA("GuiButton") then
		v.Activated:Connect(function()
			if _G.CanSummon == false then
				return
			end

			local framename = resolveButtonTarget(v)
			local actionName = normalizeName(framename)
			local visualRoot = buttonVisuals[v] or v

			if v:GetAttribute("RequireTransition") or visualRoot:GetAttribute("RequireTransition") then
				UIHandlerModule.Transition()
				task.wait(1)
			end

			local character = player.Character

			if actionName == "summon" then
				debugSummonMenu("menuButton:summon", "button=" .. tostring(v.Name), "framename=" .. tostring(framename))
				if character then
					character:PivotTo(workspace.SummonTeleporters.Teleport.CFrame)
				end
				closeall()
				return
			elseif actionName == "play" then
				if character then
					character:PivotTo(workspace.PlayTeleport.Teleporter.CFrame)
				end
				closeall()
				return
			end

			closeall(framename)
		end)
	end
end
