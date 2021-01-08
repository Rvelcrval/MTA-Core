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
local FRONT_ROTATION_MARKER = 80

local function get_rotation(ply, pos)
	local diff = pos - ply:GetShootPos()
	diff.z = 0
	diff:Normalize()

	return math.abs(math.deg(math.acos(ply:EyeAngles():Forward():Dot(diff))))
end

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
		self:DrawModel()
		self:DrawCustomTexture(self:GetPos() + self:GetForward() * -0.2, self:GetAngles())
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

		local wep = ent:GetActiveWeapon()
		if IsValid(wep) and wep:GetClass() == "weapon_riot_shield" then
			local atck = dmg_info:GetAttacker()
			if dmg_info:IsExplosionDamage() and get_rotation(ent, atck:WorldSpaceCenter()) < FRONT_ROTATION_MARKER then
				return true
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

weapons.Register(SWEP, "weapon_riot_shield")