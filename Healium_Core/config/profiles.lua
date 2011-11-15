-- Character/Class specific config

local H, C, L = unpack(select(2,...))

if H.myname == "Meuhhnon" then
	C["general"].debuffFilter = "BLACKLIST"

	C["DRUID"][3].spells[6].spellID = nil
	C["DRUID"][3].spells[6].macroName = "NSHT" -- Nature Swiftness + Healing Touch

	C["DRUID"][3].spells[9].spellID = nil
	C["DRUID"][3].spells[9].macroName = "NSBR" -- Nature Swiftness + Rebirth

	-- remove Weakened soul from blacklist(6788)
	if C["blacklist"] then
		for id, value in pairs(C["blacklist"]) do
			if value == 6788 then
				tremove(C["blacklist"], id)
				break
			end
		end
	end
end

if H.myname == "Enimouchet" then
	C["general"].debuffFilter = "BLACKLIST"
end

if H.myname == "Yoog" then
	C["general"].debuffFilter = "BLACKLIST"

	C["SHAMAN"][3].spells[5].spellID = nil
	C["SHAMAN"][3].spells[5].macroName = "NSHW" -- Nature Swiftness + Greater Healing Wave

	-- TEST
	C["general"].debuffFilter = "NONE"

	--C["SHAMAN"][3].spells = nil

	C["general"].showPriorityDebuff = true
	C["SHAMAN"][1] = {}
	C["SHAMAN"][1].spells = {
		{ macroName = "TEST" }
	}
end

--------------------------------------------------------------

if H.myname == "Holycrap" then
	C.general.maxButtonCount = 15
	C.general.dispelAnimation = "NONE"

	C["general"].debuffFilter = "BLACKLIST"

	C["PRIEST"][2].spells = {
		{ spellID = 47788 }, -- Guardian Spirit (Holy)
		{ spellID = 139 }, -- Renew
		{ spellID = 2050 }, -- Heal
		{ spellID = 33076 }, -- Prayer of Mending
		{ spellID = 34861 }, -- Circle of Healing (Holy)
		{ spellID = 2061 }, -- Flash Heal
		{ spellID = 2060 }, -- Greater Heal
		{ spellID = 32546 }, -- Binding Heal
		{ spellID = 596 }, -- Prayer of Healing
		{ spellID = 17, debuffs = { 6788 } }, -- Power Word: Shield not castable if affected by Weakened Soul
		{ spellID = 527, dispels = { ["Magic"] = true } }, -- Dispel Magic
		{ spellID = 528, dispels = { ["Disease"] = true } }, -- Cure Disease
		{ spellID = 1706 }, -- Levitate
		{ spellID = 2006 }, -- Resurection
		{ spellID = 73325 }, -- Leap of Faith
	}
end

if H.myname == "Bombella" then
	C["general"].debuffFilter = "BLACKLIST"
	C["SHAMAN"][3].spells = {
		{ spellID = 974 }, -- Earth Shield
		{ spellID = 61295 }, -- Riptide
		{ spellID = 331 }, -- Healing Wave
		{ spellID = 77472 },  -- Greater Healing Wave
		{ spellID = 1064 }, -- Chain Heal
		{ spellID = 8004 }, -- Healing Surge
		{ spellID = 51886, dispels = { ["Curse"] = true, ["Magic"] = function() return select(5, GetTalentInfo(3,12)) > 0 end } }, -- Cleanse Spirit
	}
end

--------------------------------------------------------------

if H.myname == "Noctissia" then
	C["general"].debuffFilter = "BLACKLIST"
	C["SHAMAN"][3].spells = {
		{ spellID = 974 }, -- Earth Shield
		{ spellID = 61295 }, -- Riptide
		{ spellID = 331 }, -- Healing Wave
		{ macroName = "NSHW" },  -- Greater Healing Wave
		{ spellID = 1064 }, -- Chain Heal
		{ spellID = 8004 }, -- Healing Surge
		{ spellID = 51886, dispels = { ["Curse"] = true, ["Magic"] = function() return select(5, GetTalentInfo(3,12)) > 0 end } }, -- Cleanse Spirit
	}
end

if H.myclass == "HUNTER" then
	C["general"].showBuff = true
	C["general"].showDebuff = false
	C["general"].showOOM = false
	C["general"].showOOR = false
end
