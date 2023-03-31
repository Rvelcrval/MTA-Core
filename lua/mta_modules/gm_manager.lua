if IS_MTA_GM then return end
if SERVER then return end

local tag = "mta_wait"
local waiting_server = false
local waiting_error = ""
local function on_join()
	if not gm_request then return end

	local serverid = "#" .. MTA_CONFIG.core.GMServerID
	if gm_request:IsServerGamemode(MTA_CONFIG.core.GMServerID, "MTA") then
		RunConsoleCommand("say","/advert JOIN THE MTA GAME WITH ME. Type !goto #3")
		RunConsoleCommand("aowl", "goto", serverid)
		return
	end

	waiting_server = true
	gm_request:RequestGamemodeChange("MTA", MTA_CONFIG.core.GMServerID, function(success)
		-- give 5 seconds before dropping the notification
		timer.Simple(5, function()
			waiting_server = false
			waiting_error = ""
		end)

		if not success then
			waiting_error = "Could not switch to MTA :("
			return
		end

		waiting_server = false
		RunConsoleCommand("say","/advert JOIN THE MTA GAME WITH ME. Type !goto #3")
		RunConsoleCommand("aowl", "goto", serverid)
	end)

	local dot_count = 0
	local next_dot = 0
	hook.Add("PostDrawHUD", tag, function()
		if not waiting_server then
			hook.Remove("PostDrawHUD", tag)
			return
		end

		local w, h = 500, 50
		local x, y = ScrW() / 2 - w / 2, ScrH() / 2 - h / 2

		surface.SetDrawColor(0,0,0,150)
		surface.DrawRect(x, y, w, h)
		surface.SetDrawColor(MTA.PrimaryColor)
		surface.DrawOutlinedRect(x, y, w, h, 2)

		local text
		if #waiting_error == 0 then
			if next_dot < CurTime() then
				dot_count = dot_count + 1
				next_dot = CurTime() + 1

				if dot_count >= 6 then
					dot_count = 0
				end
			end

			text = "Waiting for server" .. ("."):rep(2 + dot_count)
		else
			text = waiting_error
		end

		surface.SetFont("DermaLarge")
		surface.SetTextColor(MTA.TextColor)

		local tw, th = surface.GetTextSize(text)
		surface.SetTextPos(x + (w / 2 - tw / 2), y + (h / 2 - th / 2))
		surface.DrawText(text)
	end)
end

local PANEL = {}

function PANEL:Init()
	self:SetBackgroundBlur(true)
	self:SetSize(500, 500)
	self:SetTitle("MTA")
	self:SetSkin("MTA")
	derma.RefreshSkins()

	self.lblTitle:SetFont("Trebuchet24")

	local area = (LocalPlayer().InLobby and LocalPlayer():InLobby()) and "lobby" or "caves"
	local header = self:Add("DLabel")
	header:Dock(TOP)
	header:SetWrap(true)
	header:SetFont("Trebuchet24")
	header:SetTall(100)
	header:SetColor(MTA.NewValueColor)
	header:SetText(("Looks like you're causing chaos in the %s. "):format(area)
		.. "Our forces tried to/stopped you. Would you like to join the server where you have an actual chance to fight back?")

	local gains_header = self:Add("DLabel")
	gains_header:SetText("You will gain")
	gains_header:Dock(TOP)
	gains_header:SetFont("Trebuchet24")
	gains_header:DockMargin(5, 15, 5, 5)

	local gains = self:Add("DLabel")
	gains:Dock(TOP)
	gains:DockMargin(20, 5, 5, 5)
	gains:SetWrap(true)
	gains:SetTall(140)
	gains:SetFont("Trebuchet24")
	gains:SetColor(MTA.PrimaryColor)
	gains:SetText([[
	● Proper weapons
	● More CPs (criminal points) and coins
	● Skills and boosts
	● Vehicles
	● Items
	● Chaos >:)]])

	local info_header = self:Add("DLabel")
	info_header:SetText("Server Info")
	info_header:Dock(TOP)
	info_header:SetFont("Trebuchet24")
	info_header:DockMargin(5, 15, 5, 5)

	local btn_join = self:Add("DButton")
	btn_join:SetText("Join")
	btn_join:SetFont("Trebuchet24")
	btn_join:SetColor(MTA.TextColor)
	btn_join:SetPos(80, self:GetTall() - 60)
	btn_join:SetSize(150, 30)
	function btn_join:Paint(w, h)
		surface.SetDrawColor(MTA.NewValueColor)
		surface.DrawRect(0, 0, w, h)

		if self:IsHovered() then
			surface.SetDrawColor(MTA.TextColor)
			surface.DrawOutlinedRect(0, 0, w, h, 2)
		end
	end

	btn_join.DoClick = function()

		on_join()
		self:Close()
	end

	local btn_remain = self:Add("DButton")
	btn_remain:SetText("Remain Here")
	btn_remain:SetFont("Trebuchet24")
	btn_remain:SetColor(MTA.TextColor)
	btn_remain:SetPos(270, self:GetTall() - 60)
	btn_remain:SetSize(150, 30)
	function btn_remain:Paint(w, h)
		surface.SetDrawColor(MTA.OldValueColor)
		surface.DrawRect(0, 0, w, h)

		if self:IsHovered() then
			surface.SetDrawColor(MTA.TextColor)
			surface.DrawOutlinedRect(0, 0, w, h, 2)
		end
	end

	btn_remain.DoClick = function()
		self:Close()
	end
