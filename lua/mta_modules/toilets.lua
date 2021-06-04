local model = "models/props_c17/furnituretoilet001a.mdl"
local tag = "mta_toilets"

if SERVER then
	function handle_use(ply)
		local ent = ply:GetEyeTrace().Entity
		if not IsValid(ent) then return end
		if ent:GetModel() ~= model then return end
		if not ent:CreatedByMap() then return end
		if ent:GetNWBool("ToiletInUse") then return end
		if ply:GetPos():Distance(ent:GetPos()) > 128 then return end

		local seat = ents.Create("prop_vehicle_prisoner_pod")
		seat:SetModel("models/nova/jeep_seat.mdl")
		seat:SetPos(ent:GetPos() - ent:GetUp() * 35)
		seat:SetAngles(ent:GetAngles() + Angle(0, -90, 0))
		seat:SetParent(ent)
		seat:Spawn()
		seat:SetNoDraw(true)
		seat.lobbyok = true
		seat.ms_notouch = true
		seat.IsToiletSeat = true
		seat.Toilet = ent

		local ret = hook.Run("CanPlayerEnterVehicle", ply, seat, 0)
		if ret == false then
			SafeRemoveEntity(seat)
			return
		end

		ent:SetNWBool("ToiletInUse", true)
		ply:SetNWBool("IsDefecating", true)

		ply:EnterVehicle(seat)
	end

	function handle_space(ply)
		if not ply:GetNWBool("IsDefecating") then return end
		local new_score = ply:GetNWInt("DefecateScore", 0) + 1
		ply:SetNWInt("DefecateScore", new_score)

		if new_score % 20 == 0 then
			local chatsound = ("saysound fart#%d^%d"):format(math.random(1, 4), new_score)
			ply:ConCommand(chatsound)

			timer.Simple(0.4, function()
				if not IsValid(ply) then return end
				local toilet = ply:GetVehicle()
				if IsValid(toilet) then
					toilet:EmitSound("ambient/water/water_splash1.wav")
				end
			end)
		end
	end

	hook.Add("KeyPress", tag, function(ply, key)
		if key == IN_USE then
			handle_use(ply)
		elseif key == IN_JUMP then
			handle_space(ply)
		end
	end)

	hook.Add("PlayerLeaveVehicle", tag, function(ply, veh)
		if not veh.IsToiletSeat then return end
		veh.Toilet:SetNWBool("ToiletInUse", false)
		veh.Toilet:EmitSound("ambient/machines/usetoilet_flush1.wav")
		veh:Remove()

		ply:SetNWBool("IsDefecating", false)
		ply:SetNWInt("DefecateScore", 0)
	end)

	hook.Add("InitPostEntity", tag, function()
		for _, toilet in pairs(ents.FindByModel(model)) do
			if toilet:CreatedByMap() then
				toilet:SetNWBool("MapToilet", true)
			end
		end
	end)
end

if CLIENT then
	local toilets = {}
	-- _G.THETOILETS=toilets

	local function NotifyShouldTransmit(ent, should)
		if should then
			if ent:GetModel() == model then
				--print("maybe toilet?", ent)

				if ent:GetNWBool("MapToilet") then
					--print("toilet!", ent)
					toilets[ent] = ent:GetNetworkOrigin() -- GetPos is nil here
				end
			end
		else --if toilets[ent] then
			--print("toilet gone", ent)
			toilets[ent] = nil
		end
	end
	hook.Add("NotifyShouldTransmit", tag, NotifyShouldTransmit)
	
	-- preseed for development
	for k,v in pairs(ents.GetAll()) do
		if not v:IsDormant() then
			NotifyShouldTransmit(v,true)
		end
	end
	
	local poop_color = Color(89, 48, 1, 230)
	local TOILET_TRACE={
		mask = MASK_VISIBLE,
		output={}
	}

	local display_distance = 128^2
	local hit_pos_distance = 25^2
	hook.Add("HUDPaint", tag, function()
		
		
		local lp = LocalPlayer()
		if lp:GetNWBool("IsDefecating") then
			local bind = input.LookupBinding("+jump", true)
			if not bind then return end

			local i = (lp:GetNWInt("DefecateScore", 0) * 10) % 200

			surface.SetDrawColor(poop_color)

			local sw_half, sh_half = ScrW() / 2, ScrH() / 2
			local coef = math.sin(RealTime() * i) * 3
			surface.DrawRect((sw_half - 25) + coef, sh_half + 100 - i, 50, i)

			surface.SetDrawColor(255, 255 - i, 255 - i)
			surface.DrawOutlinedRect((sw_half - 25) + coef, sh_half - 100, 50, 200)

			local text = ("Mash [%s]"):format(bind)
			surface.SetFont("MTALargeFont")
			local tw, th = surface.GetTextSize(text)
			surface.SetTextPos((sw_half - tw / 2) + coef, sh_half - 140)
			surface.SetTextColor(255, 255 - i, 255 - i)
			surface.DrawText(text)
			return
		end
		
		local eye_pos = lp:EyePos()
		
		for toilet,toiletpos in pairs(toilets) do
			--debugoverlay.Text( toiletpos, tostring(toilet), 0.1, false )
			if toilet:IsValid() and toiletpos:DistToSqr(eye_pos) < display_distance then
				if not toilet:GetNWBool("ToiletInUse") then
					
					local bind = MTA.GetBindKey("+use")
					if not bind then return end
					
					TOILET_TRACE.start = eye_pos
					TOILET_TRACE.endpos = toiletpos
					local tr = util.TraceLine(TOILET_TRACE)

					if tr.HitPos:DistToSqr(toiletpos) < hit_pos_distance then
						MTA.HighlightPosition(toiletpos - toilet:GetUp() * 30, ("/// Defecate [%s] ///"):format(bind), color_white)
					end
				end
			end
		end
		
	end)
end
