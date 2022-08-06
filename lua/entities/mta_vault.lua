AddCSLuaFile()

local tag = "mta_vault"

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Author = "Earu"
ENT.Spawnable = false
ENT.AdminSpawnable = false
ENT.ms_notouch = true
ENT.lobbyok = true
ENT.PhysgunDisabled = true

if SERVER then
	resource.AddFile("models/props_mta/mta_vault/mta_vault.mdl")
	resource.AddFile("materials/models/props_mta/mta_vault/vault_metal.vmt")
	resource.AddFile("materials/models/props_mta/mta_vault/vault_misc.vmt")
	resource.AddFile("materials/models/props_mta/mta_vault/vault_normal.vtf")

	function ENT:Initialize()
		self:SetModel("models/props_mta/mta_vault/mta_vault.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)

		local phys = self:GetPhysicsObject()
		if phys:IsValid() then
			phys:Wake()
			phys:EnableMotion(false)
		end

		self:SetNWBool("CanDrill", true)
		self:SetNWInt("DrillingProgress", 0)
		self:SetNWBool("Drilling", false)
		self:SetNWEntity("DrillingPlayer", NULL)

		if not IS_MTA_GM then
			SafeRemoveEntityDelayed(self, 1)
		end
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_ALWAYS
	end

	function ENT:ResetDrill()
		self:SetNWBool("CanDrill", true)
		self:SetNWInt("DrillingProgress", 0)
		self:SetNWBool("Drilling", false)
		self:SetNWEntity("DrillingPlayer", NULL)

		self:SetSequence(0)
		self:SetCycle(0)
	end

	function ENT:StartDrill(ply)
		self:SetNWInt("DrillingProgress", 0)
		self:SetNWBool("Drilling", true)
		self:SetNWEntity("DrillingPlayer", ply)
		ply:SetNWEntity("MTAVault", self)
		ply.MTAVaultStreak = math.min((ply.MTAVaultStreak or 0) + 1, 3)
		MTA.DisallowPlayerEscape(ply)
		MTA.IncreasePlayerFactor(ply, 10)

		hook.Run("MTADrillStart", ply, self)
		MTA.Print(("%s started drilling a vault"):format(ply))
	end

	function ENT:Think()
		if not self:GetNWBool("CanDrill", true) then return end
		if not self:GetNWBool("Drilling", false) then return end

		local effect_data = EffectData()
		effect_data:SetOrigin(self:WorldSpaceCenter() + Vector(0, 0, 10) + self:GetForward() * 15)
		effect_data:SetEntity(self)
		effect_data:SetNormal(self:GetForward())
		effect_data:SetScale(25)
		util.Effect("MetalSpark", effect_data)

		self:NextThink(CurTime() + 0.05)
		return true
	end

	local function explode(vault)
		if not IsValid(vault) then return end
		local explosion = ents.Create("env_explosion")
		explosion:SetPos(vault:WorldSpaceCenter())
		explosion:Spawn()
		explosion:Fire("explode")
	end

	function ENT:Explode()
		explode(self)
		timer.Simple(0.1, function() explode(self) end)
		timer.Simple(0.3, function()
			explode(self)
			if coins and coins.Create then
				coins.Create(self:WorldSpaceCenter() + self:GetForward() * 20, math.random(10000, 100000), "MTA Vault")
			end
			self:SetSequence(1)
			self:SetCycle(1)
		end)
	end

	local function stop_drill(ply)
		local vault = ply:GetNWEntity("MTAVault")
		if not IsValid(vault) then return end

		ply.MTAVaultStreak = 0
		ply:SetNWEntity("MTAVault", NULL)
		MTA.AllowPlayerEscape(ply)
		vault:ResetDrill()
		timer.Remove(("MTA_VAULT_%d_%s"):format(vault:EntIndex(), ply:SteamID()))
		hook.Run("MTADrillFailed", ply, vault)
	end

	local VAULT_DISTANCE_LIMIT = 3000
	function ENT:AcceptInput(input_name, activator)
		if not MTA.IsEnabled() then return end
		if input_name ~= "Use" then return end

		if not activator:IsPlayer() then return end
		if MTA.IsOptedOut(activator) then return end

		if not self:GetNWBool("CanDrill", true) then return end
		if self:GetNWBool("Drilling", false) then return end
		if IsValid(activator:GetNWEntity("MTAVault")) then return end

		if IS_MTA_GM then
			local succ, x, y = MTA.Inventory.FindItemSlot(activator, "drill")
			if not succ then return end

			if not MTA.Inventory.RemoveItem(activator, "drill", x, y, 1) then return end
		end

		self:StartDrill(activator)
		timer.Create(("MTA_VAULT_%d_%s"):format(self:EntIndex(), activator:SteamID()), 3, 100, function()
			if IsValid(self) and IsValid(activator) then
				if activator:GetPos():Distance(self:GetPos()) >= VAULT_DISTANCE_LIMIT then
					stop_drill(activator)
					return
				end

				local progress = self:GetNWInt("DrillingProgress", 0) + 1 -- done in 5 mins
				self:SetNWInt("DrillingProgress", progress)
				MTA.IncreasePlayerFactor(activator, 4 * math.min(activator.MTAVaultStreak or 1, 3))

				if progress == 100 then
					self:Explode()
					MTA.ChatPrint(activator, "The vault has been successfully drilled, hurry and get your money!")
					self:SetNWBool("CanDrill", false)
					activator:SetNWEntity("MTAVault", NULL)
					MTA.AllowPlayerEscape(activator)
					MTA.GivePoints(activator, 100 * math.min(activator.MTAVaultStreak or 1, 3))
					timer.Simple(600, function()
						if IsValid(self) then self:ResetDrill() end
					end)
					hook.Run("MTADrillSuccess", activator, self)
				end
			end
		end)

		return true
	end

	function ENT:OnRemove()
		local ply = self:GetNWEntity("DrillingPlayer")
		if IsValid(ply) then
			stop_drill(ply)
		end
	end

	hook.Add("MTAPlayerFailed", tag, stop_drill)
	hook.Add("MTAReset", tag, function()
		for _, vault in pairs(ents.FindByClass("mta_vault")) do
			local ply = vault:GetNWEntity("DrillingPlayer")
			if IsValid(ply) then
				stop_drill(ply)
			end
		end
	end)
end

if CLIENT then
	pcall(include, "autorun/translation.lua")
	local L = translation and translation.L or function(s) return s end

	local drill_base = ClientsideModel("models/props_combine/combine_mine01.mdl")
	drill_base:SetNoDraw(true)

	local drill = ClientsideModel("models/Items/combine_rifle_ammo01.mdl")
	drill:SetNoDraw(true)

	function ENT:Draw()
		self:DrawModel()

		if self:GetNWBool("CanDrill", false) and self:GetNWBool("Drilling", false) then
			local progress = self:GetNWInt("DrillingProgress", 0)

			local pos = self:WorldSpaceCenter() + Vector(0, 0, 10) + self:GetForward() * 15
			local ang = self:GetAngles()
			ang:RotateAroundAxis(ang:Right(), -90)

			drill_base:SetPos(pos)
			drill_base:SetAngles(ang)
			drill_base:DrawModel()

			pos:Add(ang:Up() * (20 - 10 * progress / 100))

			ang:RotateAroundAxis(ang:Right(), 180)

			ang:RotateAroundAxis(ang:Up(), CurTime() * 500)

			drill:SetPos(pos)
			drill:SetAngles(ang)
			drill:DrawModel()
		end
	end

	local MIN_INDICATOR_DIST = 300
	local function show_vault_indicator(vault)
		if not vault:GetNWBool("CanDrill", true) then return false end
		if vault.CachedIndicatorCheck ~= nil and vault.NextCache > CurTime() then return vault.CachedIndicatorCheck end

		vault.CachedIndicatorCheck = false
		vault.NextCache = CurTime() + 0.5

		local lp_vault = LocalPlayer():GetNWEntity("MTAVault", NULL)
		if IsValid(lp_vault) and lp_vault == vault then
			vault.CachedIndicatorCheck = true
		elseif vault:WorldSpaceCenter():Distance(LocalPlayer():WorldSpaceCenter()) <= MIN_INDICATOR_DIST then
			vault.CachedIndicatorCheck = true
		end

		return vault.CachedIndicatorCheck
	end

	local verb = L"Drill"
	hook.Add("HUDPaint", tag, function()
		if MTA.IsOptedOut() then return end

		local bind = MTA.GetBindKey("+use")
		if not bind then return end

		for _, vault in ipairs(ents.FindByClass("mta_vault")) do
			if show_vault_indicator(vault) then
				if not vault:GetNWBool("Drilling", false) then
					if IS_MTA_GM and not MTA.Inventory.HasItem(LocalPlayer(), "drill", 1) then
						local text = ("/// You don't have a drill! ///"):format(verb, bind)
						MTA.HighlightEntity(vault, text, MTA.DangerColor)
					else
						local text = ("/// %s [%s] ///"):format(verb, bind)
						MTA.HighlightEntity(vault, text, MTA.PrimaryColor)
					end
				else
					local driller = vault:GetNWEntity("DrillingPlayer", NULL)
					local driller_nick = IsValid(driller) and driller:Nick() or "???"
					local text = ("/// %s's %s: %d%% ///"):format(driller_nick, verb, vault:GetNWInt("DrillingProgress", 0))
					MTA.HighlightEntity(vault, text, MTA.PrimaryColor)
				end
			end
		end
	end)
end