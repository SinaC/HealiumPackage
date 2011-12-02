local ADDON_NAME, _ = ...

--local H, HC = unpack(HealiumCore)
local H = unpack(HealiumCore)

-- Get oUF
local oUF = oUFTukui or oUF
assert(oUF, "Tukui was unable to locate oUF install.")
if not oUF then return end -- No need to continue if oUF is not found

-- Get Tukui
local T, C, L = unpack(Tukui)
-- Check Tukui config for raidframes
if not C["unitframes"].enable == true or C["unitframes"].gridonly == true then return end -- No need to continue if unitframes are not displayed or grid mode

-- Aliases
local PerformanceCounter = H.PerformanceCounter
local TabMenu = _G["Tukui_TabMenu"]

-- Raid frame headers
local PlayerRaidHeader = nil
local PetRaidHeader = nil
local TankRaidHeader = nil
local NamelistRaidHeader = nil

-- Namelist functions
------------------------------------
local function AddToNamelist(list, name)
	local newList = ""
	if list ~= "" then
		local names = { strsplit(",", list) }
		for _, v in ipairs(names) do
			if v == name then return false, list end
		end
		newList = list .. "," .. name
	else
		newList = name
	end
	return true, newList
end

local function RemoveFromNamelist(list, name)
	if list == "" then return false, list end
	local names = { strsplit(",", list) }
	local found = false
	newList = ""
	for _, v in ipairs(names) do
		if v == name then
			found = true
		else
			newList = (newList == "") and v or (newList .. "," .. v)
		end
	end
	return found, newList
end

-- Skin Healium Buttons/Buff/Debuffs
------------------------------------
local CreateHealiumButton_ = H.CreateHealiumButton -- save old function
function H:CreateHealiumButton(parent, name, size, anchor)
	--print(">Tukui:CreateHealiumButton")
	-- frame
	local button = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
	button:CreatePanel("Default", size, size, unpack(anchor))
	-- texture setup, texture icon is set in UpdateFrameButtons
	button.texture = button:CreateTexture(nil, "BORDER")
	button.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button.texture:SetPoint("TOPLEFT", button ,"TOPLEFT", 0, 0)
	button.texture:SetPoint("BOTTOMRIGHT", button ,"BOTTOMRIGHT", 0, 0)
	button:SetPushedTexture("Interface/Buttons/UI-Quickslot-Depress")
	button:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square")
	button.texture:SetVertexColor(1, 1, 1)
	button:SetBackdropColor(0.6, 0.6, 0.6)
	button:SetBackdropBorderColor(0.1, 0.1, 0.1)
	-- cooldown overlay
	button.cooldown = CreateFrame("Cooldown", "$parentCD", button, "CooldownFrameTemplate")
	button.cooldown:SetAllPoints(button.texture)
	--print("<Tukui:CreateHealiumButton")
	return button
end

local CreateHealiumDebuff_ = H.CreateHealiumDebuff -- save old function
function H:CreateHealiumDebuff(parent, name, size, anchor)
	--print(">Tukui:CreateHealiumDebuff")
	-- frame
	local debuff = CreateFrame("Frame", name, parent) -- --debuff = CreateFrame("Frame", debuffName, parent, "TargetDebuffFrameTemplate")
	debuff:CreatePanel("Default", size, size, unpack(anchor))
	-- icon
	debuff.icon = debuff:CreateTexture(nil, "ARTWORK")
	debuff.icon:Point("TOPLEFT", 2, -2)
	debuff.icon:Point("BOTTOMRIGHT", -2, 2)
	debuff.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	-- cooldown
	debuff.cooldown = CreateFrame("Cooldown", "$parentCD", debuff, "CooldownFrameTemplate")
	debuff.cooldown:SetAllPoints(debuff.icon)
	debuff.cooldown:SetReverse()
	-- count
	debuff.count = debuff:CreateFontString("$parentCount", "OVERLAY")
	debuff.count:SetFont(C["media"].uffont, 14, "OUTLINE")
	debuff.count:Point("BOTTOMRIGHT", 1, -1)
	debuff.count:SetJustifyH("CENTER")
	--print("<Tukui:CreateHealiumDebuff")
	return debuff
end

