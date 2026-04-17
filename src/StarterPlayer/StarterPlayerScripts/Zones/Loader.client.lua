for i,v in script:GetChildren() do
	task.spawn(function()
		require(v)
	end)
end