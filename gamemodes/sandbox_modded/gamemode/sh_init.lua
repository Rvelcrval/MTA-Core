include ("cl_targetid.lua")

DeriveGamemode("sandbox")

GM.Name = "MTA"
GM.Author = "Meta Construct"
GM.Email = ""
GM.Website = "http://metastruct.net"

team.SetUp(6669, "Wanted", Color(244, 135, 2), false)
team.SetUp(6668, "Bounty Hunters", Color(255, 0, 0), false)

if SERVER then
	local GOD_CVAR = GetConVar("sbox_godmode")
	if GOD_CVAR then GOD_CVAR:SetBool(false) end

	RunConsoleCommand("sbox_godmode", "0")
	RunConsoleCommand("sv_allowcslua", "0")

	local hooks = {
		"PlayerSpawnEffect", "PlayerSpawnNPC", "PlayerSpawnObject", "PlayerSpawnProp",
		"PlayerSpawnSENT", "PlayerSpawnSWEP", "PlayerSpawnVehicle", "PlayerNoClip"
	}

	for _, hook_name in pairs(hooks) do
		GM[hook_name] = function(gm, ply)
			return ply:IsAdmin()
		end
	end

	function GM:PlayerLoadout(ply)
		if ply:IsAdmin() then
			ply:Give("weapon_physgun")
		end

		ply:Give("weapon_crowbar")
		ply:Give("none")

		ply:SelectWeapon("none")

		return true
	end

	local mta_ents = {
		{
			["ang"] = Angle(0, 0, 0),
			["pos"] = Vector(840, -4237, 5512),
			["class"] = "mta_vault",
		},
		{
			["ang"] = Angle(0, 0, 0),
			["pos"] = Vector(-2005, 749, 5416),
			["class"] = "lua_npc",
			["role"] = "dealer",
		},
		{
			["ang"] = Angle(0, 0, 0),
			["pos"] = Vector(3904, 7282, 5525),
			["class"] = "mta_vault",
		},
		{
			["ang"] = Angle(0, -90, 0),
			["pos"] = Vector(-1638, 837, 5416),
			["class"] = "mta_skills_computer",
		},
		{
			["ang"] = Angle(0, 0, 0),
			["pos"] = Vector(6048, -362, 5520),
			["class"] = "mta_vault",
		},
		{
			["ang"] = Angle(0, -90, 0),
			["pos"] = Vector(-6702, 2956, 5464),
			["class"] = "mta_vault",
		},
		{
			["ang"] = Angle(0, 0, 0),
			["pos"] = Vector(-1938, 503, 5457),
			["class"] = "mta_jukebox",
		},
		{
			["ang"] = Angle(0, -90, 0),
			["pos"] = Vector(-2242, 5527, 5522),
			["class"] = "mta_vault",
		},
		{
			["ang"] = Angle(0, -90, 0),
			["pos"] = Vector(-6368, 2949, 5464),
			["class"] = "mta_vault",
		},
		{
			["ang"] = Angle(0, -90, 0),
			["pos"] = Vector(728, 7581, 5522),
			["class"] = "mta_vault",
		},
		{
			["ang"] = Angle(0, -90, 0),
			["pos"] = Vector(2267, 1183, 5440),
			["class"] = "mta_vault",
		},
		{
			["ang"] = Angle(0, 90, 0),
			["pos"] = Vector(-6345, 2462, 5464),
			["class"] = "mta_vault",
		},
		{
			["ang"] = Angle(0, 90, 0),
			["pos"] = Vector(-6678, 2445, 5464),
			["class"] = "mta_vault",
		},
		{
			["ang"] = Angle(90, -90, 180),
			["pos"] = Vector(-1632, 973, 5456),
			["class"] = "mta_riot_shield_table",
		},
	}

	local function spawn_ents()
		if not game.GetMap():match("^rp%_unioncity") then return end

		for _, data in pairs(mta_ents) do
			local ent = ents.Create(data.class)
			ent:SetPos(data.pos)
			ent:SetAngles(data.ang)
			ent.role = data.role
			ent:Spawn()
			ent:DropToFloor()
		end
	end

	function GM:PostCleanupMap()
		spawn_ents()
	end

	function GM:InitPostEntity()
		spawn_ents()
	end

	local jail_spots = {
		Vector(1870, -974, 5416),
		Vector(2124, -985, 5416),
		Vector(2112, -1329, 5416),
		Vector(1999, -1317, 5416),
		Vector(1888, -1331, 5416)
	}
	function GM:MTAPlayerFailed(ply, max_factor, old_factor, is_death)
		local spot = jail_spots[math.random(#jail_spots)]
		timer.Simple(0.5, function()
			if not IsValid(ply) then return end
			ply:Spawn()
			ply:SetPos(spot)
		end)
	end

	local function handle_mta_team(ply, state, mta_id)
		if state then
			ply:SetTeam(mta_id)
		elseif aowl then
			ply:SetTeam(ply:IsAdmin() and 2 or 1) -- aowl compat?
		else
			ply:SetTeam(1)
		end
	end

	function GM:MTAWantedStateUpdate(ply, is_wanted)
		handle_mta_team(ply, is_wanted, 6669)
	end

	function GM:MTABountyHunterStateUpdate(ply, is_bounty_hunter)
		handle_mta_team(ply, is_wanted, 6668)
	end
end