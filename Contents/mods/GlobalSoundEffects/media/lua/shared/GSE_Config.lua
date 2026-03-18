-- Global Sound Effects - Shared Config
-- Central place for sound categories and defaults.

local GSE_Config = {}

GSE_Config.DEFAULT_CATEGORY = "Standard"

-- sound registry used by ui and validation
-- Keys are categories; values are arrays of sound event names (as defined in media/scripts/*.txt).
GSE_Config.CATEGORIES = {
	[GSE_Config.DEFAULT_CATEGORY] = {
		"GSE_explode",
		"GSE_firefight",
		"GSE_flyby",
		"GSE_gunfight",
		"GSE_helicopter",
		"GSE_nuclear",
		"GSE_overflight",
		"GSE_siren",
		"GSE_nightvolatile",
	},
}

-- simple helpers (kept here to avoid another shared file for now)
local function trim(s)
	return (tostring(s):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function isNonEmptyString(v)
	return type(v) == "string" and trim(v) ~= ""
end

local function ensureCategory(category)
	if not isNonEmptyString(category) then
		category = GSE_Config.DEFAULT_CATEGORY
	end
	if not GSE_Config.CATEGORIES[category] then
		GSE_Config.CATEGORIES[category] = {}
	end
	return category
end

local function findSoundIndex(list, soundName)
	for i, s in ipairs(list) do
		if s == soundName then
			return i
		end
	end
	return nil
end

-- add (or ensure) a category exists
function GSE_Config.addCategory(category)
	category = ensureCategory(category)
	return category
end

-- add a sound to a category (no duplicates). returns true if added, false if already existed/invalid
function GSE_Config.addSound(category, soundName)
	if not isNonEmptyString(soundName) then
		return false
	end
	soundName = trim(soundName)
	category = ensureCategory(category)

	local list = GSE_Config.CATEGORIES[category]
	if findSoundIndex(list, soundName) then
		return false
	end
	table.insert(list, soundName)
	return true
end

-- remove a sound from a category. returns true if removed
function GSE_Config.removeSound(category, soundName)
	if not isNonEmptyString(category) or not isNonEmptyString(soundName) then
		return false
	end
	category = trim(category)
	soundName = trim(soundName)

	local list = GSE_Config.CATEGORIES[category]
	if not list then
		return false
	end

	local idx = findSoundIndex(list, soundName)
	if not idx then
		return false
	end
	table.remove(list, idx)
	return true
end

-- bulk register
-- table format: { CategoryA = {"Sound1","Sound2"}, CategoryB = {"Sound3"} }
function GSE_Config.registerCategories(categoryTable)
	if type(categoryTable) ~= "table" then
		return
	end
	for cat, sounds in pairs(categoryTable) do
		ensureCategory(cat)
		if type(sounds) == "table" then
			for _, s in ipairs(sounds) do
				GSE_Config.addSound(cat, s)
			end
		end
	end
end

function GSE_Config.isValidSound(soundName)
	if type(soundName) ~= "string" then
		return false
	end
	for _, sounds in pairs(GSE_Config.CATEGORIES) do
		for _, s in ipairs(sounds) do
			if s == soundName then
				return true
			end
		end
	end
	return false
end

-- get all categories sorted alphabetically
function GSE_Config.getCategoriesSorted()
	local out = {}
	for k, _ in pairs(GSE_Config.CATEGORIES) do
		table.insert(out, k)
	end
	table.sort(out, function(a, b)
		-- Always keep default/standard category first.
		if a == GSE_Config.DEFAULT_CATEGORY then
			return true
		end
		if b == GSE_Config.DEFAULT_CATEGORY then
			return false
		end
		return tostring(a) < tostring(b)
	end)
	return out
end

function GSE_Config.getSoundsForCategory(category)
	if type(category) ~= "string" then
		return {}
	end
	return GSE_Config.CATEGORIES[category] or {}
end

return GSE_Config
