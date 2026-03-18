-- Global Sound Effects - Shared Trigger Helpers
-- Persistent triggers are stored server-side in ModData under key "GSE_Triggers".

local GSE_TriggerShared = {}

GSE_TriggerShared.MODDATA_KEY = "GSE_Triggers"

-- Trigger schema:
-- {
--   id = string,
--   enabled = boolean,
--   shape = "radius"|"rect",
--   x = number, y = number, z = number, radius = number,           -- radius shape
--   x1 = number, y1 = number, x2 = number, y2 = number, z = number, -- rect shape (2 corners)
--   sound = string,
--   volume = number,
--   loop = boolean,          -- if true: start loop on enter, stop on exit (best-effort)
--   soundGlobal = boolean,   -- if true: ignore epicenter and play for player regardless of coords
-- }

local function toInt(v)
	v = tonumber(v)
	if not v then
		return nil
	end
	return math.floor(v)
end

function GSE_TriggerShared.normalizeTrigger(t)
	if type(t) ~= "table" then
		return nil
	end
	local out = {}

	out.id = tostring(t.id or "")
	out.enabled = t.enabled == true
	out.shape = (t.shape == "rect") and "rect" or "radius"
	out.sound = tostring(t.sound or "")
	out.volume = tonumber(t.volume) or 1.0
	out.loop = t.loop == true
	out.soundGlobal = t.soundGlobal == true
	out.z = toInt(t.z) or 0

	if out.shape == "radius" then
		out.x = toInt(t.x)
		out.y = toInt(t.y)
		out.radius = tonumber(t.radius) or 1
		if out.radius < 1 then
			out.radius = 1
		end
		if not out.x or not out.y then
			return nil
		end
	else
		out.x1 = toInt(t.x1)
		out.y1 = toInt(t.y1)
		out.x2 = toInt(t.x2)
		out.y2 = toInt(t.y2)
		if not out.x1 or not out.y1 or not out.x2 or not out.y2 then
			return nil
		end
		-- normalize corner order
		local minX = math.min(out.x1, out.x2)
		local maxX = math.max(out.x1, out.x2)
		local minY = math.min(out.y1, out.y2)
		local maxY = math.max(out.y1, out.y2)
		out.x1, out.x2 = minX, maxX
		out.y1, out.y2 = minY, maxY
	end

	if out.volume < 0 then
		out.volume = 0
	end
	if out.volume > 5 then
		out.volume = 5
	end
	if out.id == "" then
		return nil
	end
	if out.sound == "" then
		return nil
	end

	return out
end

function GSE_TriggerShared.isInside(trigger, x, y, z)
	if not trigger or not x or not y then
		return false
	end
	if (tonumber(trigger.z) or 0) ~= (tonumber(z) or 0) then
		return false
	end
	if trigger.shape == "rect" then
		return x >= trigger.x1 and x <= trigger.x2 and y >= trigger.y1 and y <= trigger.y2
	end
	-- radius
	local dx = x - trigger.x
	local dy = y - trigger.y
	return (dx * dx + dy * dy) <= (trigger.radius * trigger.radius)
end

return GSE_TriggerShared
