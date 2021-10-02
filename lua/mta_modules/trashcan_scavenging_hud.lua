if SERVER then return end

require("bsp")

pcall(include, "autorun/translation.lua")
local L = translation and translation.L or function(s) return s end

local static_props = {}
pcall(function() static_props = game.OpenBSP():GetStaticProps().entries end)
if table.Count(static_props) then return end

local trash_models = {
	["models/props_trainstation/trashcan_indoor001a.mdl"] = true,
	["models/props_trainstation/trashcan_indoor001b.mdl"] = true,
	["models/props_junk/trashdumpster01a.mdl"] = true
}

local trashcans = {}
for _, static_prop in pairs(static_props) do
	if trash_models[static_prop.PropType:lower()] then
		table.insert(trashcans, static_prop)
	end
end

local display_distance = 128^2
local hit_pos_distance = 25^2
local offset = Vector(0, 0, 10)
local verb = L"Scavenge"

hook.Add("HUDPaint", "trashcans", function()
	local bind = MTA.GetBindKey("+use")
	if not bind then return end

	local lp = LocalPlayer()
	local text = ("/// %s [%s] ///"):format(verb, bind)
	local eye_pos = lp:EyePos()
	for _, trashcan in ipairs(trashcans) do
		local pos = trashcan.Origin + offset
		if pos:DistToSqr(eye_pos) < display_distance then
			local tr = util.TraceLine({
				start = eye_pos,
				endpos = pos,
				mask = MASK_VISIBLE,
			})

			if tr.HitPos:DistToSqr(pos) < hit_pos_distance then
				MTA.HighlightPosition(pos, text, MTA.TextColor)
			end
		end
	end
end)

