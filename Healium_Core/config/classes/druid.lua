local H, C, L = unpack(select(2,...))

C["DRUID"] = {
	-- 774 Rejuvenation
	-- 2782 Remove Corruption
	-- 5185 Healing Touch
	-- 8936 Regrowth
	-- 18562 Swiftmend, castable only of affected by Rejuvenation or Regrowth
	-- 20484 Rebirth
	-- 29166 Innervate
	-- 33763 Lifebloom
	-- 48438 Wild Growth
	-- 50464 Nourish
	[3] = { -- Restoration
		spells = {
			{ spellID = 774 }, -- Rejuvenation
			{ spellID = 33763 }, -- Lifebloom
			{ spellID = 50464 }, -- Nourish
			{ spellID = 8936 }, -- Regrowth
			{ spellID = 18562, buffs = { 774, 8936 } }, -- Swiftmend, castable only of affected by Rejuvenation or Regrowth
			{ spellID = 5185 }, -- Macro Nature Swiftness + Healing Touch
			{ spellID = 48438 }, -- Wild Growth
			{ spellID = 2782, dispels = { ["Poison"] = true, ["Curse"] = true, ["Magic"] = function() return select(5, GetTalentInfo(3,17)) > 0 end } }, -- Remove Corruption
			{ spellID = 20484, rez = true }, -- Rebirth
		},
	}
}