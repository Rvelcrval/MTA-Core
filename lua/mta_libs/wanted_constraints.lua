local tag = "wanted_constraints"

local players = {}

local ply_ents_to_remove = {
    gmod_wire_expression2 = function(e2)
        e2.error = true
    end,
    starfall_processor = function(sf)
        sf:Destroy()
        sf._didsetoff = true
    end,
}
local function constrain(ply, constraint_reason)
    players[ply] = constraint_reason or "unknown"

    if ply:InVehicle() then
        ply:ExitVehicle()
    end

    -- fuck you pac :)
    if pacx and pacx.SetPlayerSize then
        pacx.SetPlayerSize(ply, 1, true)
    end

    if ply.SetSuperJumpMultiplier then
        ply:SetSuperJumpMultiplier(1)
    end

    if ply.SetFlying then
        ply:SetFlying(false)
    end

    if ply:GetMoveType() == MOVETYPE_NOCLIP then
        ply:SetMoveType(MOVETYPE_WALK)
    end

    if prop_owner and prop_owner.GetTable then
        local entities = prop_owner.GetTable()
        for ent, owner in pairs(entities) do
            local callback = IsValid(ent) and ply_ents_to_remove[ent:GetClass()]
            if callback and owner == ply then
                if isfunction(callback) then
                    callback(ent)
                else
                    SafeRemoveEntity(ent)
                end
            end
        end
    end
end

local function release(ply)
    players[ply] = nil

    if ply.SetSuperJumpMultiplier then
        ply:SetSuperJumpMultiplier(1.5)
    end
end

local function is_constrained(ply)
    return players[ply] ~= nil
end

local function deny(ply)
    if is_constrained(ply) then
        local reason = players[ply]
        return false, reason
    end
end

hook.Add("CanPlyTeleport", tag, deny)
hook.Add("CanPlyGoBack", tag, deny)
hook.Add("OnPlayerSit", tag , deny)
hook.Add("CanBoxify", tag, deny)
hook.Add("PrePACConfigApply", tag, deny)
hook.Add("PlayerFly", tag, deny)
hook.Add("PlayerNoClip", tag, deny)

hook.Add("CanPlyCursedBullet", tag, function(ply, atck)
    if is_constrained(ply) or is_constrained(atck) then return false end
end)

hook.Add("PhysgunPickup", tag, function(ply, ent)
    if is_constrained(ply) then return false end
    if ent:IsPlayer() and is_constrained(ent) then return false end
end)

hook.Add("PlayerCanPickupItem", tag, function(ply, item)
    if is_constrained(ply) then
        -- disallow picking up dissolving items
        for _, ent in ipairs(item:GetChildren()) do
            if ent:GetClass() == "env_entity_dissolver" then
                return false
            end
        end
    end
end)

hook.Add("PlayerCanPickupWeapon", tag, function(ply, wep)
    if is_constrained(ply) then
        -- disallow picking up dissolving items
        for _, ent in ipairs(wep:GetChildren()) do
            if ent:GetClass() == "env_entity_dissolver" then
                return false
            end
        end
    end
end)

hook.Add("CanPlyUseMSItems", tag, function(ply, _, _)
    if is_constrained(ply) then
        return false
    end
end)

-- I tried using PlayerTeleported but it's broken
-- so we're hacking into this instead
hook.Add("CanPlyGoto", tag, function(ply)
    local old_pos = ply:GetPos()
    timer.Simple(0, function()
        if not IsValid(ply) then return end
        if ply.InLobby and ply:InLobby() and is_constrained(ply) then
            ply:SetPos(old_pos)
        end
    end)
end)

return constrain, release