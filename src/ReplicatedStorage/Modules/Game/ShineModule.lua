local TweenService = game:GetService("TweenService")
local rep = game:GetService("ReplicatedStorage")
local assets = rep:WaitForChild("Assets")
local UI = assets:WaitForChild("UI")
local Shimmer = UI:FindFirstChild("Shimmer") 

local ShineModule = {}

function ShineModule.Animate(arg1, arg2)
	local ShimmerImage_2 = arg1:FindFirstChild("ShimmerImage")
	if ShimmerImage_2 then
		ShimmerImage_2.Visible = true
	end
	local var11 = ShimmerImage_2
	if not var11 then
		var11 = arg2._trove:Add(Shimmer:Clone())
	end

	local rarityGradientName = arg2.additional_params.rarity or "Common"
	local SOME_upvr_2 = var11:FindFirstChild(rarityGradientName)

	if not SOME_upvr_2 then
		SOME_upvr_2 = var11:FindFirstChild(arg2.additional_params.OverrideGrad or "UIGradient")
	end

	if not SOME_upvr_2 then
		return
	end

	var11.Parent = arg1
	SOME_upvr_2.Enabled = true
	local var13_upvr = arg2.additional_params.tweenDuration or 2
	local class_ScreenGui = arg1:FindFirstAncestorOfClass("ScreenGui")
	if not class_ScreenGui then
		class_ScreenGui = arg1:FindFirstAncestorOfClass("BillboardGui")
		if not class_ScreenGui then
			class_ScreenGui = arg1:FindFirstAncestorOfClass("SurfaceGui")
		end
	end
	if class_ScreenGui.Enabled then
		(function()
			SOME_upvr_2.Offset = Vector2.new(-1, 0)
			arg2._trove:Add(TweenService:Create(SOME_upvr_2, TweenInfo.new(var13_upvr, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {
				Offset = Vector2.new(1, 0);
			})):Play()
		end)()
	end
	task.wait(arg2.additional_params.shimmerDelay or 1)
end

return ShineModule