local TAG = "MTAHalloween"

local coefs = {
	["player"] = {
		["kill_coef"] = 2.5,
		["damage_coef"] = 0,
	},
	["npc_manhack"] = {
		["kill_coef"] = 1,
		["damage_coef"] = 0.75,
	},
	["lua_npc"] = {
		["kill_coef"] = 1,
		["damage_coef"] = 0.5,
	},
	["lua_npc_wander"] = {
		["kill_coef"] = 1,
		["damage_coef"] = 0.5,
	},
	["npc_combine_s"] = {
		["kill_coef"] = 1.5,
		["damage_coef"] = 1,
	},
	["npc_metropolice"] = {
		["kill_coef"] = 1.5,
		["damage_coef"] = 1,
	},
	["npc_zombie"] = {
		["kill_coef"] = 1.5,
		["damage_coef"] = 1,
	},
	["npc_poisonzombie"] = {
		["kill_coef"] = 1.5,
		["damage_coef"] = 1,
	},
	["npc_fastzombie"] = {
		["kill_coef"] = 1.5,
		["damage_coef"] = 1,
	},
	["npc_zombine"] = {
		["kill_coef"] = 1.5,
		["damage_coef"] = 1,
	},
	["npc_headcrab"] = {
		["kill_coef"] = 1,
		["damage_coef"] = 0.75,
	},
	["npc_headcrab_black"] = {
		["kill_coef"] = 1,
		["damage_coef"] = 0.75,
	},
	["npc_headcrab_fast"] = {
		["kill_coef"] = 1,
		["damage_coef"] = 0.75,
	},
	["npc_headcrab_poison"] = { -- same as black but for some reason poison?
		["kill_coef"] = 1,
		["damage_coef"] = 0.75,
	},
	["hwn_pumpkin"] = {
		["kill_coef"] = 1,
		["damage_coef"] = 0.75,
	}
}

local is_halloween = false
local function check_halloween()
	-- dont enable on MTA gamemode, we can make this infinitely better,
	-- this is just a tiny easter egg thing
	is_halloween = os.date("%m") == "10" and not IS_MTA_GM

	if is_halloween then
		MTA.Coeficients = coefs
	else
		MTA.Coeficients = MTA_CONFIG.core.Coeficients
	end

	if CLIENT then
		MTA.PrimaryColor = is_halloween and Color(255, 0, 0) or Color(244, 135, 2)
		MTA.WantedText = is_halloween and "HORDE" or "WANTED"
	end
end

timer.Create(TAG, 60, 0, check_halloween)

