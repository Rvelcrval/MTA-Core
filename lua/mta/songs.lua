-- DB SCHEME
--[[
CREATE TABLE mta_stats (
	id INTEGER NOT NULL PRIMARY KEY,
	urls TEXT NOT NULL DEFAULT ''
)
]]--

local tag = "mta_songs"

local NET_SONGS_TRANSMIT = "MTA_SONGS_TRANSMIT"
if SERVER then
	util.AddNetworkString(NET_SONGS_TRANSMIT)

	local function can_db()
		return _G.db and _G.co
	end

	MTA.Songs = {}
	MTA.Songs.URLs = {}

	function MTA.Songs.Save(ply, songs)
		local prestige_lvl = MTA.GetPlayerStat(ply, "prestige_level")
		local count = #songs >= prestige_lvl and prestige_lvl or #songs
		local urls = table.concat(songs, ";", 1, count)

		net.Start(NET_SONGS_TRANSMIT)
		net.WriteString(urls)
		net.Send(ply)

		MTA.Songs.URLs[ply] = MTA.Songs.URLs[ply] or {}
		for i = 1, count do
			table.insert(MTA.Songs.URLs[ply], songs[i])
		end

		if not can_db() then return end
		co(function()
			db.Query(("UPDATE mta_user_songs SET urls = '%s' WHERE id = %d;"):format(urls, ply:AccountID()))
		end)
	end

	function MTA.Songs.Init(ply)
		if not can_db() then return {} end
		co(function()
			local ret = db.Query(("SELECT * FROM mta_user_songs WHERE id = %d;"):format(ply:AccountID()))[1]
			if ret and ret.urls then
				local prestige_lvl = MTA.GetPlayerStat(ply, "prestige_level")
				local songs = ret.urls:Split(";")
				MTA.Songs.URLs[ply] = MTA.Songs.URLs[ply] or {}
				for i = 1, count do
					table.insert(MTA.Songs.URLs[ply], songs[i])
				end

				net.Start(NET_SONGS_TRANSMIT)
				net.WriteString(ret.urls)
				net.Send(ply)
			else
				db.Query(("INSERT INTO mta_user_songs(id, urls) VALUES(%d, '');"):format(ply:AccountID()))
			end
		end)
	end

	function MTA.Songs.Get(ply)
		return MTA.Songs.URLs[ply] or {}
	end

	net.Receive(NET_SONGS_TRANSMIT, function(_, ply)
		local mode = net.ReadString()
		local url = net.ReadString()
		if url:Trim() == "" then return end

		local cur_songs = MTA.Songs.Get(ply)

		if mode == "add" then
			table.insert(cur_songs, url)
		elseif mode == "delete" then
			table.RemoveByValue(cur_songs, url)
		else
			-- funny client hijacking ??
			return
		end

		MTA.Songs.Save(ply, cur_songs)
	end)

	hook.Add("MTAPlayerStatsInitialized", tag, MTA.Songs.Init)
	hook.Add("PlayerDisconnected", tag, function(ply) MTA.Songs.URLs[ply] = nil end)
end

