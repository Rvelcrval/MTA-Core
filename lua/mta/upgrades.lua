local tag = "mta_upgrades"

local NET_MTA_GUI = "MTA_GUI"
local NET_CONVERT_POINTS = "MTA_CONVERT_POINTS"
local NET_UPGRADE = "MTA_UPGRADE"
local NET_GIVE_WEAPON = "MTA_GIVE_WEAPON"
local NET_REFILL_WEAPON = "MTA_REFILL_WEAPON"

local COIN_MULTIPLIER = 300
local POINT_MULTIPLIER = 5 / 110

-- DB SCHEME
--[[
CREATE TABLE MTA_STATS (
	id integer NOT NULL PRIMARY KEY,
	points integer DEFAULT 0,
	killed_cops integer DEFAULT 0,
	criminal_count integer DEFAULT 0,
	damage_multiplier double precision DEFAULT 1.00,
	defense_multiplier double precision DEFAULT 1.00
	healing_multiplier double precision DEFAULT 1.00
)
]]--

-- TODO IDEAS:
--[[
- getting back your old weapons with coins
- use points to revive with your current wanted level
- skill to scare metrocops away if grenade explodes or whatever
]]--

local color_white = Color(255, 255, 255)

local valid_stats = {
	criminal_count = 0,
	points = 0,
	killed_cops = 0,
	damage_multiplier = 1,
	defense_multiplier = 1,
	healing_multiplier = 1,
}

local weapon_prices = {
	weapon_ar2 = 8,
	weapon_357 = 4,
	weapon_pistol = 1,
	weapon_crossbow = 10,
	weapon_rpg = 15,
	weapon_smg1 = 6,
	weapon_shotgun = 6,
	weapon_asmd = 12,
	weapon_plasmanade = 6,
	weapon_slam = 4,
}

