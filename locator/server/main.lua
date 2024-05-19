local robberies = {}
local npcHandle, npcNetId = nil, nil
local robBlips = {}
local countCops = 0
local webhook = 'https://discord.com/api/webhooks/1137888949390544986/KHDr-u77jjTruyPSMoyQWBz0cdikSUOpjgWI2GQzp71VA-bZGNeC1L9ceQR-In3G3C8Q'
CreateThread(function()
    Citizen.SetTimeout(1000, function()
        debugprint("[LOCATOR] Setting locator as available")
        if not npcHandle then
            createNpc()
        end
        while true do
            local changed = false
            Wait(120000)
            local policeCount = countCops
            for houseId, data in pairs(robberies) do
                if data.Source then
                    if data.Entity and data.NetId then
                        if not DoesEntityExist(data.Entity) then
                            debugprint(addVeh(robberies[houseId].NetId, {}, true))
                            TriggerClientEvent("8bit_locator:vehicleIsGone", data.Source)
                            robberies[houseId] = nil
                            changed = true
                        end
                    end
                    if not data.Entity and not data.NetId and policeCount < ServerConfig.PoliceCount then
                        TriggerClientEvent("ox_lib:notify", data.Source, {
                            type = "success",
                            title = "Lokátor",
                            description = "Zkuste to příště, vozidlo se tam už nenachází...",
                            icon = "fas fa-hand-rock",
                            duration = 4500
                        })
                        robberies[houseId] = nil
                        changed = true
                    end
                end
            end
            if changed then
                TriggerClientEvent("8bit_locator:sendRobberies", -1, robberies)
            end
        end
    end)
end)

