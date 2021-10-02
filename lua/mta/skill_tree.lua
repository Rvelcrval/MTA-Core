local NET_UPGRADE = "MTA_UPGRADE"
local POINT_MULTIPLIER = MTA_CONFIG.upgrades.PointMultiplier

local tree_data = {
	damage_multiplier = {
		Name = "Damage",
		Description = "The damages dealt to the combines",
		ComputeValue = function(lvl)
			local multiplier = lvl or MTA.GetPlayerStat("damage_multiplier")
			return ("%d%%"):format((100 + multiplier) * 2)
		end,
		Skills = {}
	},
	defense_multiplier = {
		Name = "Resistance",
		Description = "Resistance to the damages dealt by the combines",
		ComputeValue = function(lvl)
			local multiplier = lvl or MTA.GetPlayerStat("defense_multiplier")
			return ("%.2f%%"):format(multiplier * 0.75)
		end,
		Skills = {}
	},
	healing_multiplier = {
		Name = "Healing",
		Description = "Healing each 10 seconds while being wanted",
		ComputeValue = function(lvl)
			local multiplier = lvl or MTA.GetPlayerStat("healing_multiplier")
			return ("%dHPs"):format(math.ceil((multiplier * 1.6) / 2))
		end,
		Skills = {
			medic = {
				Name = "Medic",
				Description = "Health and armor chargers in the medbay become usable",
				Level = 15,
			}
		}
	}
}

local skill_level_map = {}

-- SKILLS
function MTA.HasSkill(ply, branch_name, skill_name)
	local branch_data = tree_data[branch_name]
	if not branch_data then return false end

	local skill_data = branch_data.Skills[skill_name]
	if not skill_data then return false end

	local cur_level = SERVER and MTA.GetPlayerStat(ply, branch_name) or MTA.GetPlayerStat(branch_name)
	return cur_level >= skill_data.Level
end

function MTA.RegisterSkill(skill_id, skill_branch, skill_level, skill_name, skill_description)
	local branch_data = tree_data[skill_branch]
	if not branch_data then return end

	branch_data.Skills[skill_id] = {
		Name = skill_name,
		Description = skill_description,
		Level = skill_level
	}

	skill_level_map[skill_level] = skill_level_map[skill_level] or {}
	if not table.HasValue(skill_level_map[skill_level], skill_id) then
		table.insert(skill_level_map[skill_level], skill_id)
	end
end

do -- load skills
	for _, f in pairs(file.Find("mta_skills/*.lua", "LUA")) do
		local path = "mta_skills/" .. f
		AddCSLuaFile(path)
		include(path)
	end
end

