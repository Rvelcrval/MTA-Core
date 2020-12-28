AddCSLuaFile()

pcall(include, "autorun/translation.lua")
local L = translation and translation.L or function(s) return s end

local is_refresh_lua = _G.MTA ~= nil
if is_refresh_lua then
	_G.MTA.Reset()
end

local tag = "mta"
local MTA = _G.MTA or {}
_G.MTA = MTA

function MTA.Print(...)
	Msg("[MTA] ")
	print(...)
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
	if ply.InLobby then
		return ply:InLobby()
	end

	return false
end

local NET_WANTED_STATE = "MTA_WANTED_STATE"

if SERVER then
	util.AddNetworkString(NET_WANTED_STATE)

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

	local blocked_maps = {
		gm_construct_m3_204 = true, -- broken triggers
		gm_construct_m3_207 = true, -- same
		gm_construct_m3_234 = true, -- same :)
	}

	local MTA_MODE = CreateConVar("mta_mode", "1", FCVAR_ARCHIVE, "Changes the mode for MTA: " .. mta_mode_help())
	cvars.RemoveChangeCallback(MTA_MODE:GetName(), "mta")
	cvars.AddChangeCallback(MTA_MODE:GetName(), function(old_value)
		local cur_value = MTA_MODE:GetInt()
		if cur_value == tonumber(old_value) then return end

		if cur_value ~= 0 and blocked_maps[game.GetMap()] then
			MTA.Print("Blocked MTA mode change, the map is blocked")
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
		return ply:GetInfoNum("mta_opt_out", 0) ~= 0
	end

	local MAX_COMBINES = 25
	local ESCAPE_TIME = 20 -- in seconds

	MTA.FarCombine = MTA.FarCombine or function() return false, "did not load \'far_combine\'" end
	MTA.SetupCombine = MTA.SetupCombine or function() return false, "did not load \'far_combine\'" end
	MTA.ConstrainPlayer = MTA.ConstrainPlayer or function() return false, "did no load \'wanted_constraints\'" end
	MTA.ReleasePlayer = MTA.ReleasePlayer or function() return false, "did no load \'wanted_constraints\'" end

	MTA.ToSpawn = 0
	MTA.Combines = {}
	MTA.BadPlayers = {}
	MTA.Factors = {}
	MTA.Coeficients = {
		lua_npc_wander = {
			damage_coef = 0.5,
			kill_coef = 1,
		},
		lua_npc = {
			damage_coef = 0.5,
			kill_coef = 1,
		},
		npc_combine_s = {
			damage_coef = 1,
			kill_coef = 1.5,
		},
		npc_metropolice = {
			damage_coef = 1,
			kill_coef = 1.5,
		},
		npc_manhack = {
			damage_coef = 0.75,
			kill_coef = 1,
		},
		player = {
			damage_coef = 0,
			kill_coef =  2.5,
		}
	}

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
	end

	local spawn_fails = {}
	local spawn_fail_reps = 0
	function MTA.SpawnCombine()
		if MTA.ToSpawn < 1 then return end
		if #MTA.Combines >= MAX_COMBINES then return end
		if #MTA.BadPlayers == 0 then return end

		local succ, ret = MTA.FarCombine(MTA.BadPlayers)
		if succ and IsValid(ret) then -- should never be NULL or nil but what do I know
			table.insert(MTA.Combines, ret)
			ret:SetNWBool("MTACombine", true)
			ret.ms_notouch = true

			MTA.ToSpawn = MTA.ToSpawn - 1
		else
			local reason = ret or "???"
			spawn_fail_reps = spawn_fail_reps + 1
			spawn_fails[reason] = true

			hook.Run("MTASpawnFail", spawn_fail_reps, reason)

			timer.Create("MTASpawnFails", 5, 1, function()
				local fail_reason_display = table.concat(table.GetKeys(spawn_fails), " & ")
				MTA.Print(("Failed to spawn combines %d times: %s"):format(spawn_fail_reps, fail_reason_display))

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

			MTA.ConstrainPlayer(ply, "Wanted by MTA")
			MTA.Print(tostring(ply) .. " is now a criminal")
		end

		local count = #MTA.Combines
		factor = math.max(0, math.floor(factor / 2))

		if count >= 1 then
			if count < factor then -- spawn remaining combines
				MTA.ToSpawn = math.min(MAX_COMBINES, factor - count)
			end
		else
			MTA.ToSpawn = factor
		end
	end

	function MTA.UpdatePlayerBadge(ply, factor)
		local succ, err = pcall(function()
			if MetaBadges and factor >= 1 then
				local new_level = math.Clamp(math.ceil(factor / 10), 1, 1000)
				MetaBadges.UpgradeBadge(ply, "criminal", new_level)
			end
		end)

		if not succ then
			MTA.Print("Failed to update badge for:", ply, err)
		end
	end

	function MTA.ResetPlayerFactor(ply, should_pay)
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
			if ply.PayCoins and not ply:PayCoins(old_factor * 1000, "MTA Criminal Fee") then
				local cur_coins = ply:GetCoins()
				if cur_coins > 0 then
					ply:PayCoins(cur_coins, "MTA Criminal Fee")

					local hell_pos = landmark and landmark.get("hll") or nil
					if hell_pos then
						ply:SetPos(hell_pos)
						MTA.ChatPrint(ply, "Not enough money to pay the fee! To hell you go!")
					end
				end
			end

			hook.Run("MTAPlayerFailed", ply, max_factor)
		end

		hook.Run("MTAWantedStateUpdate", ply, false)
		net.Start(NET_WANTED_STATE)
		net.WriteEntity(ply)
		net.WriteBool(false)
		net.Broadcast()

		ply.MTABad = nil
		local removed = remove_ent_from_table(ply, MTA.BadPlayers)
		if not removed then
			MTA.Print(("failed to reset citizenship of %s properly, cleaning up data."):format(tostring(ply)))
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

	local function is_valid_context()
		for i = 1, 3 do
			local stack_info_source = debug.getinfo(i).source
			if stack_info_source:match("gcompute") or stack_info_source:match("luadev") then
				return false
			end
		end

		return true
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
		if not is_valid_context() then return end
		if not MTA.IsEnabled() then return end

		local factor = (MTA.Factors[ply] or 0) + amount
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
		if not is_valid_context() then return end

		local old_factor = MTA.Factors[ply] or 0
		local factor = math.max(old_factor - amount, 0)
		MTA.Factors[ply] = factor

		local processed_factor = factor < 1 and 0 or math.ceil(factor / 10)
		ply:SetNWInt("MTAFactor", processed_factor)
		hook.Run("MTAPlayerWantedLevelDecreased", ply, processed_factor)

		if factor < 1 then
			hook.Run("MTAPlayerEscaped", ply, ply.MTAMaxSessionFactor or 0)
			MTA.ResetPlayerFactor(ply, false)
		end

		MTA.UpdatePlayerBadge(ply, old_factor)
	end

	-- With this numbers the maximum time to escape at lvl 1000 should be
	-- about 1mins 45 and 1min for lvl 10. Keep in mind these levels are hidden
	-- and to get the displayed levels you should divide them by 10.
	local BASE_DECREASE_FACTOR = 1
	local DECREASE_DIVIDER = 250 -- increase to slow down escape, increase to speed up escape
	function MTA.UpdateState()
		MTA.SpawnCombine()

		local time = CurTime()
		for _, ply in ipairs(MTA.BadPlayers) do
			if ply:IsValid() then
				if not MTA.CanPlayerEscape(ply) then
					-- refresh the "player factor state", since we dont want them to escape
					MTA.ProcessPlayerFactor(ply)
				elseif (time - (ply.MTALastFactorIncrease or 0)) >= ESCAPE_TIME then
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
			{ Stages = 1, Title = L "Literally Hitler" },
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

	local function spawn_lobby_persistent_ents()
		-- we need to handle it ourselves because
		-- ms.persist doesnt handle anything but saving and pasting
		if ms and ms.persist and ms.persist.paste then
			for _, ent in ipairs(ents.GetAll()) do
				if ent.__persist_page == "lobby_mta" then
					SafeRemoveEntity(ent)
				end
			end

			ms.persist.paste("lobby_mta", "lobby_3", Angle())
		end
	end

	function MTA.Initialize()
		-- this is done here, because only here will the proper nodegraph be available
		local far_combine, setup_combine = include("mta_libs/far_combine.lua")
		if not far_combine or not setup_combine then
			MTA.Print("Could not include far_combine.lua properly")
			return
		end

		MTA.FarCombine = far_combine
		MTA.SetupCombine = setup_combine

		local constrain_player, release_player = include("mta_libs/wanted_constraints.lua")
		if not constrain_player or not release_player then
			MTA.Print("Could not include wanted_constraints.lua properly")
			return
		end

		MTA.ConstrainPlayer = constrain_player
		MTA.ReleasePlayer = release_player

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
			MTA.Print("Could not create badge:", err)
		end

		spawn_lobby_persistent_ents()

		if blocked_maps[game.GetMap()] then
			MTA.Print("BAD MAP DETECTED DISABLING")
			MTA_MODE:SetInt(0)
		end
	end

	function MTA.ShouldIncreasePlayerFactor(ply)
		if not IsValid(ply) then return false end
		if ply.MTAIgnore then return false end
		if not ply:IsPlayer() then return false end
		if not ply:Alive() then return false end
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

		-- dont count banned players
		if banni and banni.isbanned(ent) then return false end

		-- dont count things spawned by players
		if ent.CPPIGetOwner and IsValid(ent:CPPIGetOwner()) then return false end

		return true
	end

	local whitelist = {
		["crossbow_bolt"] = true,
		["npc_grenade_frag"] = true,
		["rpg_missile"] = true,
		["rpg_rocket"] = true,
		["prop_combine_ball"] = true,
		["grenade_ar2"] = true,
		["npc_satchel"] = true,
		["crossbow_bolt_hl1"] = true,
		["monster_tripmine"] = true,
		["grenade_hand"] = true,
		["ent_lite_hegrenade"] = true,
		["ms_hax_monitor"] = true,
		["mta_mobile_emp"] = true,
	}
	hook.Add("EntityTakeDamage", tag, function(ent, dmg_info)
		if dmg_info:IsFallDamage() then return end

		-- dont account damage by yourself
		local atck = dmg_info:GetAttacker()
		if ent == atck then return end

		if ent:GetNWBool("MTACombine") then
			-- dont let combines hurt each others
			if atck:GetNWBool("MTACombine") then return true end

			-- dont let opted out players damage the npcs
			if type(atck) == "Player" and MTA.IsOptedOut(atck) then
				return true
			end
		end

		if not MTA.ShouldConsiderEntity(ent) then return end
		if not MTA.ShouldIncreasePlayerFactor(atck) then return end

		if Instances and not Instances.ShouldInteract(atck, ent) then
			return true
		end

		local inflictor = dmg_info:GetInflictor()
		if isentity(inflictor) and IsValid(inflictor) then
			if inflictor.ConcussionBall then return true end
			if type(inflictor) ~= "Player" and not inflictor:IsWeapon() and not whitelist[inflictor:GetClass()] then
				return true
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

	local function combine_weapon_drop(npc)
		local dissolving = false
		for _, ent in ipairs(npc:GetChildren()) do
			if ent:GetClass() == "env_entity_dissolver" then
				dissolving = true
				break
			end
		end

		local wep = npc:GetActiveWeapon()
		if IsValid(wep) then
			local dropped_wep = ents.Create(wep:GetClass())
			dropped_wep.lobbyok = true
			dropped_wep.unrestricted_gun = true
			dropped_wep.PhysgunDisabled = true
			dropped_wep.dont_televate = true
			dropped_wep:SetPos(npc:WorldSpaceCenter())
			dropped_wep:Spawn()
			dropped_wep:SetClip1(dropped_wep:GetMaxClip1() / 2)

			if dissolving then
				dropped_wep:SetName("mta_disolve_" .. tostring(dropped_wep:EntIndex()))

				local dissolver = ents.Create("env_entity_dissolver")
				dissolver:SetKeyValue("target", "mta_disolve_" .. tostring(dropped_wep:EntIndex()))
				dissolver:SetKeyValue("dissolvetype", "0")
				dissolver:Spawn()
				dissolver:Activate()
				dissolver:Fire("Dissolve", dropped_wep:GetName(), 0)
				SafeRemoveEntityDelayed(dissolver, 0.1)
			end

			SafeRemoveEntity(wep)
			timer.Simple(5, function()
				if not IsValid(dropped_wep) then return end
				local parent = dropped_wep:GetParent()
				if IsValid(parent) and parent:IsPlayer() then return end

				dropped_wep:Remove()
			end)
		end
	end

	hook.Add("OnNPCKilled", tag, function(npc)
		if not npc:GetNWBool("MTACombine") then return end

		combine_weapon_drop(npc)
		ensure_combine_removal(npc)
	end)

	hook.Add("EntityRemoved", tag, function(ent) -- can be removed by other factors
		if ent:IsNPC() and ent:GetNWBool("MTACombine") then
			ensure_combine_removal(ent)
		end
	end)

	hook.Add("PlayerDisconnected", tag, function(ply) MTA.ResetPlayerFactor(ply, true) end)
	hook.Add("PlayerDeath", tag, function(ply) MTA.ResetPlayerFactor(ply, true) end)
	hook.Add("PlayerSilentDeath", tag, function(ply) MTA.ResetPlayerFactor(ply, true) end)

	hook.Add("InstanceChanged", tag, function(ent, id)
		if not ent:IsPlayer() then return end
		if id ~= 0 then
			MTA.ResetPlayerFactor(ent, true)
		end
	end)

	hook.Add("PlayerLeftTrigger", tag, function(ply)
		timer.Simple(1, function()
			if not IsValid(ply) then return end
			if not MTA.InLobby(ply) then
				MTA.ResetPlayerFactor(ply, true)
			end
		end)
	end)

	hook.Add("PlayerShouldTakeDamage", tag, function(ply, atck)
		if atck:IsPlayer() and atck.MTABad and ply.MTABad then
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
					local target = MTA.BadPlayers[math.random(#MTA.BadPlayers)]
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

	hook.Add("InitPostEntity", tag, MTA.Initialize)
	hook.Add("PostCleanupMap", tag, spawn_lobby_persistent_ents)

	if is_refresh_lua then
		MTA.Initialize()
	end
end

if CLIENT then
	local MTA_OPT_OUT = CreateClientConVar("mta_opt_out", "0", true, true, "Disable criminal events in the lobby for yourself")
	local MTA_SHOW_WANTEDS = CreateClientConVar("mta_show_wanteds", "1", true, false, "Displays other wanted players")
	cvars.AddChangeCallback("mta_opt_out", function(_, _, new)
		if tobool(new) and LocalPlayer():GetNWInt("MTAFactor", 0) > 0 then -- cba to network a reset fuck this
			RunConsoleCommand("kill")
		end
	end)

	function MTA.IsOptedOut()
		return MTA_OPT_OUT:GetBool()
	end

	function MTA.IsWanted()
		return LocalPlayer():GetNWInt("MTAFactor") >= 1
	end

	surface.CreateFont("MTAIndicatorFont", {
		font = "Arial",
		size = 20,
		weight = 800,
		shadow = false,
	})

	surface.CreateFont("MTAHUDFont", {
		font = "Tahoma",
		size = 20,
		weight = 600,
		antialias = true,
	})

	surface.CreateFont("MTAHUDFontExtra", {
		font = "Tahoma",
		size = 100,
		weight = 600,
		antialias = true,
	})

	local black_color = Color(0, 0, 0, 150)
	local orange_color = Color(244, 135, 2)

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

	local MIN_DIST = 300
	function MTA.ManagedHighlightEntity(ent, text, color)
		if CurTime() >= (ent.NextHighlightCheck or 0) then
			ent.NextHighlightCheck = CurTime() + 1

			local lp = LocalPlayer()
			if lp:WorldSpaceCenter():Distance(ent:WorldSpaceCenter()) > MIN_DIST then
				ent.ShouldHighlight = false
				return
			end

			local tr = util.TraceLine({
				start = lp:EyePos(),
				endpos = ent:WorldSpaceCenter(),
				filter = lp
			})
			if tr.Entity ~= ent then
				ent.ShouldHighlight = false
				return
			end

			ent.ShouldHighlight = true
		end

		if ent.ShouldHighlight then
			MTA.HighlightEntity(ent, text, color)
		end
	end

	function MTA.GetBindKey(binding)
		local bind = input.LookupBinding(binding, true)
		if not bind then return end
		return bind:upper()
	end

	hook.Add("HUDPaint", tag, function()
		if not MTA_SHOW_WANTEDS:GetBool() then return end
		if not MTA.IsWanted() then return end

		for _, ply in ipairs(player.GetAll()) do
			local ply_factor = ply:GetNWInt("MTAFactor")
			if ply_factor >= 1 then
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

	net.Receive(NET_WANTED_STATE, function()
		local ply = net.ReadEntity()
		local is_wanted = net.ReadBool()

		hook.Run("MTAWantedStateUpdate", ply, is_wanted)
	end)

	local function dont_draw(ent)
		ent:SetRenderMode(RENDERMODE_NONE)
		ent:AddEffects(EF_NODRAW)
		ent:AddEffects(EF_NOSHADOW)
		ent:AddEffects(EF_NORECEIVESHADOW)
		ent.RenderOverride = function() end
	end

	hook.Add("OnEntityCreated", tag, function(ent)
		if not MTA.IsOptedOut() then return end
		timer.Simple(0.5, function()
			if not IsValid(ent) then return end
			if not ent:GetNWBool("MTACombine") then return end
			dont_draw(ent)
			for _, child in pairs(ent:GetChildren()) do
				dont_draw(child)
			end
		end)
	end)
end

for _, f in pairs((file.Find("mta_modules/*.lua", "LUA"))) do
	local path = "mta_modules/" .. f
	AddCSLuaFile(path)
	include(path)
end