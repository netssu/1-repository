local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)

local VP = ViewPortModule.CreateViewPort('Fawn', true)

VP.Parent = script.Parent