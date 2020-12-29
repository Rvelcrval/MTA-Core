if not MetAchievements then return end

resource.AddFile("materials/metachievements/master_of_all_trades/s1/icon.png")

local tag = "MetAchievements"
local id = "master_of_all_trades"

MetAchievements.RegisterAchievement(id, {
	title = "Master of all Trades",
	description = "Upgrades all your MTA branches to the maximum!"
})

local MAX_LEVEL = 100
local stat_names = { "damage_multiplier", "defense_multiplier", "healing_multiplier" }
local function check_stats(ply)
	for _, stat_name in ipairs(stat_names) do
		if MTA.GetPlayerStat(ply, stat_name) < MAX_LEVEL then return end
	end

	MetAchievements.UnlockAchievement(ply, id)
end

local hook_name = ("%s_%s"):format(tag, id)
hook.Add("MTAStatIncrease", hook_name, check_stats)
hook.Add("PlayerInitialSpawn", hook_name, check_stats)