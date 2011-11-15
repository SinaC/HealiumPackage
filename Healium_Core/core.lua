-------------------------------------------------------
-- Healium components
-------------------------------------------------------

-- Exported functions
-- H:Initialize(config)				Initialize Healium and merge config parameter with own config
-- H:RegisterFrame(frame)			register a frame in Healium
-- H:DumpInformation()				return a table with every available information about buttons/buffs/debuffs

local ADDON_NAME, ns = ...
local H, C, L = unpack(select(2,...))

local Private = ns.Private
local FlashFrame = H.FlashFrame
local PerformanceCounter = H.PerformanceCounter

local OriginButtonVertexColor = {1, 1, 1}
local OriginButtonBackdropColor = {0.6, 0.6, 0.6}
local OriginButtonBackdropBorderColor = {0.1, 0.1, 0.1}

local ActivatePrimarySpecSpellName = GetSpellInfo(63645)
local ActivateSecondarySpecSpellName = GetSpellInfo(63644)

local UpdateDelay = 0.2

local HealiumInitialized = false

local SpecSettings = nil

-- Fields added to unitframe
--		hDisabled: true if unitframe is dead/ghost/disconnected, false otherwise
--		hButtons: heal buttons (SecureActionButtonTemplate)
--		hDebuffs: debuff on unit (no template)
--		hBuffs: buffs on unit (only buff castable by heal buttons)
-- Fields added to hButton
--		hSpellBookID: spellID of spell linked to button
--		hMacroName: name of macro linked to button
--		hPrereqFailed: button is disabled because of prereq
--		hOOM: not enough mana to cast spell
--		hNotUsable: not usable (see http://www.wowwiki.com/API_IsUsableSpell)  -> NOT YET USED
--		hDispelHighlight: debuff dispellable by button
--		hOOR: unit of range
--		hInvalid: spell is not valid

-------------------------------------------------------
-- Helpers
-------------------------------------------------------
local ERROR = Private.ERROR
local WARNING = Private.WARNING
local DEBUG = Private.DEBUG

-- Get value or set to default if nil
local function Getter(value, default)
	return value == nil and default or value
end

-- Get book spell id from spell name
local function GetSpellBookID(spellName)
	for i = 1, 300, 1 do
		local spellBookName = GetSpellBookItemName(i, SpellBookFrame.bookType)
		if not spellBookName then break end
		if spellName == spellBookName then
			local slotType = GetSpellBookItemInfo(i, SpellBookFrame.bookType)
			if slotType == "SPELL" then
				return i
			end
			return nil
		end
	end
	return nil
end

-- Is spell learned?
local function IsSpellLearned(spellID)
	local spellName = GetSpellInfo(spellID)
	if not spellName then return nil end
	local skillType, globalSpellID = GetSpellBookItemInfo(spellName)
	-- skill type: "SPELL", "PETACTION", "FUTURESPELL", "FLYOUT"
	if skillType == "SPELL" and globalSpellID == spellID then return skillType end
	return nil
end

-- Duplicate any object
local function DeepCopy(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return new_table
    end
    return _copy(object)
end

-------------------------------------------------------
-- Settings
-------------------------------------------------------
-- Check spell settings
local function CheckSpellSettings()
	--H:DEBUG(1000,"CheckSpellSettings")
	-- Check settings
	if SpecSettings then
		if not SpecSettings.spells then
			WARNING("No spells found for current spec")
		else
			for _, spellSetting in ipairs(SpecSettings.spells) do
				--H:DEBUG(1,"CheckSpellSettings:"..tostring(spellSetting.spellID).."  "..tostring(spellSetting.macroName))
				if spellSetting.spellID and not IsSpellLearned(spellSetting.spellID) then
					local name = GetSpellInfo(spellSetting.spellID)
					if name then
						ERROR(string.format(L.CHECKSPELL_SPELLNOTLEARNED, name, spellSetting.spellID))
					else
						ERROR(string.format(L.CHECKSPELL_SPELLNOTEXISTS, spellSetting.spellID))
					end
				elseif spellSetting.macroName and GetMacroIndexByName(spellSetting.macroName) == 0 then
					ERROR(string.format(L.CHECKSPELL_MACRONOTFOUND, spellSetting.macroName))
				end
			end
		end
	end
end

-- Get settings for current spec and assign it to SpecSettings (if not already set)
local function GetSpecSettings()
	if SpecSettings then return end
	if not C[H.myclass] then return end
	local ptt = GetPrimaryTalentTree()
	if not ptt then return end
	--H:DEBUG(1, "GetSpecSettings done:"..ptt)
	SpecSettings = C[H.myclass][ptt]
	--CheckSpellSettings()
end

local function ResetSpecSettings()
	SpecSettings = nil
end

-- Create a list with spellID and spellName from a list of spellID (+ remove duplicates)
local function CreateFilterList(listName, list)
	local newList = {}
	local index = 1
	for key, value in pairs(list) do
		local spellID = type(value) == "table" and value[1] or value
		local priority = type(value) == "table" and value[2] or nil
		local spellName = GetSpellInfo(spellID)
		if spellName then
			-- Check for duplicate
			local j = 1
			local found = false
			while j < #newList do
				if newList[j].spellName == spellName then
					found = true
					break
				end
				j = j + 1
			end
			if not found then
				-- Create entry in new list
				if priority then
					newList[index] = {spellID = spellID, spellName = spellName, priority = priority}
				else
					newList[index] = {spellID = spellID, spellName = spellName}
				end
				index = index + 1
			-- else
				-- -- Duplicate found
				-- WARNING(string.format(L.SETTINGS_DUPLICATEBUFFDEBUFF, list[i], newList[j].spellID, spellName, listName))
			end
		--else
			-- Unknown spell found
			--WARNING(string.format(L.SETTINGS_UNKNOWNBUFFDEBUFF, list[i], listName))
		end
		--i = i + 1
	end

	-- for k, v in pairs(newList) do
		-- H:DEBUG(1000, listName..":"..tostring(k).." "..tostring(v.spellID).." "..tostring(v.priority).." "..tostring(v.spellName))
	-- end

	return newList
end

local function InitializeSettings()
	-- For every class <> myclass, C[class] = nil
	local classList = {"DEATHKNIGHT", "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR"}
	for _, class in pairs(classList) do
		if H.myclass ~= class and C[class] then
			C[class] = nil
		end
	end

	-- Fill blacklist, whitelist, dispellable with spellName instead of spellID
	if C.blacklist and C.general.debuffFilter == "BLACKLIST" then
		C.blacklist = CreateFilterList("debuff blacklist", C.blacklist)
	else
		--H:DEBUG(1000,"Clearing debuffBlacklist")
		C.blacklist = nil
	end

	if C.whitelist and C.general.debuffFilter == "WHITELIST" then
		C.whitelist = CreateFilterList("debuff whitelist", C.whitelist)
	else
		--H:DEBUG(1000,"Clearing debuffWhitelist")
		C.whitelist = nil
	end

	if C.dispellable then
		C.dispellable = CreateFilterList("dispellable filter", C.dispellable)
	end

	-- Add spellName to spell list
	if C[H.myclass] then
		for _, specSetting in pairs(C[H.myclass]) do
			if specSetting.spells then
				for _, spellSetting in ipairs(specSetting.spells) do
					if spellSetting.spellID then
						local spellName = GetSpellInfo(spellSetting.spellID)
						spellSetting.spellName = spellName
					end
				end
			end
		end
	end
end

-------------------------------------------------------
-- Tooltips
-------------------------------------------------------
-- Heal buttons tooltip
local function ButtonOnEnter(self)
	-- Heal tooltips are anchored to tukui tooltip
	local tooltipAnchor = C.general.buttonTooltipAnchor or self
	GameTooltip_SetDefaultAnchor(GameTooltip, tooltipAnchor)
	--GameTooltip:SetOwner(tooltipAnchor, "ANCHOR_NONE")
	GameTooltip:ClearLines()
	if self.hInvalid then
		if self.hSpellBookID then
			local name = GetSpellInfo(self.hSpellBookID) -- in this case, hSpellBookID contains global spellID
			GameTooltip:AddLine(string.format(L.TOOLTIP_UNKNOWNSPELL, name, self.hSpellBookID), 1, 1, 1)
		elseif self.hMacroName then
			GameTooltip:AddLine(string.format(L.TOOLTIP_UNKNOWN_MACRO, self.hMacroName), 1, 1, 1)
		else
			GameTooltip:AddLine(L.TOOLTIP_UNKNOWN, 1, 1, 1)
		end
	else
		if self.hSpellBookID then
			GameTooltip:SetSpellBookItem(self.hSpellBookID, SpellBookFrame.bookType)
		elseif self.hMacroName then
			GameTooltip:AddLine(string.format(L.TOOLTIP_MACRO, self.hMacroName), 1, 1, 1)
		else
			GameTooltip:AddLine(L.TOOLTIP_UNKNOWN, 1, 1, 1)
		end
		local unit = SecureButton_GetUnit(self)
		if not UnitExists(unit) then return end
		local unitName = UnitName(unit)
		if not unitName then unitName = "-" end
		GameTooltip:AddLine(string.format(L.TOOLTIP_TARGET, unitName), 1, 1, 1)
	end
	GameTooltip:Show()
end

-- Debuff tooltip
local function DebuffOnEnter(self)
	if C.general.debuffTooltipAnchor then
		GameTooltip_SetDefaultAnchor(GameTooltip, C.general.debuffTooltipAnchor)
	else
		--http://wow.go-hero.net/framexml/13164/TargetFrame.xml
		if self:GetCenter() > GetScreenWidth()/2 then
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		else
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		end
	end
	GameTooltip:SetUnitDebuff(self.unit, self:GetID())
	GameTooltip:Show()
end

-- Buff tooltip
local function BuffOnEnter(self)
	if C.general.buffTooltipAnchor then
		GameTooltip_SetDefaultAnchor(GameTooltip, C.general.buffTooltipAnchor)
	else
		--http://wow.go-hero.net/framexml/13164/TargetFrame.xml
		if self:GetCenter() > GetScreenWidth()/2 then
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		else
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		end
	end
	GameTooltip:SetUnitBuff(self.unit, self:GetID())
	GameTooltip:Show()
end


-------------------------------------------------------
-- Unitframes list management
-------------------------------------------------------
local Unitframes = {}
-- Save frame
local function SaveUnitframe(frame)
	tinsert(Unitframes, frame)
end

-- Loop among every valid with specified unit unitframe in party/raid and call a function
local function ForEachUnitframeWithUnit(unit, fct, ...)
	--PerformanceCounter:Increment(ADDON_NAME, "ForEachUnitframeWithUnit")
	if not Unitframes then return nil end
	for _, frame in ipairs(Unitframes) do
		if frame and frame.unit == unit then
			fct(frame, ...)
		end
	end
end

-- Loop among every valid unitframe in party/raid and call a function
local function ForEachUnitframe(fct, ...)
	--PerformanceCounter:Increment(ADDON_NAME, "ForEachUnitframe")
	if not Unitframes then return end
	for _, frame in ipairs(Unitframes) do
		--if frame and frame:IsShown() then -- IsShown is false if /reloadui
		if frame and frame.unit ~= nil --[[and frame:GetParent():IsShown()]] then -- IsShown is false if /reloadui
			fct(frame, ...)
		end
	end
end

-- Loop among every valid unitframe in party/raid and call a function for each button[index]
local function ForEachUnitframeButton(index, fct, ...)
	--PerformanceCounter:Increment(ADDON_NAME, "ForEachUnitframeButton")
	if not Unitframes then return end
	for _, frame in ipairs(Unitframes) do
		--if frame and frame:IsShown() then -- IsShown is false if /reloadui
		if frame and frame.unit ~= nil --[[and frame:GetParent():IsShown()]] then -- IsShown is false if /reloadui
			if frame.hButtons then
				local button = frame.hButtons[index]
				if button then
					fct(frame, button, ...)
				end
			end
		end
	end
end

-- Loop among every unitframe even if not shown or unit is nil
local function ForEachUnitframeEvenIfInvalid(fct, ...)
	--PerformanceCounter:Increment(ADDON_NAME, "ForEachUnitframeEvenIfInvalid")
	if not Unitframes then return end
	for _, frame in ipairs(Unitframes) do
		if frame then
			fct(frame, ...)
		end
	end
end

-------------------------------------------------------
-- Healium buttons/buff/debuffs update
-------------------------------------------------------
-- Update buff icon, id, unit, ...
local function UpdateBuff(buff, id, unit, icon, count, duration, expirationTime)
	-- id, unit: used by tooltip
	buff:SetID(id)
	buff.unit = unit
	-- texture
	buff.icon:SetTexture(icon)
	-- count
	if buff.count then
		if count > 1 then
			buff.count:SetText(count)
			buff.count:Show()
		else
			buff.count:Hide()
		end
	end
	-- cooldown
	if buff.cooldown then
		if duration and duration > 0 then
			--H:DEBUG(1000, "BUFF ON")
			local startTime = expirationTime - duration
			buff.cooldown:SetCooldown(startTime, duration)
		else
			--H:DEBUG(1000, "BUFF OFF")
			buff.cooldown:Hide()
		end
	end
	-- show
	buff:Show()
end

-- Update debuff icon, id, unit, ...
local function UpdateDebuff(debuff, id, unit, icon, count, duration, expirationTime, debuffType)
	-- id, unit: used by tooltip
	debuff:SetID(id)
	debuff.unit = unit
	-- texture
	debuff.icon:SetTexture(icon)
	-- count
	if debuff.count then
		if count > 1 then
			debuff.count:SetText(count)
			debuff.count:Show()
		else
			debuff.count:Hide()
		end
	end
	-- cooldown
	if debuff.cooldown then
		if duration and duration > 0 then
			local startTime = expirationTime - duration
			debuff.cooldown:SetCooldown(startTime, duration)
			debuff.cooldown:Show()
		else
			debuff.cooldown:Hide()
		end
	end
	-- debuff color
	local debuffColor = debuffType and DebuffTypeColor[debuffType] or DebuffTypeColor["none"]
	--H:DEBUG(1000,"debuffType: "..(debuffType or 'nil').."  debuffColor: "..(debuffColor and debuffColor.r or 'nil')..","..(debuffColor and debuffColor.g or 'nil')..","..(debuffColor and debuffColor.b or 'nil'))
	debuff:SetBackdropBorderColor(debuffColor.r, debuffColor.g, debuffColor.b)
	-- show
	debuff:Show()
end

-- Update healium button color depending on frame status and button status
-- frame disabled -> color in dark red except rez spell if dead or ghost
-- out of range -> color in deep red
-- disabled -> dark gray
-- not usable -> color in medium red
-- out of mana -> color in medium blue
-- dispel highlight -> color in debuff color
local function UpdateButtonColor(frame, button, buttonSpellSetting)
	PerformanceCounter:Increment(ADDON_NAME, "UpdateButtonColor")
	local unit = frame.unit

	if frame.hDisabled and (not UnitIsConnected(unit) or not buttonSpellSetting or ((not buttonSpellSetting.rez or buttonSpellSetting.rez == false) and UnitIsDeadOrGhost(unit))) then
		-- not (rez and unit is dead) -> color in red
		button.texture:SetVertexColor(unpack(C.colors.unitDead))
	elseif button.hOOR and not button.hInvalid then
		-- out of range -> color in red
		button.texture:SetVertexColor(unpack(C.colors.unitOOR))
	elseif button.hPrereqFailed and not button.hInvalid then
		-- button disabled -> color in gray
		button.texture:SetVertexColor(unpack(C.colors.spellPrereqFailed))
	elseif button.hNotUsable and not button.hInvalid then
		-- button not usable -> color in medium red
		button.texture:SetVertexColor(unpack(C.colors.spellNotUsable))
	elseif button.hOOM and not button.hInvalid then
		-- no mana -> color in blue
		button.texture:SetVertexColor(unpack(C.colors.OOM))
	elseif button.hDispelHighlight ~= "none" and not button.hInvalid then
		-- dispel highlight -> color with debuff color
		local debuffColor = DebuffTypeColor[button.hDispelHighlight] or DebuffTypeColor["none"]
		button:SetBackdropColor(debuffColor.r, debuffColor.g, debuffColor.b)
		-- --button:SetBackdropBorderColor(debuffColor.r, debuffColor.g, debuffColor.b)
		button.texture:SetVertexColor(debuffColor.r, debuffColor.g, debuffColor.b)
	else
		button.texture:SetVertexColor(unpack(OriginButtonVertexColor))
		button:SetBackdropColor(unpack(OriginButtonBackdropColor))
		button:SetBackdropBorderColor(unpack(OriginButtonBackdropBorderColor))
	end
end

-- Update button OOR
local function UpdateButtonOOR(frame, button, spellName, spellSetting)
	--PerformanceCounter:Increment(ADDON_NAME, "UpdateButtonOOR")
	local inRange = IsSpellInRange(spellName, frame.unit)
	if not inRange or inRange == 0 then
		button.hOOR = true
	else
		button.hOOR = false
	end
	UpdateButtonColor(frame, button, spellSetting)
end

-- Update button OOM
local function UpdateButtonOOM(frame, button, OOM, spellSetting)
	--PerformanceCounter:Increment(ADDON_NAME, "UpdateButtonOOM")
	button.hOOM = OOM
	UpdateButtonColor(frame, button, spellSetting)
end

-- Update button cooldown
local function UpdateButtonCooldown(frame, button, start, duration, enabled)
	--PerformanceCounter:Increment(ADDON_NAME, "UpdateButtonCooldown")
	CooldownFrame_SetTimer(button.cooldown, start, duration, enabled)
end

-- Update frame buttons color
local function UpdateFrameButtonsColor(frame)
	PerformanceCounter:Increment(ADDON_NAME, "UpdateFrameButtonsColor")
	if not frame.hButtons then return end
	if not SpecSettings or not SpecSettings.spells then return end
	for index, spellSetting in ipairs(SpecSettings.spells) do
		local button = frame.hButtons[index]
		if button then
			UpdateButtonColor(frame, button, spellSetting)
		end
	end
end

-- Update frame buff/debuff/prereq
local LastDebuffSoundTime = GetTime()
local listBuffs = {} -- GC-friendly
local listDebuffs = {} -- GC-friendly
local function UpdateFrameBuffsDebuffsPrereqs(frame)
	PerformanceCounter:Increment(ADDON_NAME, "UpdateFrameBuffsDebuffsPrereqs")

	--H:DEBUG(1000,"UpdateFrameBuffsDebuffsPrereqs: frame: "..frame:GetName().." unit: "..(unit or "nil"))

	local unit = frame.unit
	if not unit then return end

	-- reset button.hPrereqFailed and button.hDispelHighlight
	if frame.hButtons and not frame.hDisabled then
		--H:DEBUG(1000,"---- reset dispel, disabled")
		for index, button in ipairs(frame.hButtons) do
			button.hDispelHighlight = "none"
			button.hPrereqFailed = false
		end
	end
	-- reset priorityDebuff
	if frame.hPriorityDebuff then
		-- lower value ==> higher priority
		frame.hPriorityDebuff.priority = 1000 -- lower priority
		frame.hPriorityDebuff:Hide()
	end

	-- buff: parse buff even if showBuff is set to false for prereq
	local buffCount = 0
	if not frame.hDisabled then
		local buffIndex = 1
		if SpecSettings and SpecSettings.spells then
			for i = 1, 40, 1 do
				-- get buff, don't filter on PLAYER because we need a full list of buff to check prereq
				local name, _, icon, count, _, duration, expirationTime, unitCaster, _, _, spellID = UnitBuff(unit, i)
				if not name then break end
				listBuffs[i] = spellID -- display only buff castable by player but keep whole list of buff to check prereq
				buffCount = buffCount + 1
				if unitCaster == "player" and frame.hBuffs and buffIndex <= C.general.maxBuffCount then -- only buff casted by player are shown
					-- is buff casted by player and in spell list?
					local found = false
					for index, spellSetting in ipairs(SpecSettings.spells) do
						--if spellSetting.spellID and spellSetting.spellID == spellID then
						if spellSetting.spellName and spellSetting.spellName == name then
							found = true
							break
						elseif spellSetting.macroName then
							local macroID = GetMacroIndexByName(spellSetting.macroName)
							if macroID > 0 then
								local spellName = GetMacroSpell(macroID)
								if spellName == name then
									found = true
									break
								end
							end
						end
					end
					if found then
						-- buff casted by player and in spell list
						local buff = frame.hBuffs[buffIndex]
						UpdateBuff(buff, i, unit, icon, count, duration, expirationTime)
						-- next buff
						buffIndex = buffIndex + 1
						--WARNING(string.format(L.BUFFDEBUFF_TOOMANYBUFF, frame:GetName(), unit))
					end
				end
			end
		end
		if frame.hBuffs then
			for i = buffIndex, C.general.maxBuffCount, 1 do
				-- hide remainder buff
				local buff = frame.hBuffs[i]
				buff:Hide()
			end
		end
	end

	-- debuff: parse debuff even if showDebuff is set to false for prereq and even if frame is disabled
	local debuffCount = 0
	local debuffIndex = 1
	local dispellableFound = false
	if (SpecSettings and SpecSettings.spells) or C.general.showDebuff then
		for i = 1, 40, 1 do
			-- get debuff
			local name, _, icon, count, debuffType, duration, expirationTime, _, _, _, spellID = UnitDebuff(unit, i)
			if not name then break end
			local debuffPriority = 1000 -- lowest priority
			if C.general.debugDebuff then
				debuffType = C.general.debugDebuff -- DEBUG purpose :)
			end
			listDebuffs[i] = {spellID = spellID, type = debuffType, spellName = name} -- display not filtered debuff but keep whole debuff list to check prereq and highlight dispel buttons
			debuffCount = debuffCount + 1
			local dispellable = false -- default: non-dispellable
			if debuffType then
				for _, spellSetting in ipairs(SpecSettings.spells) do
					if spellSetting.dispels then
						local canDispel = type(spellSetting.dispels[debuffType]) == "function" and spellSetting.dispels[debuffType]() or spellSetting.dispels[debuffType]
						if canDispel then
							debuffPriority = 0 -- highest priority
							dispellable = true
							dispellableFound = true
							break
						end
					end
				end
			end
			local filtered = false -- default: not filtered
			if not dispellable then
				-- non-dispellable are rejected or filtered using blacklist/whitelist
				if C.general.debuffFilter == "DISPELLABLE" then
					filtered = true
				elseif C.general.debuffFilter == "BLACKLIST" and C.blacklist then
					-- blacklisted ?
					filtered = false -- default: not filtered
					for _, entry in ipairs(C.blacklist) do
						if entry.spellName == name then
							filtered = true -- found in blacklist -> filtered
							break
						end
					end
				elseif C.general.debuffFilter == "WHITELIST" and C.whitelist then
					-- whitelisted ?
					filtered = true -- default: filtered
					for _, entry in ipairs(C.whitelist) do
						if entry.spellName == name then
							debuffPriority = entry.priority or 1000
							filtered = false -- found in whitelist -> not filtered
							break
						end
					end
				end
			end
			if not filtered then
				-- debuff not filtered
				if frame.hDebuffs and debuffIndex <= C.general.maxDebuffCount then
					-- set normal debuff
					local debuff = frame.hDebuffs[debuffIndex]
					UpdateDebuff(debuff, i, unit, icon, count, duration, expirationTime, debuffType)
					-- next debuff
					debuffIndex = debuffIndex + 1
					--- too many debuff?
					--WARNING(string.format(L.BUFFDEBUFF_TOOMANYDEBUFF, frame:GetName(), unit))
				end
				if frame.hPriorityDebuff and debuffPriority <= frame.hPriorityDebuff.priority then
					-- set priority debuff if any
					UpdateDebuff(frame.hPriorityDebuff, i, unit, icon, count, duration, expirationTime, debuffType)
					frame.hPriorityDebuff.priority = debuffPriority
				end
			end
		end
	end
	if frame.hDebuffs then
		for i = debuffIndex, C.general.maxDebuffCount, 1 do
			-- hide remainder debuff
			local debuff = frame.hDebuffs[i]
			debuff:Hide()
		end
	end

	--H:DEBUG(1000,"BUFF:"..buffCount.."  DEBUFF:"..debuffCount)

	-- color dispel button if dispellable debuff (and not in dispellable filter list) + prereqs management (is buff or debuff a prereq to enable/disable a spell)
	if SpecSettings and SpecSettings.spells and frame.hButtons and not frame.hDisabled then
		local isUnitInRange = UnitInRange(unit)
		local highlightDispel = Getter(C.general.highlightDispel, true)
		local playSound = false -- play sound only if at least one debuff dispellable not filtered and option activated
		local dispelAnimation = C.general.dispelAnimation
		for index, spellSetting in ipairs(SpecSettings.spells) do
			local button = frame.hButtons[index]
			-- buff prereq: if not present, spell is inactive
			if spellSetting.buffs then
				--H:DEBUG(1000,"searching buff prereq for "..spellSetting.spellID)
				local prereqBuffFound = false
				for _, prereqBuffSpellID in ipairs(spellSetting.buffs) do
					--H:DEBUG(1000,"buff prereq for "..spellSetting.spellID.." "..prereqBuffSpellID)
					--for _, buff in pairs(listBuffs) do
					for i = 1, buffCount, 1 do
						local buff = listBuffs[i]
						--H:DEBUG(1000,"buff on unit "..buffSpellID)
						if buff == prereqBuffSpellID then
							--H:DEBUG(1000,"PREREQ: "..prereqBuffSpellID.." is a buff prereq for "..spellSetting.spellID.." "..button:GetName())
							prereqBuffFound = true
							break
						end
					end
					if prereqBuffFound then break end
				end
				if not prereqBuffFound then
					--H:DEBUG(1000,"PREREQ: BUFF for "..spellSetting.spellID.." NOT FOUND")
					button.hPrereqFailed = true
				end
			end
			-- debuff prereq: if present, spell is inactive
			if spellSetting.debuffs then
				--H:DEBUG(1000,"searching buff prereq for "..spellSetting.spellID)
				local prereqDebuffFound = false
				for _, prereqDebuffSpellID in ipairs(spellSetting.debuffs) do
					--H:DEBUG(1000,"buff prereq for "..spellSetting.spellID.." "..prereqDebuffSpellID)
					--for _, debuff in ipairs(listDebuffs) do
					for i = 1, debuffCount, 1 do
						local debuff = listDebuffs[i]
						local debuffSpellID = debuff.spellID -- [1] = spellID
						--H:DEBUG(1000,"debuff on unit "..debuffSpellID)
						if debuffSpellID == prereqDebuffSpellID then
							--H:DEBUG(1000,"PREREQ: "..prereqDebuffSpellID.." is a debuff prereq for "..spellSetting.spellID.." "..button:GetName())
							prereqDebuffFound = true
							break
						end
					end
					if prereqDebuffFound then break end
				end
				if prereqDebuffFound then
					--H:DEBUG(1000,"PREREQ: DEBUFF for "..spellSetting.spellID.." FOUND")
					button.hPrereqFailed = true
				end
			end
			-- color dispel button if affected by a debuff curable by a player spell
			if dispellableFound and spellSetting.dispels and (highlightDispel or dispelAnimation ~= "NONE") then
				--for _, debuff in ipairs(listDebuffs) do
				for i = 1, debuffCount, 1 do
					local debuff = listDebuffs[i]
					local debuffType = debuff.type -- [2] = debuffType
					local debuffName = debuff.spellName
					if debuffType then
						local filtered = false
						if C.dispellable then
							for _, entry in ipairs(C.dispellable) do
								if entry.spellName == debuffName then
									filtered = true
									break
								end
							end
						end
						if not filtered then
							playSound = Getter(C.general.playSoundOnDispel, true) -- play sound only if at least one debuff dispellable not filtered and option activated
							--H:DEBUG(1000,"type: "..type(spellSetting.dispels[debuffType]))
							local canDispel = type(spellSetting.dispels[debuffType]) == "function" and spellSetting.dispels[debuffType]() or spellSetting.dispels[debuffType]
							if canDispel then
								--print("DEBUFF dispellable")
								local debuffColor = DebuffTypeColor[debuffType] or DebuffTypeColor["none"]
								-- Highlight dispel button?
								if highlightDispel then
									button.hDispelHighlight = debuffType
								end
								-- Flash dispel?
								if isUnitInRange then
									if dispelAnimation == "FLASH" then
										FlashFrame:ShowFlashFrame(button, debuffColor, 320, 100, false)
									elseif dispelAnimation == "BLINK" then
										FlashFrame:Blink(button, 0.3)
									elseif dispelAnimation == "PULSE" then
										FlashFrame:Pulse(button, 1.75)
									end
								end
								break -- a debuff dispellable is enough
							end
						end
					end
				end
			end
		end
		-- Play sound?
		if playSound and isUnitInRange then
			local now = GetTime()
			--print("DEBUFF in range: "..now.."  "..h_listDebuffsoundTime)
			if now > LastDebuffSoundTime + 7 then -- no more than once every 7 seconds
				--print("DEBUFF in time")
				PlaySoundFile(C.general.dispelSoundFile)
				LastDebuffSoundTime = now
			end
		end
	end

	-- Color buttons
	if SpecSettings then
		UpdateFrameButtonsColor(frame)
	end
end

--
local function UpdateFrameDisableStatus(frame)
	PerformanceCounter:Increment(ADDON_NAME, "UpdateFrameDisableStatus")

	local unit = frame.unit
	if not unit then return end

	--H:DEBUG(1000,"UpdateFrameVisibility: "..frame:GetName().."  "..(unit or 'nil'))
	if not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) then
		if not frame.hDisabled then
			--H:DEBUG(1000,"->DISABLE")
			frame.hDisabled = true
			-- hide buff
			if frame.hBuffs then
				--H:DEBUG(1000,"disable healium buffs")
				for _, buff in ipairs(frame.hBuffs) do
					buff:Hide()
				end
			end
			if SpecSettings then
				UpdateFrameButtonsColor(frame)
			end
		end
	elseif frame.hDisabled then
		--H:DEBUG(1000,"DISABLED")
		frame.hDisabled = false
		if SpecSettings then
			UpdateFrameButtonsColor(frame)
		end
	end
