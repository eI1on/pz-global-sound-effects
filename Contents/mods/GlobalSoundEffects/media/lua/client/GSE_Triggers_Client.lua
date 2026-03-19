local GSE_AudioEngine = require("GSE_AudioEngine")
local GSE_TriggerShared = require("GSE_TriggerShared")

local GSE_Triggers_Client = {}
GSE_Triggers_Client.triggers = {}
GSE_Triggers_Client._initialized = false
GSE_Triggers_Client._activeTriggerId = nil
GSE_Triggers_Client._activeFingerprint = nil

local function getLocalTriggers()
	if isClient() then
		return nil
	end
	return ModData.getOrCreate(GSE_TriggerShared.MODDATA_KEY)
end

local function requestTriggersOnce()
	if isClient() then
		sendClientCommand("GlobalSoundEffects", "RequestTriggers", {})
		return
	end

	GSE_Triggers_Client.setTriggers(getLocalTriggers())
end

local function fingerprintTrigger(trig)
	if not trig then
		return ""
	end
	return table.concat({
		tostring(trig.id),
		tostring(trig.sound),
		tostring(trig.volume),
		tostring(trig.loop == true),
		tostring(trig.priority or 0),
		tostring(trig.x or trig.x1 or ""),
		tostring(trig.y or trig.y1 or ""),
		tostring(trig.x2 or ""),
		tostring(trig.y2 or ""),
		tostring(trig.radius or ""),
		tostring(trig.z or 0),
	}, "|")
end

local function compareTriggers(a, b)
	local pa = tonumber(a and a.priority) or 0
	local pb = tonumber(b and b.priority) or 0
	if pa ~= pb then
		return pa > pb
	end

	local la = tostring(a and a.label or a and a.sound or "")
	local lb = tostring(b and b.label or b and b.sound or "")
	if la ~= lb then
		return la < lb
	end

	return tostring(a and a.id or "") < tostring(b and b.id or "")
end

local function buildTriggerRequest(trigger)
	if not trigger then
		return nil
	end

	return {
		sound = trigger.sound,
		volume = trigger.volume,
		loop = trigger.loop == true,
		source = "trigger",
		sourceKey = tostring(trigger.id),
		label = tostring(trigger.label or trigger.sound),
	}
end

function GSE_Triggers_Client.init()
	if GSE_Triggers_Client._initialized then
		return
	end
	GSE_Triggers_Client._initialized = true
	Events.OnTick.Add(GSE_Triggers_Client.update)
	requestTriggersOnce()
end

function GSE_Triggers_Client.setTriggers(payload)
	GSE_Triggers_Client.triggers = type(payload) == "table" and payload or {}
	GSE_Triggers_Client._activeTriggerId = nil
	GSE_Triggers_Client._activeFingerprint = nil
	GSE_AudioEngine.setTrigger(nil)
end

function GSE_Triggers_Client.getTriggers()
	return GSE_Triggers_Client.triggers
end

function GSE_Triggers_Client.getSortedTriggers()
	local list = {}
	for id, trig in pairs(GSE_Triggers_Client.triggers) do
		if type(trig) == "table" then
			local copy = {}
			for k, v in pairs(trig) do
				copy[k] = v
			end
			copy.id = id
			table.insert(list, copy)
		end
	end

	table.sort(list, compareTriggers)
	return list
end

function GSE_Triggers_Client.refreshLocal()
	if isClient() then
		return
	end
	GSE_Triggers_Client.setTriggers(getLocalTriggers())
end

function GSE_Triggers_Client.update()
	local playerObj = getPlayer()
	if not playerObj then
		return
	end

	local px = math.floor(playerObj:getX())
	local py = math.floor(playerObj:getY())
	local pz = math.floor(playerObj:getZ())

	local best = nil
	for _, trig in pairs(GSE_Triggers_Client.triggers) do
		if type(trig) == "table" and trig.enabled == true and GSE_TriggerShared.isInside(trig, px, py, pz) then
			if (not best) or compareTriggers(trig, best) then
				best = trig
			end
		end
	end

	local nextId = best and tostring(best.id) or nil
	local nextFingerprint = best and fingerprintTrigger(best) or nil

	if not best then
		GSE_Triggers_Client._activeTriggerId = nil
		GSE_Triggers_Client._activeFingerprint = nil
		GSE_AudioEngine.setTrigger(nil)
		return
	end

	if best.loop == true then
		GSE_AudioEngine.setTrigger(buildTriggerRequest(best))
		GSE_Triggers_Client._activeTriggerId = nextId
		GSE_Triggers_Client._activeFingerprint = nextFingerprint
		return
	end

	GSE_AudioEngine.setTrigger(nil)

	local changed = GSE_Triggers_Client._activeTriggerId ~= nextId
		or GSE_Triggers_Client._activeFingerprint ~= nextFingerprint
	if changed then
		local current = GSE_AudioEngine.getCurrentRequest()
		if ((not current) or current.source == "trigger") and not GSE_AudioEngine.isQueueActive() then
			GSE_AudioEngine.play(buildTriggerRequest(best))
		end
	end

	GSE_Triggers_Client._activeTriggerId = nextId
	GSE_Triggers_Client._activeFingerprint = nextFingerprint
end

return GSE_Triggers_Client
