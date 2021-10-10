if not MetAchievements then return end

resource.AddFile("materials/metachievements/explosive_technology/s1/icon.png")

local tag = "MetAchievements"
local id = "explosive_technology"

MetAchievements.RegisterAchievement(id, {
	title = "Explosive Technology",
	description = "The MTA has developed a new tech. Don't stand in the same area for too long."
})

local hook_name = ("%s_%s"):format(tag, id)
hook.Add("PlayerDeath", hook_name, function(ply, inflictor, attacker)
	if MetAchievements.HasAchievement(ply, id) then return end

	if (inflictor:GetClass() == "grenade_helicopter" and inflictor:GetNWBool("MTABomb"))
		or (attacker:GetClass() == "grenade_helicopter" and attacker:GetNWBool("MTABomb"))
	then
		MetAchievements.UnlockAchievement(ply, id)
	end
end)