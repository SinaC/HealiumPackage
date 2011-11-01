-------------------------------------------------------
-- Healium components
-------------------------------------------------------

-- Exported functions
-- H:AddHealiumComponents(frame)	add healium buttons/buffs/debuffs to frame
-- H:DumpInformation()				return a table with every available information about buttons/buffs/debuffs

local ADDON_NAME, _ = ...
local H, C, L = unpack(select(2,...))

local FlashFrame = H.FlashFrame
local PerformanceCounter = H.PerformanceCounter

local DefaultButtonVertexColor = {1, 1, 1}
local DefaultButtonBackdropColor = {0.6, 0.6, 0.6}
local DefaultButtonBackdropBorderColor = {0.1, 0.1, 0.1}

local ActivatePrimarySpecSpellName = GetSpellInfo(63645)
local ActivateSecondarySpecSpellName = GetSpellInfo(63644)

local UpdateDelay = 0.2

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
local function Message(...)
	print("Healium_Components:", ...)
end

local function ERROR(...)
	print("|CFFFF0000Healium_Components|r:",...)
end

local function WARNING(...)
	print("|CFF00FFFFHealium_Components|r:",...)
end

local function DEBUG(lvl, ...)
	if C.general.debug and C.general.debug >= lvl then
		print("|CFF00FF00HC|r:",...)
	end
end

-- Get value or set to default if nil
local function Getter(value, default)
	return value == nil and default or value
end

-- Format big number
local function ShortValueNegative(v)
	if v <= 999 then return v end
	if v >= 1000000 then
		local value = string.format("%.1fm", v/1000000)
		return value
	elseif v >= 1000 then
		local value = string.format("%.1fk", v/1000)
		return value
	end
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

-------------------------------------------------------
-- Settings
-------------------------------------------------------
-- Get settings for current spec and assign it to SpecSettings (if not already set)
local function GetSpecSettings()
	if SpecSettings then return end
	if not C[H.myclass] then return end
	local ptt = GetPrimaryTalentTree()
	if not ptt then return end
	SpecSettings = C[H.myclass][ptt]
end

local function ResetSpecSettings()
	SpecSettings = nil
end

-- Create a list with spellID and spellName from a list of spellID (+ remove duplicates)
local function CreateDebuffFilterList(listName, list)
	local newList = {}
	local i = 1
	local index = 1
	while i <= #list do
		local spellName = GetSpellInfo(list[i])
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
				newList[index] = {spellID = list[i], spellName = spellName}
				index = index + 1
			-- else
				-- -- Duplicate found
				-- WARNING(string.format(L.SETTINGS_DUPLICATEBUFFDEBUFF, list[i], newList[j].spellID, spellName, listName))
			end
		else
			-- Unknown spell found
			WARNING(string.format(L.SETTINGS_UNKNOWNBUFFDEBUFF, list[i], listName))
		end
		i = i + 1
	end
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

	-- Fill blacklist and whitelist with spellName instead of spellID
	if C.blacklist and C.general.debuffFilter == "BLACKLIST" then
		C.blacklist = CreateDebuffFilterList("debuff blacklist", C.blacklist)
	else
		--DEBUG(1000,"Clearing debuffBlacklist")
		C.blacklist = nil
	end

	if C.whitelist and C.general.debuffFilter == "WHITELIST" then
		C.whitelist = CreateDebuffFilterList("debuff whitelist", C.whitelist)
	else
		--DEBUG(1000,"Clearing debuffWhitelist")
		C.whitelist = nil
	end

	-- Add spellName to spell list
	if C[H.myclass] then
		for _, specSetting in pairs(C[H.myclass]) do
			for _, spellSetting in ipairs(specSetting.spells) do
				if spellSetting.spellID then
					local spellName = GetSpellInfo(spellSetting.spellID)
					spellSetting.spellName = spellName
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
	PerformanceCounter:Increment(ADDON_NAME, "ForEachUnitframeWithUnit")
	if not Unitframes then return nil end
	for _, frame in ipairs(Unitframes) do
		if frame and frame.unit == unit then
			fct(frame, ...)
		end
	end
end

-- Loop among every valid unitframe in party/raid and call a function
local function ForEachUnitframe(fct, ...)
	PerformanceCounter:Increment(ADDON_NAME, "ForEachUnitframe")
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
	PerformanceCounter:Increment(ADDON_NAME, "ForEachUnitframeButton")
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
	PerformanceCounter:Increment(ADDON_NAME, "ForEachUnitframeEvenIfInvalid")
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

