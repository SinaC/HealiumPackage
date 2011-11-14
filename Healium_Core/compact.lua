local ADDON_NAME, ns = ...
local H, C, L = unpack(select(2,...))

-- TODO: 
-- add an optional litte square on a spell to indicate if spell's buff present (beacon of light, hands of protection, ...)
-- priority debuff
-- debuff frame border highlight
-- frame background

if true then return end

local FlashFrame = H.FlashFrame
local Private = ns.Private

local ERROR = Private.ERROR
local WARNING = Private.WARNING
local DEBUG = Private.DEBUG

local buttonSize = 20
local selfWidth = 5*buttonSize
local selfHeight = 4*buttonSize

--[[

normal = {
	buttons = {
	}
},
compact = {
	bars = {
	},
	buttons = {
	},
	hidden = {
	}
}

--]]

-- 15 buttons
-- 2 bars + 10 buttons
-- 4 bars + 5 buttons

C["compact"] = {
	["DRUID"] = {
		[3] = {
			bars = {
				{ spellID = 774, color = {0.85, 0.15, 0.80} }, -- Rejuvenation
				{ spellID = 33763, color = {0, 0, 0.8} }, -- Lifebloom
				{ spellID = 8936, color = {0.05, 0.3, 0.1} }, -- Regrowth
				{ spellID = 48438, color = {0.5, 0.8, 0.3} }, -- Wild Growth
			},
			buttons = {
				{ spellID = 50464 }, -- Nourish
				{ spellID = 18562, buffs = { 774, 8936 } }, -- Swiftmend, castable only if affected by Rejuvenation or Regrowth
				{ spellID = 5185 }, -- Macro Nature Swiftness + Healing Touch
				{ spellID = 20484, rez = true }, -- Rebirth
			},
			hidden = { -- no icon, spell cast when right-clicking on frame
				{ spellID = 2782, dispels = { ["Poison"] = true, ["Curse"] = true, ["Magic"] = function() return select(5, GetTalentInfo(3,17)) > 0 end } }, -- Remove Corruption
			}
		}
	},
	["SHAMAN"] = {
		[3] = {
			bars = {
				{ spellID = 974, color = {0.85, 0.65, 0.1} }, -- Earth Shield
				{ spellID = 61295, color = {0.1, 0.1, 0.9} }, -- Riptide
			},
			buttons = {
				{ spellID = 8004 }, -- Healing Surge
				{ spellID = 331 }, -- Healing Wave
				{ spellID = 77472 },  -- Greater Healing Wave
				{ spellID = 1064 }, -- Chain Heal
			},
			hidden = {
				{ spellID = 51886, dispels = { ["Curse"] = true, ["Magic"] = function() return select(5, GetTalentInfo(3,12)) > 0 end } }, -- Cleanse Spirit
			}
		}
	},
	["PALADIN"] = {
		[1] = {
			bars = {
				--{ spellID = 53563, color = {0.9, 0.7, 0.1} }, -- Beacon of Light
				{ spellID = 6940, color = {0.5, 0.5, 0.9} }, -- Hand of Sacrifice
				{ spellID = 1044, color = {0.4, 0.8, 0.9} }, -- Hand of Freedom
			},
			buttons = {
				{ spellID = 20473 }, -- Holy Shock
				{ spellID = 85673 }, -- Word of Glory
				{ spellID = 19750 }, -- Flash of Light
				{ spellID = 635 }, -- Holy Light
				{ spellID = 82326 }, -- Divine Light
				{ spellID = 633, debuffs = { 25771 } }, -- Lay on Hands (not if affected by Forbearance)
				{ spellID = 1022, debuffs = { 25771 } }, -- Hand of Protection (not if affected by Forbearance)
				{ spellID = 53563, color = {0.9, 0.7, 0.1} }, -- Beacon of Light
			},
			hidden = {
				{ spellID = 4987, dispels = { ["Poison"] = true, ["Disease"] = true, ["Magic"] = function() return select(5, GetTalentInfo(1,14)) > 0 end } }, -- Cleanse
			}
		}
	}
}

