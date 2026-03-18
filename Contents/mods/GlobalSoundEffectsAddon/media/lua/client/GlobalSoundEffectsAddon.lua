if not getActivatedMods():contains("GlobalSoundEffects") then
	return
end

local GSE_Config = require("GSE_Config")

-- GSE_Config.addSound("Weather", "GSE_bells")
-- GSE_Config.addSound("Weather", "GSE_king")

-- GSE_Config.addSound(nil, "GSE_bells")

GSE_Config.registerCategories({
	Miscellaneous = { "GSE_bells" },
	Parody = { "GSE_king" },
})