local CreateHealiumBuff_ = H.CreateHealiumBuff
function H:CreateHealiumBuff(parent, name, size, anchor)
	--print(">Tukui:CreateHealiumBuff")
	-- frame
	local buff = CreateFrame("Frame", name, parent) --buff = CreateFrame("Frame", buffName, frame, "TargetBuffFrameTemplate")
	buff:CreatePanel("Default", size, size, unpack(anchor))
	-- icon
	buff.icon = buff:CreateTexture(nil, "ARTWORK")
	buff.icon:Point("TOPLEFT", 2, -2)
	buff.icon:Point("BOTTOMRIGHT", -2, 2)
	buff.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	-- cooldown
	buff.cooldown = CreateFrame("Cooldown", "$parentCD", buff, "CooldownFrameTemplate")
	buff.cooldown:SetAllPoints(buff.icon)
	buff.cooldown:SetReverse()
	-- count
	buff.count = buff:CreateFontString("$parentCount", "OVERLAY")
	buff.count:SetFont(C["media"].uffont, 14, "OUTLINE")
	buff.count:Point("BOTTOMRIGHT", 1, -1)
	buff.count:SetJustifyH("CENTER")
	--print("<Tukui:CreateHealiumBuff")
	return buff
end

-- LFD role handler
------------------------------------
local function LFDRoleUpdate(self, event)
	local unit = self.unit
	local role = UnitGroupRolesAssigned(unit)
	-- default behaviour
	local lfdrole = self.LFDRole
	if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
		lfdrole:SetTexCoord(GetTexCoordsForRoleSmallCircle(role))
		lfdrole:Show()
	else
		lfdrole:Hide()
	end
	-- build list of tanks
	if C["healium"].showTanks == true and TankRaidHeader then
		local name = GetUnitName(unit, false)
		local list = TankRaidHeader:GetAttribute("nameList") or ""
--print("LFDRoleUpdate: "..tostring(name).."  "..tostring(role).."  "..tostring(list))
		if role == "TANK" then
			_, list = AddToNamelist(list, name)
		else
			_, list = RemoveFromNamelist(list, name)
		end
--print("LFDRoleUpdate: -->"..tostring(list))
		TankRaidHeader:SetAttribute("nameList", list)
	end
end

-- Create Tukui raid frames
------------------------------------
local font2 = C["media"].uffont
local font1 = C["media"].font
local normTex = C["media"].normTex
local backdrop = {
	bgFile = C["media"].blank,
	insets = {top = -T.mult, left = -T.mult, bottom = -T.mult, right = -T.mult},
}

