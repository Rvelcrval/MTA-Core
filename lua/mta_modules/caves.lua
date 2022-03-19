if IS_MTA_GM then return end

hook.Add("MTAIsInValidArea", "mta_mines", function(ply)
	if ply.IsInZone and ply:IsInZone("cave") then return true end
end)

if SERVER then
	local function add_coefs()
		MTA.Coeficients.npc_antlion = {
			["kill_coef"] = 1.5,
			["damage_coef"] = 1,
		}

		MTA.Coeficients.npc_antlion_worker = {
			["kill_coef"] = 1.5,
			["damage_coef"] = 1,
		}

		MTA.Coeficients.npc_antlionguard = {
			["kill_coef"] = 5,
			["damage_coef"] = 1,
		}
	end

	local npcs = {
		antlions = function() return ents.Create("npc_antlion") end,
		antlion_workers = function() return ents.Create("npc_antlion_worker") end,
		antlion_guards = function() return ents.Create("npc_antlionguard") end,
	}

	hook.Add("MTANPCSpawnProcess", "mines", function(ply, pos, wanted_lvl)
		if not ply.IsInZone then return end
		if not ply:IsInZone("cave") then return end

		add_coefs()

		local spawn_function = npcs.antlions
		if wanted_lvl > 10 then
			if math.random(0, 100) < 25 then
				spawn_function = npcs.antlion_guards
			end

			if wanted_level > 20 and math.random(0, 100) < 5 then
				spawn_function = npcs.antlion_guards
			end
		end

		return spawn_function
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

	local song = "https://gitlab.com/metastruct/mta_projects/mta/-/raw/master/external/songs/caves/TRACK_1.ogg"
	hook.Add("MTAGetDefaultSong", TAG, function()
		if not ply.IsInZone then return end
		if not ply:IsInZone("cave") then return end

		return song, "caves.dat"
	end)
end