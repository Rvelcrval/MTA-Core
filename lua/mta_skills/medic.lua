if SERVER then
	local input_blacklist = {
		item_suitcharger = true,
		item_healthcharger = true,
	}
	hook.Add("AcceptInput", "MTASkill_Medic", function(ent, input, activator)
		if not activator:IsPlayer() then return end
		if not activator.MTABad then return end

		if input == "Use" and input_blacklist[ent:GetClass()] and not MTA.HasSkill(activator, "healing_multiplier", "medic") then
			return true
		end
	end)
end

MTA.RegisterSkill("medic", "healing_multiplier", 15, "Medic", "Health and armor chargers in the medbay become usable")