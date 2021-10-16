local tag = "mta_pickpocket"

pcall(include, "autorun/translation.lua")
local L = translation and translation.L or function(s) return s end

local NET_ADD_PICKPOCKET = "MTA_ADD_PICKPOCKET"
local NET_REMOVE_PICKPOCKET = "MTA_REMOVE_PICKPOCKET"

local pickpockets = setmetatable({}, { __mode = "k" })

if SERVER then
	util.AddNetworkString(NET_ADD_PICKPOCKET)
	util.AddNetworkString(NET_REMOVE_PICKPOCKET)

	local voice_lines = {
		male = {
			"vo/npc/male01/answer25.wav", -- "How bout that"
			"vo/npc/male01/gotone01.wav", -- "Got one"
			"vo/npc/male01/gotone02.wav", -- "Haha I got one"
			"vo/npc/male01/oneforme.wav", -- "One for me and one for me"
		},
		female = {
			"vo/npc/female01/answer25.wav",
			"vo/npc/female01/gotone01.wav",
			"vo/npc/female01/gotone02.wav",
		}
	}

	hook.Add("EntityTakeDamage", tag, function(target, dmg_info)
		local pickpocket_data = pickpockets[target]
		if not pickpocket_data then return end

		local atck = dmg_info:GetAttacker()
		if atck ~= pickpocket_data.Player then return end
		if not atck.GiveCoins then return end

		atck:GiveCoins(pickpocket_data.Amount * 2, "MTA Caught Pickpocket")
		pickpockets[target] = nil

		net.Start(NET_REMOVE_PICKPOCKET)
		net.WriteEntity(target)
		net.Send(atck)
	end)

	hook.Add("OnNPCKilled", tag, function(npc, atck)
		if not _G.coins then return end

		local pickpocket_data = pickpockets[npc]
		if not pickpocket_data then return end

		if atck ~= pickpocket_data.Player then
			_G.coins.Create(npc:GetPos(), pickpocket_data.Amount * 2, "MTA Killed Pickpocket")

			pickpockets[npc] = nil

			if atck:IsPlayer() then
				net.Start(NET_REMOVE_PICKPOCKET)
				net.WriteEntity(npc)
				net.Send(atck)
			end
		end
	end)

	hook.Add("EntityRemoved", tag, function(ent)
		if not _G.coins then return end

		local pickpocket_data = pickpockets[ent]
		if not pickpocket_data then return end

		_G.coins.Create(ent:GetPos(), pickpocket_data.Amount * 2, "MTA Killed Pickpocket")

		pickpockets[ent] = nil

		if IsValid(pickpocket_data.Player) then
			net.Start(NET_REMOVE_PICKPOCKET)
			net.WriteEntity(ent)
			net.Send(pickpocket_data.Player)
		end
	end)

	local function is_pickpocketable_player(ply)
		if ply.IsLoadingIn and ply:IsLoadingIn() then return false end
		if not ply:Alive() then return false end
		if MTA.IsOptedOut(ply) then return false end
		if ply.IsAFK and ply:IsAFK() then return false end
		if MetaBadges and MetaBadges.IsValidBadge("good_fortune") then
			local chance = MetaBadges.GetBadgeLevel(ply, "good_fortune") or 0
			if (math.random() * 100) < chance then return false end
		end

		local ret = hook.Run("MTAShouldPickpocket", ply)
		if ret == false then return false end

		return true
	end

	hook.Add("InitPostEntity", tag, function()
		if not AI_Activities or not AI_Tasks then return end

		local INCLUDE_RANGE = 500
		AI_Tasks:Add("FindPickpocketablePlayer", function(npc, state, inputs)
			local pos = npc:GetPos()
			local players = {}

			for _, ply in pairs(player.GetAll()) do
				local dist = ply:GetPos():Distance(pos)
				if dist <= INCLUDE_RANGE and is_pickpocketable_player(ply) then
					table.insert(players, ply)
				end
			end

			state.LastTargetEntity = state.Rand:TableElement(players)
		end)

		AI_Tasks:Add("PickpocketPlayer", function(npc, state, inputs)
			local ply = state.LastTargetEntity
			if not IsValid(ply) then return ACTIVITY_TASK_FAIL end

			if not ply:IsPlayer() or not ply.TakeCoins or not ply.GetCoins then
				return ACTIVITY_TASK_FAIL
			end

			if ply:GetPos():Distance(npc:GetPos()) > 150 then
				return ACTIVITY_TASK_FAIL
			end

			local amount = math.random(500, 2000)
			local ply_total_coins = ply:GetCoins()
			if ply_total_coins > 0 then
				ply:TakeCoins(amount > ply_total_coins and ply_total_coins or amount, "wander pickpocket")
				ply:SetVelocity((npc:GetPos() - ply:GetPos()):GetNormalized() * 128)
				ply:EmitSound("physics/body/body_medium_impact_soft7.wav", 65, 75)
				ply:EmitSound("npc/combine_soldier/gear5.wav", 65, math.random(110, 125))

				net.Start(NET_ADD_PICKPOCKET)
				net.WriteEntity(npc)
				net.WriteInt(amount, 32)
				net.Send(ply)

				npc.MTAIgnore = true
				npc:SetNWBool("MTAWasMugged", true) -- cant mug pickpocket
				pickpockets[npc] = { Amount = amount, Player = ply }

				local gender_lines = voice_lines[npc.GetGender and npc:GetGender() or "male"]
				npc:EmitSound(gender_lines[math.random(#gender_lines)])
			end
		end)

		AI_Tasks:Add("FinishPickpocket", function(npc, state, inputs)
			local pickpocket_data = pickpockets[npc]
			if not pickpocket_data then return ACTIVITY_TASK_FAIL end

			npc.MTAIgnore = nil
			npc:SetNWBool("MTAWasMugged", false) -- alow npc to be mugged afterward

			if not IsValid(pickpocket_data.Player) then
				pickpockets[npc] = nil
				return ACTIVITY_TASK_FAIL
			end

			net.Start(NET_REMOVE_PICKPOCKET)
			net.WriteEntity(npc)
			net.Send(pickpocket_data.Player)

			pickpockets[npc] = nil
		end)

		AI_Activities:Add("PickpocketPlayer", {
			TestCondition = function(npc, state)
				return true
			end,
			GetPriority = function(npc, state)
				return 25
			end,
			Tasks = {
				{ "PushPosition" },
				{ "FindPickpocketablePlayer" },
				{ "MoveToTargetEntity", { Run = true } },
				{ "PickpocketPlayer" },
				{ "PopPosition" },
				{ "FindSpot", { Type = "far" } },
				{ "MoveToPosition", { Run = true } },
				{ "FindSpot", { Type = "far" } },
				{ "MoveToPosition", { Run = true } },
				{ "FindSpot", { Type = "far" } },
				{ "MoveToPosition", { Run = true } },
				{ "FinishPickpocket" }
			}
		})
	end)
end

if CLIENT then
	net.Receive(NET_ADD_PICKPOCKET, function()
		local npc = net.ReadEntity()
		local amount = net.ReadInt(32)
		pickpockets[npc] = amount
	end)

	net.Receive(NET_REMOVE_PICKPOCKET, function()
		local npc = net.ReadEntity()
		pickpockets[npc] = nil
	end)

	local thief_name = L"Thief"
	hook.Add("HUDPaint", tag, function()
		for npc, amount in pairs(pickpockets) do
			if npc:IsValid() and not npc:IsDormant() then
				local text = ("/// %s (%d c) ///"):format(thief_name, amount)
				MTA.HighlightEntity(npc, text, MTA.PrimaryColor)
			end
		end
	end)
end

