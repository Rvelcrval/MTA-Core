local tag = "mta_bounties"
local NET_MTA_BOUNTIES = "MTA_BOUNTIES"
local NET_MTA_ACCEPT_BOUNTY = "MTA_ACCEPT_BOUNTY"
local NET_MTA_REMOVE_BOUNTY = "MTA_REMOVE_BOUNTY"

local MINIMUM_LEVEL = MTA_CONFIG.bounties.MinimumLevel
local MAX_BOUNTIES_PER_HUNTER = MTA_CONFIG.bounties.MaxBountiesPerHunter
local TIME_TO_BOUNTY_REFRESH = MTA_CONFIG.bounties.TimeToBountyRefresh

if SERVER then
	util.AddNetworkString(NET_MTA_BOUNTIES)
	util.AddNetworkString(NET_MTA_ACCEPT_BOUNTY)
	util.AddNetworkString(NET_MTA_REMOVE_BOUNTY)

	local function get_lobby_players()
		local plys = {}
		for _, ply in ipairs(player.GetAll()) do
			if MTA.InLobby(ply) and not MTA.IsWanted(ply) and not MTA.IsOptedOut(ply) then
				table.insert(plys, ply)
			end
		end

		return plys
	end

	local bounties = {}
	local hunters = {}
	local blocked_hunters = {}

	local function set_nw_data(hunter)
		local nw_data = ""
		for _, bounty in ipairs(hunters[hunter]) do
			nw_data = nw_data .. ("%d;"):format(bounty:EntIndex())
		end
		hunter:SetNWString("MTABountyHunter", nw_data)
	end

	local function finish_bounty(hunter)
		local steam_id = hunter:SteamID()
		blocked_hunters[steam_id] = (blocked_hunters[steam_id] or 0) + 1
		if blocked_hunters[steam_id] >= MAX_BOUNTIES_PER_HUNTER then
			timer.Simple(TIME_TO_BOUNTY_REFRESH, function()
				blocked_hunters[steam_id] = nil
			end)
		end
	end

	local function clear_bounty(ply)
		bounties[ply] = nil
		for hunter, targets in pairs(hunters) do
			table.RemoveByValue(targets, ply)
			set_nw_data(hunter)
		end

		net.Start(NET_MTA_REMOVE_BOUNTY)
		net.WriteEntity(ply)
		net.Broadcast()
	end

	local function check_immunity()
		for ply, targets in pairs(hunters) do
			if IsValid(ply) and #targets == 0 then
				ply.MTAIgnore = nil
				ply:SetNWString("MTABountyHunter", "")
				hunters[ply] = nil
				MTA.ReleasePlayer(ply)
				hook.Run("MTABountyHunterStateUpdate", ply, false)
			end
		end
	end

	hook.Add("MTAPlayerWantedLevelIncreased", tag, function(ply, wanted_level)
		if wanted_level < (MINIMUM_LEVEL + (MTA.GetPlayerStat(ply, "prestige_level") * 10)) then return end
		if bounties[ply] then return end

		MTA.ChatPrint(ply, "A bounty has been ", MTA.OldValueColor, "issued for you!")
		bounties[ply] = true
		net.Start(NET_MTA_BOUNTIES)
		net.WriteEntity(ply)
		net.Send(get_lobby_players())
	end)

	local function announce_bounty_end(bounty, was_hunted, hunter, points_earned)
		local filter = {}
		for _, ply in ipairs(player.GetAll()) do
			if (not was_hunted and MTA.InLobby(ply)) or (was_hunted and ply ~= hunter and MTA.InLobby(ply)) then
				table.insert(filter, ply)
			end
		end

		if was_hunted then
			MTA.ChatPrint(filter, bounty, MTA.TextColor, "'s bounty was claimed by ", hunter, MTA.TextColor,
				" for ", MTA.NewValueColor, ("%d criminal points"):format(points_earned))
		else
			MTA.ChatPrint(filter, bounty, MTA.TextColor, "'s bounty was ", MTA.OldValueColor, "cleared", MTA.TextColor, " by the police")
		end
	end

	hook.Add("PlayerDeath", tag, function(ply, _, atck)
		-- the bounty gains points for killing its hunters
		if hunters[ply] and table.HasValue(hunters[ply], atck) then
			MTA.GivePoints(atck, 15)
			MTA.ChatPrint(ply, "You have ", MTA.OldValueColor, "failed", MTA.TextColor, " to collect the bounty for ", atck,
				MTA.TextColor, " you can try again in ", MTA.NewValueColor, "30s")
			finish_bounty(ply)

			timer.Simple(30, function()
				if not IsValid(ply) then return end
				if not IsValid(atck) then return end
				if not bounties[atck] then return end

				ply.MTAIgnore = nil
				ply:SetNWString("MTABountyHunter", "")
				hunters[ply] = nil
				MTA.ReleasePlayer(ply)
				hook.Run("MTABountyHunterStateUpdate", ply, false)

				net.Start(NET_MTA_BOUNTIES)
				net.WriteEntity(atck)
				net.Send(ply)
			end)

			return
		end

		if not bounties[ply] then return end

		local targets = hunters[atck]
		if atck:IsPlayer() and targets and table.HasValue(targets, ply) then
			local point_amount = math.ceil(ply:GetNWInt("MTAFactor") * 0.8) * (1 + MTA.GetPlayerStat(ply, "prestige_level"))
			--local total_points = MTA.GivePoints(atck, point_amount)

			if atck.GiveCoins then
				atck:GiveCoins(point_amount * 300)
			end

			finish_bounty(ply)
			clear_bounty(ply)
			timer.Simple(1, check_immunity)
			announce_bounty_end(ply, true, atck, point_amount)
		else
			clear_bounty(ply)
			check_immunity()
			announce_bounty_end(ply, false)
		end
	end)

	hook.Add("MTAPlayerEscaped", tag, function(ply)
		clear_bounty(ply)
		check_immunity()
	end)

	hook.Add("MTAPlayerFailed", tag, function(ply)
		clear_bounty(ply)
		check_immunity()
	end)

	hook.Add("EntityTakeDamage", tag, function(ent, dmg_info)
		local atck = dmg_info:GetAttacker()
		if hunters[atck] and ent:GetNWBool("MTACombine") then return true end
	end)

	hook.Add("PlayerShouldTakeDamage", tag, function(ply, atck)
		if not atck:IsPlayer() then return end

		-- allow the bounties to fight back
		if not IS_MTA_GM and bounties[atck] and hunters[ply] then return true end

		-- dont damage this player if you have a bounty for them
		if not hunters[atck] and bounties[ply] then
			atck:PrintMessage(HUD_PRINTTALK, "You must accept the bounty for this player to kill them")
			return false
		end

		local targets = hunters[atck]
		if not targets then return end

		if not table.HasValue(targets, ply) then
			atck:PrintMessage(HUD_PRINTTALK, "You must accept the bounty for this player to kill them")
			return false
		end

		return true
	end)

	hook.Add("PlayerDisconnected", tag, function(ply)
		clear_bounty(ply)
		check_immunity()
	end)

	net.Receive(NET_MTA_ACCEPT_BOUNTY, function(_, ply)
		local target = net.ReadEntity()
		if not IsValid(target) then return end

		if blocked_hunters[ply:SteamID()] then
			MTA.ChatPrint(ply, "Bounty quota ", MTA.OldValueColor, "exceeded", MTA.TextColor, " try again in ", MTA.NewValueColor, "2 hours")
			return
		end

		ply.MTAIgnore = true
		hunters[ply] = hunters[ply] or {}
		table.insert(hunters[ply], target)
		set_nw_data(ply)

		MTA.ConstrainPlayer(ply, "MTA bounty hunter")
		ply:Spawn()
		hook.Run("MTABountyHunterStateUpdate", ply, true)

		MTA.ChatPrint(target, ply, MTA.TextColor, " has accepted a bounty for your head!")
	end)
