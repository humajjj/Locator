local robberies = {}
local sellBlip, globalHouseId, globalHouseData = false, nil, nil
local isRemoving = false
local locatorblip = nil

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    ESX.PlayerData = xPlayer
    ESX.PlayerLoaded = true

    TriggerServerEvent("8bit_locator:getData")
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    ESX.PlayerLoaded = false
    ESX.PlayerData = {}

    if globalHouseId then
        endRemovingLocator("fail", globalHouseId)
    end
    if DoesBlipExist(sellBlip) then
        RemoveBlip(sellBlip)
        sellBlip = nil
    end
    if DoesBlipExist(locatorblip) then
        RemoveBlip(locatorblip)
        locatorblip = nil
    end
end)

RegisterNetEvent('esx:setJob', function(job, lastJob)
    ESX.PlayerData.job = job
end)

CreateThread(function()
    while true do
        TriggerServerEvent('8bit_locator:sendCops', exports.viper_scoreboard:getcopnumber())
        Wait(30000)
    end
end)

function hasWhitelistedJob()
    if Config.WhitelistedJobs[ESX.PlayerData.job.name] then
        return true
    end

    return false 
end

RegisterNetEvent("8bit_locator:sendRobberies")
AddEventHandler("8bit_locator:sendRobberies", function(newRobberies, npcNetId)
    print(json.encode(newRobberies, {indent=true}))
    robberies = newRobberies
    if npcNetId then
        setPedFlags(npcNetId)
    end
end)

RegisterNetEvent("8bit_locator:vehicleIsGone")
AddEventHandler("8bit_locator:vehicleIsGone", function()
    isRemoving, globalHouseId, globalHouseData = false, nil, nil
    exports.ox_lib:notify({
        type = "warning",
        title = "Smůla",
        description = "Vozidlo s lokátorem Vám zmizelo!",
        icon = "fas fa-times",
        duration = 3000
    })
end)

RegisterNetEvent("8bit_locator:openHouse")
AddEventHandler("8bit_locator:openHouse", function(houseId, houseData)
    globalHouseId, globalHouseData = tostring(houseId), houseData
    exports.qtarget:AddCircleZone("locator-house-" .. houseId, houseData.Enter.xyz, 1.0, {
        useZ = true,
        name = "locator-house-" .. houseId
    }, {
        options = {
            {
                action = function()
                    TriggerServerEvent("8bit_locator:enterHouse", houseId)
                end,
                icon = "fas fa-comments",
                label = "Vstúpiť do nemovitosti"
            },
        },
        distance = 1.5
    })
    local garageType = houseData.Type
    exports.qtarget:AddCircleZone("locator-house-exit-" .. houseId, Config.Garages[garageType].Doors.xyz, 1.0, {
        useZ = true,
        name = "locator-house-exit-" .. houseId
    }, {
        options = {
            {
                action = function()
                    leaveHouse(houseData)
                end,
                icon = "fas fa-comments",
                label = "Opustit nemovitost",
                canInteract = function(entity)
                    return not hasWhitelistedJob()
                end
            }
        },
        distance = 1.5
    })
end)

function leaveHouse(houseData)
    TriggerServerEvent("instance:quitInstance")
    Wait(1000)
    SetEntityCoords(cache.ped, houseData.Enter)
end

function createGaragePolyZones(houseId, garageType)
    local keyPlace = math.random(1, #(Config.Garages[garageType].Places))
    exports.qtarget:RemoveZone("locator-house-" .. houseId)
    for i, coords in each(Config.Garages[garageType].Places) do
        exports.qtarget:AddCircleZone("locator-house-places-" .. i, coords, 1.0, {
            useZ = true,
            name = "locator-house-places-" .. houseId,
        }, {
            options = {
                {
                    action = function()
                        searchPlace({Key = keyPlace, Current = i, House = houseId, Garage = garageType})
                    end,
                    icon = "fas fa-search",
                    label = "Prohledat",
                    canInteract = function(entity)
                        return not hasWhitelistedJob()
                    end
                }
            },
            distance = 1.5
        })
    end
end

function searchPlace(data)
    if lib.progressBar({
        duration = 5000,
        label = 'Prohledáváte..',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        },
        anim = {
            dict = 'missexile3',
            clip = 'ex03_dingy_search_case_a_michael' 
        },
    }) 
    then 
        if data.Key == data.Current then
            TriggerServerEvent("8bit_locator:foundKeys", data.House)
            startExitThread(data.House)
            removePlacesZones(data.Garage)
        else
            exports.qtarget:RemoveZone("locator-house-places-" .. data.Current)
            exports.ox_lib:notify({
                type = "error",
                title = "Smůla",
                description = "Zkus to jinde, tady si klíčky nenašel!",
                icon = "fas fa-times",
                duration = 3000
            })
        end
    end
