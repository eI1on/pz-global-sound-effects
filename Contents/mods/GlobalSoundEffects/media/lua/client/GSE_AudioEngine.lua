-- Global Sound Effects - Client Audio Engine
-- Handles queueing, looping, and per-request volume without touching the game's global volume.

local GSE_AudioEngine = {}

GSE_AudioEngine._initialized = false
GSE_AudioEngine._emitter = nil
GSE_AudioEngine._current = nil
GSE_AudioEngine._queue = {}
GSE_AudioEngine._activeLoop = false

local function isPlaying(emitter, soundId)
	return emitter and soundId and emitter:isPlaying(soundId)
end

function GSE_AudioEngine.init()
	if GSE_AudioEngine._initialized then
		return
	end
	GSE_AudioEngine._emitter = FMODSoundEmitter.new()
	Events.OnTick.Add(GSE_AudioEngine.update)
	GSE_AudioEngine._initialized = true
end

function GSE_AudioEngine.update()
	if not GSE_AudioEngine._emitter then
		return
	end
	GSE_AudioEngine._emitter:tick()

	-- if the current sound finished (non-loop), play the next queued item
	if GSE_AudioEngine._current and (not isPlaying(GSE_AudioEngine._emitter, GSE_AudioEngine._current)) then
		GSE_AudioEngine._current = nil
		GSE_AudioEngine._activeLoop = false
	end

	if (not GSE_AudioEngine._current) and (#GSE_AudioEngine._queue > 0) then
		local nextReq = table.remove(GSE_AudioEngine._queue, 1)
		GSE_AudioEngine._playNow(nextReq)
	end
end

function GSE_AudioEngine.stopAll()
	if not GSE_AudioEngine._emitter then
		return
	end
	if GSE_AudioEngine._current and isPlaying(GSE_AudioEngine._emitter, GSE_AudioEngine._current) then
		GSE_AudioEngine._emitter:stopSoundLocal(GSE_AudioEngine._current)
	end
	GSE_AudioEngine._current = nil
	GSE_AudioEngine._activeLoop = false
	GSE_AudioEngine._queue = {}
end

-- UI helpers
function GSE_AudioEngine.getQueue()
	return GSE_AudioEngine._queue
end

function GSE_AudioEngine.clearQueue()
	GSE_AudioEngine._queue = {}
end

function GSE_AudioEngine.isQueueActive()
	return #GSE_AudioEngine._queue > 0
end

function GSE_AudioEngine.isPlaying()
	return isPlaying(GSE_AudioEngine._emitter, GSE_AudioEngine._current)
end

-- internal: plays immediately (interrupts current)
function GSE_AudioEngine._playNow(req)
	if not req or type(req.sound) ~= "string" then
		return
	end
	if not GSE_AudioEngine._emitter then
		return
	end

	-- interrupt current sound
	if GSE_AudioEngine._current and isPlaying(GSE_AudioEngine._emitter, GSE_AudioEngine._current) then
		GSE_AudioEngine._emitter:stopSoundLocal(GSE_AudioEngine._current)
	end

	local volume = tonumber(req.volume) or 1.0
	if volume < 0 then
		volume = 0
	end
	if volume > 5 then
		volume = 5
	end
	GSE_AudioEngine._emitter:setVolumeAll(volume)

	local loop = req.loop == true
	GSE_AudioEngine._activeLoop = loop
	-- playSoundImpl(soundName, loop, character) - use nil character for UI/global
	GSE_AudioEngine._current = GSE_AudioEngine._emitter:playSoundImpl(req.sound, loop, nil)
end

-- public: play a sound request
-- req = { sound=string, volume=number, loop=bool, queue="enqueue"|"interrupt" }
function GSE_AudioEngine.play(req)
	if not GSE_AudioEngine._initialized then
		GSE_AudioEngine.init()
	end
	if not req then
		return
	end

	local mode = req.queue
	if mode == "enqueue" then
		table.insert(GSE_AudioEngine._queue, req)
		return
	end

	-- default: interrupt
	GSE_AudioEngine._queue = {}
	GSE_AudioEngine._playNow(req)
end

return GSE_AudioEngine
