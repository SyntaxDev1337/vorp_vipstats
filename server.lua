local VorpCore = exports.vorp_core:GetCore()
local SERVER_NAME = "🌵 YOUR NAME SERVER PVP"

-- Rank configuration
local RANK_ICONS = {
    ["vip"]       = { title = "VIP",          icon = "🌟" },
    ["admin"]     = { title = "Admin Access",  icon = "⭐" },
    ["moderator"] = { title = "Staff Access",  icon = "🤠" }
}

-- Arena names (customize as needed)
local ARENA_NAMES = {
    [1] = "Blackwater",
    [2] = "Saint Denis",
    [3] = "Annesburg",
    [4] = "Tumbleweed",
    [5] = "Strawberry",
    [6] = "Rhodes",
    [7] = "Armadillo"
}

-- ─────────────────────────────────────────────
-- Helper: get identifier + charid from source
-- ─────────────────────────────────────────────
local function getCharacterData(src)
    local User = VorpCore.getUser(src)
    if not User then return nil, nil, nil end

    local Character
    if type(User.getUsedCharacter) == "function" then
        Character = User.getUsedCharacter()
    else
        Character = User.usedCharacter or User.getUsedCharacter
    end
    if not Character then return nil, nil, nil end

    local identifier = Character.identifier
    local charid     = Character.charIdentifier or Character.charid
    return User, identifier, charid
end