local cfg = nil
if H.myname == "Meuhhnon" then cfg = C["compact"]["DRUID"][3] end
if H.myname == "Yoog" then cfg = C["compact"]["SHAMAN"][3] end
if H.myname == "Enimouchet" then cfg = C["compact"]["PALADIN"][1] end

if cfg == nil then return end

DEBUG(1,"TESTING COMPACT MODE...")


local Unitframes = {}

-- Loop among every valid unitframe in party/raid and call a function
local function ForEachUnitframe(fct, ...)
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

-- Loop among every valid with specified unit unitframe in party/raid and call a function
local function ForEachUnitframeWithUnit(unit, fct, ...)
	if not Unitframes then return nil end
	for _, frame in ipairs(Unitframes) do
		if frame and frame.unit == unit then
			fct(frame, ...)
		end
	end
end

-- Update button cooldown
local function UpdateButtonCooldown(frame, button, start, duration, enabled)
	CooldownFrame_SetTimer(button.cooldown, start, duration, enabled)
end

-- Update cooldowns
local lastCD = {} -- keep a list of CD between calls, if CD information are the same, no need to update buttons
local function UpdateCooldowns()
	-- buttons
	for _, spellSetting in ipairs(cfg.buttons) do
		local start, duration, enabled
		local index = spellSetting.buttonIndex
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
				ForEachUnitframeButton(index, UpdateButtonCooldown, start, duration, enabled)
				lastCD[index] = {start = start, duration = duration}
			end
		end
	end
	-- bars
	for _, barSetting in ipairs(cfg.bars) do
		local start, duration, enabled
		local index = barSetting.buttonIndex
		if barSetting.spellID then
			start, duration, enabled = GetSpellCooldown(barSetting.spellID)
		elseif barSetting.macroName then
			local name = GetMacroSpell(barSetting.macroName)
			if name then
				start, duration, enabled = GetSpellCooldown(name)
			else
				enabled = false
			end
		end
		if start and start > 0 then
			local arrayEntry = lastCD[index]
			if not arrayEntry or arrayEntry.start ~= start or arrayEntry.duration ~= duration then
				ForEachUnitframeButton(index, UpdateButtonCooldown, start, duration, enabled)
				lastCD[index] = {start = start, duration = duration}
			end
		end
	end
	-- GCD
	local start, duration, enabled = GetSpellCooldown(774)
	ForEachUnitframe(
		function(frame, start, duration, enabled)
			frame.hGCD:Show()
			CooldownFrame_SetTimer( frame.hGCD, start, duration, enabled)
		end,
		start, duration, enabled)
end

-- Update bar
local function Round(number, decimals) -- TUKUI
	if not decimals then decimals = 0 end
    return (("%%.%df"):format(decimals)):format(number)
end

local function RGBToHex(r, g, b) -- TUKUI
	r = r <= 1 and r >= 0 and r or 0
	g = g <= 1 and g >= 0 and g or 0
	b = b <= 1 and b >= 0 and b or 0
	return string.format("|cff%02x%02x%02x", r*255, g*255, b*255)
end

