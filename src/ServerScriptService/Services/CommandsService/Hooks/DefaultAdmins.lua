local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Admins = require(ReplicatedStorage.Modules.Data.Admins)

return function(registry)
    registry:RegisterHook("BeforeRun", function(context)
        if context.Group == "DefaultAdmin" and not Admins[context.Executor.UserId] then
            return "You do not have permission to run this command."
        end

    end)
end