local function Shared(self, unit)
	--print("Shared: "..(unit or "nil").."  "..self:GetName())

	self.colors = T.UnitColor or T.oUF_colors
	self:RegisterForClicks("AnyUp")
	self:SetScript('OnEnter', UnitFrame_OnEnter)
	self:SetScript('OnLeave', UnitFrame_OnLeave)

	self.menu = T.SpawnMenu

	self:SetBackdrop({bgFile = C["media"].blank, insets = {top = -T.mult, left = -T.mult, bottom = -T.mult, right = -T.mult}})
	self:SetBackdropColor(0.1, 0.1, 0.1)

	local health = CreateFrame('StatusBar', nil, self)
	health:SetPoint("TOPLEFT")
	health:SetPoint("TOPRIGHT")
	health:Height(27*T.raidscale)
	health:SetStatusBarTexture(normTex)
	self.Health = health

	health.bg = health:CreateTexture(nil, 'BORDER')
	health.bg:SetAllPoints(health)
	health.bg:SetTexture(normTex)
	health.bg:SetTexture(0.3, 0.3, 0.3)
	health.bg.multiplier = 0.3
	self.Health.bg = health.bg

	health.value = health:CreateFontString(nil, "OVERLAY")
	health.value:SetPoint("RIGHT", health, -3, 1)
	health.value:SetFont(font2, 12*T.raidscale, "THINOUTLINE")
	health.value:SetTextColor(1,1,1)
	health.value:SetShadowOffset(1, -1)
	self.Health.value = health.value

	health.PostUpdate = T.PostUpdateHealthRaid

	health.frequentUpdates = true

	if C["unitframes"].unicolor == true then
		health.colorDisconnected = false
		health.colorClass = false
		health:SetStatusBarColor(.3, .3, .3, 1)
		health.bg:SetVertexColor(.1, .1, .1, 1)
	else
		health.colorDisconnected = true
		health.colorClass = true
		health.colorReaction = true
	end

	local power = CreateFrame("StatusBar", nil, self)
	power:Height(4*T.raidscale)
	power:Point("TOPLEFT", health, "BOTTOMLEFT", 0, -1)
	power:Point("TOPRIGHT", health, "BOTTOMRIGHT", 0, -1)
	power:SetStatusBarTexture(normTex)
	self.Power = power

	power.frequentUpdates = true
	power.colorDisconnected = true

	power.bg = self.Power:CreateTexture(nil, "BORDER")
	power.bg:SetAllPoints(power)
	power.bg:SetTexture(normTex)
	power.bg:SetAlpha(1)
	power.bg.multiplier = 0.4
	self.Power.bg = power.bg

	if C["unitframes"].unicolor == true then
		power.colorClass = true
		power.bg.multiplier = 0.1
	else
		power.colorPower = true
	end

	local name = health:CreateFontString(nil, "OVERLAY")
	name:SetPoint("LEFT", health, 3, 0)
	name:SetFont(font2, 12*T.raidscale, "THINOUTLINE")
	name:SetShadowOffset(1, -1)
	self:Tag(name, "[Tukui:namemedium]")
	self.Name = name

	local leader = health:CreateTexture(nil, "OVERLAY")
	leader:Height(12*T.raidscale)
	leader:Width(12*T.raidscale)
	leader:SetPoint("TOPLEFT", 0, 6)
	self.Leader = leader

	local LFDRole = health:CreateTexture(nil, "OVERLAY")
	LFDRole:Height(6*T.raidscale)
	LFDRole:Width(6*T.raidscale)
	LFDRole:Point("TOPRIGHT", -2, -2)
	LFDRole:SetTexture("Interface\\AddOns\\Tukui\\medias\\textures\\lfdicons.blp")
	self.LFDRole = LFDRole
	self.LFDRole.Override = LFDRoleUpdate

	local MasterLooter = health:CreateTexture(nil, "OVERLAY")
	MasterLooter:Height(12*T.raidscale)
	MasterLooter:Width(12*T.raidscale)
	self.MasterLooter = MasterLooter
	self:RegisterEvent("PARTY_LEADER_CHANGED", T.MLAnchorUpdate)
	self:RegisterEvent("PARTY_MEMBERS_CHANGED", T.MLAnchorUpdate)

	if C["unitframes"].aggro == true then
		table.insert(self.__elements, T.UpdateThreat)
		self:RegisterEvent('PLAYER_TARGET_CHANGED', T.UpdateThreat)
		self:RegisterEvent('UNIT_THREAT_LIST_UPDATE', T.UpdateThreat)
		self:RegisterEvent('UNIT_THREAT_SITUATION_UPDATE', T.UpdateThreat)
	end

	if C["unitframes"].showsymbols == true then
		local RaidIcon = health:CreateTexture(nil, 'OVERLAY')
		RaidIcon:Height(18*T.raidscale)
		RaidIcon:Width(18*T.raidscale)
		RaidIcon:SetPoint('CENTER', self, 'TOP')
		RaidIcon:SetTexture("Interface\\AddOns\\Tukui\\medias\\textures\\raidicons.blp") -- thx hankthetank for texture
		self.RaidIcon = RaidIcon
	end

	local ReadyCheck = self.Power:CreateTexture(nil, "OVERLAY")
	ReadyCheck:Height(12*T.raidscale)
	ReadyCheck:Width(12*T.raidscale)
	ReadyCheck:SetPoint('CENTER')
	self.ReadyCheck = ReadyCheck

	if C["unitframes"].showrange == true then
		local range = {insideAlpha = 1, outsideAlpha = C["unitframes"].raidalphaoor}
		self.Range = range
	end

	if C["unitframes"].showsmooth == true then
		health.Smooth = true
		power.Smooth = true
	end

	if C["unitframes"].healcomm then
		local width = self:GetWidth()
		local mhpb = CreateFrame('StatusBar', nil, self.Health)
		mhpb:SetPoint('TOPLEFT', self.Health:GetStatusBarTexture(), 'TOPRIGHT', 0, 0)
		mhpb:SetPoint('BOTTOMLEFT', self.Health:GetStatusBarTexture(), 'BOTTOMRIGHT', 0, 0)
		mhpb:SetWidth(width*T.raidscale)
		mhpb:SetStatusBarTexture(normTex)
		mhpb:SetStatusBarColor(0, 1, 0.5, 0.25)

		local ohpb = CreateFrame('StatusBar', nil, self.Health)
		ohpb:SetPoint('TOPLEFT', mhpb:GetStatusBarTexture(), 'TOPRIGHT', 0, 0)
		ohpb:SetPoint('BOTTOMLEFT', mhpb:GetStatusBarTexture(), 'BOTTOMRIGHT', 0, 0)
		ohpb:SetWidth(width*T.raidscale)
		ohpb:SetStatusBarTexture(normTex)
		ohpb:SetStatusBarColor(0, 1, 0, 0.25)

		self.HealPrediction = {
			myBar = mhpb,
			otherBar = ohpb,
			maxOverflow = 1,
		}
	end

	-- Register frame to Healium
	H:RegisterFrame(self)

	return self
