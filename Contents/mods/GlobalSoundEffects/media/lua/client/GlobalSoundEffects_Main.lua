local GSE_Config = require("GSE_Config")
local GSE_AudioEngine = require("GSE_AudioEngine")
local GSE_Triggers_Client = require("GSE_Triggers_Client")

local GlobalSoundEffects = {}

function GlobalSoundEffects.ReceiveAudio(args)
	local playerObj = getPlayer()
	if not playerObj then
		return
	end

	local cmd = tostring(args and args.cmd or "play")
	if cmd == "stop" then
		GSE_AudioEngine.stopAll()
		return
	end

	local sound = tostring(args and args.sound or "")
	if not GSE_Config.isValidSound(sound) then
		if isDebugEnabled() then
			print("[Global Sound Effects] Invalid sound: " .. tostring(sound))
		end
		return
	end

	local isGlobal = args and args.soundGlobal == true
	if not isGlobal then
		local x = tonumber(args and args.x)
		local y = tonumber(args and args.y)
		local radius = tonumber(args and args.radius) or 0
		if not x or not y or radius <= 0 then
			return
		end
		local playerX, playerY = playerObj:getX(), playerObj:getY()
		local distance = math.sqrt((playerX - x) ^ 2 + (playerY - y) ^ 2)
		if distance > radius then
			return
		end
	end

	if (playerObj:getAccessLevel() == "Admin") or isDebugEnabled() then
		print(
			string.format(
				"[Global Sound Effects] sound=%s volume=%s global=%s loop=%s queue=%s",
				tostring(sound),
				tostring(args and args.volume),
				tostring(args and args.soundGlobal),
				tostring(args and args.loop),
				tostring(args and args.queue)
			)
		)
	end

	GSE_AudioEngine.play({
		sound = sound,
		volume = tonumber(args and args.volume) or 1.0,
		loop = args and args.loop == true,
		queue = args and args.queue or nil, -- "enqueue" to queue, otherwise interrupt
	})
end

Events.OnServerCommand.Add(function(module, command, args)
	if module ~= "GlobalSoundEffects" then
		return
	end
	if command == "ReceiveAudio" then
		GlobalSoundEffects.ReceiveAudio(args)
	elseif command == "LoadTriggers" then
		GSE_Triggers_Client.setTriggers(args)
	end
end)

Events.OnCreatePlayer.Add(function()
	GSE_Triggers_Client.init()
end)

return GlobalSoundEffects
