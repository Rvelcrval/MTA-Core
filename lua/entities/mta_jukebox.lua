AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Author = "Earu & Jule"
ENT.Spawnable = false
ENT.AdminSpawnable = false
ENT.ms_notouch = true
ENT.lobbyok = true
ENT.PhysgunDisabled = true
ENT.dont_televate = true

local NET_JUKEBOX = "MTA_JUKEBOX"

if SERVER then
	resource.AddFile("models/fallout3/jukebox.mdl")
	resource.AddFile("materials/fallout3/jukebox_body.vmt")
	resource.AddFile("materials/fallout3/jukebox_menu.vmt")

	util.AddNetworkString(NET_JUKEBOX)

	function ENT:Initialize()
		self:SetModel("models/fallout3/jukebox.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:Wake()
			phys:EnableMotion(false)
		end

		self:Activate()
	end

	function ENT:Use(activator)
		if not activator:IsPlayer() then
			return
		end

		net.Start(NET_JUKEBOX)
		net.Send(activator)
	end
end

if CLIENT then
	pcall(include, "autorun/translation.lua")
	local L = translation and translation.L or function(s) return s end

	local color_white = Color(255, 255, 255)
	local verb = L "Jukebox"
	function ENT:Initialize()
		hook.Add("HUDPaint", self, function()
			if MTA.IsOptedOut() then return end

			local bind = MTA.GetBindKey("+use")
			if not bind then return end

			local text = ("/// %s [%s] ///"):format(verb, bind)
			MTA.HighlightEntity(self, text, color_white)
		end)
	end

	local function show_jukebox_ui()
		local frame = vgui.Create("DFrame")
		frame:SetTitle("MTA Jukebox")
		frame:ShowCloseButton(false)
		frame:SetSize(500, 300)
		frame:Center()

		function frame:Paint(w, h)
			surface.SetDrawColor(0, 0, 0, 240)
			surface.DrawRect(0, 0, self:GetWide(), 25)

			surface.SetDrawColor(0, 0, 0, 210)
			surface.DrawRect(0, 25, self:GetWide(), self:GetTall() - 25)
		end

		frame:MakePopup()

		local frame_close_btn = frame:Add("DButton")
		frame_close_btn:SetSize(30, 25)
		frame_close_btn:SetPos(frame:GetWide() - frame_close_btn:GetWide(), 0)
		frame_close_btn:SetPaintBackground(false)
		frame_close_btn:SetTextColor(Color(255, 0, 0))
		frame_close_btn:SetText("X")
		function frame_close_btn:DoClick() frame:Close() end

		-- Song selection
		local songs = frame:Add("DPanel")
		songs:SetSize(frame:GetWide() - 20, 200)
		songs:Dock(TOP)
		function songs:Paint( w, h)
			surface.SetDrawColor(100, 100, 100, 200)
			surface.DrawOutlinedRect(0, 0, w, h, 3)
		end

		local songs_label = songs:Add("DLabel")
		songs_label:SetPos(10, 10)
		songs_label:SetText(
			"Select and preview songs that play during police assault!\nYou can also randomize the song that plays with shuffle.\nWith custom song slots you can add/remove your own songs."
		)
		songs_label:SizeToContents()

		local songs_shuffle = songs:Add("DCheckBox")
		songs_shuffle:SetSize(15, 15)
		songs_shuffle:SetPos(10, 65)
		songs_shuffle:SetChecked(false)
		function songs_shuffle:Paint(w, h)
			surface.SetDrawColor(255, 150, 0)

			if not self:GetChecked() then
				surface.DrawOutlinedRect(0, 0, w, h)
			else
				surface.DrawRect(0, 0, w, h)
			end
		end

		local songs_shuffle_label = songs:Add("DLabel")
		songs_shuffle_label:SetPos(30, 65)
		songs_shuffle_label:SetTextColor(Color(255, 255, 255))
		songs_shuffle_label:SetText("Shuffle")
		songs_shuffle_label:SizeToContents()

		local songs_combobox = songs:Add("DComboBox")
		songs_combobox:SetSize(300, 20)
		songs_combobox:SetPos(10, 100)
		songs_combobox:SetPaintBackground(false)
		songs_combobox:SetTextColor(Color(255, 255, 255))
		songs_combobox:SetSortItems(false)
		function songs_combobox:Paint(w, h)
			surface.SetDrawColor(255, 150, 0, 255)
			surface.DrawOutlinedRect(0, 0, w, h, 1.5)
		end

		local songs_preview_btn = songs:Add("DButton")
		songs_preview_btn:SetSize(60, 20)
		songs_preview_btn:SetPos(250, 75)
		songs_preview_btn:SetText("PREVIEW")
		local preview_is_playing = false
		function songs_preview_btn:Paint(w, h)
			surface.SetDrawColor(255, 150, 0, 255)
			surface.DrawOutlinedRect(0, 0, w, h, 1.5)

			local col = (self:IsHovered()) and Color(255, 200, 100) or Color(255, 255, 255)
			self:SetTextColor(col)
		end
		function songs_preview_btn:DoClick()
			preview_is_playing = not preview_is_playing

			local text = (preview_is_playing) and "STOP" or "PREVIEW"
			self:SetText(text)
		end

		local songs_select_btn = songs:Add("DButton")
		songs_select_btn:SetSize(50, 20)
		songs_select_btn:SetPos(340, 100)
		songs_select_btn:SetTextColor(Color(255, 255, 255, 255))
		songs_select_btn:SetText("SELECT")
		function songs_select_btn:Paint(w, h)
			self:SetEnabled(not songs_shuffle:GetChecked())

			local alpha = (self:IsEnabled()) and 255 or 50

			surface.SetDrawColor(255, 150, 0, alpha)
			surface.DrawOutlinedRect(0, 0, w, h, 1.5)

			local col = (self:IsHovered() and self:IsEnabled()) and Color(255, 200, 100, 255) or Color(255, 255, 255, alpha)
			self:SetTextColor(col)
		end

		local songs_remove_btn = songs:Add("DButton")
		songs_remove_btn:SetSize(50, 20)
		songs_remove_btn:SetPos(400, 100)
		songs_remove_btn:SetTextColor(Color(255, 255, 255))
		songs_remove_btn:SetText("REMOVE")
		function songs_remove_btn:Paint(w, h)
			surface.SetDrawColor(255, 150, 0, 255)
			surface.DrawOutlinedRect(0, 0, w, h, 1.5)

			local col = (self:IsHovered()) and Color(255, 200, 100) or Color(255, 255, 255)
			self:SetTextColor(col)
		end

		local songs_customs_textentry = songs:Add("DTextEntry")
		songs_customs_textentry:SetSize(300, 20)
		songs_customs_textentry:SetPos(10, 160)
		songs_customs_textentry:SetPlaceholderText("Type url here..") -- This didn't even work by itself so uhh
		songs_customs_textentry:SetPaintBackground(false)
		function songs_customs_textentry:Paint(w, h)
			surface.SetDrawColor(255, 150, 0, 255)
			surface.DrawOutlinedRect(0, 0, w, h, 1.5)

			if not self:HasFocus() and self:GetText():Trim() == "" then
				self:SetText(self:GetPlaceholderText())
			end

			local col = (self:GetText() == self:GetPlaceholderText()) and Color(150, 150, 150) or Color(255, 255, 255)
			self:SetTextColor(col)

			derma.SkinHook("Paint", "TextEntry", self, w, h)
		end
		function songs_customs_textentry:OnGetFocus()
			if self:GetText() == self:GetPlaceholderText() then
				self:SetText("")
			end
		end

		local songs_customs_textentry_label = songs:Add("DLabel")
		songs_customs_textentry_label:SetPos(10, 140)
		songs_customs_textentry_label:SetText(
			"You have " .. MTA.GetPlayerStat("prestige_level") .. " slots for custom songs left."
		)
		songs_customs_textentry_label:SizeToContentsX(10)

		local songs_customs_add_btn = songs:Add("DButton")
		songs_customs_add_btn:SetPos(340, 160)
		songs_customs_add_btn:SetSize(40, 20)
		songs_customs_add_btn:SetText("ADD")
		function songs_customs_add_btn:Paint(w, h)
			surface.SetDrawColor(255, 150, 0, 255)
			surface.DrawOutlinedRect(0, 0, w, h, 1.5)

			local col = (self:IsHovered()) and Color(255, 200, 100) or Color(255, 255, 255)
			self:SetTextColor(col)
		end

		-- Visualizer
		local visualizer = frame:Add("DPanel", frame)
		visualizer:SetSize(frame:GetWide() - 20, 60)
		visualizer:Dock(TOP)
		visualizer:DockMargin(0, 5, 0, 0)

		local COUNT = 40

		local FFT_DATA = {}

		local SMOOTH_DATA = {}
		for I = 1, COUNT do
			SMOOTH_DATA[I] = 0
		end
		function visualizer:Paint(w, h)
			surface.SetDrawColor(100, 100, 100, 200)
			surface.DrawOutlinedRect(0, 0, w, h, 3)

			local station = INSERT_STATION_HERE

			if IsValid(station) then
				station:FFT(FFT_DATA, FFT_256)

				for I = 1, COUNT do
					if FFT_DATA[I] then
						SMOOTH_DATA[I] = Lerp(FrameTime() * 15, SMOOTH_DATA[I], FFT_DATA[I])

						surface.SetDrawColor(255, 255, 255, 255)
						local height = math.min(SMOOTH_DATA[I] * 600, h - 6)
						surface.DrawRect(3 + I * (w - 6) / COUNT - (w - 6) / COUNT, h - height - 3, w / COUNT + 1, height)
					end
				end
			else
				for I = 1, COUNT do
					surface.SetDrawColor(255, 255, 255, 255)
					local height = math.min(math.abs(math.sin(CurTime() + I * 50) * 40), h - 6)
					height = math.max(height, 10)
					surface.DrawRect(3 + I * (w - 6) / COUNT - (w - 6) / COUNT, h - height - 3, w / COUNT + 1, height)
				end
			end
		end
	end

	net.Receive(NET_JUKEBOX, show_jukebox_ui)
end

if SERVER then
	-- DB SCHEME
	--[[
	CREATE TABLE mta_stats (
		id INTEGER NOT NULL PRIMARY KEY,
		urls TEXT NOT NULL DEFAULT ''
	)
	]]--

	local function can_db()
		return _G.db and _G.co
	end

	MTA.Songs = {

	}

	function MTA.Songs.Save(ply, songs)
		local prestige_lvl = MTA.GetPlayerStat(ply, "prestige_level")
		local urls = table.concat(songs, ";", 1, #songs >= prestige_lvl and prestige_lvl or #songs)

		for i = 1, prestige_lvl do
			ply:SetNWString(("MTAUserSong_%d"):format(i), songs[i] or "")
		end

		if not can_db() then return end
		co(function()
			db.Query(("UPDATE mta_user_songs SET urls = '%s' WHERE id = %d"):format(urls, ply:AccountID()))
		end)
	end

	function MTA.Songs.Init(ply)
		if not can_db() then return {} end
		co(function()
			local ret = db.Query(("SELECT * FROM mta_user_songs WHERE id = %d;"):format(ply:AccountID()))[1]
			if ret then
				local prestige_lvl = MTA.GetPlayerStat(ply, "prestige_level")
				local songs = ret.urls:Split(";")
				for i = 1, prestige_lvl do
					ply:SetNWString(("MTAUserSong_%d"):format(i), songs[i] or "")
				end
			end
		end)
	end

	function MTA.Songs.Get(ply)
		local urls = {}
		local prestige_lvl = MTA.GetPlayerStat(ply, "prestige_level")
		for i = 1, prestige_lvl do
			local url = ply:GetNWString(("MTAUserSong_%d"):format(i))
			table.insert(urls, url)
		end

		return urls
	end
end