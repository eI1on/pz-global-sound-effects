local GSE_AudioEngine = {}

GSE_AudioEngine._initialized = false
GSE_AudioEngine._emitter = nil
GSE_AudioEngine._current = nil
GSE_AudioEngine._currentRequest = nil
GSE_AudioEngine._queue = {}
GSE_AudioEngine._pendingManualLoop = nil
GSE_AudioEngine._pendingTrigger = nil

local SOURCE_PRIORITY = {
	trigger = 10,
	manual = 100,
}

local function isPlaying(emitter, soundId)
	return emitter and soundId and emitter:isPlaying(soundId)
end

local function clampVolume(volume)
	volume = tonumber(volume) or 1.0
	if volume < 0 then
		return 0
	end
	if volume > 5 then
		return 5
	end
	return volume
end

local function normalizeRequest(req, defaultSource)
	if type(req) ~= "table" or type(req.sound) ~= "string" or req.sound == "" then
		return nil
	end

	local out = {}
	for k, v in pairs(req) do
		out[k] = v
	end

	out.sound = tostring(req.sound)
	out.volume = clampVolume(req.volume)
	out.loop = req.loop == true
	out.playLoop = req.playLoop == true
	out.queue = req.queue == "enqueue" and "enqueue" or nil
	out.source = tostring(req.source or defaultSource or "manual")
	out.priority = tonumber(req.priority) or SOURCE_PRIORITY[out.source] or 0
	out.sourceKey = tostring(req.sourceKey or out.source .. ":" .. out.sound)
	out.label = tostring(req.label or out.sound)

	if req.playLoop == nil then
		out.playLoop = out.loop
	end

	return out
end

local function sameRequest(a, b)
	if not a and not b then
		return true
	end
	if not a or not b then
		return false
	end
	return a.sound == b.sound
		and a.volume == b.volume
		and a.loop == b.loop
		and a.source == b.source
		and a.sourceKey == b.sourceKey
		and a.label == b.label
end

local function stopCurrent()
	if GSE_AudioEngine._current and isPlaying(GSE_AudioEngine._emitter, GSE_AudioEngine._current) then
		GSE_AudioEngine._emitter:stopSoundLocal(GSE_AudioEngine._current)
	end
	GSE_AudioEngine._current = nil
	GSE_AudioEngine._currentRequest = nil
end

function GSE_AudioEngine.init()
	if GSE_AudioEngine._initialized then
		return
	end
	GSE_AudioEngine._emitter = FMODSoundEmitter.new()
	Events.OnTick.Add(GSE_AudioEngine.update)
	GSE_AudioEngine._initialized = true
end

function GSE_AudioEngine._playNow(req)
	req = normalizeRequest(req)
	if not req or not GSE_AudioEngine._emitter then
		return
	end

	stopCurrent()

	GSE_AudioEngine._emitter:setVolumeAll(req.volume)
	GSE_AudioEngine._currentRequest = req
	GSE_AudioEngine._current = GSE_AudioEngine._emitter:playSoundImpl(req.sound, req.playLoop == true, nil)
end

function GSE_AudioEngine._playNextEligible()
	if #GSE_AudioEngine._queue > 0 then
		local nextReq = table.remove(GSE_AudioEngine._queue, 1)
		GSE_AudioEngine._playNow(nextReq)
		return true
	end

	if GSE_AudioEngine._pendingManualLoop then
		GSE_AudioEngine._playNow(GSE_AudioEngine._pendingManualLoop)
		return true
	end

	if GSE_AudioEngine._pendingTrigger then
		GSE_AudioEngine._playNow(GSE_AudioEngine._pendingTrigger)
		return true
	end

	return false
end

function GSE_AudioEngine.update()
	if not GSE_AudioEngine._emitter then
		return
	end
	GSE_AudioEngine._emitter:tick()

	if GSE_AudioEngine._currentRequest and not isPlaying(GSE_AudioEngine._emitter, GSE_AudioEngine._current) then
		GSE_AudioEngine._current = nil
		GSE_AudioEngine._currentRequest = nil
	end

	if not GSE_AudioEngine._currentRequest then
		GSE_AudioEngine._playNextEligible()
	elseif GSE_AudioEngine._currentRequest.source == "trigger" then
		if
			GSE_AudioEngine._pendingTrigger
			and not sameRequest(GSE_AudioEngine._currentRequest, GSE_AudioEngine._pendingTrigger)
		then
			GSE_AudioEngine._playNow(GSE_AudioEngine._pendingTrigger)
		end
	end
