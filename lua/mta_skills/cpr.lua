local tag = "MTASkill_CPR"

local REVIVE_COST = MTA_CONFIG.upgrades.ReviveCost

if SERVER then
	util.AddNetworkString(tag)

	local dead_players = {}
	net.Receive(tag, function(_, ply)
		local should_revive = net.ReadBool()
		if not should_revive then
			dead_players[ply] = nil
			return
		end

		local ply_data = dead_players[ply]
		if not ply_data then
			MTA.ChatPrint(ply, "There was a problem reviving you")
			return
		end

		if MTA.GetPlayerStat(ply, "points") < REVIVE_COST then return end
		MTA.IncreasePlayerStat(ply, "points", -REVIVE_COST, true)

		local pos = ply_data.Pos or ply:GetPos()
		ply:Spawn()
		ply:SetPos(pos)
		for _, wep_class_name in pairs(ply_data.Weapons) do
			local wep = ply:Give(wep_class_name)
			wep.unrestricted_gun = true
			wep.lobbyok = true
			wep.PhysgunDisabled = true
			wep.dont_televate = true

			if wep.SetClip1 and wep.GetMaxClip1 then
				wep:SetClip1(wep:GetMaxClip1())
			end

			if wep.SetClip2 then
				wep:SetClip2(2)
			end
		end

		-- we check this because people can make scripts that auto revive
		-- themselves and get sent to other places on the map
		-- its also possible if a friend brings you
		if not MTA.ShouldIncreasePlayerFactor(ply, true) then return end
		MTA.IncreasePlayerFactor(ply, ply_data.WantedLevel * 10)
	end)

	hook.Add("PlayerDisconnected", tag, function(ply)
		dead_players[ply] = nil
	end)

	-- we do this here, because PlayerDeath is too late
	hook.Add("MTAPlayerFailed", tag, function(ply, _, wanted_level, is_death)
		if not is_death then return end

		if MTA.HasSkill(ply, "healing_multiplier", "cpr") then
			local wep_class_names = {}
			for _, wep in pairs(ply:GetWeapons()) do
				table.insert(wep_class_names, wep:GetClass())
			end

			dead_players[ply] = {
				Weapons = wep_class_names,
				WantedLevel = wanted_level,
				Pos = ply:GetPos(),
			}

			net.Start(tag)
			net.Send(ply)
		end
	end)
end

if CLIENT then
	net.Receive(tag, function()
		Derma_Query("Would you like to revive yourself with your current wanted level and weapoons?", "MTA CPR (Revive)",
			("Yes (%dpts)"):format(REVIVE_COST), function()
				net.Start(tag)
				net.WriteBool(true)
				net.SendToServer()
			end,
			"No", function()
				net.Start(tag)
				net.WriteBool(false)
				net.SendToServer()
			end
		)
	end)
end

MTA.RegisterSkill("cpr", "healing_multiplier", 40, "CPR", "Get a second chance in exchange for points")