-- Update healium button color depending on frame and button status
-- frame disabled -> color in dark red except rez if dead or ghost
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
		button.texture:SetVertexColor(unpack(DefaultButtonVertexColor))
		button:SetBackdropColor(unpack(DefaultButtonBackdropColor))
		button:SetBackdropBorderColor(unpack(DefaultButtonBackdropBorderColor))
	end
end

-- Update button OOR
local function UpdateButtonOOR(frame, button, spellName, spellSetting)
	PerformanceCounter:Increment(ADDON_NAME, "UpdateButtonOOR")
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
	PerformanceCounter:Increment(ADDON_NAME, "UpdateButtonOOM")
	button.hOOM = OOM
	UpdateButtonColor(frame, button, spellSetting)
end

-- Update button cooldown
local function UpdateButtonCooldown(frame, button, start, duration, enabled)
	PerformanceCounter:Increment(ADDON_NAME, "UpdateButtonCooldown")
	CooldownFrame_SetTimer(button.cooldown, start, duration, enabled)
end

-- Update frame buttons color
local function UpdateFrameButtonsColor(frame)
	if not frame.hButtons then return end
	if not SpecSettings then return end
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

	--DEBUG(1000,"UpdateFrameBuffsDebuffsPrereqs: frame: "..frame:GetName().." unit: "..(unit or "nil"))

	local unit = frame.unit
	if not unit then return end

	-- reset button.hPrereqFailed and button.hDispelHighlight
	if frame.hButtons and not frame.hDisabled then
		--DEBUG(1000,"---- reset dispel, disabled")
		for index, button in ipairs(frame.hButtons) do
			button.hDispelHighlight = "none"
			button.hPrereqFailed = false
		end
	end

	-- buff: parse buff even if showBuff is set to false for prereq
	local buffCount = 0
	if not frame.hDisabled then
		local buffIndex = 1
		if SpecSettings then
			for i = 1, 40, 1 do
				-- get buff
				name, _, icon, count, _, duration, expirationTime, _, _, _, spellID = UnitAura(unit, i, "PLAYER|HELPFUL")
				if not name then
					buffCount = i-1
					break
				end
				listBuffs[i] = spellID -- display only buff castable by player but keep whole list of buff to check prereq
				-- is buff casted by player and in spell list?
				local found = false
				for index, spellSetting in ipairs(SpecSettings.spells) do
					if spellSetting.spellID and spellSetting.spellID == spellID then
						found = true
					elseif spellSetting.macroName then
						local macroID = GetMacroIndexByName(spellSetting.macroName)
						if macroID > 0 then
							local spellName = GetMacroSpell(macroID)
							if spellName == name then
								found = true
							end
						end
					end
				end
				if found and frame.hBuffs then
					-- buff casted by player and in spell list
					local buff = frame.hBuffs[buffIndex]
					-- id, unit  used by tooltip
					buff:SetID(i)
					buff.unit = unit
					-- texture
					buff.icon:SetTexture(icon)
					-- count
					if count > 1 then
						buff.count:SetText(count)
						buff.count:Show()
					else
						buff.count:Hide()
					end
					-- cooldown
					if duration and duration > 0 then
						--DEBUG(1000, "BUFF ON")
						local startTime = expirationTime - duration
						buff.cooldown:SetCooldown(startTime, duration)
					else
						--DEBUG(1000, "BUFF OFF")
						buff.cooldown:Hide()
					end
					-- show
					buff:Show()
					-- next buff
					buffIndex = buffIndex + 1
					-- too many buff?
					if buffIndex > C.general.maxBuffCount then
						--WARNING(string.format(L.BUFFDEBUFF_TOOMANYBUFF, frame:GetName(), unit))
						break
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

	-- debuff: parse debuff even if showDebuff is set to false for prereq
	local debuffCount = 0
	local debuffIndex = 1
	if SpecSettings or C.general.showDebuff then
		for i = 1, 40, 1 do
			-- get debuff
			local name, _, icon, count, debuffType, duration, expirationTime, _, _, _, spellID = UnitDebuff(unit, i)
			if not name then
				debuffCount = i-1
				break
			end
			--debuffType = "Curse" -- DEBUG purpose :)
			listDebuffs[i] = {spellID = spellID, type = debuffType} -- display not filtered debuff but keep whole debuff list to check prereq
			local dispellable = false -- default: non-dispellable
			if debuffType then
				for _, spellSetting in ipairs(SpecSettings.spells) do
					if spellSetting.dispels then
						local canDispel = type(spellSetting.dispels[debuffType]) == "function" and spellSetting.dispels[debuffType]() or spellSetting.dispels[debuffType]
						if canDispel then
							dispellable = true
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
							filtered = false -- found in whitelist -> not filtered
							break
						end
					end
				end
			end
			if not filtered and frame.hDebuffs then
				-- debuff not filtered
				local debuff = frame.hDebuffs[debuffIndex]
				-- id, unit  used by tooltip
				debuff:SetID(i)
				debuff.unit = unit
				-- texture
				debuff.icon:SetTexture(icon)
				-- count
				if count > 1 then
					debuff.count:SetText(count)
					debuff.count:Show()
				else
					debuff.count:Hide()
				end
				-- cooldown
				if duration and duration > 0 then
					local startTime = expirationTime - duration
					debuff.cooldown:SetCooldown(startTime, duration)
					debuff.cooldown:Show()
				else
					debuff.cooldown:Hide()
				end
				-- debuff color
				local debuffColor = debuffType and DebuffTypeColor[debuffType] or DebuffTypeColor["none"]
				--DEBUG(1000,"debuffType: "..(debuffType or 'nil').."  debuffColor: "..(debuffColor and debuffColor.r or 'nil')..","..(debuffColor and debuffColor.g or 'nil')..","..(debuffColor and debuffColor.b or 'nil'))
				debuff:SetBackdropBorderColor(debuffColor.r, debuffColor.g, debuffColor.b)
				-- show
				debuff:Show()
				-- next debuff
				debuffIndex = debuffIndex + 1
				--- too many debuff?
				if debuffIndex > C.general.maxDebuffCount then
					--WARNING(string.format(L.BUFFDEBUFF_TOOMANYDEBUFF, frame:GetName(), unit))
					break
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

	--DEBUG(1000,"BUFF:"..buffCount.."  DEBUFF:"..debuffCount)

	-- color dispel button if dispellable debuff + prereqs management (is buff or debuff a prereq to enable/disable a spell)
	if SpecSettings and frame.hButtons and not frame.hDisabled then
		local isUnitInRange = UnitInRange(unit)
		local debuffDispellableFound = false
		local highlightDispel = Getter(C.general.highlightDispel, true)
		local playSound = Getter(C.general.playSoundOnDispel, true)
		local flashStyle = C.general.flashStyle
		for index, spellSetting in ipairs(SpecSettings.spells) do
			local button = frame.hButtons[index]
			-- buff prereq: if not present, spell is inactive
			if spellSetting.buffs then
				--DEBUG(1000,"searching buff prereq for "..spellSetting.spellID)
				local prereqBuffFound = false
				for _, prereqBuffSpellID in ipairs(spellSetting.buffs) do
					--DEBUG(1000,"buff prereq for "..spellSetting.spellID.." "..prereqBuffSpellID)
					--for _, buff in pairs(listBuffs) do
					for i = 1, buffCount, 1 do
						local buff = listBuffs[i]
						--DEBUG(1000,"buff on unit "..buffSpellID)
						if buff == prereqBuffSpellID then
							--DEBUG(1000,"PREREQ: "..prereqBuffSpellID.." is a buff prereq for "..spellSetting.spellID.." "..button:GetName())
							prereqBuffFound = true
							break
						end
					end
					if prereqBuffFound then break end
				end
				if not prereqBuffFound then
					--DEBUG(1000,"PREREQ: BUFF for "..spellSetting.spellID.." NOT FOUND")
					button.hPrereqFailed = true
				end
			end
			-- debuff prereq: if present, spell is inactive
			if spellSetting.debuffs then
				--DEBUG(1000,"searching buff prereq for "..spellSetting.spellID)
				local prereqDebuffFound = false
				for _, prereqDebuffSpellID in ipairs(spellSetting.debuffs) do
					--DEBUG(1000,"buff prereq for "..spellSetting.spellID.." "..prereqDebuffSpellID)
					--for _, debuff in ipairs(listDebuffs) do
					for i = 1, debuffCount, 1 do
						local debuff = listDebuffs[i]
						local debuffSpellID = debuff.spellID -- [1] = spellID
						--DEBUG(1000,"debuff on unit "..debuffSpellID)
						if debuffSpellID == prereqDebuffSpellID then
							--DEBUG(1000,"PREREQ: "..prereqDebuffSpellID.." is a debuff prereq for "..spellSetting.spellID.." "..button:GetName())
							prereqDebuffFound = true
							break
						end
					end
					if prereqDebuffFound then break end
				end
				if prereqDebuffFound then
					--DEBUG(1000,"PREREQ: DEBUFF for "..spellSetting.spellID.." FOUND")
					button.hPrereqFailed = true
				end
			end
			-- color dispel button if affected by a debuff curable by a player spell
			if spellSetting.dispels and (highlightDispel or playSound or flashStyle ~= "NONE") then
				--for _, debuff in ipairs(listDebuffs) do
				for i = 1, debuffCount, 1 do
					local debuff = listDebuffs[i]
					local debuffType = debuff.type -- [2] = debuffType
					if debuffType then
						--DEBUG(1000,"type: "..type(spellSetting.dispels[debuffType]))
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
								if flashStyle == "FLASH" then
									FlashFrame:ShowFlashFrame(button, debuffColor, 320, 100, false)
								elseif flashStyle == "FADEOUT" then
									FlashFrame:Fadeout(button, 0.3)
								end
							end
							debuffDispellableFound = true
							break -- a debuff dispellable is enough
						end
					end
				end
			end
		end
		if debuffDispellableFound then
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

	--DEBUG(1000,"UpdateFrameVisibility: "..frame:GetName().."  "..(unit or 'nil'))
	if not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) then
		if not frame.hDisabled then
			--DEBUG(1000,"->DISABLE")
			frame.hDisabled = true
			-- hide buff
			if frame.hBuffs then
				--DEBUG(1000,"disable healium buffs")
				for _, buff in ipairs(frame.hBuffs) do
					buff:Hide()
				end
			end
			if SpecSettings then
				UpdateFrameButtonsColor(frame)
			end
		end
	elseif frame.hDisabled then
		--DEBUG(1000,"DISABLED")
		frame.hDisabled = false
		if SpecSettings then
			UpdateFrameButtonsColor(frame)
		end
	end
