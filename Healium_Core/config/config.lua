local H, C, L = unpack(select(2,...))

C["general"] = {
	debug = 1000,
	--debugDebuff = "Curse",

	showOOM = true,						-- color heal button in blue when OOM
	showOOR = false,					-- very time consuming and not really useful if unitframes are already tagged as OOR

	maxButtonCount = 12,				-- maximum number of buttons
	buttonSpacing = 2,					-- distance between 2 buttons
	showButtonTooltip = true,			-- display heal buttons tooltip
	buttonTooltipAnchor = nil, 			-- debuff tooltip anchor (nil means button itself)--(ElvUI and _G["TooltipHolder"]) or (Tukui and _G["TukuiTooltipAnchor"])

	showBuff = true,					-- display buff castable by configured spells
	maxBuffCount = 6,					-- maximum number of buff displayed
	buffSpacing = 2,					-- distance between 2 buffs
	showBuffTooltip = true,				-- display buff tooltip
	buffTooltipAnchor = nil,			-- debuff tooltip anchor (nil means buff itself)

	showDebuff = true,					-- display debuff
	maxDebuffCount = 8,					-- maximum number of debuff displayed
	debuffSpacing = 2,					-- distance between 2 debuffs
	showDebuffTooltip = true,			-- display debuff tooltip
	debuffTooltipAnchor = nil,			-- debuff tooltip anchor (nil means debuff itself)
	showPriorityDebuff = false,			-- display only one debuff frame displaying the most important debuff (priority may be added in whilelist, lower value means higher priority)

	-- DISPELLABLE: show only dispellable debuff
	-- BLACKLIST: exclude non-dispellable debuff from list
	-- WHITELIST: include non-dispellable debuff from list
	-- NONE: show every non-dispellable debuff
	debuffFilter = "WHITELIST",
	highlightDispel = true,				-- highlight dispel button when debuff is dispellable (no matter they are shown or not but only if not in dispellable filter)
	playSoundOnDispel = true,			-- play a sound when a debuff is dispellable (no matter they are shown or not but only if not in dispellable filter)
	dispelSoundFile = "Sound\\Doodad\\BellTollHorde.wav",
	-- FLASH: flash button
	-- BLINK: blink button
	-- PULSE: pulse button
	-- NONE: no flash
	dispelAnimation = "PULSE", 			-- animate dispel button when debuff is dispellable (no matter they are shown or not but only if not in dispellable filter)
}

C["colors"] = {
	unitDead = {1, 0.1, 0.1},
	unitOOR = {1.0, 0.3, 0.3},
	spellPrereqFailed = {0.2, 0.2, 0.2},
	spellNotUsable = {1.0, 0.5, 0.5},
	OOM = {0.5, 0.5, 1.0},
}