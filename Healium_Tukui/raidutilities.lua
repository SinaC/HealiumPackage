-- Ripped from Tukui\modules\misc\raidutilities.lua

local ADDON_NAME, _ = ...
local T, C, L = unpack(Tukui)
local panel_height = ((T.Scale(5)*3) + (T.Scale(22)*3))

local function CreateUtilities(self, event, addon)
	-- only when this addon is loaded
	if addon ~= ADDON_NAME then return end
	-- already created ?
	if _G["TukuiRaidUtility"] then return end
	-- it need the Tukui minimap
	if not TukuiMinimap then return end

	--Create main frame
	local TukuiRaidUtility = CreateFrame("Frame", "TukuiRaidUtility", UIParent)
	TukuiRaidUtility:CreatePanel("Default", TukuiMinimap:GetWidth(), panel_height, "TOPRIGHT", TukuiMinimapStatsRight, "BOTTOMRIGHT", 0, -2)
	TukuiRaidUtility:Hide()

	--Check if We are Raid Leader or Raid Officer
	local function CheckRaidStatus()
		local inInstance, instanceType = IsInInstance()
		if (UnitIsRaidOfficer("player")) and not (inInstance and (instanceType == "pvp" or instanceType == "arena")) then
			return true
		else
			return false
		end
	end

	--Change border when mouse is inside the button
	local function ButtonEnter(self)
		local color = RAID_CLASS_COLORS[T.myclass]
		self:SetBackdropBorderColor(color.r, color.g, color.b)
	end

	--Change border back to normal when mouse leaves button
	local function ButtonLeave(self)
		self:SetBackdropBorderColor(unpack(C["media"].bordercolor))
	end

	-- Function to create buttons in this module
	local function CreateButton(name, parent, template, width, height, point, relativeto, point2, xOfs, yOfs, text, texture)
		local b = CreateFrame("Button", name, parent, template)
		b:SetWidth(width)
		b:SetHeight(height)
		b:SetPoint(point, relativeto, point2, xOfs, yOfs)
		b:HookScript("OnEnter", ButtonEnter)
		b:HookScript("OnLeave", ButtonLeave)
		b:EnableMouse(true)
		b:SetTemplate("Default")
		if text then
			local t = b:CreateFontString(nil,"OVERLAY",b)
			t:SetFont(C["media"].font,12)
			t:SetPoint("CENTER")
			t:SetJustifyH("CENTER")
			t:SetText(text)
			b:SetFontString(t)
		elseif texture then
			local t = b:CreateTexture(nil,"OVERLAY",nil)
			t:SetTexture(normTex)
			t:SetPoint("TOPLEFT", b, "TOPLEFT", T.mult, -T.mult)
			t:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -T.mult, T.mult)
		end
	end

	--Show Button
	CreateButton("TukuiRaidUtilityShowButton", UIParent, "UIMenuButtonStretchTemplate, SecureHandlerClickTemplate", TukuiMinimap:GetWidth(), 21, "TOPRIGHT", TukuiMinimapStatsRight, "BOTTOMRIGHT", 0, -2, RAID_ASSISTANT, nil)
	TukuiRaidUtilityShowButton:SetFrameRef("TukuiRaidUtility", TukuiRaidUtility)
	TukuiRaidUtilityShowButton:SetAttribute("_onclick", [=[self:Hide(); self:GetFrameRef("TukuiRaidUtility"):Show();]=])
	TukuiRaidUtilityShowButton:SetScript("OnMouseUp", function(self) TukuiRaidUtility.toggled = true end)
	TukuiRaidUtilityShowButton:Hide()

	--Close Button
	CreateButton("TukuiRaidUtilityCloseButton", TukuiRaidUtility, "UIMenuButtonStretchTemplate, SecureHandlerClickTemplate", TukuiMinimap:GetWidth(), 21, "TOP", TukuiRaidUtility, "BOTTOM", 0, -2, CLOSE, nil)
	TukuiRaidUtilityCloseButton:SetFrameRef("TukuiRaidUtilityShowButton", TukuiRaidUtilityShowButton)
	TukuiRaidUtilityCloseButton:SetAttribute("_onclick", [=[self:GetParent():Hide(); self:GetFrameRef("TukuiRaidUtilityShowButton"):Show();]=])
	TukuiRaidUtilityCloseButton:SetScript("OnMouseUp", function(self) TukuiRaidUtility.toggled = false end)

	--Disband Raid button
	CreateButton("TukuiRaidUtilityDisbandRaidButton", TukuiRaidUtility, "UIMenuButtonStretchTemplate", TukuiRaidUtility:GetWidth() * 0.95, T.Scale(21), "TOP", TukuiRaidUtility, "TOP", 0, T.Scale(-5), "Disband Group", nil)
	TukuiRaidUtilityDisbandRaidButton:SetScript("OnMouseUp", function(self)
		if CheckRaidStatus() then
			StaticPopup_Show("TUKUIDISBAND_RAID")
		end
	end)

	--Role Check button
	CreateButton("TukuiRaidUtilityRoleCheckButton", TukuiRaidUtility, "UIMenuButtonStretchTemplate", TukuiRaidUtility:GetWidth() * 0.95, T.Scale(21), "TOP", TukuiRaidUtilityDisbandRaidButton, "BOTTOM", 0, T.Scale(-5), ROLE_POLL, nil)
	TukuiRaidUtilityRoleCheckButton:SetScript("OnMouseUp", function(self)
		if CheckRaidStatus() then
			InitiateRolePoll()
		end
	end)

	--Ready Check button
	CreateButton("TukuiRaidUtilityReadyCheckButton", TukuiRaidUtility, "UIMenuButtonStretchTemplate", TukuiRaidUtilityRoleCheckButton:GetWidth() * 0.75, T.Scale(21), "TOPLEFT", TukuiRaidUtilityRoleCheckButton, "BOTTOMLEFT", 0, T.Scale(-5), READY_CHECK, nil)
	TukuiRaidUtilityReadyCheckButton:SetScript("OnMouseUp", function(self)
		if CheckRaidStatus() then
			DoReadyCheck()
		end
	end)

	--Reposition/Resize and Reuse the World Marker Button
	CompactRaidFrameManagerDisplayFrameLeaderOptionsRaidWorldMarkerButton:ClearAllPoints()
	CompactRaidFrameManagerDisplayFrameLeaderOptionsRaidWorldMarkerButton:SetPoint("TOPLEFT", TukuiRaidUtilityReadyCheckButton, "TOPRIGHT", T.Scale(4), 0)
	CompactRaidFrameManagerDisplayFrameLeaderOptionsRaidWorldMarkerButton:SetParent(TukuiRaidUtility)
	CompactRaidFrameManagerDisplayFrameLeaderOptionsRaidWorldMarkerButton:SetHeight(T.Scale(21))
	CompactRaidFrameManagerDisplayFrameLeaderOptionsRaidWorldMarkerButton:SetWidth(TukuiRaidUtilityRoleCheckButton:GetWidth() * 0.22)

	--Put other stuff back
	CompactRaidFrameManagerDisplayFrameLeaderOptionsInitiateReadyCheck:ClearAllPoints()
	CompactRaidFrameManagerDisplayFrameLeaderOptionsInitiateReadyCheck:SetPoint("BOTTOMLEFT", CompactRaidFrameManagerDisplayFrameLockedModeToggle, "TOPLEFT", 0, 1)
	CompactRaidFrameManagerDisplayFrameLeaderOptionsInitiateReadyCheck:SetPoint("BOTTOMRIGHT", CompactRaidFrameManagerDisplayFrameHiddenModeToggle, "TOPRIGHT", 0, 1)

	CompactRaidFrameManagerDisplayFrameLeaderOptionsInitiateRolePoll:ClearAllPoints()
	CompactRaidFrameManagerDisplayFrameLeaderOptionsInitiateRolePoll:SetPoint("BOTTOMLEFT", CompactRaidFrameManagerDisplayFrameLeaderOptionsInitiateReadyCheck, "TOPLEFT", 0, 1)
	CompactRaidFrameManagerDisplayFrameLeaderOptionsInitiateRolePoll:SetPoint("BOTTOMRIGHT", CompactRaidFrameManagerDisplayFrameLeaderOptionsInitiateReadyCheck, "TOPRIGHT", 0, 1)

	--Reskin Stuff
	do
		local buttons = {
			"CompactRaidFrameManagerDisplayFrameLeaderOptionsRaidWorldMarkerButton",
			"TukuiRaidUtilityDisbandRaidButton",
			--"TukuiRaidUtilityMainTankButton",
			--"TukuiRaidUtilityMainAssistButton",
			"TukuiRaidUtilityRoleCheckButton",
			"TukuiRaidUtilityReadyCheckButton",
			"TukuiRaidUtilityShowButton",
			"TukuiRaidUtilityCloseButton"
		}

		for i, button in pairs(buttons) do
			local f = _G[button]
			_G[button.."Left"]:SetAlpha(0)
			_G[button.."Middle"]:SetAlpha(0)
			_G[button.."Right"]:SetAlpha(0)
			f:SetHighlightTexture("")
			f:SetDisabledTexture("")
			f:HookScript("OnEnter", ButtonEnter)
			f:HookScript("OnLeave", ButtonLeave)
			f:SetTemplate("Default", true)
		end
	end

	local function ToggleRaidUtil(self, event)
		if InCombatLockdown() then
			self:RegisterEvent("PLAYER_REGEN_ENABLED")
			return
		end

		if CheckRaidStatus() then
			if not TukuiRaidUtility.toggled then TukuiRaidUtilityShowButton:Show() end
		else
			TukuiRaidUtilityShowButton:Hide()
			if TukuiRaidUtility:IsShown() then TukuiRaidUtility:Hide() end
		end

		if event == "PLAYER_REGEN_ENABLED" then
			self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		end
	end

	--Automatically show/hide the frame if we have RaidLeader or RaidOfficer
	local LeadershipCheck = CreateFrame("Frame")
	LeadershipCheck:RegisterEvent("RAID_ROSTER_UPDATE")
	LeadershipCheck:RegisterEvent("PLAYER_ENTERING_WORLD")
	LeadershipCheck:SetScript("OnEvent", ToggleRaidUtil)

	-- Starts hidden
	--TukuiRaidUtilityShowButton:Hide()
	--TukuiRaidUtility:Hide()
end

local AddonLoaded = CreateFrame("Frame")
AddonLoaded:RegisterEvent("ADDON_LOADED")
AddonLoaded:SetScript("OnEvent", CreateUtilities)