local TAG = "MTAHalloween"

local is_halloween = false
local function check_halloween()
	-- dont enable on MTA gamemode, we can make this infinitely better,
	-- this is just a tiny easter egg thing
	is_halloween = os.date("%m") == "10" and not IS_MTA_GM
end

timer.Create(TAG, 60, 0, check_halloween)

if SERVER then
	local enemy_types = {
		zombies = function()
			return ents.Create("npc_zombie")
		end,
		poison_zombies = function()
			return ents.Create("npc_poisonzombie")
		end,
		fast_zombies = function()
			return ents.Create("npc_fastzombie")
		end,
		zombines = function()
			return ents.Create("npc_zombine")
		end,
	}
	hook.Add("MTANPCSpawnProcess", TAG, function(target, pos, wanted_lvl)
		if not is_halloween then return end

		-- below 10 is just zombies
		local spawn_function = enemy_types.zombies

		-- 10% chance of getting poison zombies here and there
		if math.random(0, 100) <= 10 then
			spawn_function = enemy_types.poison_zombies

		-- above level 10 progressively change to only fast zombies
		elseif wanted_lvl < 60 and wanted_lvl >= 10 then
			spawn_function = math.random(0, 60) <= (wanted_lvl + 20) and enemy_types.fast_zombies or enemy_types.zombies

		-- above 60 we add zombines
		elseif wanted_lvl >= 60 then
			spawn_function = math.random(0, 100) < 25 and enemy_types.zombines or enemy_types.fast_zombies
		end

		return spawn_function
	end)

	hook.Add("MTANPCDrops", TAG, function(npc)
		if not is_halloween then return end
		if not CreateCandy then return end

		local candy_count = math.random(0, 5)
		for _ = 1, candy_count do
			local candy = CreateCandy(npc:WorldSpaceCenter(), Angle(0, 0, 0))
			candy:SetVelocity(VectorRand() * 100)
		end
	end)
end

if CLIENT then
	local songs = {
		"https://dl.dropboxusercontent.com/s/3yhyi3r516c452r/SIERRA%20TRAPPED.ogg",
		"https://dl.dropboxusercontent.com/s/rd59wk27r3cjg3o/TARIK%20BOUISFI%20EVIL%20GATEWAY.ogg"
	}
	hook.Add("MTAGetDefaultSong", TAG, function()
		if not is_halloween then return end
		local i = math.random(#songs)
		return songs[i], ("halloween_%d.dat"):format(i)
	end)
end