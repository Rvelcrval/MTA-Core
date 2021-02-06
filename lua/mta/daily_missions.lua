if not IS_MTA_GM then return end

local tag = "mta_daily_missions"
local base_missions = {}
local cur_missions = {}

local function get_progress(ply, mission_id)
	local nw_var_name = tag .. "_" .. mission_id
	return ply:GetNWInt(nw_var_name)
end

local function add_progress(ply, mission_id, amount)
	if CLIENT then return end
	if not cur_missions[mission_id] then return end

	local mission = base_missions[mission_id]
	if not mission then return end

	local state = cur_missions[mission_id][ply:AccountID()] or { Progress = 0, Completed = false }
	if state.Completed then return end

	state.Progress = state.Progress + amount
	cur_missions[mission_id][ply:AccountID()] = state

	local nw_var_name = tag .. "_" .. mission_id
	ply:SetNWInt(nw_var_name, state.Progress)

	if state.Progress >= mission.Completion then
		MTA.GivePoints(ply, mission.Reward)
		cur_missions[mission_id][ply:AccountID()].Completed = true
	end
end

base_missions.kill_shotgunners = {
	Description = "Kill 10 shotgunners",
	Completion = 10,
	Reward = 20,
	Execute = function()
		hook.Add("OnNPCKilled", tag .. "_kill_shotgunners", function(npc, attacker)
			if not attacker:IsPlayer() then return end
			if npc:GetNWBool("MTACombine") then
				local wep = npc:GetActiveWeapon()
				if IsValid(wep) and wep:GetClass() == "weapon_shotgun" then
					add_progress(attacker, "kill_shotgunners", 1)
				end
			end
		end)
	end,
	Finish = function()
		hook.Remove("OnNPCKilled", tag .. "_kill_shotgunners")
	end
}

base_missions.kill_metropolice = {
	Description = "Kill 25 metropolice agents",
	Completion = 25,
	Reward = 20,
	Execute = function()
		hook.Add("OnNPCKilled", tag .. "_kill_metropolice", function(npc, attacker)
			if not attacker:IsPlayer() then return end
			if npc:GetNWBool("MTACombine") and npc:GetClass() == "npc_metropolice" then
				add_progress(attacker, "kill_metropolice", 1)
			end
		end)
	end,
	Finish = function()
		hook.Remove("OnNPCKilled", tag .. "_kill_metropolice")
	end
}

base_missions.drill_vaults = {
	Description = "Drill 3 vaults successfully",
	Completion = 3,
	Reward = 100,
	Execute = function()
		hook.Add("MTADrillSuccess", tag .. "_drill_vaults", function(ply)
			add_progress(ply, "drill_vaults", 1)
		end)
	end,
	Finish = function()
		hook.Remove("MTADrillSuccess", tag .. "_drill_vaults")
	end,
}

base_missions.wanted_lvl_75 = {
	Description = "Get up to wanted level 75",
	Completion = 75,
	Reward = 100,
	Execute = function()
		hook.Add("MTAPlayerWantedLevelIncreased", tag .. "_wanted_lvl_75", function(ply, wanted_level)
			local progress = get_progress(ply, "wanted_lvl_75")
			if progress < wanted_level then
				add_progress(ply, "wanted_lvl_75", 1)
			end
		end)
	end,
	Finish = function()
		hook.Remove("MTAPlayerWantedLevelIncreased", tag .. "_wanted_lvl_75")
	end,
}