-- ─────────────────────────────────────────────
-- /mystats  →  open advanced UI
-- ─────────────────────────────────────────────
RegisterNetEvent('vip_analytics:requestAdvancedStats')
AddEventHandler('vip_analytics:requestAdvancedStats', function()
    local src = source
    local User, identifier, charid = getCharacterData(src)
    if not identifier then return end

    -- Check rank from DB
    exports.oxmysql:execute('SELECT `group` FROM users WHERE identifier = ?', { identifier }, function(userRow)
        local playerGroup = "cowboy"
        if userRow and userRow[1] and userRow[1].group then
            playerGroup = tostring(userRow[1].group):lower()
        end

        if not RANK_ICONS[playerGroup] then
            VorpCore.NotifyLeft(src, "VIP Analytics", "Only VIP or Staff profiles are authorized to view advanced logs!", "generic_textures", "tick", 4000, "danger")
            return
        end

        local rankConfig = RANK_ICONS[playerGroup]

        -- 1. Global kill/hit totals  (FIX: index [1] not [0])
        exports.oxmysql:execute(
            'SELECT SUM(total_kills) as tkills, SUM(headshots) as ths, SUM(shots_hit) as thit, SUM(legs_hit) as tlegs FROM vip_weapons_analytics WHERE identifier = ? AND charid = ?',
            { identifier, charid },
            function(generalRes)
                local g = (generalRes and generalRes[1]) or {}
                local stats = {
                    total_kills = g.tkills  or 0,
                    hit_head    = g.ths     or 0,
                    hit_chest   = g.thit    or 0,
                    hit_legs    = g.tlegs   or 0,
                }

                -- 2. Per-arena data
                exports.oxmysql:execute(
                    'SELECT arena_id, SUM(time_seconds) as total_time, SUM(kills) as total_kills, SUM(deaths) as total_deaths FROM vip_arena_stats WHERE identifier = ? AND charid = ? GROUP BY arena_id',
                    { identifier, charid },
                    function(arenaRows)
                        local arenasData = {}
                        for i = 1, 7 do
                            arenasData[i] = { time = 0, kills = 0, deaths = 0, fav_weapon = "None" }
                        end

                        if arenaRows then
                            for _, row in ipairs(arenaRows) do
                                local id = tonumber(row.arena_id)
                                if id and id >= 1 and id <= 7 then
                                    arenasData[id].time   = math.floor((row.total_time or 0) / 60)
                                    arenasData[id].kills  = row.total_kills  or 0
                                    arenasData[id].deaths = row.total_deaths or 0
                                    arenasData[id].name   = ARENA_NAMES[id] or ("Arena " .. id)
                                end
                            end
                        end

                        -- Favorite weapon per arena
                        exports.oxmysql:execute(
                            'SELECT arena_id, weapon_name, SUM(total_kills) as wkills FROM vip_weapons_analytics WHERE identifier = ? AND charid = ? GROUP BY arena_id, weapon_name ORDER BY wkills DESC',
                            { identifier, charid },
                            function(favRows)
                                local seen = {}
                                if favRows then
                                    for _, row in ipairs(favRows) do
                                        local id = tonumber(row.arena_id)
                                        if id and id >= 1 and id <= 7 and not seen[id] then
                                            arenasData[id].fav_weapon = row.weapon_name or "None"
                                            seen[id] = true
                                        end
                                    end
                                end

                                -- 3. MVP match history
                                exports.oxmysql:execute(
                                    'SELECT * FROM vip_match_history WHERE identifier = ? AND charid = ? AND result = "MVP" ORDER BY id DESC LIMIT 10',
                                    { identifier, charid },
                                    function(historyRes)
                                        local matchHistory = {}
                                        if historyRes and #historyRes > 0 then
                                            for _, row in ipairs(historyRes) do
                                                table.insert(matchHistory, {
                                                    result     = "MVP",
                                                    arena_name = row.arena_name or "PvP Arena Match",
                                                    kills      = row.kills      or 0,
                                                    deaths     = row.deaths     or 0,
                                                    date       = row.date       or "Recent"
                                                })
                                            end
                                        end

                                        -- 4. Per-weapon stats
                                        exports.oxmysql:execute(
                                            'SELECT * FROM vip_weapons_analytics WHERE identifier = ? AND charid = ?',
                                            { identifier, charid },
                                            function(weaponsRes)
                                                local dbWeapons = {}
                                                if weaponsRes then
                                                    for _, row in ipairs(weaponsRes) do
                                                        local wn = row.weapon_name
                                                        if wn then
                                                            if not dbWeapons[wn] then
                                                                dbWeapons[wn] = {
                                                                    total_kills  = 0,
                                                                    headshots    = 0,
                                                                    shots_fired  = 0,
                                                                    shots_hit    = 0,
                                                                    legs_hit     = 0,
                                                                    fav_zone     = "Chest",
                                                                    minutes_used = 0
                                                                }
                                                            end
                                                            -- Aggregate across arenas
                                                            dbWeapons[wn].total_kills  = dbWeapons[wn].total_kills  + (row.total_kills  or 0)
                                                            dbWeapons[wn].headshots    = dbWeapons[wn].headshots    + (row.headshots    or 0)
                                                            dbWeapons[wn].shots_fired  = dbWeapons[wn].shots_fired  + (row.shots_fired  or 0)
                                                            dbWeapons[wn].shots_hit    = dbWeapons[wn].shots_hit    + (row.shots_hit    or 0)
                                                            dbWeapons[wn].legs_hit     = dbWeapons[wn].legs_hit     + (row.legs_hit     or 0)
                                                            dbWeapons[wn].minutes_used = dbWeapons[wn].minutes_used + (row.minutes_used or 0)
                                                            if (row.shots_hit or 0) > 0 then
                                                                dbWeapons[wn].fav_zone = row.fav_zone or "Chest"
                                                            end
                                                        end
                                                    end
                                                end

                                                TriggerClientEvent('vip_analytics:openAdvancedUI', src, stats, dbWeapons, arenasData, matchHistory, SERVER_NAME, rankConfig)
                                            end
                                        )
                                    end
                                )
                            end
                        )
                    end
                )
            end
        )
    end)
end)

-- ─────────────────────────────────────────────
-- Sync: weapon fire (1 shot counted server-side)
-- ─────────────────────────────────────────────
RegisterNetEvent('vip_analytics:syncWeaponFire')
AddEventHandler('vip_analytics:syncWeaponFire', function(weaponName, arenaId)
    local src = source
    local _, identifier, charid = getCharacterData(src)
    if not identifier then return end

    if not arenaId or arenaId < 1 or arenaId > 7 then arenaId = 0 end

    exports.oxmysql:execute(
        'INSERT INTO vip_weapons_analytics (identifier, charid, weapon_name, arena_id, shots_fired) VALUES (?, ?, ?, ?, 1) ON DUPLICATE KEY UPDATE shots_fired = shots_fired + 1',
        { identifier, charid, weaponName, arenaId }
    )
end)

