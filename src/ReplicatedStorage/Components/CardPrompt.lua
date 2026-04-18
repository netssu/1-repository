local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Trove = require(ReplicatedStorage.Packages.Trove)
local Packs = require(ReplicatedStorage.UserInterface.Packs)

local LocalPlayer = RunService:IsClient() and Players.LocalPlayer or nil

local CARD_COLORS = {
	Cosmetics = Color3.fromRGB(255, 60, 60),
	Emotes = Color3.fromRGB(255, 249, 87),
	Player = Color3.fromRGB(250, 99, 255),
}

local HOVER_HEIGHT_OFFSET = 0.5
local HEIGHT_LERP_SPEED = 12
local ROTATION_SPEED = math.rad(120)

local module = {}
module.__index = module

module.Tag = script.Name

type self = {
	Trove: any,
	CardModel: Model,
	MeshPart: MeshPart,
	OriginalCFrame: CFrame,
	Highlight: Highlight?,
	IsHovering: boolean,
	TargetHeightOffset: number,
	CurrentHeightOffset: number,
	RotationAngle: number,
}

type CardPrompt = typeof(setmetatable({} :: self, module))

local function ResolveCardType(cardModel: Model): string
	local modelName = cardModel.Name
	if modelName == "Cosmetics" then
		return "Cosmetics"
	end
	if modelName == "Emotes" then
		return "Emotes"
	end
	if modelName == "Player" then
		return "Player"
	end

	error(`[CardPrompt]: Unknown card model name '{modelName}'. Expected 'Cosmetics', 'Emotes', or 'Player'.`)
end

function module.new(instance: ProximityPrompt): CardPrompt
	local cardModel = instance.Parent and instance.Parent.Parent
	local cardMesh = instance.Parent

	if not cardModel or not cardModel:IsA("Model") then
		error(`[CardPrompt]: Expected ProximityPrompt parent to be a Model, got {cardModel and cardModel.ClassName or "nil"}`)
	end

	if not cardMesh or not cardMesh:IsA("MeshPart") then
		error(`[CardPrompt]: Expected ProximityPrompt parent to be a MeshPart, got {cardMesh and cardMesh.ClassName or "nil"}`)
	end

	local cardType = ResolveCardType(cardModel)
	local self = setmetatable({} :: self, module)
	local trove = Trove.new()

	self.CardModel = cardModel
	self.MeshPart = cardMesh
	self.OriginalCFrame = cardMesh.CFrame
	self.Highlight = nil
	self.IsHovering = false
	self.TargetHeightOffset = 0
	self.CurrentHeightOffset = 0
	self.RotationAngle = 0

	local highlight = Instance.new("Highlight")
	highlight.Name = "CardHighlight"
	highlight.FillColor = CARD_COLORS[cardType]
	highlight.OutlineColor = CARD_COLORS[cardType]
	highlight.FillTransparency = 0.7
	highlight.OutlineTransparency = 0.3
	highlight.Enabled = false
	highlight.Parent = cardModel

	self.Highlight = highlight
	trove:Add(highlight)

	trove:Connect(instance.Triggered, function(whoTriggered: Player)
		if not RunService:IsClient() then
			return
		end
		if whoTriggered ~= LocalPlayer then
			return
		end

		Packs.PlaySummonAnimation(cardType)
	end)

	if RunService:IsClient() then
		trove:Connect(RunService.RenderStepped, function(deltaTime: number)
			local alpha = 1 - math.exp(-math.max(deltaTime, 0) * HEIGHT_LERP_SPEED)
			self.CurrentHeightOffset += (self.TargetHeightOffset - self.CurrentHeightOffset) * alpha
			self.RotationAngle = (self.RotationAngle + ROTATION_SPEED * deltaTime) % (math.pi * 2)
			cardMesh.CFrame = self.OriginalCFrame
				* CFrame.new(0, self.CurrentHeightOffset, 0)
				* CFrame.Angles(0, self.RotationAngle, 0)
		end)

		trove:Connect(instance.PromptShown, function()
			self.IsHovering = true
			self.TargetHeightOffset = HOVER_HEIGHT_OFFSET
			highlight.Enabled = true
		end)

		trove:Connect(instance.PromptHidden, function()
			self.IsHovering = false
			self.TargetHeightOffset = 0
			highlight.Enabled = false
		end)
	end

	self.Trove = trove

	return self
end

function module.Destroy(self: CardPrompt): ()
	self.MeshPart.CFrame = self.OriginalCFrame
	self.Trove:Destroy()
end

return module