if SERVER then
	util.AddNetworkString(tag)

	local function select_daily_missions()
		for mission_id, _ in pairs(cur_missions) do
			base_missions[mission_id].Finish()
			base_missions[mission_id] = nil
		end

		local keys = table.GetKeys(base_missions)
		local selected_mission_ids = {}
		for i = 1, 3 do
			local rand = math.random(#keys)
			table.insert(selected_mission_ids, keys[rand])
			table.remove(keys, rand)
		end

		for _, mission_id in pairs(selected_mission_ids) do
			cur_missions[mission_id] = {}
			base_missions[mission_id].Execute()
		end

		net.Start(tag)
		net.WriteTable(selected_mission_ids)
		net.Broadcast()
	end

	hook.Add("PlayerFullyConnected", tag, function(ply)
		net.Start(tag)
		net.WriteTable(table.GetKeys(cur_missions))
		net.Send(ply)
	end)

	select_daily_missions()
	timer.Create(tag, 86400, 0, select_daily_missions)
end

if CLIENT then
	local selected_mission_ids = {}
	net.Receive(tag, function()
		selected_mission_ids = net.ReadTable()
	end)

	surface.CreateFont("MTAMissionsFont", {
		font = IS_MTA_GM and "Orbitron" or "Arial",
		size = 20,
		weight = 600,
		shadow = false,
		extended = true,
	})

	surface.CreateFont("MTAMissionsFontDesc", {
		font = IS_MTA_GM and "Alte Haas Grotesk" or "Arial",
		size = 20,
		weight = 600,
		shadow = false,
		extended = true,
	})

	surface.CreateFont("MTAMissionsFontTitle", {
		font = IS_MTA_GM and "Alte Haas Grotesk" or "Arial",
		size = 30,
		weight = 600,
		shadow = false,
		extended = true,
	})

	local orange_color = Color(244, 135, 2)
	local white_color = Color(255, 255, 255)
	local offset_x = 300
	local width = 280

	local screen_ration = ScrH() / 1080
	local mat_vec = Vector()
	local pos_x_left = -25 * screen_ration
	local pos_y_left = -100 * screen_ration
	local last_angles = EyeAngles()
	local ang_delta_p = 0
	local ang_delta_y = 0
	local last_translate_p = 0
	local last_translate_y = 0
	local mat_vec = Vector()

	hook.Add("HUDPaint", tag, function()
		local curAngs = EyeAngles()
		local vel = LocalPlayer():GetAbsVelocity()

		ang_delta_p = math.AngleDifference(last_angles.p, curAngs.p)
		ang_delta_y = math.AngleDifference(last_angles.y, curAngs.y)

		last_angles = curAngs

		last_translate_p = Lerp(FrameTime() * 5, last_translate_p, ang_delta_p)
		last_translate_y = Lerp(FrameTime() * 5, last_translate_y, ang_delta_y)

		if vel.z ~= 0 then
			last_translate_p = last_translate_p + (math.Clamp(vel.z, -100, 100) * FrameTime() * 0.2)
		end

		local mat = Matrix()
		mat:SetField(2, 1, 0.10)

		mat_vec.x = pos_x_left + (last_translate_y * 2)
		mat_vec.y = pos_y_left + (last_translate_p * 3)

		mat:SetTranslation(mat_vec)
		cam.PushModelMatrix(mat)

		local title_x, title_y = ScrW() - offset_x, ScrH() / 2 - 50
		surface.SetDrawColor(0, 0, 0, 150)
		surface.DrawRect(title_x - 5, title_y - 5, width, 40)

		surface.SetDrawColor(orange_color)
		surface.DrawOutlinedRect(title_x - 5, title_y - 5, width, 40, 2)

		surface.SetTextColor(color_white)
		surface.SetTextPos(title_x + 5, title_y)
		surface.SetFont("MTAMissionsFontTitle")
		surface.DrawText("DAILY CHALLENGES")

		for i, mission_id in pairs(selected_mission_ids) do
			local mission = base_missions[mission_id]
			local progress = get_progress(LocalPlayer(), mission_id)
			if progress < mission.Completion then
				surface.SetFont("MTAMissionsFontDesc")
				local desc = mission.Description:upper()
				local x, y = ScrW() - offset_x, ScrH() / 2 + 60*(i -1)
				surface.SetDrawColor(0, 0, 0, 150)
				surface.DrawRect(x - 5, y - 5, width, 50)

				surface.SetTextColor(white_color)
				surface.SetTextPos(x, y)
				surface.DrawText(desc)

				surface.SetFont("MTAMissionsFont")
				surface.SetTextColor(orange_color)
				surface.SetTextPos(x, y + 20)
				local progress = get_progress(LocalPlayer(), mission_id)
				surface.DrawText(("%d/%d"):format(progress, mission.Completion))

				local points = mission.Reward .. "pts"
				local tw, _ = surface.GetTextSize(points)
				surface.SetTextPos(x + width - (tw + 10), y + 20)
				surface.DrawText(points)

				surface.SetDrawColor(orange_color)
				surface.DrawLine(x - 5, y + 45, x + width - 5, y + 45)
			end
		end

		cam.PopModelMatrix()
	end)
end