end

-- Slash commands
-------------------------------------------------------
local function Message(...)
	print("Healium_Tukui:", ...)
end

local function ToggleHeader(header)
	if not header then return end
	--DEBUG(1000,"header:"..header:GetName().."  "..tostring(header:IsShown()))
	if header:IsShown() then
		UnregisterAttributeDriver(header, "state-visibility")
		header:Hide()
	else
		RegisterAttributeDriver(header, "state-visiblity", header.hVisibilityAttribute)
		header:Show()
	end
end

SLASH_HLMT1 = "/ht"
SLASH_HLMT2 = "/hlmt"
local LastPerformanceCounterReset = GetTime()
local function SlashHandlerShowHelp()
	Message(string.format(L.healium_CONSOLE_HELP_GENERAL, SLASH_HLMT1, SLASH_HLMT2))
	Message(SLASH_HLMT1..L.healium_CONSOLE_HELP_DUMPGENERAL)
	Message(SLASH_HLMT1..L.healium_CONSOLE_HELP_DUMPFULL)
	Message(SLASH_HLMT1..L.healium_CONSOLE_HELP_DUMPUNIT)
	Message(SLASH_HLMT1..L.healium_CONSOLE_HELP_DUMPPERF)
	Message(SLASH_HLMT1..L.healium_CONSOLE_HELP_DUMPSHOW)
	Message(SLASH_HLMT1..L.healium_CONSOLE_HELP_RESETPERF)
	Message(SLASH_HLMT1..L.healium_CONSOLE_HELP_TOGGLE)
	Message(SLASH_HLMT1..L.healium_CONSOLE_HELP_NAMELISTADD)
	Message(SLASH_HLMT1..L.healium_CONSOLE_HELP_NAMELISTREMOVE)
	Message(SLASH_HLMT1..L.healium_CONSOLE_HELP_NAMELISTCLEAR)
end

local function SlashHandlerDump(args)
	local function CountEntry(t)
		local count = 0
		for k, v in pairs(t) do
			count = count + 1
		end
		return count
	end
	local function Dump(level, k, v)
		local pad = ""
		for i = 1, level, 1 do
			pad = pad .. "  "
		end
		if type(v) == "table" then
			local count = CountEntry(v)
			if count > 0 then
				if k then
					DumpSack:Add(pad..tostring(k))
				end
				for key, value in pairs(v) do
					Dump(level+1, key, value)
				end
			end
		else
			DumpSack:Add(pad..tostring(k).."="..tostring(v))
		end
	end
	if not args then
		local infos = H:DumpInformation(true)
		if infos then
			Dump(0, nil, infos)
			DumpSack:Flush("Healium_Tukui")
		end
	elseif args == "full" then
		local infos = H:DumpInformation(false)
		if infos then
			Dump(0, nil, infos)
			DumpSack:Flush("Healium_Tukui")
		end
	elseif args == "perf" then
		local infos = PerformanceCounter:Get("Healium_Core")
		if infos then
			Dump(0, nil, infos)
			DumpSack:Flush("Healium_Tukui")
		end
	elseif args == "show" then
		DumpSack:Show()
	else
		local infos = H:DumpInformation()
		local found = false
		if infos and infos.Units then
			for _, unitInfo in infos.Units do
				if unitInfo.Unit == arg1 or unitInfo.Unitname == arg1 then
					Dump(0, nil, unitInfo)
					found = true
				end
			end
		end
		if found then
			DumpSack:Flush("Healium_Tukui")
		else
			Message(L.healium_CONSOLE_DUMP_UNITNOTFOUND)
		end
	end
