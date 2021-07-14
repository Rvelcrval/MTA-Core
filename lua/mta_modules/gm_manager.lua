if IS_MTA_GM then return end
if SERVER then return end

local tag = "mta_wait"
local orange_color = Color(244, 135, 2)
local white_color = Color(255, 255, 255)
local waiting_server = false
local waiting_error = ""
local function on_join()
	if not gm_request then return end

	if gm_request:IsServerGamemode(3, "MTA") then
		RunConsoleCommand("aowl", "goto", "#3")
		return
	end

	waiting_server = true
	gm_request:RequestGamemodeChange("MTA", 3, function(success)
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
		RunConsoleCommand("aowl", "goto", "#3")
	end)

	local dot_count = 0
	local next_dot = 0
	hook.Add("HUDPaint", tag, function()
		if not waiting_server then
			hook.Remove("HUDPaint", tag)
			return
		end

		local w, h = 500, 50
		local x, y = ScrW() / 2 - w / 2, ScrH() / 2 - h / 2

		surface.SetDrawColor(0,0,0,150)
		surface.DrawRect(x, y, w, h)
		surface.SetDrawColor(orange_color)
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
		surface.SetTextColor(white_color)

		local tw, th = surface.GetTextSize(text)
		surface.SetTextPos(x + (w / 2 - tw / 2), y + (h / 2 - th / 2))
		surface.DrawText(text)
	end)
end

hook.Add("MTAWantedStateUpdate", tag, function(ply, is_wanted)
	if is_wanted then return end
	if ply ~= LocalPlayer() then return end
	if waiting_server then return end
	if not gm_request then return end

	Derma_Query(
		"Looks like you're enjoying MTA, do you wish to join the dedicated MTA server? (we have guns, pvp and a gamemode :eyes:)",
		"MTA",
		"Join", on_join,
		"Remain here", function() end
	)
end)
