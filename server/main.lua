--[[
    BSRP Housing — server
    Locations from bsrp_houselocations (imported from bsrpfreeroam.houselocations)
]]

local Houses = {} -- [name] = house def
local Ownership = {} -- [name] = { identifier, keyholders, locked }
local Inside = {} -- [src] = houseName

local function log(msg, ...)
    print(('[bsrp-housing] ' .. msg):format(...))
end

local function getIdentifier(src)
    if GetResourceState('bsrp') == 'started' then
        local id = exports.bsrp:GetIdentifier(src)
        if id then return id end
    end
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if id:find('license:') == 1 then return id end
    end
    return 'src:' .. tostring(src)
end

local function notify(src, msg, nType)
    TriggerClientEvent('bsrp:client:notify', src, msg, nType or 'info')
end

local function decodeJson(raw, fallback)
    if type(raw) == 'table' then return raw end
    if type(raw) ~= 'string' or raw == '' then return fallback or {} end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == 'table' then return data end
    return fallback or {}
end

local function ensureTables()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `bsrp_houselocations` (
          `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
          `name` VARCHAR(255) NOT NULL,
          `label` VARCHAR(255) NOT NULL,
          `coords` LONGTEXT NOT NULL,
          `price` INT NOT NULL DEFAULT 0,
          `tier` TINYINT NOT NULL DEFAULT 1,
          `garage` LONGTEXT NULL,
          PRIMARY KEY (`id`),
          UNIQUE KEY `uq_name` (`name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `bsrp_player_houses` (
          `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
          `house` VARCHAR(255) NOT NULL,
          `identifier` VARCHAR(64) NOT NULL,
          `keyholders` LONGTEXT NULL,
          `locked` TINYINT(1) NOT NULL DEFAULT 1,
          `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          UNIQUE KEY `uq_house` (`house`),
          KEY `idx_owner` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end

local function loadFromJsonFallback()
    local raw = LoadResourceFile(GetCurrentResourceName(), 'data/houselocations.json')
    if not raw or raw == '' then return 0 end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' then return 0 end
    local n = 0
    for _, h in ipairs(data) do
        if h.name then
            Houses[h.name] = {
                name = h.name,
                label = h.label or h.name,
                coords = h.coords or {},
                price = tonumber(h.price) or 0,
                tier = tonumber(h.tier) or Config.DefaultTier or 3,
                garage = h.garage,
            }
            n = n + 1
        end
    end
    return n
end

local function loadHouses()
    Houses = {}
    local rows = MySQL.query.await('SELECT name, label, coords, price, tier, garage FROM bsrp_houselocations') or {}
    if #rows == 0 then
        local n = loadFromJsonFallback()
        log('loaded %s houses from JSON fallback', n)
        return
    end
    for _, r in ipairs(rows) do
        Houses[r.name] = {
            name = r.name,
            label = r.label or r.name,
            coords = decodeJson(r.coords, {}),
            price = tonumber(r.price) or 0,
            tier = tonumber(r.tier) or Config.DefaultTier or 3,
            garage = decodeJson(r.garage, nil),
        }
    end
    log('loaded %s houses from MySQL', #rows)
end

local function loadOwnership()
    Ownership = {}
    local rows = MySQL.query.await('SELECT house, identifier, keyholders, locked FROM bsrp_player_houses') or {}
    for _, r in ipairs(rows) do
        Ownership[r.house] = {
            identifier = r.identifier,
            keyholders = decodeJson(r.keyholders, {}),
            locked = r.locked == nil and true or (r.locked == 1 or r.locked == true),
        }
    end
    log('loaded %s owned houses', #rows)
end

local function countOwned(identifier)
    local n = 0
    for _, o in pairs(Ownership) do
        if o.identifier == identifier then n = n + 1 end
    end
    return n
end

local function hasAccess(src, houseName)
    local o = Ownership[houseName]
    if not o then return false end
    local id = getIdentifier(src)
    if o.identifier == id then return true end
    if type(o.keyholders) == 'table' then
        for _, k in ipairs(o.keyholders) do
            if k == id then return true end
        end
    end
    return false
end

local function publicHouseList()
    local list = {}
    for name, h in pairs(Houses) do
        local enter = h.coords and h.coords.enter
        if enter and enter.x then
            local o = Ownership[name]
            list[#list + 1] = {
                name = name,
                label = h.label,
                price = h.price,
                tier = h.tier,
                enter = { x = enter.x, y = enter.y, z = enter.z, h = enter.h or 0.0 },
                garage = h.garage,
                owned = o ~= nil,
                owner = o and o.identifier or nil,
                locked = o and o.locked ~= false,
            }
        end
    end
    return list
end

local function interiorFor(tier)
    local interiors = Config.Interiors or {}
    return interiors[tier] or interiors[Config.DefaultTier or 3] or interiors[3]
end

local function stashId(houseName)
    return ('housing_%s'):format((houseName or 'x'):gsub('%s+', '_'))
end

local function registerStash(houseName, tier)
    if GetResourceState('ox_inventory') ~= 'started' then return end
    local cfg = (Config.Stash and Config.Stash[tier]) or { slots = 50, weight = 100000 }
    local house = Houses[houseName]
    pcall(function()
        exports.ox_inventory:RegisterStash(
            stashId(houseName),
            (house and house.label or houseName) .. ' Stash',
            cfg.slots,
            cfg.weight,
            false
        )
    end)
end

CreateThread(function()
    MySQL.ready(function()
        ensureTables()
        -- Import from JSON into DB if empty
        local count = MySQL.scalar.await('SELECT COUNT(*) FROM bsrp_houselocations') or 0
        if tonumber(count) == 0 then
            local raw = LoadResourceFile(GetCurrentResourceName(), 'data/houselocations.json')
            if raw and raw ~= '' then
                local ok, data = pcall(json.decode, raw)
                if ok and type(data) == 'table' then
                    local n = 0
                    for _, h in ipairs(data) do
                        MySQL.insert.await(
                            [[INSERT IGNORE INTO bsrp_houselocations (name, label, coords, price, tier, garage)
                              VALUES (?, ?, ?, ?, ?, ?)]],
                            {
                                h.name,
                                h.label or h.name,
                                json.encode(h.coords or {}),
                                tonumber(h.price) or 0,
                                tonumber(h.tier) or 3,
                                h.garage and json.encode(h.garage) or nil,
                            }
                        )
                        n = n + 1
                    end
                    log('imported %s houses into MySQL from JSON', n)
                end
            end
        end
        loadHouses()
        loadOwnership()
        for name, h in pairs(Houses) do
            if Ownership[name] then
                registerStash(name, h.tier)
            end
        end
    end)
end)

RegisterNetEvent('bsrp-housing:server:requestSync', function()
    local src = source
    TriggerClientEvent('bsrp-housing:client:sync', src, publicHouseList(), getIdentifier(src))
end)

RegisterNetEvent('bsrp-housing:server:buy', function(houseName)
    local src = source
    local h = Houses[houseName]
    if not h then
        notify(src, 'House not found', 'error')
        return
    end
    if Ownership[houseName] then
        notify(src, 'House already owned', 'error')
        return
    end
    local id = getIdentifier(src)
    local max = Config.MaxOwnedHouses or 3
    if countOwned(id) >= max then
        notify(src, ('You can only own %d houses'):format(max), 'error')
        return
    end
    local price = h.price or 0
    if price > 0 and GetResourceState('bsrp') == 'started' then
        if not exports.bsrp:RemoveMoney(src, 'bank', price, 'house_buy') then
            if not exports.bsrp:RemoveMoney(src, 'cash', price, 'house_buy') then
                notify(src, 'Not enough money', 'error')
                return
            end
        end
    end

    MySQL.insert.await(
        'INSERT INTO bsrp_player_houses (house, identifier, keyholders, locked) VALUES (?, ?, ?, 1)',
        { houseName, id, json.encode({ id }) }
    )
    Ownership[houseName] = { identifier = id, keyholders = { id }, locked = true }
    registerStash(houseName, h.tier)
    notify(src, ('Purchased %s for $%s'):format(h.label, price), 'success')
    log('%s bought %s', id, houseName)
    TriggerClientEvent('bsrp-housing:client:sync', -1, publicHouseList(), nil)
    TriggerClientEvent('bsrp-housing:client:sync', src, publicHouseList(), id)
end)

RegisterNetEvent('bsrp-housing:server:sell', function(houseName)
    local src = source
    local h = Houses[houseName]
    local o = Ownership[houseName]
    if not h or not o then return end
    local id = getIdentifier(src)
    if o.identifier ~= id then
        notify(src, 'You do not own this house', 'error')
        return
    end
    local refund = math.floor((h.price or 0) * (Config.SellBackPercent or 0.5))
    MySQL.update.await('DELETE FROM bsrp_player_houses WHERE house = ?', { houseName })
    Ownership[houseName] = nil
    if refund > 0 and GetResourceState('bsrp') == 'started' then
        exports.bsrp:AddMoney(src, 'bank', refund, 'house_sell')
    end
    notify(src, ('Sold %s for $%s'):format(h.label, refund), 'success')
    if Inside[src] == houseName then
        Inside[src] = nil
        SetPlayerRoutingBucket(src, 0)
        local enter = h.coords.enter
        TriggerClientEvent('bsrp-housing:client:exitHouse', src, {
            x = enter.x, y = enter.y, z = enter.z, h = enter.h or 0.0,
        })
    end
    TriggerClientEvent('bsrp-housing:client:sync', -1, publicHouseList(), nil)
end)

RegisterNetEvent('bsrp-housing:server:enter', function(houseName)
    local src = source
    local h = Houses[houseName]
    if not h then return end
    local o = Ownership[houseName]
    if not o then
        notify(src, 'House is not owned', 'error')
        return
    end
    if o.locked ~= false and not hasAccess(src, houseName) then
        notify(src, 'Door is locked', 'error')
        return
    end

    local interior = interiorFor(h.tier)
    if not interior then
        notify(src, 'Interior missing for this tier', 'error')
        return
    end

    -- Unique routing bucket per house
    local bucket = 20000 + (math.abs(GetHashKey(houseName)) % 30000)
    SetPlayerRoutingBucket(src, bucket)
    Inside[src] = houseName
    registerStash(houseName, h.tier)

    TriggerClientEvent('bsrp-housing:client:enterHouse', src, {
        house = houseName,
        label = h.label,
        tier = h.tier,
        interior = interior,
        stashId = stashId(houseName),
        isOwner = o.identifier == getIdentifier(src),
        locked = o.locked ~= false,
    })
end)

RegisterNetEvent('bsrp-housing:server:leave', function()
    local src = source
    local houseName = Inside[src]
    if not houseName then return end
    local h = Houses[houseName]
    Inside[src] = nil
    SetPlayerRoutingBucket(src, 0)
    if h and h.coords and h.coords.enter then
        local e = h.coords.enter
        TriggerClientEvent('bsrp-housing:client:exitHouse', src, {
            x = e.x, y = e.y, z = e.z, h = e.h or 0.0,
        })
    else
        TriggerClientEvent('bsrp-housing:client:exitHouse', src, nil)
    end
end)

RegisterNetEvent('bsrp-housing:server:toggleLock', function(houseName)
    local src = source
    local o = Ownership[houseName]
    if not o or o.identifier ~= getIdentifier(src) then
        notify(src, 'Only the owner can lock/unlock', 'error')
        return
    end
    o.locked = not (o.locked ~= false)
    MySQL.update.await('UPDATE bsrp_player_houses SET locked = ? WHERE house = ?', { o.locked and 1 or 0, houseName })
    notify(src, o.locked and 'House locked' or 'House unlocked', 'info')
    TriggerClientEvent('bsrp-housing:client:sync', -1, publicHouseList(), nil)
end)

RegisterNetEvent('bsrp-housing:server:openStash', function(houseName)
    local src = source
    if Inside[src] ~= houseName then return end
    if not hasAccess(src, houseName) then
        notify(src, 'No access', 'error')
        return
    end
    local h = Houses[houseName]
    registerStash(houseName, h and h.tier or 3)
    TriggerClientEvent('bsrp-housing:client:openStash', src, stashId(houseName))
end)

AddEventHandler('playerDropped', function()
    local src = source
    if Inside[src] then
        SetPlayerRoutingBucket(src, 0)
        Inside[src] = nil
    end
end)

-- Admin: give house
RegisterCommand('givehouse', function(source, args)
    if source ~= 0 then
        local p = GetResourceState('bsrp') == 'started' and exports.bsrp:GetPlayer(source)
        local level = p and (p.admin_level or 0) or 0
        if level < 2 and not IsPlayerAceAllowed(source, 'bsrp.admin') then
            notify(source, 'No permission', 'error')
            return
        end
    end
    local target = tonumber(args[1])
    local houseName = args[2] and table.concat(args, ' ', 2) or nil
    if not target or not houseName or not Houses[houseName] then
        if source == 0 then print('Usage: givehouse [id] [house name]') else notify(source, 'Usage: /givehouse [id] [house name]', 'error') end
        return
    end
    if Ownership[houseName] then
        if source == 0 then print('Already owned') else notify(source, 'Already owned', 'error') end
        return
    end
    local id = getIdentifier(target)
    MySQL.insert.await(
        'INSERT INTO bsrp_player_houses (house, identifier, keyholders, locked) VALUES (?, ?, ?, 1)',
        { houseName, id, json.encode({ id }) }
    )
    Ownership[houseName] = { identifier = id, keyholders = { id }, locked = true }
    registerStash(houseName, Houses[houseName].tier)
    notify(target, ('You received house: %s'):format(Houses[houseName].label), 'success')
    if source ~= 0 then notify(source, 'House given', 'success') end
    TriggerClientEvent('bsrp-housing:client:sync', -1, publicHouseList(), nil)
end, false)

print('^2[bsrp-housing]^7 server starting…')
