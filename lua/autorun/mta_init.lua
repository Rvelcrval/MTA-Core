pcall(require, "coinsys")

IS_MTA_GM = false
MTA_CONFIG = {}

for _, f in pairs(file.Find("mta_cfg/*.lua", "LUA")) do
	local path = "mta_cfg/" .. f
	AddCSLuaFile(path)
end

AddCSLuaFile("skins/mta.lua")
AddCSLuaFile("mta/core.lua")
AddCSLuaFile("mta/songs.lua")
AddCSLuaFile("mta/weapons.lua")
AddCSLuaFile("mta/upgrades.lua")
AddCSLuaFile("mta/skill_tree.lua")
AddCSLuaFile("mta/bounties.lua")
AddCSLuaFile("mta/bombs.lua")
AddCSLuaFile("mta/fever.lua")
AddCSLuaFile("mta/riot_shield_texture_manager.lua")

-- better combine tracers
do
	if SERVER then
		resource.AddFile("particles/cmb_tracers_rework.pcf")
		resource.AddFile("particles/weapon_fx.pcf")
	end

	PrecacheParticleSystem("cmb_tracer")
	PrecacheParticleSystem("ar2_combineball")
	PrecacheParticleSystem("Weapon_Combine_Ion_Cannon")

	game.AddParticles("particles/cmb_tracers_rework.pcf")
	game.AddParticles("particles/weapon_fx.pcf")
end

-- custom mta combine skins
if SERVER then
	local skin_path = "materials/models/mta/police_skins/"
	for _, f in pairs(file.Find(skin_path .. "*", "GAME")) do
		local ext = string.GetExtensionFromFilename(f)
		if ext == "vtf" or ext == "vmt" then
			resource.AddSingleFile(skin_path .. f)
		end
	end
end

-- badges & achievements that materials that are needed everywhere even if only used
-- in the gamemode
if SERVER then
	resource.AddFile("materials/metabadges/criminal/s1/default.vmt")
	resource.AddFile("materials/metabadges/daily_commitment/s1/default.vmt")
	resource.AddFile("materials/metabadges/zombie_massacre/s1/default.vmt")
end

hook.Add("PostGamemodeLoaded", "MTA", function()
	IS_MTA_GM = (gmod.GetGamemode() or GM or GAMEMODE).Name == "MTA"

	for _, f in pairs(file.Find("mta_cfg/*.lua", "LUA")) do
		local path = "mta_cfg/" .. f
		MTA_CONFIG[f:StripExtension()] = include(path)
	end

	include("skins/mta.lua")
	include("mta/gm_badges.lua")
	include("mta/core.lua")
	include("mta/songs.lua")
	include("mta/weapons.lua")
	include("mta/upgrades.lua")
	include("mta/skill_tree.lua")
	include("mta/bounties.lua")
	include("mta/bombs.lua")
	include("mta/fever.lua")
	include("mta/riot_shield_texture_manager.lua")

	hook.Run("MTAInitialized")
end)