local DISTANCE = MTA_CONFIG.upgrades.EMPDistance
local INTERVAL = MTA_CONFIG.upgrades.EMPInterval

local ENT = {}
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Author = "Earu"
ENT.PrintName = "Mobile EMP"
ENT.Spawnable = false
ENT.AdminSpawnable = false
ENT.ms_notouch = true
ENT.lobbyok = true
ENT.PhysgunDisabled = true
ENT.dont_televate = true

if SERVER then
	function ENT:Initialize()
		self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_VPHYSICS)
		self:SetUnFreezable(true)
		self:SetModel("models/dav0r/hoverball.mdl")
		self:SetMaterial("models/alyx/emptool_glow")
		self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		self:DrawShadow(false)
	end

	local function do_emp(ply)
		if not IsValid(ply) then return end

		local shockwave = ents.Create("mta_mobile_emp")
		shockwave:SetPos(ply:WorldSpaceCenter())
		shockwave:Spawn()

		SafeRemoveEntityDelayed(shockwave, 0.35)
		shockwave:SetModelScale(30, 0.3)

		local dmg_info = DamageInfo()
		dmg_info:SetInflictor(shockwave)
		dmg_info:SetAttacker(ply)
		dmg_info:SetDamage(1000)
		dmg_info:SetDamageType(DMG_SHOCK)

		for _, ent in ipairs(ents.FindInSphere(shockwave:GetPos(), DISTANCE)) do
			if ent:GetClass() == "npc_manhack" then
				ent:TakeDamageInfo(dmg_info)
			end
		end
	end

	local function get_timer_id(ply)
		return ("MTASkill_MobileEMP_%d"):format(ply:AccountID())
	end

	hook.Add("MTAStatIncrease", "MTASkill_MobileEMP", function(ply)
		if MTA.IsWanted(ply) and MTA.HasSkill(ply, "defense_multiplier", "mobile_emp") then
			local timer_id = get_timer_id(ply)
			if timer.Exists(timer_id) then return end
			timer.Create(timer_id, INTERVAL, 0, function() do_emp(ply) end)
		end
	end)

	hook.Add("MTAWantedStateUpdate", "MTASkill_MobileEMP", function(ply, is_wanted)
		local timer_id = get_timer_id(ply)
		if is_wanted and MTA.HasSkill(ply, "defense_multiplier", "mobile_emp") then
			timer.Create(timer_id, INTERVAL, 0, function() do_emp(ply) end)
		elseif not is_wanted then
			timer.Remove(timer_id)
		end
	end)
end

if CLIENT then
	language.Add("mta_mobile_emp", "Mobile EMP")
end

scripted_ents.Register(ENT, "mta_mobile_emp")
MTA.RegisterSkill("mobile_emp", "defense_multiplier", 25, "Mobile EMP", ("Fires an electro-magnetic shockwave breaking all nearby manhacks every %d seconds"):format(INTERVAL))