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

	local status_color = Color(109, 169, 214)
	local function do_emp(ply)
		if not IsValid(ply) then return end

		local ret = hook.Run("MTACanMobileEMP", ply)
		if ret == false then return end

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
			if not ent:IsNPC() then continue end
			if hook.Run("MTAMobileEMPShouldDamage", ply, ent, shockwave:GetPos()) then
				ent:TakeDamageInfo(dmg_info)
			elseif ent:GetClass() == "npc_manhack" then
				ent:TakeDamageInfo(dmg_info)
			elseif ent:GetNWBool("MTACombine") then
				local wep = ent.GetActiveWeapon and ent:GetActiveWeapon()
				if IsValid(wep) then
					ent.MTAEMP = true
					timer.Simple(INTERVAL / 2, function()
						if not IsValid(ent) then return end
						ent.MTAEMP = nil
					end)
				end
			end
		end

		if IS_MTA_GM then
			MTA.Statuses.AddStatus(ply, "emp", "Mobile EMP", status_color, CurTime() + INTERVAL)
		end
	end

	local function get_timer_id(ply)
		return ("MTASkill_MobileEMP_%d"):format(ply:AccountID())
	end

	hook.Add("MTAStatIncrease", "MTASkill_MobileEMP", function(ply)
		if MTA.IsWanted(ply) and MTA.HasSkill(ply, "defense_multiplier", "mobile_emp") then
			local timer_id = get_timer_id(ply)
			if timer.Exists(timer_id) then return end

			if IS_MTA_GM then
				MTA.Statuses.AddStatus(ply, "emp", "Mobile EMP", status_color, CurTime() + INTERVAL)
			end

			timer.Create(timer_id, INTERVAL, 0, function() do_emp(ply) end)
		end
	end)

	hook.Add("MTAWantedStateUpdate", "MTASkill_MobileEMP", function(ply, is_wanted)
		local timer_id = get_timer_id(ply)
		if is_wanted and MTA.HasSkill(ply, "defense_multiplier", "mobile_emp") then
			if IS_MTA_GM then
				MTA.Statuses.AddStatus(ply, "emp", "Mobile EMP", status_color, CurTime() + INTERVAL)
			end

			timer.Create(timer_id, INTERVAL, 0, function() do_emp(ply) end)
		elseif not is_wanted then
			timer.Remove(timer_id)

			if IS_MTA_GM then
				MTA.Statuses.RemoveStatus(ply, "emp")
			end
		end
	end)

	hook.Add("EntityFireBullets", "MTASkill_MobileEMP", function(ent)
		if ent:GetNWBool("MTACombine") and ent.MTAEMP then return false end
	end)
end

if CLIENT then
	language.Add("mta_mobile_emp", "Mobile EMP")
end

scripted_ents.Register(ENT, "mta_mobile_emp")
MTA.RegisterSkill("mobile_emp", "defense_multiplier", 25, "Mobile EMP", ("Fires an electro-magnetic shockwave breaking all nearby manhacks and disabling combine weapons every %d seconds"):format(INTERVAL))