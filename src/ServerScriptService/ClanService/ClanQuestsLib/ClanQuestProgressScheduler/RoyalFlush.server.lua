local ClanQuestProgressScheduler = require(script.Parent)

game:BindToClose(function()
	ClanQuestProgressScheduler.flushQueue()	
	
	task.wait(15)
end)

while true do
	task.spawn(function()
		ClanQuestProgressScheduler.flushQueue()
	end)
	
	task.wait(60)
end

if not workspace:GetAttribute('Lobby') then
	workspace.Info.GameOver.Changed:Connect(function()
		if workspace.Info.GameOver.Value then
			ClanQuestProgressScheduler.flushQueue()
		end
	end)
end