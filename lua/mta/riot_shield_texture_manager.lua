local MTA_SHIELD_TEXTURE_REQUEST = "MTA_SHIELD_TEXTURE_REQUEST"
local MTA_SHIELD_TEXTURE_UPDATE_BROADCAST = "MTA_SHIELD_TEXTURE_UPDATE_BROADCAST"
local MTA_SHIELD_TEXTURE_UPDATE = "MTA_SHIELD_TEXTURE_UPDATE"
local MTA_SHIELD_TEXTURE_MANAGER_DISCONNECT = "MTAShieldTextureManagerDisconnect"
local MTA_SHIELD_TEXTURE_MANAGER_CONNECT = "MTAShieldTextureManagerConnect"

local CUSTOM_TEXTURE_WIDTH = 64
local CUSTOM_TEXTURE_HEIGHT = 108

local function net_colors_to_table()
    local size = net.ReadUInt(32)
    local data = util.Decompress(net.ReadData(size))

    if SERVER then
        MTA.Print("Received shield data, length: " .. size)
    end

    local colors = {}
    
    for index = 0, CUSTOM_TEXTURE_WIDTH * CUSTOM_TEXTURE_HEIGHT - 1 do
        local red = string.byte(data[index * 4 + 1]) or 0
        local green = string.byte(data[index * 4 + 2]) or 0
        local blue = string.byte(data[index * 4 + 3]) or 0
        local alpha = string.byte(data[index * 4 + 4]) or 0

        colors[index] = Color(red, green, blue, alpha)
    end

    return colors
end
local function net_table_to_colors(colors)

    local number_string = ""
    for index = 0, CUSTOM_TEXTURE_WIDTH * CUSTOM_TEXTURE_HEIGHT - 1 do
        local color = colors[index]
        number_string = number_string .. string.char(color.r, color.g, color.b, color.a)
    end

    local raw_string = util.Compress(number_string)
    net.WriteUInt(#raw_string, 32)
    net.WriteData(raw_string, #raw_string)
end

local cached_textures = {}

if SERVER then
    util.AddNetworkString(MTA_SHIELD_TEXTURE_REQUEST)
    util.AddNetworkString(MTA_SHIELD_TEXTURE_UPDATE_BROADCAST)
    util.AddNetworkString(MTA_SHIELD_TEXTURE_UPDATE)

    local players_first_upload = {}

    hook.Add("PlayerDisconnected", MTA_SHIELD_TEXTURE_MANAGER_DISCONNECT, function(ply)
        players_first_upload[ply] = nil
    end)

    net.Receive(MTA_SHIELD_TEXTURE_UPDATE_BROADCAST, function(len, ply)
		local data = net_colors_to_table()

        if not players_first_upload[ply] then
            players_first_upload[ply] = true
        else
            if ply:GetCoins() < 5000 then return end
            ply:TakeCoins(5000)
        end

		cached_textures[ply] = {
			width = CUSTOM_TEXTURE_WIDTH,
			height = CUSTOM_TEXTURE_HEIGHT,
			data = data
        }

		net.Start(MTA_SHIELD_TEXTURE_UPDATE, true)
		net.WriteEntity(ply)
		net_table_to_colors(data)
		net.Broadcast()
    end)

    net.Receive(MTA_SHIELD_TEXTURE_REQUEST, function(len, ply)
        local texture_ply = net.ReadEntity()
        if not IsValid(texture_ply) then return end
        local texture = cached_textures[texture_ply]
        if texture then
            net.Start(MTA_SHIELD_TEXTURE_UPDATE, true)
            net.WriteEntity(texture_ply)
            net_table_to_colors(texture.data)
            net.Send(ply)
        end
    end)
end

if CLIENT then
    net.Receive(MTA_SHIELD_TEXTURE_UPDATE, function(len)
		local ply = net.ReadEntity()
		local texture_data = net_colors_to_table()
		if not IsValid(ply) then return end
		cached_textures[ply] = {
			width = CUSTOM_TEXTURE_WIDTH,
			height = CUSTOM_TEXTURE_HEIGHT,
			data = texture_data
		}
	end)

    MTA.ShieldTextureManager = {}

    local requested = {} -- Used for internal timer to prevent spamming in draw hooks
    function MTA.ShieldTextureManager.Get(ply)
        if not IsValid(ply) then return nil end
        if cached_textures[ply] then return cached_textures[ply] end
        if not requested[ply] then
            net.Start(MTA_SHIELD_TEXTURE_REQUEST)
            net.WriteEntity(ply)
            net.SendToServer()
            requested[ply] = CurTime() + 10
        else
            if requested[ply] > CurTime() then
                requested[ply] = nil
            end
        end
        return nil
    end

    function MTA.ShieldTextureManager.UploadDirect(data)
        net.Start(MTA_SHIELD_TEXTURE_UPDATE_BROADCAST)
        net_table_to_colors(data)
        net.SendToServer()
    end

    function MTA.ShieldTextureManager.Upload(data)
        Derma_Query("Upload Shield to server?", "MTA Shield Customization - Upload", "Yes", function()
            MTA.ShieldTextureManager.UploadDirect(data)
        end, "No")
    end

    function MTA.ShieldTextureManager.SaveLocal()
        if not LocalPlayer().MTAShieldTextureEditing then return end
        MTA.Print("Saving shield to file")
        if not file.Exists("mta", "DATA") then
            file.CreateDir("mta")
        end
        file.Write("mta/shield.txt", util.TableToJSON(LocalPlayer().MTAShieldTextureEditing.data, true))
    end

    function MTA.ShieldTextureManager.LoadLocalFromFileOrMemory()
        if LocalPlayer().MTAShieldTextureEditing then return end
        if file.Exists("mta/shield.txt", "DATA") then
            local data = util.JSONToTable(file.Read("mta/shield.txt", "DATA"))
            if data then
                LocalPlayer().MTAShieldTextureEditing = {
                    width = CUSTOM_TEXTURE_WIDTH,
                    height = CUSTOM_TEXTURE_HEIGHT,
                    data = data
                }
            else
                LocalPlayer().MTAShieldTextureEditing = {
                    width = CUSTOM_TEXTURE_WIDTH,
                    height = CUSTOM_TEXTURE_HEIGHT,
                    data = {}
                }
            end
        else
            LocalPlayer().MTAShieldTextureEditing = {
                width = CUSTOM_TEXTURE_WIDTH,
                height = CUSTOM_TEXTURE_HEIGHT,
                data = {}
            }
        end
    end

    hook.Add("InitPostEntity", MTA_SHIELD_TEXTURE_MANAGER_CONNECT, function()
        MTA.ShieldTextureManager.LoadLocalFromFileOrMemory()
        MTA.ShieldTextureManager.UploadDirect(LocalPlayer().MTAShieldTextureEditing.data)
    end)

end