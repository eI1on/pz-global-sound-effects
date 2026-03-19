-- Global Sound Effects - Server Persistent Triggers

local GSE_Config = require("GSE_Config")
local GSE_TriggerShared = require("GSE_TriggerShared")

local GSE_Triggers_Server = {}
GSE_Triggers_Server.ServerCommands = {}

local function canUse(playerObj)
	if not playerObj then
		return false
	end
	if playerObj:getAccessLevel() == "Admin" then
		return true
	end
	if isDebugEnabled() then
		return true
	end
	return false
end

local function getTriggers()
	return ModData.getOrCreate(GSE_TriggerShared.MODDATA_KEY)
end

local function pushAll()
	sendServerCommand("GlobalSoundEffects", "LoadTriggers", getTriggers())
end

local function pushToPlayer(playerObj)
	sendServerCommand(playerObj, "GlobalSoundEffects", "LoadTriggers", getTriggers())
end

function GSE_Triggers_Server.ServerCommands.RequestTriggers(playerObj, args)
	pushToPlayer(playerObj)
end

function GSE_Triggers_Server.ServerCommands.AddTrigger(playerObj, args)
	if not canUse(playerObj) then
		return
	end
	if type(args) ~= "table" then
		return
	end

	local trig = GSE_TriggerShared.normalizeTrigger(args.trigger)
	if not trig then
		return
	end
	if not GSE_Config.isValidSound(trig.sound) then
		return
	end

	local triggers = getTriggers()
	triggers[trig.id] = trig
	pushAll()
end

function GSE_Triggers_Server.ServerCommands.RemoveTrigger(playerObj, args)
	if not canUse(playerObj) then
		return
	end

	local id = tostring(args and args.id or "")
	if id == "" then
		return
	end

	local triggers = getTriggers()
	triggers[id] = nil
	pushAll()
end

function GSE_Triggers_Server.onClientCommand(module, command, playerObj, args)
	if module ~= "GlobalSoundEffects" then
		return
	end
	if GSE_Triggers_Server.ServerCommands[command] then
		GSE_Triggers_Server.ServerCommands[command](playerObj, args)
	end
end

Events.OnClientCommand.Add(GSE_Triggers_Server.onClientCommand)

return GSE_Triggers_Server
