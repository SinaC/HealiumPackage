----------------------------------------------
-- Create oUF raid frames and add Healium components
-------------------------------------------------------
-- Get Healium Components
local H = unpack(HealiumComponents)

-- Tags
local function utf8sub(string, i, dots)
	if not string then return end
	local bytes = string:len()
	if (bytes <= i) then
		return string
	else
		local len, pos = 0, 1
		while(pos <= bytes) do
			len = len + 1
			local c = string:byte(pos)
			if (c > 0 and c <= 127) then
				pos = pos + 1
			elseif (c >= 192 and c <= 223) then
				pos = pos + 2
			elseif (c >= 224 and c <= 239) then
				pos = pos + 3
			elseif (c >= 240 and c <= 247) then
				pos = pos + 4
			end
			if (len == i) then break end
		end

		if (len == i and pos <= bytes) then
			return string:sub(1, pos - 1)..(dots and '...' or '')
		else
			return string
		end
	end
end

oUF.Tags.Events['oUF_Healium:namemedium'] = 'UNIT_NAME_UPDATE'
oUF.Tags.Methods['oUF_Healium:namemedium'] = function(unit)
	local name = UnitName(unit)
	return utf8sub(name, 15, true)
end

-- Create oUF raid frames
------------------------------------
local function Shared(self, unit)
	--print("Shared: "..(unit or "nil").."  "..self:GetName())

	self.colors = Healium_oUF_Config.colors
	self:RegisterForClicks("AnyUp")
	self:SetScript('OnEnter', UnitFrame_OnEnter)
	self:SetScript('OnLeave', UnitFrame_OnLeave)

	self.horizTopBorder = self:CreateTexture(nil, "BORDER")
	self.horizTopBorder:ClearAllPoints();
	self.horizTopBorder:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, -7);
	self.horizTopBorder:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, -7);
	self.horizTopBorder:SetTexture("Interface\\RaidFrame\\Raid-HSeparator");
	self.horizTopBorder:SetHeight(8);

	self.horizBottomBorder = self:CreateTexture(nil, "BORDER")
	self.horizBottomBorder:ClearAllPoints();
	self.horizBottomBorder:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, 1);
	self.horizBottomBorder:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, 1);
	self.horizBottomBorder:SetTexture("Interface\\RaidFrame\\Raid-HSeparator");
	self.horizBottomBorder:SetHeight(8);

	self.vertLeftBorder = self:CreateTexture(nil, "BORDER")
	self.vertLeftBorder:ClearAllPoints();
	self.vertLeftBorder:SetPoint("TOPRIGHT", self, "TOPLEFT", 7, 0);
	self.vertLeftBorder:SetPoint("BOTTOMRIGHT", self, "BOTTOMLEFT", 7, 0);
	self.vertLeftBorder:SetTexture("Interface\\RaidFrame\\Raid-VSeparator");
	self.vertLeftBorder:SetWidth(8);

	self.vertRightBorder = self:CreateTexture(nil, "BORDER")
	self.vertRightBorder:ClearAllPoints();
	self.vertRightBorder:SetPoint("TOPLEFT", self, "TOPRIGHT", -1, 0);
	self.vertRightBorder:SetPoint("BOTTOMLEFT", self, "BOTTOMRIGHT", -1, 0);
	self.vertRightBorder:SetTexture("Interface\\RaidFrame\\Raid-VSeparator");
	self.vertRightBorder:SetWidth(8);

	self.menu = function(self)
		local unit = self.unit:gsub("(.)", string.upper, 1)
		if unit == "Targettarget" or unit == "focustarget" or unit == "pettarget" then return end

		if _G[unit.."FrameDropDown"] then
			ToggleDropDownMenu(1, nil, _G[unit.."FrameDropDown"], "cursor")
		elseif (self.unit:match("party")) then
			ToggleDropDownMenu(1, nil, _G["PartyMemberFrame"..self.id.."DropDown"], "cursor")
		else
			FriendsDropDown.unit = self.unit
			FriendsDropDown.id = self.id
			FriendsDropDown.initialize = RaidFrameDropDown_Initialize
			ToggleDropDownMenu(1, nil, FriendsDropDown, "cursor")
		end
	end

	local health = CreateFrame('StatusBar', nil, self)
	health:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
	health:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -1)
	health:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -1, 4)
	self.Health = health

	health.bg = health:CreateTexture(nil, 'BORDER')
	health.bg:SetAllPoints(health)
	health.bg:SetTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Bg")
	health.bg:SetTexture(0.3, 0.3, 0.3)
	health.bg.multiplier = 0.3
	self.Health.bg = health.bg

	health.value = health:CreateFontString(nil, "OVERLAY")
	health.value:SetPoint("RIGHT", health, -3, 1)
	health.value:SetFontObject(GameFontNormalSmall)
	health.value:SetTextColor(1,1,1)
	health.value:SetShadowOffset(1, -1)
	self.Health.value = health.value

	health.colorDisconnected = true
	health.colorClass = true
	health.colorReaction = true

	local power = CreateFrame("StatusBar", nil, self)
	power:SetHeight(4)
	power:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 1, 4)
	power:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", -1, 4)
	power:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Resource-Fill");
	self.Power = power

	power.frequentUpdates = true
	power.colorDisconnected = true

	power.bg = self.Power:CreateTexture(nil, "BORDER")
	power.bg:SetAllPoints(power)
	power.bg:SetTexture("Interface\\RaidFrame\\Raid-Bar-Resource-Background")
	power.bg:SetAlpha(1)
	power.bg.multiplier = 0.4
	self.Power.bg = power.bg

	power.colorPower = true

	local name = health:CreateFontString(nil, "OVERLAY")
	name:SetPoint("LEFT", health, 3, 0)
	name:SetFontObject(GameFontNormal )
	name:SetShadowOffset(1, -1)
	self:Tag(name, "[oUF_Healium:namemedium]")
	self.Name = name

	local leader = health:CreateTexture(nil, "OVERLAY")
	leader:SetHeight(12)
	leader:SetWidth(12)
	leader:SetPoint("TOPLEFT", 0, 6)
	self.Leader = leader

	local LFDRole = health:CreateTexture(nil, "OVERLAY")
	LFDRole:SetHeight(12)
	LFDRole:SetWidth(12)
	LFDRole:SetPoint("TOPRIGHT", -2, -2)
	self.LFDRole = LFDRole

	local masterLooter = health:CreateTexture(nil, "OVERLAY")
	masterLooter:SetHeight(12)
	masterLooter:SetWidth(12)
	self.MasterLooter = masterLooter

	if Healium_oUF_Config.showsymbols == true then
		local RaidIcon = health:CreateTexture(nil, 'OVERLAY')
		RaidIcon:SetHeight(18)
		RaidIcon:SetWidth(18)
		RaidIcon:SetPoint('CENTER', self, 'CENTER')
		self.RaidIcon = RaidIcon
	end

	local ReadyCheck = self.Power:CreateTexture(nil, "OVERLAY")
	ReadyCheck:SetHeight(12)
	ReadyCheck:SetWidth(12)
	ReadyCheck:SetPoint('CENTER')
	self.ReadyCheck = ReadyCheck

	if Healium_oUF_Config.showrange == true then
		local range = {insideAlpha = 1, outsideAlpha = Healium_oUF_Config.raidalphaoor}
		self.Range = range
	end

	if Healium_oUF_Config.showsmooth == true then
		health.Smooth = true
		power.Smooth = true
	end

	if Healium_oUF_Config.healcomm then
		local width = self:GetWidth()
		local mhpb = CreateFrame('StatusBar', nil, self.Health)
		mhpb:SetPoint('TOPLEFT', self.Health:GetStatusBarTexture(), 'TOPRIGHT', 0, 0)
		mhpb:SetPoint('BOTTOMLEFT', self.Health:GetStatusBarTexture(), 'BOTTOMRIGHT', 0, 0)
		mhpb:SetWidth(width)
		mhpb:SetStatusBarColor(0, 1, 0.5, 0.25)

		local ohpb = CreateFrame('StatusBar', nil, self.Health)
		ohpb:SetPoint('TOPLEFT', mhpb:GetStatusBarTexture(), 'TOPRIGHT', 0, 0)
		ohpb:SetPoint('BOTTOMLEFT', mhpb:GetStatusBarTexture(), 'BOTTOMRIGHT', 0, 0)
		ohpb:SetWidth(width)
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

