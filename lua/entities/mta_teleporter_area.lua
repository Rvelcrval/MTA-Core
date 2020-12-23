AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Author = "Earu"
ENT.Spawnable = false
ENT.AdminSpawnable = false
ENT.ms_notouch = true
ENT.lobbyok = true
ENT.PhysgunDisabled = true
ENT.dont_televate = true

local TIME_TO_TELEPORT = 20

if SERVER then
	function ENT:Initialize()
		self.NextTeleportCheck = 0
		self.TeleportTime = 0

		self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_VPHYSICS)
		self:SetUnFreezable(true)
		self:SetModel("models/hunter/plates/plate6x6.mdl")
		self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		self:DrawShadow(false)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:PhysWake()

		local trigger = ents.Create("base_brush")
        trigger:SetPos(self:GetPos())
        trigger:SetParent(self)
        trigger:SetTrigger(true)
        trigger:SetSolid(SOLID_BBOX)
		trigger:SetNotSolid(true)

		local maxs = self:OBBMaxs() / 2
		maxs.z = 150
		trigger:SetCollisionBounds(self:OBBMins() / 2, maxs)

		trigger.EndTouch = function(_, ent) self:EndTouch(ent) end
		self.Trigger = trigger
	end

	function ENT:SetPlayer(ply)
		if not IsValid(ply) then return end

		self.Player = ply
		self.Rings = {}
		for i = 1, 5 do
			local ring = ents.Create("prop_physics")
			ring:SetModel("models/props_lab/teleportring.mdl")
			ring:SetPos(ply:GetPos() + Vector(0, 0, 10) * i + Vector(0, 0, 10))
			ring:SetSkin(2)
			ring:SetMoveType(MOVETYPE_NONE)
			ring:SetRenderMode(RENDERMODE_TRANSCOLOR)
			ring:SetColor(Color(0, 0, 0, 0))
			ring.Direction = i % 2 == 0 and 1 or -1
			table.insert(self.Rings, ring)
		end

		self:EmitSound("ambient/levels/labs/teleport_mechanism_windup1.wav")
		self:EmitSound("ambient/levels/labs/teleport_active_loop1.wav")

		local filter = RecipientFilter()
		filter:AddPlayer(ply)
		self.LoopSound = CreateSound(self, "ambient/levels/labs/teleport_active_loop1.wav", filter)
		self.LoopSound:ChangeVolume(0)
		self.LoopSound:ChangePitch(75)
		self.LoopSound:Play()

		self.LoopSound:ChangeVolume(1, TIME_TO_TELEPORT)
		self.LoopSound:ChangePitch(200, TIME_TO_TELEPORT)
	end

	function ENT:EndTouch(ent)
		if ent == self.Player then
			self:EmitSound("ambient/energy/zap9.wav")
			self:EmitSound("ambient/energy/power_off1.wav")
			self:Remove()
		end
	end

	function ENT:Think()
		if not IsValid(self.Player) then
			self:Remove()
		end

		if not self.Rings then return end
		if CurTime() >= self.NextTeleportCheck then
			self.TeleportTime = self.TeleportTime + 1
			self.NextTeleportCheck = CurTime() + 1
		end

		if not self.FinalSoundsPlayed and self.TeleportTime > (TIME_TO_TELEPORT - 9) then
			self:EmitSound("ambient/levels/labs/teleport_mechanism_windup5.wav")
			self.FinalSoundsPlayed = true
		end

		local pos = self.Player:GetPos()
		for _, ring in ipairs(self.Rings) do
			if self.TeleportTime > (TIME_TO_TELEPORT / 2) then
				ring:SetSkin(1)
			end

			local alpha = 50 + ((TIME_TO_TELEPORT / 255) * self.TeleportTime * 2 * 100)
			ring:SetColor(Color(255, 255, 255, alpha))
			ring:SetPos(Vector(pos.x, pos.y, ring:GetPos().z))

			local ang = ring:GetAngles()
			ring:SetAngles(Angle(0, ang.yaw + (ring.Direction * self.TeleportTime * 2), 0))
		end

		if self.TeleportTime >= TIME_TO_TELEPORT then
			self:EmitSound("ambient/machines/teleport" .. math.random(1, 4) .. ".wav")
			self.Player:ConCommand("aowl goto dealer")
			local internal_factor = self.Player:GetNWInt("MTAFactor") * 10
			MTA.DecreasePlayerFactor(self.Player, internal_factor)
			self.Player:EmitSound("ambient/machines/teleport" .. math.random(1, 4) .. ".wav")
			self:Remove()
		end

		self:NextThink(CurTime())
		return true
	end

	function ENT:OnRemove()
		self.LoopSound:Stop()
		if not self.Rings then return end
		for _, ring in ipairs(self.Rings) do
			SafeRemoveEntity(ring)
		end
	end
end

if CLIENT then
	local text = "Teleporting..."
	function ENT:Draw()
		if MTA.IsOptedOut() then return end

		local alpha = 50 + math.abs((math.sin(CurTime() * 3) * 150))
		local pos = self:GetPos() - (self:GetForward()) * 100 - (self:GetRight() * 100)
		cam.Start3D2D(pos, self:GetAngles(), 0.5)
			surface.SetDrawColor(255, 0, 0, alpha)
			surface.DrawOutlinedRect(0, 0, 400, 400, 5)

			surface.SetDrawColor(200, 0, 0, alpha - 150)
			surface.DrawRect(0, 0, 400, 400)

			surface.SetTextColor(255, 0, 0, alpha)
			surface.SetFont("DermaLarge")

			local tw, th = surface.GetTextSize(text)
			surface.SetTextPos(200 - tw / 2, 200 - th / 2)
			surface.DrawText(text)
		cam.End3D2D()
	end
end