end

function startExitThread(houseId)
    local stringHouseId = tostring(houseId)
    CreateThread(function()
        print(json.encode(robberies[stringHouseId].NetId, {indent=true}))
        local vehicle = NetToVeh(robberies[stringHouseId].NetId)
        while true do
            Wait(0)
            if IsPedInVehicle(PlayerPedId(), vehicle) and GetEntitySpeed(vehicle) > 2.0 then
                fadeEffect()
                SetPedCoordsKeepVehicle(PlayerPedId(), globalHouseData.Exit.xyz)
                SetEntityHeading(vehicle, globalHouseData.Exit.w)
                TriggerServerEvent("8bit_locator:announceLocator", houseId)
                break
            end
        end
        startTimer(robberies[stringHouseId].NetId, houseId)
    end)
end

function removePlacesZones(garageType)
    for i, _ in each(Config.Garages[garageType].Places) do
        exports.qtarget:RemoveZone("locator-house-places-" .. i)
    end
end

RegisterNetEvent("8bit_locator:enterHouse")
AddEventHandler("8bit_locator:enterHouse", function(houseId)
    local playerPed = PlayerPedId()
    TriggerServerEvent("InteractSound_SV:PlayOnSource", "lockpick", 3.0)
    if lib.progressBar({
        duration = 10000,
        label = 'Snažíte se vypáčit zámek..',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        },
        anim = {
            dict = 'missheistfbisetup1',
            clip = 'hassle_intro_loop_f' 
        },
    }) 
    then 
        DoScreenFadeOut(2000)
        while not IsScreenFadedOut() do
            Wait(10)
        end
        TriggerServerEvent("instance:joinInstance", "8bit_locator_" .. houseId)
        Wait(1000)
        local garageType = globalHouseData.Type
        SetEntityCoords(playerPed, Config.Garages[garageType].Doors.xyz)
        SetEntityHeading(playerPed, Config.Garages[garageType].Doors.w)
        Wait(200)
        
        TriggerServerEvent("8bit_locator:spawnVehicle", houseId)
        Wait(200)
        while not robberies[tostring(houseId)] and not NetworkDoesEntityExistWithNetworkId(robberies[tostring(houseId)].NetId) do
            Wait(100)
        end
        DoScreenFadeIn(2000)
        while not IsScreenFadedIn() do
            Wait(2000)
            DoScreenFadeIn(2000)
        end
        createGaragePolyZones(houseId, garageType)    
    end
end)

local font = RegisterFontId("Fire Sans")
function drawTxt(text)
    SetTextFont(font)
    SetTextScale(0.5, 0.5)
    SetTextColour(255, 255, 255, 255)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    EndTextCommandDisplayText(0.8, 0.5)
end

function fadeEffect()
    DoScreenFadeOut(1000)
    Wait(3000)
    DoScreenFadeIn(1000)
end

function tableLength(table)
    local count = 0
    for _ in pairs(table) do
        count = count + 1
    end
    return count
end

