--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local VisualFx = require(ReplicatedStorage.Modules.Game.VisualFx)

local BallImpactFx = {}
local LocalPlayer: Player = Players.LocalPlayer

local SHOT_DISTANCE_MIN_DISTANCE: number = 10
local SHOT_DISTANCE_LABEL_SUFFIX: string = "m"
local BALL_SHOT_DISTANCE_EFFECT_NAME: string = "ShotDistance"

local ImpactState = {
	LastInAir = false,
	LastOnGround = false,
}

local ShotDistanceState = {
	Active = false,
	StartPosition = nil :: Vector3?,
	MarkerInstance = nil :: Instance?,
	Billboard = nil :: BillboardGui?,
	TextLabel = nil :: TextLabel?,
	LandingDistance = 0 :: number,
}

local function DestroyShotDistanceMarker(): ()
	if ShotDistanceState.MarkerInstance and ShotDistanceState.MarkerInstance.Parent then
		ShotDistanceState.MarkerInstance:Destroy()
	end

	ShotDistanceState.MarkerInstance = nil
	ShotDistanceState.Billboard = nil
	ShotDistanceState.TextLabel = nil
end

local function ClearShotDistanceVisuals(DestroyMarker: boolean): ()
	if ShotDistanceState.Billboard then
		ShotDistanceState.Billboard.Enabled = false
	end

	if DestroyMarker then
		DestroyShotDistanceMarker()
	end

	ShotDistanceState.Active = false
	ShotDistanceState.StartPosition = nil
	ShotDistanceState.LandingDistance = 0
end

local function CreateShotDistanceMarker(): ()
	DestroyShotDistanceMarker()

	local AssetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	local EffectsFolder = AssetsFolder and AssetsFolder:FindFirstChild("Effects")
	local Template = EffectsFolder and EffectsFolder:FindFirstChild(BALL_SHOT_DISTANCE_EFFECT_NAME)
	if not Template then
		return
	end

	local MarkerClone = Template:Clone()
	if MarkerClone:IsA("Attachment") then
		MarkerClone.Parent = Workspace.Terrain
	else
		MarkerClone.Parent = Workspace
	end

	VisualFx.SetBillboardsEnabled(MarkerClone, false)
	ShotDistanceState.MarkerInstance = MarkerClone
	ShotDistanceState.Billboard = VisualFx.ResolveFirstBillboard(MarkerClone)
	ShotDistanceState.TextLabel = if ShotDistanceState.Billboard
		then ShotDistanceState.Billboard:FindFirstChildWhichIsA("TextLabel", true)
		else nil
end

local function StartShotDistance(StartPosition: Vector3): ()
	ClearShotDistanceVisuals(true)
	ShotDistanceState.Active = true
	ShotDistanceState.StartPosition = StartPosition
end

local function SetShotDistanceText(Distance: number): ()
	local textLabel = ShotDistanceState.TextLabel
	if not textLabel then
		return
	end

	textLabel.Text = string.format("%d%s", math.floor(Distance), SHOT_DISTANCE_LABEL_SUFFIX)
end

local function ResolveLocalPlayerDistanceToBall(BallPart: BasePart?): number?
	if not BallPart then
		return nil
	end

	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end

	return (root.Position - BallPart.Position).Magnitude
end

local function UpdateShotDistanceText(BallPart: BasePart?): ()
	local Billboard = ShotDistanceState.Billboard
	if not Billboard or not Billboard.Enabled then
		return
	end

	local LocalDistance = ResolveLocalPlayerDistanceToBall(BallPart)
	if typeof(LocalDistance) == "number" then
		SetShotDistanceText(LocalDistance)
		return
	end

	if ShotDistanceState.LandingDistance > 0 then
		SetShotDistanceText(ShotDistanceState.LandingDistance)
	end
end

local function FinishShotDistance(BallPart: BasePart, LandingPosition: Vector3): ()
	local StartPosition = ShotDistanceState.StartPosition
	if not StartPosition then
		ClearShotDistanceVisuals(true)
		return
	end

	local TotalDistance = (LandingPosition - StartPosition).Magnitude
	if TotalDistance < SHOT_DISTANCE_MIN_DISTANCE then
		ClearShotDistanceVisuals(true)
		return
	end

	if not ShotDistanceState.MarkerInstance then
		CreateShotDistanceMarker()
	end

	local MarkerInstance = ShotDistanceState.MarkerInstance
	if MarkerInstance then
		VisualFx.PlaceAtWorldPosition(MarkerInstance, LandingPosition)
		VisualFx.SetBillboardsEnabled(MarkerInstance, true)
	end

	local Billboard = ShotDistanceState.Billboard
	if Billboard then
		Billboard.Enabled = true
	end

	ShotDistanceState.LandingDistance = TotalDistance
	UpdateShotDistanceText(BallPart)
	ShotDistanceState.Active = false
end

function BallImpactFx.Clear(): ()
	ClearShotDistanceVisuals(true)
	ImpactState.LastInAir = false
	ImpactState.LastOnGround = false
end

function BallImpactFx.Update(
	BallPart: BasePart?,
	Data: Instance?,
	DataInAir: boolean,
	DataOnGround: boolean,
	Possession: any
): ()
	if not BallPart or not Data then
		BallImpactFx.Clear()
		return
	end

	if DataInAir and not ImpactState.LastInAir then
		local StartPosition = Data:GetAttribute("FTBall_SpawnPos")
		if typeof(StartPosition) == "Vector3" then
			StartShotDistance(StartPosition)
		else
			StartShotDistance(BallPart.Position)
		end
	end

	if typeof(Possession) == "number" and Possession > 0 then
		ClearShotDistanceVisuals(true)
	end

	if DataOnGround and not ImpactState.LastOnGround and ImpactState.LastInAir then
		local LandingPosition = Data:GetAttribute("FTBall_GroundPos")
		if typeof(LandingPosition) == "Vector3" then
			FinishShotDistance(BallPart, LandingPosition)
		else
			FinishShotDistance(BallPart, BallPart.Position)
		end
	end

	UpdateShotDistanceText(BallPart)

	ImpactState.LastInAir = DataInAir
	ImpactState.LastOnGround = DataOnGround
end

return BallImpactFx
