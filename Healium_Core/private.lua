local ADDON_NAME, ns = ...
local H, C, L = unpack(select(2,...))
local Private = ns.Private

local tekDebugFrame = tekDebug and tekDebug:GetFrame(ADDON_NAME)
--local function TekDebug(...) if tekDebugFrame then tekDebugFrame:AddMessage(string.join(", ", ...)) end end

function Private.ERROR(...)
	local line = "|CFFFF0000HealiumCore|r:" .. strjoin(" ", ...)
	print(line)
end

function Private.WARNING(...)
	local line = "|CFF00FFFFHealiumCore|r:" .. strjoin(" ", ...)
	print(line)
end

function Private.DEBUG(lvl, ...)
	--print(tostring(lvl).."  "..type(lvl).."  "..strjoin(" ", ...))
	if type(lvl) ~= "number" then
		Private:ERROR("INVALID DEBUG (lvl not a number)"..(...))
	end
	if C.general.debug and C.general.debug >= lvl then
		local line = "|CFF00FF00HC|r:" .. strjoin(" ", ...)
		if tekDebugFrame then
			tekDebugFrame:AddMessage(line)
		-- else
			-- print(line)
		end
	end
end

if not tekDebugFrame and C.general.debug then
	WARNING("tekDebug not found, debug output sent to chat") -- TODO: localization
end