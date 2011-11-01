local H, C, L = unpack(select(2,...))

C["PALADIN"] = {
	-- 633 Lay on Hands
	-- 635 Holy Light
	-- 1022 Hand of Protection
	-- 1044 Hand of Freedom
	-- 1038 Hand of Salvation
	-- 4987 Cleanse
	-- 6940 Hand of Sacrifice
	-- 19750 Flash of Light
	-- 20473 Holy Shock
	-- 31789 Righteous Defense
	-- 53563 Beacon of Light
	-- 82326 Divine Light
	-- 85673 Word of Glory
	[1] = { -- Holy
		spells = {
			{ spellID = 20473 }, -- Holy Shock
			{ spellID = 85673 }, -- Word of Glory
			{ spellID = 19750 }, -- Flash of Light
			{ spellID = 635 }, -- Holy Light
			{ spellID = 82326 }, -- Divine Light
			{ spellID = 633 }, -- Lay on Hands
			{ spellID = 1022 }, -- Hand of Protection
			{ spellID = 1044 }, -- Hand of Freedom
			{ spellID = 6940 }, -- Hand of Sacrifice
			{ spellID = 4987, dispels = { ["Poison"] = true, ["Disease"] = true, ["Magic"] = function() return select(5, GetTalentInfo(1,14)) > 0 end } }, -- Cleanse
			{ spellID = 53563 }, -- Beacon of Light
		}
	},
	[2] = { -- Protection
		spells = {
			{ spellID = 31789 }, -- Righteous Defense
			{ spellID = 6940 }, -- Hand of Sacrifice
			{ spellID = 633 }, -- Lay on Hands
			{ spellID = 4987, dispels = { ["Poison"] = true, ["Disease"] = true } }, -- Cleanse
		}
	},
}