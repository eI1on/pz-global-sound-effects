-- Global Sound Effects - Client Trigger Listener
-- Keeps a local copy of server-persistent triggers and sends enter/exit events.

local GSE_TriggerShared = require("GSE_TriggerShared")

local GSE_Triggers_Client = {}
GSE_Triggers_Client.triggers = {}
GSE_Triggers_Client._inside = {} -- id -> bool
GSE_Triggers_Client._initialized = false

local function requestTriggersOnce()
	if not isClient() then
		-- SP: no server to sync from; nothing to do yet.
		return
	end
	sendClientCommand("GlobalSoundEffects", "RequestTriggers", {})
end

function GSE_Triggers_Client.init()
	if GSE_Triggers_Client._initialized then return end
	GSE_Triggers_Client._initialized = true
	Events.OnTick.Add(GSE_Triggers_Client.update)
	requestTriggersOnce()
end

function GSE_Triggers_Client.setTriggers(payload)
	-- payload expected as table: id -> trigger
	GSE_Triggers_Client.triggers = type(payload) == "table" and payload or {}
	GSE_Triggers_Client._inside = {}
end

function GSE_Triggers_Client.update()
	local playerObj = getPlayer()
	if not playerObj then return end

	local px = math.floor(playerObj:getX())
	local py = math.floor(playerObj:getY())
	local pz = math.floor(playerObj:getZ())

	for id, trig in pairs(GSE_Triggers_Client.triggers) do
		if type(trig) == "table" and trig.enabled == true then
			local insideNow = GSE_TriggerShared.isInside(trig, px, py, pz)
			local insidePrev = GSE_Triggers_Client._inside[id] == true

			if insideNow and not insidePrev then
				GSE_Triggers_Client._inside[id] = true
				if isClient() then
					sendClientCommand("GlobalSoundEffects", "TriggerEvent", { id = id, ev = "enter" })
				end
			elseif (not insideNow) and insidePrev then
				GSE_Triggers_Client._inside[id] = false
				if isClient() then
					sendClientCommand("GlobalSoundEffects", "TriggerEvent", { id = id, ev = "exit" })
				end
			end
		end
	end
end

return GSE_Triggers_Client

