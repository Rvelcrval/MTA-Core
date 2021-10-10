local tag = "mta_fever"

local FEVER_TIME = MTA_CONFIG.fever.FeverTime
local FEVER_TRESHOLD = MTA_CONFIG.fever.FeverTreshold
local FEVER_INTERVAL = MTA_CONFIG.fever.FeverInterval
local FEVER_TIMEOUT = MTA_CONFIG.fever.FeverTimeout
local FEVER_WEAPON_CLASS = MTA_CONFIG.fever.FeverWeaponClass

if SERVER then
	util.AddNetworkString(tag)

	local fever_data = {}

	local function stop_fever(ply)
		ply:StripWeapon(FEVER_WEAPON_CLASS)
		ply.MTAInFever = nil
		fever_data[ply] = nil
		hook.Run("MTAFeverState", ply, false)
		net.Start(tag)
		net.WriteBool(false)
		net.Send(ply)
	end

	hook.Add("OnNPCKilled", tag, function(npc, atck)
		if not npc:GetNWBool("MTACombine") then return end
		if not atck:IsPlayer() then return end
		if not MTA.IsWanted(atck) then return end
		if atck.MTANextFever and atck.MTANextFever >= CurTime() then return end

		local data = fever_data[atck] or {}
		table.insert(data, CurTime())

		if #data >= FEVER_TRESHOLD then
			table.remove(data, 1)

			local oldest_kill = data[1]
			if oldest_kill > (CurTime() - FEVER_INTERVAL) then
				local wep = atck:Give(FEVER_WEAPON_CLASS)
				wep.unrestricted_gun = true
				wep.lobbyok = true
				wep.PhysgunDisabled = true
				wep.dont_televate = true
				atck:SelectWeapon(FEVER_WEAPON_CLASS)
				atck:SetActiveWeapon(wep)

				net.Start(tag)
				net.WriteBool(true)
				net.Send(atck)

				atck.MTAInFever = true
				atck.MTANextFever = CurTime() + FEVER_TIMEOUT

				hook.Run("MTAFeverState", atck, true)

				if IS_MTA_GM then
					MTA.Statuses.AddStatus(atck, "fever", "Fever", MTA.DangerColor, CurTime() + FEVER_TIME)
				end

				timer.Simple(FEVER_TIME, function()
					if not IsValid(atck) then return end
					stop_fever(atck)
				end)
			end
		end

		fever_data[atck] = data
	end)

	hook.Add("MTAWantedStateUpdate", tag, function(ply, is_wanted)
		if not is_wanted then
			stop_fever(ply)
			ply.MTANextFever = nil
		end
	end)

	hook.Add("PlayerShouldTakeDamage", tag, function(ply)
		if ply.MTAInFever then return false end
	end)

	hook.Add("PlayerSwitchWeapon", tag, function(ply, old_wep)
		if ply.MTAInFever and IsValid(old_wep) and old_wep:GetClass() == FEVER_WEAPON_CLASS then
			return true
		end
	end)

	hook.Add("PlayerDroppedWeapon", tag, function(_, wep)
		if wep:GetClass() == FEVER_WEAPON_CLASS then
			SafeRemoveEntityDelayed(wep, 0)
		end
	end)
end

if CLIENT then
	local in_fever = false
	local fever_end_time = 0
	local cmds = { "pp_sobel", "pp_bloom", "pp_sharpen", "pp_toytown " }
	net.Receive(tag, function()
		in_fever = net.ReadBool()
		fever_end_time = CurTime() + FEVER_TIME

		local cmd_arg = in_fever and 1 or 0
		for _, cmd in pairs(cmds) do
			LocalPlayer():ConCommand(("%s %s"):format(cmd, cmd_arg))
		end
	end)

	-- doing this here not to draw above MTAPaint stuff
	hook.Add("HUDPaint", tag, function()
		if not in_fever then return end
		local scrw, scrh = ScrW(), ScrH()
		surface.SetDrawColor(255, 0, 0, 35)
		surface.DrawRect(0, 0, scrw, scrh)
	end)

	if not IS_MTA_GM then
		hook.Add("MTAPaint", tag, function()
			if not in_fever then return end

			local scrw, scrh = ScrW(), ScrH()
			surface.SetTextColor(MTA.DangerColor)
			surface.SetFont("MTALargeFont")

			local diff = math.max(fever_end_time - CurTime(), 0)
			local s, ms = math.floor(diff), math.Round(math.fmod(diff, 1) * 1000)
			local time_left = ("/// %d:%d ///"):format(s, ms)
			local tw, th = surface.GetTextSize(time_left)
			local pos_x, pos_y = scrw / 2 - tw / 2, scrh / 2 - th / 2

			surface.SetDrawColor(MTA.BackgroundColor)
			surface.DrawRect(pos_x - 5, pos_y - 5, tw + 10, th + 10)

			surface.SetDrawColor(MTA.DangerColor)
			surface.DrawOutlinedRect(pos_x - 5, pos_y - 5, tw + 10, th + 10)

			surface.SetTextPos(pos_x, pos_y)
			surface.DrawText(time_left)
		end)
	end

	hook.Add("EntityEmitSound", tag, function(data)
		if not in_fever then return end
		data.DSP = 6
		return true
	end)
end