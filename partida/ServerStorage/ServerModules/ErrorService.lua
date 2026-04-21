local RunService = game:GetService('RunService')
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local errorEvent = ReplicatedStorage:WaitForChild("ServerErrorEvent")

local ErrorCatcher = {}

function ErrorCatcher.wrap(fn, ...)
	fn(...) -- ErrorServiceV2 takes over now :)
	
	--if not RunService:IsStudio() then
	--    local success, result = pcall(fn, ...)
	--    if not success then
	--        local errorResult = '💥 Caught Server Error: 💥' .. result
	--        errorEvent:FireAllClients(errorResult)
	--        error(errorResult)
	--	end
	--else
	--	fn(...)
	--end
end

return ErrorCatcher