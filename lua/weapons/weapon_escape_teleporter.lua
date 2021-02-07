AddCSLuaFile()

SWEP.PrintName = "Escape Teleporter"
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
SWEP.ViewModel = ""
SWEP.WorldModel = "models/maxofs2d/hover_rings.mdl"
SWEP.UseHands = true

SWEP.Primary = {}
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"

SWEP.Secondary = {}
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Ammo = "none"

function SWEP:PrimaryAttack()
end

function SWEP:SecondaryAttack()
end

function SWEP:Think()
end

function SWEP:Deploy()
	self:SetHoldType("slam")
end

if SERVER then
	function SWEP:Initialize()
		self:SetModel("models/maxofs2d/hover_rings.mdl")
		self:SetModelScale(0.3)
	end

	function SWEP:PrimaryAttack()
		local owner = self:GetOwner()
		if not IsValid(owner) then return end
		if not owner:IsPlayer() then return end
		if not MTA.IsWanted(owner) then return end

		if not MTA.CanPlayerEscape(owner) then
			MTA.ChatPrint(owner, "You cannot currently teleport!")
			self:SetNextPrimaryFire(CurTime() + 2)
			return
		end

		self:SetNextPrimaryFire(CurTime() + 120)

		local teleporter_area = ents.Create("mta_teleporter_area")
		teleporter_area:SetPos(owner:GetPos() + Vector(0, 0, 5))
		teleporter_area:Spawn()
		teleporter_area:SetPlayer(owner)

		local phys = teleporter_area:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(false)
		end
	end
end