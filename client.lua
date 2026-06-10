local isLoaded       = false
local currentArena   = 0
local arenaTime      = 0

-- Throttle: evităm spam-ul de fire events
local lastFireTime   = {}

local pvpWeapons = {
    [GetHashKey("WEAPON_REVOLVER_CATTLEMAN")]    = "Cattleman Revolver",
    [GetHashKey("WEAPON_REVOLVER_DOUBLEACTION")] = "Double Action Revolver",
    [GetHashKey("WEAPON_REVOLVER_SCHOFIELD")]    = "Schofield Revolver",
    [GetHashKey("WEAPON_REVOLVER_LEMAT")]        = "LeMat Revolver",
    [GetHashKey("WEAPON_PISTOL_VOLCANIC")]       = "Volcanic Pistol",
    [GetHashKey("WEAPON_PISTOL_SEMIAUTOMATIC")]  = "Semi-Automatic Pistol",
    [GetHashKey("WEAPON_PISTOL_MAUSER")]         = "Mauser Pistol",
    [GetHashKey("WEAPON_REPEATER_CARBINE")]      = "Carbine Repeater",
    [GetHashKey("WEAPON_REPEATER_LANCASTER")]    = "Lancaster Repeater",
    [GetHashKey("WEAPON_REPEATER_LITCHFIELD")]   = "Litchfield Repeater",
    [GetHashKey("WEAPON_REPEATER_EVANS")]        = "Evans Repeater",
    [GetHashKey("WEAPON_RIFLE_SPRINGFIELD")]     = "Springfield Rifle",
    [GetHashKey("WEAPON_RIFLE_BOLTACTION")]      = "Bolt Action Rifle",
    [GetHashKey("WEAPON_SNIPERRIFLE_ROLLINGBLOCK")] = "Rolling Block Rifle",
    [GetHashKey("WEAPON_SNIPERRIFLE_CARCANO")]   = "Carcano Rifle",
    [GetHashKey("WEAPON_SHOTGUN_SAWEDOFF")]      = "Sawed-Off Shotgun",
    [GetHashKey("WEAPON_SHOTGUN_PUMP")]          = "Pump Action Shotgun",
    [GetHashKey("WEAPON_SHOTGUN_DOUBLEBARREL")]  = "Double-Barrel Shotgun",
    [GetHashKey("WEAPON_SHOTGUN_REPEATING")]     = "Repeating Shotgun"
}

-- ─────────────────────────────────────────────
-- Arena assignment (triggerata de alte scripturi)
-- ─────────────────────────────────────────────
RegisterNetEvent('vip_analytics:setPlayerArena')
AddEventHandler('vip_analytics:setPlayerArena', function(arenaNumber)
    if arenaNumber and arenaNumber >= 1 and arenaNumber <= 7 then
        currentArena = arenaNumber
        arenaTime    = 0
    else
        -- A ieșit din arenă → salvăm timpul
        if currentArena > 0 then
            TriggerServerEvent('vip_analytics:saveMatchToHistory', currentArena, arenaTime)
        end
        currentArena = 0
        arenaTime    = 0
    end
end)

-- ─────────────────────────────────────────────
-- Comandă /mystats
-- ─────────────────────────────────────────────
RegisterCommand('mystats', function()
    TriggerServerEvent('vip_analytics:requestAdvancedStats')
end, false)

-- ─────────────────────────────────────────────
-- Thread 1: Timer per-arenă (1 tick/secundă)
-- ─────────────────────────────────────────────
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)

        if currentArena > 0 then
            arenaTime = arenaTime + 1
            TriggerServerEvent('vip_analytics:updateArenaTime', currentArena, 1)
        end
    end
end)

