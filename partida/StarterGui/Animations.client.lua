local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local events = ReplicatedStorage:WaitForChild("Events")
local animateTowerEvent = events:WaitForChild("AnimateTower")
local GameSpeed = workspace.Info.GameSpeed

local player = game.Players.LocalPlayer
local playerGui = player.PlayerGui


local function setAnimation(object, animName)
	if animName then
		local humanoid = object:WaitForChild("Humanoid", 10)
		local animationsFolder = object:WaitForChild("Animations", 10)

		if humanoid and animationsFolder then
			local animationObject = animationsFolder:WaitForChild(animName)
			if animationObject then
				local animator = humanoid:FindFirstChild("Animator") or Instance.new("Animator", humanoid)

				local playingTracks = animator:GetPlayingAnimationTracks()
				for i, track in playingTracks do
                    if track.Name == animName then
						return track
					end
				end

                local animationTrack = animator:LoadAnimation(animationObject)

				return animationTrack		
			end
		end 
	end
end

local function playAnimation(object, animName, speed, isEnemy)
	local animationTrack = setAnimation(object, animName)

    if animationTrack then
        if isEnemy then
            animationTrack.Looped = true
        end
        
		animationTrack:Play()
        animationTrack:AdjustSpeed(speed)
        
		return animationTrack
	else
		warn("Animation track does not exist")
		return
	end
end

local info = workspace:WaitForChild('Info')

if not info.Versus.Value and not info.Competitive.Value then
	workspace:WaitForChild('Mobs').ChildAdded:Connect(function(object) -- MobsCache
		playAnimation(object, "Walk", nil, true)
	end)
else
	workspace:WaitForChild('RedMobs').ChildAdded:Connect(function(object) -- MobsCache
		playAnimation(object, "Walk", nil, true)
	end)
	
	workspace:WaitForChild('BlueMobs').ChildAdded:Connect(function(object) -- MobsCache
		playAnimation(object, "Walk", nil, true)
	end)
end

workspace.Towers.ChildAdded:Connect(function(object)
	playAnimation(object, "Idle")
end)		

animateTowerEvent.OnClientEvent:Connect(function(tower, animName, target)
	local animtrack = playAnimation(tower, animName, GameSpeed.Value)
	if animtrack then
		if tower.Animations:FindFirstChild(animName):FindFirstChild("UnitAnimSpeed") then
			animtrack:AdjustSpeed(tower.Animations[animName].UnitAnimSpeed.Value*GameSpeed.Value)
		end
	end

end)

game.ReplicatedStorage.Events.StopAnimation.OnClientEvent:Connect(function(enemy, duration)
	for i, v in enemy.Humanoid:GetPlayingAnimationTracks() do
		v:AdjustSpeed(0)
	end
	task.wait(duration)
	for i, v in enemy.Humanoid:GetPlayingAnimationTracks() do
		v:AdjustSpeed(1)
	end
end)