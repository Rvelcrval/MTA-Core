AddCSLuaFile()

ENT.Base = "base_anim"
ENT.PrintName = "Riot Shield"
ENT.Author = "Earu & Mavain"
ENT.Editable = false
ENT.Spawnable = false
ENT.AdminOnly = false
ENT.PhysgunDisabled = true
ENT.lobbyok = true

if SERVER then
	resource.AddFile("materials/models/cloud/ballshield.vmt")
	resource.AddFile("materials/models/cloud/riotshield_mod.vmt")
	resource.AddFile("materials/models/cloud/shieldglass.vmt")
	resource.AddFile("models/cloud/ballisticshield_mod.mdl")

	function ENT:Initialize()
		self:SetModel("models/cloud/ballisticshield_mod.mdl")

		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)

		self:PhysWake()

		local ply = self:GetOwner()
		if not IsValid(ply) then return end

		local spine = ply:LookupBone("ValveBiped.Bip01_Spine")
		if spine and spine ~= -1 then
			self:FollowBone(ply, spine)
		else
			-- yikes
			self:SetParent(ply)
		end

		self:SetLocalAngles(Angle(0,-85,-90))
		self:SetLocalPos(Vector(-35, 20, 4))
	end

	function ENT:Think() end
	function ENT:PhysicsSimulate(phys, delta) end
end

if CLIENT then

	function ENT:Initialize()
		self:SetPredictable(true)

		if not self.CachedTexture then
			self.CachedTexture = {
				width = 64,
				height = 108,
				data = {}
			}
		end
	end

	function ENT:Draw()
		self:DrawModel()
	end
end