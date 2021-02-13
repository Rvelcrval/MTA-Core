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

base_missions.survive_2500_dmg = {
	Description = "Take 2500dmg while wanted",
	Completion = 2500,
	Reward = 75,
	Execute = function()
		hook.Add("EntityTakeDamage", tag .. "_survive_2500_dmg", function(target, dmg_info)
			if target:IsPlayer() and MTA.IsWanted(target) then
				local atck = dmg_info:GetAttacker()
				if IsValid(atck) and atck:GetNWBool("MTACombine") then
					add_progress(target, "survive_2500_dmg", dmg_info:GetDamage())
				end
			end
		end)

		hook.Add("MTAPlayerFailed", tag .. "_survive_2500_dmg", function(ply)
			local progress = get_progress(ply, "survive_2500_dmg")
			add_progress(ply, "survive_2500_dmg", -progress)
		end)
	end,
	Finish = function()
		hook.Remove("EntityTakeDamage", tag .. "_survive_2500_dmg")
		hook.Remove("MTAPlayerFailed", tag .. "_survive_2500_dmg")
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
		for mission_id, data in pairs(cur_missions) do
			local ply_data = data[ply:AccountID()] or { Progress = 0, Completed = false }
			ply:SetNWInt(tag .. "_" .. mission_id, ply_data.Progress)
		end

		net.Start(tag)
		net.WriteTable(table.GetKeys(cur_missions))
		net.Send(ply)
	end)

	local data_file_name = tag .. ".json"
	local last_day = os.date("%d")
	timer.Create(tag, 60, 0, function()
		local day_component = os.date("%d")
		if last_day ~= day_component and os.date("%H") == "0" then
			select_daily_missions()
			last_day = day_component
		end

		file.Write(data_file_name, util.TableToJSON({
			date = cur_date,
			cur_missions = cur_missions,
		}))
	end)

	local data = util.JSONToTable(file.Read(data_file_name, "DATA") or "")
	if data and data.date == os.date("%d/%m/%Y") then
		cur_missions = data
	else
		select_daily_missions()
	end
end

if CLIENT then
	local selected_mission_ids = {}
	net.Receive(tag, function()
		selected_mission_ids = net.ReadTable()
	end)

	local screen_ratio = ScrH() / 1080

	surface.CreateFont("MTAMissionsFont", {
		font = IS_MTA_GM and "Orbitron" or "Arial",
		size = 20 * screen_ratio,
		weight = 600,
		shadow = false,
		extended = true,
	})

	surface.CreateFont("MTAMissionsFontDesc", {
		font = IS_MTA_GM and "Alte Haas Grotesk" or "Arial",
		size = 20 * screen_ratio,
		weight = 600,
		shadow = false,
		extended = true,
	})

	surface.CreateFont("MTAMissionsFontTitle", {
		font = IS_MTA_GM and "Alte Haas Grotesk" or "Arial",
		size = 30 * screen_ratio,
		weight = 600,
		shadow = false,
		extended = true,
	})

	local orange_color = Color(244, 135, 2)
	local white_color = Color(255, 255, 255)
	local mat_vec = Vector()
	local function draw_daily_missions()
		return {
			Draw = function()
				local screen_ratio = MTAHud.Config.ScrRatio
				local offset_x = 300 * screen_ratio
				local width = 280 * screen_ratio
				local yaw = -EyeAngles().y
				local mat = Matrix()
				mat:SetField(2, 1, 0.10)

				mat_vec.x = (-25 * screen_ratio) + (MTAHud.Vars.LastTranslateY * 2)
				mat_vec.y = (-25 * screen_ratio) + (MTAHud.Vars.LastTranslateP * 3)

				mat:SetTranslation(mat_vec)
				cam.PushModelMatrix(mat)

				local margin = 5 * screen_ratio
				local title_x, title_y = ScrW() - offset_x, ScrH() / 2 - 50 * screen_ratio
				surface.SetDrawColor(0, 0, 0, 150)
				surface.DrawRect(title_x - margin, title_y - margin, width, 40 * screen_ratio)

				surface.SetDrawColor(orange_color)
				surface.DrawOutlinedRect(title_x - margin, title_y - margin, width, 40 * screen_ratio, 2)

				surface.SetTextColor(color_white)
				surface.SetTextPos(title_x + margin, title_y)
				surface.SetFont("MTAMissionsFontTitle")
				surface.DrawText("DAILY CHALLENGES")

				for i, mission_id in pairs(selected_mission_ids) do
					local mission = base_missions[mission_id]
					local progress = get_progress(LocalPlayer(), mission_id)
					if progress < mission.Completion then
						surface.SetFont("MTAMissionsFontDesc")
						local desc = mission.Description:upper()
						local x, y = ScrW() - offset_x, ScrH() / 2 + (60 * (i -1) * screen_ratio)
						surface.SetDrawColor(0, 0, 0, 150)
						surface.DrawRect(x - margin, y - margin, width, 50 * screen_ratio)

						surface.SetTextColor(white_color)
						surface.SetTextPos(x, y)
						surface.DrawText(desc)

						surface.SetFont("MTAMissionsFont")
						surface.SetTextColor(orange_color)
						surface.SetTextPos(x, y + 20 * screen_ratio)
						local progress = get_progress(LocalPlayer(), mission_id)
						surface.DrawText(("%d/%d"):format(progress, mission.Completion))

						local points = mission.Reward .. "pts"
						local tw, _ = surface.GetTextSize(points)
						surface.SetTextPos(x + width - (tw + 10 * screen_ratio), y + 20 * screen_ratio)
						surface.DrawText(points)

						surface.SetDrawColor(orange_color)
						surface.DrawLine(x - margin, y + 45 * screen_ratio, x + width - margin, y + 45 * screen_ratio)
					end
				end

				cam.PopModelMatrix()
			end
		}
	end

	MTAHud:AddComponent("daily_missions", draw_daily_missions())
end
