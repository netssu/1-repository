--!strict

local UserInputService : UserInputService = game:GetService('UserInputService')
local LocalPlayer = game:GetService('Players').LocalPlayer
if not LocalPlayer then
	return
end
local Character , HumanoidRootPart , Humanoid : Humanoid

local JumpUsage = 1
local RequestCooldown = 0.15
local LastRequestTime = 0

local insert = table.insert

local HumanoidStateType = Enum.HumanoidStateType
local Freefall = HumanoidStateType.Freefall
local Jumping = HumanoidStateType.Jumping
local Landed = HumanoidStateType.Landed

local Animation = Instance.new('Animation')
Animation.AnimationId = 'rbxassetid://138346988653356'
local AnimationTrack : AnimationTrack

local VFXPart = script.VFXPart
local CachedVFX : { ParticleEmitter }
local SetVFX = function()
	if not Character then
		return
	end
	if not CachedVFX then
		local NewVFXPart = VFXPart:Clone()
		NewVFXPart.Weld.Part1 = Character.PrimaryPart
		NewVFXPart.Parent = Character
		--
		local VFXDescendants = {}
		for __ , ParticleEmitter in NewVFXPart:GetDescendants() do
			if ParticleEmitter:IsA('ParticleEmitter') then
				insert( VFXDescendants , ParticleEmitter )
			end
		end
		CachedVFX = VFXDescendants
	end
end

UserInputService.JumpRequest:Connect(function()
	if tick() - LastRequestTime < RequestCooldown then
		return
	end
	LastRequestTime = tick()
	if not ( Character or HumanoidRootPart or Humanoid ) then
		Character = LocalPlayer.Character :: Model
		HumanoidRootPart = Character.PrimaryPart
		Humanoid = Character:FindFirstChildOfClass('Humanoid') :: Humanoid
		Humanoid.StateChanged:Connect(function( Old , New )
			if New == Landed then
				JumpUsage = 1
			end
		end)
		if AnimationTrack then
			AnimationTrack:Destroy()
		end
		SetVFX()
	end
	--
	if Humanoid:GetState() :: Enum.HumanoidStateType == Freefall and JumpUsage >= 1 then
		JumpUsage -= 1
		Humanoid:ChangeState( Jumping , true )
		if not AnimationTrack then
			AnimationTrack = Humanoid:FindFirstChildOfClass('Animator'):LoadAnimation( Animation )
		end
		AnimationTrack:Play( 0.1 , 1 , 0.7 )
		--
		if CachedVFX then
			for __ , ParticleEmitter : ParticleEmitter in CachedVFX do
				ParticleEmitter:Emit( 20 )
			end
		end
	end
end)