return {
	["DamageWhitelist"] = {
		"crossbow_bolt",
		"npc_grenade_frag",
		"rpg_missile",
		"rpg_rocket",
		"prop_combine_ball",
		"grenade_ar2",
		"npc_satchel",
		"crossbow_bolt_hl1",
		"monster_tripmine",
		"grenade_hand",
		"ent_lite_hegrenade",
		"ms_hax_monitor",
		"mta_mobile_emp",
	},
	["BaseDecreaseFactor"] = 1,
	["Coeficients"] = {
		["player"] = {
			["kill_coef"] = 2.5,
			["damage_coef"] = 0,
		},
		["npc_manhack"] = {
			["kill_coef"] = 1,
			["damage_coef"] = 0.75,
		},
		["lua_npc"] = {
			["kill_coef"] = 1,
			["damage_coef"] = 0.5,
		},
		["lua_npc_wander"] = {
			["kill_coef"] = 1,
			["damage_coef"] = 0.5,
		},
		["npc_combine_s"] = {
			["kill_coef"] = 1.5,
			["damage_coef"] = 1,
		},
		["npc_metropolice"] = {
			["kill_coef"] = 1.5,
			["damage_coef"] = 1,
		},
	},
	["CanOptOut"] = not IS_MTA_GM,
	["UseMapData"] = not IS_MTA_GM,
	["DecreaseDivider"] = 250,
	["EscapeTime"] = 20,
	["MaxCombines"] = IS_MTA_GM and 100 or 25,
}