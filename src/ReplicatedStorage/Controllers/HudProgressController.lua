--!strict

local HudProgressController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Trove = require(ReplicatedStorage.Packages.Trove)
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)

local GachaGuiUtil = require(ReplicatedStorage.Controllers.GachaGuiUtil)
local SoundController = require(ReplicatedStorage.Controllers.SoundController)
local ProgressionUtil = require(ReplicatedStorage.Modules.Game.ProgressionUtil)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui

local HOVER_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ORNAMENT_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HOVER_OFFSET_Y = -8
local ORNAMENT_OFFSET_X = 6
local ORNAMENT_SCALE = 1.04

type HoverState = {
	Button: GuiButton?,
	ButtonOriginalPosition: UDim2?,
	LeftOrnament: GuiObject?,
	LeftOriginalPosition: UDim2?,
	LeftOriginalSize: UDim2?,
	RightOrnament: GuiObject?,
	RightOriginalPosition: UDim2?,
	RightOriginalSize: UDim2?,
}

type ControllerState = {
	Trove: any,
	HoverTrove: any?,
	HoverState: HoverState,
	HudGui: ScreenGui?,
	MoneyLabel: TextLabel?,
	ExperienceLevelLabel: TextLabel?,
	ExpRequirementLabel: TextLabel?,
	OffsetTarget: Instance?,
}

local State: ControllerState = {
	Trove = nil,
	HoverTrove = nil,
	HoverState = {},
	HudGui = nil,
	MoneyLabel = nil,
	ExperienceLevelLabel = nil,
	ExpRequirementLabel = nil,
	OffsetTarget = nil,
}

local function findTextLabel(root: Instance?, names: {string}): TextLabel?
	local found = GachaGuiUtil.FindDescendantByNames(root, names, "TextLabel")
	return if found and found:IsA("TextLabel") then found else nil
end

local function findGuiButton(root: Instance?, names: {string}): GuiButton?
	local found = GachaGuiUtil.FindDescendantByNames(root, names, "GuiButton")
	return if found and found:IsA("GuiButton") then found else nil
end

local function findGuiObject(root: Instance?, names: {string}): GuiObject?
	local found = GachaGuiUtil.FindDescendantByNames(root, names, nil)
	return if found and found:IsA("GuiObject") then found else nil
end

local function offsetPosition(position: UDim2, xOffset: number, yOffset: number): UDim2
	return UDim2.new(position.X.Scale, position.X.Offset + xOffset, position.Y.Scale, position.Y.Offset + yOffset)
end

local function scaleSize(size: UDim2, factor: number): UDim2
	return UDim2.new(
		size.X.Scale * factor,
		math.round(size.X.Offset * factor),
		size.Y.Scale * factor,
		math.round(size.Y.Offset * factor)
	)
end

local function playTween(target: Instance, info: TweenInfo, goals: {[string]: any}): ()
	TweenService:Create(target, info, goals):Play()
end

local function applyHoverVisual(isHovered: boolean, instant: boolean?): ()
	local hoverState = State.HoverState
	local button = hoverState.Button
	local buttonOriginalPosition = hoverState.ButtonOriginalPosition

	if button and buttonOriginalPosition then
		local buttonTarget = if isHovered
			then offsetPosition(buttonOriginalPosition, 0, HOVER_OFFSET_Y)
			else buttonOriginalPosition

		if instant then
			button.Position = buttonTarget
		else
			playTween(button, HOVER_INFO, { Position = buttonTarget })
		end
	end

	local function animateOrnament(
		ornament: GuiObject?,
		originalPosition: UDim2?,
		originalSize: UDim2?,
		direction: number
	): ()
		if not ornament or not originalPosition or not originalSize then
			return
		end

		local targetPosition = if isHovered
			then offsetPosition(originalPosition, ORNAMENT_OFFSET_X * direction, 0)
			else originalPosition
		local targetSize = if isHovered then scaleSize(originalSize, ORNAMENT_SCALE) else originalSize

		if instant then
			ornament.Position = targetPosition
			ornament.Size = targetSize
		else
			playTween(ornament, ORNAMENT_INFO, {
				Position = targetPosition,
				Size = targetSize,
			})
		end
	end

	animateOrnament(hoverState.LeftOrnament, hoverState.LeftOriginalPosition, hoverState.LeftOriginalSize, -1)
	animateOrnament(hoverState.RightOrnament, hoverState.RightOriginalPosition, hoverState.RightOriginalSize, 1)
end

local function bindHover(button: GuiButton?, leftOrnament: GuiObject?, rightOrnament: GuiObject?): ()
	if State.HoverState.Button == button
		and State.HoverState.LeftOrnament == leftOrnament
		and State.HoverState.RightOrnament == rightOrnament
	then
		return
	end

	if State.HoverTrove then
		State.HoverTrove:Destroy()
		State.HoverTrove = nil
	end

	State.HoverState = {
		Button = button,
		ButtonOriginalPosition = if button then button.Position else nil,
		LeftOrnament = leftOrnament,
		LeftOriginalPosition = if leftOrnament then leftOrnament.Position else nil,
		LeftOriginalSize = if leftOrnament then leftOrnament.Size else nil,
		RightOrnament = rightOrnament,
		RightOriginalPosition = if rightOrnament then rightOrnament.Position else nil,
		RightOriginalSize = if rightOrnament then rightOrnament.Size else nil,
	}

	if not button then
		return
	end

	local hoverTrove = Trove.new()
	State.HoverTrove = hoverTrove

	applyHoverVisual(false, true)

	hoverTrove:Add(button.MouseEnter:Connect(function()
		SoundController:PlayUiHover()
		applyHoverVisual(true, false)
	end), "Disconnect")

	hoverTrove:Add(button.MouseLeave:Connect(function()
		applyHoverVisual(false, false)
	end), "Disconnect")

	hoverTrove:Add(button.AncestryChanged:Connect(function()
		if button.Parent == nil then
			applyHoverVisual(false, true)
		end
	end), "Disconnect")
