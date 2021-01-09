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

local NET_SKILL_TREE_OPEN = "MTA_SKILL_TREE_OPEN"
if SERVER then
	util.AddNetworkString(NET_SKILL_TREE_OPEN)

	function ENT:Initialize()
		self:SetModel("models/props_combine/combine_interface001.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_WORLD)
		self:SetUseType(SIMPLE_USE)

		self.Screen = ents.Create("prop_physics")
		self.Screen:SetModel("models/props_combine/combine_intmonitor001.mdl")
		self.Screen:SetPos(self:GetPos() + Vector(0, 0, 50) + self:GetForward() * -15)
		self.Screen:SetParent(self)
		self.Screen:Spawn()
		self.Screen:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
		self.Screen.lobbyok = true
		self.Screen.PhysgunDisabled = true
		self.Screen.ms_notouch = true
		self.Screen.dont_televate = true

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:Wake()
			phys:EnableMotion(false)
		end
	end

	function ENT:Use(activator)
		if not activator:IsPlayer() then return end

		net.Start(NET_SKILL_TREE_OPEN)
		net.Send(activator)
	end
end

if CLIENT then
	pcall(include, "autorun/translation.lua")
	local L = translation and translation.L or function(s) return s end

	net.Receive(NET_SKILL_TREE_OPEN, function()
		if MTA.OpenSkillTree then
			MTA.OpenSkillTree()
		end
	end)

	local color_white = Color(255, 255, 255)
	local verb = L"Upgrades"
	function ENT:Initialize()
		hook.Add("HUDPaint", self, function()
			if MTA.IsOptedOut() then return end

			local bind = MTA.GetBindKey("+use")
			if not bind then return end

			local text = ("/// %s [%s] ///"):format(verb, bind)
			MTA.ManagedHighlightEntity(self, text, color_white)
		end)
	end
end