end

local function SlashHandlerReset(args)
	if args == "perf" then
		PerformanceCounter:Reset("Healium_Core")
		LastPerformanceCounterReset = GetTime()
		Message(L.healium_CONSOLE_RESET_PERF)
	end
end

local function SlashHandlerToggle(args)
	if InCombatLockdown() then
		Message(L.healium_NOTINCOMBAT)
		return
	end
	if args == "raid" then
		ToggleHeader(PlayerRaidHeader)
	elseif args == "tank" then
		ToggleHeader(TankRaidHeader)
	elseif args == "pet" then
		ToggleHeader(PetRaidHeader)
	elseif args == "namelist" then
		ToggleHeader(NamelistRaidHeader)
	else
		Message(L.healium_CONSOLE_TOGGLE_INVALID)
	end
end

local function SlashHandlerNamelist(cmd)
	local function NamelistAdd(args)
		local name = args
		if not name then
			local realm
			name, realm = UnitName("target")
			if realm ~= nil then
				if realm:len() > 0 then
					name = name.."-".. realm
				end
			end
		end
		if name then
			local added, list = AddToNamelist(C["healium"].namelist, name)
			if not added then
				Message(L.healium_CONSOLE_NAMELIST_ADDALREADY)
			else
				C["healium"].namelist = list
				Message(L.healium_CONSOLE_NAMELIST_ADDED:format(name))
				if NamelistRaidHeader then
					NamelistRaidHeader:SetAttribute("namelist", C["healium"].namelist)
				end
			end
		else
			Message(L.healium_CONSOLE_NAMELIST_ADDREMOVEINVALID)
		end
	end

	local function NamelistRemove(args)
		local name = args
		if not name then
			local _, playerRealm = UnitName("player")
			local targetName, targetRealm = UnitName("target")
			if targetName and (targetRealm == nil or playerRealm == targetRealm)  then
				name = targetName
			end
		end
		if name then
			local removed, list = RemoveFromNamelist(C["healium"].namelist, name)
			if not removed then
				Message(L.healium_CONSOLE_NAMELIST_REMOVENOTFOUND)
			else
				C["healium"].namelist = list
				Message(L.healium_CONSOLE_NAMELIST_REMOVED:format(name))
				if NamelistRaidHeader then
					NamelistRaidHeader:SetAttribute("namelist", C["healium"].namelist)
				end
			end
		else
			Message(L.healium_CONSOLE_NAMELIST_ADDREMOVEINVALID)
		end
	end

	local function NamelistClear()
		C["healium"].namelist = ""
		if NamelistRaidHeader then
			NamelistRaidHeader:SetAttribute("namelist", list)
		end
	end

	local switch = cmd:match("([^ ]+)")
	local args = cmd:match("[^ ]+ (.+)")

	if switch == "add" then
		NamelistAdd(args)
	elseif switch == "remove" or switch == "rem" then
		NamelistRemove(args)
	elseif switch == "clear" then
		NamelistClear()
	else
		Message(L.healium_CONSOLE_NAMELIST_INVALIDOPTION)
	end
end

SlashCmdList["HLMT"] = function(cmd)
	local switch = cmd:match("([^ ]+)")
	local args = cmd:match("[^ ]+ (.+)")
	if switch == "dump" then
		SlashHandlerDump(args)
	elseif switch == "reset" then
		SlashHandlerReset(args)
	elseif switch == "toggle" then
		SlashHandlerToggle(args)
	elseif switch == "namelist" then
		SlashHandlerNamelist(args)
	else
		SlashHandlerShowHelp()
	end
end

