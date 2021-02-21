AddCSLuaFile()
AddCSLuaFile("mta_libs/far_combine.lua")

-- when is that going to get added ???
AddCSLuaFile("metalog_handlers/ml_console_printer.lua")
AddCSLuaFile("includes/modules/metalog.lua")

pcall(require, "metalog")
pcall(include, "autorun/translation.lua")
local L = translation and translation.L or function(s) return s end

local is_refresh_lua = _G.MTA ~= nil and _G.MTA.Reset ~= nil
if is_refresh_lua then
	_G.MTA.Reset()
end

local tag = "mta"
local MTA = _G.MTA or {}
_G.MTA = MTA

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

function MTA.Print(...)
	if not metalog then
		default_log(...)
		return
	end

	metalog.info("MTA", nil, ...)
end

function MTA.Reset()
	MTA.Print("state was reset")
	if SERVER then
		timer.Remove(tag)
		MTA.RemoveCombines()
		for _, ply in pairs(player.GetAll()) do
			MTA.ResetPlayerFactor(ply, false)
		end
		timer.Create(tag, 0.3, 0, MTA.UpdateState)
	end

	hook.Run("MTAReset")
end

function MTA.InLobby(ply)
	if IS_MTA_GM then return true end
	if ply.InLobby then
		return ply:InLobby()
	end

	return false
end

local NET_WANTED_STATE = "MTA_WANTED_STATE"
local NET_SOUND_HACK = "MTA_SOUND_HACK"

