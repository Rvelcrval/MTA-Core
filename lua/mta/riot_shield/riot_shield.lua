local ENT = {}
ENT.Base = "base_anim"
ENT.PrintName = "Riot Shield"
ENT.Author = "Earu & Mavain"
ENT.Editable = false
ENT.Spawnable = false
ENT.AdminOnly = false
ENT.PhysgunDisabled = true
ENT.lobbyok = true

local MTA_SHIELD_TEXTURE_UPDATE = "MTA_SHIELD_TEXTURE_UPDATE"

local ZOFFSET = Vector(0, 0, 35)
local FORWARD_OFFSET = -20
local FRONT_ROTATION_MARKER = 50

local function get_rotation(ply, pos)
	local diff = pos - ply:GetShootPos()
	diff.z = 0
	diff:Normalize()

	return math.abs(math.deg(math.acos(ply:EyeAngles():Forward():Dot(diff))))
end

local function compute_params(ply)
	local ang = ply:EyeAngles()
	ang.pitch = 0
	ang.yaw = ang.yaw + 180

	local pos = ply:WorldSpaceCenter() + ang:Right() * 5 - ZOFFSET
	local vel = ply:GetVelocity()
	if vel:Length2DSqr() == 0 then
		pos = pos + ang:Forward() * FORWARD_OFFSET
	else
		if get_rotation(ply, pos + vel) < FRONT_ROTATION_MARKER then
			local multiplier = SERVER and 40 or 20 -- account for server delay
			pos = pos + (vel:GetNormalized() * multiplier)
		end
	end

	return pos, ang
end


if SERVER then
	resource.AddFile("materials/models/cloud/ballshield.vmt")
	resource.AddFile("materials/models/cloud/riotshield_mod.vmt")
	resource.AddFile("materials/models/cloud/shieldglass.vmt")
	resource.AddFile("models/cloud/ballisticshield_mod.mdl")

	function ENT:Initialize()
		self:SetModel("models/cloud/ballisticshield_mod.mdl")

		self:EnableCustomCollisions()

		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)

		self:MakePhysicsObjectAShadow()
		self:StartMotionController()

		self:PhysWake()

		local ply = self:GetOwner()
	end

	function ENT:Think()
		local ply = self:GetOwner()
		if not IsValid(ply) then return end

		if self:WorldSpaceCenter():Distance(ply:WorldSpaceCenter()) >= 300 then
			local pos, ang = compute_params(ply)
			self:SetPos(pos)
			self:SetAngles(ang)
		end

		self:NextThink(CurTime() + 1)
		return true
	end

	function ENT:PhysicsSimulate(phys, delta)
		local ply = self:GetOwner()
		if not IsValid(ply) then return end

		phys:EnableCollisions(ply:GetMoveType() ~= MOVETYPE_NOCLIP)
		phys:Wake()

		local pos, ang = compute_params(ply)
		phys:UpdateShadow(pos, ang, delta)
	end
end

