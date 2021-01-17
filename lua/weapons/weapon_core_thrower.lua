AddCSLuaFile()

SWEP.PrintName = "Core Thrower"
SWEP.Author = "Earu"
SWEP.Instructions = "Left mouse to fire a core!"
SWEP.Spawnable = false
SWEP.AdminOnly = true
SWEP.Weight	= 1
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom	= false
SWEP.Slot = 1
SWEP.SlotPos = 2
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true
SWEP.ViewModel = "models/weapons/v_ut2k4_shock_rifle.mdl"
SWEP.WorldModel	= "models/weapons/w_ut2k4_shock_rifle.mdl"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"

function SWEP:PrimaryAttack()
	self.Weapon:SetNextPrimaryFire(CurTime() + 0.1)
	self:ThrowCore()
end

function SWEP:SecondaryAttack()
end

function SWEP:Obliterate(ent)
	if not IsValid(ent) then return end
	if not ent:GetNWBool("MTACombine") then return end

	local dmg = DamageInfo()
	dmg:SetDamage(2e9)
	dmg:SetDamageForce(VectorRand() * 100)
	dmg:SetDamageType(DMG_DISSOLVE)
	dmg:SetAttacker(self:GetOwner())
	dmg:SetInflictor(self)

	ent:TakeDamageInfo(dmg)
end

local core_color = Color(200, 20, 75)
function SWEP:AttachCore(parent)
	local core = ents.Create("meta_core")
	core:SetPos(parent:GetPos())
	core:SetParent(parent)
	core:Spawn()
	core.lobbyok = true
	core:SetColor(core_color)
	core:SetSize(10)
	if core.CPPISetOwner then
		core:CPPISetOwner(self:GetOwner())
	end
	parent.lobbyok = true
	parent.IsThrownCore = true

	core.Dissolver:SetKeyValue("dissolvetype", "2")
	core.Trigger.Touch = function(_, ent)
		if ent:GetClass() == "meta_core" or ent.IsThrownCore then return end
		if not IsValid(self) then return end
		if IsValid(self:GetOwner()) and ent == self:GetOwner() then return end
		local dist = ent:WorldSpaceCenter():Distance(core:GetPos()) / 2 / 4
		if dist <= core:GetSize() and ent:IsNPC() then
			self:Obliterate(ent)
		end
	end

	core.Think = function(self)
		if IsValid(parent) and not util.IsInWorld(parent:GetPos()) then
			parent:Remove()
			return
		end

		local phys = parent:GetPhysicsObject()
		if not IsValid(phys) then return end
		local vel = phys:GetVelocity()
		phys:SetVelocity(vel:GetNormalized() * 9999)

		self:NextThink(CurTime())
		return true
	end
end

function SWEP:ThrowCore()
	self:EmitSound("ut2k4/shockrifle/altfire.wav")
	if CLIENT then return end

	local ent = ents.Create("prop_physics")
	if not IsValid(ent)then return end
	ent:SetModel("models/hunter/blocks/cube025x025x025.mdl")
	local owner = self:GetOwner()
	ent:SetPos(owner:EyePos() + (owner:GetAimVector() * 50))
	ent:Spawn()
	ent:SetNoDraw(true)
	--ent:SetNotSolid(true)
	if ent.CPPISetOwner then
		ent:CPPISetOwner(owner)
	end
	self:AttachCore(ent)

	local phys = ent:GetPhysicsObject()
	if not IsValid(phys) then ent:Remove() return end

	phys:SetVelocity(owner:GetAimVector() * 9999)
	phys:EnableGravity(false)
	phys:EnableCollisions(false)

	SafeRemoveEntityDelayed(ent, 3)
end

function SWEP:Deploy()
	self:SetHoldType("rpg")
end

function SWEP:OnDrop()
	SafeRemoveEntity(self)
end

function SWEP:Equip()
	SafeRemoveEntity(self)
end

if SERVER then
	hook.Add("EntityTakeDamage", "mta_weapon_core_thrower", function(ent, dmg)
		if not ent:IsPlayer() then return end
		local inflictor = dmg:GetInflictor()
		if IsValid(inflictor) and inflictor:GetClass() == "meta_core" and inflictor.IsThrownCore then
			return true
		end
	end)
end