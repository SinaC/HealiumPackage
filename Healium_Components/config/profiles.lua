local H, C, L = unpack(select(2,...))

if H.myname == "Meuhhnon" then
	C["DRUID"][3].spells[6].spellID = nil
	C["DRUID"][3].spells[6].macroName = "NSHT" -- Nature Swiftness + Healing Touch

	C["DRUID"][3].spells[9].spellID = nil
	C["DRUID"][3].spells[9].macroName = "NSBR" -- Nature Swiftness + Rebirth
end

if H.myname == "Yoog" then
	C["SHAMAN"][3].spells[5].spellID = nil
	--C["SHAMAN"][3].spells[5].macroName = "NSHW" -- Nature Swiftness + Greater Healing Wave
	C["SHAMAN"][3].spells[5].macroName = "TEST" -- TEST

	C["SHAMAN"][1] = {}
	C["SHAMAN"][1].spells = {
		{ macroName = "TEST" }
	}
end

if H.myclass == "HUNTER" then
	C["general"].showBuff = true
	C["general"].showDebuff = false
	C["general"].showOOM = false
	C["general"].showOOR = false
end