end

-- For each spell, get cooldown then loop among Healium Unitframes and set cooldown
local lastCD = {} -- keep a list of CD between calls, if CD information are the same, no need to update buttons
local function UpdateCooldowns()
	PerformanceCounter:Increment(ADDON_NAME, "UpdateCooldowns")
	--DEBUG(1000,"UpdateCooldowns")
	if not SpecSettings then return end
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
				--DEBUG(1000,"CD KEEP:"..index.."  "..start.."  "..duration.."  /  "..(arrayEntry and arrayEntry.start or 'nil').."  "..(arrayEntry and arrayEntry.duration or 'nil'))
				ForEachUnitframeButton(index, UpdateButtonCooldown, start, duration, enabled)
				lastCD[index] = {start = start, duration = duration}
			--else
				--DEBUG(1000,"CD SKIP:"..index.."  "..start.."  "..duration.."  /  "..(arrayEntry and arrayEntry.start or 'nil').."  "..(arrayEntry and arrayEntry.duration or 'nil'))
			end
		-- else
			-- DEBUG(1000,"CD: skipping:"..index)
		end
	end
end

-- Check OOM spells
local lastOOM = {} -- keep OOM status of previous step, if no change, no need to update butttons
local function UpdateOOMSpells()
	PerformanceCounter:Increment(ADDON_NAME, "UpdateOOMSpells")
	--DEBUG(1000,"UpdateOOMSpells")
	if not SpecSettings then return end
	for index, spellSetting in ipairs(SpecSettings.spells) do
		local spellName = spellSetting.spellName -- spellName is automatically set if spellID was found in settings
		if spellSetting.macroName then
			local macroID = GetMacroIndexByName(spellSetting.macroName)
			if macroID > 0 then
				spellName = GetMacroSpell(macroID)
			end
		end
		if spellName then
			--DEBUG(1000,"spellName:"..spellName)
			local _, OOM = IsUsableSpell(spellName)
			if lastOOM[index] ~= OOM then
				ForEachUnitframeButton(index, UpdateButtonOOM, OOM, spellSetting)
				lastOOM[index] = OOM
			-- else
				-- DEBUG(1000,"Skipping UpdateButtonOOM:"..index)
			end
		end
	end
