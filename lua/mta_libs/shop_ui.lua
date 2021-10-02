if SERVER then return end

local PANEL = {}
function PANEL:Init()
    self:SetSkin("MTA")
    derma.RefreshSkins()

    do -- header
        local header = self:Add("DPanel")
        header:Dock(TOP)
        header:SetTall(50)

        local dealer_av = header:Add("DModelPanel")
        dealer_av:Dock(LEFT)
        dealer_av:SetModel("models/props_junk/PopCan01a.mdl")
        self.HeaderAvatar = dealer_av

        function dealer_av:LayoutEntity(ent)
            ent:SetSequence(ent:LookupSequence("idle_subtle"))
            self:RunAnimation()
        end

        local intro = header:Add("DLabel")
        intro:Dock(FILL)
        intro:SetText("Hey there!")
        intro:SetWrap(true)
        self.HeaderText = intro
    end

    local content = self:Add("DScrollPanel")
    content:Dock(FILL)
    content:DockMargin(5, 10, 5, 5)
    self.Content = content
end

function PANEL:SetHeader(npc, header_text)
    if IsValid(npc) then
        self.HeaderAvatar:SetModel(npc:GetModel())

        local bone_number = self.HeaderAvatar.Entity:LookupBone("ValveBiped.Bip01_Head1")
        if bone_number then
            local head_pos = self.HeaderAvatar.Entity:GetBonePosition(bone_number)
            if head_pos then
                self.HeaderAvatar:SetLookAt(head_pos)
                self.HeaderAvatar:SetCamPos(head_pos - Vector(-13, 0, 0))

                print(self.HeaderAvatar)
            end
        end
    end

    header_text = (header_text or ""):Trim()
    if #header_text > 0 then
        self.HeaderText:SetText(header_text)
    end
end

function PANEL:OnKeyCodePressed(key_code)
    if key_code == KEY_ESCAPE or key_code == KEY_E then
        self:Remove()
    end
end

local proper_stat_names = {
    points = "Points",
    killed_cops = "Killed Cops",
    criminal_count = "Times Wanted"
}

local stat_height_margin = 10
local stat_width_margin = 20
function PANEL:PaintOver(w, h)
    local p_r, p_g, p_b = MTA.PrimaryColor:Unpack()

    local current_width = 0
    local i = 1
    for stat_name, proper_name in pairs(proper_stat_names) do
        surface.SetFont("DermaDefault")
        surface.SetTextColor(p_r, p_g, p_b)

        local text = ("%s: %d"):format(proper_name, MTA.GetPlayerStat(stat_name))
        local tw, th = surface.GetTextSize(text)
        surface.SetTextPos(i * stat_width_margin + current_width, h - (th + stat_height_margin))
        surface.DrawText(text)

        current_width = current_width + tw
        i = i + 1
    end

    surface.SetDrawColor(p_r, p_g, p_b)
    surface.DrawOutlinedRect(0, h - 30, w, 30, 2)

    surface.SetDrawColor(p_r, p_g, p_b, 10)
    surface.DrawRect(0, h - 30, w, 30)
end

vgui.Register("mta_shop", PANEL, "DFrame")