local Model:Model = GetUnitModel[game.Workspace.CurrentHour:GetAttribute(Rarity)]:Clone()
local Scale = Model:GetScale()
Model:ScaleTo(Scale * ScaleMulti)
local HRP = Model:WaitForChild("HumanoidRootPart")
local Humanoid:Humanoid = Model:WaitForChild("Humanoid")
local animations = Model:FindFirstChild("Animations")
HRP.Anchored = true
if HRP and Humanoid then
	pcall(function()

		HRP.CFrame = SummonNPC[Rarity]:WaitForChild("PositionPart").CFrame
		Model.Parent = SummonNPC[Rarity].Unit
		local animator = Humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", Humanoid)

		if animations then
			local track = animator:LoadAnimation(Model.Animations.Idle)
			track:Play()
			track:Destroy()
		end
	end)
end