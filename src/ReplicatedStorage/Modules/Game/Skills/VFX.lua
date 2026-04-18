--!strict

local HttpService: HttpService = game:GetService("HttpService")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packets: any = require(ReplicatedStorage.Modules.Game.Packets)

local Replicator = {}

local ModulesFolder: Instance = script:WaitForChild("Client")
local LoadedModules: {[string]: any} = {}
local IsInitialized: boolean = false
local LastEventAtByKey: {[string]: number} = {}
local DUPLICATE_EVENT_WINDOW: number = 0.12

local function GetModule(Name: string): any
	if LoadedModules[Name] then
		return LoadedModules[Name]
	end

	local ModuleScriptInstance: Instance? = ModulesFolder:FindFirstChild(Name)
	if not ModuleScriptInstance then
		return nil
	end

	local Success: boolean, Required: any = pcall(require, ModuleScriptInstance)
	if not Success then
		warn(string.format("[SkillReplicator] Failed to require module '%s': %s", Name, tostring(Required)))
		return nil
	end

	LoadedModules[Name] = Required
	return Required
end

local function NormalizePosition(Data: {[string]: any}): ()
	local PositionValue: any = Data.Position
	if not PositionValue then
		return
	end
	if typeof(PositionValue) == "Vector3" then
		return
	end

	if type(PositionValue) == "table" then
		local X: number = PositionValue.X or PositionValue[1] or 0
		local Y: number = PositionValue.Y or PositionValue[2] or 0
		local Z: number = PositionValue.Z or PositionValue[3] or 0
		Data.Position = Vector3.new(X, Y, Z)
	end
end

local function DecodePayload(Args: {any}): {[string]: any}?
	for _, Argument in Args do
		local ArgumentType: string = type(Argument)
		if ArgumentType == "table" and Argument.Type then
			return Argument
		end
		if ArgumentType == "string" and string.sub(Argument, 1, 1) == "{" then
			local Success: boolean, Decoded: any = pcall(function()
				return HttpService:JSONDecode(Argument)
			end)
			if Success and type(Decoded) == "table" and Decoded.Type then
				return Decoded
			end
		end
	end

	return nil
end

function Replicator.Emit(EventName: string, Data: {[string]: any}): ()
	local Action: string = tostring(Data.Action or "")
	local Token: string = tostring(Data.Token or "")
	local SourceUserId: string = tostring(Data.SourceUserId or "")
	local MarkerName: string = ""
	if Action == "Marker" then
		MarkerName = tostring(Data.MarkerName or Data.Marker or "")
	end
	local DedupKey: string = EventName .. ":" .. Action .. ":" .. Token .. ":" .. SourceUserId .. ":" .. MarkerName
	local Now: number = os.clock()
	local LastAt: number? = LastEventAtByKey[DedupKey]
	if LastAt and (Now - LastAt) < DUPLICATE_EVENT_WINDOW then
		return
	end
	LastEventAtByKey[DedupKey] = Now

	local ModuleInstance: any = GetModule(EventName)
	if not ModuleInstance then
		return
	end

	if type(ModuleInstance.Start) ~= "function" then
		warn(string.format("[SkillReplicator] Module '%s' has no Start() function", EventName))
		return
	end

	task.spawn(function()
		local Success: boolean, ErrorMessage: any = pcall(function()
			ModuleInstance.Start(Data)
		end)
		if not Success then
			warn(string.format("[SkillReplicator] Error on '%s': %s", EventName, tostring(ErrorMessage)))
		end
	end)
end

function Replicator.Cleanup(): ()
	for Name, ModuleInstance in LoadedModules do
		if type(ModuleInstance.Cleanup) == "function" then
			local Success: boolean, ErrorMessage: any = pcall(function()
				ModuleInstance.Cleanup()
			end)
			if not Success then
				warn(string.format("[SkillReplicator] Cleanup error on '%s': %s", Name, tostring(ErrorMessage)))
			end
		end
	end
end

function Replicator.Init(): ()
	if IsInitialized then
		return
	end
	IsInitialized = true

	task.spawn(function()
		for _, ModuleScriptInstance in ModulesFolder:GetChildren() do
			if ModuleScriptInstance:IsA("ModuleScript") then
				GetModule(ModuleScriptInstance.Name)
			end
		end
	end)

	Packets.Replicator.OnClientEvent:Connect(function(...)
		local Data: {[string]: any}? = DecodePayload({...})
		if not Data then
			return
		end
		if type(Data.Type) ~= "string" then
			return
		end
		NormalizePosition(Data)
		Replicator.Emit(Data.Type, Data)
	end)
end

return Replicator