end

function PANEL:SetData(player_count, max_players, map_name)
	local info_map = self:Add("DLabel")
	info_map:SetText("Map: " .. map_name)
	info_map:Dock(TOP)
	info_map:SetFont("Trebuchet24")
	info_map:DockMargin(20, 5, 5, 5)

	local info_players = self:Add("DLabel")
	info_players:SetText(("Players: %d/%d"):format(player_count + 1, max_players))
	info_players:Dock(TOP)
	info_players:SetFont("Trebuchet24")
	info_players:DockMargin(20, 5, 5, 5)
end

vgui.Register("mta_join", PANEL, "DFrame")

local loading_in = true
hook.Add("InitPostEntity", tag, function()
	timer.Simple(23, function()
		loading_in = false
	end)

	hook.Remove("InitPostEntity", tag)
end)

hook.Add("MTAWantedStateUpdate", tag, function(ply, is_wanted)
	if is_wanted or loading_in then return end
	if ply ~= LocalPlayer() then return end
	if waiting_server then return end
	if gm_request and gm_request:IsHostServer() then return end

	local ret = hook.Run("MTADisplayJoinPanel")
	if ret == false then return end

	-- this doesnt work for some reason
	--if ply:GetNWInt("MTAFactor") <= 1 then return end -- dont bother if its a player mistake

	http.Fetch(MTA_CONFIG.core.GMInfoAPI .. MTA_CONFIG.core.GMServerID, function(body)
		local data = util.JSONToTable(body)
		local cannot_votegamemode = false
		local player_count = 0
		for k,v in pairs(data and data.players or {}) do
			if not v.IsBanned and not v.IsBot then
				player_count = player_count + 1
				if not v.AFK or v.IsAdmin then
					-- afk players are not counted except for admins (TODO: check afk length)
					cannot_votegamemode = true
				end
			end
		end
		local max_player_count = data and data.serverinfo and data.serverinfo.maxplayers or 123
		local map_name = data and data.serverinfo and data.serverinfo.map or "unknown"
		local gamemode = data and data.serverinfo and data.serverinfo.gm or "mta"
		local is_mta = (gm_request and gm_request.IsServerGamemode and gm_request:IsServerGamemode(MTA_CONFIG.core.GMServerID, "MTA")) or gamemode:lower() == "mta"

		if not is_mta and cannot_votegamemode then
			return -- server already occupied
		end

		local panel = vgui.Create("mta_join")
		panel:Center()
		panel:MakePopup()
		panel:SetData(player_count, max_player_count, map_name)
	end, function()
		--error, can't do anything as we don't know if the server even exists and client can't query that
	end)

end)
