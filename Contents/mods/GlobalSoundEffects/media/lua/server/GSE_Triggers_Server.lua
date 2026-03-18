-- Global Sound Effects - Server Persistent Triggers

local GSE_Config = require("GSE_Config")
local GSE_TriggerShared = require("GSE_TriggerShared")

local GSE_Triggers_Server = {}
GSE_Triggers_Server.ServerCommands = {}

local function canUse(playerObj)
	if not playerObj then return false end
	if playerObj:getAccessLevel() == "Admin" then return true end
	if isDebugEnabled() then return true end
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
	-- Any player can request current triggers list (read-only).
	pushToPlayer(playerObj)
end

function GSE_Triggers_Server.ServerCommands.AddTrigger(playerObj, args)
	if not canUse(playerObj) then return end
	if type(args) ~= "table" then return end

	local trig = GSE_TriggerShared.normalizeTrigger(args.trigger)
	if not trig then return end
	if not GSE_Config.isValidSound(trig.sound) then return end

	local triggers = getTriggers()
	triggers[trig.id] = trig
	pushAll()
end

function GSE_Triggers_Server.ServerCommands.RemoveTrigger(playerObj, args)
	if not canUse(playerObj) then return end
	local id = tostring(args and args.id or "")
	if id == "" then return end
	local triggers = getTriggers()
	triggers[id] = nil
	pushAll()
end

-- Fired by clients when they enter/exit; server then plays/stops for that player.
function GSE_Triggers_Server.ServerCommands.TriggerEvent(playerObj, args)
	if not playerObj then return end
	local id = tostring(args and args.id or "")
	local ev = tostring(args and args.ev or "")
	if id == "" or (ev ~= "enter" and ev ~= "exit") then return end

	local triggers = getTriggers()
	local trig = triggers[id]
	if not trig or trig.enabled ~= true then return end
	if not GSE_Config.isValidSound(trig.sound) then return end

	if ev == "enter" then
		-- play once or start loop for this player
		sendServerCommand(playerObj, "GlobalSoundEffects", "ReceiveAudio", {
			cmd = "play",
			sound = trig.sound,
			volume = trig.volume,
			loop = trig.loop == true,
			queue = nil,
			soundGlobal = true, -- client already validated inside; deliver directly
		})
	else
		-- best-effort: stop loops on exit (this stops any active sound from this mod for that player)
		if trig.loop == true then
			sendServerCommand(playerObj, "GlobalSoundEffects", "ReceiveAudio", { cmd = "stop" })
		end
	end
end

function GSE_Triggers_Server.onClientCommand(module, command, playerObj, args)
	if module ~= "GlobalSoundEffects" then return end
	if GSE_Triggers_Server.ServerCommands[command] then
		GSE_Triggers_Server.ServerCommands[command](playerObj, args)
	end
end

Events.OnClientCommand.Add(GSE_Triggers_Server.onClientCommand)

return GSE_Triggers_Server