if CLIENT then
	local MTA_PAYDAY = CreateClientConVar("mta_payday", "1", true, false, "Enable the payday assault")

	local BASE_SONG_AMOUNT = 14
	local SONG_VOLUME = 0.65
	local WIDTH = ScrW() * 0.24
	local is_assault = false

	file.CreateDir("mta")
	local function get_custom_content(url, name, cb)
		cb = cb or function() end

		if not file.Exists("mta/" .. name, "DATA") then
			http.Fetch(url, function(body, _, _, code)
				if code == 200 and body then
					file.Write("mta/" .. name, body)
					cb()
				end
			end)
		else
			cb()
		end
	end

	if MTA_PAYDAY:GetBool() then
		get_custom_content("https://cdn.zeni.space/meta/policeassault.png", "policeassault.png")
		get_custom_content("https://cdn.zeni.space/meta/policeassault_corners.png", "policeassault_corners.png")
		get_custom_content("https://cdn.zeni.space/meta/policeassault_icon.png", "policeassault_icon.png")
	end

	if IsValid(_G.payday_assault) then
		_G.payday_assault:Remove()
		_G.payday_assault = nil
	end

	MTA.Songs = MTA.Songs or {}
	MTA.SongStation = nil

	net.Receive(NET_SONGS_TRANSMIT, function()
		local urls = net.ReadString()

		-- remove previous songs
		for i, _ in pairs(MTA.Songs) do
			local file_path = ("mta/custom_song_slot_%d.dat"):format(i)
			file.Delete(file_path)
		end

		MTA.Songs = urls == "" and {} or urls:Split(";")
		for i, _ in pairs(MTA.Songs) do
			local file_name = ("custom_song_slot_%d.dat"):format(i)
			get_custom_content(url, file_name)
		end
	end)

	local PANEL = {}
	function PANEL:Init()
		self:SetSize(WIDTH, ScrH() * 0.06)
		self:SetPos(ScrW() - WIDTH, 0)

		function self:ExpandText()
			self.shouldexpand = true
			self.size = 0
			self.realtime = RealTime()

			self.material = Material("data/mta/policeassault.png")
			self.material2 = Material("data/mta/policeassault_corners.png")
		end

		local offset = 0
		local uv_x = 0
		self.Paint = function(self, w, h)
			if self.shouldexpand then
				local start = self.realtime - RealTime()
				--local a = math.abs(math.sin(start * 3))
				local color = math.abs((((self.realtime - RealTime()) * 2) % 2) - 1)
				color = color * 255

				local offset_pos = w - self.size
				local scaling_width = w * (self.size / w)
				surface.SetDrawColor(color, color, 0, color / 3)
				self.size = math.Approach(self.size, w, 1000 * FrameTime())
				surface.DrawRect(offset_pos - offset, 0, scaling_width, h)

				surface.SetDrawColor(255, 255, 0, 255)
				surface.SetMaterial(self.material2)

				surface.DrawTexturedRect(math.max(offset_pos - offset, 0), 0, math.min(scaling_width, w - offset), h)
				surface.SetMaterial(self.material)
				uv_x = math.Approach(uv_x, 0.5, 0.2 * RealFrameTime())
				if uv_x >= 0.5 then
					uv_x = 0.027 -- aa help
				end

				if IsValid(MTA.SongStation) and (MTA.SongStation:GetState() == GMOD_CHANNEL_STOPPED or MTA.SongStation:GetVolume() ~= SONG_VOLUME) then
					MTA.SongStation:Play()
					MTA.SongStation:SetVolume(SONG_VOLUME)
				end

				surface.DrawTexturedRectUV(offset_pos - offset, 0, scaling_width, h, uv_x, 0, 0.5 + uv_x, 1)
			else
				if not self.size then return end

				local offset_pos = w - self.size
				local scaling_width = w * (self.size / w)

				self.size = math.Approach(self.size, 0, 1000 * FrameTime())

				surface.SetDrawColor(140, 140, 140, 60)
				surface.DrawRect(offset_pos - offset, 0, scaling_width, h)

				local station_valid = IsValid(MTA.SongStation)
				local volume = (self.size / w)
				if station_valid then
					MTA.SongStation:SetVolume(volume)
				end

				if self.size == 0 and (not station_valid or MTA.SongStation:GetVolume() == 0) then
					--self:Remove()

					self.size = nil
					return
				end
			end
		end

		local icon = self:Add("EditablePanel")
		icon:SetWide(math.min(self:GetWide() * 0.1, 46))
		icon:SetTall(self:GetTall() * 0.65)
		icon:SetPos(self:GetWide() - icon:GetWide(), 0)
		icon.alpha = 0

		offset = icon:GetWide() + 10

		icon.Paint = function(pnl, w, h)
			if not pnl.should_draw then return end

			if pnl.flash_amount and pnl.last_flash - RealTime() < 0 then
				if pnl.flash_amount <= 0 then
					pnl.flash_amount = nil

					pnl.alpha = 1
					self:ExpandText()
					return
				end

				pnl.alpha = pnl.alpha == 1 and 0 or 1
				pnl.flash_amount = pnl.flash_amount - 1
				pnl.last_flash = RealTime() + 0.12
			end

			surface.SetAlphaMultiplier(pnl.alpha)

			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(pnl.material)
			surface.DrawTexturedRect(0, 0, w, h)

			surface.SetAlphaMultiplier(1)
		end

		function self:HideText()
			self.size = self.size or 0
			self.shouldexpand = false
			icon.should_draw = nil
		end

		self.icon = icon
	end
	vgui.Register("payday_assault", PANEL, "EditablePanel")

	local payday_assault
	local function start_assault(song_file_name)
		if not IsValid(payday_assault) then
			payday_assault = vgui.Create("payday_assault")

			_G.payday_assault = payday_assault
		end

		local icon = payday_assault.icon

		icon.should_draw = true
		icon.material = Material("data/mta/policeassault_icon.png")
		icon.flash_amount = 10
		icon.last_flash = 0

		if IsValid(MTA.SongStation) then
			MTA.SongStation:Stop()
			MTA.SongStation = nil
		end

		local song_path = ("data/mta/%s"):format(song_file_name)
		sound.PlayFile(song_path, "", function(music)
			if not IsValid(music) then print("not valid?", music, song_path) return end -- how#3

			MTA.SongStation = music
			MTA.SongStation:Play()
			MTA.SongStation:SetVolume(SONG_VOLUME)

			if ms and ms.SetNonRoomMusicPlaying then
				ms.SetNonRoomMusicPlaying(true)
			end
		end)
	end

	local function on_going_assault()
		return is_assault
	end

	local function end_assault(instant)
		if IsValid(payday_assault) then
			payday_assault:HideText()

			if instant then
				payday_assault.size = nil
			end
		end

		is_assault = nil

		if IsValid(MTA.SongStation) then
			MTA.SongStation:Stop()
			MTA.SongStation = nil
		end

		if ms and ms.SetNonRoomMusicPlaying then
			ms.SetNonRoomMusicPlaying(false)
		end
	end

	local function get_rand_song_index(id, max)
		return id and math.min(math.max(id, 1), max) or math.random(1, max)
	end

	local function fetch_song(id)
		is_assault = true

		if #MTA.Songs > 0 then
			local index = get_rand_song_index(id, #MTA.Songs)
			local file_name = ("custom_song_slot_%d.dat"):format(index)
			get_custom_content(MTA.Songs[index], file_name, function()
				if not on_going_assault() then return end
				start_assault(file_name)
			end)

			return
		end

		local index = get_rand_song_index(id, BASE_SONG_AMOUNT)
		local file_name = ("song_%d.dat"):format(index)
		local base_song_url = "https://cdn.zeni.space/meta/song_" .. index .. "%2e" .. "ogg"
		get_custom_content(base_song_url, file_name, function()
			if not on_going_assault() then return end
			start_assault(file_name)
		end)
	end

	hook.Add("MTAWantedStateUpdate", tag, function(ply, is_wanted)
		if not IsValid(LocalPlayer()) then return end
		if ply ~= LocalPlayer() then return end

		if on_going_assault() and not is_wanted then
			return end_assault()
		end

		if not MTA_PAYDAY:GetBool() then return end

		if not on_going_assault() and is_wanted then
			fetch_song()
		end
	end)

	concommand.Add("mta_cycle_song", function(_, _, args)
		if not on_going_assault() then return end
		local id = tonumber(args[1])

		end_assault(true)
		fetch_song(id)
	end, nil, "Plays a random MTA song. Use numbers to play a specific song. Your own songs will be prioritized.")
end