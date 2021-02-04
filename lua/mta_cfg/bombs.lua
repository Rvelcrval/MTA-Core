local IS_MTA_GM = (gmod.GetGamemode() or GM or GAMEMODE).Name == "MTA"

return {
	["BlockingClasses"] = {
		"prop_door_rotating",
		"func_breakable",
		"func_movelinear",
		"prop_physics",
		"prop_dynamic",
	},
	["CampingDistance"] = IS_MTA_GM and 300 or 150,
	["CampingInterval"] = 180,
}
