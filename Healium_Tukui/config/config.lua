local T, C, L = unpack(Tukui) -- Import: T - functions, constants, variables; C - config; L - locales

C["healium"] = {
	unitframeWidth = 120,
	unitframeHeight = 28,

	showTabMenu = true,

	showTanks = true,

	showPets = false,
	maxPets = 5,

	showNamelist = false,
	namelist = "Yoog,Sweetlight,Mirabillis,Enimouchet",

	["general"] = { -- will override Healium_Core config
		buttonTooltipAnchor = _G["TukuiTooltipAnchor"],
		showOOR = false
	},

	-- TODO: use profile
--[[
	["party"] = {
		showTanks = false,
		showPets = true,
		maxPets = 5,
		showNamelist = false,
	},
	["raid10"] = {
		showTanks = false,
		showPets = true,
		maxPets = 5,
		showNamelist = false,
	},
	["raid25"] = {
		style = "COMPACT",
		showTanks = true,
		showPets = false,
		showNamelist = false,
	},
	["raid40"] = {
		style = "COMPACT",
		showTanks = false,
		showPets = false,
		showNamelist = false,
	}
--]]
}
