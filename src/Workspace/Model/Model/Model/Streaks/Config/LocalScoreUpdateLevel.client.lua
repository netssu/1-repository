wait(1)
while true do
	script.RemoteFunction.Value:InvokeServer()
	wait(script.Refresh.Value)
end

