local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)

local isServer = RunService:IsServer()
local isClient = RunService:IsClient()

local module = {}

function module.debug(func: (string) -> (), message: string)
	if not RunService:IsStudio() then
		return
	end

	func(message)
end

function module.getContents(folder: Folder?): { [string]: { any? } }
	local modules = {}
	if not folder then
		return modules
	end

	for _, descendant in pairs(folder:GetDescendants()) do
		if not descendant:IsA("ModuleScript") then
			continue
		end

		local success, result = pcall(require, descendant)
		if not success then
			module.debug(warn, `Failed to require module {descendant.Name}: {result}`)
		end

		if type(result) ~= "table" then
			continue
		end

		modules[descendant.Name] = result
	end

	return modules
end

function module.callFrom(funcName: string, contents: { [string]: { any? } }, callback: (name: string) -> ()): ()
	for contentName, content in pairs(contents) do
		if type(content[funcName]) ~= "function" then
			continue
		end

		Promise.promisify(content[funcName])(content):andThenCall(callback, contentName):catch(function(err)
			module.debug(warn, `Something went wrong while calling {funcName} from {contentName}: {err}`)
		end)
	end
end

function module.startComponents(components: { [string]: { any? } }): ()
	local prefix = (isServer and "S") or isClient and "C"

	for componentName, content in pairs(components) do
		if type(content.new) ~= "function" then
			continue
		end

		if not content.Tag then
			module.debug(warn, `[{prefix}]: Missing tag for {componentName} component`)
			continue
		end

		for _, instance in pairs(CollectionService:GetTagged(content.Tag)) do
			local success, object = pcall(content.new, instance)
			if not success then
				module.debug(
					warn,
					`[{prefix}]: Failed to create object for instance {instance.Name} of component {componentName}: {object}`
				)
				continue
			end

			object.Trove:Connect(CollectionService:GetInstanceRemovedSignal(content.Tag), function(removedFrom)
				if instance == removedFrom then
					object:Destroy()
				end
			end)
		end

		CollectionService:GetInstanceAddedSignal(content.Tag):Connect(function(instance)
			local success, object = pcall(content.new, instance)
			if not success then
				module.debug(
					warn,
					`[{prefix}]: Failed to create object for instance {instance.Name} of component {componentName}: {object}`
				)
				return
			end

			object.Trove:Connect(CollectionService:GetInstanceRemovedSignal(content.Tag), function(removedFrom)
				if instance == removedFrom then
					object:Destroy()
				end
			end)
		end)

		module.debug(print, `[{prefix}]: {componentName} component started`)
	end
end

return module
