local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animages = ReplicatedStorage:WaitForChild("Animages")
local Animage = require(ReplicatedStorage:WaitForChild("Animage"))

local Tag = "Animage"

local Attribute1 = "Holder"
local Attribute2 = "SpriteSheet"

local function AnimageAdded(Target)
	if typeof(Target) ~= "Instance" then
		return
	end
	
	local Holder = Target:GetAttribute(Attribute1)
	if Holder then
		Holder = Animages:FindFirstChild(Holder)
	end
	
	if Target:FindFirstAncestorOfClass("StarterGui") then
		return
	end
	
	
	local FPS = 8
	
	local Anim = Animage.new(Target, Holder)
	Anim:Play(FPS)
end

local function AnimageRemoved(Target)
	
end


for _, Target in CollectionService:GetTagged(Tag) do
	task.spawn(AnimageAdded, Target)
end

CollectionService:GetInstanceAddedSignal(Tag):Connect(AnimageAdded)