--returns both what text to display, and how long until the next update
local DAY, HOUR, MINUTE = 86400, 3600, 60 --used for formatting text
local DAYISH, HOURISH, MINUTEISH = 3600 * 23.5, 60 * 59.5, 59.5 --used for formatting text at transition points
local HALFDAYISH, HALFHOURISH, HALFMINUTEISH = DAY/2 + 0.5, HOUR/2 + 0.5, MINUTE/2 + 0.5 --used for calculating next update times
local EXPIRING_DURATION = 8 --the minimum number of seconds a cooldown must be to use to display in the expiring format
local EXPIRING_FORMAT = RGBToHex(1, 0, 0)..'%.1f|r' --format for timers that are soon to expire
local SECONDS_FORMAT = RGBToHex(1, 1, 0)..'%d|r' --format for timers that have seconds remaining
local MINUTES_FORMAT = RGBToHex(1, 1, 1)..'%dm|r' --format for timers that have minutes remaining
local HOURS_FORMAT = RGBToHex(0.4, 1, 1)..'%dh|r' --format for timers that have hours remaining
local DAYS_FORMAT = RGBToHex(0.4, 0.4, 1)..'%dh|r' --format for timers that have days remaining
local function GetTimeText(s) -- TUKUI
	--format text as seconds when below a minute
	if s < MINUTEISH then
		local seconds = tonumber(Round(s))
		if seconds > EXPIRING_DURATION then
			return SECONDS_FORMAT, seconds, s - (seconds - 0.51)
		else
			return EXPIRING_FORMAT, s, 0.051
		end
	--format text as minutes when below an hour
	elseif s < HOURISH then
		local minutes = tonumber(Round(s/MINUTE))
		return MINUTES_FORMAT, minutes, minutes > 1 and (s - (minutes*MINUTE - HALFMINUTEISH)) or (s - MINUTEISH)
	--format text as hours when below a day
	elseif s < DAYISH then
		local hours = tonumber(Round(s/HOUR))
		return HOURS_FORMAT, hours, hours > 1 and (s - (hours*HOUR - HALFHOURISH)) or (s - HOURISH)
	--format text as days
	else
		local days = tonumber(Round(s/DAY))
		return DAYS_FORMAT, days,  days > 1 and (s - (days*DAY - HALFDAYISH)) or (s - DAYISH)
	end
end

local function UpdateBar(self, elapsed)
	if self.nextUpdate > 0 then
		self.nextUpdate = self.nextUpdate - elapsed
	else
		local t = GetTime()
		local remain = self.duration - (t - self.startTime)
		if tonumber(Round(remain)) > 0 then
			local formatStr, time, nextUpdate = GetTimeText(remain)

			self.timeLeft:SetFormattedText(formatStr, time)

			if self.rightToLeft then
				--self:SetMinMaxValues(t, t + self.duration)
				--self:SetValue(t)
				local width = self.originalWidth * (remain/self.duration)
				if width <= 0 then width = 0.01 end
				self:SetWidth(width)
			else
				self:SetValue(remain)
			end

			self.nextUpdate = nextUpdate
		else
			self:SetScript("OnUpdate", nil)
			self.enabled = false
			self:Hide()
		end
	end
end

-- Update frame buffs
local function UpdateFrameBuffs(frame)
	--DEBUG(1,"UpdateFrameBuffs")
	local unit = frame.unit
	if not unit then return end

	for i = 1, 40, 1 do
		local name, _, icon, count, _, duration, expirationTime, unitCaster, _, _, spellID = UnitAura(unit, i, "HELPFUL")
		if unitCaster == "player" then
			if frame.hCompactMode then
				for index, barSetting in ipairs(cfg.bars) do
					if barSetting.spellID == spellID then
						local bar = frame.hBuffs[index]
						if duration and duration > 0 then
							local startTime = expirationTime - duration
							bar.startTime = startTime
							bar.duration = duration
							bar.nextUpdate = 0
							bar.enabled = true
							bar:SetMinMaxValues(0, duration)
							if bar.rightToLeft then
								bar:SetWidth(bar.originalWidth)
								bar:SetValue(duration)
							end
							bar:Show()
							bar:SetScript("OnUpdate", UpdateBar)
						end
						if count > 1 then
							bar.count:SetText(count)
							bar.count:Show()
						else
							bar.count:Hide()
						end

					end
				end
			end
		end
	end
end

local function ButtonOnEnter(self)
	-- self.originalFrameLevel = self:GetFrameLevel()
	-- self:SetFrameLevel(self.originalFrameLevel+1)
	-- FlashFrame:ZoomIn(self, 1.5)
	--TODO: tooltip
end

local function ButtonOnLeave(self)
	-- FlashFrame:ZoomOut(self)
	-- self:SetFrameLevel(self.originalFrameLevel)
	--TODO: tooltip
end

