local ADDON_NAME, ns = ...
local H, C, L = unpack(select(2,...))
local Private = ns.Private
--[[
local tekDebugFrame = tekDebug and tekDebug:GetFrame(ADDON_NAME)
--local function TekDebug(...) if tekDebugFrame then tekDebugFrame:AddMessage(string.join(", ", ...)) end end

function Private.ERROR(...)
	local line = "|CFFFF0000HealiumCore|r:" .. strjoin(" ", ...)
	print(line)
end

function Private.WARNING(...)
	local line = "|CFFFFFF00HealiumCore|r:" .. strjoin(" ", ...)
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

if not tekDebugFrame then --and C.general.debug then
	Private:WARNING("tekDebug not found, debug output sent to chat") -- TODO: localization
end
--]]

function Private.ERROR(...)
	local line = "|CFFFF0000HealiumCore|r:" .. strjoin(" ", ...)
	print(line)
end

function Private.WARNING(...)
	local line = "|CFFFFFF00HealiumCore|r:" .. strjoin(" ", ...)
	print(line)
end

local tekWarningDisplayed = false
local tekDebugFrame = tekDebug and tekDebug:GetFrame(ADDON_NAME) -- tekDebug support
function Private.DEBUG(lvl, ...)
	--print(tostring(lvl).."  "..type(lvl).."  "..strjoin(" ", ...))
	local params = strjoin(" ", ...)
	if type(lvl) ~= "number" then
		Private.ERROR("INVALID DEBUG (lvl not a number)"..params)
	end
	if C.general.debug and C.general.debug >= lvl then
		local line = "|CFF00FF00HC|r:" .. params
		if tekDebugFrame then
			tekDebugFrame:AddMessage(line)
		else
			if not tekWarningDisplayed then
				Private.WARNING("tekDebug not found. Debug message disabled") -- TODO: localization
				tekWarningDisplayed = true
			end
		end
	end
end