if SERVER then
	util.AddNetworkString(NET_MTA_GUI)
	util.AddNetworkString(NET_CONVERT_POINTS)
	util.AddNetworkString(NET_UPGRADE)
	util.AddNetworkString(NET_GIVE_WEAPON)
	util.AddNetworkString(NET_REFILL_WEAPON)

	local MAX_NPC_DIST = 300 * 300
	hook.Add("KeyPress", tag, function(ply, key)
		if key ~= IN_USE then return end

		local npc = ply:GetEyeTrace().Entity
		if not npc:IsValid() then return end

		if npc.role == "dealer" and npc:GetPos():DistToSqr(ply:GetPos()) <= MAX_NPC_DIST then
			net.Start(NET_MTA_GUI)
			net.WriteEntity(npc)
			net.Send(ply)

			if ply.LookAt then
				ply:LookAt(npc, 0.1, 0)
			end
		end
	end)

	local function can_db()
		return _G.db and _G.co
	end

	function MTA.GetPlayerStat(ply, stat_name)
		local nw_value_name = ("MTAStat_%s"):format(stat_name)
		local default_value = valid_stats[stat_name] or 0
		local cur_value = ply:GetNWInt(nw_value_name, default_value)

		if cur_value < default_value then return default_value end
		return cur_value
	end

	local old_value_color = Color(252, 71, 58)
	local new_value_color = Color(58, 252, 113)
	function MTA.IncreasePlayerStat(ply, stat_name, amount, should_log)
		if not IsValid(ply) then return -1 end
		if not can_db() then return -1 end
		if ply:IsBot() then return -1 end
		if banni and banni.isbanned(ply) then return -1 end

		local nw_value_name = ("MTAStat_%s"):format(stat_name)
		local cur_value = ply:GetNWInt(nw_value_name, 0)
		local new_value = cur_value + amount
		ply:SetNWInt(nw_value_name, new_value)

		hook.Run("MTAStatIncrease", ply, stat_name, cur_value, new_value)

		-- dont spam this
		local account_id = ply:AccountID()
		timer.Create(("MTAStatIncrease_%d_%s"):format(account_id, stat_name), 1, 1, function()
			if should_log then
				Msg("[MTA] ")
				MsgC(color_white, ("%s %s: "):format(ply, stat_name), old_value_color,
					cur_value, color_white, " -> ", new_value_color, new_value .. "\n")
			end

			co(function()
				db.Query(("UPDATE mta_stats SET %s = %d WHERE id = %d;"):format(stat_name, cur_value + amount, account_id))
			end)
		end)

		return new_value
	end

	hook.Add("MTAWantedStateUpdate", tag, function(ply, is_wanted)
		if is_wanted then
			MTA.IncreasePlayerStat(ply, "criminal_count", 1)
		end
	end)

	local total_value_color = Color(200, 200, 200)
	function MTA.GivePoints(ply, amount)
		if amount < 2 then return end

		local total_points = MTA.IncreasePlayerStat(ply, "points", amount, true)
		if total_points == -1 then return -1 end

		MTA.ChatPrint(ply, color_white, "You've earned ", new_value_color, amount .. " criminal points",
			total_value_color, (" (Total: %d)"):format(total_points), color_white, ", you can spend them with the ", new_value_color, "dealer.")

		return total_points
	end

	hook.Add("MTAPlayerEscaped", tag, function(ply, max_factor)
		MTA.GivePoints(ply, math.ceil(max_factor * 1.5))
	end)

	hook.Add("MTAPlayerFailed", tag, function(ply, max_factor)
		MTA.GivePoints(ply, math.floor(max_factor / 2))
	end)

	hook.Add("OnNPCKilled", tag, function(npc, attacker)
		if not npc:GetNWBool("MTACombine") then return end
		if not attacker:IsPlayer() then return end

		MTA.IncreasePlayerStat(attacker, "killed_cops", 1)
	end)

	hook.Add("ScaleNPCDamage", tag, function(npc, _, dmg_info)
		if not npc:GetNWBool("MTACombine") then return end

		local attacker = dmg_info:GetAttacker()
		if not attacker:IsPlayer() then return end
		if not MTA.InLobby(attacker) then return end

		local multiplier = MTA.GetPlayerStat(attacker, "damage_multiplier")
		dmg_info:ScaleDamage((1 + (0.01 * multiplier)) * 2) -- up to 4x the damage
	end)

	hook.Add("ScalePlayerDamage", tag, function(ply, _, dmg_info)
		if not ply.MTABad then return end

		local attacker = dmg_info:GetAttacker()
		if not attacker:GetNWBool("MTACombine") then return end

		local multiplier = MTA.GetPlayerStat(attacker, "defense_multiplier")
		local dmg = dmg_info:GetDamage()
		local dmg_blocked = ((dmg / 100) * (multiplier * 0.75)) -- up to 80% of the damages blocked
		dmg_info:SetDamage(dmg - dmg_blocked)
	end)

	local next_heal = 0
	hook.Add("Think", tag, function()
		if next_heal > CurTime() then return end

		for _, ply in ipairs(MTA.BadPlayers) do
			local multiplier = MTA.GetPlayerStat(ply, "healing_multiplier")
			local to_heal = math.ceil((multiplier * 1.6) / 2)
			local cur_health = ply:Health()
			if cur_health < 100 then
				ply:SetHealth(math.min(cur_health + to_heal, 100))
			else
				ply:SetArmor(math.min(ply:Armor() + to_heal, 100))
			end
		end

		next_heal = CurTime() + 10
	end)

	hook.Add("PlayerInitialSpawn", tag, function(ply)
		if not can_db() then return end

		co(function()
			local account_id = ply:AccountID()
			local ret = db.Query(("SELECT * FROM mta_stats WHERE id = %d;"):format(account_id))[1]
			if not ret then
				db.Query(("INSERT INTO mta_stats(id) VALUES(%d);"):format(account_id))
				for stat_name, default_value in pairs(valid_stats) do
					MTA.IncreasePlayerStat(ply, stat_name, default_value)
				end
			else
				for stat_name, default_value in pairs(valid_stats) do
					MTA.IncreasePlayerStat(ply, stat_name, ret[stat_name] or default_value)
				end
			end
		end)

		if aowl then
			aowl.AddCommand("dealer", "Teleports you to the MTA dealer", function(ply)
				ply:ConCommand("aowl goto dealer")
			end)

			aowl.AddCommand("mtastats", "Gets the MTA stats of a player", function(caller, _, target)
				if not target or #target:Trim() == 0 then
					target = caller
				else
					target = easylua.FindEntity(target)
				end

				if not IsValid(target) then return false, "invalid target" end
				if not target:IsPlayer() then return false, "not a player" end

				local target_nick = UndecorateNick(caller:Nick())
				local msg = ("Stats for %s:\n"):format(target_nick)
				for stat_name, _ in pairs(valid_stats) do
					msg = msg .. ("- %s: %d\n"):format(stat_name, MTA.GetPlayerStat(target, stat_name))
				end

				MTA.ChatPrint(caller, msg)
			end)
		end
	end)

	hook.Add("AowlGiveAmmo", tag, function(ply)
		if ply.MTABad then return false end
	end)

	hook.Add("OnEntityCreated", tag, function(ent)
		if ent:GetClass() ~= "lua_npc" then return end
		timer.Simple(0, function()
			if not IsValid(ent) then return end
			if ent.role ~= "dealer" then return end

			ent:SetNWBool("MTADealer", true)
		end)
	end)

	net.Receive(NET_CONVERT_POINTS, function(_, ply)
		local points_to_convert = net.ReadUInt(32)
		local cur_ply_points = MTA.GetPlayerStat(ply, "points")
		if points_to_convert > cur_ply_points then return end
		if not ply.GiveCoins then return end

		local coins = points_to_convert * COIN_MULTIPLIER
		MTA.IncreasePlayerStat(ply, "points", -points_to_convert, true)
		ply:GiveCoins(coins, "MTA Converted Points")
	end)

	local function try_upgrade_player_stat(ply, stat_name)
		local cur_value = MTA.GetPlayerStat(ply, stat_name)
		local upgrade_price = math.Round(math.exp(cur_value * POINT_MULTIPLIER))
		if MTA.GetPlayerStat(ply, "points") < upgrade_price then return end
		if cur_value >= 100 then return end -- lock at level 100

		MTA.IncreasePlayerStat(ply, "points", -upgrade_price, true)
		MTA.IncreasePlayerStat(ply, stat_name, 1)
	end

	net.Receive(NET_UPGRADE, function(_, ply)
		local stat = net.ReadString()
		if not valid_stats[stat] then return end

		try_upgrade_player_stat(ply, stat)
	end)

	net.Receive(NET_GIVE_WEAPON, function(_, ply)
		local weapon_class = net.ReadString()

		local wep_price = weapon_prices[weapon_class]
		if not wep_price then return end

		if MTA.GetPlayerStat(ply, "points") < wep_price then return end
		MTA.IncreasePlayerStat(ply, "points", -wep_price, true)

		local wep = ply:HasWeapon(weapon_class) and ply:GetWeapon(weapon_class) or ply:Give(weapon_class)
		wep.unrestricted_gun = true
		wep.lobbyok = true
		wep.PhysgunDisabled = true
		wep.dont_televate = true
		wep:SetClip1(wep:GetMaxClip1())
		wep:SetClip2(2)
		ply:SelectWeapon(weapon_class)
	end)

	net.Receive(NET_REFILL_WEAPON, function(_, ply)
		if ply.PayCoins and ply:PayCoins(400, "MTA Weapon Refill") then
			local wep = ply:GetActiveWeapon()
			if wep.GetPrimaryAmmoType and wep:GetPrimaryAmmoType() ~= -1 then
				ply:GiveAmmo(wep:GetMaxClip1() / 2, wep:GetPrimaryAmmoType())
			end

			if wep.GetSecondaryAmmoType and wep:GetSecondaryAmmoType() ~= -1 then
				ply:GiveAmmo(wep:GetMaxClip2() / 2, wep:GetSecondaryAmmoType())
			end
		end
	end)
