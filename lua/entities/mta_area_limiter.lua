AddCSLuaFile()

local tag = "mta_limiters"

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

if SERVER then
	function ENT:Initialize()
		self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_VPHYSICS)
		self:SetUnFreezable(true)
		self:SetModel("models/hunter/blocks/cube4x4x025.mdl")
		self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		self:DrawShadow(false)

		local trigger = ents.Create("base_brush")
        trigger:SetPos(self:GetPos())
        trigger:SetParent(self)
        trigger:SetTrigger(true)
        trigger:SetSolid(SOLID_BBOX)
		trigger:SetNotSolid(true)
		trigger:SetCollisionBounds(self:OBBMins() / 2, self:OBBMaxs() / 2)
		trigger.Touch = function(_, ent) self:Touch(ent) end
		self.Trigger = trigger
	end

	local offset = Vector(0, 0, -40)
	function ENT:Touch(ent)
		if ent:IsPlayer() and MTA.IsWanted(ent) then
			local dir = self:GetUp()
			ent:SetPos(self:GetPos() + offset + dir * 120)
			ent:SetVelocity(dir * 10)
		end
	end

	local function get_closest_ent(pos, entities)
		local ret
		local min_dist = 2e9
		for _, entity in pairs(entities) do
			if IsValid(entity) then
				local dist = entity:WorldSpaceCenter():Distance(pos)
				if dist < min_dist then
					min_dist = dist
					ret = entity
				end
			end
		end

		return ret
	end

	-- deal or no deal, arcade, core relay room, core entrance
	local PLACES_TO_RESTRICT = { "mg", "arcade", "relay_cntl", "coretele" }

	local triggers = {}
	local has_initialized = false
	local function lazy_init()
		if has_initialized then return end
		if not ms then return end
		if not ms.GetTrigger then return end

		for _, trigger_name in ipairs(PLACES_TO_RESTRICT) do
			local trigger = ms.GetTrigger(trigger_name)
			if IsValid(trigger) then
				if not trigger.pllist and trigger.EnablePlayerList then
					trigger:EnablePlayerList()
				end

				if not trigger.entlist and trigger.EnableEntityList then
					trigger:EnableEntityList()
				end

				local limiters = {}
				for ent, _ in pairs(trigger:GetEntities() or {}) do
					if ent:IsValid() and ent:GetClass() == "mta_area_limiter" then
						table.insert(limiters, ent)
					end
				end

				-- if we cant find limiters IN the trigger find the closest one
				if #limiters == 0 then
					local closest_limiter = get_closest_ent(trigger:WorldSpaceCenter(), ents.FindByClass("mta_area_limiter"))
					if IsValid(closest_limiter) then
						table.insert(limiters, closest_limiter)
					end
				end

				triggers[trigger_name] = {
					Trigger = trigger,
					Limiters = limiters,
				}
			end
		end

		has_initialized = true
	end

	local function should_invalidate(trigger_details)
		if not IsValid(trigger_details.Trigger) then return true end
		if #trigger_details.Limiters > 0 then
			for _, limiter in ipairs(trigger_details.Limiters) do
				if not IsValid(limiter) then return true end
			end
		end

		return false
	end

	hook.Add("PlayerEnteredTrigger", tag, function(ply, place)
		lazy_init()

		if not triggers[place] then return end
		if should_invalidate(triggers[place]) then
			has_initialized = false
			lazy_init()
		end

		local limiter = get_closest_ent(ply:GetPos(), triggers[place].Limiters)
		if not IsValid(limiter) then return end

		limiter:Touch(ply)
	end)

	hook.Add("OnEnteredTelevator", tag, function(ent)
		if ent:IsPlayer() and MTA.IsWanted(ent) then
			local limiter = get_closest_ent(ent:WorldSpaceCenter(), ents.FindByClass("mta_area_limiter"))
			if IsValid(limiter) then
				limiter:Touch(ent)
			end
		end
	end)

	hook.Add("MTAWantedStateUpdate", tag, function(ply, is_wanted)
		if not is_wanted then return end

		lazy_init()

		local valid_limiters = {}
		for _, trigger_details in pairs(triggers) do
			if should_invalidate(trigger_details) then
				has_initialized = false
				lazy_init()
			end

			if IsValid(trigger_details.Trigger) and trigger_details.Trigger:IsPlayerInside(ply) then
				valid_limiters = table.Add(valid_limiters, trigger_details.Limiters)
			end
		end

		local limiter = get_closest_ent(ply:WorldSpaceCenter(), valid_limiters)
		if not IsValid(limiter) then return end

		limiter:Touch(ply)
	end)
end

if CLIENT then
	local text = "/// AREA RESTRICTED ///"
	local function draw_side(alpha)
		surface.SetDrawColor(255, 255, 0, 10)
		surface.DrawRect(0, 0, 400, 400)

		surface.SetFont("DermaDefaultBold")
		local th, tw = surface.GetTextSize(text)
		local tx, ty = 125 + tw / 2, 125 + th / 2
		surface.SetTextPos(tx, ty)

		surface.SetDrawColor(255, 255, 0, alpha)
		surface.DrawRect(0, 191, 400, 25)

		surface.SetTextColor(255, 255, 255)
		surface.DrawText(text)
	end


	local angle_sides = Angle(0, 0, 90)
	function ENT:Draw()
		if MTA.IsOptedOut() then return end
		if LocalPlayer():GetNWInt("MTAFactor") < 1 then return end

		local alpha = 10 + math.abs((math.sin(CurTime() * 3) * 150))
		local side_pos = self:GetPos() - self:GetForward() * 100
		local left_pos = side_pos - self:GetRight() * 100

		cam.Start3D2D(left_pos, self:GetAngles(), 0.5)
			draw_side(alpha)
		cam.End3D2D()
	end
end