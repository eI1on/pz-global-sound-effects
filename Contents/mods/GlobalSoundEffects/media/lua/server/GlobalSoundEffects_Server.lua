-- Global Sound Effects - Server
-- server is the authority: validates and rebroadcasts requests to clients

local GSE_Config = require("GSE_Config")
require("GSE_Triggers_Server")

local GlobalSoundEffects = {}

local function canUse(playerObj)
	-- sp uses direct call on client; mp uses client->server commands
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

-- client -> server: request to play/stop
function GlobalSoundEffects.SendAudio(playerObj, args)
	if not canUse(playerObj) then
		return
	end
	if not args then
		return
	end

	local cmd = tostring(args.cmd or "play")
	if cmd == "stop" then
		sendServerCommand("GlobalSoundEffects", "ReceiveAudio", { cmd = "stop" })
		return
	end

	local sound = tostring(args.sound or "")
	if not GSE_Config.isValidSound(sound) then
		return
	end

	local volume = tonumber(args.volume) or 1.0
	if volume < 0 then
		volume = 0
	end
	if volume > 5 then
		volume = 5
	end

	local payload = {
		cmd = "play",
		sound = sound,
		label = tostring(args.label or sound),
		volume = volume,
		loop = args.loop == true,
		queue = args.queue, -- "enqueue" to queue, otherwise interrupt
		soundGlobal = args.soundGlobal == true,
		x = tonumber(args.x),
		y = tonumber(args.y),
		z = tonumber(args.z),
		radius = tonumber(args.radius),
	}

	sendServerCommand("GlobalSoundEffects", "ReceiveAudio", payload)
end

Events.OnClientCommand.Add(function(module, command, playerObj, args)
	if module == "GlobalSoundEffects" and GlobalSoundEffects[command] then
		GlobalSoundEffects[command](playerObj, args)
	end
end)
