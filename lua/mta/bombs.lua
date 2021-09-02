local tag = "mta_bombs"

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
	    local left = ply:WorldSpaceCenter() + ply:GetRight() * (-maxs.x + margin)
	    local right = ply:WorldSpaceCenter() + ply:GetRight() * (maxs.x + margin)
	    local forward = ply:WorldSpaceCenter() + ply:GetForward() * (maxs.y + margin)
	    local backward = ply:WorldSpaceCenter() + ply:GetForward() * (-maxs.y + margin)

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
		bomb:SetNWBool("MTACombine", true)
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
	for _, class_name in pairs(MTA_CONFIG.bombs.BlockingClasses) do
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

	hook.Add("EntityRemoved", tag, function(grenade)
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

	local COMBINE_MAXS = Vector(13, 13, 72)
	hook.Add("MTASpawnFail", tag, function(failed_count, reason, target)
		if #MTA.BadPlayers < 1 then return end
		if failed_count > 0 and failed_count % 5 == 0 then
			local pos = find_space(target, COMBINE_MAXS)
			MTA.TrySpawnCombine(target, pos)
		end
	end)

	local CAMPING_DIST = MTA_CONFIG.bombs.CampingDistance
	local START_CAMPING_DURATION = MTA_CONFIG.bombs.CampingInterval
	local WARNING_DURATION = 20

	local campers = {}
	local red_color = Color(255, 0, 0)
	timer.Create(tag, 1, 0, function()
		for _, ply in ipairs(MTA.BadPlayers) do
			if ply:IsValid() then
				local pos = ply:GetPos()
				local camping_state = campers[ply]
				if camping_state and camping_state.LastPos:Distance(pos) <= CAMPING_DIST then
					camping_state.Times = camping_state.Times + 1

					if IS_MTA_GM and not ply.MTATpBombWarned and camping_state.Times >= START_CAMPING_DURATION - WARNING_DURATION then
						MTA.Statuses.AddStatus(ply, "tp_bomb", "Incoming Bomb", red_color, CurTime() + WARNING_DURATION)
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

	--[[local FAR_AWAY_DIST = 2048
	local TOO_CLOSE_DIST = 75
	local function find_space_ex(combine) -- thats an amazing joke I know... Don't hate me pls
		local enemy = combine:GetEnemy()
		local c_pos = combine:WorldSpaceCenter()
		local e_pos = enemy:WorldSpaceCenter()
		local dir = (c_pos - e_pos):GetNormalized()
		local end_pos = e_pos + dir * (FAR_AWAY_DIST / 4)
		local tr = util.TraceHull({
			start = e_pos,
	        endpos = end_pos,
	        filter = function(ent)
	        	if ent == enemy or ent:GetParent() == enemy then return false end
	        end,
	        mins = combine:OBBMins(),
	        maxs = combine:OBBMaxs()
		})

		return tr.HitPos or end_pos
	end

	local function do_distance_checks(combine)
		if combine.DontTouchMe then return end

		local enemy = combine:GetEnemy()
		if not IsValid(enemy) then return end

		local enemy_pos = enemy:GetPos()
		if combine:IsUnreachable(enemy) or enemy_pos:Distance(combine:GetPos()) >= FAR_AWAY_DIST then
			local pos = find_space_ex(combine)
			if pos:Distance(enemy_pos) <= TOO_CLOSE_DIST then
				pos = find_space(enemy, combine, 150)
			end

			pos.z = enemy_pos.z

			SafeRemoveEntity(combine)
			MTA.ToSpawn = math.min(MTA.MAX_COMBINES, MTA.ToSpawn + 1)
			MTA.SpawnCombine(enemy, pos)
		end
	end]]--

	-- ok this is buggy
	--[[timer.Create("mta_combine_fallback_tp", 4, 0, function()
		for _, combine in ipairs(MTA.Combines) do
			do_distance_checks(combine)
		end
	end)]]--
end

if CLIENT then
	local red_color = Color(255, 0, 0)
	hook.Add("HUDPaint", tag, function()
		if not MTA.IsWanted() then return end
		for _, bomb in ipairs(ents.FindByClass("grenade_helicopter")) do
			if bomb:GetNWBool("MTABomb") then
				MTA.HighlightEntity(bomb, "Teleported Bomb", red_color)
			end
		end
	end)
end