end

-- Check OOR spells
local function UpdateOORSpells()
	PerformanceCounter:Increment(ADDON_NAME, "UpdateOORSpells")
	--DEBUG(1000,"UpdateOORSpells")
	if not SpecSettings then return end
	for index, spellSetting in ipairs(SpecSettings.spells) do
		local spellName = spellSetting.spellName -- spellName is automatically set if spellID was found in settings
		if spellSetting.macroName then
			local macroID = GetMacroIndexByName(spellSetting.macroName)
			if macroID > 0 then
				spellName = GetMacroSpell(macroID)
			end
		end
		if spellName then
			--DEBUG(1000,"spellName:"..spellName)
			ForEachUnitframeButton(index, UpdateButtonOOR, spellName, spellSetting)
		end
	end
end

-- Update healium frame debuff position, debuff must be anchored to last shown button
local function UpdateFrameDebuffsPosition(frame)
	PerformanceCounter:Increment(ADDON_NAME, "UpdateFrameDebuffsPosition")
	if not frame.hDebuffs or not frame.hButtons then return end
	--DEBUG(1000,"UpdateFrameDebuffsPosition")
	--DEBUG(1000,"Update debuff position for "..frame:GetName())
	local anchor = frame
	if SpecSettings then -- if no heal buttons, anchor to unitframe
		anchor = frame.hButtons[#SpecSettings.spells]
	end
	--DEBUG(1000,"Update debuff position for "..frame:GetName().." anchoring on "..anchor:GetName())
	local firstDebuff = frame.hDebuffs[1]
	--DEBUG(1000,"anchor: "..anchor:GetName().."  firstDebuff: "..firstDebuff:GetName())
	local debuffSpacing = C.general.debuffSpacing or 2
	firstDebuff:ClearAllPoints()
	firstDebuff:SetPoint("TOPLEFT", anchor, "TOPRIGHT", debuffSpacing, 0)
end

-- Update healium frame buttons, set texture, extra attributes and show/hide.
local function UpdateFrameButtonsAttributes(frame)
	PerformanceCounter:Increment(ADDON_NAME, "UpdateFrameButtonsAttributes")
	if InCombatLockdown() then return end
	--DEBUG(1000,"Update frame buttons for "..frame:GetName())
	if not frame.hButtons then return end
	for i, button in ipairs(frame.hButtons) do
		--DEBUG(1000,"UpdateFrameButtonsAttributes:"..tostring(SpecSettings))--.."  "..(SpecSettings and SpecSettings.spells and tostring(#SpecSettings.spells) or "nil").."  "..i)
		if SpecSettings and i <= #SpecSettings.spells then
			local spellSetting = SpecSettings.spells[i]
			local icon, name, type
			if spellSetting.spellID then
				if IsSpellLearned(spellSetting.spellID) then
					type = "spell"
					name, _, icon = GetSpellInfo(spellSetting.spellID)
					button.hSpellBookID = GetSpellBookID(name)
					button.hMacroName = nil
				else
					if spellSetting.spellName then
						ERROR(string.format(L.CHECKSPELL_SPELLNOTLEARNED, name, spellSetting.spellID))
					else
						ERROR(string.format(L.CHECKSPELL_SPELLNOTEXISTS, spellSetting.spellID))
					end
				end
			elseif spellSetting.macroName then
				if GetMacroIndexByName(spellSetting.macroName) > 0 then
					type = "macro"
					icon = select(2,GetMacroInfo(spellSetting.macroName))
					name = spellSetting.macroName
					button.hSpellBookID = nil
					button.hMacroName = name
				else
					ERROR(string.format(L.CHECKSPELL_MACRONOTFOUND, spellSetting.macroName))
				end
			end
			if type and name and icon then
				--DEBUG(1000,"show button "..i.." "..frame:GetName().."  "..name)
				button.texture:SetTexture(icon)
				button:SetAttribute("type", type)
				button:SetAttribute(type, name)
				button.hInvalid = false
			else
				--DEBUG(1000,"invalid button "..i.." "..frame:GetName())
				button.hInvalid = true
				button.hSpellBookID = spellSetting.spellID
				button.hMacroName = spellSetting.macroName
				button.texture:SetTexture("Interface/Icons/INV_Misc_QuestionMark")
				--button:SetAttribute("type","target") -- action is target if spell is not valid
			end
			button:Show()
		else
			--DEBUG(1000,"hide button "..i.." "..frame:GetName())
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

	--DEBUG(1000,"CreateHealiumButtons")
	if InCombatLockdown() then
		--DEBUG(1000,"CreateHealiumButtons: delayed creation of frame "..frame:GetName())
		tinsert(DelayedButtonsCreation, frame)
		return
	end

	frame.hButtons = {}
	local buttonSize = frame:GetHeight()
	local buttonSpacing = C.general.buttonSpacing or 2
	for i = 1, C.general.maxButtonCount, 1 do
		-- name
		local buttonName = frame:GetName().."_HealiumButton_"..i
		local anchor
		if i == 1 then
			anchor = {"TOPLEFT", frame, "TOPRIGHT", buttonSpacing, 0}
		else
			anchor = {"TOPLEFT", frame.hButtons[i-1], "TOPRIGHT", buttonSpacing, 0}
		end
		local button = H:CreateHealiumButton(frame, buttonName, buttonSize, anchor)
		assert(button.cooldown, "Missing cooldown on HealiumButton:"..buttonName) -- TODO: localization
		assert(button.texture, "Missing texture on HealiumButton:"..buttonName) -- TODO: localization
		local vr, vg, vb = button.texture:GetVertexColor()
		DefaultButtonVertexColor = vr and {vr, vg, vb} or DefaultButtonVertexColor
		local br, bg, bb = button:GetBackdropColor()
		DefaultButtonBackdropColor = br and {br, bg, bb} or DefaultButtonBackdropColor
		local bbr, bbg, bbb = button:GetBackdropBorderColor()
		DefaultButtonBackdropBorderColor = bbr and {bbr, bbg, bbb} or DefaultButtonBackdropBorderColor
		-- click event/action, attributes 'type' and 'spell' are set in UpdateFrameButtons
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

	--DEBUG(1000,"CreateHealiumDebuffs:"..frame:GetName())
	frame.hDebuffs = {}
	local debuffSize = frame:GetHeight()
	local debuffSpacing = C.general.debuffSpacing or 2
	for i = 1, C.general.maxDebuffCount, 1 do
		--DEBUG(1000,"Create debuff "..i)
		-- name
		local debuffName = frame:GetName().."_HealiumDebuff_"..i
		local anchor
		if i == 1 then
			anchor = {"TOPLEFT", frame, "TOPRIGHT", debuffSpacing, 0}
		else
			anchor = {"TOPLEFT", frame.hDebuffs[i-1], "TOPRIGHT", debuffSpacing, 0}
		end
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

	--DEBUG(1000,"CreateHealiumBuffs:"..frame:GetName())
	frame.hBuffs = {}
	local buffSize = frame:GetHeight()
	local buffSpacing = C.general.buffSpacing or 2
	for i = 1, C.general.maxBuffCount, 1 do
		local buffName = frame:GetName().."_HealiumBuff_"..i
		local anchor
		 if i == 1 then
			anchor = {"TOPRIGHT", frame, "TOPLEFT", -buffSpacing, 0}
		else
			anchor = {"TOPRIGHT", frame.hBuffs[i-1], "TOPLEFT", -buffSpacing, 0}
		end
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
	--DEBUG(1000,"CreateDelayedButtons:"..tostring(DelayedButtonsCreation).."  "..(#DelayedButtonsCreation))
	if not DelayedButtonsCreation or #DelayedButtonsCreation == 0 then return false end

	for _, frame in ipairs(DelayedButtonsCreation) do
		--DEBUG(1000,"Delayed frame creation for "..frame:GetName())
		if not frame.hButtons then
			CreateHealiumButtons(frame)
		--else
			--DEBUG(1000,"Frame already created for "..frame:GetName())
		end
	end
	DelayedButtonsCreation = {}
	return true
end

-- Add healium components to a frame
function H:AddHealiumComponents(frame)
	-- heal buttons
	CreateHealiumButtons(frame)

	-- healium debuffs
	if C.general.showDebuff then
		CreateHealiumDebuffs(frame)
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
end

-------------------------------------------------------
-- Handle healium specific events
-------------------------------------------------------
local function DisableHealium(handler)
	handler.hRespecing = nil
	handler:UnregisterAllEvents()
	handler:RegisterEvent("PLAYER_TALENT_UPDATE")
	ForEachUnitframeEvenIfInvalid(
		function(frame)
			-- disable buttons
			if frame.hButtons then
				for i = 1, C.general.maxButtonCount, 1 do
					local button = frame.hButtons[i]
					button.hInvalid = true
					button.hSpellBookID = nil
					button.hMacroName = nil
					button.texture:SetTexture("")
					button:Hide()
				end
			end
			-- disable buffs
			if frame.hBuffs then
				for i = 1, C.general.maxBuffCount, 1 do
					local buff = frame.hBuffs[i]
					buff.Hide()
				end
			end
			-- disable debuffs
			if frame.hDebuffs then
				for i = 1, C.general.maxDebuffCount, 1 do
					local debuff = frame.hDebuffs[i]
					debuff.Hide()
				end
			end
		end
	)
end

local function EnableHealium(handler)
	handler:RegisterEvent("RAID_ROSTER_UPDATE")
	handler:RegisterEvent("PARTY_MEMBERS_CHANGED")
	handler:RegisterEvent("PLAYER_REGEN_ENABLED")
	handler:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	handler:RegisterEvent("UNIT_AURA")
	handler:RegisterEvent("UNIT_POWER")
	handler:RegisterEvent("UNIT_MAXPOWER")
	--handler:RegisterEvent("UNIT_SPELLCAST_SENT")
	--handler:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	--handler:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	handler:RegisterEvent("UNIT_HEALTH_FREQUENT")
	handler:RegisterEvent("UNIT_CONNECTION")

	ForEachUnitframe(UpdateFrameButtonsAttributes)
	ForEachUnitframe(UpdateFrameDebuffsPosition)
	ForEachUnitframe(UpdateFrameBuffsDebuffsPrereqs)
end

local healiumEventHandler = CreateFrame("Frame")
healiumEventHandler:RegisterEvent("PLAYER_ENTERING_WORLD")
healiumEventHandler:RegisterEvent("ADDON_LOADED")
healiumEventHandler:RegisterEvent("RAID_ROSTER_UPDATE")
healiumEventHandler:RegisterEvent("PARTY_MEMBERS_CHANGED")
healiumEventHandler:RegisterEvent("PLAYER_REGEN_ENABLED")
healiumEventHandler:RegisterEvent("PLAYER_TALENT_UPDATE")
healiumEventHandler:RegisterEvent("SPELL_UPDATE_COOLDOWN")
healiumEventHandler:RegisterEvent("UNIT_AURA")
healiumEventHandler:RegisterEvent("UNIT_POWER")
healiumEventHandler:RegisterEvent("UNIT_MAXPOWER")
--healiumEventHandler:RegisterEvent("UNIT_SPELLCAST_SENT")
--healiumEventHandler:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
--healiumEventHandler:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
healiumEventHandler:RegisterEvent("UNIT_HEALTH_FREQUENT")
healiumEventHandler:RegisterEvent("UNIT_CONNECTION")
healiumEventHandler:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
	--DEBUG(1000,"Event: "..event)
	PerformanceCounter:Increment(ADDON_NAME, event)

	if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
		self:UnregisterEvent("ADDON_LOADED")
		local version = GetAddOnMetadata(ADDON_NAME, "version")
		if version then
			Message(string.format(L.GREETING_VERSION, tostring(version)))
		else
			Message(L.GREETING_VERSIONUNKNOWN)
		end
		Message(L.GREETING_OPTIONS)
		InitializeSettings()
	elseif event == "PLAYER_ENTERING_WORLD" or event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
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
	-- elseif event == "UNIT_SPELLCAST_SENT" and arg1 == "player" and (arg2 == ActivatePrimarySpecSpellName or arg2 == ActivateSecondarySpecSpellName) then
		-- self.hRespecing = 1 -- respec started
	-- elseif (event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_SUCCEEDED") and arg1 == "player" and (arg2 == ActivatePrimarySpecSpellName or arg2 == ActivateSecondarySpecSpellName) then
		-- self.hRespecing = nil --> respec stopped
	elseif event == "PLAYER_TALENT_UPDATE" then
		ResetSpecSettings()
		-- if self.hRespecing == 2 then -- respec finished
			-- local SpecSettings = GetSpecSettings()
			-- ForEachUnitframe(UpdateFrameButtonsAttributes, SpecSettings)
			-- ForEachUnitframe(UpdateFrameDebuffsPosition, SpecSettings)
			-- ForEachUnitframe(UpdateFrameBuffsDebuffsPrereqs, SpecSettings)
			-- self.hRespecing = nil -- no respec running
		-- elseif self.hRespecing == 1 then -- respec not yet finished
			-- self.hRespecing = 2 -- respec finished
		-- else -- respec = nil, not respecing (called while connecting)
		GetSpecSettings()
		ForEachUnitframe(UpdateFrameButtonsAttributes)
		ForEachUnitframe(UpdateFrameDebuffsPosition)
		ForEachUnitframe(UpdateFrameBuffsDebuffsPrereqs)
		-- end
	elseif event == "SPELL_UPDATE_COOLDOWN" then
		GetSpecSettings()
		if SpecSettings then UpdateCooldowns() end
	elseif event == "UNIT_AURA" then
		GetSpecSettings()
		if SpecSettings then
			ForEachUnitframeWithUnit(arg1, UpdateFrameBuffsDebuffsPrereqs)
		end
	elseif (event == "UNIT_POWER" or event == "UNIT_MAXPOWER") and arg1 == "player" then
		if C.general.showOOM then
			GetSpecSettings()
			if SpecSettings then
				UpdateOOMSpells()
			end
		end
	elseif event == "UNIT_CONNECTION" or event == "UNIT_HEALTH_FREQUENT" then
		GetSpecSettings()
		ForEachUnitframeWithUnit(arg1, UpdateFrameDisableStatus)
	end
end)

if C.general.showOOR then
	healiumEventHandler.hTimeSinceLastUpdate = GetTime()
	healiumEventHandler:SetScript("OnUpdate", function (self, elapsed)
		self.hTimeSinceLastUpdate = self.hTimeSinceLastUpdate + elapsed
		if self.hTimeSinceLastUpdate > UpdateDelay then
			--GetSpecSettings()
			if SpecSettings then
				UpdateOORSpells()
			end
			self.hTimeSinceLastUpdate = 0
		end
	end)
end

-------------------------------------------------------
-- Dump
-------------------------------------------------------
function H:DumpInformation()
	local infos = {}
	infos.Version = GetAddOnMetadata(ADDON_NAME, "version")
	infos.PerformanceCounter = PerformanceCounter:Get(ADDON_NAME)
	infos.Units = {}
	ForEachUnitframeEvenIfInvalid(
		function (frame)
			infos.Units[frame:GetName()] = {}
			local unitInfo = infos.Units[frame:GetName()]
			unitInfo.Unit = frame.unit
			unitInfo.Unitname = frame.unit and UnitName(frame.unit) or nil
			unitInfo.Disabled = frame.hDisabled
			unitInfo.Buttons = {}
			for i = 1, C.general.maxButtonCount, 1 do
				local button = frame.hButtons[i]
				unitInfo.Buttons[i] = {}
				local buttonInfo = unitInfo.Buttons[i]
				buttonInfo.Texture = button.icon and button.icon:GetTexture() or nil
				buttonInfo.IsShown = button:IsShown()
				buttonInfo.SpellID = button.hSpellBookID
				buttonInfo.MacroName = button.hMacroName
				buttonInfo.OOM = button.hOOM
				buttonInfo.NotUsable = button.hNotUsable
				buttonInfo.DispelHighlight = button.hDispelHighlight
				buttonInfo.OOR = button.hOOR
				buttonInfo.Invalid = button.hInvalid
			end
			unitInfo.Buffs = {}
			for i = 1, C.general.maxBuffCount, 1 do
				local buff = frame.hBuffs[i]
				unitInfo.Buffs[i] = {}
				local buffInfo = unitInfo.Buffs[i]
				buffInfo.IsShown = buff:IsShown()
				buffInfo.Texture = buff.texture and buff.texture:GetTexture() or nil
				buffInfo.Count = buff.count:GetText()
				buffInfo.ID = buff:GetID()
			end
			unitInfo.Debuffs = {}
			for i = 1, C.general.maxDebuffCount, 1 do
				local debuff = frame.hDebuffs[i]
				unitInfo.Debuffs[i] = {}
				local debuffInfo = unitInfo.Debuffs[i]
				debuffInfo.IsShown = debuff:IsShown()
				debuffInfo.Texture = debuff.texture and debuff.texture:GetTexture() or nil
				debuffInfo.Count = debuff.count:GetText()
				debuffInfo.ID = debuff:GetID()
			end
		end
	)
	return infos
end