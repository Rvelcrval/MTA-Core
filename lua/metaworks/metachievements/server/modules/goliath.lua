if not MetAchievements then return end

resource.AddFile("materials/metachievements/goliath/s1/icon.png")

local tag = "MetAchievements"
local id = "goliath"

MetAchievements.RegisterAchievement(id, {
	title = "Like a GOLIATH",
	description = "Kill a GOLIATH unit"
})

local hook_name = ("%s_%s"):format(tag, id)
hook.Add("MTAGoliathKilled", hook_name, function(ply)
	if MetAchievements.HasAchievement(ply, id) then return end
	MetAchievements.UnlockAchievement(ply, id)
end)