end

-- For each spell, get cooldown then loop among Healium Unitframes and set cooldown
local lastCD = {} -- keep a list of CD between calls, if CD information are the same, no need to update buttons
local function UpdateCooldowns()
	--PerformanceCounter:Increment(ADDON_NAME, "UpdateCooldowns")
	--H:DEBUG(1000,"UpdateCooldowns")
	if not SpecSettings or not SpecSettings.spells then return end
	for index, spellSetting in ipairs(SpecSettings.spells) do
		local start, duration, enabled
		if spellSetting.spellID then
			start, duration, enabled = GetSpellCooldown(spellSetting.spellID)
		elseif spellSetting.macroName then
			local name = GetMacroSpell(spellSetting.macroName)
			if name then
				start, duration, enabled = GetSpellCooldown(name)
			else
				enabled = false
			end
		end
		if start and start > 0 then
			local arrayEntry = lastCD[index]
			if not arrayEntry or arrayEntry.start ~= start or arrayEntry.duration ~= duration then
				PerformanceCounter:Increment(ADDON_NAME, "UpdateButtonCooldown by frame")
				--H:DEBUG(1000,"CD KEEP:"..index.."  "..start.."  "..duration.."  /  "..(arrayEntry and arrayEntry.start or 'nil').."  "..(arrayEntry and arrayEntry.duration or 'nil'))
				ForEachUnitframeButton(index, UpdateButtonCooldown, start, duration, enabled)
				lastCD[index] = {start = start, duration = duration}
			else
				PerformanceCounter:Increment(ADDON_NAME, "SKIP UpdateButtonCooldown by frame")
				--H:DEBUG(1000,"CD SKIP:"..index.."  "..start.."  "..duration.."  /  "..(arrayEntry and arrayEntry.start or 'nil').."  "..(arrayEntry and arrayEntry.duration or 'nil'))
			end
		else
			PerformanceCounter:Increment(ADDON_NAME, "INVALID UpdateButtonCooldown by frame")
			-- H:DEBUG(1000,"CD: skipping:"..index)
		end
	end