-- TabMenu with Dropdown list
-------------------------------------------------------
if C["healium"].showTabMenu == true and TabMenu and TukuiChatBackgroundRight then
	local function MenuToggleHeader(info, header)
		if InCombatLockdown() then
			Message(L.healium_NOTINCOMBAT)
			return
		end
		ToggleHeader(header)
	end
	-- menu function (see Interface\Addons\Healium\HealiumMenu.lua  and  http://www.wowwiki.com/Using_UIDropDownMenu)
	local function MenuInitializeDropDown(self, level)
		level = level or 1
		local info
		if level == 1 then
			info = UIDropDownMenu_CreateInfo()
			info.text = L.healium_TAB_TITLE
			info.isTitle = 1
			info.notCheckable = 1
			info.owner = self:GetParent()
			info.func = MenuToggleHeader
			info.arg1 = TankRaidHeader
			UIDropDownMenu_AddButton(info, level)
			if PlayerRaidHeader then
				info = UIDropDownMenu_CreateInfo()
				info.text = PlayerRaidHeader:IsShown() and L.healium_TAB_PLAYERFRAMEHIDE or L.healium_TAB_PLAYERFRAMESHOW
				info.notCheckable = 1
				info.owner = self:GetParent()
				info.func = MenuToggleHeader
				info.arg1 = PlayerRaidHeader
				UIDropDownMenu_AddButton(info, level)
			end
			if TankRaidHeader then
				info = UIDropDownMenu_CreateInfo()
				info.text = TankRaidHeader:IsShown() and L.healium_TAB_TANKFRAMEHIDE or L.healium_TAB_TANKFRAMESHOW
				info.notCheckable = 1
				info.owner = self:GetParent()
				info.func = MenuToggleHeader
				info.arg1 = TankRaidHeader
				UIDropDownMenu_AddButton(info, level)
			end
			if PetRaidHeader then
				info = UIDropDownMenu_CreateInfo()
				info.text = PetRaidHeader:IsShown() and L.healium_TAB_PETFRAMEHIDE or L.healium_TAB_PETFRAMESHOW
				info.notCheckable = 1
				info.owner = self:GetParent()
				info.func = MenuToggleHeader
				info.arg1 = PetRaidHeader
				UIDropDownMenu_AddButton(info, level)
			end
			if NamelistRaidHeader then
				info = UIDropDownMenu_CreateInfo()
				info.text = NamelistRaidHeader:IsShown() and L.healium_TAB_NAMELISTFRAMEHIDE or L.healium_TAB_NAMELISTFRAMESHOW
				info.notCheckable = 1
				info.owner = self:GetParent()
				info.func = MenuToggleHeader
				info.arg1 = NamelistRaidHeader
				UIDropDownMenu_AddButton(info, level)
			end
			info = UIDropDownMenu_CreateInfo()
			info.text = CLOSE
			info.notCheckable = 1
			info.owner = self:GetParent()
			info.func = self.HideMenu
			UIDropDownMenu_AddButton(info, level)
		end
	end

	local tab = TabMenu:AddCustomTab(TukuiChatBackgroundRight, "LEFT", "Healium", "Interface\\AddOns\\Healium_Tukui\\medias\\ability_druid_improvedtreeform")

	-- create menu frame
	local menu = CreateFrame("Frame", "HealiumMenu", tab, "UIDropDownMenuTemplate")
	menu:SetPoint("BOTTOM", tab, "TOP")
	UIDropDownMenu_Initialize(menu, MenuInitializeDropDown, "MENU")
	-- events
	tab:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, T.Scale(6))
		GameTooltip:ClearAllPoints()
		GameTooltip:SetPoint("BOTTOM", self, "TOP", 0, T.mult)
		GameTooltip:ClearLines()
		GameTooltip:AddLine(L.healium_TAB_TOOLTIP, 1, 1, 1)
		GameTooltip:Show()
	end)
	tab:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
	tab:SetScript("OnClick", function(self, button)
		GameTooltip:Hide()
		ToggleDropDownMenu(1, nil, menu, self, 0, 100)
	end)
end

