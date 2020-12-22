if SERVER then
	hook.Add("ScaleNPCDamage", "MTASkill_FieryBullets", function(npc, _, dmg_info)
		if not npc:GetNWBool("MTACombine") then return end

		local atck = dmg_info:GetAttacker()
		if not atck:IsPlayer() then return end
		if not MTA.IsWanted(atck) then return end
		if not MTA.HasSkill(atck, "damage_multiplier", "incendary_bullets") then return end
		if not dmg_info:IsBulletDamage() then return end

		if math.random(0, 100) <= 25 then
			dmg_info:SetDamageType(DMG_BURN)
			npc:Ignite(2)
		end
	end)
end

MTA.RegisterSkill("incendary_bullets", "damage_multiplier", 20, "Fiery Bullets", "Each bullets has a 25% chance to ignite enemies for 2s on-hit")