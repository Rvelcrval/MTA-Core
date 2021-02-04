local IS_MTA_GM = (gmod.GetGamemode() or GM or GAMEMODE).Name == "MTA"

return {
	["MaxBountiesPerHunter"] = IS_MTA_GM and 10 or 4,
	["MinimumLevel"] = 20,
	["TimeToBountyRefresh"] = 7200,
}