--!strict

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace: Workspace = game:GetService("Workspace")

local FTConfig = require(ReplicatedStorage.Modules.Game.Config)
local Utility = require(ReplicatedStorage.Modules.Game.Utility)

local ThrowAimResolver = {}

local MIN_DIRECTION_MAGNITUDE: number = 1e-4
local DEFAULT_DIRECTION: Vector3 = Vector3.new(0, 0, -1)

local function GetCampo(): Instance?
	local GameFolder: Instance? = Workspace:FindFirstChild("Game")
	if not GameFolder then
		return nil
	end
	return GameFolder:FindFirstChild("Campo")
end

local function GetCampoPlaneY(Campo: Instance): number?
	if Campo:IsA("BasePart") then
		return Campo.Position.Y + (Campo.Size.Y * 0.5)
	end
	if Campo:IsA("Model") then
		local CFrameValue: CFrame, Size: Vector3 = Campo:GetBoundingBox()
		return CFrameValue.Position.Y + (Size.Y * 0.5)
	end
	return nil
end

local function GetAimOrigin(Player: Player): Vector3?
	local Character: Model? = Player.Character
	if not Character then
		return nil
	end
	local RightArm: BasePart? = Character:FindFirstChild("Right Arm") :: BasePart?
	if not RightArm then
		RightArm = Character:FindFirstChild("RightHand") :: BasePart?
	end
	if not RightArm then
		RightArm = Character:FindFirstChild("RightLowerArm") :: BasePart?
	end
	if not RightArm then
		RightArm = Character:FindFirstChild("RightUpperArm") :: BasePart?
	end
	if RightArm then
		return RightArm.Position
	end
	local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return Root and Root.Position or nil
end

local function GetMouseRay(Player: Player): (Vector3?, Vector3?)
	local Camera: Camera? = Workspace.CurrentCamera
	if not Camera then
		return nil
	end
	local Mouse = Player:GetMouse()
	local Ray = Camera:ViewportPointToRay(Mouse.X, Mouse.Y)
	local Direction: Vector3 = Ray.Direction.Magnitude > MIN_DIRECTION_MAGNITUDE and Ray.Direction.Unit
		or DEFAULT_DIRECTION
	return Ray.Origin, Direction
end

local function RaycastCampo(RayOrigin: Vector3, Direction: Vector3, MaxDistance: number, Campo: Instance): Vector3?
	local Params: RaycastParams = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = { Campo }
	local Result: RaycastResult? = Workspace:Raycast(RayOrigin, Direction * MaxDistance, Params)
	return Result and Result.Position or nil
end

local function ResolveFallbackTarget(
	Origin: Vector3,
	Direction: Vector3,
	MaxDistance: number,
	Campo: Instance
): Vector3?
	local PlaneY: number? = GetCampoPlaneY(Campo)
	if PlaneY == nil then
		return nil
	end

	if math.abs(Direction.Y) > MIN_DIRECTION_MAGNITUDE then
		local PlaneDistance: number = (PlaneY - Origin.Y) / Direction.Y
		if PlaneDistance > 0 and PlaneDistance <= MaxDistance then
			return Vector3.new(
				Origin.X + (Direction.X * PlaneDistance),
				PlaneY,
				Origin.Z + (Direction.Z * PlaneDistance)
			)
		end
	end

	local PlanarDirection: Vector3 = Vector3.new(Direction.X, 0, Direction.Z)
	if PlanarDirection.Magnitude < MIN_DIRECTION_MAGNITUDE then
		PlanarDirection = DEFAULT_DIRECTION
	else
		PlanarDirection = PlanarDirection.Unit
	end

	local Target: Vector3 = Origin + (PlanarDirection * MaxDistance)
	return Vector3.new(Target.X, PlaneY, Target.Z)
end

function ThrowAimResolver.ResolveCurrentTarget(Player: Player?, MaxDistance: number?): Vector3?
	local ActivePlayer: Player? = Player or Players.LocalPlayer
	if not ActivePlayer then
		return nil
	end

	local Campo: Instance? = GetCampo()
	if not Campo then
		return nil
	end

	local Origin: Vector3? = GetAimOrigin(ActivePlayer)
	if not Origin then
		return nil
	end

	local DistanceLimit: number =
		math.max(MaxDistance or FTConfig.THROW_CONFIG.MaxAimDistance, FTConfig.THROW_CONFIG.MinAimDistance)
	local RayOrigin: Vector3?, Direction: Vector3? = GetMouseRay(ActivePlayer)
	if not RayOrigin or not Direction then
		return nil
	end

	local HitPosition: Vector3? = RaycastCampo(RayOrigin, Direction, DistanceLimit, Campo)
	local Target: Vector3? = HitPosition or ResolveFallbackTarget(Origin, Direction, DistanceLimit, Campo)
	if not Target then
		return nil
	end

	local Offset: Vector3 = Target - Origin
	local Distance: number = Offset.Magnitude
	if Distance < FTConfig.THROW_CONFIG.MinAimDistance then
		local SafeDirection: Vector3
		if Offset.Magnitude > MIN_DIRECTION_MAGNITUDE then
			SafeDirection = Offset.Unit
		else
			local PlanarDirection: Vector3 = Vector3.new(Direction.X, 0, Direction.Z)
			if PlanarDirection.Magnitude < MIN_DIRECTION_MAGNITUDE then
				SafeDirection = DEFAULT_DIRECTION
			else
				SafeDirection = PlanarDirection.Unit
			end
		end
		Target = Origin + (SafeDirection * FTConfig.THROW_CONFIG.MinAimDistance)
		local PlaneY: number? = GetCampoPlaneY(Campo)
		if PlaneY ~= nil then
			Target = Vector3.new(Target.X, PlaneY, Target.Z)
		end
	end

	return Utility.ClampToMap(Target)
end

return ThrowAimResolver
