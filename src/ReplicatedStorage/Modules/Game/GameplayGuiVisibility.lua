--!strict

local GameplayGuiVisibility = {}

local GAME_GUI_NAME: string = "GameGui"
local HUD_GUI_NAME: string = "HudGui"
local ATTR_AWAKEN_CUTSCENE_ACTIVE: string = "FTAwakenCutsceneActive"
local ATTR_CUTSCENE_HUD_HIDDEN: string = "FTCutsceneHudHidden"
local ATTR_TOUCHDOWN_GAMEPLAY_GUI_OVERRIDE: string = "FTTouchdownGameplayGuiOverride"

export type GameplayGuis = {
	PlayerGui: PlayerGui?,
	GameGui: ScreenGui?,
	HudGui: ScreenGui?,
}

function GameplayGuiVisibility.ResolveGameplayGuis(Player: Player?): GameplayGuis
	if not Player then
		return {
			PlayerGui = nil,
			GameGui = nil,
			HudGui = nil,
		}
	end

	local PlayerGui: PlayerGui? = Player:FindFirstChildOfClass("PlayerGui")
	if not PlayerGui then
		return {
			PlayerGui = nil,
			GameGui = nil,
			HudGui = nil,
		}
	end

	return {
		PlayerGui = PlayerGui,
		GameGui = PlayerGui:FindFirstChild(GAME_GUI_NAME) :: ScreenGui?,
		HudGui = PlayerGui:FindFirstChild(HUD_GUI_NAME) :: ScreenGui?,
	}
end

local function IsCutsceneFlagActive(Target: Instance?): boolean
	if not Target then
		return false
	end

	return Target:GetAttribute(ATTR_CUTSCENE_HUD_HIDDEN) == true
		or Target:GetAttribute(ATTR_AWAKEN_CUTSCENE_ACTIVE) == true
end

local function HasGameplayGuiOverride(Player: Player?): boolean
	if not Player then
		return false
	end

	if Player:GetAttribute(ATTR_TOUCHDOWN_GAMEPLAY_GUI_OVERRIDE) == true then
		return true
	end

	local Character = Player.Character
	return Character ~= nil and Character:GetAttribute(ATTR_TOUCHDOWN_GAMEPLAY_GUI_OVERRIDE) == true
end

function GameplayGuiVisibility.IsGameplayGuiBlocked(Player: Player?): boolean
	if not Player then
		return false
	end

	if HasGameplayGuiOverride(Player) then
		return false
	end

	if IsCutsceneFlagActive(Player) then
		return true
	end

	return IsCutsceneFlagActive(Player.Character)
end

function GameplayGuiVisibility.EnforceGameplayGuiHidden(Player: Player?): ()
	if HasGameplayGuiOverride(Player) then
		return
	end

	local GameplayGuis: GameplayGuis = GameplayGuiVisibility.ResolveGameplayGuis(Player)
	if GameplayGuis.HudGui then
		GameplayGuis.HudGui.Enabled = false
	end
	if GameplayGuis.GameGui then
		GameplayGuis.GameGui.Enabled = false
	end
end

return GameplayGuiVisibility
