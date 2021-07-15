local TRACK_CB = {}
hook.Add("Tick", "CheckCB", function()
	local cb = ents.FindByClass("prop_combine_ball")
	for k, v in pairs(cb) do
		if not TRACK_CB[v] then
			TRACK_CB[v] = {true, v:GetPos(), CurTime()}
			ParticleEffectAttach("ar2_combineball", PATTACH_ABSORIGIN_FOLLOW, v, 0)
		else
			TRACK_CB[v][1] = true
			TRACK_CB[v][2] = v:GetPos()
		end
	end
end)