end

local function resolveUi(): boolean
	local hudGui = PlayerGui:FindFirstChild("HudGui")
	if not hudGui or not hudGui:IsA("ScreenGui") then
		State.HudGui = nil
		State.MoneyLabel = nil
		State.ExperienceLevelLabel = nil
		State.ExpRequirementLabel = nil
		State.OffsetTarget = nil
		bindHover(nil, nil, nil)
		return false
	end

	local moneyBar = GachaGuiUtil.FindDescendantByNames(hudGui, { "MoneyBar" }, nil)
	local experienceBar = GachaGuiUtil.FindDescendantByNames(hudGui, { "ExperienceBar" }, nil)
	local visualBar = GachaGuiUtil.FindDescendantByNames(experienceBar, { "VisualBar" }, nil)

	State.HudGui = hudGui
	State.MoneyLabel = findTextLabel(moneyBar, { "CurrentLevel" })
	State.ExperienceLevelLabel = findTextLabel(experienceBar, { "CurrentLevel" })
	State.ExpRequirementLabel = findTextLabel(experienceBar, { "EXPRequirement", "ExpRequirement" })
	State.OffsetTarget = GachaGuiUtil.FindDescendantByNames(visualBar, { "AdjustThisOffset" }, nil)

	bindHover(
		findGuiButton(experienceBar, { "ImageButton" }),
		findGuiObject(experienceBar, { "Ornament#1", "Ornament1" }),
		findGuiObject(experienceBar, { "Ornament#2", "Ornament2" })
	)

	return true
end

local function updateMoney(): ()
	if not resolveUi() then
		return
	end

	local moneyLabel = State.MoneyLabel
	if not moneyLabel then
		return
	end

	local currentYen = tonumber(PlayerDataManager:Get(LocalPlayer, { "Yen" })) or 0
	moneyLabel.Text = GachaGuiUtil.FormatMoney(math.max(0, math.floor(currentYen)))
end

local function updateProgress(): ()
	if not resolveUi() then
		return
	end

	local levelLabel = State.ExperienceLevelLabel
	local expRequirementLabel = State.ExpRequirementLabel
	local offsetTarget = State.OffsetTarget

	local currentLevel = ProgressionUtil.NormalizeLevel(PlayerDataManager:Get(LocalPlayer, { "Level" }))
	local currentExp = ProgressionUtil.NormalizeExp(PlayerDataManager:Get(LocalPlayer, { "Exp" }))
	local requiredExp = ProgressionUtil.GetRequiredExpForLevel(currentLevel)
	local normalizedProgress = if requiredExp > 0 then math.clamp(currentExp / requiredExp, 0, 1) else 0

	if levelLabel then
		levelLabel.Text = string.format("LEVEL %d", currentLevel)
	end

	if expRequirementLabel then
		expRequirementLabel.Text = string.format(
			"%s/%s",
			GachaGuiUtil.FormatMoney(currentExp),
			GachaGuiUtil.FormatMoney(requiredExp)
		)
	end

	if offsetTarget then
		pcall(function()
			(offsetTarget :: any).Offset = Vector2.new(normalizedProgress, 0)
		end)
	end
end

local function refreshAll(): ()
	updateMoney()
	updateProgress()
end

function HudProgressController:Start()
	if State.Trove then
		return
	end

	State.Trove = Trove.new()

	State.Trove:Add(PlayerGui.DescendantAdded:Connect(function(child: Instance)
		if child.Name ~= "HudGui" then
			return
		end

		task.defer(refreshAll)
		task.delay(0.25, refreshAll)
	end), "Disconnect")

	State.Trove:Add(PlayerGui.DescendantAdded:Connect(function(descendant: Instance)
		local hudGui = State.HudGui or PlayerGui:FindFirstChild("HudGui")
		if not hudGui or not descendant:IsDescendantOf(hudGui) then
			return
		end

		if descendant.Name == "MoneyBar"
			or descendant.Name == "ExperienceBar"
			or descendant.Name == "CurrentLevel"
			or descendant.Name == "EXPRequirement"
			or descendant.Name == "AdjustThisOffset"
			or descendant.Name == "ImageButton"
			or descendant.Name == "Ornament#1"
			or descendant.Name == "Ornament#2"
		then
			task.defer(refreshAll)
		end
	end), "Disconnect")

	local yenSignal = PlayerDataManager:GetValueChangedSignal(LocalPlayer, { "Yen" })
	State.Trove:Add(yenSignal:Connect(updateMoney), "Disconnect")

	local levelSignal = PlayerDataManager:GetValueChangedSignal(LocalPlayer, { "Level" })
	State.Trove:Add(levelSignal:Connect(updateProgress), "Disconnect")

	local expSignal = PlayerDataManager:GetValueChangedSignal(LocalPlayer, { "Exp" })
	State.Trove:Add(expSignal:Connect(updateProgress), "Disconnect")

	task.defer(refreshAll)
	task.delay(0.25, refreshAll)
end

return HudProgressController
