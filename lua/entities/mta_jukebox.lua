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

local NET_JUKEBOX = "MTA_JUKEBOX"

if SERVER then
	resource.AddFile("models/fallout3/jukebox.mdl")
	resource.AddFile("materials/fallout3/jukebox_body.vmt")
	resource.AddFile("materials/fallout3/jukebox_menu.vmt")

	util.AddNetworkString(NET_JUKEBOX)

	function ENT:Initialize()
		self:SetModel("models/fallout3/jukebox.mdl")
		self:SetModelScale(0.75)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_WORLD)
		self:SetUseType(SIMPLE_USE)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:Wake()
			phys:EnableMotion(false)
		end
	end

	function ENT:Use(activator)
		if not activator:IsPlayer() then return end

		net.Start(NET_JUKEBOX)
		net.Send(activator)
	end
end

if CLIENT then
	pcall(include, "autorun/translation.lua")
	local L = translation and translation.L or function(s) return s end

	local color_white = Color(255, 255, 255)
	local verb = L"Jukebox"
	function ENT:Initialize()
		hook.Add("HUDPaint", self, function()
			if MTA.IsOptedOut() then return end

			local bind = MTA.GetBindKey("+use")
			if not bind then return end

			local text = ("/// %s [%s] ///"):format(verb, bind)
			MTA.ManagedHighlightEntity(self, text, color_white)
		end)
	end

	net.Receive(NET_JUKEBOX, function()

	end)
end