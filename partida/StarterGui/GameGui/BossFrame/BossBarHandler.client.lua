if true then return end

local storageFrame = script.Parent.Storage
local templateFrame = script.TemplateFrame
local UIHandler = require(game.ReplicatedStorage.Modules.Client.UIHandler)
local ViewPortModule = require(game.ReplicatedStorage.Modules.ViewPortModule)
local TS = game:GetService("TweenService")
function NewBoss(boss)
	
	local newUIFrame = templateFrame:Clone()

    newUIFrame.Parent = storageFrame
    
    --print('da boss:')
	--print(boss)
	if not boss then warn('Boss aint found?') return end
    
	--newUIFrame.BossName.Text = boss.Name
	local ViewPort = ViewPortModule.CreateViewPort(boss.Name)
	if ViewPort then
		ViewPort.Parent = newUIFrame.InnerVp
	end

	local trackerConnection; trackerConnection = game["Run Service"].Heartbeat:Connect(function()
		if boss and boss.Parent ~= nil then
			if newUIFrame.Visible == false then
				newUIFrame.Visible = true
				--newUIFrame.BossName.Text = boss.Name
				
			end
			local hum = boss:FindFirstChild("Humanoid")
			if hum then
				newUIFrame.HealthText.Text = hum.Health.."/"..hum.MaxHealth
				newUIFrame.Bar.Size = UDim2.new(hum.Health/hum.MaxHealth,0,.741,0)
				
				--boss.Parent.DescendantRemoving:Connect(function()
				--	game.ReplicatedStorage:WaitForChild("Events"):WaitForChild("Client"):WaitForChild("BossDead"):FireServer()
				--end)
			else
				boss = nil
			end
		else
			newUIFrame.Visible = false
			boss = nil
			trackerConnection:Disconnect()
			newUIFrame:Destroy()
		end
	end)
	
	
	
end



local currentBoss = nil
game.ReplicatedStorage.Events.Client.BossSpawn.OnClientEvent:Connect(function(boss)
	warn(boss)
	local Warn = script.Warn:Clone()
	local Scale = Warn.UIScale
	Scale.Scale = 0
	TS:Create(Scale,TweenInfo.new(1,Enum.EasingStyle.Exponential),{Scale = 1}):Play()
	UIHandler.PlaySound("Alarm")
	Warn.Parent = script.Parent.Parent
	
	
	task.wait(3)
	TS:Create(Scale,TweenInfo.new(1,Enum.EasingStyle.Exponential),{Scale = 0}):Play()
    task.wait(.75)
    
    print('da boss we are given:')
    print(boss)
	NewBoss(boss)
	--currentBoss = boss
end)