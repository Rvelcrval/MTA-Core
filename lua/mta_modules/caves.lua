if IS_MTA_GM then return end

local TAG = "mta_hives"

local HIVE = {
	Base = "base_anim",
	Type = "anim",
	PrintName = "Hive",
	Author = "Earu",
	Spawnable = false,
	AdminOnly = true,
	ms_notouch = true,
	PhysgunDisabled = true,
	dont_televate = true,
}

local function is_in_caves(ply)
	if not ply.IsInZone then return false end
	if not ply:IsInZone("cave") then return false end

	return true
end

local npc_classes = {
	npc_antlion = "antlions",
	npc_antlion_worker = "antlion_workers",
	npc_antlionguard = "antlion_guards",
}

hook.Add("PlayerEnteredZone", "MTAHiveLocalEvent", function(ply, zone)
	if zone == "cave" then
		ply.MTALocalEvent = true
	end
end)

hook.Add("PlayerExitedZone", "MTAHiveLocalEvent", function(ply, zone)
	if zone == "cave" then
		ply.MTALocalEvent = false
	end
end)

if SERVER then
	local hive_spots = {
		Vector (-78, -2591, -69),
		Vector (-1616, -2533, -100),
		Vector (1189, 1725, -217),
	}

	function HIVE:Initialize()
		self:SetSolid(SOLID_VPHYSICS)
		self:SetModel("models/props_wasteland/antlionhill.mdl")
		self:SetModelScale(1 / 4)
		self:ManipulateBoneScale(0, Vector(1.33, 1.33, 1.33))
		self:SetHealth(1000)
		self:Activate()

		local trigger = ents.Create("base_brush")
		trigger:SetPos(self:GetPos())
		trigger:SetAngles(self:GetAngles())
		trigger:SetParent(self)
		trigger:SetTrigger(true)
		trigger:SetSolid(SOLID_BBOX)
		trigger:SetNotSolid(true)
		trigger:SetCollisionBounds(self:OBBMins() / 2, Vector(200, 200, 200))
		trigger.StartTouch = function(_, ent) self:StartTouch(ent) end
		trigger.EndTouch = function(_, ent) self:EndTouch(ent) end

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(false)
			phys:Wake()
		end
	end

	function HIVE:IsDuplicateHive()
		local tr = util.TraceHull({
			start = self:GetPos(),
			endpos = self:GetPos() + Vector(0, 0, 100),
			mins = self:OBBMins(),
			maxs = self:OBBMaxs(),
			filter = self,
		})

		return IsValid(tr.Entity) and tr.Entity:GetClass() == "mta_hive"
	end

	local tracked_ply = nil
	local taunt_sound = "npc/antlion_guard/growl_idle.wav"

	function HIVE:StartTouch(ent)
		if IsValid(ent) and ent:IsPlayer() and not tracked_ply then
			tracked_ply = ent
			self:EmitSound(taunt_sound, 75, 100, 1, CHAN_AUTO, 32, 114)
		end
	end

	function HIVE:EndTouch(ent)
		if IsValid(ent) and ent:IsPlayer() and tracked_ply and tracked_ply == ent then
			self:StopSound(taunt_sound)
			tracked_ply = nil
		end
	end

	local MIN_ATCK_DIST = 200 * 200
	local hurt_sounds = {
		"npc/antlion_guard/frustrated_growl1.wav",
		"npc/antlion_guard/frustrated_growl2.wav",
		"npc/antlion_guard/frustrated_growl3.wav"
	}
	function HIVE:OnTakeDamage(dmg_info)
		local attacker = dmg_info:GetAttacker()
		if not IsValid(attacker) then return end
		if not attacker:IsPlayer() then return end
		if MTA.IsOptedOut(attacker) then return end
		if self.Destroying then return end
		if not attacker:IsInWorld() then return end
		if attacker:GetPos():DistToSqr(self:GetPos()) >= MIN_ATCK_DIST then return end

		local cur_health = self:Health()
		local dmg = dmg_info:GetDamage()
		local new_health = math.max(0, cur_health - dmg)
		self:SetHealth(new_health)
		self:EmitSound(hurt_sounds[math.random(#hurt_sounds)], 75, 100, 1, CHAN_AUTO, 0, 114)

		if new_health <= 1 then
			self.Destroying = true

			local prev_pos = self:GetPos()
			MTA.IncreasePlayerFactor(attacker, 100)
			self:StopSound(taunt_sound)
			self:Remove()

			util.RockImpact(attacker, prev_pos, Vector(0, 0, 1), 2, true)

			local local_boss = ents.Create("npc_antlionguard")
			local_boss:SetMaterial("Models/antlion_guard/antlionGuard2")
			local_boss:SetModelScale(1.25)
			local_boss:SetHealth(20000)
			local_boss:SetPos(prev_pos + Vector(0, 0, 100))
			local_boss:Spawn()
			local_boss:Activate()
			local_boss:DropToFloor()
			local_boss:SetKeyValue("startburrowed", "1")
			local_boss:SetKeyValue("allowbark", "1")
			local_boss.MTAOverrideSquad = "hive"
			local_boss.MTAOverrideCollisionGroup = COLLISION_GROUP_NPC

			timer.Simple(0.1, function()
				if not IsValid(local_boss) then return end
				local_boss:Input("Unburrow")
			end)

			MTA.EnrollNPC(local_boss, attacker)

			pcall(function()
				if not MetaBadges then return end
				local cur_level = MetaBadges.GetBadgeLevel(attacker, "pest_control") or 0
				MetaBadges.UpgradeBadge(attacker, "pest_control", cur_level + 1)
			end)

			-- respawn after 10mins
			timer.Simple(10 * 60, function()
				local new_hive = ents.Create("mta_hive")
				new_hive:SetPos(prev_pos)
				new_hive:Spawn()

				if new_hive:IsDuplicateHive() then
					new_hive:Remove()
				end
			end)
		else
			MTA.IncreasePlayerFactor(attacker, math.max(1, math.ceil(1 * (dmg / 10))))
		end
	end

	local function spawn_hives()
		if not landmark then return end

		local cave_center = landmark.get("land_caves")
		if not cave_center then return end

		for _, hive in pairs(ents.FindByClass("mta_hive")) do
			hive:Remove()
		end

		for _, spot in ipairs(hive_spots) do
			local pos = cave_center + spot
			local hive = ents.Create("mta_hive")
			hive:SetPos(pos)
			hive:Spawn()

			if hive:IsDuplicateHive() then
				hive:Remove()
			end
		end
	end

	hook.Add("InitPostEntity", TAG, spawn_hives)
	hook.Add("PostCleanupMap", TAG, spawn_hives)
	hook.Add("MTAReset", TAG, spawn_hives)
end

if CLIENT then
	local GREEN_COLOR = Color(0, 255, 0)
	local MAT = Material("models/props_combine/portalball001_sheet")
	function HIVE:Draw()
		self:DrawModel()

		render.MaterialOverride(MAT)
		render.SetColorModulation(0, 1, 0)
			self:DrawModel()
		render.SetColorModulation(1, 1, 1)
		render.MaterialOverride()

		cam.Start2D()
		MTA.ManagedHighlightEntity(self, ("HIVE: %d/1000"):format(self:Health()), GREEN_COLOR)
		cam.End2D()
	end
end

scripted_ents.Register(HIVE, "mta_hive")

hook.Add("MTAIsInValidArea", TAG, function(ply)
	if is_in_caves(ply) then return true end
end)

if SERVER then
	local function add_coefs()
		MTA.Coeficients.npc_antlion = {
			["kill_coef"] = 1.5,
			["damage_coef"] = 1,
		}

		MTA.Coeficients.npc_antlion_worker = {
			["kill_coef"] = 1.5,
			["damage_coef"] = 1,
		}

		MTA.Coeficients.npc_antlionguard = {
			["kill_coef"] = 5,
			["damage_coef"] = 1,
		}
	end

	local function unburrow(ent)
		ent:SetKeyValue("startburrowed", "1")
		timer.Simple(0.1, function()
			if not IsValid(ent) then return end
			ent:Input("Unburrow")
		end)
	end

	local npcs = {}
	for npc_class, npc_key in pairs(npc_classes) do
		npcs[npc_key] = function()
			local ent = ents.Create(npc_class)
			ent.MTAOverrideSquad = "hive"
			ent.MTAOverrideCollisionGroup = COLLISION_GROUP_NPC
			unburrow(ent)
			return ent
		end
	end

	npcs.antlion_guards = function()
		local ent = ents.Create("npc_antlionguard")
		ent.MTAOverrideCollisionGroup = COLLISION_GROUP_NPC
		ent.MTAOverrideSquad = "hive"
		ent:SetKeyValue("allowbark", "1")
		unburrow(ent)
		return ent
	end

	local SCALE = 20
	local RETRIES = 5
	local function find_nearby_spot(center_pos)
		local cur_retries = 0

		local new_pos = center_pos
		while cur_retries < RETRIES do
			new_pos = new_pos + Vector(
				math.random() > 0.5 and math.random(SCALE, SCALE + SCALE) or math.random(-SCALE, -(SCALE + SCALE)),
				math.random() > 0.5 and math.random(SCALE, SCALE + SCALE) or math.random(-SCALE, -(SCALE + SCALE)),
				0
			)

			local tr = util.TraceHull({
				start = new_pos,
				endpos = new_pos,
				mins = Vector(-SCALE, -SCALE, 0),
				maxs = Vector(SCALE, SCALE, 100),
			})

			if not IsValid(tr.Entity) and util.IsInWorld(new_pos) then
				return true, new_pos
			end

			cur_retries = cur_retries + 1
		end

		return false, "no available spot"
	end

	local function spawn_rocklion(ply)
		local succ, pos = find_nearby_spot(ply:GetPos())
		if not succ then return end

		local npc = ms.Ores.SpawnRockyAntlion(pos, ms.Ores.SelectRarityFromSpawntable())
		npc.MTAOverrideSquad = "hive"
		npc.MTAOverrideCollisionGroup = COLLISION_GROUP_NPC

		MTA.EnrollNPC(npc, ply)
	end

	hook.Add("MTANPCSpawnProcess", TAG, function(ply, pos, wanted_lvl)
		if not is_in_caves(ply) then return end

		add_coefs()

		local spawn_function, npc_class = npcs.antlions, "npc_antlion"
		if wanted_lvl > 10 then
			if math.random(0, 100) < 25 then
				spawn_function, npc_class = npcs.antlion_workers, "npc_antlion_worker"
			end

			if wanted_lvl > 20 and math.random(0, 100) < 5 then
				spawn_function, npc_class = npcs.antlion_guards, "npc_antlionguard"
			end
		end

		if math.random(0, 100) <= 15 and ms and ms.Ores and ms.Ores.SpawnRockyAntlion then
			spawn_rocklion(ply)
		end

		return spawn_function, npc_class
	end)

	local function DENY(ply)
		if is_in_caves(ply) then return false end
	end

	hook.Add("MTAStatIncrease", TAG, DENY)
	hook.Add("MTACanBeBounty", TAG, DENY)
	hook.Add("MTACanUpdateBadge", TAG, DENY)
	hook.Add("MTAShouldPayTax", TAG, DENY)
	hook.Add("MTACanMobileEMP", TAG, DENY)

	hook.Add("PlayerExitedZone", TAG, function(ply, zone)
		if zone ~= "cave" then return end
		if not MTA.IsWanted(ply) then return end

		local cave_center = landmark and landmark.get("land_caves")
		if not cave_center then return end

		ply:SetPos(cave_center)
		MTA.ChatPrint(ply, "You cannot leave this area while fighting the hive!")
	end)

	-- dont respawn npcs where they shouldnt be
	hook.Add("MTADisplaceNPC", TAG, function(ply, npc_class)
		if npc_class == "Rocklion" then return false end
		if is_in_caves(ply) and not npc_classes[npc_class] then return false end
		if not is_in_caves(ply) and npc_classes[npc_class] then return false end
	end)

	hook.Add("MTAShouldConsiderEntity", TAG, function(ent, ply)
		if not is_in_caves(ply) then return end

		return npc_classes[ent:GetClass()] ~= nil
	end)

	hook.Add("MTARemoveNPC", TAG, function(ent)
		if not npc_classes[ent:GetClass()] then return end
		if ent.MTARemoving then return end

		ent:SetAngles(Angle(0, 0, 0))
		ent:SetPos(ent:GetPos() + Vector(0, 0, 10))
		ent:DropToFloor()

		ent.MTARemoving = true
		ent:Input("BurrowAway")

		SafeRemoveEntityDelayed(ent, 3)
		return false
	end)

	local function create_badge()
		if not MetaBadges then return end

		pcall(include, "autorun/translation.lua")
		local L = translation and translation.L or function(s) return s end
		local levels = {
			default = {
				title = L "Pest Control",
				description = L "Antlion hives destroyed"
			}
		}

		MetaBadges.RegisterBadge("pest_control", {
			basetitle = "Pest Control",
			levels = levels,
			level_interpolation = MetaBadges.INTERPOLATION_FLOOR
		})
	end

	hook.Add("Initialize", TAG, function()
		pcall(create_badge)
	end)
end

if CLIENT then
	local prev_color, prev_text = MTA.PrimaryColor, MTA.WantedText

	-- for reloads and respawns in the caves
	local function check_cave()
		if is_in_caves(LocalPlayer()) then
			hook.Run("PlayerEnteredZone", LocalPlayer(), "cave")
		end
	end

	check_cave()
	hook.Add("InitPostEntity", TAG, check_cave)

	hook.Add("PlayerEnteredZone", TAG, function(ply, zone)
		if zone ~= "cave" then return end

		MTA.OnGoingEvent = "mines"

		prev_color, prev_text = MTA.PrimaryColor, MTA.WantedText
		MTA.PrimaryColor = Color(0, 255, 0)
		MTA.WantedText = "HIVE"
	end)

	hook.Add("PlayerExitedZone", TAG, function(ply, zone)
		if zone ~= "cave" then return end

		MTA.OnGoingEvent = false
		MTA.PrimaryColor = prev_color
		MTA.WantedText = prev_text
	end)

	local song = "https://gitlab.com/metastruct/mta_projects/mta/-/raw/master/external/songs/caves/TRACK_1.ogg"
	hook.Add("MTAGetDefaultSong", TAG, function()
		local ply = LocalPlayer()

		if not ply.IsInZone then return end
		if not ply:IsInZone("cave") then return end

		return song, "caves.dat"
	end)

	hook.Add("MTASpawnEffect", TAG, function(pos, npc_class)
		if npc_classes[npc_class] then
			return false -- ignore for now
		end
	end)

	hook.Add("MTADisplayJoinPanel", TAG, function()
		if is_in_caves(LocalPlayer()) then return false end
	end)
end