local TAG = "mta_balancing"

if SERVER then
	local function is_free_space(ply, vec, ent)
	    local maxs = isentity(ent) and ent:OBBMaxs() or ent
	    local tr = util.TraceHull({
	        start = vec,
	        endpos = vec + Vector(0, 0, maxs.z or 60),
	        filter = ply,
	        mins = Vector(-maxs.y, -maxs.y, 0),
	        maxs = Vector(maxs.y, maxs.y, 1)
		})

		if not util.IsInWorld(tr.HitPos) then return false end

		-- this checks if the pos found is behind a wall or obstacle of some kind
		local filter = { ply }
		if isentity(ent) then table.insert(filter, ent) end

		tr = util.TraceLine({
			start = ply:WorldSpaceCenter(),
			endpos = tr.HitPos,
			filter = filter
		})

		-- only use the pos if its not obstructed
		return tr.Fraction == 1
	end

	local function find_space(ply, ent, margin)
		margin = margin or 75

	   	local maxs = ply:OBBMaxs()
	    local left = ply:WorldSpaceCenter() + ply:GetRight() * -(maxs.x + margin)
	    local right = ply:WorldSpaceCenter() + ply:GetRight() * (maxs.x + margin)
	    local forward = ply:WorldSpaceCenter() + ply:GetForward() * (maxs.y + margin)
	    local backward = ply:WorldSpaceCenter() + ply:GetForward() * -(maxs.y + margin)

		if is_free_space(ply, forward, ent) then
	        return forward
	    elseif is_free_space(ply, left, ent) then
	        return left
	    elseif is_free_space(ply, right, ent) then
	        return right
	    elseif is_free_space(ply, backward, ent) then
	    	return backward
	    else
	        return ply:GetPos() + Vector(0, 0, ply:OBBMaxs().z)
	    end
	end

	local function do_effect(pos, name, scale)
		local effect_data = EffectData()
		effect_data:SetOrigin(pos)
		if scale then
			effect_data:SetScale(scale)
		end
		util.Effect(name, effect_data)
	end

	function MTA.TeleportBombToPlayer(ply)
		local bomb = ents.Create("grenade_helicopter")
		bomb:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
		bomb:Spawn()
		bomb:SetNWBool("MTANPC", true)
		bomb:SetNWBool("MTABomb", true)

		local pos = find_space(ply, bomb)
		bomb:SetPos(pos)
		bomb:EmitSound(")ambient/machines/teleport3.wav", 100)

		do_effect(pos, "MuzzleFlash")
		do_effect(pos, "ManhackSparks", 100)
		do_effect(pos, "ThumperDust")
		do_effect(pos, "VortDispel", 10)

		timer.Simple(0, function()
			if not IsValid(bomb) then return end
			bomb:SetCollisionGroup(COLLISION_GROUP_WORLD)
		end)

		timer.Simple(2, function()
			if not IsValid(bomb) then return end

			local phys = bomb:GetPhysicsObject()
			if IsValid(phys) then
				phys:Wake()
				phys:EnableMotion(false)
			end
		end)
	end

	local blocking_classes = {}
	for _, class_name in pairs(MTA_CONFIG.balancing.BlockingClasses) do
		blocking_classes[class_name] = true
	end

	local function is_blocking_entity(ent)
		if not IsValid(ent) then return false end

		local class = ent:GetClass()
		if class:match("func_door.*") then return true end
		if blocking_classes[class] then return true end

		-- blow up player stuff
		if ent.CPPIGetOwner and IsValid(ent:CPPIGetOwner()) then
			return true
		end

		return false
	end

	local function is_explodable_car(car)
		return car:GetClass() == "gmod_sent_vehicle_fphysics_base" and car:IsVehicle() and car.ExplodeVehicle
	end

	hook.Add("EntityRemoved", TAG, function(grenade)
		if grenade:GetClass() == "grenade_helicopter" and grenade:GetNWBool("MTABomb") then
			local pos = grenade:WorldSpaceCenter()
			local dmg_info = DamageInfo()
			dmg_info:SetDamage(150)
			dmg_info:SetInflictor(grenade)
			dmg_info:SetAttacker(grenade)
			dmg_info:SetDamageType(DMG_BURN)
			util.BlastDamageInfo(dmg_info, pos, 300)

			if FindMetaTable("Entity").PropDoorRotatingExplode then
				for _, ent in pairs(ents.FindInSphere(pos, 300)) do
					if is_explodable_car(ent) then
						ent:ExplodeVehicle()
					elseif is_blocking_entity(ent) then
						ent:PropDoorRotatingExplode(nil, 30, false, false)
					end
				end
			end

		end
	end)

	local NPC_MAXS = Vector(13, 13, 72)
	hook.Add("MTASpawnFail", TAG, function(failed_count, reason, target, npc_class)
		if #MTA.BadPlayers < 1 then return end
		if failed_count > 0 and failed_count % 5 == 0 then
			local should_displace = hook.Run("MTADisplaceNPC", target, npc_class)
			if should_displace == false then return end

			local pos = find_space(target, NPC_MAXS)
			MTA.TrySpawnNPC(target, pos)
		end
	end)

	local CAMPING_DIST = MTA_CONFIG.balancing.CampingDistance
	local START_CAMPING_DURATION = MTA_CONFIG.balancing.CampingInterval
	local WARNING_DURATION = 20

	local campers = {}
	timer.Create(TAG, 1, 0, function()
		for _, ply in ipairs(MTA.BadPlayers) do
			if ply:IsValid() then
				local pos = ply:GetPos()
				local camping_state = campers[ply]
				if camping_state and camping_state.LastPos:Distance(pos) <= CAMPING_DIST then
					camping_state.Times = camping_state.Times + 1

					if IS_MTA_GM and not ply.MTATpBombWarned and camping_state.Times >= START_CAMPING_DURATION - WARNING_DURATION then
						MTA.Statuses.AddStatus(ply, "tp_bomb", "Incoming Bomb", MTA.DangerColor, CurTime() + WARNING_DURATION)
						ply.MTATpBombWarned = true
					end

					if camping_state.Times >= START_CAMPING_DURATION then
						MTA.TeleportBombToPlayer(ply)
						campers[ply] = nil -- reset for next run
					end
				else
					if IS_MTA_GM then
						MTA.Statuses.RemoveStatus(ply, "tp_bomb")
						ply.MTATpBombWarned = nil
					end

					campers[ply] = {
						LastPos = pos,
						Times = 0
					}
				end
			end
		end
	end)

	local perf_cache = 0
	local perf_cache_count = 0
	local next_perf_check = 0
	hook.Add("Think", TAG, function()
		perf_cache = perf_cache + (1 / (RealFrameTime and RealFrameTime() or FrameTime()))
		perf_cache_count = perf_cache_count + 1

		if CurTime() >= next_perf_check then
			next_perf_check = CurTime() + 5

			local avg_perf = perf_cache / perf_cache_count
			perf_cache = 0
			perf_cache_count = 0

			-- avg_perf should be a score between 1 and about 30
			local tickrate = 1 / engine.TickInterval()
			MTA.MAX_NPCS = math.ceil(math.max(10, MTA_CONFIG.core.MaxNPCs / tickrate * avg_perf))

			for i = 1, #MTA.NPCs do
				if i >= MTA.MAX_NPCS then
					MTA.RemoveNPC(MTA.NPCs[i])
				end
			end
		end
	end)
end

if CLIENT then
	hook.Add("HUDPaint", TAG, function()
		if not MTA.IsWanted() then return end
		for _, bomb in ipairs(ents.FindByClass("grenade_helicopter")) do
			if bomb:GetNWBool("MTABomb") then
				MTA.HighlightEntity(bomb, "Teleported Bomb", MTA.DangerColor)
			end
		end
	end)
end
