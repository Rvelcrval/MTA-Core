if not MetAchievements then return end

local tag = "MetAchievements"
local id = "invincible"

resource.AddFile("materials/metachievements/" .. id .. "/s1/icon.png")

MetAchievements.RegisterAchievement(id, {
	title = "Invincible",
	description = "Fighting the MTA gets you going... Maybe a little too much"
})

local hook_name = ("%s_%s"):format(tag, id)
hook.Add("MTAFeverState", hook_name, function(ply, is_fever)
	if not is_fever then return end
	if MetAchievements.HasAchievement(ply, id) then return end

	MetAchievements.UnlockAchievement(ply, id)
end)