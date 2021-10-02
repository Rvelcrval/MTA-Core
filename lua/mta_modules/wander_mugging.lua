local tag = "mta_mug"

pcall(include, "autorun/translation.lua")
local L = translation and translation.L or function(s) return s end

local function can_mug(ply, ent)
	if not ply:Alive() then return false end
	if not IsValid(ent) then return false end
	if ent:GetClass() ~= "lua_npc_wander" or ent:GetNWBool("MTAWasMugged", false) then return false end
	if ent:GetPos():Distance(ply:GetPos()) > 125 then return false end

	return true
end

if SERVER then
	hook.Add("KeyPress", tag, function(ply, key)
		if not MTA.IsEnabled() then return end
		if key ~= IN_RELOAD then return end
		if not MTA.ShouldIncreasePlayerFactor(ply) then return end

		local tr = ply:GetEyeTrace()
		local target = tr.Entity
		if can_mug(ply, target) and ply.GiveCoins then
			local coins_mugged = math.random(0, 500)
			if coins_mugged > 0 then
				ply:GiveCoins(coins_mugged, "MTA Citizen Mugging")
			end

			target:SetNWBool("MTAWasMugged", true)

			target.MTAIgnore = true
			target:TakeDamage(1, ply, ply)
			timer.Simple(1, function()
				if not IsValid(target) then return end
				target.MTAIgnore = nil
			end)

			if math.random() > 0.75 then
				MTA.IncreasePlayerFactor(ply, 2)
			end
		end
	end)
end

if CLIENT then
	local verb = L"Mug"
	hook.Add("HUDPaint", tag, function()
		if MTA.IsOptedOut() then return end

		local ply = LocalPlayer()
		local tr = ply:GetEyeTrace()
		local target = tr.Entity
		if not can_mug(ply, target) then return end

		local bind = MTA.GetBindKey("+reload")
		if not bind then return end

		local text = ("/// %s [%s] ///"):format(verb, bind)
		MTA.HighlightEntity(target, text, MTA.TextColor)
	end)
end

