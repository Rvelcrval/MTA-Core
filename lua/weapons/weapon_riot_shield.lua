AddCSLuaFile()

SWEP.PrintName = "Riot Shield"
SWEP.Author = "Earu"
SWEP.Spawnable = false
SWEP.AdminOnly = false
SWEP.Weight = 1
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Slot = 1
SWEP.SlotPos = 2
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.ViewModel = "models/weapons/c_arms_citizen.mdl"
SWEP.WorldModel = ""

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Ammo = "none"

function SWEP:PrimaryAttack()
end

function SWEP:SecondaryAttack()
end

local FRONT_ROTATION_MARKER = 55

local function get_rotation(ply, pos)
	local diff = pos - ply:GetShootPos()
	diff.z = 0
	diff:Normalize()

	return math.abs(math.deg(math.acos(ply:EyeAngles():Forward():Dot(diff))))
end

if SERVER then
	function SWEP:PrimaryAttack()
		self:SetNextPrimaryFire(CurTime() + 0.75)
		if not IsValid(self.MTAShield) then return end

		self.MTAShield:EmitSound(("physics/flesh/fist_swing_0%d.wav"):format(math.random(1, 6)))

		local tr = util.TraceEntity({
			start = self.MTAShield:GetPos(),
			endpos = self.MTAShield:GetPos() + self.MTAShield:GetForward() * -40,
			filter = { self.MTAShield, self, self:GetOwner() }
		}, self.MTAShield)

		local ent = tr.Entity
		if IsValid(ent) then
			self.MTAShield:EmitSound(("physics/flesh/flesh_impact_hard%d.wav"):format(math.random(1, 6)))
			if ent:IsPlayer() or ent:IsNPC() then
				if ent:IsPlayer() then
					ent:SetMoveType(MOVETYPE_WALK)
				end

				ent:SetGroundEntity(NULL)
				ent:SetVelocity(self:GetForward() * 200 + Vector(0, 0, 200))
				ent:TakeDamage(10, self:GetOwner(), self)
			else
				local phys = ent:GetPhysicsObject()
				if IsValid(phys) then
					phys:SetVelocity(self:GetForward() * 200 + Vector(0, 0, 200))
				end
			end
		end
	end

	function SWEP:Deploy()
		self:SetHoldType("duel")

		local owner = self:GetOwner()
		if not IsValid(owner) then return end
		if IsValid(self.MTAShield) then return end

		self.MTAShield = ents.Create("mta_riot_shield")
		self.MTAShield:SetPos(owner:WorldSpaceCenter())
		self.MTAShield:SetOwner(owner)
		self.MTAShield:Spawn()
		self.MTAShield:Activate()

		if owner:IsPlayer() then
			self.OriginalRunSpeed = owner:GetRunSpeed()
			self.OriginalWalkSpeed = owner:GetWalkSpeed()
			self.OwningPlayer = owner
			owner:SetRunSpeed(100)
			owner:SetWalkSpeed(100)
		end
	end

	local function remove_shield(self)
		SafeRemoveEntity(self.MTAShield)
		if IsValid(self.OwningPlayer) and self.OwningPlayer:IsPlayer() then
			self.OwningPlayer:SetRunSpeed(self.OriginalRunSpeed)
			self.OwningPlayer:SetWalkSpeed(self.OriginalWalkSpeed)
			self.OwningPlayer = nil
			self.OriginalRunSpeed = nil
			self.OriginalWalkSpeed = nil
		end
	end

	function SWEP:OnDrop()
		remove_shield(self)
	end

	function SWEP:OnRemove()
		remove_shield(self)
	end

	function SWEP:Holster()
		remove_shield(self)
		return true
	end

	hook.Add("EntityTakeDamage", "mta_riot_shield", function(ent, dmg_info)
		if not ent:IsPlayer() then return end
		if dmg_info:IsExplosionDamage() then return end
		if dmg_info:IsFallDamage() then return end

		local wep = ent:GetActiveWeapon()
		if IsValid(wep) and wep:GetClass() == "weapon_riot_shield" then
			local atck = dmg_info:GetAttacker()
			if get_rotation(ent, atck:WorldSpaceCenter()) < FRONT_ROTATION_MARKER then
				return true
			elseif not atck:IsPlayer() then
				dmg_info:ScaleDamage(0.3)
			end
		end
	end)
end

if CLIENT then
	local is_held = false

	function SWEP:Deploy()
		self:SetHoldType("duel")

		if self:IsCarriedByLocalPlayer() then
			is_held = true
		end
	end

	function SWEP:OnDrop()
		if self:IsCarriedByLocalPlayer() then
			is_held = false
		end
	end

	function SWEP:OnRemove()
		if self:IsCarriedByLocalPlayer() then
			is_held = false
		end
	end

	function SWEP:Holster()
		if self:IsCarriedByLocalPlayer() then
			is_held = false
		end
		return true
	end

	function SWEP:Draw() end

	hook.Add("HUDShouldDraw", "mta_riot_shield", function(element)
		if element == "CHudDamageIndicator" and is_held then return false end
	end)
end