-- ─────────────────────────────────────────────
-- Thread 2: Detectare foc (un singur foc per apăsare)
-- Folosim flag wasFiring pentru a număra doar leading edge
-- ─────────────────────────────────────────────
Citizen.CreateThread(function()
    local wasFiring = false

    while true do
        Citizen.Wait(50) -- 20Hz e suficient

        local ped = PlayerPedId()
        local _, hash = GetCurrentPedWeapon(ped, true, 0, true)

        if pvpWeapons[hash] then
            local isShooting = IsPedShooting(ped)

            -- Leading edge: tocmai a început să tragă
            if isShooting and not wasFiring then
                local wName = pvpWeapons[hash]
                TriggerServerEvent('vip_analytics:syncWeaponFire', wName, currentArena)
            end

            wasFiring = isShooting
        else
            wasFiring = false
        end
    end
end)

-- ─────────────────────────────────────────────
-- Thread 3: Detectare hit pe alt jucător
-- Rulăm la 100ms (nu 10ms) — suficient pentru combat
-- ─────────────────────────────────────────────
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)

        local ped      = PlayerPedId()
        local _, hash  = GetCurrentPedWeapon(ped, true, 0, true)

        if not pvpWeapons[hash] then goto continue end

        local players = GetActivePlayers()
        for _, playerId in ipairs(players) do
            if playerId ~= PlayerId() then
                local targetPed = GetPlayerPed(playerId)

                if targetPed and targetPed ~= 0 and HasEntityBeenDamagedByEntity(targetPed, ped, true) then
                    local wName = pvpWeapons[hash]

                    -- Determinăm zona lovită
                    local found, hitBone = GetPedLastDamageBone(targetPed)
                    local zone = "Chest"

                    if found then
                        -- Bone IDs aproximative RDR2/RedM pentru cap
                        if hitBone == 21030 or hitBone == 14283 or hitBone == 12844 then
                            zone = "Head"
                        -- Bone IDs pentru picioare (femur, tibie, gleznă)
                        elseif hitBone == 58271 or hitBone == 63931 or hitBone == 36864
                            or hitBone == 14201 or hitBone == 51826 or hitBone == 16335 then
                            zone = "Legs"
                        end
                    end

                    TriggerServerEvent('vip_analytics:syncWeaponHit', wName, zone, currentArena)
                    ClearEntityLastDamageEntity(targetPed)
                end
            end
        end

        ::continue::
    end
end)

-- ─────────────────────────────────────────────
-- NUI: deschide UI cu datele primite de la server
-- ─────────────────────────────────────────────
RegisterNetEvent('vip_analytics:openAdvancedUI')
AddEventHandler('vip_analytics:openAdvancedUI', function(dbData, dbWeapons, arenasData, matchHistory, serverName, rankConfig)
    SetNuiFocus(true, true)

    local uiWeapons = {}
    for _, name in pairs(pvpWeapons) do
        local totalK = 0; local hs = 0; local fired = 0; local hit = 0
        local zone = "Chest"; local minUsed = 0; local legsHit = 0

        if dbWeapons and dbWeapons[name] then
            local d   = dbWeapons[name]
            totalK    = d.total_kills  or 0
            hs        = d.headshots    or 0
            fired     = d.shots_fired  or 0
            hit       = d.shots_hit    or 0
            zone      = d.fav_zone     or "Chest"
            minUsed   = d.minutes_used or 0
            legsHit   = d.legs_hit     or 0
        end

        table.insert(uiWeapons, {
            name          = name,
            minutes_used  = minUsed,
            total_kills   = totalK,
            headshots     = hs,
            legs_hit      = legsHit,
            fired         = fired,
            hit           = hit,
            favorite_zone = zone
        })
    end

    -- Sortăm după kills (cele mai folosite primele)
    table.sort(uiWeapons, function(a, b) return a.total_kills > b.total_kills end)

    SendNUIMessage({
        action     = "open",
        serverName = serverName,
        rankData   = rankConfig,
        stats      = dbData,
        weapons    = uiWeapons,
        arenas     = arenasData,
        history    = matchHistory
    })
end)

-- ─────────────────────────────────────────────
-- NUI Callback: închide UI
-- ─────────────────────────────────────────────
RegisterNUICallback('closeUI', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)
