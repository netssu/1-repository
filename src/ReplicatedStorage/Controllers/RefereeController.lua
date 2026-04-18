local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local AnimationController = require(ReplicatedStorage.Controllers.AnimationController)

local FTRefereeController = {}

local refereeInstance: Model? = nil
local lastAnimCheck = 0
local ANIM_INTERVAL = 0.1
local MOVE_THRESHOLD = 1.5
local lastMoving = false
local requestConn: RBXScriptConnection? = nil

local function UpdateRunAnimation(): ()
	if not refereeInstance then return end
	local humanoid = refereeInstance:FindFirstChildOfClass("Humanoid")
	local root = refereeInstance:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then return end

	local now = os.clock()
	if now - lastAnimCheck < ANIM_INTERVAL then
		return
	end
	lastAnimCheck = now

	local velocity = root.AssemblyLinearVelocity
	local planarSpeed = Vector2.new(velocity.X, velocity.Z).Magnitude
	local moving = planarSpeed > MOVE_THRESHOLD

	if moving ~= lastMoving then
		if moving then
			AnimationController.PlayAnimationForModel(refereeInstance, "Run", {
				Looped = true,
				Priority = Enum.AnimationPriority.Movement,
				FadeTime = 0.1,
			})
		else
			AnimationController.StopAnimationForModel(refereeInstance, "Run", 0.15)
		end
		lastMoving = moving
	end
end

local function OnHeartbeat(): ()
	if not refereeInstance or not refereeInstance.Parent then
		refereeInstance = Workspace:FindFirstChild("Game", true) and Workspace.Game:FindFirstChild("Referee")
		if refereeInstance and requestConn then
			requestConn:Disconnect()
			requestConn = nil
		end
		if refereeInstance then
			requestConn = refereeInstance:GetAttributeChangedSignal("RequestBall"):Connect(function()
				if refereeInstance:GetAttribute("RequestBall") == true then
					AnimationController.PlayAnimationForModel(refereeInstance, "Request Ball", {
						Looped = false,
						Priority = Enum.AnimationPriority.Action,
						FadeTime = 0.1,
					})
				end
			end)
		end
	end
	
	if refereeInstance then
		UpdateRunAnimation()
	end
end

function FTRefereeController.Init(_self: typeof(FTRefereeController)): ()
	RunService.Heartbeat:Connect(OnHeartbeat)
end

function FTRefereeController.Start(_self: typeof(FTRefereeController)): ()
end

return FTRefereeController
