-- SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService: TweenService = game:GetService("TweenService")
local Debris: Debris = game:GetService("Debris")

-- CONSTANTS
local COMMANDER_FOLDER_NAME = "Commander Codi 222th"
local SKILL1_FOLDER_NAME = "Skill1"
local SKILL2_FOLDER_NAME = "Skill2"
local SKILL3_FOLDER_NAME = "Skill3"

local SKILL1_CAST_DELAY = 0.7
local SKILL1_SHOT_DELAY = 0.1
local SKILL1_PROJECTILE_TIME = 0.2
local SKILL1_MISSILE_LIFETIME = 2.5
local SKILL1_EXPLOSION_LIFETIME = 2.5
local SKILL1_LAUNCH_LIFETIME = 2.5

local SKILL2_CAST_DELAY = 0.65
local SKILL2_HIT_COUNT = 4
local SKILL2_HIT_DELAY = 0.26
local SKILL2_RADIUS = 5.5
local SKILL2_EFFECT_LIFETIME = 2.5
local SKILL2_FINISH_DELAY = 0.65

local SKILL3_CAST_DELAY = 0.75
local SKILL3_IMPACT_DELAY = 0.25
local SKILL3_LAUNCH_LIFETIME = 4
local SKILL3_EXPLOSION_LIFETIME = 7
local SKILL3_FINISH_DELAY = 1.2

local FRONT_OFFSET = 2.5
local TARGET_Y_OFFSET = -1

-- VARIABLES
local UnitSoundEffectLib = require(ReplicatedStorage:WaitForChild("VFXModules"):WaitForChild("UnitSoundEffectLib"))
local VFXHelper = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("VFX_Helper"))

local vfxRoot: Folder = ReplicatedStorage:WaitForChild("VFX") :: Folder
local commanderFolder: Folder = vfxRoot:WaitForChild(COMMANDER_FOLDER_NAME) :: Folder
local worldVFXFolder: Folder = workspace:WaitForChild("VFX") :: Folder
local gameSpeedValue: NumberValue = workspace:WaitForChild("Info"):WaitForChild("GameSpeed") :: NumberValue

local module = {}

-- FUNCTIONS
local function get_speed(): number
	local speed = gameSpeedValue.Value
	if speed <= 0 then
		return 1
	end

	return speed
end

local function set_attacking(character: Model, state: boolean): ()
	local attacking = character:FindFirstChild("Attacking")
	if attacking and attacking:IsA("BoolValue") then
		attacking.Value = state
	end
end

local function get_target_position(HRP: BasePart, target: Model): Vector3
	local targetHRP = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetHRP then
		return HRP.Position + HRP.CFrame.LookVector * 10
	end

	return Vector3.new(
		targetHRP.Position.X,
		HRP.Position.Y + TARGET_Y_OFFSET,
		targetHRP.Position.Z
	)
end

local function get_gun_part(character: Model, HRP: BasePart): BasePart
	local rightArm = character:FindFirstChild("Right Arm")
	if rightArm then
		local gun = rightArm:FindFirstChild("Gun")
		if gun then
			local pos = gun:FindFirstChild("Pos")
			if pos and pos:IsA("BasePart") then
				return pos
			end
		end
	end

	return HRP
end

local function set_instance_cframe(inst: Instance, cf: CFrame): ()
	if inst:IsA("BasePart") then
		inst.CFrame = cf
		return
	end

	if inst:IsA("Model") then
		inst:PivotTo(cf)
	end
end

local function set_effect_enabled(inst: Instance, enabled: boolean): ()
	for _, descendant in inst:GetDescendants() do
		if descendant:IsA("Beam") or descendant:IsA("Trail") then
			descendant.Enabled = enabled
		end
	end
end

local function hide_effect(inst: Instance): ()
	VFXHelper.OffAllParticles(inst)
	set_effect_enabled(inst, false)

	if inst:IsA("BasePart") then
		inst.Transparency = 1
	end

	for _, descendant in inst:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
		end
	end
end

local function attach_destroy_cleanup(character: Model, inst: Instance): RBXScriptConnection?
	if not character or not character.Parent then
		return nil
	end

	return character.Destroying:Once(function()
		if inst and inst.Parent then
			inst:Destroy()
		end
	end)
end

local function disconnect_connection(connection: RBXScriptConnection?): ()
	if connection then
		connection:Disconnect()
	end
end

local function play_folder_sound(origin: BasePart, folder: Instance): ()
	local sound = folder:FindFirstChild("Sound")
	if sound and sound:IsA("Sound") then
		VFXHelper.SoundPlay(origin, sound)
	end
end

local function spawn_effect(effectTemplate: Instance, cf: CFrame, lifetime: number): Instance
	local clone = effectTemplate:Clone()
	set_instance_cframe(clone, cf)
	clone.Parent = worldVFXFolder

	set_effect_enabled(clone, true)
	VFXHelper.EmitAllParticles(clone)

	Debris:AddItem(clone, lifetime)

	return clone
end

local function get_front_cframe(HRP: BasePart, lookAtPosition: Vector3): CFrame
	local frontPosition = HRP.Position + HRP.CFrame.LookVector * FRONT_OFFSET
	return CFrame.lookAt(frontPosition, lookAtPosition)
end

local function get_random_offset(radius: number): Vector3
	local x = (math.random() * radius * 2) - radius
	local z = (math.random() * radius * 2) - radius
	return Vector3.new(x, 0, z)
end

