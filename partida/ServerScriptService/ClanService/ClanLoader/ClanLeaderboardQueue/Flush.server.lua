local ClanDSQueue = require(script.Parent)


game:BindToClose(function()
	ClanDSQueue.flushQueue()
	task.wait(2)
end)

task.spawn(function()
	while true do
		if os.clock() - ClanDSQueue.lastFlushTime >= ClanDSQueue.flushInterval then
			local s,e = pcall(function()
				ClanDSQueue.flushQueue()
			end)
			
			task.spawn(function()
				if not s then
					error(e)
				end
			end)
		end
		task.wait(1)
	end
end)