-- Spawn Headers and register spawn style
oUF:RegisterStyle('oUFHealiumR01R25', Shared)
oUF:Factory(function(self)
	-- Raid header visibility attributes
	local Visibility25 = "custom [@raid26,exists] hide;show"
	local Visibility10 = "custom [@raid11,exists] hide;show"

	oUF:SetActiveStyle("oUFHealiumR01R25")

	PlayerRaidHeader = self:SpawnHeader("oUF_HealiumRaid0125", nil, "custom [@raid26,exists] hide;show",
		'oUF-initialConfigFunction', [[
			local header = self:GetParent()
			self:SetWidth(header:GetAttribute('initial-width'))
			self:SetHeight(header:GetAttribute('initial-height'))
		]],
		'initial-width', Healium_oUF_Config.unitframeWidth,
		'initial-height', Healium_oUF_Config.unitframeHeight,
		"showSolo", Healium_oUF_Config.showsolo,
		"showParty", true,
		"showPlayer", Healium_oUF_Config.showplayerinparty,
		"showRaid", true,
		"groupFilter", "1,2,3,4,5,6,7,8",
		"groupingOrder", "1,2,3,4,5,6,7,8",
		"groupBy", "GROUP",
		"yOffset", -4
	)
	PlayerRaidHeader:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 180, -300)
	PlayerRaidHeader.hVisibilityAttribute = Visibility25

	if Healium_oUF_Config.showPets then
		PetRaidHeader = self:SpawnHeader("oUF_HealiumRaidPet0125", "SecureGroupPetHeaderTemplate", "custom [@raid11,exists] hide;show",
			'oUF-initialConfigFunction', [[
				local header = self:GetParent()
				self:SetWidth(header:GetAttribute('initial-width'))
				self:SetHeight(header:GetAttribute('initial-height'))
			]],
			'initial-width', Healium_oUF_Config.unitframeWidth,
			'initial-height', Healium_oUF_Config.unitframeHeight,
			"showSolo", Healium_oUF_Config.showsolo,
			"showParty", true,
			"showRaid", true,
			"yOffset", -4,
			"groupFilter", "1,2,3,4,5,6,7,8",
			"groupingOrder", "1,2,3,4,5,6,7,8",
			"groupBy", "GROUP",
			"maxColumns", 1,
			"unitsPerColumn", 10,
			"filterOnPet", true,
			"sortMethod", "NAME"
		)
		PetRaidHeader:SetPoint("TOPLEFT", PlayerRaidHeader, "BOTTOMLEFT", 0, -50)
		PetRaidHeader.hVisibilityAttribute = Visibility10
	end

	if Healium_oUF_Config.showTanks then
		-- Tank frame (attributes: [["groupFilter", "MAINTANK,TANK"]],  [["groupBy", "ROLE"]],    showParty, showRaid but not showSolo)
		TankRaidHeader = self:SpawnHeader("oUF_HealiumRaidTank0125", nil, Visibilityl25,
			'oUF-initialConfigFunction', [[
				local header = self:GetParent()
				self:SetWidth(header:GetAttribute('initial-width'))
				self:SetHeight(header:GetAttribute('initial-height'))
			]],
			'initial-width', Healium_oUF_Config.unitframeWidth,
			'initial-height', Healium_oUF_Config.unitframeHeight,
			"showSolo", false,
			"showParty", true,
			"showRaid", true,
			"showPlayer", Healium_oUF_Config.showplayerinparty,
			"yOffset", -4,
			"groupFilter", "MAINTANK,TANK",
			"sortMethod", "NAME"
		)
		TankRaidHeader:SetPoint("BOTTOMLEFT", PlayerRaidHeader, "TOPLEFT", 0, 50)
		TankRaidHeader.hVisibilityAttribute = Visibility25
	end

	if Healium_oUF_Config.showNamelist then
		-- Namelist frame
		NamelistRaidHeader = self:SpawnHeader("oUF_HealiumRaidNamelist0125", nil, Visibility25,
			'oUF-initialConfigFunction', [[
				local header = self:GetParent()
				self:SetWidth(header:GetAttribute('initial-width'))
				self:SetHeight(header:GetAttribute('initial-height'))
			]],
			'initial-width', Healium_oUF_Config.unitframeWidth,
			'initial-height', Healium_oUF_Config.unitframeHeight,
			"showSolo", Healium_oUF_Config.showsolo,
			"showParty", true,
			"showRaid", true,
			"showPlayer", Healium_oUF_Config.showplayerinparty,
			"yOffset", -4,
			"sortMethod", "NAME",
			"maxColumns", 1,
			"unitsPerColumn", 20,
			"nameList", Healium_oUF_Config.namelist
		)
		NamelistRaidHeader:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -400, -300)
		NamelistRaidHeader.hVisibilityAttribute = Visibility25
	end
end)