if not MetAchievements then return end

local tag = "MetAchievements"
local id = "master_of_all_trades"

resource.AddFile("materials/metachievements/" .. id .. "/s1/icon.png")

MetAchievements.RegisterAchievement(id, {
	title = "Master of all Trades",
	description = "Upgrade all your MTA branches to the maximum!"
})

local MAX_LEVEL = 100
local stat_names = { "damage_multiplier", "defense_multiplier", "healing_multiplier" }
local function check_stats(ply)
	if MetAchievements.HasAchievement(ply, id) then return end

	for _, stat_name in ipairs(stat_names) do
		if MTA.GetPlayerStat(ply, stat_name) < MAX_LEVEL then return end
	end

	MetAchievements.UnlockAchievement(ply, id)
end

local hook_name = ("%s_%s"):format(tag, id)
hook.Add("MTAStatIncrease", hook_name, check_stats)
hook.Add("PlayerSpawn", hook_name, check_stats)