-- Event handlers
-------------------------------------------------------
local eventHandlers = CreateFrame("Frame")
eventHandlers:RegisterEvent("PLAYER_LOGIN")
eventHandlers:RegisterEvent("ADDON_LOADED")
eventHandlers:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
		-- Initialize Healium
		H:Initialize(C["healium"])
		-- Display version
		local version = GetAddOnMetadata(ADDON_NAME, "version")
		local libVersion = GetAddOnMetadata("Healium_Core", "version")
		if version and libVersion then
			Message(string.format(L.healium_GREETING_VERSION, tostring(version), tostring(libVersion)))
		else
			Message(L.healium_GREETING_VERSIONUNKNOWN)
		end
		Message(L.healium_GREETING_OPTIONS)
	elseif event == "PLAYER_LOGIN" then
		---- Set tooltip anchor
		--HC.general.buttonTooltipAnchor = _G["TukuiTooltipAnchor"] -- change button tooltip anchor

		-- Kill blizzard raid frames
		local dummy = function() return end
		local function Kill(object)
			if object.UnregisterAllEvents then
				object:UnregisterAllEvents()
			end
			object.Show = dummy
			object:Hide()
		end
		InterfaceOptionsFrameCategoriesButton10:SetScale(0.00001)
		InterfaceOptionsFrameCategoriesButton10:SetAlpha(0)
		InterfaceOptionsFrameCategoriesButton11:SetScale(0.00001)
		InterfaceOptionsFrameCategoriesButton11:SetAlpha(0)
		Kill(CompactRaidFrameManager)
		Kill(CompactRaidFrameContainer)
		CompactUnitFrame_UpateVisible = dummy
		CompactUnitFrame_UpdateAll = dummy
	end
end)

