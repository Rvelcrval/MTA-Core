if IS_MTA_GM then return end

if SERVER then
	local function antlion()
		return ents.Create("npc_antlion")
	end

	hook.Add("MTANPCSpawnProcess", "mines", function(ply, pos, wanted_lvl)
		if not ply.IsInZone then return end
		if not ply:IsInZone("cave") then return end

		return antlion
	end)

	hook.Add("MTAIsInValidArea", "mta_mines", function(ply)
		if ply.IsInZone and ply:IsInZone("cave") then return true end
	end)

	hook.Add("MTAStatIncrease", "mta_mines", function(ply)
		if ply.IsInZone and ply:IsInZone("cave") then return false end
	end)
end

if CLIENT then
	local prev_color, prev_text = MTA.PrimaryColor, MTA.WantedText
	hook.Add("PlayerEnteredZone", "mta_mines", function(_, zone)
		if zone ~= "cave" then return end

		MTA.OnGoingEvent = "mines"

		prev_color, prev_text = MTA.PrimaryColor, MTA.WantedText
		MTA.PrimaryColor = Color(0, 255, 0)
		MTA.WantedText = "RUCHE"
	end)


	hook.Add("PlayerExitedZone", "mta_mines", function(_, zone)
		if zone ~= "cave" then return end

		MTA.OnGoingEvent = false
		MTA.PrimaryColor = prev_color
		MTA.WantedText = prev_text
	end)
end