if not MetAchievements then return end

local tag = "MetAchievements"
local id = "hole_maker"

resource.AddFile("materials/metachievements/" .. id .. "/s1/icon.png")

MetAchievements.RegisterAchievement(id, {
	title = "Hole Maker",
	description = "You like to make holes, even in things that can get you in troubles!"
})

local hook_name = ("%s_%s"):format(tag, id)
hook.Add("MTADrillStart", hook_name, function(ply)
	if MetAchievements.HasAchievement(ply, id) then return end
	MetAchievements.UnlockAchievement(ply, id)
end)
