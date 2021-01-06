if not MetAchievements then return end

resource.AddFile("materials/metachievements/infamous/s1/icon.png")

local tag = "MetAchievements"
local id = "infamous"

local PRESTIGE_LEVEL = 5

local function get_statistics(req, ply, stats)
	local count = istable(stats) and stats.count
	return ("Prestige: %d / %d")
		:format((isnumber(count) and count or 0), PRESTIGE_LEVEL)
end

local function get_progress(req, ply, stats)
	local count = istable(stats) and stats.count
	if not isnumber(count) then count = 0 end
	return count / PRESTIGE_LEVEL
end

MetAchievements.RegisterAchievement(id, {
	title = "Infamous",
	description = string.format("Reach the MTA Criminal Prestige %d", PRESTIGE_LEVEL),
	statistics = get_statistics,
	progress = get_progress,
})

local function on_prestige(ply)
	local observable = MetAchievements.GetStat_ASYNC(ply, id, "count")
	if not observable then return end
	observable = observable:defaultIfEmpty(0)
		:map(function(c) return math.Clamp(MTA.GetPlayerStat(ply, "prestige_level"), 0, PRESTIGE_LEVEL) end)

	observable
		:subscribe(function(c)
			MetAchievements.SetStat(ply, id, "count", c)
		end)

	observable
		:filter(function(c) return c == PRESTIGE_LEVEL end)
		:subscribe(function(c)
			MetAchievements.UnlockAchievement(ply, id)
		end)
end

local hook_name = ("%s_%s"):format(tag, id)
hook.Add("MTAPlayerPrestige", hook_name, on_prestige)
hook.Add("PlayerSpawn", hook_name, function(ply)
	if MTA.GetPlayerStat(ply, "prestige_level") >= PRESTIGE_LEVEL then
		MetAchievements.UnlockAchievement(ply, id)
	end
end)