-- Spawn headers
-------------------------------------------------------
oUF:RegisterStyle('TukuiHealiumR01R25', Shared)
oUF:Factory(function(self)
	-- Raid header visibility attributes
	local Visibility25 = "custom [@raid26,exists] hide;show"
	local Visibility10 = "custom [@raid11,exists] hide;show"

	oUF:SetActiveStyle("TukuiHealiumR01R25")

	PlayerRaidHeader = self:SpawnHeader("oUF_TukuiHealiumRaid0125", nil, Visibility25,
		'oUF-initialConfigFunction', [[
			local header = self:GetParent()
			self:SetWidth(header:GetAttribute('initial-width'))
			self:SetHeight(header:GetAttribute('initial-height'))
		]],
		'initial-width', T.Scale(C["healium"].unitframeWidth*T.raidscale),
		'initial-height', T.Scale(C["healium"].unitframeHeight*T.raidscale),
		"showSolo", C["unitframes"].showsolo or true,
		"showParty", true,
		"showPlayer", C["unitframes"].showplayerinparty or true,
		"showRaid", true,
		"groupFilter", "1,2,3,4,5,6,7,8",
		"groupingOrder", "1,2,3,4,5,6,7,8",
		"groupBy", "GROUP",
		"yOffset", T.Scale(-4)
	)
	PlayerRaidHeader:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 180, -300*T.raidscale)
	PlayerRaidHeader.hVisibilityAttribute = Visibility25

	if C["healium"].showPets == true then
		PetRaidHeader = self:SpawnHeader("oUF_TukuiHealiumRaidPet0125", "SecureGroupPetHeaderTemplate", "custom [@raid11,exists] hide;show",
			'oUF-initialConfigFunction', [[
				local header = self:GetParent()
				self:SetWidth(header:GetAttribute('initial-width'))
				self:SetHeight(header:GetAttribute('initial-height'))
			]],
			'initial-width', T.Scale(C["healium"].unitframeWidth*T.raidscale),
			'initial-height', T.Scale(C["healium"].unitframeHeight*T.raidscale),
			"showSolo", C["unitframes"].showsolo or true,
			"showParty", true,
			"showRaid", true,
			"yOffset", T.Scale(-4),
			"groupFilter", "1,2,3,4,5,6,7,8",
			"groupingOrder", "1,2,3,4,5,6,7,8",
			"groupBy", "GROUP",
			"maxColumns", 1,
			"unitsPerColumn", C["healium"].maxPets or 5,
			"filterOnPet", true,
			"sortMethod", "NAME"
		)
		PetRaidHeader:SetPoint("TOPLEFT", PlayerRaidHeader, "BOTTOMLEFT", 0, -50*T.raidscale)
		PetRaidHeader.hVisibilityAttribute = Visibility10
	end
	
	-- if C["healium"].showTanks == true then
		-- -- Tank frame (attributes: [["groupFilter", "MAINTANK,TANK"]],  [["groupBy", "ROLE"]],    showParty, showRaid but not showSolo)
		-- TankRaidHeader = self:SpawnHeader("oUF_TukuiHealiumRaidTank0125", nil, Visibility25,
			-- 'oUF-initialConfigFunction', [[
				-- local header = self:GetParent()
				-- self:SetWidth(header:GetAttribute('initial-width'))
				-- self:SetHeight(header:GetAttribute('initial-height'))
			-- ]],
			-- 'initial-width', T.Scale(C["healium"].unitframeWidth*T.raidscale),
			-- 'initial-height', T.Scale(C["healium"].unitframeHeight*T.raidscale),
			-- "showSolo", false,
			-- "showParty", true,
			-- "showRaid", true,
			-- "showPlayer", C["unitframes"].showplayerinparty or true,
			-- "yOffset", T.Scale(-4),
			-- "groupFilter", "MAINTANK",--,MAINASSIST",--,TANK",
			-- "groupingOrder", "1,2,3,4,5,6,7,8",
			-- "groupBy", "ROLE"
			-- --"sortMethod", "NAME"
		-- )
		-- --TankRaidHeader:SetPoint("BOTTOMLEFT", PlayerRaidHeader, "TOPLEFT", 0, 50*T.raidscale)
		-- TankRaidHeader:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -400*T.raidscale, -300*T.raidscale)
		-- TankRaidHeader.hVisibilityAttribute = Visibility25
	-- end
	if C["healium"].showTanks == true then
		-- Tank frame (attributes: [["groupFilter", "MAINTANK,TANK"]],  [["groupBy", "ROLE"]],    showParty, showRaid but not showSolo)
		TankRaidHeader = self:SpawnHeader("oUF_TukuiHealiumRaidTank0125", nil, Visibility25,
			'oUF-initialConfigFunction', [[
				local header = self:GetParent()
				self:SetWidth(header:GetAttribute('initial-width'))
				self:SetHeight(header:GetAttribute('initial-height'))
			]],
			'initial-width', T.Scale(C["healium"].unitframeWidth*T.raidscale),
			'initial-height', T.Scale(C["healium"].unitframeHeight*T.raidscale),
			"showSolo", false,
			"showParty", true,
			"showRaid", true,
			"showPlayer", C["unitframes"].showplayerinparty or true,
			"yOffset", T.Scale(-4),
			"sortMethod", "NAME",
			"maxColumns", 1,
			"unitsPerColumn", 20,
			"nameList", ""
		)
		--TankRaidHeader:SetPoint("BOTTOMLEFT", PlayerRaidHeader, "TOPLEFT", 0, 50*T.raidscale)
		TankRaidHeader:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -500*T.raidscale, -300*T.raidscale)
		TankRaidHeader.hVisibilityAttribute = Visibility25
	end

	if C["healium"].showNamelist == true then
		-- Namelist frame
		NamelistRaidHeader = self:SpawnHeader("oUF_TukuiHealiumRaidNamelist0125", nil, Visibility25,
			'oUF-initialConfigFunction', [[
				local header = self:GetParent()
				self:SetWidth(header:GetAttribute('initial-width'))
				self:SetHeight(header:GetAttribute('initial-height'))
			]],
			'initial-width', T.Scale(C["healium"].unitframeWidth*T.raidscale),
			'initial-height',T.Scale(C["healium"].unitframeHeight*T.raidscale),
			"showSolo", C["unitframes"].showsolo,
			"showParty", true,
			"showRaid", true,
			"showPlayer", C["unitframes"].showplayerinparty or true,
			"yOffset", T.Scale(-4),
			"sortMethod", "NAME",
			"maxColumns", 1,
			"unitsPerColumn", 20,
			"nameList", C["healium"].namelist or ""
		)
		NamelistRaidHeader:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -400*T.raidscale, -300*T.raidscale)
		NamelistRaidHeader.hVisibilityAttribute = Visibility25
	end
end)