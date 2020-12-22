if SERVER then
	local Tag = "MTA_ClipSizeSkill"

	-- awaiting Weapon:SetMaxClip# to be added
	--[[local clip_sizes = {
		["weapon_357"] = 6,
		["weapon_pistol"] = 18,
		["weapon_ar2"] = 32,
		["weapon_rpg"] = 3,
		["weapon_shotgun"] = 6,
		["weapon_smg1"] = 45,
	}--]]

	hook.Add("MTAWantedStateUpdate", Tag, function(ply, state)
		if state == true then
			for id, amt in pairs(ply:GetAmmo()) do
				local extra = 0
				--[[for i = 1, 4 do
					if MTA.HasSkill(ply, "damage_multiplier", "clip_size_" .. i) then
						extra = extra + (game.GetAmmoMax(id) * 0.25)
					end
				end--]]
				local max = game.GetAmmoMax(id) * 2
				ply:SetAmmo(math.min(max + extra, amt), id)
			end

			--[[for _, wep in ipairs(ply:GetWeapons()) do
				if clip_sizes[wep] then
					local clip = clip_sizes[wep]
					local extra = 0
					for i = 1, 4 do
						if MTA.HasSkill(ply, "damage_multiplier", "clip_size_" .. i) then
							extra = extra + (clip * 0.25)
						end
					end

					if wep:GetMaxClip1() == clip + extra then continue end
				end
			end--]]
		end
	end)

	local changingAmmo = false
	hook.Add("PlayerAmmoChanged", Tag, function(ply, id, old, new)
		if ply.MTABad and not changingAmmo then
			if old == new then return end
			changingAmmo = true
			timer.Simple(0, function()
				local extra = 0
				--[[for i = 1, 4 do
					if MTA.HasSkill(ply, "damage_multiplier", "clip_size_" .. i) then
						extra = extra + (game.GetAmmoMax(id) * 0.25)
					end
				end--]]
				local max = game.GetAmmoMax(id) * 2
				ply:SetAmmo(math.min(max + extra, new), id)

				-- try this if another loop occurs
				-- otherwise disable it again since theres no good way to set max ammo dynamically without having it apply everywhere :/
				-- timer.Simple(0, function()
					changingAmmo = false
				-- end)
			end)
		end
	end)

	--[[hook.Add("WeaponEquip", Tag, function(wep, ply)

	end)--]]
end

--[[MTA.RegisterSkill("clip_size_1", "damage_multiplier", 15, "Clip Size I", "+25% more ammo in a clip")
MTA.RegisterSkill("clip_size_2", "damage_multiplier", 35, "Clip Size II", "+50% more ammo in a clip")
MTA.RegisterSkill("clip_size_3", "damage_multiplier", 55, "Clip Size III", "+75% more ammo in a clip")
MTA.RegisterSkill("clip_size_4", "damage_multiplier", 75, "Clip Size IV", "Double clip size")--]]