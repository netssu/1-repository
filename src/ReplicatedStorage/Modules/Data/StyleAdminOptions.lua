--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StylesData = require(ReplicatedStorage.Modules.Data.StylesData)

export type StyleEntry = {
	DisplayName: string,
	StyleId: string,
}

type AliasRecord = {
	IsAmbiguous: boolean,
	Priority: number,
	StyleId: string?,
}

type StyleAdminOptionsModule = {
	GetEntries: () -> {StyleEntry},
	GetDisplayNames: () -> {string},
	GetDisplayName: (StyleId: string) -> string,
	ResolveStyleId: (StyleName: string) -> string?,
	GetAvailableDisplayText: () -> string,
}

local StyleAdminOptions: StyleAdminOptionsModule = {} :: StyleAdminOptionsModule

local EMPTY_STRING: string = ""
local STYLE_SEPARATOR: string = ", "
local NORMALIZE_PATTERN: string = "[%s_%-_]+"
local WORD_PATTERN: string = "[^%s_%-_]+"

local WORD_ALIAS_PRIORITY: number = 1
local LEGACY_ALIAS_PRIORITY: number = 2
local EXACT_ALIAS_PRIORITY: number = 3

local DISPLAY_NAME_OVERRIDES: {[string]: string} = {
	SenaKobayakawa = "Senna",
	Hiruma = "Hiruma",
	FatGuy = "Kurita",
}

local LEGACY_ALIASES: {[string]: string} = {
	sena = "SenaKobayakawa",
	senna = "SenaKobayakawa",
	hiruma = "Hiruma",
	kuritas = "FatGuy",
	fatguy = "FatGuy",
	fatguys = "FatGuy",
}

local CachedEntries: {StyleEntry}? = nil
local CachedDisplayNames: {string}? = nil
local CachedDisplayNameByStyleId: {[string]: string}? = nil
local CachedAliasMap: {[string]: string}? = nil
local CachedAvailableDisplayText: string? = nil

local function NormalizeStyleText(Text: string): string
	return string.lower(Text):gsub(NORMALIZE_PATTERN, EMPTY_STRING)
end

local function CopyEntries(Entries: {StyleEntry}): {StyleEntry}
	local EntryCopies: {StyleEntry} = {}

	for Index, Entry in Entries do
		EntryCopies[Index] = {
			DisplayName = Entry.DisplayName,
			StyleId = Entry.StyleId,
		}
	end

	return EntryCopies
end

local function CopyStringList(Entries: {string}): {string}
	local EntryCopies: {string} = {}

	for Index, Entry in Entries do
		EntryCopies[Index] = Entry
	end

	return EntryCopies
end

local function RegisterAlias(AliasRegistry: {[string]: AliasRecord}, RawAlias: string, StyleId: string, Priority: number): ()
	local Alias: string = NormalizeStyleText(RawAlias)
	if Alias == EMPTY_STRING then
		return
	end

	local ExistingRecord: AliasRecord? = AliasRegistry[Alias]
	if not ExistingRecord then
		AliasRegistry[Alias] = {
			IsAmbiguous = false,
			Priority = Priority,
			StyleId = StyleId,
		}
		return
	end

	if ExistingRecord.IsAmbiguous then
		if ExistingRecord.Priority < Priority then
			AliasRegistry[Alias] = {
				IsAmbiguous = false,
				Priority = Priority,
				StyleId = StyleId,
			}
		end
		return
	end

	if ExistingRecord.StyleId == StyleId then
		if Priority > ExistingRecord.Priority then
			ExistingRecord.Priority = Priority
		end
		return
	end

	if Priority > ExistingRecord.Priority then
		AliasRegistry[Alias] = {
			IsAmbiguous = false,
			Priority = Priority,
			StyleId = StyleId,
		}
		return
	end

	if Priority == ExistingRecord.Priority then
		AliasRegistry[Alias] = {
			IsAmbiguous = true,
			Priority = Priority,
			StyleId = nil,
		}
	end
end

local function RegisterWordAliases(AliasRegistry: {[string]: AliasRecord}, RawText: string, StyleId: string): ()
	for Word in string.gmatch(RawText, WORD_PATTERN) do
		RegisterAlias(AliasRegistry, Word, StyleId, WORD_ALIAS_PRIORITY)
	end