end

function GSE_AudioEngine.stopAll()
	if not GSE_AudioEngine._emitter then
		return
	end
	GSE_AudioEngine._queue = {}
	GSE_AudioEngine._pendingManualLoop = nil
	GSE_AudioEngine._pendingTrigger = nil
	stopCurrent()
end

function GSE_AudioEngine.stopRequestedPlayback()
	if not GSE_AudioEngine._emitter then
		return
	end
	GSE_AudioEngine._queue = {}
	GSE_AudioEngine._pendingManualLoop = nil
	if GSE_AudioEngine._currentRequest and GSE_AudioEngine._currentRequest.source ~= "trigger" then
		stopCurrent()
	end
end

function GSE_AudioEngine.getQueue()
	return GSE_AudioEngine._queue
end

function GSE_AudioEngine.getCurrentRequest()
	return GSE_AudioEngine._currentRequest
end

function GSE_AudioEngine.getPlaybackEntries()
	local entries = {}
	if GSE_AudioEngine._currentRequest then
		table.insert(entries, {
			status = "playing",
			sound = GSE_AudioEngine._currentRequest.sound,
			label = GSE_AudioEngine._currentRequest.label,
			source = GSE_AudioEngine._currentRequest.source,
			loop = GSE_AudioEngine._currentRequest.loop == true,
		})
	end

	for i = 1, #GSE_AudioEngine._queue do
		local req = GSE_AudioEngine._queue[i]
		table.insert(entries, {
			status = "queued",
			position = i,
			sound = req.sound,
			label = req.label,
			source = req.source,
			loop = req.loop == true,
		})
	end

	if #entries == 0 and GSE_AudioEngine._pendingTrigger then
		table.insert(entries, {
			status = "armed",
			sound = GSE_AudioEngine._pendingTrigger.sound,
			label = GSE_AudioEngine._pendingTrigger.label,
			source = GSE_AudioEngine._pendingTrigger.source,
			loop = GSE_AudioEngine._pendingTrigger.loop == true,
		})
	end

	return entries
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

function GSE_AudioEngine.setTrigger(req)
	if not GSE_AudioEngine._initialized then
		GSE_AudioEngine.init()
	end

	if not req then
		GSE_AudioEngine._pendingTrigger = nil
		return
	end

	req = normalizeRequest(req, "trigger")
	if not req then
		return
	end
	req.queue = nil
	req.source = "trigger"
	req.priority = SOURCE_PRIORITY.trigger
	-- trigger "loops" are handled as repeated one-shots so the current play
	-- can finish naturally after the player exits the area.
	req.playLoop = false

	GSE_AudioEngine._pendingTrigger = req

	if not GSE_AudioEngine._currentRequest then
		GSE_AudioEngine._playNow(req)
	elseif GSE_AudioEngine._currentRequest.source == "trigger" then
		if not sameRequest(GSE_AudioEngine._currentRequest, req) then
			GSE_AudioEngine._playNow(req)
		end
	end
end

function GSE_AudioEngine.play(req)
	if not GSE_AudioEngine._initialized then
		GSE_AudioEngine.init()
	end

	req = normalizeRequest(req, "manual")
	if not req then
		return
	end

	GSE_AudioEngine._pendingManualLoop = nil

	if req.loop then
		req.queue = nil
	end
	-- Manual "loops" are replayed as one-shots so they reliably repeat and
	-- still finish the active pass if playback is interrupted later.
	req.playLoop = false

	if req.queue == "enqueue" then
		if (GSE_AudioEngine._currentRequest and GSE_AudioEngine._currentRequest.loop == true) or req.loop then
			req.queue = nil
		else
			table.insert(GSE_AudioEngine._queue, req)
			return
		end
	end

	GSE_AudioEngine._queue = {}
	if req.loop then
		GSE_AudioEngine._pendingManualLoop = req
	end
	GSE_AudioEngine._playNow(req)
end

return GSE_AudioEngine
