local H, C, L = unpack(select(2,...))

C["PRIEST"] = {
	-- 17 Power Word: Shield not castable if affected by Weakened Soul (6788)
	-- 139 Renew
	-- 527 Dispel Magic (Discipline, Holy)
	-- 528 Cure Disease
	-- 596 Prayer of Healing
	-- 1706 Levitate
	-- 2061 Flash Heal
	-- 2050 Heal
	-- 2060 Greater Heal
	-- 6346 Fear Ward
	-- 32546 Binding Heal
	-- 33076 Prayer of Mending
	-- 47540 Penance (Discipline)
	-- 47788 Guardian Spirit (Holy)
	-- 73325 Leap of Faith
	-- 88684 Holy Word: Serenity (Holy)
	[1] = { -- Discipline
		spells = {
			{ spellID = 17, debuffs = { 6788 } }, -- Power Word: Shield not castable if affected by Weakened Soul
			{ spellID = 139 }, -- Renew
			{ spellID = 2061 }, -- Flash Heal
			{ spellID = 2050 }, -- Heal
			{ spellID = 2060 }, -- Greater Heal
			{ spellID = 47540 }, -- Penance
			{ spellID = 33076 }, -- Prayer of Mending
			{ spellID = 596 }, -- Prayer of Healing
			{ spellID = 527, dispels = { ["Magic"] = true } }, -- Dispel Magic
			{ spellID = 528, dispels = { ["Disease"] = true } }, -- Cure Disease
		},
	},
	[2] = {
		spells = {
			{ spellID = 139 }, -- Renew
			{ spellID = 2061 }, -- Flash Heal
			{ spellID = 2050 }, -- Heal
			{ spellID = 2060 }, -- Greater Heal
			{ spellID = 88684 }, -- Holy Word: Serenity
			{ spellID = 33076 }, -- Prayer of Mending
			{ spellID = 596 }, -- Prayer of Healing
			{ spellID = 47788 }, -- Guardian Spirit
			{ spellID = 527, dispels = { ["Magic"] = true } }, -- Dispel Magic
			{ spellID = 528, dispels = { ["Disease"] = true } }, -- Cure Disease
		},
	}
}