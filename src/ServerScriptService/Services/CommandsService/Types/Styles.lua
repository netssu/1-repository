local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StyleAdminOptions = require(ReplicatedStorage.Modules.Data.StyleAdminOptions)

return function(registry)
    local styleNames = StyleAdminOptions.GetDisplayNames()
    registry:RegisterType("styles", registry.Cmdr.Util.MakeEnumType("styles", styleNames))
end
