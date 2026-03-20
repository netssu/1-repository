------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//VARIABLES
local ButtonRegistry = {}
local registry = {}
local starterRegistry = {}
local loaded = {}
local uiRoot: Instance = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Game")

------------------//FUNCTIONS
local function register_module(modName: string, modTable: {[string]: any}): ()
	if loaded[modName] then
		return
	end
	loaded[modName] = true

	for fname, fn in modTable do
		if type(fname) == "string" and type(fn) == "function" then
			registry[fname] = fn
		end
	end

	if modTable.starter and type(modTable.starter) == "table" then
		for fname, fn in modTable.starter do
			if type(fname) == "string" and type(fn) == "function" then
				starterRegistry[fname] = fn
			end
		end
	end
end

local function load_all_ui_modules(): ()
	local children = script:GetChildren()
	for i , m in children do
		if m:IsA("ModuleScript") then
			local t = require(m)
			if type(t) == "table" then
				register_module(m.Name, t)
			else
				warn("[ButtonRegistry] Falha ao carregar módulo:", m.Name, t)
			end
		end
	end
end

function ButtonRegistry.exists(functionName: string, isStarter: boolean?): boolean
	if isStarter then
		return starterRegistry[functionName] ~= nil
	end
	return registry[functionName] ~= nil
end

function ButtonRegistry.call(functionName: string, context: {[string]: any}?): ()
	local fn = registry[functionName]
	if not fn then
		warn("[ButtonRegistry] Função (Interaction) não encontrada:", functionName)
		return
	end
	return fn(context)
end

function ButtonRegistry.callStarter(functionName: string, context: {[string]: any}?): ()
	local fn = starterRegistry[functionName]
	if not fn then
		return
	end
	return fn(context)
end

function ButtonRegistry.load(): ()
	registry = {}
	starterRegistry = {}
	loaded = {}
	load_all_ui_modules()
end

return ButtonRegistry