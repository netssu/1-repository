local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)

local module = {}
local rs = game:GetService("ReplicatedStorage")
local Effects = rs.VFX
local vfxFolder = workspace.VFX
local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local VFX = rs.VFX
local VFX_Helper = require(rs.Modules.VFX_Helper)
local specialVfx = require(game.ReplicatedStorage.Modules.VFX.SpecialVFX)
local towerInfo = require(game.ReplicatedStorage.Modules.Helpers.TowerInfo)


local GameSpeed = workspace.Info.GameSpeed
module["Ice Stomp"] = function(HRP, target)
	local speed = GameSpeed.Value
	local Folder = VFX["Hoth Trooper"].First
	task.wait(0.4/speed)
	VFX_Helper.SoundPlay(HRP,Folder.First)
	local HRPCF = HRP.CFrame
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true
	local range = towerInfo.GetRange(HRP.Parent)
	local distance = math.floor((range / 10) * 7) 

	UnitSoundEffectLib.playSound(HRP.Parent, 'IceAttack')
	specialVfx.IceStomp(HRP.Parent, HRPCF * CFrame.new(0, -1.2, -1), distance, Vector3.new(1, 1, 1), 0.5, 2.5, 0.025)


	task.wait(0.1/speed)
	HRP.Parent.Attacking.Value = false

	if not HRP or not HRP.Parent then return end

end



return module
