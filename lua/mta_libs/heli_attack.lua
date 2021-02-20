local Z_OFFSET = Vector(0, 0, 700)
local NPC_CLASS = "npc_helicopter"

for _, npc in ipairs(ents.FindByClass(NPC_CLASS)) do
	npc:Remove()
end

local function get_proper_offset(pos)
	local offset = Z_OFFSET
	if not util.IsInWorld(pos + Z_OFFSET) then
		offset = Z_OFFSET / 2
	end

	return Z_OFFSET
end

local function heuristic_cost_estimate(start, goal)
	-- Perhaps play with some calculations on which corner is closest/farthest or whatever
	return start:GetCenter():Distance(goal:GetCenter())
end

-- using CNavAreas as table keys doesn't work, we use IDs
local function reconstruct_path(came_from, current)
	local total_path = { current }

	current = current:GetID()
	while came_from[current] do
		current = came_from[current]
		table.insert(total_path, navmesh.GetNavAreaByID(current))
	end

	return total_path
end

local function a_star(ent, start, goal)
	if not IsValid(start) or not IsValid(goal) then return false end
	if start == goal then return true end

	start:ClearSearchLists()
	start:AddToOpenList()

	local came_from = {}

	start:SetCostSoFar(0)
	start:SetTotalCost(heuristic_cost_estimate(start, goal))
	start:UpdateOnOpenList()

	while not start:IsOpenListEmpty() do
		local current = start:PopOpenList() -- Remove the area with lowest cost in the open list and return it
		if current == goal then return reconstruct_path(came_from, current) end

		current:AddToClosedList()

		for _, neighbor in pairs(current:GetAdjacentAreas()) do
			local new_cost_so_far = current:GetCostSoFar() + heuristic_cost_estimate(current, neighbor)
			local tr = util.TraceLine({
				start = current:GetCenter() + Z_OFFSET,
				endpos = neighbor:GetCenter() + Z_OFFSET,
				filter = ent,
				mask = MASK_PLAYERSOLID_BRUSHONLY,
				collisiongroup = COLLISION_GROUP_DEBRIS,
			})

			--if tr.Fraction >= 0.75 then
				if not ((neighbor:IsOpen() or neighbor:IsClosed()) and neighbor:GetCostSoFar() <= new_cost_so_far) then
					neighbor:SetCostSoFar(new_cost_so_far)
					neighbor:SetTotalCost(new_cost_so_far + heuristic_cost_estimate(neighbor, goal))

					if neighbor:IsClosed() then
						neighbor:RemoveFromClosedList()
					end

					if neighbor:IsOpen() then
						-- This area is already on the open list, update its position in the list to keep costs sorted
						neighbor:UpdateOnOpenList()
					else
						neighbor:AddToOpenList()
					end

					came_from[neighbor:GetID()] = current:GetID()
				end
			--end
		end
	end

	return false
end

local function create_track(prev_tack, pos)
	local track = ents.Create("path_track")
	track:Spawn()

	track:SetSaveValue("m_pprevious", prev_tack)
	track:SetPos(pos + get_proper_offset(pos))

	if IsValid(prev_track) then
		prev_tack:SetSaveValue("m_pnext", track)
	end

	return track
end

local function target_player(ply)
	local closest_node = navmesh.GetNearestNavArea(ply:WorldSpaceCenter())
	if not IsValid(closest_node) then return false, "no useable node" end

	local npc = ents.Create(NPC_CLASS)
	npc:SetPos(closest_node:GetCenter() + Z_OFFSET)
	npc:Spawn()
	npc:Activate()
	npc:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
	npc:SetNotSolid(true)
	npc.DontTouchMe = true

	local phys = npc:GetPhysicsObject()
	if IsValid(phys) then phys:EnableCollisions(false) end

	npc:Fire("StartSprinkleBehavior")

	MTA.SetupCombine(npc, ply, MTA.BadPlayers)

	local track_name = ("MTA_HELI_TRACK_%d"):format(npc:EntIndex())
	timer.Create(track_name, 5, 0, function()
		for _, track in ipairs(ents.FindByClass("path_track")) do
			if track:GetName() == track_name then
				track:Remove()
			end
		end

		if not IsValid(ply) or not IsValid(npc) then
			timer.Remove(track_name)
			return
		end

		local enemy = npc:GetEnemy()
		if IsValid(enemy) then ply = enemy end

		local start_area, goal_area =
			navmesh.GetNearestNavArea(npc:GetPos()),
			navmesh.GetNearestNavArea(ply:WorldSpaceCenter())

		local ret = a_star(npc, start_area, goal_area)
		if not istable(ret) then return end

		local prev_track = NULL
		for i, node in ipairs(ret) do
			local track = create_track(prev_track, node:GetCenter())
			track:SetName(track_name)
			track.AssignedEntity = ply
			prev_track = track
		end

		npc:Fire("SetTrack", track_name)
	end)

	return true, npc
end

return target_player