if CLIENT then
	local SKILL_TREE_PANEL = {}

	function SKILL_TREE_PANEL:Init()
		self.Branches = {}

		self:SetWide(800)
		self:SetDraggable(false)
		self:SetSizable(false)

		self:SetTitle("MTA Upgrades")
		self.btnMinim:Hide()
		self.btnMaxim:Hide()

		function self.btnClose:Paint(w, h)
			surface.SetTextColor(MTA.DangerColor)
			surface.SetFont("DermaDefault")

			local tw, th = surface.GetTextSize("X")
			surface.SetTextPos(w / 2 - tw / 2, h / 2 - th / 2)
			surface.DrawText("X")
		end

		self.Info = self:Add("DPanel")
		self.Info:SetTall(100)
		self.Info:Dock(TOP)
		self.Info:DockMargin(5, 5, 5, 5)

		self.Info.Title = self.Info:Add("DLabel")
		self.Info.Title:Dock(TOP)
		self.Info.Title:DockMargin(5, 5, 5, 0)
		self.Info.Title:SetTall(25)
		self.Info.Title:SetFont("DermaLarge")
		self.Info.Title:SetTextColor(MTA.PrimaryColor)

		self.Info.Description = self.Info:Add("DLabel")
		self.Info.Description:Dock(TOP)
		self.Info.Description:DockMargin(5, 0, 5, 0)
		self.Info.Description:SetTall(25)
		self.Info.Description:SetFont("DermaDefaultBold")
		self.Info.Description:SetTextColor(MTA.PrimaryColor)

		self.Info.Changes = self.Info:Add("DPanel")
		self.Info.Changes:Dock(TOP)
		self.Info.Changes:DockMargin(5, -15, 5, 0)
		self.Info.Changes:SetTall(60)
		self.Info.Changes.Paint = function() end

		self.Info.Changes.OldValue = self.Info.Changes:Add("DLabel")
		self.Info.Changes.OldValue:SetPos(5, 5)
		self.Info.Changes.OldValue:SetSize(100, 60)
		self.Info.Changes.OldValue:SetFont("DermaLarge")
		self.Info.Changes.OldValue:SetTextColor(MTA.OldValueColor)

		self.Info.Changes.Arrow = self.Info.Changes:Add("DLabel")
		self.Info.Changes.Arrow:SetPos(120, 3)
		self.Info.Changes.Arrow:SetSize(100, 60)
		self.Info.Changes.Arrow:SetFont("DermaLarge")
		self.Info.Changes.Arrow:SetTextColor(MTA.TextColor)
		self.Info.Changes.Arrow:SetText("»»")

		self.Info.Changes.NewValue = self.Info.Changes:Add("DLabel")
		self.Info.Changes.NewValue:SetPos(150, 5)
		self.Info.Changes.NewValue:SetSize(100, 60)
		self.Info.Changes.NewValue:SetFont("DermaLarge")
		self.Info.Changes.NewValue:SetTextColor(MTA.NewValueColor)

		self.Info.Unlock = self.Info:Add("DButton")
		self.Info.Unlock:SetSize(220, 50)
		self.Info.Unlock:SetFont("DermaLarge")
		self.Info.Unlock:SetText("Unlock")
		self.Info.Unlock:SetPos(self:GetWide() - (self.Info.Unlock:GetWide() + 50), self.Info:GetTall() / 2 - self.Info.Unlock:GetTall() / 2)

		local main_panel = self
		function self.Info.Unlock:DoClick()
			if not main_panel.SelectedLevel.Unlockable then return end

			net.Start(NET_UPGRADE)
			net.WriteString(main_panel.SelectedStat)
			net.SendToServer()
			surface.PlaySound("ui/buttonclick.wav")
		end

		function self.Info.Unlock:Paint(w, h)
			local p_r, p_g, p_b = MTA.PrimaryColor:Unpack()

			if self.Locked then
				surface.SetDrawColor(252, 71, 58, 10)
				surface.DrawRect(0, 0, w, h)

				surface.SetDrawColor(MTA.OldValueColor)
				surface.DrawOutlinedRect(0, 0, w, h, 2)
				return
			end

			if not self:IsEnabled() then
				surface.SetDrawColor(p_r, p_g, p_b, 10)
				surface.DrawRect(0, 0, w, h)

				surface.SetDrawColor(MTA.PrimaryColor)
				surface.DrawOutlinedRect(0, 0, w, h, 2)
				return
			end

			if not self:IsHovered() then
				surface.SetDrawColor(30, 30, 30)
			else
				surface.SetDrawColor(p_r, p_g, p_b, 10)
			end

			surface.DrawRect(0, 0, w, h)

			if not self:IsHovered() then
				surface.SetDrawColor(MTA.TextColor)
			else
				surface.SetDrawColor(p_r, p_g, p_b)
			end

			surface.DrawOutlinedRect(0, 0, w, h, 2)
		end

		function self.Info:Paint(w, h)
			local p_r, p_g, p_b = MTA.PrimaryColor:Unpack()

			surface.SetDrawColor(p_r, p_g, p_b)
			surface.DrawOutlinedRect(0, 0, w, h, 2)

			surface.SetDrawColor(p_r, p_g, p_b, 10)
			surface.DrawRect(0, 0, w, h)
		end
	end

	function SKILL_TREE_PANEL:SelectLevel(level_panel, stat_name)
		local branch_data = tree_data[stat_name] or {}

		if IsValid(self.SelectedLevel) then
			self.SelectedLevel.Selected = false
		end

		self.SelectedStat = stat_name
		self.SelectedLevel = level_panel
		level_panel.Selected = true

		self.Info.Title:SetText(("%s LVL. %d"):format(branch_data.Name or "???", level_panel.Level))
		self.Info.Description:SetText(branch_data.Description or "???")
		self.Info.Changes.OldValue:SetText(branch_data.ComputeValue())
		self.Info.Changes.NewValue:SetText(branch_data.ComputeValue(level_panel.Level))

		local cur_level = MTA.GetPlayerStat(stat_name)
		local completed = level_panel.Level <= cur_level
		local completable = level_panel.Level == cur_level + 1

		local text = "Unlock"
		local text_color = MTA.TextColor
		local locked = false
		if completed then
			text = "Unlocked ✓"
			text_color = MTA.PrimaryColor
			locked = false
		elseif completable then
			local cur_points = MTA.GetPlayerStat("points")
			local required_points = math.Round(math.exp(level_panel.Level * POINT_MULTIPLIER))

			text = ("Unlock (%dpts)"):format(required_points)
			local unlockable = cur_points >= required_points
			text_color = unlockable and MTA.TextColor or MTA.OldValueColor
			locked = false
			level_panel.Unlockable = unlockable
		else
			text = "Locked ✘"
			text_color = MTA.OldValueColor
			locked = true
		end

		self.Info.Unlock:SetEnabled(not completed and completable)
		self.Info.Unlock:SetTextColor(text_color)
		self.Info.Unlock:SetText(text)
		self.Info.Unlock.Locked = locked
	end

	function SKILL_TREE_PANEL:AddBranch(stat_name)
		local branch_data = tree_data[stat_name] or {}

		local branch_row = self:Add("Panel")
		branch_row:SetSize(self:GetWide(), 50)
		branch_row:Dock(TOP)
		branch_row:DockMargin(5, 5, 5, 5)
		table.insert(self.Branches, branch_row)

		local label = branch_row:Add("DLabel")
		label:SetText(branch_data.Name or "???")
		label:SetTextColor(MTA.TextColor)
		label:Dock(LEFT)
		label:DockMargin(10, 0, 10, 0)

		local level_margin = 10
		local level_size = 25
		local cur_level = MTA.GetPlayerStat(stat_name)
		local remaining_levels = 100 - cur_level
		local levels_to_show = math.min(remaining_levels, math.floor((branch_row:GetWide() - 75) / (level_margin + level_size)))
		local cur_x = 75
		for i = cur_level, cur_level + levels_to_show do
			local level_panel = branch_row:Add("DButton")
			level_panel:SetSize(level_size, level_size)
			level_panel:SetPos(cur_x + level_margin, branch_row:GetTall() / 2 - level_size / 2)
			level_panel:SetText(tostring(i))
			level_panel:SetTextColor(i <= cur_level and MTA.BackgroundColor or MTA.TextColor)
			level_panel.Level = i

			cur_x = cur_x + (level_margin + level_size)

			if not IsValid(self.SelectedLevel) then
				self:SelectLevel(level_panel, stat_name)
			end

			local main_panel = self
			function level_panel:DoClick()
				if self.Selected and self.Unlockable then
					net.Start(NET_UPGRADE)
					net.WriteString(stat_name)
					net.SendToServer()
					surface.PlaySound("ui/buttonclick.wav")
					return
				end

				main_panel:SelectLevel(self, stat_name)
			end

			local level_skills = skill_level_map[i] or {}
			local has_skills = false
			for _, skill_name in pairs(level_skills) do
				if branch_data.Skills[skill_name] then
					has_skills = true
					break
				end
			end

			function level_panel:HoverStateChanged(is_hovered)
				if not has_skills then return end

				if is_hovered then
					local hover_panel = vgui.Create("DLabel")
					hover_panel:SetWide(200)
					hover_panel:SetWrap(true)
					hover_panel:SetPos(gui.MouseX(), gui.MouseY())
					hover_panel:SetDrawOnTop(true)
					hover_panel:SetFont("DermaDefault")
					hover_panel:SetTextColor(MTA.PrimaryColor)

					local text = ""
					for _, skill_name in pairs(level_skills) do
						local skill_data = branch_data.Skills[skill_name]
						if skill_data then
							text = text .. ("\n%s:\n%s\n\n"):format(skill_data.Name, skill_data.Description)
						end
					end
					text = text:Trim()

					hover_panel:SetText(text)
					local text_h = (#text:Split("\n") + 4) * draw.GetFontHeight("DermaDefault")
					hover_panel:SetTall(text_h)

					function hover_panel:Paint(w, h)
						surface.DisableClipping(true)

						local bg_r, bg_g, bg_b = MTA.BackgroundColor:Unpack()
						surface.SetDrawColor(bg_r, bg_g, bg_b, 255)
						surface.DrawRect(-4, 10, w + 8, h - 20)

						surface.SetDrawColor(MTA.PrimaryColor)
						surface.DrawOutlinedRect(-4, 10, w + 8, h - 20)

						surface.DisableClipping(false)
					end

					function hover_panel:Think()
						if not IsValid(level_panel) then
							self:Remove()
						end
					end

					self.HoverPanel = hover_panel
				else
					if IsValid(self.HoverPanel) then
						self.HoverPanel:Remove()
					end
				end
			end

			local prev_hover_state = false
			function level_panel:Paint(w, h)
				local is_hovered = self:IsHovered()
				if prev_hover_state ~= is_hovered then
					level_panel:HoverStateChanged(is_hovered)
					prev_hover_state = is_hovered
				end

				local stat_level = MTA.GetPlayerStat(stat_name)
				local completed = i <= stat_level
				self:SetTextColor(completed and MTA.BackgroundColor or MTA.TextColor)
				if completed then
					surface.SetDrawColor(MTA.TextColor)
					surface.DrawRect(0, 0, w, h)
				else
					if i == stat_level + 1 then
						surface.SetDrawColor(MTA.TextColor)
					else
						surface.SetDrawColor(55, 55, 55)
					end
					surface.DrawOutlinedRect(0, 0, w, h)
				end

				if has_skills then
					local p_r, p_g, p_b = MTA.PrimaryColor:Unpack()
					surface.SetDrawColor(p_r, p_g, p_b, completed and 255 or 50)
					surface.DrawOutlinedRect(2, 2, w - 4, h - 4)
				end

				if self.Selected then
					surface.DisableClipping(true)
					surface.SetDrawColor(MTA.PrimaryColor)

					-- top left
					surface.DrawLine(-2, -2, -2, 2)
					surface.DrawLine(-2, -2, 2, -2)

					-- top right
					surface.DrawLine(w + 2, -2, w + 2, 2)
					surface.DrawLine(w + 2, -2, w - 2, -2)

					-- bottom left
					surface.DrawLine(-2, h + 2, -2, h - 2)
					surface.DrawLine(-2, h + 2, 2, h + 2)

					-- bottom right
					surface.DrawLine(w + 2, h + 2, w + 2, h - 2)
					surface.DrawLine(w + 2, h + 2, w - 2, h + 2)

					surface.DisableClipping(false)
				end
			end
		end

		function branch_row:Paint(w, h)
			surface.SetDrawColor(0, 0, 0, 240)
			surface.DrawRect(0, 0, w, h)

			surface.SetDrawColor(50, 50, 50)
			surface.DrawOutlinedRect(0, 0, w, h, 2)
			surface.DrawOutlinedRect(0, 0, 75, h, 2)
		end

		self:SetTall(self.Info:GetTall() + #self.Branches * 50 + 105)
		self:SetPos(0, ScrH() / 2 - self:GetTall() / 2)
	end

	function SKILL_TREE_PANEL:OnKeyCodePressed(key_code)
		if key_code == KEY_ESCAPE or key_code == KEY_E then
			self:Remove()
		end
	end

	function SKILL_TREE_PANEL:Paint(w, h)
		local p_r, p_g, p_b = MTA.PrimaryColor:Unpack()

		surface.SetDrawColor(0, 0, 0, 240)
		surface.DrawRect(0, 0, w, 25)

		surface.SetDrawColor(0, 0, 0, 200)
		surface.DrawRect(0, 25, w, h - 25)

		surface.SetFont("DermaDefault")
		surface.SetTextColor(p_r, p_g, p_b)

		local text = ("Points: %d"):format(MTA.GetPlayerStat("points"))
		surface.SetTextPos(10, h - 22)
		surface.DrawText(text)

		surface.SetDrawColor(p_r, p_g, p_b)
		surface.DrawOutlinedRect(0, h - 30, w, 30, 2)

		surface.SetDrawColor(p_r, p_g, p_b, 10)
		surface.DrawRect(0, h - 30, w, 30)
	end

	vgui.Register("MTASkillTree", SKILL_TREE_PANEL, "DFrame")

	local skill_tree
	function MTA.OpenSkillTree()
		if IsValid(skill_tree) then return end

		skill_tree = vgui.Create("MTASkillTree")
		for stat_name, _ in pairs(tree_data) do
			skill_tree:AddBranch(stat_name)
		end
		skill_tree:MakePopup()
		skill_tree:Center()
	end
end