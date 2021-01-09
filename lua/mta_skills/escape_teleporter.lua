if SERVER then
	hook.Add("MTAPlayerWantedLevelIncreased", "MTASkill_EscapeTeleporter", function(ply, factor)
		if not MTA.HasSkill(ply, "defense_multiplier", "escape_teleporter") then return end
		if factor >= 10 and not ply:HasWeapon("weapon_escape_teleporter") then
			local wep = ply:Give("weapon_escape_teleporter")
			wep.unrestricted_gun = true
		end
	end)
end

MTA.RegisterSkill("escape_teleporter", "defense_multiplier", 10, "Escape Teleporter", "Above wanted level 10 you are granted a teleporter to escape the police")