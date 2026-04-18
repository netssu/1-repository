local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiController = require(ReplicatedStorage.Controllers.GuiController)
local SoundController = require(ReplicatedStorage.Controllers.SoundController)
local Trove = require(ReplicatedStorage.Packages.Trove)

local INFO_HOVER  = TweenInfo.new(0.18, Enum.EasingStyle.Sine,  Enum.EasingDirection.Out)
local INFO_LEAVE  = TweenInfo.new(0.22, Enum.EasingStyle.Sine,  Enum.EasingDirection.Out)
local INFO_CLICK  = TweenInfo.new(0.10, Enum.EasingStyle.Sine,  Enum.EasingDirection.Out)
local INFO_BOUNCE = TweenInfo.new(0.28, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)
local INFO_ICON   = TweenInfo.new(0.22, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)

-- Multiplicador de UDim2 preservando Scale e Offset
local function scaleSize(base: UDim2, factor: number): UDim2
	return UDim2.new(
		base.X.Scale  * factor, base.X.Offset * factor,
		base.Y.Scale  * factor, base.Y.Offset * factor
	)
end

local HOVER_COLOR  = Color3.fromRGB(0,0,0)
local _NORMAL_COLOR = Color3.fromRGB(255, 255, 255) 

local module = {}
module.__index = module
module.Tag = script.Name

type self = {
	Trove: Trove.Trove,
}
type UIAnimation = typeof(setmetatable({} :: self, module))

local cache = {}

function module.new(instance: GuiObject): UIAnimation
	if not instance:IsA("GuiObject") then
		error(`Expected type GuiObject, got {instance.ClassName}.`)
	end
	if cache[instance] then
		warn(`Instance: {instance.Name}, already have animations`)
		return
	end
	cache[instance] = true

	local self = setmetatable({} :: self, module)
	local mainTrove = Trove.new()

	mainTrove:Add(function()
		cache[instance] = nil
	end)

	local oldSize     = instance.Size
	local baseColor   = instance.BackgroundColor3
	local hoverColor  = baseColor:Lerp(HOVER_COLOR, 0.12) 

	mainTrove:Connect(instance.MouseEnter, function()
		TweenService:Create(instance, INFO_HOVER, {
			Size              = scaleSize(oldSize, 1.08),
			BackgroundColor3  = hoverColor,
		}):Play()

		local icon = instance:FindFirstChild("Icon")
		if icon then
			TweenService:Create(icon, INFO_ICON, { Rotation = 12 }):Play()
		end

		SoundController:PlayUiHover()
	end)

	local function onMouseLeave()
		TweenService:Create(instance, INFO_LEAVE, {
			Size             = oldSize,
			BackgroundColor3 = baseColor,
		}):Play()

		local icon = instance:FindFirstChild("Icon")
		if icon then
			TweenService:Create(icon, INFO_LEAVE, { Rotation = 0 }):Play()
		end
	end
	mainTrove:Connect(instance.MouseLeave, onMouseLeave)

	local link = instance:GetAttribute("Link")
	if link then
		if CollectionService:HasTag(instance, "GuiButton") then
			mainTrove:Add(
				GuiController.GuiOpened:Connect(function(guiName)
					if guiName ~= link then return end
					onMouseLeave()
				end),
				"Disconnect"
			)
		elseif CollectionService:HasTag(instance, "CloseButton") then
			mainTrove:Add(
				GuiController.GuiClosed:Connect(function(guiName)
					if guiName ~= link then return end
					onMouseLeave()
				end),
				"Disconnect"
			)
		end
	end

	if instance:IsA("GuiButton") then
		mainTrove:Connect(instance.MouseButton1Down, function()
			TweenService:Create(instance, INFO_CLICK, {
				Size = scaleSize(oldSize, 0.88),
			}):Play()
		end)

		mainTrove:Connect(instance.MouseButton1Up, function()
			TweenService:Create(instance, INFO_BOUNCE, {
				Size = scaleSize(oldSize, 1.08),
			}):Play()
		end)

		mainTrove:Connect(instance.MouseButton1Click, function()
			SoundController:Play("Select")
		end)

	else
		mainTrove:Connect(instance.InputBegan, function(input)
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then return end

			TweenService:Create(instance, INFO_CLICK, {
				Size = scaleSize(oldSize, 0.90),
			}):Play()
			SoundController:Play("Select")
		end)

		mainTrove:Connect(instance.InputEnded, function(input)
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then return end

			TweenService:Create(instance, INFO_BOUNCE, {
				Size = scaleSize(oldSize, 1.08),
			}):Play()
		end)
	end

	self.Trove = mainTrove
	return self
end

function module.Destroy(self: UIAnimation): ()
	self.Trove:Destroy()
end

return module
