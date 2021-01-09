AddCSLuaFile()

ENT.Base = "base_anim"
ENT.PrintName = "Riot Shield"
ENT.Author = "Earu & Mavain"
ENT.Editable = false
ENT.Spawnable = false
ENT.AdminOnly = false
ENT.PhysgunDisabled = true
ENT.lobbyok = true

local MTA_SHIELD_TEXTURE_UPDATE = "MTA_SHIELD_TEXTURE_UPDATE"

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