local function UpdateHealth(self, event, unit)
	local frame = self:GetParent()
	if frame.unit ~= unit then return end

	local min, max = UnitHealth(unit), UnitHealthMax(unit)
	self:SetMinMaxValues(0, max)
	self:SetValue(min)

	frame.Health.value:SetFormattedText("%d%%", floor(min / max * 100))
end

local function UpdateResource(self, event, unit)
	local frame = self:GetParent()
	if frame.unit ~= unit then return end

	local displayType = UnitPowerType(unit)
	local min, max = UnitPower(unit, displayType), UnitPowerMax(unit, displayType)
	self:SetMinMaxValues(0, max)
	self:SetValue(min)
end

--[[
100x80  (5x20 X 4*20)
Rshshshshshshshshshs        R: resource [4x20]
R   Name                    Name: unit name
R   Debuff      %HP         Debuff: priority debuff [20x20]
Rshshshshshshshshshs        %HP: percentage health
H3H3<-----T----CH4H4        H1, H2, H3, H4: bar (with CD) [20x20]
H3H3C-----T---->H4H4        s1, s2, s3, s4: status bar  s1, s3: C--T-->    s2, s4: <--T--C   C: count   T: time left  [60x20]
H1H1<-----T----CH2H2        D1, D2, D3, D4, D5: direct heal [20x20]
H1H1C-----T---->H2H2        sh: health status bar [96x20]
D1D1D2D2D3D3D4D4D5D5
D1D1D2D2D3D3D4D4D5D5

if only 2 bars, move H1 et H2 and add one more row of direct heals
--]]

function CompactFrame_OnLoad(self)
	DEBUG(1,"CompactFrame_OnLoad:"..self:GetName())

	self:SetFrameStrata("BACKGROUND")

	-- compact mode
	self.hCompactMode = true

	-- TODO: MACRO
	local buttonIndex = 1
	self.hButtons = {} -- bars + buttons
	self.hBuffs = {} -- bars

	-- buttons
	for i = 1, #cfg.buttons, 1 do
		local spell = cfg.buttons[i]
		local spellName, _, icon = GetSpellInfo(spell.spellID)
		-- button
		local buttonName = self:GetName().."_HealiumButton_"..i
		local button = CreateFrame("Button", name, self, "SecureActionButtonTemplate")
		if i == 1 then
			button:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
		elseif i == 6 or i == 11 then
			button:SetPoint("BOTTOMLEFT", self.hButtons[i-5], "TOPLEFT", 0, 0)
		else
			button:SetPoint("TOPLEFT", self.hButtons[i-1], "TOPRIGHT", 0, 0)
		end
		button:SetFrameStrata("MEDIUM")
		button:SetFrameLevel(2)
		button:SetHeight(buttonSize)
		button:SetWidth(buttonSize)
		-- texture setup, texture icon is set in UpdateFrameButtons
		button.texture = button:CreateTexture(nil, "BORDER")
		button.texture:SetPoint("TOPLEFT", button ,"TOPLEFT", 0, 0)
		button.texture:SetPoint("BOTTOMRIGHT", button ,"BOTTOMRIGHT", 0, 0)
		button.texture:SetTexture(icon)
		button:SetPushedTexture("Interface/Buttons/UI-Quickslot-Depress")
		button:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square")
		button.texture:SetTexCoord(0.1, 0.9, 0.1, 0.9)
		-- cooldown overlay
		button.cooldown = CreateFrame("Cooldown", "$parentCD", button, "CooldownFrameTemplate")
		button.cooldown:SetAllPoints(button.texture)
		-- click event/action
		button:RegisterForClicks("LeftButtonUp")
		button:SetAttribute("useparent-unit", "true")
		button:SetAttribute("type", "spell") -- TODO: set later
		button:SetAttribute("spell", spellName) -- TODO: set later
		-- OnEnter/OnLeave
		button:SetScript("OnEnter", ButtonOnEnter)
		button:SetScript("OnLeave", ButtonOnLeave)
