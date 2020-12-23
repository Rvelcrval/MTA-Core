if SERVER then
	local function clamp_vector(vec, limit)
		vec.x = math.Clamp(vec.x, -limit, limit)
		vec.y = math.Clamp(vec.y, -limit, limit)
		vec.z = math.Clamp(vec.z, -limit, limit)

		return vec
	end

	hook.Add("EntityTakeDamage", "MTASkill_Ionization", function(target, dmg_info)
		if not target:GetNWBool("MTACombine") then return end

		local atck = dmg_info:GetAttacker()
		if IsValid(atck) and MTA.IsWanted(atck) and MTA.HasSkill(atck, "damage_multiplier", "ionization") then
			local force = clamp_vector((atck:WorldSpaceCenter() - target:WorldSpaceCenter()) * 9999, 9999999)
			dmg_info:SetDamageForce(-force)
			dmg_info:SetDamage(2e6)
			dmg_info:SetDamageType(DMG_DISSOLVE)
		end
	end)
end

MTA.RegisterSkill("ionization", "damage_multiplier", 100, "Ionization", "Your weapons become highly charged with ion particles becoming instantly lethal to combines")