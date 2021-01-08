if SERVER then return end

if IsValid(_G.payday_assault) then
	_G.payday_assault:Remove()
	_G.payday_assault = nil
end

local shouldplay_convar = CreateClientConVar("mta_payday", "1", true, false, "Enable the payday assault")

file.CreateDir("zeni")
local function GetCustomContent(url, name, cb)
	cb = cb or function() end

	if not file.Exists("zeni/" .. name, "DATA") then
		http.Fetch(url, function(body, _, _, code)
			assert(code == 200, body)

			file.Write("zeni/" .. name, body)

			cb()
		end, error)
	else
		cb()
	end
end

if shouldplay_convar:GetBool() then
	GetCustomContent("https://cdn.zeni.space/meta/policeassault.png", "policeassault.png")
	GetCustomContent("https://cdn.zeni.space/meta/policeassault_corners.png", "policeassault_corners.png")
	GetCustomContent("https://cdn.zeni.space/meta/policeassault_icon.png", "policeassault_icon.png")
end

local SONG_AMOUNT = 14
local SONG_VOLUME = 0.65
local WIDTH = ScrW() * 0.24

local song
local station
local is_assault

local PANEL = {}
function PANEL:Init()
	self:SetSize(WIDTH, ScrH() * 0.06)
	self:SetPos(ScrW() - WIDTH, 0)

	function self:ExpandText()
		self.shouldexpand = true
		self.size = 0
		self.realtime = RealTime()

		self.material = Material("data/zeni/policeassault.png")
		self.material2 = Material("data/zeni/policeassault_corners.png")
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
				uv_x = 0.027 -- aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa help
			end

			if IsValid(station) and (station:GetState() == GMOD_CHANNEL_STOPPED or station:GetVolume() ~= SONG_VOLUME) then
				station:Play()
				station:SetVolume(SONG_VOLUME)
			end

			surface.DrawTexturedRectUV(offset_pos - offset, 0, scaling_width, h, uv_x, 0, 0.5 + uv_x, 1)
		else
			if not self.size then return end

			local offset_pos = w - self.size
			local scaling_width = w * (self.size / w)

			self.size = math.Approach(self.size, 0, 1000 * FrameTime())

			surface.SetDrawColor(140, 140, 140, 60)
			surface.DrawRect(offset_pos - offset, 0, scaling_width, h)

			local station_valid = IsValid(station)
			local volume = (self.size / w)
			if station_valid then
				station:SetVolume(volume)
			end

			if self.size == 0 and (not station_valid or station:GetVolume() == 0) then
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
local function StartAssault()
	if not IsValid(payday_assault) then
		payday_assault = vgui.Create("payday_assault")

		_G.payday_assault = payday_assault
	end

	local icon = payday_assault.icon

	icon.should_draw = true
	icon.material = Material("data/zeni/policeassault_icon.png")
	icon.flash_amount = 10
	icon.last_flash = 0

	if IsValid(station) then
		station:Stop()
		station = nil
	end

	sound.PlayFile("data/zeni/song_" .. song .. ".dat", "", function(music)
		if not IsValid(music) then print("not valid?", music, song) return end -- how#3

		station = music
		station:Play()
		station:SetVolume(SONG_VOLUME)

		if ms and ms.SetNonRoomMusicPlaying then
			ms.SetNonRoomMusicPlaying(true)
		end
	end)
end

local function OnGoingAssault()
	return is_assault
end

local function EndAssault(instant)
	if IsValid(payday_assault) then
		payday_assault:HideText()

		if instant then
			payday_assault.size = nil
		end
	end

	is_assault = nil

	if ms and ms.SetNonRoomMusicPlaying then
		ms.SetNonRoomMusicPlaying(false)
	end
end

local function FetchSong(id)
	is_assault = true

	song = id and math.min(math.max(id, 1), SONG_AMOUNT) or math.random(1, SONG_AMOUNT)

	GetCustomContent("https://cdn.zeni.space/meta/song_" .. song .. "%2e" .. "ogg", "song_" .. song .. ".dat", function()
		if not OnGoingAssault() then return end

		StartAssault()
	end)
end

hook.Add("MTAWantedStateUpdate", "payday2", function(ply, is_wanted)
	if not IsValid(LocalPlayer()) then return end
	if ply ~= LocalPlayer() then return end

	if OnGoingAssault() and not is_wanted then
		return EndAssault()
	end

	if not shouldplay_convar:GetBool() then return end

	if not OnGoingAssault() and is_wanted then
		FetchSong()
	end
end)

concommand.Add("mta_cycle_song", function(_, _, args)
	if not OnGoingAssault() then return end
	local id = tonumber(args[1])

	EndAssault(true)
	FetchSong(id)
end, nil, "Plays a random MTA song. Use numbers 1 - " .. SONG_AMOUNT .. " to play a specific song.")