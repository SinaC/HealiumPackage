local H, C, L = unpack(select(2,...))

C["SHAMAN"] = {
	-- 331 Healing Wave
	-- 1064 Chain Heal
	-- 974 Earth Shield
	-- 8004 Healing Wave
	-- 51886 Cleanse Spirit
	-- 61295 Riptide
	-- 77472 Greater Healing Wave
	[3] = { -- Restoration
		spells = {
			{ spellID = 974 }, -- Earth Shield
			{ spellID = 61295 }, -- Riptide
			{ spellID = 8004 }, -- Healing Surge
			{ spellID = 331 }, -- Healing Wave
			{ spellID = 77472 },  -- Greater Healing Wave
			{ spellID = 1064 }, -- Chain Heal
			{ spellID = 51886, dispels = { ["Curse"] = true, ["Magic"] = function() return select(5, GetTalentInfo(3,12)) > 0 end } }, -- Cleanse Spirit
		},
	}
}