end

local function BuildCache(): ()
	if CachedEntries and CachedDisplayNames and CachedDisplayNameByStyleId and CachedAliasMap and CachedAvailableDisplayText then
		return
	end

	local Entries: {StyleEntry} = {}
	local DisplayNameByStyleId: {[string]: string} = {}
	local AliasRegistry: {[string]: AliasRecord} = {}
	local StyleIdExists: {[string]: boolean} = {}

	for StyleId, StyleData in StylesData do
		local SourceDisplayName: string = StyleId
		if typeof(StyleData.Name) == "string" and StyleData.Name ~= EMPTY_STRING then
			SourceDisplayName = StyleData.Name
		end

		local AdminDisplayName: string = DISPLAY_NAME_OVERRIDES[StyleId] or SourceDisplayName
		StyleIdExists[StyleId] = true
		DisplayNameByStyleId[StyleId] = AdminDisplayName

		table.insert(Entries, {
			DisplayName = AdminDisplayName,
			StyleId = StyleId,
		})

		RegisterAlias(AliasRegistry, StyleId, StyleId, EXACT_ALIAS_PRIORITY)
		RegisterAlias(AliasRegistry, SourceDisplayName, StyleId, EXACT_ALIAS_PRIORITY)
		RegisterAlias(AliasRegistry, AdminDisplayName, StyleId, EXACT_ALIAS_PRIORITY)

		RegisterWordAliases(AliasRegistry, SourceDisplayName, StyleId)
		RegisterWordAliases(AliasRegistry, AdminDisplayName, StyleId)
	end

	for Alias, StyleId in LEGACY_ALIASES do
		if StyleIdExists[StyleId] then
			RegisterAlias(AliasRegistry, Alias, StyleId, LEGACY_ALIAS_PRIORITY)
		end
	end

	table.sort(Entries, function(LeftEntry: StyleEntry, RightEntry: StyleEntry): boolean
		local LeftDisplayName: string = string.lower(LeftEntry.DisplayName)
		local RightDisplayName: string = string.lower(RightEntry.DisplayName)

		if LeftDisplayName == RightDisplayName then
			return LeftEntry.StyleId < RightEntry.StyleId
		end

		return LeftDisplayName < RightDisplayName
	end)

	local DisplayNames: {string} = {}
	for Index, Entry in Entries do
		DisplayNames[Index] = Entry.DisplayName
	end

	local AliasMap: {[string]: string} = {}
	for Alias, AliasRecordData in AliasRegistry do
		if not AliasRecordData.IsAmbiguous and AliasRecordData.StyleId then
			AliasMap[Alias] = AliasRecordData.StyleId
		end
	end

	CachedEntries = Entries
	CachedDisplayNames = DisplayNames
	CachedDisplayNameByStyleId = DisplayNameByStyleId
	CachedAliasMap = AliasMap
	CachedAvailableDisplayText = table.concat(DisplayNames, STYLE_SEPARATOR)
end

function StyleAdminOptions.GetEntries(): {StyleEntry}
	BuildCache()
	return CopyEntries(CachedEntries :: {StyleEntry})
end

function StyleAdminOptions.GetDisplayNames(): {string}
	BuildCache()
	return CopyStringList(CachedDisplayNames :: {string})
end

function StyleAdminOptions.GetDisplayName(StyleId: string): string
	BuildCache()
	local DisplayNameByStyleId: {[string]: string} = CachedDisplayNameByStyleId :: {[string]: string}
	return DisplayNameByStyleId[StyleId] or StyleId
end

function StyleAdminOptions.ResolveStyleId(StyleName: string): string?
	BuildCache()

	local NormalizedStyleName: string = NormalizeStyleText(StyleName)
	if NormalizedStyleName == EMPTY_STRING then
		return nil
	end

	local AliasMap: {[string]: string} = CachedAliasMap :: {[string]: string}
	return AliasMap[NormalizedStyleName]
end

function StyleAdminOptions.GetAvailableDisplayText(): string
	BuildCache()
	return CachedAvailableDisplayText :: string
end

return StyleAdminOptions