end

-- Check OOM spells
local lastOOM = {} -- keep OOM status of previous step, if no change, no need to update butttons
local function UpdateOOMSpells()
	--PerformanceCounter:Increment(ADDON_NAME, "UpdateOOMSpells")
	--H:DEBUG(1000,"UpdateOOMSpells")
	if not SpecSettings or not SpecSettings.spells then return end
	for index, spellSetting in ipairs(SpecSettings.spells) do
		local spellName = spellSetting.spellName -- spellName is automatically set if spellID was found in settings
		if spellSetting.macroName then
			local macroID = GetMacroIndexByName(spellSetting.macroName)
			if macroID > 0 then
				spellName = GetMacroSpell(macroID)
			end
		end
		if spellName then
			--H:DEBUG(1000,"spellName:"..spellName)
			local _, OOM = IsUsableSpell(spellName)
			if lastOOM[index] ~= OOM then
				PerformanceCounter:Increment(ADDON_NAME, "UpdateButtonOOM by frame")
				ForEachUnitframeButton(index, UpdateButtonOOM, OOM, spellSetting)
				lastOOM[index] = OOM
			else
				PerformanceCounter:Increment(ADDON_NAME, "SKIP UpdateButtonOOM by frame")
				-- H:DEBUG(1000,"Skipping UpdateButtonOOM:"..index)
			end
		end
	end
