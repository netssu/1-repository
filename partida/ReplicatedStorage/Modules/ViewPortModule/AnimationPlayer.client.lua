local ReplicatedStorage = game:GetService("ReplicatedStorage")

task.wait()
if script.Parent:FindFirstChild('Animations') and script.Parent:FindFirstChild('Humanoid') then	
	--script.Parent.Humanoid:LoadAnimation(script.Parent.Animations.Idle):Play()
	--local Track: AnimationTrack = script.Parent.Humanoid:LoadAnimation(script.Parent.Animations.Idle)
	--Track:Play()
	--Track:AdjustSpeed(0)
	
	--local AnimTrack = script.Parent.Humanoid:LoadAnimation(script.Parent.Animations.Idle)
	--local AnimTrack = Animator:LoadAnimation(script.Parent.Animations.Idle)
	--AnimTrack:Play()
	
	
	local Humanoid = script.Parent.Humanoid
	local AnimationController = Instance.new('AnimationController', script.Parent)
	local Animator = Instance.new('Animator', AnimationController)
	
	Humanoid:Destroy()
	
	local foundAnimation = script.Parent.Animations:FindFirstChild('Idle')
	
	local AnimTrack: AnimationTrack = Animator:LoadAnimation(foundAnimation or ReplicatedStorage.Defaults.Idle) -- should silence any animation errors (Ace)
	AnimTrack:Play()
	AnimTrack:AdjustSpeed(0.1) -- note from ace: because we have SO MANY VIEWPORTS, like 200 in inventory etc i suggest disabling anims completely
	-- this does a huge toll on performance so
	
end