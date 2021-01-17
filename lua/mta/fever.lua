local tag = "mta_fever"

local FEVER_TIME = 20
local FEVER_TRESHOLD = 10
local FEVER_INTERVAL = 10
local FEVER_TIMEOUT = 180
local FEVER_WEAPON_CLASS = "weapon_core_thrower"

if SERVER then
	util.AddNetworkString(tag)

	local fever_data = {}

	local function stop_fever(ply)
		ply:StripWeapon("weapon_core_thrower")
		ply.MTAInFever = nil
		fever_data[ply] = nil
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
				atck:SetActiveWeapon(wep)

				net.Start(tag)
				net.WriteBool(true)
				net.Send(atck)

				atck.MTAInFever = true
				atck.MTANextFever = CurTime() + FEVER_TIMEOUT

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
	local cmds = { "pp_sobel", "pp_bloom", "pp_sharpen", "pp_toytown " }
	net.Receive(tag, function()
		in_fever = net.ReadBool()

		local cmd_arg = in_fever and 1 or 0
		for _, cmd in pairs(cmds) do
			LocalPlayer():ConCommand(("%s %s"):format(cmd, cmd_arg))
		end
	end)

	hook.Add("HUDPaint", tag, function()
		if not in_fever then return end
		surface.SetDrawColor(255, 0, 0, 35)
		surface.DrawRect(0, 0, ScrW(), ScrH())
	end)

	hook.Add("EntityEmitSound", tag, function(data)
		if not in_fever then return end
		data.DSP = 6
		return true
	end)
end