function startTimer(netId, houseId)
    CreateThread(function()
        local timer = 0
        isRemoving, hasPassenger = true, false
        local veh = NetworkGetEntityFromNetworkId(netId)
        while isRemoving do
            Wait(1)
            local text = "Lokátor"
            local passenger = GetPedInVehicleSeat(veh, 0)
            local secondSeat = DoesEntityExist(passenger)
            if GetEntitySpeed(veh) == 0.0 and IsPedInVehicle(PlayerPedId(), veh) or secondSeat then
                if not hasPassenger and secondSeat then
                    hasPassenger = GetPlayerServerId(NetworkGetEntityOwner(passenger))
                    TriggerServerEvent("8bit_locator:shareLocator", hasPassenger, houseId)
                elseif hasPassenger and not secondSeat then
                    hasPassenger = false
                end

                timer += 20
                text = "Odstraňujete lokátor"
                Entity(veh).state:set("locator", timer, true)
                if makeNewTime(timer) >= 100 then
                    isRemoving = false
                    endRemovingLocator("success", houseId)
                end
            end
            drawTxt(text .. "~r~ " .. makeNewTime(timer) .. "~s~%")
        end
    end)
end

function makeNewTime(oldTime)
    return math.floor((oldTime / 1000) / 360 * 100) -- 360
end

function endRemovingLocator(status, houseId)
    if status == "success" then
        exports.ox_lib:notify({
            type = "success",
            title = "Lokátor",
            description = "Odstranil/a jste úspěšně lokátor",
            icon = "fas fa-car",
            duration = 3000
        })
    else
        exports.ox_lib:notify({
            type = "error",
            title = "Smůla",
            description = "Auto s lokátorem zmizelo!",
            icon = "fas fa-car",
            duration = 3000
        })
        globalHouseId, globalHouseData = nil, nil
    end
    TriggerServerEvent("8bit_locator:removeLocator", houseId, status)
end

RegisterNetEvent("8bit_locator:shareLocator")
AddEventHandler("8bit_locator:shareLocator", function(houseId)
    if robberies[houseId] and robberies[houseId].NetId then
        CreateThread(function()
            local netId = robberies[houseId].NetId
            local veh = NetworkGetEntityFromNetworkId(netId)
            while GetPedInVehicleSeat(veh, 0) == PlayerPedId() and makeNewTime(Entity(veh).state.locator) < 100.0 do
                Wait(1)
                while not Entity(veh).state.locator do
                    Wait(10)
                end
                drawTxt("Odstraňujete lokátor~r~ " .. makeNewTime(Entity(veh).state.locator) .. "~s~%")
            end
        end)
    end
end)

RegisterNetEvent("8bit_locator:sellPoint")
AddEventHandler("8bit_locator:sellPoint", function(sellPoint)
    local veh = NetToVeh(robberies[tostring(globalHouseId)].NetId)
    local alreadyEnteredZone = false

    createSellBlip(sellPoint)
    while true do
        local toWait = 2000
        local inZone = false
        if #(GetEntityCoords(PlayerPedId()) - sellPoint) <= 5.0 then
            toWait = 0
            inZone  = true

            if IsControlJustReleased(0, 54) then
                if IsPedInVehicle(PlayerPedId(), veh) then
                    fadeEffect()
                    TriggerServerEvent("8bit_locator:finishTheft", tostring(globalHouseId))
                    endSellingLocator()
                    break
                else
                    exports.ox_lib:notify({
                        type = "error",
                        title = "Chyba",
                        description = "Kde máš auto?",
                        icon = "fas fa-times",
                        duration = 3000
                    })
                end
            end
        end

        if inZone and not alreadyEnteredZone then
            alreadyEnteredZone = true
            lib.showTextUI('[E] - Odevzdat')
        end

        if not inZone and alreadyEnteredZone then
            alreadyEnteredZone = false
            lib.hideTextUI()
        end
        Wait(toWait)
    end
end)

function createNewBlip(blipData)
    local blip = AddBlipForCoord(blipData.coords.x, blipData.coords.y, blipData.coords.z)

    SetBlipSprite(blip, blipData.sprite)
    SetBlipScale(blip, blipData.scale)
    SetBlipColour(blip, blipData.colour)
    SetBlipDisplay(blip, blipData.display)
    SetBlipAsShortRange(blip, blipData.isShortRange)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("<FONT FACE='Fire Sans'>" .. blipData.text .. "</FONT>")
    EndTextCommandSetBlipName(blip)

    return blip
end

