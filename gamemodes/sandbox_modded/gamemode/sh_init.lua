DeriveGamemode("sandbox")

GM.Name = "MTA"
GM.Author = "Meta Construct"
GM.Email = ""
GM.Website = "http://metastruct.net"

if SERVER then
	local GOD_CVAR = GetConVar("sbox_godmode")
	if GOD_CVAR then GOD_CVAR:SetBool(false) end

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
		ply:Give("weapon_crowbar")
		ply:Give("none")

		-- Prevent default Loadout.
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
		end
	end

	function GM:PostCleanupMap()
		spawn_ents()
	end

	function GM:InitPostEntity()
		spawn_ents()
	end
end