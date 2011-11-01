local H, HC = unpack(HealiumComponents)

-- Get Performance Counter
local PerformanceCounter = H.PerformanceCounter

-- Get oUF
local oUF = oUFTukui or oUF
assert(oUF, "Tukui was unable to locate oUF install.")
if not oUF then return end -- No need to continue if oUF is not found

-- Get Tukui
local T, C, L = unpack(Tukui)
-- Check Tukui config for raidframes
if not C["unitframes"].enable == true or C["unitframes"].gridonly == true then return end -- No need to continue if unitframes are not displayed or grid mode

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

	self.colors = T.oUF_colors
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

	H:AddHealiumComponents(self)

	return self
end

-- Raid unitframes header
local PlayerRaidHeader = nil
local PetRaidHeader = nil
local TankRaidHeader = nil
local NamelistRaidHeader = nil

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

-- Slash commands
-------------------------------------------------------
local LastPerformanceCounterReset = GetTime()
local function SlashHandlerShowHelp()
	Message(string.format(L.healium_CONSOLE_HELP_GENERAL, SLASH_THLM1, SLASH_THLM2))
	Message(SLASH_THLM1..L.healium_CONSOLE_HELP_DUMPGENERAL)
	Message(SLASH_THLM1..L.healium_CONSOLE_HELP_DUMPUNIT)
	Message(SLASH_THLM1..L.healium_CONSOLE_HELP_DUMPPERF)
	Message(SLASH_THLM1..L.healium_CONSOLE_HELP_DUMPSHOW)
	Message(SLASH_THLM1..L.healium_CONSOLE_HELP_RESETPERF)
	Message(SLASH_THLM1..L.healium_CONSOLE_HELP_TOGGLE)
	Message(SLASH_THLM1..L.healium_CONSOLE_HELP_NAMELISTADD)
	Message(SLASH_THLM1..L.healium_CONSOLE_HELP_NAMELISTREMOVE)
	Message(SLASH_THLM1..L.healium_CONSOLE_HELP_NAMELISTCLEAR)
end

local function SlashHandlerDump(args)
	local function Dump(level, k, v)
		if type(t) == "table" then
			if k then
				DumpSack:Add(tostring(k))
			end
			for key, value in pairs(t) do
				Dump(level+1, key, value)
			end
		else
			local pad = ""
			for i = 1, level, 1 do
				pad = pad .. "  "
			end
			DumpSack:Add(pad..tostring(k).."="..tostring(t))
		end
	end
	if not args then
		local infos = H:DumpInformation()
		if infos then
			Dump(0, nil, infos)
			DumpSack:Flush("Healium_Tukui")
		end
	elseif args == "perf" then
		local infos = H:DumpInformation()
		if info and infos.PerformanceCounter then
			Dump(0, nil, infos.PerformanceCounter)
			DumpSack:Flush("Healium_Tukui")
		end
	elseif args == "show" then
		DumpSack:Show()
	else
		local infos = H:DumpInformation()
		local found = false
		if infos and infos.Units then
			for _, unitInfo in info.Units do
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
		PerformanceCounter:Reset("Healium_Components")
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
			local fAdded = AddToNamelist(C["healium"].namelist, name)
			if not fAdded then
				Message(L.healium_CONSOLE_NAMELIST_ADDALREADY)
			else
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
			local fRemoved = RemoveFromNamelist(C["healium"].namelist, name)
			if not fRemoved then
				Message(L.healium_CONSOLE_NAMELIST_REMOVENOTFOUND)
			else
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


SLASH_THLM1 = "/th"
SLASH_THLM2 = "/thlm"
SlashCmdList["THLM"] = function(cmd)
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

-- Event handlers
-------------------------------------------------------
local eventHandlers = CreateFrame("Frame")
eventHandlers:RegisterEvent("PLAYER_LOGIN")
eventHandlers:SetScript("OnEvent", function(self)
	-- Set tooltip anchor
	HC.general.buttonTooltipAnchor = _G["TukuiTooltipAnchor"] -- change button tooltip anchor

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
end)

