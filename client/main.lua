local Houses = {} -- synced list
local MyIdentifier = nil
local nearHouse = nil
local insideHouse = nil
local blips = {}
local menuOpen = false

local function notify(msg, nType)
    if GetResourceState('bsrp') == 'started' then
        exports.bsrp:Notify(msg, nType or 'info')
    end
end

local function clearBlips()
    for _, b in pairs(blips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    blips = {}
end

local function refreshBlips()
    clearBlips()
    for _, h in ipairs(Houses) do
        if not h.enter then goto continue end
        local isMine = MyIdentifier and h.owner == MyIdentifier
        if isMine and Config.BlipOwned then
            local b = AddBlipForCoord(h.enter.x, h.enter.y, h.enter.z)
            SetBlipSprite(b, Config.Blip.owned.sprite)
            SetBlipColour(b, Config.Blip.owned.color)
            SetBlipScale(b, Config.Blip.owned.scale)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(h.label or Config.Blip.owned.label)
            EndTextCommandSetBlipName(b)
            blips[#blips + 1] = b
        elseif not h.owned and Config.BlipForSale then
            local b = AddBlipForCoord(h.enter.x, h.enter.y, h.enter.z)
            SetBlipSprite(b, Config.Blip.sale.sprite)
            SetBlipColour(b, Config.Blip.sale.color)
            SetBlipScale(b, Config.Blip.sale.scale)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(Config.Blip.sale.label)
            EndTextCommandSetBlipName(b)
            blips[#blips + 1] = b
        end
        ::continue::
    end
end

RegisterNetEvent('bsrp-housing:client:sync', function(list, identifier)
    Houses = list or {}
    if identifier then MyIdentifier = identifier end
    refreshBlips()
end)

local function openMenu(house)
    menuOpen = true
    SetNuiFocus(true, true)
    local isMine = MyIdentifier and house.owner == MyIdentifier
    SendNUIMessage({
        action = 'open',
        data = {
            name = house.name,
            label = house.label,
            price = house.price,
            tier = house.tier,
            owned = house.owned,
            locked = house.locked,
            isMine = isMine,
            hasAccess = isMine or (house.owned and not house.locked),
            inside = insideHouse ~= nil,
        },
    })
end

local function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb({ ok = true })
end)

RegisterNUICallback('buy', function(data, cb)
    if data and data.name then
        TriggerServerEvent('bsrp-housing:server:buy', data.name)
    end
    closeMenu()
    cb({ ok = true })
end)

RegisterNUICallback('sell', function(data, cb)
    if data and data.name then
        TriggerServerEvent('bsrp-housing:server:sell', data.name)
    end
    closeMenu()
    cb({ ok = true })
end)

RegisterNUICallback('enter', function(data, cb)
    if data and data.name then
        TriggerServerEvent('bsrp-housing:server:enter', data.name)
    end
    closeMenu()
    cb({ ok = true })
end)

RegisterNUICallback('leave', function(_, cb)
    TriggerServerEvent('bsrp-housing:server:leave')
    closeMenu()
    cb({ ok = true })
end)

RegisterNUICallback('lock', function(data, cb)
    if data and data.name then
        TriggerServerEvent('bsrp-housing:server:toggleLock', data.name)
    end
    cb({ ok = true })
end)

RegisterNUICallback('stash', function(data, cb)
    if data and data.name then
        TriggerServerEvent('bsrp-housing:server:openStash', data.name)
    end
    closeMenu()
    cb({ ok = true })
end)

RegisterNetEvent('bsrp-housing:client:enterHouse', function(payload)
    if type(payload) ~= 'table' or not payload.interior then return end
    insideHouse = payload
    local exit = payload.interior.exit or payload.interior.door
    DoScreenFadeOut(300)
    Wait(350)
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, exit.x, exit.y, exit.z, false, false, false)
    SetEntityHeading(ped, exit.w or 0.0)
    FreezeEntityPosition(ped, false)
    DoScreenFadeIn(400)
    notify(('Entered %s'):format(payload.label or 'house'), 'success')
end)

RegisterNetEvent('bsrp-housing:client:exitHouse', function(pos)
    insideHouse = nil
    DoScreenFadeOut(300)
    Wait(350)
    if pos and pos.x then
        local ped = PlayerPedId()
        SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
        SetEntityHeading(ped, pos.h or 0.0)
    end
    DoScreenFadeIn(400)
    notify('Left house', 'info')
end)

RegisterNetEvent('bsrp-housing:client:openStash', function(id)
    if GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:openInventory('stash', id)
    else
        notify('ox_inventory required for stash', 'error')
    end
end)

-- Proximity loop
CreateThread(function()
    while true do
        local sleep = 800
        if not menuOpen then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            nearHouse = nil

            if insideHouse then
                sleep = 0
                local interior = insideHouse.interior
                local door = interior.door or interior.exit
                local stash = interior.stash
                if door then
                    local d = #(coords - vector3(door.x, door.y, door.z))
                    if d < 15.0 then
                        DrawMarker(20, door.x, door.y, door.z + 0.1, 0, 0, 0, 0, 0, 0, 0.25, 0.25, 0.25, 0, 229, 255, 160, false, true, 2, false, nil, nil, false)
                        if d < 1.5 then
                            BeginTextCommandDisplayHelp('STRING')
                            AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ Leave house')
                            EndTextCommandDisplayHelp(0, false, true, -1)
                            if IsControlJustReleased(0, Config.InteractKey) then
                                TriggerServerEvent('bsrp-housing:server:leave')
                            end
                        end
                    end
                end
                if stash then
                    local d = #(coords - stash)
                    if d < 12.0 then
                        DrawMarker(20, stash.x, stash.y, stash.z, 0, 0, 0, 0, 0, 0, 0.25, 0.25, 0.25, 124, 92, 255, 160, false, true, 2, false, nil, nil, false)
                        if d < 1.5 then
                            BeginTextCommandDisplayHelp('STRING')
                            AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ Open stash')
                            EndTextCommandDisplayHelp(0, false, true, -1)
                            if IsControlJustReleased(0, Config.InteractKey) then
                                TriggerServerEvent('bsrp-housing:server:openStash', insideHouse.house)
                            end
                        end
                    end
                end
            else
                for _, h in ipairs(Houses) do
                    if h.enter then
                        local pos = vector3(h.enter.x, h.enter.y, h.enter.z)
                        local dist = #(coords - pos)
                        if dist < Config.MarkerDistance then
                            sleep = 0
                            if Config.DrawMarker then
                                local m = Config.Marker
                                DrawMarker(
                                    m.type, pos.x, pos.y, pos.z + 0.15,
                                    0, 0, 0, 0, 0, 0,
                                    m.scale.x, m.scale.y, m.scale.z,
                                    m.color.r, m.color.g, m.color.b, m.color.a,
                                    false, true, 2, false, nil, nil, false
                                )
                            end
                            if dist < Config.InteractDistance then
                                nearHouse = h
                                BeginTextCommandDisplayHelp('STRING')
                                AddTextComponentSubstringPlayerName(('~INPUT_CONTEXT~ %s'):format(h.label or 'House'))
                                EndTextCommandDisplayHelp(0, false, true, -1)
                                if IsControlJustReleased(0, Config.InteractKey) then
                                    openMenu(h)
                                end
                            end
                        end
                    end
                end
            end
        else
            sleep = 200
        end
        Wait(sleep)
    end
end)

-- Request house list after framework load
RegisterNetEvent('bsrp:client:onPlayerLoaded', function()
    Wait(1000)
    TriggerServerEvent('bsrp-housing:server:requestSync')
end)

CreateThread(function()
    Wait(2500)
    TriggerServerEvent('bsrp-housing:server:requestSync')
end)

RegisterCommand('houses', function()
    TriggerServerEvent('bsrp-housing:server:requestSync')
    notify(('Loaded %s house locations'):format(#Houses), 'info')
end, false)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        clearBlips()
        closeMenu()
    end
end)