end

if CLIENT then
	-- for debug
	local FAKE_STAT = CreateClientConVar("mta_fake_stat", "0", false, false, "Fake your MTA stat levels for debug purposes")

	function MTA.GetPlayerStat(stat_name)
		local fake_stat_value = FAKE_STAT:GetInt()
		if fake_stat_value > 0 then return fake_stat_value end

		local nw_value_name = ("MTAStat_%s"):format(stat_name)
		local default_value = valid_stats[stat_name] or 0
		local cur_value = LocalPlayer():GetNWInt(nw_value_name, default_value)

		if cur_value < default_value then return default_value end
		return cur_value
	end

	local function paint_btn(self, w, h)
		if not self:IsEnabled() then
			surface.SetDrawColor(220, 0, 75)
			surface.DrawRect(0, 0, w, h)
			return
		end

		surface.SetDrawColor(30, 30, 30)
		surface.DrawRect(0, 0, w, h)

		if self:IsHovered() then
			surface.SetDrawColor(255, 255, 255)
			surface.DrawOutlinedRect(0, 0, w, h)
		end
	end

	local function show_dealer_frame(npc)
		local frame = vgui.Create("DFrame")
		frame:SetSize(640, 480)
		frame:Center()
		frame:DockPadding(5, 30, 5, 30)
		frame:SetTitle("MTA Dealer")
		frame:MakePopup()
		frame.btnMinim:Hide()
		frame.btnMaxim:Hide()

		-- header
		do
			local header = frame:Add("DPanel")
			header:Dock(TOP)
			header:DockPadding(5, 5, 5, 5)
			header:SetTall(50)

			local dealer_av = header:Add("DModelPanel")
			dealer_av:Dock(LEFT)
			dealer_av:SetModel(npc:GetModel())

			local headpos = dealer_av.Entity:GetBonePosition(dealer_av.Entity:LookupBone("ValveBiped.Bip01_Head1"))
			dealer_av:SetLookAt(headpos)
			dealer_av:SetCamPos(headpos - Vector(-13, 0, 0))

			function dealer_av:LayoutEntity(ent)
				ent:SetSequence(ent:LookupSequence("idle_subtle"))
				self:RunAnimation()
			end

			local intro = header:Add("DLabel")
			intro:Dock(FILL)
			intro:SetText([[Pssst... Hey kid, interested in some upgrades? I got plenty of things here.
			What? What's MTA? That's the system in place to prevent you from rebelling against the gov' of course!]])
			intro:SetWrap(true)

			function header:Paint(w, h)
				surface.SetDrawColor(0, 0, 0, 240)
				surface.DrawRect(0, 0, w, h)

				surface.SetDrawColor(50, 50, 50)
				surface.DrawOutlinedRect(0, 0, w, h, 2)
			end
		end

		-- actions
		do
			local content = frame:Add("DScrollPanel")
			content:Dock(FILL)
			content:DockMargin(5, 10, 5, 5)

			local function add_action(description, action, callback)
				local panel = content:Add("DPanel")
				panel:Dock(TOP)
				panel:DockMargin(0, 10, 0, 0)
				panel:SetTall(50)

				function panel:Paint(w, h)
					surface.SetDrawColor(0, 0, 0, 240)
					surface.DrawRect(0, 0, w, h)

					surface.SetDrawColor(50, 50, 50)
					surface.DrawOutlinedRect(0, 0, w, h, 2)
				end

				local label = panel:Add("DLabel")
				label:Dock(LEFT)
				label:DockMargin(10, 5, 5, 5)
				label:SetText(description)
				label:SetWide(400)

				local btn = panel:Add("DButton")
				btn:Dock(RIGHT)
				btn:DockMargin(5, 5, 5, 5)
				btn:SetText(action)
				btn:SetTextColor(color_white)
				btn:SetWide(125)
				btn.DoClick = callback
				btn.Paint = paint_btn
				btn.Description = label

				return btn
			end

			add_action("Convert points to coins", "Convert", function(btn)
				Derma_StringRequest("Convert Points to Coins", "Amount of points to convert", "0", function(text)
					local amount = tonumber(text)
					if not amount then return end
					if amount <= 0 then return end

					net.Start(NET_CONVERT_POINTS)
					net.WriteUInt(amount, 32)
					net.SendToServer()
					surface.PlaySound("ui/buttonclick.wav")
				end)
			end)

			-- weapons
			do
				local panel = content:Add("DPanel")
				panel:Dock(TOP)
				panel:DockMargin(0, 10, 0, 0)

				function panel:Paint(w, h)
					surface.SetDrawColor(0, 0, 0, 240)
					surface.DrawRect(0, 0, w, h)

					surface.SetDrawColor(50, 50, 50)
					surface.DrawOutlinedRect(0, 0, w, h, 2)
				end

				local label = panel:Add("DLabel")
				label:Dock(TOP)
				label:DockMargin(10, 5, 5, 5)
				label:SetText("Weapons")
				label:SetWide(300)

				local weapons_lookup = {
					weapon_ar2 = { Name = "AR2", Model = "models/weapons/w_irifle.mdl" },
					weapon_357 = { Name = "Revolver", Model = "models/weapons/w_357.mdl" },
					weapon_pistol = { Name = "Pistol", Model = "models/weapons/w_pistol.mdl" },
					weapon_rpg = { Name = "RPG", Model = "models/weapons/w_rocket_launcher.mdl" },
					weapon_smg1 = { Name = "SMG", Model = "models/weapons/w_smg1.mdl" },
					weapon_shotgun = { Name = "Shotgun", Model = "models/weapons/w_shotgun.mdl" },
					weapon_crossbow = { Name = "Crossbow", Model = "models/weapons/w_crossbow.mdl" },
					weapon_asmd = { Name = "ASMD Shock Rifle", Model = "models/weapons/w_ut2k4_shock_rifle.mdl" },
					weapon_plasmanade = { Name = "Plasma Grenade", Model = "models/weapons/w_grenade.mdl" },
					weapon_slam = { Name = "SLAM", Model = "models/weapons/w_slam.mdl" }
				}
				local weapon_x, weapon_y = 5, 30
				local i = 0
				local function add_weapon(weapon_class)
					local wep_price = weapon_prices[weapon_class]
					local wep_details = weapons_lookup[weapon_class]
					if not wep_price or not wep_details then return end

					local wep_panel = panel:Add("Panel")
					wep_panel:SetSize(90, 90)
					wep_panel:SetPos(weapon_x, weapon_y)

					i = i + 1
					weapon_x = weapon_x + wep_panel:GetWide() + 5
					if i % 6 == 0 then -- rows of 6
						local y_to_add = wep_panel:GetTall() + 5
						weapon_y = weapon_y + y_to_add
						weapon_x = 5
						panel:SetTall(weapon_y + y_to_add)
					end

					function wep_panel:Paint(w, h)
						surface.SetDrawColor(75, 75, 75, 240)
						surface.DrawRect(0, 0, w, h)

						surface.SetDrawColor(MTA.GetPlayerStat("points") >= wep_price and 50 or 255, 50, 50)
						surface.DrawOutlinedRect(0, 0, w, h, 2)
					end

					local mdl = wep_panel:Add("DModelPanel")
					mdl:Dock(FILL)
					mdl:SetModel(wep_details.Model)
					mdl:SetCamPos(Vector(0, 30, 0))
					mdl:SetLookAt(Vector(0, 0, 0))

					local btn = wep_panel:Add("DButton")
					btn:SetWrap(true)
					btn:SetPos(10, 30)
					btn:SetSize(wep_panel:GetWide() - 10, wep_panel:GetTall() - 10)
					btn:SetText(("%s (%dpts)"):format(wep_details.Name, wep_price))
					btn:SetTextColor(color_white)
					function btn:Paint() end

					function btn:DoClick()
						net.Start(NET_GIVE_WEAPON)
						net.WriteString(weapon_class)
						net.SendToServer()
						surface.PlaySound("ui/buttonclick.wav")
					end
				end

				for weapon_class, _ in pairs(weapon_prices) do
					add_weapon(weapon_class)
				end
			end

			local btn_refill = add_action("Refill your current weapon's clip (ammo)", "Buy (400c)", function()
				net.Start(NET_REFILL_WEAPON)
				net.SendToServer()
				surface.PlaySound("ui/buttonclick.wav")
			end)
			function btn_refill:Think()
				local lp = LocalPlayer()
				if not lp.GetCoins then return end

				self:SetDisabled(lp:GetCoins() < 400)
			end
		end

		function frame.btnClose:Paint(w, h)
			surface.SetTextColor(220, 0, 50)
			surface.SetFont("DermaDefault")

			local tw, th = surface.GetTextSize("X")
			surface.SetTextPos(w / 2 - tw / 2, h / 2 - th / 2)
			surface.DrawText("X")
		end

		function frame:OnKeyCodePressed(key_code)
			if key_code == KEY_ESCAPE or key_code == KEY_E then
				self:Remove()
			end
		end

		local proper_stat_names = {
			points = "Points",
			killed_cops = "Killed Cops",
			criminal_count = "Times Wanted"
		}

		local stat__height_margin = 10
		local stat_width_margin = 20
		function frame:Paint(w, h)
			surface.SetDrawColor(0, 0, 0, 240)
			surface.DrawRect(0, 0, w, 25)

			surface.SetDrawColor(0, 0, 0, 200)
			surface.DrawRect(0, 25, w, h - 25)
		end

		function frame:PaintOver(w, h)
			local current_width = 0
			local i = 1
			for stat_name, proper_name in pairs(proper_stat_names) do
				surface.SetFont("DermaDefault")
				surface.SetTextColor(244, 135, 2)

				local text = ("%s: %d"):format(proper_name, MTA.GetPlayerStat(stat_name))
				local tw, th = surface.GetTextSize(text)
				surface.SetTextPos(i * stat_width_margin + current_width, h - (th + stat__height_margin))
				surface.DrawText(text)

				current_width = current_width + tw
				i = i + 1
			end

			surface.SetDrawColor(244, 135, 2)
			surface.DrawOutlinedRect(0, h - 30, w, 30, 2)

			surface.SetDrawColor(244, 135, 2, 10)
			surface.DrawRect(0, h - 30, w, 30)
		end
	end

	local dealer_npc
	local next_dealer_search = 0
	local function get_dealer_npc()
		if IsValid(dealer_npc) then return dealer_npc end
		if CurTime() < next_dealer_search then return end

		for _, npc in pairs(ents.FindByClass("lua_npc")) do
			if npc:GetNWBool("MTADealer") then
				dealer_npc = npc
				break
			end
		end

		next_dealer_search = CurTime() + 2
		return dealer_npc
	end

	hook.Add("HUDPaint", tag, function()
		local npc = get_dealer_npc()
		if not IsValid(npc) then return end

		local bind = MTA.GetBindKey("+use")
		if not bind then return end

		local text = ("/// Dealer [%s] ///"):format(bind)
		MTA.ManagedHighlightEntity(dealer_npc, text, color_white)
	end)

	net.Receive(NET_MTA_GUI, function()
		local dealer = net.ReadEntity()
		show_dealer_frame(dealer)
	end)
end