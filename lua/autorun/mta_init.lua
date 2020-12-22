AddCSLuaFile("mta/core.lua")
AddCSLuaFile("mta/payday2_assault.lua")
AddCSLuaFile("mta/upgrades.lua")
AddCSLuaFile("mta/skill_tree.lua")
AddCSLuaFile("mta/bounties.lua")
AddCSLuaFile("mta/bombs.lua")

include("mta/core.lua")
include("mta/payday2_assault.lua")
include("mta/upgrades.lua")
include("mta/skill_tree.lua")
include("mta/bounties.lua")
include("mta/bombs.lua")

-- riot shield
do
	-- apparently the texture manager needs to be loaded before the entities
	AddCSLuaFile("mta/riot_shield/riot_shield.texture_manager.lua")
	AddCSLuaFile("mta/riot_shield/riot_shield.lua")
	AddCSLuaFile("mta/riot_shield/riot_shield_table.lua")

	include("mta/riot_shield/riot_shield.texture_manager.lua")
	include("mta/riot_shield/riot_shield.lua")
	include("mta/riot_shield/riot_shield_table.lua")
end