--!strict

export type SkillExecutor = (Character: Model) -> ()

type ExecutorCache = {[string]: SkillExecutor | false}

export type SkillModuleRegistry = {
	_Folder: Folder,
	_Cache: ExecutorCache,
	ResolveExecutor: (self: SkillModuleRegistry, ModuleName: string) -> SkillExecutor?,
	Warmup: (self: SkillModuleRegistry, ModuleNames: {string}) -> (),
}

local SkillModuleRegistry = {}
SkillModuleRegistry.__index = SkillModuleRegistry

function SkillModuleRegistry.new(SkillsFolder: Folder): SkillModuleRegistry
	local self = setmetatable({}, SkillModuleRegistry) :: any
	self._Folder = SkillsFolder
	self._Cache = {}
	return self :: SkillModuleRegistry
end

function SkillModuleRegistry:ResolveExecutor(ModuleName: string): SkillExecutor?
	if ModuleName == "" then
		return nil
	end

	local Cached: SkillExecutor | false? = self._Cache[ModuleName]
	if Cached == false then
		return nil
	end
	if Cached then
		return Cached
	end

	local SkillModule: Instance? = self._Folder:FindFirstChild(ModuleName)
	if not SkillModule or not SkillModule:IsA("ModuleScript") then
		self._Cache[ModuleName] = false
		return nil
	end

	local Ok: boolean, Result: any = pcall(require, SkillModule)
	if not Ok or type(Result) ~= "function" then
		self._Cache[ModuleName] = false
		return nil
	end

	local Executor: SkillExecutor = Result :: SkillExecutor
	self._Cache[ModuleName] = Executor
	return Executor
end

function SkillModuleRegistry:Warmup(ModuleNames: {string}): ()
	local Seen: {[string]: boolean} = {}
	for _, ModuleName in ModuleNames do
		if ModuleName ~= "" and not Seen[ModuleName] then
			Seen[ModuleName] = true
			self:ResolveExecutor(ModuleName)
		end
	end
end

return SkillModuleRegistry