if CLIENT then

	function ENT:Initialize()
		self:EnableCustomCollisions()

		if not self.CachedTexture then
			self.CachedTexture = {
				width = 64,
				height = 108,
				data = {}
			}
		end
	end

	function ENT:DrawCustomTexture(pos, ang)
		if not MTA.ShieldTextureManager then return end

		local ply = self:GetOwner()
		if not IsValid(ply) then return end

		local cached_texture = MTA.ShieldTextureManager.Get(ply)
		if not cached_texture then return end

		if not self.CustomTexture then
			self.CustomTexture = GetRenderTarget("weapon_riot_shield_texture" .. (self:GetOwner():SteamID64() or "_BOT"),
						1024,
						1024)
			render.PushRenderTarget(self.CustomTexture)
			render.OverrideAlphaWriteEnable(true, true)
			render.ClearDepth()
			render.Clear(0, 0, 0, 0)
			render.OverrideAlphaWriteEnable(false)
			render.PopRenderTarget()
		end
		if not self.CustomMaterial then
			self.CustomMaterial = CreateMaterial("weapon_riot_shield_material" .. (self:GetOwner():SteamID64() or "_BOT"), "UnlitGeneric", {
				["$basetexture"] = self.CustomTexture:GetName(),
				["$translucent"] = 1,
				["$vertexcolor"] = 1
			})
		end

		if cached_texture ~= self.CachedTexture then

			self.CachedTexture = cached_texture

			local tex_data = self.CachedTexture

			render.PushRenderTarget(self.CustomTexture)
			render.OverrideAlphaWriteEnable(true, true)
			render.ClearDepth()
			render.Clear(0, 0, 0, 0)
				cam.Start2D()

					for y = 0, tex_data.height - 1 do
						for x = 0, tex_data.width - 1 do
							local pixel = tex_data.data[x + y * tex_data.width] or Color(0, 0, 0, 0)
							surface.SetDrawColor(pixel.r, pixel.g, pixel.b, pixel.a)
							surface.DrawRect(x, y, 1, 1)
						end
					end

				cam.End2D()
			render.OverrideAlphaWriteEnable(false)
			render.PopRenderTarget()

		end

		local cam_pos_local = Vector(-1.2, 16.2, 43.6) --ang:Forward() + ang:Up() * 44 - ang:Right() * 16
		local cam_ang_local = Angle(0, 90, -90)
		local cam_pos, cam_ang = LocalToWorld(cam_pos_local, cam_ang_local, pos, ang)
		cam.Start3D2D(cam_pos, cam_ang, -0.1)

		local scale_x = self.CachedTexture.width / self.CustomTexture:GetMappingWidth()
		local scale_y = self.CachedTexture.height / self.CustomTexture:GetMappingHeight()
		local sub_x = 0.5 / self.CustomTexture:GetMappingWidth()
		local sub_y = 0.5 / self.CustomTexture:GetMappingHeight()

		render.PushFilterMag(TEXFILTER.POINT)
		render.PushFilterMin(TEXFILTER.POINT)

		local light_normal = -ang:Forward()
		local light_pos, light_normal = pos + light_normal * 5, light_normal
		local lighting_color_vec = render.ComputeLighting(light_pos, light_normal) + render.GetAmbientLightColor()
		render.SuppressEngineLighting(true)
		surface.SetDrawColor(lighting_color_vec.x * 255, lighting_color_vec.y * 255, lighting_color_vec.z * 255, 255)
		surface.SetMaterial(self.CustomMaterial)
		surface.DrawTexturedRectUV(0, 0, 256, 430, -sub_x, -sub_y, scale_x - sub_x, scale_y - sub_y)
		render.SuppressEngineLighting(false)
		render.PopFilterMin()
		render.PopFilterMag()

		cam.End3D2D()

	end

	function ENT:Draw()
		local ply = self:GetOwner()
		if not IsValid(ply) then
			self:DrawModel()
			return
		end

		local pos, ang = compute_params(ply)
		self:SetRenderOrigin(pos)
		self:SetRenderAngles(ang)

		self:DrawModel()
		self:DrawCustomTexture(pos, ang)
	end
end

scripted_ents.Register(ENT, "mta_riot_shield")

local SWEP = {
	PrintName = "Riot Shield",
	Author = "Earu",
	Spawnable = false,
	AdminOnly = false,
	Weight = 1,
	AutoSwitchTo = false,
	AutoSwitchFrom = false,
	Slot = 1,
	SlotPos = 2,
	DrawAmmo = false,
	DrawCrosshair = false,
	ViewModel = "models/weapons/c_arms_citizen.mdl",
	WorldModel = "",
	Primary = {
		ClipSize = -1,
		DefaultClip = -1,
		Automatic = true,
		Ammo = "none"
	},
	Secondary = {
		ClipSize = -1,
		DefaultClip = -1,
		Automatic = true,
		Ammo = "none"
	},
}

function SWEP:PrimaryAttack()
end

function SWEP:SecondaryAttack()
end

function SWEP:Deploy()
	self:SetHoldType("duel")
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
end

if CLIENT then
	function SWEP:Draw() end
end

weapons.Register(SWEP, "weapon_riot_shield")