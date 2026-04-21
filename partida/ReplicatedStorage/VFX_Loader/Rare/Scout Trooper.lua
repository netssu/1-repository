local module = {}
local rs = game:GetService("ReplicatedStorage")
local Effects = rs.VFX
local vfxFolder = workspace.VFX
local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local VFX = rs.VFX
local VFX_Helper = require(rs.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed

function cubicBezier(t, p0, p1, p2, p3)
	return (1 - t)^3*p0 + 3*(1 - t)^2*t*p1 + 3*(1 - t)*t^2*p2 + t^3*p3
end

module["Grenade Attack"] = function(HRP, target)
	local Folder = VFX.RAR["Scout Trooper"].First
	local speed = GameSpeed.Value
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)
	task.wait(0.77/speed)
	if not HRP or not HRP.Parent then return end
	VFX_Helper.SoundPlay(HRP,Folder.Sound)

	task.wait(0.13/speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true

	local granata = HRP.Parent["Right Arm"].Handle
	
	local grenadeClone = granata:Clone()
	grenadeClone.Parent = HRP	
	grenadeClone.CFrame = granata.CFrame
	
	
	local function makeTransparent(part)
		if part:IsA("BasePart") then
			part.Transparency = 1
		end
		for _, child in ipairs(part:GetChildren()) do
			makeTransparent(child)
		end
	end
	makeTransparent(granata)
	
	local End = CFrame.new(enemypos)
	local Start	= HRP.CFrame
	local Middle = CFrame.new((Start.Position + End.Position) / 2 + Vector3.new(0,2,0))
	local Middle2 = CFrame.new((Start.Position + End.Position) / 2 + Vector3.new(0,2,0))

	for i = 1, 102, 6  do
		local t = i/100
		local NewPos = cubicBezier(t, Start.Position, Middle.Position, Middle2.Position, End.Position)
		grenadeClone.CFrame = CFrame.new(NewPos)
		task.wait(0.01/speed)
	end
	
	local EXPL = Folder:WaitForChild("Explosion"):Clone()
	EXPL.Position = enemypos
	EXPL.Parent = HRP
	Debris:AddItem(EXPL,2/speed)
	VFX_Helper.EmitAllParticles(EXPL)
	task.wait(0.5)
	if not HRP or not HRP.Parent then return end
	local function restoreTransparency(part)
		if part:IsA("BasePart") then
			part.Transparency = 0
		end
		for _, child in ipairs(part:GetChildren()) do
			restoreTransparency(child)
		end
	end
	restoreTransparency(granata)
	task.wait(0.2)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = false
end


return module