end

-- Check OOR spells
local function UpdateOORSpells()
	PerformanceCounter:Increment(ADDON_NAME, "UpdateOORSpells")
	--H:DEBUG(1000,"UpdateOORSpells")
	if not SpecSettings or not SpecSettings.spells then return end
	for index, spellSetting in ipairs(SpecSettings.spells) do
		local spellName = spellSetting.spellName -- spellName is automatically set if spellID was found in settings
		if spellSetting.macroName then
			local macroID = GetMacroIndexByName(spellSetting.macroName)
			if macroID > 0 then
				spellName = GetMacroSpell(macroID)
			end
		end
		if spellName then
			--H:DEBUG(1000,"spellName:"..spellName)
			ForEachUnitframeButton(index, UpdateButtonOOR, spellName, spellSetting)
		end
	end
end

-- Update healium frame debuff position, debuff must be anchored to last shown button
local function UpdateFrameDebuffsPosition(frame)
	PerformanceCounter:Increment(ADDON_NAME, "UpdateFrameDebuffsPosition")
	if not frame.hDebuffs or not frame.hButtons then return end
	--H:DEBUG(1000,"UpdateFrameDebuffsPosition")
	--H:DEBUG(1000,"Update debuff position for "..frame:GetName())
	local anchor = frame
	if SpecSettings and SpecSettings.spells then -- if no heal buttons, anchor to unitframe
		anchor = frame.hButtons[#SpecSettings.spells]
	end
	--H:DEBUG(1000,"Update debuff position for "..frame:GetName().." anchoring on "..anchor:GetName())
	local firstDebuff = frame.hDebuffs[1]
	--H:DEBUG(1000,"anchor: "..anchor:GetName().."  firstDebuff: "..firstDebuff:GetName())
	local debuffSpacing = C.general.debuffSpacing or 2
	firstDebuff:ClearAllPoints()
	firstDebuff:SetPoint("TOPLEFT", anchor, "TOPRIGHT", debuffSpacing, 0)
end

-- Update healium frame buttons, set texture, extra attributes and show/hide.
local function UpdateFrameButtonsAttributes(frame)
	PerformanceCounter:Increment(ADDON_NAME, "UpdateFrameButtonsAttributes")
	if InCombatLockdown() then return end
	--H:DEBUG(1000,"Update frame buttons for "..frame:GetName())
	if not frame.hButtons then return end
	for i, button in ipairs(frame.hButtons) do
		--H:DEBUG(1000,"UpdateFrameButtonsAttributes:"..tostring(SpecSettings))--.."  "..(SpecSettings and SpecSettings.spells and tostring(#SpecSettings.spells) or "nil").."  "..i)
		if SpecSettings and SpecSettings.spells and i <= #SpecSettings.spells then
			local spellSetting = SpecSettings.spells[i]
			local icon, name, type
			if spellSetting.spellID then
				if IsSpellLearned(spellSetting.spellID) then
					type = "spell"
					name, _, icon = GetSpellInfo(spellSetting.spellID)
					button.hSpellBookID = GetSpellBookID(name)
					button.hMacroName = nil
				-- else
					-- if spellSetting.spellName then
						-- ERROR(string.format(L.CHECKSPELL_SPELLNOTLEARNED, name, spellSetting.spellID))
					-- else
						-- ERROR(string.format(L.CHECKSPELL_SPELLNOTEXISTS, spellSetting.spellID))
					-- end
				end
			elseif spellSetting.macroName then
				if GetMacroIndexByName(spellSetting.macroName) > 0 then
					type = "macro"
					icon = select(2,GetMacroInfo(spellSetting.macroName))
					name = spellSetting.macroName
					button.hSpellBookID = nil
					button.hMacroName = name
				-- else
					-- ERROR(string.format(L.CHECKSPELL_MACRONOTFOUND, spellSetting.macroName))
				end
			end
			if type and name and icon then
				--H:DEBUG(1000,"show button "..i.." "..frame:GetName().."  "..name)
				button.texture:SetTexture(icon)
				button:SetAttribute("type", type)
				button:SetAttribute(type, name)
				button.hInvalid = false
			else
				--H:DEBUG(1000,"invalid button "..i.." "..frame:GetName())
				button.hInvalid = true
				button.hSpellBookID = spellSetting.spellID
				button.hMacroName = spellSetting.macroName
				button.texture:SetTexture("Interface/Icons/INV_Misc_QuestionMark")
				--button:SetAttribute("type","target") -- action is target if spell is not valid
			end
			button:Show()
		else
			--H:DEBUG(1000,"hide button "..i.." "..frame:GetName())
			button.hInvalid = true
			button.hSpellBookID = nil
			button.hMacroName = nil
			button.texture:SetTexture("")
			button:Hide()
		end
	end
end

-------------------------------------------------------
-- Healium buttons/buff/debuffs creation
-------------------------------------------------------
local DelayedButtonsCreation = {}
-- Create heal buttons for a frame
local function CreateHealiumButtons(frame)
	if frame.hButtons then return end

	--H:DEBUG(1000,"CreateHealiumButtons")
	if InCombatLockdown() then
		--H:DEBUG(1000,"CreateHealiumButtons: delayed creation of frame "..frame:GetName())
		tinsert(DelayedButtonsCreation, frame)
		return
	end

	frame.hButtons = {}
	local buttonSize = frame:GetHeight()
	local buttonSpacing = C.general.buttonSpacing or 2
	for i = 1, C.general.maxButtonCount, 1 do
		-- name
		local buttonName = frame:GetName().."_HealiumButton_"..i
		-- anchor
		local anchor
		if i == 1 then
			anchor = {"TOPLEFT", frame, "TOPRIGHT", buttonSpacing, 0}
		else
			anchor = {"TOPLEFT", frame.hButtons[i-1], "TOPRIGHT", buttonSpacing, 0}
		end
		-- frame
		local button = H:CreateHealiumButton(frame, buttonName, buttonSize, anchor)
		assert(button.cooldown, "Missing cooldown on HealiumButton:"..buttonName) -- TODO: localization
		assert(button.texture, "Missing texture on HealiumButton:"..buttonName) -- TODO: localization
		local vr, vg, vb = button.texture:GetVertexColor()
		OriginButtonVertexColor = vr and {vr, vg, vb} or OriginButtonVertexColor
		local br, bg, bb = button:GetBackdropColor()
		OriginButtonBackdropColor = br and {br, bg, bb} or OriginButtonBackdropColor
		local bbr, bbg, bbb = button:GetBackdropBorderColor()
		OriginButtonBackdropBorderColor = bbr and {bbr, bbg, bbb} or OriginButtonBackdropBorderColor
		-- click event/action, attributes 'type' and 'spell' are set in UpdateFrameButtonsAttributes
		button:RegisterForClicks("AnyUp")
		button:SetAttribute("useparent-unit","true")
		button:SetAttribute("*unit2", "target")
		-- tooltip
		if C.general.showButtonTooltip then
			button:SetScript("OnEnter", ButtonOnEnter)
			button:SetScript("OnLeave", function(frame)
				GameTooltip:Hide()
			end)
		end
		-- custom
		button.hPrereqFailed = false
		button.hOOM = false
		button.hDispelHighlight = "none"
		button.hOOR = false
		button.hInvalid = true
		button.hNotUsable = false
		-- hide
		button:Hide()
		-- save button
		tinsert(frame.hButtons, button)
	end
end

-- Create debuffs for a frame
local function CreateHealiumDebuffs(frame)
	if frame.hDebuffs then return end

	--H:DEBUG(1000,"CreateHealiumDebuffs:"..frame:GetName())
	frame.hDebuffs = {}
	local debuffSize = frame:GetHeight()
	local debuffSpacing = C.general.debuffSpacing or 2
	for i = 1, C.general.maxDebuffCount, 1 do
		--H:DEBUG(1000,"Create debuff "..i)
		-- name
		local debuffName = frame:GetName().."_HealiumDebuff_"..i
		-- anchor
		local anchor
		if i == 1 then
			anchor = {"TOPLEFT", frame, "TOPRIGHT", debuffSpacing, 0}
		else
			anchor = {"TOPLEFT", frame.hDebuffs[i-1], "TOPRIGHT", debuffSpacing, 0}
		end
		-- frame
		local debuff = H:CreateHealiumDebuff(frame, debuffName, debuffSize, anchor)
		assert(debuff.icon, "Missing icon on HealiumDebuff:"..debuffName) -- TODO: localization
		assert(debuff.cooldown, "Missing cooldown on HealiumDebuff:"..debuffName) -- TODO: localization
		assert(debuff.count, "Missing count on HealiumDebuff:"..debuffName) -- TODO: localization
		-- tooltip
		if C.general.showDebuffTooltip then
			debuff:SetScript("OnEnter", DebuffOnEnter)
			debuff:SetScript("OnLeave", function(frame)
				GameTooltip:Hide()
			end)
		end
		-- hide
		debuff:Hide()
		-- save debuff
		tinsert(frame.hDebuffs, debuff)
	end
end

-- Create buff for a frame
local function CreateHealiumBuffs(frame)
	if not frame then return end
	if frame.hBuffs then return end

	--H:DEBUG(1000,"CreateHealiumBuffs:"..frame:GetName())
	frame.hBuffs = {}
	local buffSize = frame:GetHeight()
	local buffSpacing = C.general.buffSpacing or 2
	for i = 1, C.general.maxBuffCount, 1 do
		-- name
		local buffName = frame:GetName().."_HealiumBuff_"..i
		-- anchor
		local anchor
		 if i == 1 then
			anchor = {"TOPRIGHT", frame, "TOPLEFT", -buffSpacing, 0}
		else
			anchor = {"TOPRIGHT", frame.hBuffs[i-1], "TOPLEFT", -buffSpacing, 0}
		end
		-- frame
		local buff = H:CreateHealiumBuff(frame, buffName, buffSize, anchor)
		assert(buff.icon, "Missing icon on HealiumBuff:"..buffName) -- TODO: localization
		assert(buff.cooldown, "Missing cooldown on HealiumBuff:"..buffName) -- TODO: localization
		assert(buff.count, "Missing count on HealiumBuff:"..buffName) -- TODO: localization
		-- tooltip
		if C.general.showBuffDebuffTooltip then
			buff:SetScript("OnEnter", BuffOnEnter)
			buff:SetScript("OnLeave", function(frame)
				GameTooltip:Hide()
			end)
		end
		-- hide
		buff:Hide()
		-- save buff
		tinsert(frame.hBuffs, buff)
	end
end

-- Create delayed buttons
local function CreateDelayedButtons()
	if InCombatLockdown() then return false end
	--H:DEBUG(1000,"CreateDelayedButtons:"..tostring(DelayedButtonsCreation).."  "..(#DelayedButtonsCreation))
	if not DelayedButtonsCreation or #DelayedButtonsCreation == 0 then return false end

	for _, frame in ipairs(DelayedButtonsCreation) do
		--H:DEBUG(1000,"Delayed frame creation for "..frame:GetName())
		if not frame.hButtons then
			CreateHealiumButtons(frame)
		--else
			--H:DEBUG(1000,"Frame already created for "..frame:GetName())
		end
	end
	DelayedButtonsCreation = {}
	return true
end

-- Create unique debuff frame showing most important debuff
local function CreateHealiumPriorityDebuff(frame)
	if frame.hPriorityDebuff then return end
	local anchor = {"CENTER", frame, "CENTER", 10, 0}
	local size = frame:GetHeight()-6
	local debuffName = frame:GetName().."_HealiumPriorityDebuff"
	--local debuff = CreateFrame("Frame", debuffName, frame)
	local debuff = H:CreateHealiumDebuff(frame, debuffName, size, anchor)
	assert(debuff.icon, "Missing icon on HealiumDebuff:"..debuffName) -- TODO: localization
	assert(debuff.cooldown, "Missing cooldown on HealiumDebuff:"..debuffName) -- TODO: localization
	assert(debuff.count, "Missing count on HealiumDebuff:"..debuffName) -- TODO: localization
	debuff:SetFrameLevel(8)
	debuff:SetFrameStrata("MEDIUM") -- "BACKGROUND"
	debuff:SetAlpha(0.7)
	debuff:Hide()

	frame.hPriorityDebuff = debuff
end

-- Register a frame in Healium
function H:RegisterFrame(frame)
	if not HealiumInitialized then return false end

	-- heal buttons
	CreateHealiumButtons(frame)

	-- healium debuffs
	if C.general.showDebuff then
		CreateHealiumDebuffs(frame)
	end
	if C.general.showPriorityDebuff then
		CreateHealiumPriorityDebuff(frame) -- TEST
	end
	-- healium buffs
	if C.general.showBuff then
		CreateHealiumBuffs(frame)
	end
	-- update healium buttons visibility, icon and attributes + reposition debuff
	if SpecSettings then
		UpdateFrameButtonsAttributes(frame)
		-- update debuff position
		UpdateFrameDebuffsPosition(frame)
	end
	-- custom
	frame.hDisabled = false

	-- save frame in healium frame list
	SaveUnitframe(frame)

	return true
end

-------------------------------------------------------
-- Dump
-------------------------------------------------------
function H:DumpInformation(onlyShown)
	local infos = {}
	infos.LibVersion = GetAddOnMetadata(ADDON_NAME, "version")
	infos.PerformanceCounter = PerformanceCounter:Get(ADDON_NAME)
	infos.Units = {}
	ForEachUnitframeEvenIfInvalid(
		function (frame)
			if onlyShown == true and not frame:IsShown() then return end
			infos.Units[frame:GetName()] = {}
			local unitInfo = infos.Units[frame:GetName()]
			unitInfo.Unit = frame.unit
			unitInfo.Unitname = frame.unit and UnitName(frame.unit) or nil
			unitInfo.Disabled = frame.hDisabled
			unitInfo.Buttons = {}
			for i = 1, C.general.maxButtonCount, 1 do
				local button = frame.hButtons[i]
				if not onlyShown or button:IsShown() then
					unitInfo.Buttons[i] = {}
					local buttonInfo = unitInfo.Buttons[i]
					buttonInfo.Texture = button.texture and button.texture:GetTexture() or nil
					buttonInfo.IsShown = button:IsShown()
					buttonInfo.SpellID = button.hSpellBookID
					buttonInfo.MacroName = button.hMacroName
					buttonInfo.OOM = button.hOOM
					buttonInfo.NotUsable = button.hNotUsable
					buttonInfo.DispelHighlight = button.hDispelHighlight
					buttonInfo.OOR = button.hOOR
					buttonInfo.Invalid = button.hInvalid
				end
			end
			unitInfo.Buffs = {}
			for i = 1, C.general.maxBuffCount, 1 do
				local buff = frame.hBuffs[i]
				if not onlyShown or buff:IsShown() then
					unitInfo.Buffs[i] = {}
					local buffInfo = unitInfo.Buffs[i]
					buffInfo.IsShown = buff:IsShown()
					buffInfo.Icon = buff.icon and buff.icon:GetTexture() or nil
					buffInfo.Count = buff.count:GetText()
					buffInfo.ID = buff:GetID()
				end
			end
			unitInfo.Debuffs = {}
			for i = 1, C.general.maxDebuffCount, 1 do
				local debuff = frame.hDebuffs[i]
				if not onlyShown or debuff:IsShown() then
					unitInfo.Debuffs[i] = {}
					local debuffInfo = unitInfo.Debuffs[i]
					debuffInfo.IsShown = debuff:IsShown()
					debuffInfo.Icon = debuff.icon and debuff.icon:GetTexture() or nil
					debuffInfo.Count = debuff.count:GetText()
					debuffInfo.ID = debuff:GetID()
				end
			end
		end
	)
	return infos
end

-------------------------------------------------------
-- Events handler
-------------------------------------------------------
-- local function DisableHealium(handler)
	-- handler.hRespecing = nil
	-- handler:UnregisterAllEvents()
	-- handler:RegisterEvent("PLAYER_TALENT_UPDATE")
	-- ForEachUnitframeEvenIfInvalid(
		-- function(frame)
			-- -- disable buttons
			-- if frame.hButtons then
				-- for i = 1, C.general.maxButtonCount, 1 do
					-- local button = frame.hButtons[i]
					-- button.hInvalid = true
					-- button.hSpellBookID = nil
					-- button.hMacroName = nil
					-- button.texture:SetTexture("")
					-- button:Hide()
				-- end
			-- end
			-- -- disable buffs
			-- if frame.hBuffs then
				-- for i = 1, C.general.maxBuffCount, 1 do
					-- local buff = frame.hBuffs[i]
					-- buff.Hide()
				-- end
			-- end
			-- -- disable debuffs
			-- if frame.hDebuffs then
				-- for i = 1, C.general.maxDebuffCount, 1 do
					-- local debuff = frame.hDebuffs[i]
					-- debuff.Hide()
				-- end
			-- end
		-- end
	-- )
-- end

-- local function EnableHealium(handler)
	-- handler:RegisterEvent("RAID_ROSTER_UPDATE")
	-- handler:RegisterEvent("PARTY_MEMBERS_CHANGED")
	-- handler:RegisterEvent("PLAYER_REGEN_ENABLED")
	-- handler:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	-- handler:RegisterEvent("UNIT_AURA")
	-- handler:RegisterEvent("UNIT_POWER")
	-- handler:RegisterEvent("UNIT_MAXPOWER")
	-- --handler:RegisterEvent("UNIT_SPELLCAST_SENT")
	-- --handler:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	-- --handler:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	-- handler:RegisterEvent("UNIT_HEALTH_FREQUENT")
	-- handler:RegisterEvent("UNIT_CONNECTION")

	-- ForEachUnitframe(UpdateFrameButtonsAttributes)
	-- ForEachUnitframe(UpdateFrameDebuffsPosition)
	-- ForEachUnitframe(UpdateFrameBuffsDebuffsPrereqs)
-- end

function OnEvent(self, event, arg1, arg2, arg3)
	--H:DEBUG(1000,"Event: "..event.."  "..tostring(arg1).."  "..tostring(arg2).."  "..tostring(arg3))
	--PerformanceCounter:Increment(ADDON_NAME, event)

	if event == "PLAYER_ENTERING_WORLD" then
		GetSpecSettings()
		CheckSpellSettings()
		UpdateCooldowns()
		ForEachUnitframe(UpdateFrameButtonsAttributes)
		ForEachUnitframe(UpdateFrameDebuffsPosition)
		ForEachUnitframe(UpdateFrameBuffsDebuffsPrereqs)
	elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
		GetSpecSettings()
		ForEachUnitframe(UpdateFrameButtonsAttributes)
		ForEachUnitframe(UpdateFrameDebuffsPosition)
		ForEachUnitframe(UpdateFrameBuffsDebuffsPrereqs)
	elseif event == "PLAYER_REGEN_ENABLED" then
		local created = CreateDelayedButtons()
		if created then
			GetSpecSettings()
			ForEachUnitframe(UpdateFrameButtonsAttributes)
			ForEachUnitframe(UpdateFrameDebuffsPosition)
			ForEachUnitframe(UpdateFrameBuffsDebuffsPrereqs)
		end
	elseif event == "UNIT_SPELLCAST_SENT" and arg1 == "player" and (arg2 == ActivatePrimarySpecSpellName or arg2 == ActivateSecondarySpecSpellName) then
		--H:DEBUG(1, "Respec started")
		self.hRespecing = 1 -- respec started
	elseif (event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_SUCCEEDED") and arg1 == "player" and (arg2 == ActivatePrimarySpecSpellName or arg2 == ActivateSecondarySpecSpellName) then
		--H:DEBUG(1, "Respec stopped")
		self.hRespecing = nil --> respec stopped
	elseif event == "PLAYER_TALENT_UPDATE" then
		if self.hRespecing == 2 then -- respec finished
			--H:DEBUG(1, "Respec finished")
			ResetSpecSettings()
			GetSpecSettings()
			CheckSpellSettings()
			UpdateCooldowns()
			ForEachUnitframe(UpdateFrameButtonsAttributes, SpecSettings)
			ForEachUnitframe(UpdateFrameDebuffsPosition, SpecSettings)
			ForEachUnitframe(UpdateFrameBuffsDebuffsPrereqs, SpecSettings)
			self.hRespecing = nil -- no respec running
		elseif self.hRespecing == 1 then -- respec not yet finished
			--H:DEBUG(1, "Respec not yet finished")
			self.hRespecing = 2 -- respec finished
		else -- respec = nil, not respecing (called while connecting)
			--H:DEBUG(1, "no Respec")
			GetSpecSettings()
			UpdateCooldowns()
			ForEachUnitframe(UpdateFrameButtonsAttributes)
			ForEachUnitframe(UpdateFrameDebuffsPosition)
			ForEachUnitframe(UpdateFrameBuffsDebuffsPrereqs)
		end
	elseif event == "SPELL_UPDATE_COOLDOWN" then
		GetSpecSettings()
		if SpecSettings then
			PerformanceCounter:Increment(ADDON_NAME, "UpdateCooldowns")
			UpdateCooldowns()
		end
	elseif event == "UNIT_AURA" then
		GetSpecSettings()
		if SpecSettings then
			ForEachUnitframeWithUnit(arg1, UpdateFrameBuffsDebuffsPrereqs)
		end
	elseif (event == "UNIT_POWER" or event == "UNIT_MAXPOWER") and arg1 == "player" then
		local timeSpan = GetTime() - self.hTimeSinceLastOOM
		if timeSpan > UpdateDelay then
			if C.general.showOOM then
				--H:DEBUG(1, "Keeping UpdateOOMSpells: " .. tostring(timeSpan))
				GetSpecSettings()
				if SpecSettings then
					PerformanceCounter:Increment(ADDON_NAME, "UpdateOOMSpells")
					UpdateOOMSpells()
				end
			end
			self.hTimeSinceLastOOM = GetTime()
		else
			-- H:DEBUG(1, "Skipping UpdateOOMSpells: " .. tostring(timeSpan))
			PerformanceCounter:Increment(ADDON_NAME, "SKIP UpdateOOMSpells")
		end
	elseif event == "UNIT_CONNECTION" or event == "UNIT_HEALTH_FREQUENT" then
		GetSpecSettings()
		ForEachUnitframeWithUnit(arg1, UpdateFrameDisableStatus)
	end
end

local function OnUpdate(self, elapsed)
	self.hTimeSinceLastUpdate = self.hTimeSinceLastUpdate + elapsed
	if self.hTimeSinceLastUpdate > UpdateDelay then
		if C.general.showOOR then
			if SpecSettings then
				UpdateOORSpells()
			end
		end
		self.hTimeSinceLastUpdate = 0
	end
end

-------------------------------------------------------
-- Initialize
-------------------------------------------------------
function H:Initialize(config)
	if HealiumInitialized then return end
	HealiumInitialized = true

	-- Merge parameter config with Healium config
	if config then
		for key, value in pairs(config) do
			if C[key] then -- found in Healium config
				DEBUG(1, "Merging config "..tostring(key))
				if type(value) == "table" then
					for subKey, subValue in pairs(value) do
						if C[key][subKey] ~= nil then
							DEBUG(1, "Overriding "..tostring(subKey).."->"..tostring(C[key][subKey]).." with "..tostring(subValue))
							C[key][subKey] = DeepCopy(subValue)
						else
							DEBUG(1, "Copying "..tostring(subKey).."->"..tostring(subValue))
							C[key][subKey] = DeepCopy(subValue)
						end
					end
				else
					DEBUG(1, "Overriding "..tostring(key).."->"..tostring(C[key]).." with "..tostring(value))
					C[key] = DeepCopy(value) -- should never happens
				end
			end
		end
	end

	-- Initialize settings
	InitializeSettings()

	-- Create event handler
	local eventsHandler = CreateFrame("Frame")
	eventsHandler.hTimeSinceLastOOM = GetTime()
	eventsHandler:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventsHandler:RegisterEvent("RAID_ROSTER_UPDATE")
	eventsHandler:RegisterEvent("PARTY_MEMBERS_CHANGED")
	eventsHandler:RegisterEvent("PLAYER_REGEN_ENABLED")
	eventsHandler:RegisterEvent("PLAYER_TALENT_UPDATE")
	eventsHandler:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	eventsHandler:RegisterEvent("UNIT_AURA")
	eventsHandler:RegisterEvent("UNIT_POWER")
	eventsHandler:RegisterEvent("UNIT_MAXPOWER")
	eventsHandler:RegisterEvent("UNIT_SPELLCAST_SENT")
	eventsHandler:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	eventsHandler:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	eventsHandler:RegisterEvent("UNIT_HEALTH_FREQUENT")
	eventsHandler:RegisterEvent("UNIT_CONNECTION")
	eventsHandler:SetScript("OnEvent", OnEvent)

	eventsHandler.hTimeSinceLastUpdate = GetTime()
	eventsHandler:SetScript("OnUpdate", OnUpdate)
end