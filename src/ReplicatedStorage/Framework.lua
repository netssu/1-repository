local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Promise = require(ReplicatedStorage.Packages.Promise)

local utils = require(script.Utils)

local isServer = RunService:IsServer()
local isClient = RunService:IsClient()

local framework = {}

framework.WaitForServer = true

if isServer then
	framework.Start = function(self: Framework)
		return Promise.new(function(resolve)
			local ServerScriptService = game:GetService("ServerScriptService")

			local servicesFolder = ServerScriptService.Services
			local componentsFolder = ServerScriptService.Components

			local services = utils.getContents(servicesFolder)

			utils.debug(warn, "[S]: Initializing services")
			utils.callFrom("Init", services, function(serviceName)
				utils.debug(print, `[S]: {serviceName} initialized`)
			end)

			utils.debug(warn, `[S]: Starting services`)
			utils.callFrom("Start", services, function(serviceName)
				utils.debug(print, `[S]: {serviceName} started`)
			end)

			local components = utils.getContents(componentsFolder)

			utils.debug(warn, `[S]: Starting components`)
			utils.startComponents(components)

			if self.WaitForServer then
				script:SetAttribute("ServerFinished", true)
			end

			resolve()
		end)
	end
end

if isClient then
	framework.Start = function(self: Framework)
		return Promise.new(function(resolve)
			if self.WaitForServer and not script:GetAttribute("ServerFinished") then
				utils.debug(print, "[C]: Waiting for server to load...")

				repeat
					task.wait(1)
				until script:GetAttribute("ServerFinished")
			end

			local controllersFolder = ReplicatedStorage.Controllers
			local componentsFolder = ReplicatedStorage.Components
			local userInterfaceFolder = ReplicatedStorage.UserInterface

			local controllers = utils.getContents(controllersFolder)

			utils.debug(warn, `[C]: Initializing controllers`)
			utils.callFrom("Init", controllers, function(controllerName)
				utils.debug(print, `[C]: {controllerName} initialized`)
			end)

			utils.debug(warn, `[C]: Starting controllers`)
			utils.callFrom("Start", controllers, function(controllerName)
				utils.debug(print, `[C]: {controllerName} started`)
			end)

			local components = utils.getContents(componentsFolder)

			utils.debug(warn, `[C]: Starting components`)
			utils.startComponents(components)

			local contents = utils.getContents(userInterfaceFolder)

			utils.debug(warn, `[C]: Starting user interface`)
			utils.callFrom("Start", contents, function(contentName)
				utils.debug(print, `[C]: Started UI {contentName}`)
			end)

			resolve()
		end)
	end
end

type Framework = typeof(framework)

return framework :: Framework
