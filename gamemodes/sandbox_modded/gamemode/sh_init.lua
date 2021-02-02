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
end