-- Spawn headers
-------------------------------------------------------
oUF:RegisterStyle('TukuiHealiumR01R25', Shared)
oUF:Factory(function(self)
	-- Raid header visibility attributes
	local Visibility25 = "custom [@raid26,exists] hide;show"
	local Visibility10 = "custom [@raid11,exists] hide;show"

	oUF:SetActiveStyle("TukuiHealiumR01R25")

	PlayerRaidHeader = self:SpawnHeader("oUF_TukuiHealiumRaid0125", nil, "custom [@raid26,exists] hide;show",
		'oUF-initialConfigFunction', [[
			local header = self:GetParent()
			self:SetWidth(header:GetAttribute('initial-width'))
			self:SetHeight(header:GetAttribute('initial-height'))
		]],
		'initial-width', T.Scale(C["healium"].unitframeWidth*T.raidscale),
		'initial-height', T.Scale(C["healium"].unitframeHeight*T.raidscale),
		"showSolo", C["unitframes"].showsolo,
		"showParty", true,
		"showPlayer", C["unitframes"].showplayerinparty,
		"showRaid", true,
		"groupFilter", "1,2,3,4,5,6,7,8",
		"groupingOrder", "1,2,3,4,5,6,7,8",
		"groupBy", "GROUP",
		"yOffset", T.Scale(-4)
	)
	PlayerRaidHeader:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 180, -300*T.raidscale)
	PlayerRaidHeader.hVisibilityAttribute = Visibility25

	if C["healium"].showPets then
		PetRaidHeader = self:SpawnHeader("oUF_TukuiHealiumRaidPet0125", "SecureGroupPetHeaderTemplate", "custom [@raid11,exists] hide;show",
			'oUF-initialConfigFunction', [[
				local header = self:GetParent()
				self:SetWidth(header:GetAttribute('initial-width'))
				self:SetHeight(header:GetAttribute('initial-height'))
			]],
			'initial-width', T.Scale(C["healium"].unitframeWidth*T.raidscale),
			'initial-height', T.Scale(C["healium"].unitframeHeight*T.raidscale),
			"showSolo", C["unitframes"].showsolo,
			"showParty", true,
			"showRaid", true,
			"yOffset", T.Scale(-4),
			"groupFilter", "1,2,3,4,5,6,7,8",
			"groupingOrder", "1,2,3,4,5,6,7,8",
			"groupBy", "GROUP",
			"maxColumns", 1,
			"unitsPerColumn", 10,
			"filterOnPet", true,
			"sortMethod", "NAME"
		)
		PetRaidHeader:SetPoint("TOPLEFT", PlayerRaidHeader, "BOTTOMLEFT", 0, -50*T.raidscale)
		PetRaidHeader.hVisibilityAttribute = Visibility10
	end

	if C["healium"].showTanks then
		-- Tank frame (attributes: [["groupFilter", "MAINTANK,TANK"]],  [["groupBy", "ROLE"]],    showParty, showRaid but not showSolo)
		TankRaidHeader = self:SpawnHeader("oUF_TukuiHealiumRaidTank0125", nil, Visibilityl25,
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
			"showPlayer", C["unitframes"].showplayerinparty,
			"yOffset", T.Scale(-4),
			"groupFilter", "MAINTANK,TANK",
			"sortMethod", "NAME"
		)
		TankRaidHeader:SetPoint("BOTTOMLEFT", PlayerRaidHeader, "TOPLEFT", 0, 50*T.raidscale)
		TankRaidHeader.hVisibilityAttribute = Visibility25
	end

	if C["healium"].showNamelist then
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
			"showPlayer", C["unitframes"].showplayerinparty,
			"yOffset", T.Scale(-4),
			"sortMethod", "NAME",
			"maxColumns", 1,
			"unitsPerColumn", 20,
			"nameList", C["healium"].namelist
		)
		NamelistRaidHeader:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -400, -300)
		NamelistRaidHeader.hVisibilityAttribute = Visibility25
	end
end)