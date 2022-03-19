local tag = "mta_upgrades"

local NET_MTA_GUI = "MTA_GUI"
local NET_CONVERT_POINTS = "MTA_CONVERT_POINTS"
local NET_UPGRADE = "MTA_UPGRADE"
local NET_GIVE_WEAPON = "MTA_GIVE_WEAPON"
local NET_REFILL_WEAPON = "MTA_REFILL_WEAPON"
local NET_PRESTIGE = "MTA_PRESTIGE"

local MAX_LEVEL = MTA_CONFIG.upgrades.MaxLevel
local COIN_MULTIPLIER = MTA_CONFIG.upgrades.CoinMultiplier
local POINT_MULTIPLIER = MTA_CONFIG.upgrades.PointMultiplier

-- DB SCHEME
--[[
CREATE TABLE mta_stats (
	id integer NOT NULL PRIMARY KEY,
	points integer DEFAULT 0,
	killed_cops integer DEFAULT 0,
	criminal_count integer DEFAULT 0,
	damage_multiplier double precision DEFAULT 1.00,
	defense_multiplier double precision DEFAULT 1.00,
	healing_multiplier double precision DEFAULT 1.00,
	prestige_level integer DEFAULT 0,
)
]]--

local valid_stats = {
	criminal_count = 0,
	points = 0,
	killed_cops = 0,
	damage_multiplier = 1,
	defense_multiplier = 1,
	healing_multiplier = 1,
	prestige_level = 0,
}

local weapon_prices = MTA_CONFIG.upgrades.WeaponCosts
local prestige_stats = { "damage_multiplier", "defense_multiplier", "healing_multiplier" }
local function can_prestige_upgrade(ply)
	if not IS_MTA_GM then return false end

	for _, stat_name in ipairs(prestige_stats) do
		if SERVER and MTA.GetPlayerStat(ply, stat_name) < MAX_LEVEL then return false end
		if CLIENT and MTA.GetPlayerStat(stat_name) < MAX_LEVEL then return false end
	end

	return true
end

