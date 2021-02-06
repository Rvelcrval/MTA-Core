-- DB SCHEME
--[[
CREATE TABLE mta_user_weapons (
	id INTEGER NOT NULL PRIMARY KEY,
	classes TEXT NOT NULL DEFAULT ''
)
]]--

local tag = "mta_weapons"

local function clear_empty_classes(tbl)
	for i, class in pairs(tbl) do
		if class:Trim() == "" then
			table.remove(tbl, i)
		end
	end
end

local NET_WEAPONS_TRANSMIT = "MTA_WEAPONS_TRANSMIT"
if SERVER then
	util.AddNetworkString(NET_WEAPONS_TRANSMIT)

	local function can_db()
		return _G.db and _G.co
	end

	MTA.Weapons = {}
	MTA.Weapons.Classes = {}

	function MTA.Weapons.Save(ply, classes)
		clear_empty_classes(classes)

		local str_classes = table.concat(classes, ";")
		net.Start(NET_WEAPONS_TRANSMIT)
		net.WriteString(str_classes)
		net.Send(ply)

		MTA.Weapons.Classes[ply] = classes

		if not can_db() then return end
		co(function()
			db.Query(("UPDATE mta_user_weapons SET classes = '%s' WHERE id = %d;"):format(str_classes, ply:AccountID()))
		end)
	end

	function MTA.Weapons.Init(ply)
		if not can_db() then return {} end
		co(function()
			local ret = db.Query(("SELECT * FROM mta_user_weapons WHERE id = %d;"):format(ply:AccountID()))[1]
			if ret and ret.classes then
				local classes = ret.classes:Split(";")
				MTA.Weapons.Classes[ply] = classes

				net.Start(NET_WEAPONS_TRANSMIT)
				net.WriteString(ret.classes)
				net.Send(ply)
			else
				db.Query(("INSERT INTO mta_user_weapons(id, classes) VALUES(%d, '');"):format(ply:AccountID()))
			end
		end)
	end

	function MTA.Weapons.Get(ply)
		return MTA.Weapons.Classes[ply] or {}
	end

	net.Receive(NET_WEAPONS_TRANSMIT, function(_, ply)
		local class = net.ReadString()
		if class:Trim() == "" then return end

		local cur_classes = MTA.Weapons.Get(ply)
		table.insert(cur_classes, class)

		MTA.Weapons.Save(ply, cur_classes)
	end)

	hook.Add("MTAPlayerStatsInitialized", tag, MTA.Weapons.Init)
	hook.Add("PlayerDisconnected", tag, function(ply) MTA.Weapons.Classes[ply] = nil end)

	local function give_weapon(ply, weapon_class)
		local wep = ply:HasWeapon(weapon_class) and ply:GetWeapon(weapon_class) or ply:Give(weapon_class)
		if not IsValid(wep) then return end
		wep.unrestricted_gun = true
		wep.lobbyok = true
		wep.PhysgunDisabled = true
		wep.dont_televate = true
		wep:SetClip1(wep.GetMaxClip1 and wep:GetMaxClip1() or 10)
		wep:SetClip2(2)
		ply:SelectWeapon(weapon_class)
	end

	if IS_MTA_GM then
		hook.Add("PlayerLoadout", tag, function(ply)
			for _, weapon_class in pairs(MTA.Weapons.Get(ply)) do
				give_weapon(ply, weapon_class)
			end
		end)
	else
		hook.Add("MTAWantedStateUpdate", tag, function(ply, is_wanted)
			if not is_wanted then return end
			for _, weapon_class in pairs(MTA.Weapons.Get(ply)) do
				give_weapon(ply, weapon_class)
			end
		end)
	end
end

if CLIENT then
	MTA.Weapons = MTA.Weapons or {}

	net.Receive(NET_WEAPONS_TRANSMIT, function()
		local classes = net.ReadString():Split(";")
		clear_empty_classes(classes)

		MTA.Weapons = {}
		for _, class in pairs(classes) do
			MTA.Weapons[class] = true
		end
	end)
end