DEBUG(1,"Adding button for "..tostring(spellName).."  "..tostring(icon))
		tinsert(self.hButtons, button)
		spell.buttonIndex = buttonIndex
		buttonIndex = buttonIndex + 1
	end

	local spellsRowCount = math.ceil(#cfg.buttons/5)

	-- bars (TODO: max 4)
	if cfg.bars then
		for i = 1, #cfg.bars, 1 do
			local barSetting = cfg.bars[i]
			local spellName, _, icon = GetSpellInfo(barSetting.spellID)

			-- button
			local buttonName = self:GetName().."_HealiumBarButton_"..i
			local button = CreateFrame("Button", name, self, "SecureActionButtonTemplate")
			button:SetFrameStrata("MEDIUM")
			button:SetFrameLevel(2)
			button:SetHeight(buttonSize)
			button:SetWidth(buttonSize)
			-- texture setup, texture icon is set in UpdateFrameButtons
			button.texture = button:CreateTexture(nil, "BORDER")
			button.texture:SetPoint("TOPLEFT", button ,"TOPLEFT", 0, 0)
			button.texture:SetPoint("BOTTOMRIGHT", button ,"BOTTOMRIGHT", 0, 0)
			button.texture:SetTexture(icon)
			button:SetPushedTexture("Interface/Buttons/UI-Quickslot-Depress")
			button:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square")
			button.texture:SetTexCoord(0.1, 0.9, 0.1, 0.9)
			-- cooldown overlay
			button.cooldown = CreateFrame("Cooldown", "$parentCD", button, "CooldownFrameTemplate")
			button.cooldown:SetAllPoints(button.texture)
			-- click event/action
			button:RegisterForClicks("LeftButtonUp")
			button:SetAttribute("useparent-unit", "true")
			button:SetAttribute("type", "spell") -- TODO: set later
			button:SetAttribute("spell", spellName) -- TODO: set later
			-- OnEnter/OnLeave
			button:SetScript("OnEnter", ButtonOnEnter)
			button:SetScript("OnLeave", ButtonOnLeave)
	DEBUG(1,"Adding bar for "..tostring(spellName).."  "..tostring(icon))

			-- status bar
			local barName = self:GetName().."_HealiumBar_"..i
			local bar = CreateFrame("StatusBar", barName, self)
			bar:SetFrameStrata("MEDIUM")
			bar:SetFrameLevel(3)
			bar:SetWidth(selfWidth-2*buttonSize)
			bar:SetHeight(buttonSize/2)
			bar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Resource-Fill")
			bar:SetStatusBarColor(unpack(barSetting.color))
			bar:SetMinMaxValues(0,10)
			bar:SetValue(0)
			-- time left
			bar.timeLeft = bar:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			bar.timeLeft:SetJustifyH("CENTER")
			-- count
			bar.count = bar:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			bar.count:SetJustifyH("CENTER")
			-- cd -> on button

			-- set anchors
			if i == 1 then
				previousLeft = button
				button:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, buttonSize*spellsRowCount)
				bar:SetPoint("BOTTOMLEFT", button, "BOTTOMRIGHT", 0, 0)
				bar.count:SetPoint("LEFT", bar)
				bar.timeLeft:SetPoint("CENTER", bar)
			elseif i == 2 then
				previousRight = button
				button:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, buttonSize*spellsRowCount)
				bar:SetPoint("TOPRIGHT", button, "TOPLEFT", 0, 0)
				bar.count:SetPoint("RIGHT", bar)
				bar.rightToLeft = true
				bar.originalWidth = bar:GetWidth()
				bar.timeLeft:SetPoint("RIGHT", button, "RIGHT", -(selfWidth-buttonSize)/2, 4)
			elseif i == 3 then
				button:SetPoint("BOTTOMLEFT", self.hButtons[buttonIndex-2], "TOPLEFT", 0, 0)
				bar:SetPoint("BOTTOMLEFT", button, "BOTTOMRIGHT", 0, 0)
				bar.count:SetPoint("LEFT", bar)
				bar.timeLeft:SetPoint("CENTER", bar)
			elseif i == 4 then
				button:SetPoint("BOTTOMRIGHT", self.hButtons[buttonIndex-2], "TOPRIGHT", 0, 0)
				bar:SetPoint("TOPRIGHT", button, "TOPLEFT", 0, 0)
				bar.count:SetPoint("RIGHT", bar)
				bar.rightToLeft = true
				bar.originalWidth = bar:GetWidth()
				bar.timeLeft:SetPoint("RIGHT", button, "RIGHT", -(selfWidth-buttonSize)/2, 4)
			end
			tinsert(self.hBuffs, bar)
			tinsert(self.hButtons, button)
			barSetting.buttonIndex = buttonIndex
			buttonIndex = buttonIndex + 1
		end
	end

	-- health status bar
	local healthHeight = selfHeight-(spellsRowCount+(cfg.bars and math.ceil(#cfg.bars/2) or 0))*buttonSize
--DEBUG(1,tostring(spellsRowCount).."  "..tostring(cfg.bars and math.ceil(#cfg.bars/2) or 0).."  "..tostring(selfHeight).."  "..tostring(healthHeight))
	local health = CreateFrame('StatusBar', nil, self)
	health:SetFrameLevel(3)
	health:SetWidth(selfWidth-4)
	health:SetHeight(healthHeight)
	health:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
	health:SetStatusBarColor(0, 0.7, 0)
	health:SetPoint("TOPLEFT", self, "TOPLEFT", 4, 0)
	health:RegisterEvent("UNIT_HEALTH_FREQUENT")
	health:RegisterEvent("UNIT_MAXHEALTH")
	health:RegisterEvent("UNIT_CONNECTION")
	health:SetScript("OnEvent", UpdateHealth)
	self.Health = health
	-- health value
	health.value = health:CreateFontString(nil, "OVERLAY",  "GameFontHighlightSmall")
	health.value:SetPoint("RIGHT", health, -3, 0)
	health.value:SetTextColor(1, 1, 1)
	--health.value:SetShadowOffset(1, -1)
	self.Health.value = health.value

	-- resource status bar
	local resource = CreateFrame("StatusBar", nil, self)
	resource:SetFrameLevel(3)
	resource:SetWidth(4)
	resource:SetHeight(health:GetHeight())
	resource:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
	resource:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Resource-Fill")
	--resource:SetStatusBarColor(0.31, 0.45, 0.63)
	resource:SetStatusBarColor(PowerBarColor["MANA"].r, PowerBarColor["MANA"].g, PowerBarColor["MANA"].b, 1)
	resource:SetOrientation("VERTICAL")
	resource:RegisterEvent("UNIT_POWER")
	resource:RegisterEvent("UNIT_POWER_BAR_SHOW")
	resource:RegisterEvent("UNIT_POWER_BAR_HIDE")
	resource:RegisterEvent("UNIT_DISPLAYPOWER")
	resource:RegisterEvent("UNIT_CONNECTION")
	resource:RegisterEvent("UNIT_MAXPOWER")
	resource:SetScript("OnEvent", UpdateResource)
	self.Resource = resource

	-- name
	local name = health:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	name:SetPoint("LEFT", health, 1, 0)
	--name:SetFont(font2, 12*T.raidscale, "THINOUTLINE")
	--name:SetShadowOffset(1, -1)
	--self:Tag(name, "[Tukui:namemedium]")
	self.Name = name

	-- GCD
	local GCD = CreateFrame("Cooldown", "FrameCD", self, "CooldownFrameTemplate")
	GCD:SetAlpha(1)
	GCD:SetFrameStrata("BACKGROUND")
	GCD:SetFrameLevel(1)
	GCD:SetPoint("CENTER", 0, -1)
	GCD:SetWidth(selfWidth)
	GCD:SetHeight(selfHeight)
	GCD:Hide()
	self.hGCD = GCD

	-- TODO: priority debuff
--]]
--[[
	--self:RegisterForClicks("AnyUp")
	if cfg.hidden then
		local spellName = GetSpellInfo(cfg.hidden[1].spellID)
		-- hidden: right-click
		local button = CreateFrame("BUTTON", nil, self, "SecureActionButtonTemplate")
		button:SetWidth(selfWidth)
		button:SetHeight(self:GetHeight()-20) -- TODO
		button:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		button:RegisterForClicks("RightButtonUp")
		button:SetAttribute("useparent-unit", "true")
		button:SetAttribute("type2", "spell")
		button:SetAttribute("spell2", spellName)
		--button:SetAttribute("unit", "player")
		tinsert(self.hButtons, button)
	end
--]]
	self.hDisabled = false

	tinsert(Unitframes, self)
end

function CompactFrame_OnAttributeChanged(self, name, value)
	--DEBUG(1,"CompactFrame_OnAttributeChanged:"..tostring(self:GetName()).."  "..tostring(name).."  "..tostring(value))
	if name == "unit" or name == "unitsuffix" then
		local newUnit = SecureButton_GetUnit(self)
		if not newUnit then return end -- Should not happen

		-- Update player name
		local playerName = UnitName(newUnit)
		self.Name:SetText(playerName)

		-- Update health, mana, buff, threat, ...
		-- HealiumUnitFames_CheckPowerType(newUnit, self)
		-- Healium_UpdateUnitHealth(newUnit, self)
		-- Healium_UpdateUnitMana(newUnit, self)
		-- Healium_UpdateUnitBuffs(newUnit, self)
		-- Healium_UpdateUnitThreat(newUnit, self)
		-- Healium_UpdateUnitRole(newUnit, self)
		-- Healium_UpdateSpecialBuffs(newUnit)
		-- Healium_UpdateRaidTargetIcon(self)

		self.unit = newUnit
		--DEBUG(1,"CompactFrame_OnAttributeChanged " ..tostring(self.unit))
	end
end

local function CreateCompactHeader()
	--local headerTemplate = isPetGroup and "SecureGroupPetHeaderTemplate" or "SecureGroupHeaderTemplate"
	local header = CreateFrame("Button", "CompactHeader", UIParent, "SecureGroupHeaderTemplate")
	header:SetAttribute("initialConfigFunction", [[
		local header = self:GetParent()
		self:SetWidth(header:GetAttribute('initial-width'))
		self:SetHeight(header:GetAttribute('initial-height'))
	]])
	header:SetAttribute("initial-width", buttonSize*5)
	header:SetAttribute("initial-height", buttonSize*4)
	header:SetAttribute("template", "CompactFrameTemplate")
	header:SetAttribute("templateType", "Button")
	header:SetAttribute("point", "LEFT")
	header:SetAttribute("xOffset", 0)
	header:SetAttribute("yOffset", 0)
	header:SetAttribute("showRaid", true)
	header:SetAttribute("showParty", true)
	header:SetAttribute("showSolo", true)
	header:SetAttribute("showPlayer", true)
	header:SetAttribute("maxColumns", 8)
	header:SetAttribute("unitsPerColumn", 5)
	header:SetAttribute("columnAnchorPoint", "TOP")

	header:SetPoint("LEFT", UIParent, "LEFT", 700, 200)

	header:Show()
end

local eventsHandler = CreateFrame("Frame")
eventsHandler:RegisterEvent("PLAYER_LOGIN")
eventsHandler:RegisterEvent("SPELL_UPDATE_COOLDOWN")
eventsHandler:RegisterEvent("UNIT_AURA")
eventsHandler:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
	--DEBUG(1,"OnEvent:"..tostring(event).."  "..tostring(arg1).."  "..tostring(arg2).."  "..tostring(arg3))
	if event == "PLAYER_LOGIN" then
		CreateCompactHeader()
	elseif event == "SPELL_UPDATE_COOLDOWN" then
		UpdateCooldowns()
	elseif event == "UNIT_AURA" then
		ForEachUnitframeWithUnit(arg1, UpdateFrameBuffs)
	end
end)

