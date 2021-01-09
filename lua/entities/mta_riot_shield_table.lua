AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Author = "Earu & Mavain"
ENT.Spawnable = false
ENT.AdminSpawnable = false
ENT.ms_notouch = true
ENT.lobbyok = true
ENT.PhysgunDisabled = true
ENT.dont_televate = true

local MTA_SHIELD_GUI_OPEN = "MTA_SHIELD_GUI_OPEN"

local CUSTOM_TEXTURE_WIDTH = 64
local CUSTOM_TEXTURE_HEIGHT = 108

if SERVER then

	util.AddNetworkString(MTA_SHIELD_GUI_OPEN)

	function ENT:Initialize()
		self:SetModel("models/cloud/ballisticshield_mod.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:Wake()
			phys:EnableMotion(false)
		end
	end

	function ENT:Use(activator)
		net.Start(MTA_SHIELD_GUI_OPEN)
		net.Send(activator)
	end
end

if CLIENT then
	pcall(include, "autorun/translation.lua")
	local L = translation and translation.L or function(s) return s end

	local models_to_load = {
		{ Model = "models/props_wasteland/controlroom_desk001b.mdl", Position = Vector(20, 5, 30), Angle = Angle(0, 90, -90) },
		{ Model = "models/props_c17/tools_wrench01a.mdl", Position = Vector(-1, 5, 20), Angle = Angle(-130, 90, -90) },
		{ Model = "models/props_c17/tools_wrench01a.mdl", Position = Vector(-1, 5, 30), Angle = Angle(75, 90, -90) }
	}

	local color_white = Color(255, 255, 255)
	local verb = L"Customize Shield"
	function ENT:Initialize()
		self.Models = {}
		for _, mdl_details in pairs(models_to_load) do
			local mdl = ClientsideModel(mdl_details.Model)
			mdl:SetParent(self)
			mdl:SetLocalAngles(mdl_details.Angle)
			mdl:SetLocalPos(mdl_details.Position)
			table.insert(self.Models, mdl)
		end

		hook.Add("HUDPaint", self, function()
			if MTA.IsOptedOut() then return end

			local bind = MTA.GetBindKey("+use")
			if not bind then return end

			local text = ("/// %s [%s] ///"):format(verb, bind)
			MTA.ManagedHighlightEntity(self, text, color_white)
		end)
	end

	function ENT:OnRemove()
		for _, mdl in pairs(self.Models) do
			SafeRemoveEntity(mdl)
		end
	end

	--[[
		Sometimes, I wonder why I do things the way I do...
		Its easier just to create a whole new vgui element than it is to hack another one to act as so.
		There **should** only be one instance of this ever created at any given time
		Should probably make it more obscure or something, I don't know quite yet.
	]]
	local buffer_data = {}
	local buffer_rt = GetRenderTargetEx("mta_shield_editor_buffer",
											1024,
											1024,
											RT_SIZE_LITERAL,
											MATERIAL_RT_DEPTH_NONE,
											1,
											0,
											-1
										)
	local buffer_mat = CreateMaterial("mta_shield_editor_material", "UnlitGeneric", {
		["$basetexture"] = buffer_rt:GetName(),
		["$translucent"] = 1
	})
	local grid_mat = Material("gui/alpha_grid.png", "noclamp")

	local tools = {
		Pen = {
			SetupToolState = function(self)
				self.ToolState.old_x = 0
				self.ToolState.old_y = 0
			end,
			MouseDown = function(self, x, y)
				self.ToolState.old_x = x
				self.ToolState.old_y = y
				self:DrawLine(x, y, x, y)
			end,
			MouseMove = function(self, x, y)
				self:DrawLine(x, y, self.ToolState.old_x, self.ToolState.old_y)
				self.ToolState.old_x, self.ToolState.old_y = x, y
			end,
			MouseUp = function(self, x, y)
			end,
			Preview = function(self, x, y)
			end
		},
		Box = {
			SetupToolState = function(self)
				self.ToolState.start_x = 0
				self.ToolState.start_y = 0
				self.ToolState.preview = false
			end,
			MouseDown = function(self, x, y)
				self.ToolState.start_x = x
				self.ToolState.start_y = y
				self.ToolState.preview = true
			end,
			MouseUp = function(self, x, y)
				local min_x, max_x = math.min(self.ToolState.start_x, x), math.max(self.ToolState.start_x, x)
				local min_y, max_y = math.min(self.ToolState.start_y, y), math.max(self.ToolState.start_y, y)
				local width = max_x - min_x + 1
				local height = max_y - min_y + 1
				self:DrawBox(min_x, min_y, width, height, true)
				self.ToolState.preview = false
			end,
			Preview = function(self, x, y)
				if not self.ToolState.preview then return end
				local min_x, max_x = math.min(self.ToolState.start_x, x), math.max(self.ToolState.start_x, x)
				local min_y, max_y = math.min(self.ToolState.start_y, y), math.max(self.ToolState.start_y, y)
				local width = max_x - min_x + 1
				local height = max_y - min_y + 1
				surface.SetDrawColor(self.ActiveColor.r, self.ActiveColor.g, self.ActiveColor.b, self.ActiveColor.a)
				local start_x, start_y = self:MapGridToCursor(min_x, min_y)
				surface.DrawRect(start_x, start_y, width * self.ZoomLevel, height * self.ZoomLevel)
			end
		},
		FloodFill = {
			SetupToolState = function(self)
			end,
			MouseDown = function(self, x, y)
				self:FloodFill(x, y)
			end,
			MouseUp = function(self, x, y)
			end,
			Preview = function(self, x, y)
			end
		}
	}

	local PIXEL_EDITOR = {
		Base = "DPanel"
	}
	function PIXEL_EDITOR:Init()
		self.ActiveColor = Color(255, 0, 0)
		self.TextureResolutionX = CUSTOM_TEXTURE_WIDTH
		self.TextureResolutionY = CUSTOM_TEXTURE_HEIGHT
		self.ZoomLevel = 1
		self.OffsetX = 0
		self.OffsetY = 0
		self.Panning = false
		self.PanningCursorX = 0
		self.PanningCursorY = 0
		self.GridX = 0
		self.GridY = 0
		self.Drawing = false
		self.PixelBuffer = {}
		self.Tool = tools.Pen
		self.ToolState = {}

		self.Tool.SetupToolState(self)

		render.PushRenderTarget(buffer_rt)
		render.OverrideAlphaWriteEnable(true, true)
		render.ClearDepth()
		render.Clear(0, 0, 0, 0)
			cam.Start2D()
				for y = 0, self.TextureResolutionY - 1 do
					for x = 0, self.TextureResolutionX - 1 do
						local pixel = buffer_data[x + y * self.TextureResolutionX]
						if pixel then
							surface.SetDrawColor(pixel.r, pixel.g, pixel.b, pixel.a)
							surface.DrawRect(x, y, 1, 1)
						end
					end
				end
			cam.End2D()
		render.OverrideAlphaWriteEnable(false)
		render.PopRenderTarget()
	end

	function PIXEL_EDITOR:InBounds(x, y)
		return x >= 0 and y >= 0 and x < self.TextureResolutionX and y < self.TextureResolutionY
	end

	function PIXEL_EDITOR:GetPixel(x, y)
		return buffer_data[x + y * self.TextureResolutionX] or Color(0, 0, 0, 0)
	end

	function PIXEL_EDITOR:SetTool(tool_name)
		if tools[tool_name] then
			self.Drawing = false
			self.ToolState = {}
			self.Tool = tools[tool_name]
			self.Tool.SetupToolState(self)
		end
	end

	-- Drawing Functions
	function PIXEL_EDITOR:DrawLine(start_x, start_y, end_x, end_y)
		--[[
		This is Bresenham's Line Algorithm
		Because I worked on this while I was super tired, so this kinda fails
		]]

		if start_x > end_x then -- We always draw from left to right, up and down doesn't matter
			local temp_x, temp_y = start_x, start_y
			start_x, start_y = end_x, end_y
			end_x, end_y = temp_x, temp_y
		end

		local delta_x = end_x - start_x
		local delta_y = end_y - start_y

		-- Get some edge cases out of the way (vertical, single pixel, etc.)
		if start_x == end_x then
			if start_y == end_y then
				table.insert(self.PixelBuffer, {x = start_x, y = start_y, color = self.ActiveColor})
				return
			elseif end_y > start_y then
				for y = start_y, end_y do
					table.insert(self.PixelBuffer, {x = start_x, y = y, color = self.ActiveColor})
				end
				return
			else
				for y = end_y, start_y do
					table.insert(self.PixelBuffer, {x = start_x, y = y, color = self.ActiveColor})
				end
				return
			end
		end

		if start_y <= end_y then -- Are we going down?
			if delta_x >= delta_y then -- Slope between 0 and 1 inclusive?
				local m_param = 2 * delta_y
				local err = m_param - delta_x
				local y = start_y
				for x = start_x, end_x do
					table.insert(self.PixelBuffer, {x = x, y = y, color = self.ActiveColor})
					err = err + m_param
					if err >= 0 then
						y = y + 1
						err = err - 2 * delta_x
					end
				end
			else
				local m_param = 2 * delta_x
				local err = m_param - delta_y
				local x = start_x
				for y = start_y, end_y do
					table.insert(self.PixelBuffer, {x = x, y = y, color = self.ActiveColor})
					err = err + m_param
					if err >= 0 then
						x = x + 1
						err = err - 2 * delta_y
					end
				end
			end
		else
			if delta_x >= -delta_y then -- Slope between 0 and -1 inclusive?
				local m_param = 2 * -delta_y
				local err = m_param - delta_x
				local y = start_y
				for x = start_x, end_x do
					table.insert(self.PixelBuffer, {x = x, y = y, color = self.ActiveColor})
					err = err + m_param
					if err >= 0 then
						y = y - 1
						err = err - 2 * delta_x
					end
				end
			else
				local m_param = 2 * delta_x
				local err = m_param + delta_y
				local x = start_x
				for y = start_y, end_y, -1 do
					table.insert(self.PixelBuffer, {x = x, y = y, color = self.ActiveColor})
					err = err + m_param
					if err >= 0 then
						x = x + 1
						err = err + 2 * delta_y
					end
				end
			end
		end
	end

	function PIXEL_EDITOR:DrawBox(start_x, start_y, width, height, blend)
		for x = start_x, start_x + width - 1 do
			for y = start_y, start_y + height - 1 do
				if self:InBounds(x, y) then
					table.insert(self.PixelBuffer, {x = x, y = y, color = self.ActiveColor, blend = blend})
				end
			end
		end
	end

	function PIXEL_EDITOR:FloodFill(origin_x, origin_y)
		if not self:InBounds(origin_x, origin_y) then return end

		local picked_color = self:GetPixel(origin_x, origin_y)
		if picked_color == self.ActiveColor then return end

		local candidates = {
			{ x = origin_x, y = origin_y }
		}

		local checked_pixels = {}
		while #candidates > 0 do
			local candidate = table.remove(candidates)
			if self:InBounds(candidate.x, candidate.y)
				and self:GetPixel(candidate.x, candidate.y) ~= picked_color
				and checked_pixels[candidate.x + candidate.y * self.TextureResolutionX]
			then

				checked_pixels[candidate.x + candidate.y * self.TextureResolutionX] = true

				table.insert(self.PixelBuffer, {x = candidate.x, y = candidate.y, color = self.ActiveColor})

				table.insert(candidates, { x = candidate.x - 1, y = candidate.y })
				table.insert(candidates, { x = candidate.x + 1, y = candidate.y })
				table.insert(candidates, { x = candidate.x, y = candidate.y - 1 })
				table.insert(candidates, { x = candidate.x, y = candidate.y + 1 })
			end
		end
	end

	function PIXEL_EDITOR:MapGridToCursor(x, y)
		local scaled_x = (x - self.OffsetX - self.TextureResolutionX / 2) * self.ZoomLevel + self:GetWide() / 2
		local scaled_y = (y - self.OffsetY - self.TextureResolutionY / 2) * self.ZoomLevel + self:GetTall() / 2
		return scaled_x, scaled_y
	end

	function PIXEL_EDITOR:MapCursorToGrid(x, y)
		--[[ This is code for grid -> cursor, so do opposite
		local scaled_x = (x - self.OffsetX - self.TextureResolutionX / 2) * self.ZoomLevel + self:GetWide() / 2
		local scaled_y = (y - self.OffsetY - self.TextureResolutionY / 2) * self.ZoomLevel + self:GetTall() / 2
		]]
		local grid_x = (x - self:GetWide() / 2) / self.ZoomLevel + self.OffsetX + (self.TextureResolutionX) / 2
		local grid_y = (y - self:GetTall() / 2) / self.ZoomLevel + self.OffsetY + (self.TextureResolutionY) / 2
		return math.floor(grid_x), math.floor(grid_y)
	end

	function PIXEL_EDITOR:OnMouseWheeled( delta )
		self.ZoomLevel = math.Clamp(self.ZoomLevel + delta, 1, 20)
		if self.PostZoomChanged then self:PostZoomChanged(self.ZoomLevel) end
	end

	function PIXEL_EDITOR:OnCursorMoved(cursorX, cursorY)
		if self.Panning then
			self.OffsetX = self.OffsetX - (cursorX - self.PanningCursorX) / self.ZoomLevel
			self.OffsetY = self.OffsetY - (cursorY - self.PanningCursorY) / self.ZoomLevel
		elseif self.Drawing then
			local grid_x, grid_y = self:MapCursorToGrid(cursorX, cursorY)
			if grid_x < 0 or grid_y < 0 or grid_x >= self.TextureResolutionX or grid_y >= self.TextureResolutionY then return end
			if self.Tool and self.Tool.MouseMove then
				self.Tool.MouseMove(self, grid_x, grid_y)
			end
		end
		self.PanningCursorX = cursorX
		self.PanningCursorY = cursorY
		self.GridX, self.GridY = self:MapCursorToGrid(cursorX, cursorY)
	end

	function PIXEL_EDITOR:OnMousePressed()
		if not self.Panning then
			if self.Tool and self.Tool.MouseDown then
				local x, y = self:MapCursorToGrid(self:LocalCursorPos())
				self.Tool.MouseDown(self, x, y)
				if self.Tool.MouseMove then
					self.Drawing = true
				end
			end
		end
	end

	function PIXEL_EDITOR:OnMouseReleased()
		if self.Tool and self.Tool.MouseUp then
			local x, y = self:MapCursorToGrid(self:LocalCursorPos())
			self.Tool.MouseUp(self, x, y)
		end
		self.Drawing = false
	end

	function PIXEL_EDITOR:Paint()
		-- Fill in stuff from pixel buffer to RT if needed
		if #self.PixelBuffer > 0 then
			render.PushRenderTarget(buffer_rt)
			render.OverrideAlphaWriteEnable(true, true)
			cam.Start2D()
			for i = 1, #self.PixelBuffer do
				local data = self.PixelBuffer[i]
				if not (data.x < 0 or data.y < 0 or data.x >= self.TextureResolutionX or data.y >= self.TextureResolutionY) then
					local cell_location = data.x + data.y * self.TextureResolutionX
					if data.blend then
						surface.SetDrawColor(data.color.r, data.color.g, data.color.b, data.color.a)
						surface.DrawRect(data.x, data.y, 1, 1)
						local old_color = buffer_data[cell_location] or Color(0, 0, 0, 0)
						local r = old_color.r * (1 - data.color.a / 255) + data.color.r * data.color.a
						local g = old_color.g * (1 - data.color.a / 255) + data.color.g * data.color.a
						local b = old_color.b * (1 - data.color.a / 255) + data.color.b * data.color.a
						local a = old_color.a * (1 - data.color.a / 255) + data.color.a * data.color.a
						buffer_data[cell_location] = Color(r, g, b, a)
					else
						render.SetScissorRect(data.x, data.y, data.x + 1, data.y + 1, true)
						render.Clear(0, 0, 0, 0)
						render.SetScissorRect(0, 0, 0, 0, false)
						surface.SetDrawColor(data.color.r, data.color.g, data.color.b, data.color.a)
						surface.DrawRect(data.x, data.y, 1, 1)
						buffer_data[cell_location] = data.color
					end
				end
			end
			self.PixelBuffer = {}
			cam.End2D()
			render.OverrideAlphaWriteEnable(false)
			render.PopRenderTarget()
		end

		-- Draw Background
		surface.SetDrawColor(150, 150, 150)
		surface.DrawRect(0, 0, self:GetWide(), self:GetTall())

		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(grid_mat)

		local scaled_x = (-self.OffsetX - self.TextureResolutionX / 2) * self.ZoomLevel + self:GetWide() / 2
		local scaled_y = (-self.OffsetY - self.TextureResolutionY / 2) * self.ZoomLevel + self:GetTall() / 2
		local aspect_ratio = self.TextureResolutionX / self.TextureResolutionY
		local zoom_level = self.ZoomLevel / 3
		surface.DrawTexturedRectUV(scaled_x, scaled_y,
									self.TextureResolutionX * self.ZoomLevel,
									self.TextureResolutionY * self.ZoomLevel,
									0, 0, aspect_ratio * zoom_level, zoom_level)

		rt_scale_x = (self.TextureResolutionX) / 1024
		rt_scale_y = (self.TextureResolutionY) / 1024
		sub_x = 0.5 / 1024
		sub_y = 0.5 / 1024
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(buffer_mat)
		render.PushFilterMin(TEXFILTER.POINT)
		render.PushFilterMag(TEXFILTER.POINT)
		surface.DrawTexturedRectUV(scaled_x, scaled_y,
									self.TextureResolutionX * self.ZoomLevel,
									self.TextureResolutionY * self.ZoomLevel,
									-sub_x, -sub_y, rt_scale_x - sub_x, rt_scale_y - sub_y)

		if self.Tool and self.Tool.Preview then
			local x, y = self:MapCursorToGrid(self:LocalCursorPos())
			self.Tool.Preview(self, x, y)
		end

		render.PopFilterMag()
		render.PopFilterMin()

		return true
	end

	function open_shield_gui()

		-- LocalPlayer() should not be NULL/nil/wtf ever in here
		MTA.ShieldTextureManager.LoadLocalFromFileOrMemory()
		buffer_data = LocalPlayer().MTAShieldTextureEditing.data

		local main_window = vgui.Create("DFrame")
		main_window:SetTitle("MTA Shield Customization - Main")
		main_window:SetSize(ScrW() * 0.4, ScrH() * 0.6)
		main_window:Center()
		main_window:SetVisible(true)
		main_window:ShowCloseButton(true)
		main_window:SetSizable(true)

		local pixel_editor = vgui.CreateFromTable(PIXEL_EDITOR, main_window)
		pixel_editor:Dock(FILL)
		function pixel_editor:PostZoomChanged(zoom)
			main_window:SetTitle(("MTA Shield Customization - Main (%dx Zoom)"):format(zoom))
		end

		function main_window:OnKeyCodePressed(key)
			if key == KEY_SPACE then
				pixel_editor.Panning = true
			end
		end

		function main_window:OnKeyCodeReleased(key)
			if key == KEY_SPACE then
				pixel_editor.Panning = false
			end
		end

		local color_picker_window = vgui.Create("DFrame")
		color_picker_window:SetTitle("MTA Shield Customization - Color")
		color_picker_window:SetSize(300, 300)
		color_picker_window:SetPos(ScrW() * 0.7, ScrH() * 0.2)
		color_picker_window:SetVisible(true)
		color_picker_window:SetSizable(true)

		local color_picker_element = vgui.Create("DColorMixer", color_picker_window)
		color_picker_element:Dock(FILL)

		function color_picker_element:ValueChanged(new_color)
			pixel_editor.ActiveColor = Color(new_color.r, new_color.g, new_color.b, new_color.a)
		end

		local tool_window = vgui.Create("DFrame")
		tool_window:SetTitle("MTA Shield Customization - Tools")
		tool_window:SetSize(300, ScrH() * 0.6 - 300)
		tool_window:SetPos(ScrW() * 0.7, ScrH() * 0.2 + 300)
		tool_window:SetVisible(true)
		tool_window:ShowCloseButton(true)
		tool_window:SetSizable(true)

		local tool_categories = vgui.Create("DCategoryList", tool_window)
		tool_categories:Dock(FILL)
		tool_category_general = tool_categories:Add("General")
		tool_category_general:Add("Pen").DoClick = function()
			pixel_editor:SetTool("Pen")
		end
		tool_category_general:Add("Box").DoClick = function()
			pixel_editor:SetTool("Box")
		end
		tool_category_general:Add("Flood Fill").DoClick = function()
			pixel_editor:SetTool("FloodFill")
		end

		local on_window_close = function()
			if IsValid(main_window) then main_window:Remove() end
			if IsValid(color_picker_window) then color_picker_window:Remove() end
			if IsValid(tool_window) then tool_window:Remove() end

			MTA.ShieldTextureManager.SaveLocal()
			MTA.ShieldTextureManager.Upload(buffer_data)
		end

		main_window.OnClose = on_window_close
		color_picker_window.OnClose = on_window_close
		tool_window.OnClose = on_window_close

		main_window:MakePopup()

	end

	net.Receive(MTA_SHIELD_GUI_OPEN, function(len)
		open_shield_gui()
	end)
end