end

if CLIENT then
	local bounties = {}

	local function clear_invalid_bounties()
		local done_bounties = {}
		for i, bounty in pairs(bounties) do
			if not IsValid(bounty) then
				table.remove(bounties, i)
			else
				if done_bounties[bounty] then
					table.remove(bounties, i)
				end

				done_bounties[bounty] = true
			end
		end
	end

	net.Receive(NET_MTA_BOUNTIES, function()
		local bounty = net.ReadEntity()
		table.insert(bounties, bounty)
		clear_invalid_bounties()

		local bind = (input.LookupBinding("+menu_context", true) or "c"):upper()
		chat.AddText(MTA.OldValueColor, "[MTA] ", bounty, MTA.TextColor, " has become a ", MTA.NewValueColor, "valuable target!", MTA.TextColor,
			" Accept the bounty in the ", MTA.NewValueColor, ("context menu [PRESS %s]"):format(bind), MTA.TextColor, " to get ", MTA.NewValueColor, "points and coins!")
	end)

	net.Receive(NET_MTA_REMOVE_BOUNTY, function()
		local bounty = net.ReadEntity()
		table.RemoveByValue(bounties, bounty)
	end)

	local bounty_panels = {}
	hook.Add("OnContextMenuOpen", tag, function()
		clear_invalid_bounties()
		if #bounties == 0 then return end

		local cur_x, cur_y = 200, 100
		for _, bounty in pairs(bounties) do
			local frame = vgui.Create("DFrame")
			frame:SetWide(200)
			frame:SetPos(cur_x, cur_y)
			frame:SetTitle("MTA Bounty")
			frame:SetSkin("MTA")

			-- python hack taken from netgraphx to allow movement
			frame:SetZPos(32000)
			timer.Simple(0,function()
				if IsValid(frame) then
					frame:MakePopup()
					frame:SetKeyboardInputEnabled(false)
					frame:MoveToFront()
				end
			end)

			frame.btnMinim:Hide()
			frame.btnMaxim:Hide()

			local label_name = frame:Add("DLabel")
			label_name:SetText("Target: " .. (UndecorateNick and UndecorateNick(bounty:Nick()) or bounty:Nick()))
			label_name:Dock(TOP)
			label_name:DockMargin(5, 5, 5, 5)

			local btn_accept = frame:Add("DButton")
			btn_accept:SetText("Hunt")
			btn_accept:SetTextColor(MTA.TextColor)
			btn_accept:Dock(TOP)
			btn_accept:DockMargin(5, 5, 5, 5)

			local label_gains = frame:Add("DLabel")
			label_gains:SetText(("Potential Gains: %dpts"):format(math.ceil(bounty:GetNWInt("MTAFactor") * 0.8) * (1 + bounty:GetNWInt("MTAStat_prestige_level"))))
			label_gains:SetTextColor(MTA.PrimaryColor)
			label_gains:Dock(TOP)
			label_gains:DockPadding(10, 10, 10, 10)
			label_gains:DockMargin(5, 5, 5, 5)
			label_gains:SetContentAlignment(5)

			frame:InvalidateLayout(true)
			frame:SizeToChildren(false, true)

			function btn_accept:DoClick()
				if not IsValid(bounty) then return end

				net.Start(NET_MTA_ACCEPT_BOUNTY)
				net.WriteEntity(bounty)
				net.SendToServer()

				table.RemoveByValue(bounties, bounty)

				frame:Close()
				chat.AddText(MTA.OldValueColor, "[MTA] ", MTA.TextColor, "You have ", MTA.NewValueColor, "accepted", MTA.TextColor, " the bounty for ", bounty)
			end

			cur_x = cur_x + frame:GetWide() + 20
			if cur_x + frame:GetWide() >= ScrW() then
				cur_x = 200
				cur_y = cur_y + frame:GetTall() + 20
			end

			table.insert(bounty_panels, frame)
		end
	end)

	hook.Add("OnContextMenuClose", tag, function()
		for _, panel in pairs(bounty_panels) do
			if panel:IsValid() then
				panel:Remove()
			end
		end

		table.Empty(bounty_panels)
	end)

	local next_check_data = {}
	local function is_player_hunter(ply)
		local check_data = next_check_data[ply] or { Time = 0, Cached = false }
		if CurTime() < check_data.Time then return check_data.Cached end

		local ret = false
		local target_ids = ply:GetNWString("MTABountyHunter", "")
		if target_ids ~= "" then
			local targets = target_ids:Split(";")
			ret = table.HasValue(targets, LocalPlayer():EntIndex())
		end

		check_data.Cached = ret
		check_data.Time = CurTime() + 1
		return ret
	end

	hook.Add("HUDPaint", tag, function()
		if not MTA.IsWanted() then return end

		for _, ply in ipairs(player.GetAll()) do
			if is_player_hunter(ply) then
				MTA.HighlightEntity(ply, "/// BOUNTY HUNTER ///", MTA.DangerColor)
			end
		end
	end)
end