if SERVER then
	resource.AddFile("sound/mta/prestige.ogg")
	util.PrecacheSound("mta/prestige.ogg")

	util.AddNetworkString(NET_MTA_GUI)
	util.AddNetworkString(NET_CONVERT_POINTS)
	util.AddNetworkString(NET_UPGRADE)
	util.AddNetworkString(NET_GIVE_WEAPON)
	util.AddNetworkString(NET_REFILL_WEAPON)
	util.AddNetworkString(NET_PRESTIGE)

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

	local old_values = {}
	function MTA.IncreasePlayerStat(ply, stat_name, amount, should_log)
		if not IsValid(ply) then return -1 end
		if not can_db() then return -1 end
		if not ply:IsPlayer() or ply:IsBot() then return -1 end
		if banni and banni.isbanned(ply) then return -1 end

		local nw_value_name = ("MTAStat_%s"):format(stat_name)
		local cur_value = ply:GetNWInt(nw_value_name, 0)
		local new_value = cur_value + amount

		local ret = hook.Run("MTAStatIncrease", ply, stat_name, cur_value, new_value)
		if ret == false then return end

		ply:SetNWInt(nw_value_name, new_value)

		-- dont spam this
		local account_id = ply:AccountID()
		local log_name = ("MTAStatIncrease_%d_%s"):format(account_id, stat_name)
		old_values[log_name] = old_values[log_name] or cur_value
		timer.Create(log_name, 5, 1, function()
			if should_log then
				local log_func = metalog and function(...) metalog.infoColor("MTA", nil, ...) end or function(...) Msg("[MTA] ") MsgC(...) Msg("\n") end
				log_func(MTA.TextColor, ("%s %s: "):format(ply, stat_name), MTA.OldValueColor, old_values[log_name], MTA.TextColor, " -> ", MTA.NewValueColor, new_value)
			end

			old_values[log_name] = nil
			co(function()
				db.Query(("UPDATE mta_stats SET %s = %d WHERE id = %d;"):format(stat_name, new_value, account_id))
			end)
		end)

		return new_value
	end

	hook.Add("MTAWantedStateUpdate", tag, function(ply, is_wanted)
		if is_wanted then
			MTA.IncreasePlayerStat(ply, "criminal_count", 1)
		end
	end)

	function MTA.GivePoints(ply, amount)
		if amount < 2 then return end

		local total_points = MTA.IncreasePlayerStat(ply, "points", amount, true)
		if total_points == -1 then return -1 end

		local chat_print_args = IS_MTA_GM
			and { ", you can spend them with the ", MTA.NewValueColor, "dealer." }
			or { ", you can spend them on ", MTA.NewValueColor, "the MTA server", MTA.TextColor, " with the ", MTA.NewValueColor, "dealer." }
		MTA.ChatPrint(ply, MTA.TextColor, "You've earned ", MTA.NewValueColor, amount .. " criminal points",
			MTA.AdditionalValueColor, (" (Total: %d)"):format(total_points), MTA.TextColor, unpack(chat_print_args))
		if not IS_MTA_GM then
			MTA.ChatPrint(ply, MTA.AdditionalValueColor, "Type \"!goto mta\" to join the MTA server!")
		end

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
		if not MTA.InValidArea(attacker) then return end

		local multiplier = MTA.GetPlayerStat(attacker, "damage_multiplier")
		dmg_info:ScaleDamage((1 + (0.01 * multiplier)) * 2) -- up to 4x the damage
	end)

	local MAX_DMG_SCALING = 3
	local DMG_SCALING_STEP = 35
	hook.Add("ScalePlayerDamage", tag, function(ply, _, dmg_info)
		if not ply.MTABad then return end

		local attacker = dmg_info:GetAttacker()
		if not attacker:GetNWBool("MTACombine") then return end

		local multiplier = MTA.GetPlayerStat(attacker, "defense_multiplier")

		-- we scale combine damage up depending on wanted level here because it needs to be done
		-- before the resistance upgrade
		local dmg = dmg_info:GetDamage() + (dmg_info:GetDamage() * math.min(MAX_DMG_SCALING, ply:GetNWInt("MTAFactor") / DMG_SCALING_STEP))

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
			ply:SetHealth(math.min(cur_health + to_heal, 100))

			local remaining = to_heal - (100 - cur_health)
			if remaining > 0 then
				ply:SetArmor(math.min(ply:Armor() + remaining, 100))
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

			if not IsValid(ply) then return end
			hook.Run("MTAPlayerStatsInitialized", ply)
		end)

		if aowl then
			aowl.AddCommand("dealer", "Teleports you to the MTA dealer", function(caller)
				caller:ConCommand("aowl goto dealer")
			end)

			aowl.AddCommand("mtastats", "Gets the MTA stats of a player", function(caller, _, target)
				if not target or #target:Trim() == 0 then
					target = caller
				else
					target = easylua.FindEntity(target)
				end

				if not IsValid(target) then return false, "invalid target" end
				if not target:IsPlayer() then return false, "not a player" end

				local target_nick = UndecorateNick(target:Nick())
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

	function MTA.PayPoints(ply, amount)
		amount = math.Round(amount or 0)

		local cur_ply_points = MTA.GetPlayerStat(ply, "points")
		if amount > cur_ply_points then return false end

		return MTA.IncreasePlayerStat(ply, "points", -amount, true) ~= -1
	end

	net.Receive(NET_CONVERT_POINTS, function(_, ply)
		local points_to_convert = net.ReadUInt(32)
		if not ply.GiveCoins then return end

		if MTA.PayPoints(ply, points_to_convert) then
			local coins = points_to_convert * COIN_MULTIPLIER
			ply:GiveCoins(coins, "MTA Converted Points")
		end
	end)

	local function try_upgrade_player_stat(ply, stat_name)
		if not IS_MTA_GM then return end

		local cur_value = MTA.GetPlayerStat(ply, stat_name)
		if cur_value >= MAX_LEVEL then return end -- lock at level 100

		local upgrade_price = math.Round(math.exp(cur_value * POINT_MULTIPLIER))
		if MTA.PayPoints(ply, upgrade_price) then
			MTA.IncreasePlayerStat(ply, stat_name, 1)
		end
	end

	net.Receive(NET_UPGRADE, function(_, ply)
		local stat = net.ReadString()
		if not valid_stats[stat] then return end

		try_upgrade_player_stat(ply, stat)
	end)

	net.Receive(NET_GIVE_WEAPON, function(_, ply)
		if not IS_MTA_GM then return end

		local weapon_class = net.ReadString()

		local wep_price = weapon_prices[weapon_class]
		if not wep_price then return end

		local cur_classes = MTA.Weapons.Get(ply)
		if table.HasValue(cur_classes, weapon_class) then return end

		if MTA.PayPoints(ply, wep_price) then
			local wep = ply:HasWeapon(weapon_class) and ply:GetWeapon(weapon_class) or ply:Give(weapon_class)
			wep.unrestricted_gun = true
			wep.lobbyok = true
			wep.PhysgunDisabled = true
			wep.dont_televate = true
			wep:SetClip1(wep:GetMaxClip1())
			wep:SetClip2(2)
			ply:SelectWeapon(weapon_class)

			table.insert(cur_classes, weapon_class)
			MTA.Weapons.Save(ply, cur_classes)
		end
	end)

	net.Receive(NET_REFILL_WEAPON, function(_, ply)
		local all_weapons = net.ReadBool()
		local weps = all_weapons and ply:GetWeapons() or  { ply:GetActiveWeapon() }
		local price = 400 * #weps
		if ply.PayCoins and ply:PayCoins(price, "MTA Weapon Refill") then
			for _, wep in pairs(weps) do
				if wep.GetPrimaryAmmoType and wep:GetPrimaryAmmoType() ~= -1 then
					local max = wep:GetMaxClip1()
					max = max <= 0 and 10 or max
					ply:GiveAmmo(max, wep:GetPrimaryAmmoType())
				elseif wep.SetClip1 and wep.Clip1 then
					wep:SetClip1(wep:Clip1() + 10)
				end

				if wep.GetSecondaryAmmoType and wep:GetSecondaryAmmoType() ~= -1 then
					local max = wep:GetMaxClip2()
					max = max <= 0 and 10 or max
					ply:GiveAmmo(max, wep:GetSecondaryAmmoType())
				elseif wep.SetClip2 and wep.Clip2 then
					wep:SetClip2(wep:Clip2() + 10)
				end
			end
		end
	end)

	local stats_to_reset = { "points", "damage_multiplier", "defense_multiplier", "healing_multiplier" }
	net.Receive(NET_PRESTIGE, function(_, ply)
		if not can_prestige_upgrade(ply) then
			MTA.ChatPrint(ply, "You cannot level up your prestige yet")
			return
		end

		local new_prestige = MTA.IncreasePlayerStat(ply, "prestige_level", 1, true)

		MTA.Weapons.Save(ply, {})
		for _, stat_name in ipairs(stats_to_reset) do
			MTA.IncreasePlayerStat(ply, stat_name, -MTA.GetPlayerStat(ply, stat_name), true)
		end

		MTA.ChatPrint(player.GetAll(), ply, "'s ", MTA.NewValueColor, "Criminal Prestige", MTA.TextColor, " is growing! ", MTA.AdditionalValueColor, ("(Prestige Level %d)"):format(new_prestige))
		timer.Simple(0, function()
			net.Start(NET_PRESTIGE)
			net.WriteEntity(ply)
			net.Broadcast()
		end)

		hook.Run("MTAPlayerPrestige", ply, new_prestige)
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

	do -- prestige popup UI
		local PANEL = {}

		function PANEL:Init()
			self:SetBackgroundBlur(true)
			self:SetSize(500, 350)
			self:SetTitle("Criminal Prestige")

			local gains_header = self:Add("DLabel")
			gains_header:Dock(TOP)
			gains_header:SetText("Prestiging will get you:")

			local gains = self:Add("DLabel")
			gains:Dock(TOP)
			gains:DockMargin(20, 5, 5, 5)
			gains:SetWrap(true)
			gains:SetTall(75)
			gains:SetColor(MTA.NewValueColor)
			gains:SetText([[
			● A lower chance to be hunted by other players
			● An additional custom song slot (available at the jukebox)
			● A fancy scoreboard icon
			● A higher ranking in the overall leaderboard]])

			local losses_header = self:Add("DLabel")
			losses_header:SetText("Prestiging will reset:")
			losses_header:Dock(TOP)
			losses_header:DockMargin(5, 15, 5, 5)

			local losses = self:Add("DLabel")
			losses:Dock(TOP)
			losses:DockMargin(20, 5, 5, 5)
			losses:SetWrap(true)
			losses:SetTall(75)
			losses:SetColor(MTA.OldValueColor)
			losses:SetText([[
			● Your points
			● Your weapons
			● Your damage multiplier
			● Your resistance multiplier
			● Your healing multiplier]])

			local btn_prestige = self:Add("DButton")
			btn_prestige:SetText("Prestige Up")
			btn_prestige:SetFont("Trebuchet24")
			btn_prestige:SetColor(MTA.TextColor)
			btn_prestige:SetPos(80, self:GetTall() - 60)
			btn_prestige:SetSize(150, 30)
			function btn_prestige:Paint(w, h)
				surface.SetDrawColor(122, 219, 105)
				surface.DrawRect(0, 0, w, h)

				if self:IsHovered() then
					surface.SetDrawColor(MTA.TextColor)
					surface.DrawOutlinedRect(0, 0, w, h, 2)
				end
			end

			function btn_prestige:DoClick()
				net.Start(NET_PRESTIGE)
				net.SendToServer()
			end

			local btn_cancel = self:Add("DButton")
			btn_cancel:SetText("Cancel")
			btn_cancel:SetFont("Trebuchet24")
			btn_cancel:SetColor(MTA.TextColor)
			btn_cancel:SetPos(270, self:GetTall() - 60)
			btn_cancel:SetSize(150, 30)
			function btn_cancel:Paint(w, h)
				surface.SetDrawColor(219, 105, 105)
				surface.DrawRect(0, 0, w, h)

				if self:IsHovered() then
					surface.SetDrawColor(MTA.TextColor)
					surface.DrawOutlinedRect(0, 0, w, h, 2)
				end
			end

			btn_cancel.DoClick = function() self:Close() end
		end

		vgui.Register("mta_prestige", PANEL, "DFrame")
	end

	local function show_dealer_frame(npc)
		local frame = vgui.Create("mta_shop")
		frame:SetSize(640, 480)
		frame:Center()
		frame:DockPadding(5, 30, 5, 30)
		frame:SetTitle("MTA Dealer")
		frame:MakePopup()
		frame.btnMinim:Hide()
		frame.btnMaxim:Hide()

		frame:SetHeader(npc, [[Pssst... Hey kid, interested in some upgrades? I got plenty of things here.
		What? What's MTA? That's the system in place to prevent you from rebelling against the gov' of course!]])

		-- actions
		do
			local function add_action(description, action, callback)
				local panel = frame.Content:Add("DPanel")
				panel:Dock(TOP)
				panel:DockMargin(0, 10, 0, 0)
				panel:SetTall(50)

				local label = panel:Add("DLabel")
				label:Dock(LEFT)
				label:DockMargin(10, 5, 5, 5)
				label:SetText(description)
				label:SetWide(400)

				local btn = panel:Add("DButton")
				btn:Dock(RIGHT)
				btn:DockMargin(5, 5, 5, 5)
				btn:SetText(action)
				btn:SetTextColor(MTA.TextColor)
				btn:SetWide(125)
				btn.DoClick = callback
				btn.Description = label

				return btn
			end

			local btn_prestige = add_action("Upgrade your \"Criminal Prestige\"", "Upgrade", function()
				local popup = vgui.Create("mta_prestige")
				popup:Center()
				popup:MakePopup()
			end)
			function btn_prestige:Think()
				self:SetDisabled(not can_prestige_upgrade())
			end

			add_action("Convert points to coins", "Convert", function()
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

			local btn_refill = add_action("Refill your current weapon's clip (ammo)", "Buy (400c)", function()
				net.Start(NET_REFILL_WEAPON)
				net.WriteBool(false)
				net.SendToServer()
				surface.PlaySound("ui/buttonclick.wav")
			end)
			function btn_refill:Think()
				local lp = LocalPlayer()
				if not lp.GetCoins then return end

				self:SetDisabled(lp:GetCoins() < 400)
			end

			local btn_refill_all = add_action("Refill all your weapon clips (ammo)", "Buy", function()
				net.Start(NET_REFILL_WEAPON)
				net.WriteBool(true)
				net.SendToServer()
				surface.PlaySound("ui/buttonclick.wav")
			end)
			function btn_refill_all:Think()
				local lp = LocalPlayer()
				if not lp.GetCoins then return end
				local price = #lp:GetWeapons() * 400
				self:SetText(("Buy (%dc)"):format(price))
				self:SetDisabled(lp:GetCoins() < price)
			end
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
		if IS_MTA_GM then return end -- the gamemode has its own thing

		local npc = get_dealer_npc()
		if not IsValid(npc) then return end

		local bind = MTA.GetBindKey("+use")
		if not bind then return end

		local text = ("/// Dealer [%s] ///"):format(bind)
		MTA.ManagedHighlightEntity(dealer_npc, text, MTA.TextColor)
	end)

	net.Receive(NET_MTA_GUI, function()
		local dealer = net.ReadEntity()
		show_dealer_frame(dealer)
	end)

	local CANNON_AMT = 50
	local PARTICLES_AMT = 25
	local function do_prestige_effects(ply)
		local beam_point_origin_1 = ClientsideModel("models/props_junk/PopCan01a.mdl", RENDERGROUP_OPAQUE)
		beam_point_origin_1:SetNoDraw(true)
		SafeRemoveEntityDelayed(beam_point_origin_1, 10)

		local beam_point_origin_2 = ClientsideModel("models/props_junk/PopCan01a.mdl", RENDERGROUP_OPAQUE)
		beam_point_origin_2:SetNoDraw(true)
		SafeRemoveEntityDelayed(beam_point_origin_2, 10)

		for i = 1, CANNON_AMT do
			local ang = ((i * 36) * math.pi) / 180
			local turn = Vector(math.sin(ang), math.cos(ang), 0) * 2
			timer.Simple(i / CANNON_AMT, function()
				if not IsValid(ply) then return end
				beam_point_origin_1:SetPos(ply:GetPos() + Vector(0, 0,1000) + turn)
				beam_point_origin_2:SetPos(ply:GetPos() + Vector(0, 0,1000 * (CANNON_AMT - i) / CANNON_AMT) + turn)
				ply:CreateParticleEffect("Weapon_Combine_Ion_Cannon", {
					{ entity = beam_point_origin_1, attachtype = PATTACH_ABSORIGIN_FOLLOW },
					{ entity = beam_point_origin_2, attachtype = PATTACH_ABSORIGIN_FOLLOW },
				})
			end)
		end

		timer.Simple(1,function()
			if not IsValid(ply) then return end

			ParticleEffectAttach("Weapon_Combine_Ion_Cannon_Explosion", PATTACH_ABSORIGIN_FOLLOW, ply, 0)
			ply:EmitSound("npc/env_headcrabcanister/explosion.wav")
		end)

		timer.Simple(2, function()
			if not IsValid(ply) then return end

			local center = ply:GetPos() - Vector(0,0,50)
			local emitter = ParticleEmitter(center)
			for i = 1, PARTICLES_AMT do
			local part = emitter:Add("sprites/light_glow02_add", center + Vector(math.sin(i / PARTICLES_AMT * 2 * math.pi), math.cos(i / PARTICLES_AMT * 2 * math.pi), 0) * 50)
				if part then
					local c = MTA.PrimaryColor
					part:SetColor(c.r, c.g, c.b, c.a)
					part:SetVelocity(Vector(0, 0, 100))
					part:SetDieTime(3)
					part:SetLifeTime(0)
					part:SetStartSize(10)
					part:SetEndSize(0)
				end
			end
			emitter:Finish()

			ParticleEffectAttach("bday_confetti", PATTACH_ABSORIGIN_FOLLOW, ply, 0)
			local data = EffectData()
			data:SetOrigin(ply:GetPos())
			util.Effect("HelicopterMegaBomb",data)

			timer.Create("mta_prestige_particles_" .. ply:EntIndex(), 0.5, 5, function()
				ParticleEffectAttach("bday_confetti", PATTACH_ABSORIGIN_FOLLOW, ply, 0)
				util.Effect("cball_explode", data)
			end)

			ply:EmitSound("mta/prestige.ogg", 300)
		end)
	end

	net.Receive(NET_PRESTIGE, function()
		local ply = net.ReadEntity()
		if IsValid(ply) then
			do_prestige_effects(ply)
		end
	end)
end