function createSellBlip(sellPoint)
    sellBlip = createNewBlip({
        coords = sellPoint,
        sprite = 524,
        display = 4,
        scale = 0.4,
        colour = 69,
        isShortRange = true,
        text = "Místo odevzdání ukradeného vozidla"
    })
    SetBlipRoute(sellBlip, true)
end

function endSellingLocator()
    lib.hideTextUI()
    RemoveBlip(sellBlip)
    sellBlip, globalHouseId = false, nil
end

RegisterNetEvent("8bit_locator:deleteVehicle")
AddEventHandler("8bit_locator:deleteVehicle", function(netId)
    if NetworkDoesEntityExistWithNetworkId(netId) then
        local vehicle = NetworkGetEntityFromNetworkId(netId)
        DeleteEntity(vehicle)
    end
end)

local createdthread = false

RegisterNetEvent("8bit_locator:refreshblips")
AddEventHandler("8bit_locator:refreshblips", function(customBlips)
    debugprint("Dostavam blip")
    if not customBlips.remove then
        if customBlips.coords then
            debugprint("Nasiel som coords pre blip")
            if not locatorblip then
                locatorblip = AddBlipForRadius(customBlips.coords, customBlips.blipData.radius)

                SetBlipDisplay(locatorblip, customBlips.blipData.display)
                SetBlipColour(locatorblip, customBlips.blipData.colour)
                SetBlipAlpha(locatorblip, customBlips.blipData.alpha)
                SetBlipAsShortRange(locatorblip, customBlips.blipData.isShortRange)
                debugprint("Spravil som blip:", locatorblip, customBlips.coords)
            end

            SetBlipCoords(locatorblip, customBlips.coords)
            debugprint("Refreshujem blip:", locatorblip, customBlips.coords)
            if not createdthread then
                createdthread = true
                CreateThread(function()
                    while true do
                        if DoesBlipExist(locatorblip) and not hasWhitelistedJob() then
                            debugprint("davam preč blip")
                            RemoveBlip(locatorblip)
                            locatorblip = nil
                            createdthread = false
                            break
                        end
                        Wait(5000)
                    end
                end)
            end
        end
    else
        debugprint("davam preč blip")
        RemoveBlip(locatorblip)
        locatorblip = nil
    end
end)

function setPedFlags(npcNetId)
    while not NetworkDoesEntityExistWithNetworkId(npcNetId) do
        Wait(5000)
    end
    local npcHandle = NetToPed(npcNetId)
    SetTimeout(1000, function()
        exports.ox_target:removeLocalEntity(npcHandle, "8bit_locator-startjob")
        exports.ox_target:addLocalEntity(npcHandle, {
            {
                name = "8bit_locator-startjob",
                onSelect = function()
                    TriggerServerEvent("8bit_locator:askForJob")
                end,
                icon = "fas fa-comments",
                label = "Zeptat se na zakázku",
                canInteract = function()
                    return not hasWhitelistedJob()
                end,
                distance = 1.5
            }
        })
        FreezeEntityPosition(npcHandle, true)
        SetPedResetFlag(npcHandle, 249, 1)
        SetPedConfigFlag(npcHandle, 185, true)
        SetPedConfigFlag(npcHandle, 108, true)
        SetPedConfigFlag(npcHandle, 208, true)
        SetEntityCanBeDamaged(npcHandle, false)
        SetPedCanBeTargetted(npcHandle, false)
        SetPedCanBeDraggedOut(npcHandle, false)
        SetPedCanBeTargettedByPlayer(npcHandle, PlayerId(), false)
        SetBlockingOfNonTemporaryEvents(npcHandle, true)
        SetPedCanRagdollFromPlayerImpact(npcHandle, false)
        SetEntityAsMissionEntity(npcHandle, true, true)
        SetPedHearingRange(npcHandle, 0.0)
        SetPedSeeingRange(npcHandle, 0.0)
        SetPedAlertness(npcHandle, 0.0)
        SetPedFleeAttributes(npcHandle, 0, 0)
        SetPedCombatAttributes(npcHandle, 46, true)
        SetPedFleeAttributes(npcHandle, 0, 0)
        SetEntityInvincible(npcHandle, true)
    end)
end