-- ─────────────────────────────────────────────
-- Sync: weapon hit + zone
-- ─────────────────────────────────────────────
RegisterNetEvent('vip_analytics:syncWeaponHit')
AddEventHandler('vip_analytics:syncWeaponHit', function(weaponName, zone, arenaId)
    local src = source
    local _, identifier, charid = getCharacterData(src)
    if not identifier then return end

    if not arenaId or arenaId < 1 or arenaId > 7 then arenaId = 0 end

    local headshots = (zone == "Head") and 1 or 0
    local legsHit   = (zone == "Legs") and 1 or 0

    exports.oxmysql:execute(
        'INSERT INTO vip_weapons_analytics (identifier, charid, weapon_name, arena_id, shots_hit, headshots, legs_hit, fav_zone) VALUES (?, ?, ?, ?, 1, ?, ?, ?) ON DUPLICATE KEY UPDATE shots_hit = shots_hit + 1, headshots = headshots + ?, legs_hit = legs_hit + ?, fav_zone = ?',
        { identifier, charid, weaponName, arenaId, headshots, legsHit, zone, headshots, legsHit, zone }
    )
end)

-- ─────────────────────────────────────────────
-- Sync: arena time (every second)
-- ─────────────────────────────────────────────
RegisterNetEvent('vip_analytics:updateArenaTime')
AddEventHandler('vip_analytics:updateArenaTime', function(arenaId, seconds)
    local src = source
    local _, identifier, charid = getCharacterData(src)
    if not identifier then return end

    if not arenaId or arenaId < 1 or arenaId > 7 then return end

    exports.oxmysql:execute(
        'INSERT INTO vip_arena_stats (identifier, charid, arena_id, time_seconds) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE time_seconds = time_seconds + ?',
        { identifier, charid, arenaId, seconds, seconds }
    )
end)

-- ─────────────────────────────────────────────
-- Sync: save arena match to history on leave
-- ─────────────────────────────────────────────
RegisterNetEvent('vip_analytics:saveMatchToHistory')
AddEventHandler('vip_analytics:saveMatchToHistory', function(arenaId, timeSpent)
    local src = source
    local _, identifier, charid = getCharacterData(src)
    if not identifier then return end

    if not arenaId or arenaId < 1 or arenaId > 7 then return end

    local arenaName = ARENA_NAMES[arenaId] or ("Arena " .. arenaId)
    local currentDate = os.date("%m/%d/%Y")

    exports.oxmysql:execute(
        'INSERT INTO vip_match_history (identifier, charid, arena_name, result, kills, deaths, date) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { identifier, charid, arenaName, "Participant", 0, 0, currentDate }
    )
end)

-- ─────────────────────────────────────────────
-- MVP save — called SERVER-SIDE only by arena scripts
-- FIX: uses 'source' of the calling script, not a client param
-- Usage from another server script: TriggerEvent('vip_analytics:saveMVPMatch', playerSrc, arenaName, kills, deaths)
-- ─────────────────────────────────────────────
RegisterNetEvent('vip_analytics:saveMVPMatch')
AddEventHandler('vip_analytics:saveMVPMatch', function(targetSource, arenaName, kills, deaths)
    -- Only allow this from server-side (source == "" means server triggered)
    if source ~= "" then
        print("[vip_analytics] WARNING: saveMVPMatch must be called server-side only!")
        return
    end

    local _, identifier, charid = getCharacterData(targetSource)
    if not identifier then return end

    local currentDate = os.date("%m/%d/%Y")

    exports.oxmysql:execute(
        'INSERT INTO vip_match_history (identifier, charid, arena_name, result, kills, deaths, date) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { identifier, charid, arenaName, "MVP", kills, deaths, currentDate }
    )
end)

-- ─────────────────────────────────────────────
-- Sync: kill registered (called from arena/kill scripts)
-- ─────────────────────────────────────────────
RegisterNetEvent('vip_analytics:syncKill')
AddEventHandler('vip_analytics:syncKill', function(weaponName, arenaId)
    local src = source
    local _, identifier, charid = getCharacterData(src)
    if not identifier then return end

    if not arenaId or arenaId < 1 or arenaId > 7 then arenaId = 0 end

    exports.oxmysql:execute(
        'INSERT INTO vip_weapons_analytics (identifier, charid, weapon_name, arena_id, total_kills) VALUES (?, ?, ?, ?, 1) ON DUPLICATE KEY UPDATE total_kills = total_kills + 1',
        { identifier, charid, weaponName, arenaId }
    )

    if arenaId > 0 then
        exports.oxmysql:execute(
            'INSERT INTO vip_arena_stats (identifier, charid, arena_id, kills) VALUES (?, ?, ?, 1) ON DUPLICATE KEY UPDATE kills = kills + 1',
            { identifier, charid, arenaId }
        )
    end
end)
