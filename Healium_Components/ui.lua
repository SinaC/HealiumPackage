-- Exported functions
-- H:CreateHealiumButton(parent, name, size, anchor) create a healium button (must contains cooldown)
-- H:CreateHealiumDebuff(parent, name, size, anchor) create a healium debuff (must contains icon, cooldown, count)
-- H:CreateHealiumBuff(parent, name, size, anchor) create a healium buff (must contains icon, cooldown, count)


local H, C, L = unpack(select(2, ...))

function H:CreateHealiumButton(parent, name, size, anchor)
	--print(">Healium:CreateHealiumButton")
	-- frame
	local button = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
	button:SetFrameLevel(1)
	button:SetHeight(size)
	button:SetWidth(size)
	button:SetFrameStrata("BACKGROUND")
	button:SetPoint(unpack(anchor))
	-- texture setup, texture icon is set in UpdateFrameButtons
	button.texture = button:CreateTexture(nil, "BORDER")
	button.texture:SetPoint("TOPLEFT", button ,"TOPLEFT", 0, 0)
	button.texture:SetPoint("BOTTOMRIGHT", button ,"BOTTOMRIGHT", 0, 0)
	button:SetPushedTexture("Interface/Buttons/UI-Quickslot-Depress")
	button:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square")
	-- cooldown overlay
	button.cooldown = CreateFrame("Cooldown", "$parentCD", button, "CooldownFrameTemplate")
	button.cooldown:SetAllPoints(button.texture)
	--print("<Healium:CreateHealiumButton")
	return button
end

function H:CreateHealiumDebuff(parent, name, size, anchor)
	--print(">Healium:CreateHealiumDebuff")
	-- frame
	local debuff = CreateFrame("Frame", name, parent) -- --debuff = CreateFrame("Frame", debuffName, parent, "TargetDebuffFrameTemplate")
	debuff:SetFrameLevel(1)
	debuff:SetHeight(size)
	debuff:SetWidth(size)
	debuff:SetFrameStrata("BACKGROUND")
	debuff:SetPoint(unpack(anchor))
	-- icon
	debuff.icon = debuff:CreateTexture(nil, "ARTWORK")
	debuff.icon:SetPoint("TOPLEFT", 2, -2)
	debuff.icon:SetPoint("BOTTOMRIGHT", -2, 2)
	-- cooldown
	debuff.cooldown = CreateFrame("Cooldown", "$parentCD", debuff, "CooldownFrameTemplate")
	debuff.cooldown:SetAllPoints(debuff.icon)
	debuff.cooldown:SetReverse()
	-- count
	debuff.count = debuff:CreateFontString("$parentCount", "OVERLAY")
	debuff.count:SetFontObject(NumberFontNormal)
	debuff.count:SetPoint("BOTTOMRIGHT", 1, -1)
	debuff.count:SetJustifyH("CENTER")
	--print("<Healium:CreateHealiumDebuff")
	return debuff
end

function H:CreateHealiumBuff(parent, name, size, anchor)
	--print(">Healium:CreateHealiumBuff")
	-- frame
	local buff = CreateFrame("Frame", name, parent) --buff = CreateFrame("Frame", buffName, frame, "TargetBuffFrameTemplate")
	buff:SetFrameLevel(1)
	buff:SetHeight(size)
	buff:SetWidth(size)
	buff:SetFrameStrata("BACKGROUND")
	buff:SetPoint(unpack(anchor))
	-- icon
	buff.icon = buff:CreateTexture(nil, "ARTWORK")
	buff.icon:SetPoint("TOPLEFT", 2, -2)
	buff.icon:SetPoint("BOTTOMRIGHT", -2, 2)
	-- cooldown
	buff.cooldown = CreateFrame("Cooldown", "$parentCD", buff, "CooldownFrameTemplate")
	buff.cooldown:SetAllPoints(buff.icon)
	buff.cooldown:SetReverse()
	-- count
	buff.count = buff:CreateFontString("$parentCount", "OVERLAY")
	buff.count:SetFontObject(NumberFontNormal)
	buff.count:SetPoint("BOTTOMRIGHT", 1, -1)
	buff.count:SetJustifyH("CENTER")
	--print("<Healium:CreateHealiumBuff")
	return buff
end