if SERVER then
	local function default_log(...)
		Msg("[MTA] ")
		print(...)
	end

	local function warn_log(...)
		if not metalog then
			default_log(...)
			return
		end

		metalog.warn("MTA", nil, ...)
	end

	local enemy_types = {
		zombies = function()
			return ents.Create("npc_zombie")
		end,
		poison_zombies = function()
			return ents.Create("npc_poisonzombie")
		end,
		fast_zombies = function()
			return ents.Create("npc_fastzombie")
		end,
		zombines = function()
			return ents.Create("npc_zombine")
		end,
	}
	hook.Add("MTANPCSpawnProcess", TAG, function(target, pos, wanted_lvl)
		if not is_halloween then return end

		-- below 10 is just zombies
		local spawn_function = enemy_types.zombies

		-- 10% chance of getting poison zombies here and there
		if math.random(0, 100) <= 10 then
			spawn_function = enemy_types.poison_zombies

		-- above level 10 progressively change to only fast zombies
		elseif wanted_lvl < 60 and wanted_lvl >= 10 then
			spawn_function = math.random(0, 60) <= (wanted_lvl + 20) and enemy_types.fast_zombies or enemy_types.zombies

		-- above 60 we add zombines
		elseif wanted_lvl >= 60 then
			spawn_function = math.random(0, 100) < 25 and enemy_types.zombines or enemy_types.fast_zombies
		end

		return spawn_function
	end)

	function update_badge(ply, count)
		local succ, err = pcall(function()
			if MetaBadges then
				local cur_lvl = MetaBadges.GetBadgeLevel(ply, "zombie_massacre") or 0
				MetaBadges.UpgradeBadge(ply, "zombie_massacre", cur_lvl + count)
			end
		end)

		if not succ then
			warn_log("Failed to update badge for:", ply, err)
		end
	end

	hook.Add("MTANPCDrops", TAG, function(npc, attacker)
		if not is_halloween then return end

		if attacker:IsPlayer() then
			attacker.MTAMassacreCount = (attacker.MTAMassacreCount or 0) + 1

			if not GiveCandy then return end

			local candy_count = math.random(0, 3)
			if candy_count <= 0 then return end

			local origin_pos = npc:WorldSpaceCenter()
			timer.Create(("%s_DROP_%d"):format(TAG, npc:EntIndex()), 0.25, candy_count, function()
				local candy = ents.Create("sent_candy")
				candy:SetPos(origin_pos)
				candy:SetAngles(Angle(0,0,0))
				candy.AllowCollect = false

				candy:Spawn()
				candy:Activate()

				local target = attacker
				function candy:Think()
					if not IsValid(target) then
						SafeRemoveEntity(self)
						return
					end

					local pos = self:GetPos()
					local target_pos = target:WorldSpaceCenter()
					local phys = self:GetPhysicsObject()
					if IsValid(phys) then
						phys:SetVelocity((target_pos - pos):GetNormalized() * 1000)
					end

					if pos:DistToSqr(target_pos) <= 10000 then
						SafeRemoveEntity(self)
						GiveCandy(target, 1)
					end
				end

				local phys = candy:GetPhysicsObject()
				if IsValid(phys) then
					phys:EnableCollisions(false)
					phys:EnableGravity(false)
				end
			end)
		else
			if not CreateCandy then return end

			local candy_count = math.random(0, 3)
			if candy_count <= 0 then return end

			for _ = 1, candy_count do
				local candy = CreateCandy(npc:WorldSpaceCenter(), Angle(0, 0, 0))
				local phys = candy:GetPhysicsObject()
				if IsValid(phys) then
					phys:SetVelocity(VectorRand() * 150)
				end
			end
		end
	end)

	local headcrab_classes = {
		npc_headcrab = true,
		npc_headcrab_black = true,
		npc_headcrab_fast = true,
		npc_headcrab_poison = true,
	}
	hook.Add("OnEntityCreated", TAG, function(ent)
		if not is_halloween then return end
		if not headcrab_classes[ent:GetClass()] then return end

		-- cant do it right away, its too early
		timer.Simple(1, function()
			if not IsValid(ent) then return end
			if ent.CPPIGetOwner and IsValid(ent:CPPIGetOwner()) then return end
			if #MTA.BadPlayers == 0 then return end

			local target = MTA.BadPlayers[math.random(#MTA.BadPlayers)]
			if IsValid(target) then
				MTA.SetupCombine(ent, target, MTA.BadPlayers)
			end

			table.insert(MTA.Combines, ent)
			ent:SetNWBool("MTACombine", true)
			ent.ms_notouch = true
			MTA.ToSpawn = math.max(0, MTA.ToSpawn - 1)
		end)
	end)

	hook.Add("MTADisplayJoinPanel", TAG, function()
		if is_halloween then return false end
	end)

	hook.Add("MTAMobileEMPShouldDamage", TAG, function(ply, ent)
		if not is_halloween then return end
		if headcrab_classes[ent:GetClass()] then return true end
	end)

	local function create_badge()
		if not MetaBadges then return end

		local levels = {
			default = {
				title = "Zombie Massacre",
				description = "This tracks how much of a mess you've made against hordes of zombies"
			}
		}

		MetaBadges.RegisterBadge("zombie_massacre", {
			basetitle = "Zombie Massacre",
			levels = levels,
			level_interpolation = MetaBadges.INTERPOLATION_FLOOR
		})
	end

	hook.Add("InitPostEntity", TAG, function()
		local succ, err = pcall(create_badge)
		if not succ then
			warn_log("Could not create badge:", err)
		end
	end)

	hook.Add("MTAWantedStateUpdate", TAG, function(ply, is_wanted)
		if is_wanted then return end
		update_badge(ply, ply.MTAMassacreCount or 1)
		ply.MTAMassacreCount = 0
	end)
end

if CLIENT then
	local songs = {
		"https://dl.dropboxusercontent.com/s/3yhyi3r516c452r/SIERRA%20TRAPPED.ogg",
		"https://dl.dropboxusercontent.com/s/rd59wk27r3cjg3o/TARIK%20BOUISFI%20EVIL%20GATEWAY.ogg"
	}
	hook.Add("MTAGetDefaultSong", TAG, function()
		if not is_halloween then return end
		local i = math.random(#songs)
		return songs[i], ("halloween_%d.dat"):format(i)
	end)
end