RegisterNetEvent("8bit_locator:askForJob")
AddEventHandler("8bit_locator:askForJob", function()
    local client = source
    local policeCount = countCops
    if not isSourceRobberiesSource(client) then
        if #robberies < 1 and policeCount >= ServerConfig.PoliceCount then
            local house = 0
            local try = 10
            while true do
                house = math.random(1, #ServerConfig.Houses)
                if not ServerConfig.Houses[house].Taken then
                    break
                end
                try = try - 1
                if try <= 0 then
                    break
                end
                Wait(1)
            end

            if house > 0 then
                TriggerClientEvent("ox_lib:notify", client, {
                    type = "success",
                    title = "Chlapík",
                    description = "Nevím o co ti jde, ale doufám že hledáš tohle...",
                    icon = "fas fa-hand-rock",
                    duration = 4500
                })

                TriggerClientEvent('chat:addMessage', client, {
                    template = '<div style="width:100%; font-weight:600; color:#FFDA5B;">{0}: {1}</div>',
                    args = { "Inzerát na prodej domu...", ServerConfig.Houses[house].Message }
                })
                exports['8bit_core']:sendToDiscord({
                    webhook = webhook,
                    name = 'Locator',
                    title = 'Hráč začal lokátor',
                    desc = '',
                    color = '0'
                }, client)
                ServerConfig.Houses[house].Taken = true
                robberies[tostring(house)] = {
                    Entity = nil,
                    NetId = nil,
                    Source = client
                }
                Citizen.SetTimeout(3600000, function()
                    if robberies[tostring(house)] and robberies[tostring(house)].Source == client then
                        if DoesEntityExist(robberies[tostring(house)].Entity) then
                            despawnVehicle(tostring(house))
                        end
                        robberies[tostring(house)] = nil
                    end
                    Wait(500)
                    ServerConfig.Houses[house].Taken = false
                end)
                TriggerClientEvent("8bit_locator:sendRobberies", -1, robberies)
                TriggerClientEvent("8bit_locator:openHouse", client, house, ServerConfig.Houses[house])
            else
                TriggerClientEvent("ox_lib:notify", client, {
                    type = "error",
                    title = "Chlapík",
                    description = "S kokotama se nebavím, vysmahni",
                    icon = "fas fa-hand-rock",
                    duration = 3000
                })
            end
        else
            TriggerClientEvent("ox_lib:notify", client, {
                type = "error",
                title = "Chlapík",
                description = "Už jsem toho rozdal až moc...",
                icon = "fas fa-hand-rock",
                duration = 3000
            })
        end
    else
        TriggerClientEvent("ox_lib:notify", client, {
            type = "error",
            title = "Chlapík",
            description = "Tobě už jsem něco dal, táhni odsud.",
            icon = "fas fa-hand-rock",
            duration = 3000
        })
    end
end)

RegisterNetEvent('8bit_locator:sendCops', function(cops)
    countCops = cops
end)

RegisterNetEvent("8bit_locator:enterHouse")
AddEventHandler("8bit_locator:enterHouse", function(house)
    local client = source

    local removeResult = exports.ox_inventory:RemoveItem(client, 'lockpick', 1)
    if removeResult then
        TriggerClientEvent("8bit_locator:enterHouse", client, house)
    else
        TriggerClientEvent("ox_lib:notify", client, {
            type = "error",
            title = "Dveře",
            description = "Něco Vám chybí!",
            icon = "fas fa-hand-rock",
            duration = 3000
        })
    end
end)

RegisterNetEvent("8bit_locator:getData")
AddEventHandler("8bit_locator:getData", function()
    local client = source
    TriggerClientEvent("8bit_locator:sendRobberies", client, robberies, npcNetId)
end)

function createVehicle(vehData, spawn, client, locked, instance)
    if type(vehData) == "string" then
        vehData = getVehicle(vehData)
    end

    if not vehData or not vehData.data or not vehData.data.model then
        return 0, "vehNotExist"
    end

    if not spawn then
        return 0, "noSpawnCoords"
    end

    local vehicle = Citizen.InvokeNative(
        GetHashKey("CREATE_AUTOMOBILE"),
        GetHashKey(vehData.data.model),
        spawn.x,
        spawn.y,
        spawn.z,
        spawn.h or spawn.w
    )

    while not DoesEntityExist(vehicle) do
        Wait(0)
    end

    if instance then
        if type(instance) == "number" then
            SetEntityRoutingBucket(vehicle, instance)
        else
            SetEntityRoutingBucket(vehicle, exports.instance:createInstanceIfNotExists(instance))
        end
    end

    local state = Entity(vehicle).state

    state.fuel = math.random(80, 100)

    while not NetworkGetEntityOwner(vehicle) or NetworkGetEntityOwner(vehicle) <= 0 do
        Wait(10)
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if NetworkGetNetworkIdFromEntity(vehicle) ~= netId then
        netId = NetworkGetNetworkIdFromEntity(vehicle)
    end

    if GetEntityModel(vehicle) ~= GetHashKey(vehData.data.model) then
        print("Vozidlo se spawnulo s jiným modelem!..", vehicle, json.encode(vehData))
        return
    end

    if not vehData.data.plate then
        vehData.data.plate = vehData.data.actualPlate
    end

    local shouldBeLocked = true
    if locked then
        shouldBeLocked = locked
    end

    if shouldBeLocked then
        SetVehicleDoorsLocked(vehicle, 2)
    else
        SetVehicleDoorsLocked(vehicle, 1)
    end

    return vehicle, netId
end

RegisterNetEvent("8bit_locator:spawnVehicle")
AddEventHandler("8bit_locator:spawnVehicle", function(houseId)
    local client = source
    local houseId = tostring(houseId)
    if robberies[houseId] and robberies[houseId].Source == client and not robberies[houseId].Entity then
        local plate, instance = generateVehPlate(), "8bit_locator_" .. houseId
        local selectedVeh = ServerConfig.Vehicles[math.random(1, #ServerConfig.Vehicles)]
        local garageType = ServerConfig.Houses[tonumber(houseId)].Type
        local coords = Config.Garages[garageType].Vehicle

        exports['8bit_core']:sendToDiscord({
            webhook = webhook,
            name = 'Locator',
            title = 'Hráč našel klíče a vyjel s autem ven',
            desc = '`Vozidlo:` **' .. selectedVeh .. '**',
            color = '0'
        }, client)
        local veh, netId = createVehicle({
            spz = plate,
            data = {
                actualPlate = plate,
                model = selectedVeh,
                fuelLevel = 100.0
            }
        }, coords, client, true, exports.instance:createInstanceIfNotExists(instance))

        robberies[houseId].Entity = veh
        robberies[houseId].NetId = netId
        TriggerClientEvent("8bit_locator:sendRobberies", -1, robberies)
    end
end)

RegisterNetEvent("8bit_locator:foundKeys")
AddEventHandler("8bit_locator:foundKeys", function(houseId)
    local client = source
    local houseId = tostring(houseId)
    if robberies[houseId] and robberies[houseId].Source == client and robberies[houseId].Entity and
        robberies[houseId].NetId then
        TriggerClientEvent("ox_lib:notify", client, {
            type = "success",
            title = "Úspěch",
            description = "Tady jsou klíče!",
            icon = "fas fa-car",
            duration = 3000
        })
    end
end)

function getVehicleActualPlateNumber(vehicle)
    if DoesEntityExist(vehicle) then
        local veh = Entity(vehicle)
        if veh.state.actualPlate then
            return veh.state.actualPlate
        end

        return GetVehicleNumberPlateText(vehicle)
    end

    return nil
end

function addVeh(entityNetId, blipData, remove)
    if not remove then
        if robBlips[entityNetId] then
            return "exists"
        end

        if not blipData then
            return "missingBlipData"
        end

        if not blipData.coords
            or not blipData.radius
            or not blipData.alpha
            or not blipData.display
            or not blipData.colour
            or not blipData.isShortRange
            or not blipData.houseId then
            return "missingSpecificBlipData"
        end

        robBlips[entityNetId] = {
            blipData = blipData,
            entityNetId = entityNetId,
            entity = NetworkGetEntityFromNetworkId(entityNetId),
            remove = remove or false
        }

        local plate = getVehicleActualPlateNumber(robberies[blipData.houseId].Entity)

        TriggerClientEvent('cd_dispatch:AddNotification', -1, {
            job_table = Config.PoliceJobs,
            coords = ServerConfig.Houses[tonumber(blipData.houseId)].Exit.xyz,
            title = '10-16',
            message = "Krádež vozidla s lokátorem - "..plate,
            flash = 0,
            unique_id = tostring(math.random(0000000,9999999)),
            blip = {
                sprite = 651,
                scale = 1.5,
                color = 84,
                flashes = false,
                text = "Krádež vozidla s lokátorem",
                time = 5,
                sound = 1,
                radius = 100,
            }
        })
    
        CreateThread(function()
            debugprint(entityNetId)
            while true do
                local entitynetid = entityNetId
                local entity = NetworkGetEntityFromNetworkId(entitynetid)
                if DoesEntityExist(entity) and robBlips[entitynetid] then
    
                    robBlips[entitynetid].coords = GetEntityCoords(entity)
    
                    for i = 1, #Config.PoliceJobs do
                        local xPlayers = ESX.GetExtendedPlayers('job', Config.PoliceJobs[i])
                
                        for _, xPlayer in pairs(xPlayers) do
                            debugprint("Posielam blips pre:", xPlayer.source, xPlayer.job.name)
                            TriggerClientEvent("8bit_locator:refreshblips", xPlayer.source, robBlips[entitynetid])
                        end
                    end
                end
                if not robBlips[entitynetid] then
                    break
                end
                Wait(3000)
            end
        end)
    else
        robBlips[entityNetId].remove = remove
        debugprint(entityNetId, robBlips[entityNetId].remove)
        for i = 1, #Config.PoliceJobs do
            local xPlayers = ESX.GetExtendedPlayers('job', Config.PoliceJobs[i])
    
            for _, xPlayer in pairs(xPlayers) do
                TriggerClientEvent("8bit_locator:refreshblips", xPlayer.source, robBlips[entityNetId])
            end
        end
        robBlips[entityNetId] = nil
    end

    return "done"
end

RegisterNetEvent("8bit_locator:announceLocator")
AddEventHandler("8bit_locator:announceLocator", function(houseId)
    local client = source
    local houseId = tostring(houseId)
    if robberies[houseId] and robberies[houseId].Source == client and robberies[houseId].Entity then
        SetEntityRoutingBucket(robberies[houseId].Entity, 0)
        exports.instance:playerQuitInstance(client)

        debugprint(addVeh(robberies[houseId].NetId, {
            coords = GetEntityCoords(robberies[houseId].Entity),
            radius = 75.0,
            display = 4,
            colour = 76,
            alpha = 128,
            isShortRange = true,
            houseId = houseId
        }, false))
    end
end)

RegisterNetEvent("8bit_locator:shareLocator")
AddEventHandler("8bit_locator:shareLocator", function(target, houseId)
    local client = source
    local houseId = tostring(houseId)
    if robberies[houseId] and robberies[houseId].Source == client then
        TriggerClientEvent("8bit_locator:shareLocator", target, houseId)
    end
end)

RegisterNetEvent("8bit_locator:removeLocator")
AddEventHandler("8bit_locator:removeLocator", function(houseId, status)
    local client = source
    local houseId = tostring(houseId)
    if robberies[houseId] and robberies[houseId].Source == client then
        Wait(1000)
        if status == "success" then
            debugprint(addVeh(robberies[houseId].NetId, {}, true))
            local sellPoint = ServerConfig.SellPoints[math.random(1, #(ServerConfig.SellPoints))]
            TriggerClientEvent("8bit_locator:sellPoint", client, sellPoint)
        end
    end
end)

function getFormattedCurrency(value)
    local left, num, right = string.match(value, '^([^%d]*%d)(%d*)(.-)$')
    return "$" .. left .. (num:reverse():gsub('(%d%d%d)', '%1' .. ","):reverse()) .. right
end

RegisterNetEvent("8bit_locator:finishTheft")
AddEventHandler("8bit_locator:finishTheft", function(houseId)
    local reward = math.random(25000, 35000)
    local client = source
    local houseId = tostring(houseId)

    if robberies[houseId] and robberies[houseId].Source == client then
        exports.ox_inventory:AddItem(client, "money", reward)
        if DoesEntityExist(robberies[houseId].Entity) then
            despawnVehicle(houseId)
        end
        Wait(500)
        robberies[houseId] = nil
        exports['8bit_core']:sendToDiscord({
            webhook = webhook,
            name = 'Locator',
            title = 'Hráč dokončil lokátor',
            desc = '`Odměna:` **' .. getFormattedCurrency(reward) .. '**',
            color = '0'
        }, client)
        TriggerClientEvent("ox_lib:notify", client, {
            type = "success",
            title = "Úspěch",
            description = "Díky za fušku, tady máš svojí odměnu! - " .. getFormattedCurrency(reward),
            icon = "fas fa-car",
            duration = 4500
        })
    end
end)

function isSourceRobberiesSource(source)
    for house, data in pairs(robberies) do
        if data.Source == source then
            return tostring(house)
        end
    end
    return false
end

AddEventHandler("playerDropped", function(reason)
    local client = source
    local hasJob = isSourceRobberiesSource(client)
    if hasJob then
        if DoesEntityExist(robberies[hasJob].Entity) then
            despawnVehicle(hasJob)
        end
        Wait(500)
        robberies[hasJob] = nil
    end
end)

function despawnVehicle(houseId)
    DeleteEntity(robberies[houseId].Entity)
end

function generateVehPlate()
    local plate = ""
    for i = 1, 8 do
        plate = plate .. Config.PlateChars[math.random(#Config.PlateChars)]
    end

    return plate
end

AddEventHandler("onResourceStop", function(resource)
    if (GetCurrentResourceName() == resource) then
        for houseId, _ in pairs(robberies) do
            if DoesEntityExist(robberies[houseId].Entity) then
                despawnVehicle(houseId)
            end
            robberies[houseId] = nil
        end
        if npcHandle then
            if DoesEntityExist(npcHandle) then
                DeleteEntity(npcHandle)
            end

            npcHandle = nil
        end
    else
        return
    end
end)

function createNpc()
    local pedModel = GetHashKey("ig_joeminuteman")
    npcHandle = Citizen.InvokeNative(GetHashKey("CREATE_PED"), 0, pedModel, ServerConfig.NpcPosition.xyz,
        ServerConfig.NpcPosition.w)

    while not DoesEntityExist(npcHandle) do
        Wait(0)
    end

    SetEntityHeading(npcHandle, ServerConfig.NpcPosition.w)
    FreezeEntityPosition(npcHandle, true)
    SetPedResetFlag(npcHandle, 249, 1)
    SetPedConfigFlag(npcHandle, 185, true)
    SetPedConfigFlag(npcHandle, 108, true)
    SetPedConfigFlag(npcHandle, 208, true)
    CreateThread(function()
        while DoesEntityExist(npcHandle) do
            Wait(30000)
                
            SetEntityCoords(npcHandle, ServerConfig.NpcPosition.xyz)
            SetEntityHeading(npcHandle, ServerConfig.NpcPosition.w)
        end
        createNpc()
    end)

    npcNetId = NetworkGetNetworkIdFromEntity(npcHandle)
    while npcNetId <= 0 do
        npcNetId = NetworkGetNetworkIdFromEntity(npcHandle)
        Wait(100)
    end
    
    TriggerClientEvent("8bit_locator:sendRobberies", -1, robberies, npcNetId)
end
