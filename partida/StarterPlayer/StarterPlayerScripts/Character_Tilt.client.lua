--!nocheck
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MOMENTUM_FACTOR = 0.008
local SPEED = 15

local Enabled = false
local CharacterAddedConns = {}
local CharacterUpdateConns = {}

local function Setup(char)
	local hum = char:WaitForChild("Humanoid")
	local root = char:WaitForChild("HumanoidRootPart")
	local m6d = (hum.RigType == Enum.HumanoidRigType.R15) and char.LowerTorso.Root or root.RootJoint
	local baseC0 = m6d.C0

	local function destroy()
		local conn = CharacterUpdateConns[char]
		if conn then
			conn:Disconnect()
			CharacterUpdateConns[char] = nil
		end
	end

	char.Destroying:Once(destroy)

	CharacterUpdateConns[char] = RunService.RenderStepped:Connect(function(dt)
		local moveDir = root.CFrame:VectorToObjectSpace(hum.MoveDirection)
		local vel = root.CFrame:VectorToObjectSpace(root.Velocity) * MOMENTUM_FACTOR

		local mx = math.abs(vel.X)
		local mz = math.abs(vel.Z)

		local x = moveDir.X * mx
		local z = moveDir.Z * mz

		local angles = (hum.RigType == Enum.HumanoidRigType.R15) and { z, 0, -x } or { -z, -x, 0 }
		m6d.C0 = m6d.C0:Lerp(baseC0 * CFrame.Angles(angles[1], angles[2], angles[3]), dt * SPEED)
	end)
end

local function Enable()
	if Enabled then return end
	Enabled = true

	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			Setup(p.Character)
		end
		table.insert(CharacterAddedConns, p.CharacterAdded:Connect(Setup))
	end

	table.insert(CharacterAddedConns, Players.PlayerAdded:Connect(function(p)
		if not Enabled then return end
		table.insert(CharacterAddedConns, p.CharacterAdded:Connect(Setup))
	end))
end

local function Disable()
	if not Enabled then return end
	Enabled = false

	for i = #CharacterAddedConns, 1, -1 do
		CharacterAddedConns[i]:Disconnect()
		CharacterAddedConns[i] = nil
	end

	for char, conn in pairs(CharacterUpdateConns) do
		conn:Disconnect()
		CharacterUpdateConns[char] = nil
	end
end

Enable()