if SERVER then
	resource.AddFile("materials/metabadges/criminal/s1/default.vmt")

	util.AddNetworkString(NET_WANTED_STATE)
	util.AddNetworkString(NET_SOUND_HACK)

	local mta_mode_lookup = {
		[0] = "Disabled",
		[1] = "Enabled",
		--[2] = "Party Mode Only",
		--[3] = "Except Party Mode"
	}

	local function mta_mode_help()
		local modes = {}
		for k, v in pairs(mta_mode_lookup) do
			table.insert(modes, ("%d - %s"):format(k, v))
		end

		return table.concat(modes, ", ")
	end

	local function map_has_broken_triggers()
		local max = 0
		for _, trigger in pairs(ents.FindByClass("lua_trigger")) do
			local mdl = trigger:GetModel()
				if mdl then
				if not mdl:match("^%*") then return false end

				local num = tonumber(mdl:match("^%*(%d+)")) or 0
				if num > max then
					max = num
				end
			end
		end

		return max >= 256
	end

	local MTA_MODE = CreateConVar("mta_mode", "1", FCVAR_ARCHIVE, "Changes the mode for MTA: " .. mta_mode_help())
	cvars.RemoveChangeCallback(MTA_MODE:GetName(), "mta")
	cvars.AddChangeCallback(MTA_MODE:GetName(), function(old_value)
		local cur_value = MTA_MODE:GetInt()
		if cur_value == tonumber(old_value) then return end

		if map_has_broken_triggers() then
			warn_log("Blocked MTA mode change, the map is broken")
			MTA_MODE:SetInt(0)
			return
		end

		MTA.Reset()
		MTA.Print(mta_mode_lookup[cur_value] or "Disabled")
	end, "mta")

	local function vargs_join(...)
		local ret = ""
		for _, arg in pairs({ ... }) do
			ret = ret .. tostring(arg)
		end

		return ret
	end

	local print_header_col = Color(250, 58, 60)
	function MTA.ChatPrint(ply, ...)
		if EasyChat then
			EasyChat.PlayerAddText(ply, print_header_col, "[MTA] ", color_white, ...)
		else
			local msg = vargs_join(...)
			ply:ChatPrint("[MTA] " .. msg)
		end
	end

	function MTA.IsEnabled()
		local lobby_party = GetConVar("ms_lobby_party")
		if lobby_party and lobby_party:GetBool() then return false end

		local mode = MTA_MODE:GetInt()
		if mode == 0 then return false end
		if mode == 1 then return true end

		--local lobby_party = GetConVar("ms_lobby_party")
		--if mode == 2 and lobby_party and lobby_party:GetBool() then return true end
		--if mode == 3 and not (lobby_party and lobby_party:GetBool()) then return true end

		return false
	end

	function MTA.IsOptedOut(ply)
		if not MTA_CONFIG.core.CanOptOut then return false end
		if banni and banni.isbanned(ply) then return true end
		return ply:GetInfoNum("mta_opt_out", 0) ~= 0
	end

	MTA.MAX_COMBINES = MTA_CONFIG.core.MaxCombines
	MTA.MAX_HELIS = MTA_CONFIG.core.MaxHelis
	MTA.ESCAPE_TIME = MTA_CONFIG.core.EscapeTime

	MTA.FarCombine = MTA.FarCombine or function() return false, "did not load \'far_combine\'" end
	MTA.SetupCombine = MTA.SetupCombine or function() return false, "did not load \'far_combine\'" end
	MTA.ConstrainPlayer = MTA.ConstrainPlayer or function() return false, "did no load \'wanted_constraints\'" end
	MTA.ReleasePlayer = MTA.ReleasePlayer or function() return false, "did no load \'wanted_constraints\'" end
	MTA.SpawnHelicopter = MTA.SpawnHelicopter or function() return false, "did no load \'heli_attack\'" end

	MTA.ToSpawn = 0
	MTA.Combines = {}
	MTA.HelicopterCount = 0
	MTA.BadPlayers = {}
	MTA.Factors = {}
	MTA.Coeficients = MTA_CONFIG.core.Coeficients

	local function remove_ent_from_table(ent, tbl)
		for k, v in pairs(tbl) do
			if v:EntIndex() == ent:EntIndex() then
				table.remove(tbl, k)
				return true
			end
		end

		return false
	end

	function MTA.IsWanted(ply)
		return ply.MTABad or false
	end

	function MTA.RemoveCombines()
		MTA.ToSpawn = 0
		for _, combine in ipairs(MTA.Combines) do
			SafeRemoveEntity(combine)
		end
		MTA.Combines = {}
		MTA.HelicopterCount = 0
	end

	local function dont_transmit_combine(combine)
		local combine_ents = {}
		table.insert(combine_ents, combine)
		table.Add(combine_ents, combine:GetChildren())

		local wep = combine:GetActiveWeapon()
		if IsValid(wep) then
			table.Add(combine_ents, wep)
		end

		local plys = player.GetAll()
		for _, ent in ipairs(combine_ents) do
			for _, ply in ipairs(plys) do
				if MTA.IsOptedOut(ply) then
					ent:SetPreventTransmit(ply, true)
				end
			end
		end
	end

	local spawning = 0
	local spawn_fails = {}
	local spawn_fail_reps = 0
	local function combine_spawn_callback(combine)
		if not IsValid(combine) then return end

		if #MTA.BadPlayers == 0 or not util.IsInWorld(combine:GetPos()) then
			spawning = spawning - 1
			SafeRemoveEntity(combine)
			return
		end

		table.insert(MTA.Combines, combine)
		combine:SetNWBool("MTACombine", true)
		combine.ms_notouch = true
		dont_transmit_combine(combine)

		MTA.ToSpawn = MTA.ToSpawn - 1
		spawning = spawning - 1
	end

	local combine_types = {
		metrocops = function()
			local npc = ents.Create("npc_metropolice")
			npc:SetKeyValue("additionalequipment", math.random() > 0.5 and "weapon_pistol" or "weapon_stunstick")
			npc:SetKeyValue("manhacks", tostring(math.random(0, 2)))
			return npc
		end,
		soldiers = function() --  this includes shotgunners
			local npc = ents.Create("npc_combine_s")
			npc:SetKeyValue("additionalequipment", math.random() < 0.25 and "weapon_shotgun" or "weapon_smg1")
			return npc
		end,
		elites = function()
			local npc = ents.Create("npc_combine_s")
			npc:SetKeyValue("additionalequipment", "weapon_ar2")
			npc:SetModel("models/combine_super_soldier.mdl")
			return npc
		end,
		shotgunners = function()
			local npc = ents.Create("npc_combine_s")
			npc:SetKeyValue("additionalequipment", "weapon_shotgun")
			return npc
		end,
	}

	function MTA.ManagedSpawnHelicopter(target)
		local succ, ret = MTA.SpawnHelicopter(target)
		if not succ then
			return false, ("helicopter could not spawn: %s"):format(ret)
		end

		MTA.SetupCombine(ret, target, MTA.BadPlayers)

		table.insert(MTA.Combines, ret)
		ret:SetNWBool("MTACombine", true)
		ret.ms_notouch = true
		MTA.ToSpawn = MTA.ToSpawn - 1
		MTA.HelicopterCount = MTA.HelicopterCount + 1

		return true, ret
	end

	function MTA.TrySpawnCombine(target, pos)
		if not IsValid(target) then return false, "bad target" end
		local wanted_lvl = math.ceil((MTA.Factors[target] or 0) / 10)

		-- under 10 -> only metrocops
		local spawn_function = combine_types.metrocops

		-- 10 to 60 -> metrocops and soldiers that become more and more common
		if wanted_lvl < 60 and wanted_lvl >= 10 then
			spawn_function = math.random(0, 60) <= (wanted_lvl + 20) and combine_types.soldiers or combine_types.metrocops

		-- 60 - 80 -> only elites
		elseif wanted_lvl >= 60 and wanted_lvl < 80 then
			spawn_function = combine_types.elites

		-- 80 - inf -> elites and shotgunners
		elseif wanted_lvl >= 80 then
			if IS_MTA_GM and MTA.HelicopterCount < MTA.MAX_HELIS then
				local succ, ret = MTA.ManagedSpawnHelicopter(target)
				if succ then return true end
				if not succ then warn_log(ret) end
			end

			spawn_function = math.random(1, 5) == 1 and combine_types.shotgunners or combine_types.elites
		end

		-- TODO: Helicopters n shit ?

		return MTA.FarCombine(target, MTA.BadPlayers, spawn_function, combine_spawn_callback, pos)
	end

	function MTA.SpawnCombine(target)
		local spawning_wait_count = math.max(spawning, 0)
		if (MTA.ToSpawn - spawning_wait_count) < 1 then return end
		if (#MTA.Combines + spawning_wait_count) >= MTA.MAX_COMBINES then return end
		if #MTA.BadPlayers == 0 then return end

		local succ, ret = MTA.TrySpawnCombine(target)
		if succ then
			spawning = spawning + 1
		else
			local reason = ret or "???"
			spawn_fail_reps = spawn_fail_reps + 1
			spawn_fails[reason] = true

			hook.Run("MTASpawnFail", spawn_fail_reps, reason, target)

			timer.Create("MTASpawnFails", 5, 1, function()
				local fail_reason_display = table.concat(table.GetKeys(spawn_fails), " & ")
				warn_log(("Failed to spawn combines %d times: %s"):format(spawn_fail_reps, fail_reason_display))

				spawn_fails = {}
				spawn_fail_reps = 0
			end)
		end
	end

	function MTA.HasCoeficients(ent)
		if not IsValid(ent) then return false end

		if MTA.Coeficients[ent:GetClass()] then
			return true
		end

		return false
	end

	function MTA.ProcessPlayerFactor(ply)
		local factor = MTA.Factors[ply] or 0
		if factor < 1 then return end

		if not ply.MTABad then
			table.insert(MTA.BadPlayers, ply)
			ply.MTABad = true

			hook.Run("MTAWantedStateUpdate", ply, true)
			net.Start(NET_WANTED_STATE)
			net.WriteEntity(ply)
			net.WriteBool(true)
			net.Broadcast()

			local timer_name = ("MTACombineSpawn_%d"):format(ply:EntIndex())
			timer.Create(timer_name, 0.3, 0, function()
				if not IsValid(ply) then
					timer.Remove(timer_name)
					return
				end

				MTA.SpawnCombine(ply)
			end)
			MTA.ConstrainPlayer(ply, "Wanted by MTA")
			MTA.Print(tostring(ply) .. " is now a criminal")
		end

		local count = #MTA.Combines
		local base_divider = 3
		local count_to_spawn = IS_MTA_GM
			and math.max(1, math.floor(factor / 10 / base_divider))
			or math.max(1, math.floor(factor / 2))

		if count >= 1 then
			if count < factor then -- spawn remaining combines
				MTA.ToSpawn = math.min(MTA.MAX_COMBINES, count_to_spawn - count)
			end
		else
			MTA.ToSpawn = count_to_spawn
		end
	end

	function MTA.UpdatePlayerBadge(ply, factor)
		local succ, err = pcall(function()
			if MetaBadges and factor >= 1 then
				local new_level = math.Clamp(math.ceil(factor / 10), 1, 2000)
				MetaBadges.UpgradeBadge(ply, "criminal", new_level)
			end
		end)

		if not succ then
			warn_log("Failed to update badge for:", ply, err)
		end
	end

	function MTA.ResetPlayerFactor(ply, should_pay, is_death)
		local old_factor = MTA.Factors[ply] or 0
		local max_factor = ply.MTAMaxSessionFactor or 0
		MTA.Factors[ply] = nil -- under 1 of factor

		ply.MTALastFactorIncrease = nil
		ply.MTAMaxSessionFactor = nil
		ply.MTAPreventEscape = 0
		ply:SetNWInt("MTAFactor", 0)

		if not ply.MTABad then return end

		MTA.ReleasePlayer(ply)
		MTA.Print(tostring(ply) .. " is now a normal citizen")

		if should_pay and old_factor > 0 then
			local cur_coins = ply.GetCoins and ply:GetCoins() or 0
			local wanted_lvl = math.ceil(old_factor / 10)
			local to_pay = cur_coins > 1000000 and math.ceil((cur_coins / 10000) * wanted_lvl) or wanted_lvl * 1000
			if ply.PayCoins and not ply:PayCoins(to_pay, "MTA Criminal Fee") then
				if cur_coins > 0 then
					ply:PayCoins(cur_coins, "MTA Criminal Fee")
				end

				local hell_pos = landmark and landmark.get("hll") or nil
				if hell_pos then
					ply:SetPos(hell_pos)
					MTA.ChatPrint(ply, "Not enough money to pay the fee! To hell you go!")
				end
			end

			hook.Run("MTAPlayerFailed", ply, max_factor, wanted_lvl, is_death)
		end

		hook.Run("MTAWantedStateUpdate", ply, false)
		net.Start(NET_WANTED_STATE)
		net.WriteEntity(ply)
		net.WriteBool(false)
		net.Broadcast()

		local timer_name = ("MTACombineSpawn_%d"):format(ply:EntIndex())
		timer.Remove(timer_name)

		ply.MTABad = nil
		local removed = remove_ent_from_table(ply, MTA.BadPlayers)
		if not removed then
			warn_log(("failed to reset citizenship of %s properly, cleaning up data."):format(tostring(ply)))
			timer.Simple(1, function()
				for i, ply in pairs(MTA.BadPlayers) do
					if not ply.MTABad or not IsValid(ply) then
						table.remove(MTA.BadPlayers, i)
					end
				end
			end)
		end

		if #MTA.BadPlayers == 0 then
			MTA.RemoveCombines()
		end

		MTA.UpdatePlayerBadge(ply, old_factor)
	end

	function MTA.DisallowPlayerEscape(ply)
		ply.MTAPreventEscape = (ply.MTAPreventEscape or 0) + 1
	end

	function MTA.AllowPlayerEscape(ply)
		ply.MTAPreventEscape = math.max((ply.MTAPreventEscape or 0) - 1, 0)
	end

	function MTA.CanPlayerEscape(ply)
		return (ply.MTAPreventEscape or 0) <= 0
	end

	function MTA.IncreasePlayerFactor(ply, amount)
		if not MTA.IsEnabled() then return end

		local factor = (MTA.Factors[ply] or 0) + math.max(0, amount)
		MTA.Factors[ply] = factor

		ply.MTALastFactorIncrease = CurTime()

		local old_max_factor = ply.MTAMaxSessionFactor or 0
		local processed_factor = factor < 1 and 0 or math.ceil(factor / 10)
		ply.MTAMaxSessionFactor = processed_factor > old_max_factor and processed_factor or old_max_factor
		ply:SetNWInt("MTAFactor", processed_factor)
		hook.Run("MTAPlayerWantedLevelIncreased", ply, processed_factor)

		MTA.ProcessPlayerFactor(ply)
	end

	function MTA.DecreasePlayerFactor(ply, amount)
		local old_factor = MTA.Factors[ply] or 0
		local factor = math.max(old_factor - amount, 0)
		MTA.Factors[ply] = factor

		local processed_factor = factor < 1 and 0 or math.ceil(factor / 10)
		ply:SetNWInt("MTAFactor", processed_factor)
		hook.Run("MTAPlayerWantedLevelDecreased", ply, processed_factor)

		if factor < 1 then
			hook.Run("MTAPlayerEscaped", ply, ply.MTAMaxSessionFactor or 0)
			MTA.ResetPlayerFactor(ply, false, false)
		end

		MTA.UpdatePlayerBadge(ply, old_factor)
	end

	-- With this numbers the maximum time to escape at lvl 1000 should be
	-- about 1mins 45 and 1min for lvl 10. Keep in mind these levels are hidden
	-- and to get the displayed levels you should divide them by 10.
	local BASE_DECREASE_FACTOR = MTA_CONFIG.core.BaseDecreaseFactor
	local DECREASE_DIVIDER = MTA_CONFIG.core.DecreaseDivider -- increase to slow down escape, increase to speed up escape
	function MTA.UpdateState()
		local time = CurTime()
		for _, ply in ipairs(MTA.BadPlayers) do
			if ply:IsValid() then
				if not MTA.CanPlayerEscape(ply) then
					-- refresh the "player factor state", since we dont want them to escape
					MTA.ProcessPlayerFactor(ply)
				elseif (time - (ply.MTALastFactorIncrease or 0)) >= MTA.ESCAPE_TIME then
					local internal_factor = ply:GetNWInt("MTAFactor") * 10
					local decrease = BASE_DECREASE_FACTOR + math.exp(internal_factor / DECREASE_DIVIDER)
					MTA.DecreasePlayerFactor(ply, decrease)
				end
			end
		end
	end

	local function create_badge()
		if not MetaBadges then return end
		local levels = {
			default = {
				title = L "Criminal",
				description = L "This tracks how bad of a criminal you have been so far."
			}
		}

		local steps = {
			{ Stages = 10, Title = L "Thief" },
			{ Stages = 20, Title = L "Thug" },
			{ Stages = 40, Title = L "Gangster" },
			{ Stages = 80, Title = L "Godfather" },
			{ Stages = 160, Title = L "Warlord" },
			{ Stages = 320, Title = L "War Criminal" },
			{ Stages = 369, Title = L "Evil Mastermind" },
			{ Stages = 501, Title = L "Literally Hitler" },
			{ Stages = 500, Title = L "Satan" },
		}

		do
			local level = 1

			for _, step in ipairs(steps) do
				levels[level] = {
					title = step.Title,
					description = levels.default.description,
				}
				level = level + step.Stages
			end
		end

		MetaBadges.RegisterBadge("criminal", {
			basetitle = "Criminal",
			levels = levels,
			level_interpolation = MetaBadges.INTERPOLATION_FLOOR
		})
	end

	local blocked_ents = { "mta_vault", "mta_jukebox", "mta_skills_computer" }
	local function spawn_lobby_persistent_ents()
		if not MTA_CONFIG.core.UseMapData then return end

		-- we need to handle it ourselves because
		-- ms.persist doesnt handle anything but saving and pasting
		if ms and ms.persist and ms.persist.paste then
			for _, ent in ipairs(ents.GetAll()) do
				if ent.__persist_page == "lobby_mta" then
					SafeRemoveEntity(ent)
				end
			end

			ms.persist.paste("lobby_mta", "lobby_3", Angle())
			if IS_MTA_GM then
				for _, ent in ipairs(ents.GetAll()) do
					if blocked_ents[ent:GetClass()] then
						SafeRemoveEntity(ent)
					end
				end
			end
		end
	end

	local function trigger_hurt_fix()
		for _, trigger_hurt in ipairs(ents.FindByClass("trigger_hurt")) do
			trigger_hurt.MTAForceDamage = true
		end
	end

	function MTA.Initialize()
		-- this is done here, because only here will the proper nodegraph be available
		local far_combine, setup_combine = include("mta_libs/far_combine.lua")
		if not far_combine or not setup_combine then
			warn_log("Could not include far_combine.lua")
			return
		end

		MTA.FarCombine = far_combine
		MTA.SetupCombine = setup_combine

		local constrain_player, release_player = include("mta_libs/wanted_constraints.lua")
		if not constrain_player or not release_player then
			warn_log("Could not include wanted_constraints.lua")
			return
		end

		MTA.ConstrainPlayer = constrain_player
		MTA.ReleasePlayer = release_player

		local spawn_helicopter = include("mta_libs/heli_attack.lua")
		if not spawn_helicopter then
			warn_log("Could not include heli_attack.lua")
			return
		end

		MTA.SpawnHelicopter = spawn_helicopter

		timer.Create(tag, 0.3, 0, MTA.UpdateState)

		if aowl then
			aowl.AddCommand("resetmta", "Resets the state of meta police force in the lobby", MTA.Reset, "developers")

			local err_msg = "incorrect mode! " .. mta_mode_help()
			aowl.AddCommand("mtamode", "Sets the mode for MTA server-wide", function(caller, _, mode)
				mode = tonumber(mode)
				if not mode then return nil, err_msg end
				if not mta_mode_lookup[mode] then return nil, err_msg end

				MTA_MODE:SetInt(mode)
				MTA.ChatPrint(caller, "Changed MTA mode to: " .. mta_mode_lookup[mode] or "Disabled")
			end, "developers")
		end

		local succ, err = pcall(create_badge)
		if not succ then
			warn_log("Could not create badge:", err)
		end

		spawn_lobby_persistent_ents()
		trigger_hurt_fix()

		if map_has_broken_triggers() then
			warn_log("BROKEN TRIGGERS DETECTED DISABLING")
			MTA_MODE:SetInt(0)
		end
	end

	function MTA.ShouldIncreasePlayerFactor(ply, skip_alive)
		if not IsValid(ply) then return false end
		if ply.MTAIgnore then return false end
		if not ply:IsPlayer() then return false end
		if not skip_alive and not ply:Alive() then return false end
		if not MTA.InLobby(ply) then return false end
		if MTA.IsOptedOut(ply) then return false end

		-- metastruct ban system
		if banni and banni.isbanned(ply) then return false end

		-- hide n seek minigame
		if HnS and HnS.InGame(ply) then return false end

		return true
	end

	function MTA.ShouldConsiderEntity(ent)
		if not IsValid(ent) then return false end
		if ent.MTAIgnore then return false end
		if not MTA.HasCoeficients(ent) then return false end

		if ent:IsPlayer() then
			if not ent:Alive() then return false end
			-- dont count banned players
			if banni and banni.isbanned(ent) then return false end
		end

		-- dont count things spawned by players
		if ent.CPPIGetOwner and IsValid(ent:CPPIGetOwner()) then return false end

		return true
	end

	local whitelist = {}
	for _, class_name in pairs(MTA_CONFIG.core.DamageWhitelist) do
		whitelist[class_name] = true
	end

	hook.Add("EntityTakeDamage", tag, function(ent, dmg_info)
		if dmg_info:IsFallDamage() then return end

		-- dont account damage by yourself
		local atck = dmg_info:GetAttacker()
		if ent:GetNWBool("MTACombine") then
			-- dont let combines hurt each others
			if atck:GetNWBool("MTACombine") then return true end

			-- dont let opted out players damage the npcs
			if type(atck) == "Player" and MTA.IsOptedOut(atck) then
				return true
			end
		end

		if ent == atck then return end
		if not MTA.ShouldConsiderEntity(ent) then return end
		if not MTA.ShouldIncreasePlayerFactor(atck) then return end

		if Instances and not Instances.ShouldInteract(atck, ent) then
			return true
		end

		local inflictor = dmg_info:GetInflictor()
		if isentity(inflictor) and IsValid(inflictor) then
			if inflictor.ConcussionBall then return true end
			if type(inflictor) ~= "Player"
				and not inflictor:IsWeapon()
				and not inflictor:IsVehicle()
			then
				if not IS_MTA_GM and not whitelist[inflictor:GetClass()] then
					return true
				end
			end
		end

		-- prevent players from losing their progress just because they accidentally hit a shop npc
		if type(atck) == "Player" and atck.MTABad and ent:GetClass() == "lua_npc" then
			return true
		end

		local coef_data = MTA.Coeficients[ent:GetClass()]
		MTA.IncreasePlayerFactor(atck, dmg_info:GetDamage() >= ent:Health() and coef_data.kill_coef or coef_data.damage_coef)
	end)

	local function ensure_combine_removal(npc)
		if npc:GetClass() == "npc_helicopter" then
			MTA.HelicopterCount = math.max(MTA.HelicopterCount - 1, 0)
		end

		local removed = remove_ent_from_table(npc, MTA.Combines)
		if not removed then
			timer.Simple(1, function()
				for i, combine in pairs(MTA.Combines) do
					if not IsValid(combine) then
						table.remove(MTA.Combines, i)
					end
				end
			end)
		end
	end

	local function combine_drops(npc)
		local dissolving = false
		for _, ent in ipairs(npc:GetChildren()) do
			if ent:GetClass() == "env_entity_dissolver" then
				dissolving = true
				break
			end
		end

		local wep = npc:GetActiveWeapon()
		if IsValid(wep) and not dissolving then
			local dropped_wep = ents.Create(wep:GetClass())
			dropped_wep.lobbyok = true
			dropped_wep.unrestricted_gun = true
			dropped_wep.PhysgunDisabled = true
			dropped_wep.dont_televate = true
			dropped_wep:SetPos(npc:WorldSpaceCenter())
			dropped_wep:Spawn()
			dropped_wep:SetClip1(dropped_wep:GetMaxClip1() / 2)

			SafeRemoveEntity(wep)
			timer.Simple(5, function()
				if not IsValid(dropped_wep) then return end
				local parent = dropped_wep:GetParent()
				if IsValid(parent) and parent:IsPlayer() then return end

				dropped_wep:Remove()
			end)
		end

		local health_vial = ents.Create(math.random(0, 100) >= 75 and "item_healthkit" or "item_healthvial")
		health_vial.lobbyok = true
		health_vial.PhysgunDisabled = true
		health_vial.dont_televate = true
		health_vial:SetPos(npc:WorldSpaceCenter())
		health_vial:Spawn()
		SafeRemoveEntityDelayed(health_vial, 5)

		if math.random(0, 100) <= 30 then
			local armor_battery = ents.Create("item_battery")
			armor_battery.lobbyok = true
			armor_battery.PhysgunDisabled = true
			armor_battery.dont_televate = true
			armor_battery:SetPos(npc:WorldSpaceCenter())
			armor_battery:Spawn()
			SafeRemoveEntity(armor_battery, 5)
		end
	end

	hook.Add("OnNPCKilled", tag, function(npc)
		if not npc:GetNWBool("MTACombine") then return end

		combine_drops(npc)
		ensure_combine_removal(npc)
	end)

	hook.Add("EntityRemoved", tag, function(ent) -- can be removed by other factors
		if ent:IsNPC() and ent:GetNWBool("MTACombine") then
			ensure_combine_removal(ent)
		end
	end)

	hook.Add("PlayerDisconnected", tag, function(ply) MTA.ResetPlayerFactor(ply, true, false) end)
	hook.Add("PlayerDeath", tag, function(ply) MTA.ResetPlayerFactor(ply, true, true) end)
	hook.Add("PlayerSilentDeath", tag, function(ply) MTA.ResetPlayerFactor(ply, true, true) end)

	hook.Add("InstanceChanged", tag, function(ent, id)
		if not ent:IsPlayer() then return end
		if id ~= 0 then
			MTA.ResetPlayerFactor(ent, true, false)
		end
	end)

	hook.Add("PlayerLeftTrigger", tag, function(ply)
		timer.Simple(1, function()
			if not IsValid(ply) then return end
			if not MTA.InLobby(ply) then
				MTA.ResetPlayerFactor(ply, true, false)
			end
		end)
	end)

	hook.Add("PlayerShouldTakeDamage", tag, function(ply, atck)
		if not IS_MTA_GM and atck:IsPlayer() and atck.MTABad and ply.MTABad then
			return false
		end

		if atck.MTAForceDamage and ply.MTABad then
			ply.MTALastFactorIncrease = CurTime()
			return true
		end

		if atck:GetNWBool("MTACombine") then
			if not ply.MTABad then return false end

			ply.MTALastFactorIncrease = CurTime()

			if ply:Armor() > 100 then
				ply:SetArmor(100)
			end

			if ply:Health() > 100 then
				ply:SetHealth(100)
			end

			return true
		end
	end)

	hook.Add("OnEntityCreated", tag, function(ent)
		if ent:GetClass() ~= "npc_manhack" then return end

		-- cant do it right away, its too early
		timer.Simple(1, function()
			if not IsValid(ent) then return end
			if ent.CPPIGetOwner and IsValid(ent:CPPIGetOwner()) then return end

			for _, nearby_ent in pairs(ents.FindInSphere(ent:GetPos(), 400)) do
				if nearby_ent:GetNWBool("MTACombine") then
					local target = nearby_ent:GetEnemy()
					if IsValid(target) then
						MTA.SetupCombine(ent, target, MTA.BadPlayers)
					end

					table.insert(MTA.Combines, ent)
					ent:SetNWBool("MTACombine", true)
					ent.ms_notouch = true
					MTA.ToSpawn = MTA.ToSpawn - 1

					break
				end
			end
		end)
	end)

	local function should_sound_hack(ent)
		if whitelist[ent:GetClass()] then return true end
		if ent:GetNWBool("MTACombine") then return true end
		if ent:GetClass() == "meta_core" and ent.IsThrownCore then return true end

		if not ent:IsPlayer() then
			if ent.CPPIGetOwner and IsValid(ent:CPPIGetOwner()) then
				ent = ent:CPPIGetOwner()
			elseif ent:IsWeapon() and IsValid(ent:GetOwner()) then
				ent = ent:GetOwner()
			elseif IsValid(ent:GetParent()) then
				ent = ent:GetParent()
			end
		end

		if ent:GetNWBool("MTACombine") then return true end -- check twice in-game of parent
		if ent:IsPlayer() and MTA.IsWanted(ent) then return true end

		return false
	end

	hook.Add("EntityEmitSound", tag, function(data)
		if not IsValid(data.Entity) then return end

		local ent = data.Entity
		if should_sound_hack(ent) then
			local plys = {}
			for _, ply in ipairs(player.GetAll()) do
				if MTA.InLobby(ply) and not MTA.IsOptedOut(ply) then
					table.insert(plys, ply)
				end
			end

			net.Start(NET_SOUND_HACK, true)
			net.WriteTable(data)
			net.Send(plys)
			return false
		end
	end)

	hook.Add("InitPostEntity", tag, MTA.Initialize)
	hook.Add("PostCleanupMap", tag, spawn_lobby_persistent_ents)

	if is_refresh_lua then
		MTA.Initialize()
	end
end

if CLIENT then
	include("mta_libs/far_combine.lua")

	local MTA_OPT_OUT = CreateClientConVar("mta_opt_out", "0", true, true, "Disable criminal events in the lobby for yourself")
	local MTA_SHOW_WANTEDS = CreateClientConVar("mta_show_wanteds", "1", true, false, "Displays other wanted players")
	cvars.AddChangeCallback("mta_opt_out", function(_, _, new)
		if tobool(new) and LocalPlayer():GetNWInt("MTAFactor", 0) > 0 then -- cba to network a reset fuck this
			RunConsoleCommand("kill")
		end
	end)

	function MTA.IsOptedOut()
		if not MTA_CONFIG.core.CanOptOut then return false end
		if banni and banni.isbanned(LocalPlayer()) then return true end
		return MTA_OPT_OUT:GetBool()
	end

	function MTA.IsWanted()
		return LocalPlayer():GetNWInt("MTAFactor") >= 1
	end

	surface.CreateFont("MTAIndicatorFont", {
		font = IS_MTA_GM and "Orbitron" or "Arial",
		size = 20,
		weight = 800,
		shadow = false,
		extended = true,
	})

	surface.CreateFont("MTALargeFont", {
		font = IS_MTA_GM and "Orbitron" or "Arial",
		size = 32,
		weight = 600,
		shadow = false,
		extended = true,
	})

	surface.CreateFont("MTASmallFont", {
		font = IS_MTA_GM and "Orbitron" or "Arial",
		size = 13,
		weight = 600,
		shadow = false,
		extended = true,
	})

	local black_color = Color(0, 0, 0, 150)
	local orange_color = Color(244, 135, 2)
	local red_color = Color(255, 0, 0)
	local white_color = Color(255, 255, 255)

	function MTA.HighlightPosition(pos, text, color)
		if MTA.IsOptedOut() then return end

		local screen_pos = pos:ToScreen()
		if not screen_pos.visible then return end

		local time = RealTime()
		local matrix, translation = Matrix(), Vector(screen_pos.x, screen_pos.y)
		local size = 1.5 + (math.sin(time * 4) / 2)
		local scale, angle = Vector(size, size, size), Angle(0, (time * 100) % 360, 0)

		matrix:Translate(translation)
		matrix:SetAngles(angle)
		matrix:Scale(scale)
		matrix:Translate(-translation)

		surface.SetDrawColor(color)

		cam.PushModelMatrix(matrix)
			surface.DrawOutlinedRect(screen_pos.x - 25, screen_pos.y - 25, 50, 50)
			surface.DrawOutlinedRect(screen_pos.x - 20, screen_pos.y - 20, 40, 40)
		cam.PopModelMatrix()

		surface.SetTextColor(color)
		surface.SetFont("MTAIndicatorFont")
		local tw, th = surface.GetTextSize(text)
		local tx, ty = screen_pos.x - (tw / 2), screen_pos.y - (th / 2)

		surface.SetDrawColor(black_color)
		surface.DrawRect(tx - 5, ty - 5, tw + 10, th + 10)

		surface.SetTextPos(tx, ty)
		surface.DrawText(text)
	end

	function MTA.HighlightEntity(ent, text, color)
		MTA.HighlightPosition(ent:WorldSpaceCenter(), text, color)
	end

	local MIN_DIST_TO_SHOW = 300
	local DIST_TO_ENT = 50
	function MTA.ManagedHighlightEntity(ent, text, color)
		if CurTime() >= (ent.NextHighlightCheck or 0) then
			ent.NextHighlightCheck = CurTime() + 1

			local lp = LocalPlayer()
			if lp:WorldSpaceCenter():Distance(ent:WorldSpaceCenter()) > MIN_DIST_TO_SHOW then
				ent.ShouldHighlight = false
				return
			end

			local tr = util.TraceLine({
				start = lp:EyePos(),
				endpos = ent:WorldSpaceCenter(),
				filter = lp,
			})
			if tr.Entity ~= ent then
				ent.ShouldHighlight = tr.HitWorld and tr.HitPos:Distance(ent:WorldSpaceCenter()) <= DIST_TO_ENT or false
				return
			end

			ent.ShouldHighlight = true
		end

		if ent.ShouldHighlight then
			MTA.HighlightEntity(ent, text, color)
		end
	end

	local registered_ents = {}
	function MTA.RegisterEntityForHighlight(ent, text, color)
		registered_ents[ent] = {
			Text = text,
			Color = color,
		}
	end

	function MTA.GetBindKey(binding)
		local bind = input.LookupBinding(binding, true)
		if not bind then return end
		return bind:upper()
	end

	local function draw_instable_rect(x, y, w, h, neg, fill)
		local sign = neg and -1 or 1
		local matrix = Matrix()
		local time = SysTime()
		local size = 1 + (math.sin(time) / 100)
		local scale, angle = Vector(size, size, size), Angle(0, math.sin((time / 2) * sign) * 2, 0)
		local translation = Vector(x + w / 2, y + h / 2)

		matrix:Translate(translation)
		matrix:SetAngles(angle)
		matrix:Scale(scale)
		matrix:Translate(-translation)

		x = x + math.sin(time * sign)
		y = y + math.sin(time * sign)

		cam.PushModelMatrix(matrix)
			if fill then
				surface.DrawRect(x, y, w, h)
			else
				surface.DrawOutlinedRect(x, y, w, h, 1)
			end
		cam.PopModelMatrix()
	end

	local LOW_HEALTH = 30
	local function draw_hud()
		local lp = LocalPlayer()
		local health, armor = lp:Health(), lp:Armor()
		local scrw, scrh = ScrW(), ScrH()

		if health <= LOW_HEALTH then
			DrawMotionBlur(0.4, 0.8, 0.05)
			surface.SetDrawColor(0, 0, 0, 25)
			surface.DrawRect(0,0, scrw, scrh)
			local alpha = 10 + math.abs((math.sin(CurTime() * 3) * 100))
			surface.SetDrawColor(255, 0, 0, alpha)
			surface.DrawRect(0, 0, scrw, scrh)
		end

		surface.SetTextColor(white_color)
		surface.SetFont("MTALargeFont")
		local text = ("/// WANTED LEVEL %d ///"):format(LocalPlayer():GetNWInt("MTAFactor"))
		local tw, th = surface.GetTextSize(text)
		local pos_x, pos_y = scrw / 2 - tw / 2, (scrh / 2 - th / 2) - (450 * (scrh / 1080))
		surface.SetTextPos(pos_x, pos_y)

		surface.SetDrawColor(black_color)
		surface.DrawRect(pos_x - 10, pos_y - 10, tw + 20, th + 20)

		surface.SetDrawColor(orange_color)
		draw_instable_rect(pos_x - 10, pos_y - 10, tw + 20, th + 20, false)
		draw_instable_rect(pos_x - 10, pos_y - 10, tw + 20, th + 20, true)

		surface.DrawText(text)

		if not IS_MTA_GM then
			surface.SetFont("MTASmallFont")
			surface.SetDrawColor(health < LOW_HEALTH and red_color or orange_color)
			surface.SetTextColor(health < LOW_HEALTH and red_color or orange_color)
			surface.DrawRect(pos_x - 10, pos_y + th + 25, (tw / 100) * health, 5, true)
			surface.SetTextPos(pos_x + (tw / 100) * health, pos_y + th + 20)
			surface.DrawText(("%d HPs"):format(math.Clamp(health, 0, 100)))

			surface.SetDrawColor(orange_color)
			surface.SetTextColor(orange_color)
			surface.DrawRect(pos_x - 10, pos_y + th + 40, (tw / 100) * armor, 5, true)
			surface.SetTextPos(pos_x + (tw / 100) * armor, pos_y + th + 35)
			surface.DrawText(("%d SUIT"):format(math.Clamp(armor, 0, 100)))
		end

		hook.Run("MTAPaint", pos_x, pos_y, tw, th)
	end

	local hud_elements = {
		["CHudHealth"] = true,
		["CHudBattery"] = true
	}
	hook.Add("HUDShouldDraw", tag, function(element)
		if hud_elements[element] and MTA.IsWanted() then return false end
	end)

	hook.Add("HUDPaint", tag, function()
		for ent, draw_info in pairs(registered_ents) do
			if IsValid(ent) then
				MTA.ManagedHighlightEntity(ent, draw_info.Text, draw_info.Color)
			else
				registered_ents[ent] = nil
			end
		end

		if not MTA.IsWanted() then return end
		draw_hud()

		if not MTA_SHOW_WANTEDS:GetBool() then return end
		for _, ply in ipairs(player.GetAll()) do
			local ply_factor = ply:GetNWInt("MTAFactor")
			if ply_factor >= 1 and ply ~= LocalPlayer() then
				local text = ("/// WANTED LEVEL %d ///"):format(ply_factor)
				MTA.HighlightEntity(ply, text, orange_color)
			end
		end
	end)

	hook.Add("EntityEmitSound", tag, function(data)
		if not MTA.IsOptedOut() then return end
		if not MTA.InLobby(LocalPlayer()) then return end
		if not IsValid(data.Entity) then return end

		local ent = data.Entity
		if ent:IsWeapon() and IsValid(ent:GetParent()) then
			ent = ent:GetParent()
		end

		if ent:IsPlayer() and ent:GetNWInt("MTAFactor") >= 1 then return false end
		if ent:GetNWBool("MTACombine") then return false end
	end)

	if not IS_MTA_GM then
		hook.Add("MTAWantedStateUpdate", tag, function(ply, is_wanted)
			if is_wanted then return end
			if ply ~= LocalPlayer() then return end
			Derma_Query(
				"Looks like you're enjoying MTA, do you wish to join the dedicated MTA server? (we have guns, pvp and a gamemode :eyes:)",
				"MTA",
				"Join", function()
					RunConsoleCommand("aowl", "goto", "#3")
				end,
				"Remain here",
				function() end
			)
		end)
	end

	net.Receive(NET_WANTED_STATE, function()
		local ply = net.ReadEntity()
		local is_wanted = net.ReadBool()

		hook.Run("MTAWantedStateUpdate", ply, is_wanted)
	end)

	net.Receive(NET_SOUND_HACK, function()
		local data = net.ReadTable()
		if IsValid(data.Entity) and data.Entity ~= LocalPlayer() then
			data.Entity:EmitSound(data.SoundName, data.SoundLevel, data.Pitch,
				data.Volume, data.Channel, data.Flags, data.DSP)
		end
	end)

	local function dont_draw(ent)
		ent:SetRenderMode(RENDERMODE_NONE)
		ent:AddEffects(EF_NODRAW)
		ent:AddEffects(EF_NOSHADOW)
		ent:AddEffects(EF_NORECEIVESHADOW)
		ent:DrawShadow(false)
		ent:SetNoDraw(true)
		ent.RenderOverride = function() end

		for _, child in pairs(ent:GetChildren()) do
			dont_draw(child)
		end

		local wep = ent.GetActiveWeapon and ent:GetActiveWeapon()
		if IsValid(wep) then
			dont_draw(wep)
		end
	end

	local mta_classes = {
		npc_metropolice = true,
		npc_manhack = true,
		npc_combine_s = true
	}
	local debug_white = Material("models/debug/debugwhite")
	local function mta_render_override(self)
		if MTA.IsWanted() and LocalPlayer():Health() <= LOW_HEALTH then
			cam.IgnoreZ(true)
				render.SetLightingMode(2)
					render.MaterialOverride(debug_white)
						self:DrawModel()
					render.MaterialOverride()
				render.SetLightingMode(0)
			cam.IgnoreZ(false)
		else
			self:DrawModel()
		end
	end

	hook.Add("OnEntityCreated", tag, function(ent)
		if not MTA.IsOptedOut() then
			if mta_classes[ent:GetClass()] then
				ent.RenderOverride = mta_render_override
			end

			return
		end

		timer.Simple(0.5, function()
			if not IsValid(ent) then return end
			if not ent:GetNWBool("MTACombine") then return end
			dont_draw(ent)
		end)
	end)

	local function is_mta_ent(ent)
		if not isentity(ent) then return false end
		if not IsValid(ent) then return false end

		if ent:GetNWBool("MTACombine") then return true end
		if ent:GetNWString("MTABountyHunter") ~= "" then return true end
		if ent:GetNWInt("MTAFactor") > 0 then return true end
		if ent:GetNWBool("MTABomb") then return true end

		return false
	end

	-- funny hook that can pass nil because death notices are gay and will always be
	-- you CANNOT change my mind :)
	hook.Add("DeathNotice", tag, function(atck, inflictor, target)
		if is_mta_ent(atck) or is_mta_ent(target) or is_mta_ent(inflictor) then
			if MTA.IsOptedOut() then return false end
			if not MTA.InLobby(LocalPlayer()) then return false end
		end
	end)
end

for _, f in pairs((file.Find("mta_modules/*.lua", "LUA"))) do
	local path = "mta_modules/" .. f
	AddCSLuaFile(path)
	include(path)
end