-- INIT
module["Rocket Shot"] = function(HRP: BasePart, target: Model): ()
	local character = HRP.Parent
	if not character or not character:IsA("Model") then
		return
	end

	local folder = commanderFolder:WaitForChild(SKILL1_FOLDER_NAME)
	local speed = get_speed()
	local targetPosition = get_target_position(HRP, target)
	local gunPart = get_gun_part(character, HRP)

	task.wait(SKILL1_CAST_DELAY / speed)
	if not HRP or not HRP.Parent then
		return
	end

	set_attacking(character, true)
	play_folder_sound(HRP, folder)
	UnitSoundEffectLib.playSound(character, "Rockets" .. tostring(math.random(1, 2)))

	task.wait(SKILL1_SHOT_DELAY / speed)
	if not HRP or not HRP.Parent then
		set_attacking(character, false)
		return
	end

	local launchTemplate = folder:FindFirstChild("RocketLaunchEmit")
	if launchTemplate then
		spawn_effect(launchTemplate, get_front_cframe(HRP, targetPosition), SKILL1_LAUNCH_LIFETIME)
	end

	local missileTemplate = folder:FindFirstChild("Missile")
	local missileConnection: RBXScriptConnection? = nil
	local missile: Instance? = nil

	if missileTemplate then
		missile = missileTemplate:Clone()
		set_instance_cframe(missile, CFrame.lookAt(gunPart.Position, targetPosition))
		missile.Parent = worldVFXFolder
		Debris:AddItem(missile, SKILL1_MISSILE_LIFETIME)

		missileConnection = attach_destroy_cleanup(character, missile)

		if missile:IsA("BasePart") then
			TweenService:Create(
				missile,
				TweenInfo.new(SKILL1_PROJECTILE_TIME / speed, Enum.EasingStyle.Linear),
				{Position = targetPosition}
			):Play()
		end
	end

	task.wait(SKILL1_PROJECTILE_TIME / speed)
	if not HRP or not HRP.Parent then
		disconnect_connection(missileConnection)
		set_attacking(character, false)
		return
	end

	local explosionTemplate = folder:FindFirstChild("Explosion1")
	if explosionTemplate then
		spawn_effect(explosionTemplate, CFrame.new(targetPosition), SKILL1_EXPLOSION_LIFETIME)
	end

	UnitSoundEffectLib.playSound(character, "Explosion")

	if missile then
		hide_effect(missile)
	end

	task.wait(1 / speed)
	if HRP and HRP.Parent then
		set_attacking(character, false)
	end

	disconnect_connection(missileConnection)
end

module["Alpha Strike"] = function(HRP: BasePart, target: Model): ()
	local character = HRP.Parent
	if not character or not character:IsA("Model") then
		return
	end

	local folder = commanderFolder:WaitForChild(SKILL2_FOLDER_NAME)
	local speed = get_speed()

	task.wait(SKILL2_CAST_DELAY / speed)
	if not HRP or not HRP.Parent then
		return
	end

	set_attacking(character, true)
	play_folder_sound(HRP, folder)

	local lightningTemplate = folder:FindFirstChild("LightningExplosion")
	if not lightningTemplate then
		set_attacking(character, false)
		return
	end

	for i = 1, SKILL2_HIT_COUNT do
		if not HRP or not HRP.Parent then
			set_attacking(character, false)
			return
		end

		local targetPosition = get_target_position(HRP, target)
		local hitPosition = targetPosition + get_random_offset(SKILL2_RADIUS)

		spawn_effect(lightningTemplate, CFrame.new(hitPosition), SKILL2_EFFECT_LIFETIME)
		UnitSoundEffectLib.playSound(character, "Explosion")

		if i < SKILL2_HIT_COUNT then
			task.wait(SKILL2_HIT_DELAY / speed)
		end
	end

	task.wait(SKILL2_FINISH_DELAY / speed)
	if HRP and HRP.Parent then
		set_attacking(character, false)
	end
end

module["High Energy Shot"] = function(HRP: BasePart, target: Model): ()
	local character = HRP.Parent
	if not character or not character:IsA("Model") then
		return
	end

	local folder = commanderFolder:WaitForChild(SKILL3_FOLDER_NAME)
	local speed = get_speed()
	local targetPosition = get_target_position(HRP, target)

	task.wait(SKILL3_CAST_DELAY / speed)
	if not HRP or not HRP.Parent then
		return
	end

	set_attacking(character, true)
	play_folder_sound(HRP, folder)

	local launchTemplate = folder:FindFirstChild("RocketLaunchEmit")
	if launchTemplate then
		spawn_effect(launchTemplate, get_front_cframe(HRP, targetPosition), SKILL3_LAUNCH_LIFETIME)
	end

	UnitSoundEffectLib.playSound(character, "LaserGun" .. tostring(math.random(1, 4)))

	task.wait(SKILL3_IMPACT_DELAY / speed)
	if not HRP or not HRP.Parent then
		set_attacking(character, false)
		return
	end

	local explosionTemplate = folder:FindFirstChild("BeamExplosion")
	if explosionTemplate then
		local clone = explosionTemplate:Clone()
		set_instance_cframe(clone, CFrame.new(targetPosition))
		clone.Parent = worldVFXFolder

		VFXHelper.EmitAllParticles(clone)

		Debris:AddItem(clone, SKILL3_EXPLOSION_LIFETIME)
	end

	UnitSoundEffectLib.playSound(character, "MegaExplosion")

	task.wait(SKILL3_FINISH_DELAY / speed)
	if HRP and HRP.Parent then
		set_attacking(character, false)
	end
end

return module