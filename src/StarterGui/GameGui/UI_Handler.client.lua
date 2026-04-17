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

local buttons = {}
local buttonguis = {}
local blacklist = { NewUI:WaitForChild("HUDButtons") }
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

local function selectInstanceFromString(except)
	local foundInstance = nil

	for i, v in pairs(buttonguis) do
		if v.Name == except then
			foundInstance = v
			break
		end
	end

	if not foundInstance then
		for i, v in pairs(othermenus) do
			if v.Name == except then
				foundInstance = v
				break
			end
		end
	end

	return foundInstance
end

local function closeall(except, dontOverride)
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

local hudButtons = NewUI:WaitForChild("HUDButtons")
for _, panel in hudButtons:GetChildren() do
	if panel:IsA("Folder") or panel:IsA("Frame") then
		for _, btn in panel:GetChildren() do
			if btn:IsA("GuiBase2d") then
				table.insert(buttons, btn)
			end
		end
	elseif panel:IsA("GuiBase2d") then
		table.insert(buttons, panel)
	end
end

for _, uiElement in NewUI:GetChildren() do
	if table.find(blacklist, uiElement) then continue end

	if uiElement:IsA("Frame") or uiElement:IsA("ScrollingFrame") then
		table.insert(buttonguis, uiElement)
	elseif uiElement:IsA("Folder") or uiElement:IsA("ScreenGui") then
		for _, frame in uiElement:GetChildren() do
			if frame:IsA("Frame") or frame:IsA("ScrollingFrame") then
				table.insert(buttonguis, frame)
			end
		end
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

			if v:FindFirstChild('Internal') then
				if v.Internal:FindFirstChild('Glow') then
					tween(v.Internal.Glow, 0.1, { ImageTransparency = 0 })
				end
			end
		end)
		v.MouseLeave:Connect(function()
			if v:FindFirstChild('Internal') then
				if v.Internal:FindFirstChild("Glow") then
					tween(v.Internal.Glow, 0.1, { ImageTransparency = 0.5 })
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
	if v:IsA("ImageButton") then
		v.Activated:Connect(function()
			if _G.CanSummon == false then
				return
			end

			local framename = v.Name

			if v:GetAttribute("RequireTransition") then
				UIHandlerModule.Transition()
				task.wait(1)
			end
			local character = player.Character

			local check = framename

			if check ~= 'Units' then
				if not (NewUI:FindFirstChild(framename) or NewUI:FindFirstChild(framename, true)) then
					check = check .. 'Frame'
				end
			end

			if buttonguistatus[check] == false or buttonguistatus[framename] == false then
				if string.match(v.Name, "Summon") then
					if character then
						character:PivotTo(workspace.SummonTeleporters.Teleport.CFrame)
					end
				else
					closeall(framename)
				end
			elseif string.match(v.Name, "Play") then
				if character then
					character:PivotTo(workspace.PlayTeleport.Teleporter.CFrame)
					closeall()
				end
			else
				UIHandlerModule.PlaySound("Close")

				if NewUI:FindFirstChild(v.Name) then
					closeall(v.Name, true)
				else
					closeall()
				end
			end
		end)
	end
end