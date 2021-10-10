if not SERVER then return end

hook.Add("InitPostEntity", "MTAGMBadges", function()
	if not MetaBadges then return end

	-- daily commitment
	do
		local levels = {
			default = {
				title = "Daily Commitment",
				description = "Amount of MTA daily challenges you've completed"
			}
		}

		MetaBadges.RegisterBadge("daily_commitment", {
			basetitle = "Daily Commitment",
			levels = levels,
			level_interpolation = MetaBadges.INTERPOLATION_FLOOR
		})
	end
end)