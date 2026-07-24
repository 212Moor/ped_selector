local isOpen = false
local pedList = {}
local previewPed = nil
local previewRotation = 0.0
local currentPreviewModel = nil

-- Charger les peds (compatible avec DurtyFree)
CreateThread(function()
    local jsonData = LoadResourceFile(GetCurrentResourceName(), "peds.json")
    if not jsonData then print("[ped_selector] ⚠️ ERREUR : peds.json manquant") return end

    local success, parsed = pcall(json.decode, jsonData)
    if not success or not parsed then
        print("[ped_selector] ⚠️ ERREUR : peds.json invalide")
        return
    end

    if type(parsed[1]) == "table" and parsed[1].Name then
        for _, ped in ipairs(parsed) do
            if ped.Name and ped.Name ~= "" then
                pedList[#pedList + 1] = ped.Name
            end
        end
    else
        pedList = parsed
    end

    print(("[ped_selector] ✅ %s modèles chargés"):format(#pedList))
end)

-- Ouvrir / fermer
RegisterCommand('togglePedMenu', function()
    if isOpen then
        closeMenu()
    else
        openMenu()
    end
end, false)
RegisterKeyMapping('togglePedMenu', 'Ouvrir le menu de peds', 'keyboard', Config.OpenKey)

function openMenu()
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })

    CreateThread(function()
        local total, sent, batch = #pedList, 0, 300
        while sent < total do
            local chunk = {}
            for i = sent + 1, math.min(sent + batch, total) do
                chunk[#chunk + 1] = pedList[i]
            end
            SendNUIMessage({ action = 'addPeds', peds = chunk })
            sent = sent + #chunk
            Wait(100)
        end
    end)
end

function closeMenu()
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    deletePreviewPed()
end

-- Création du ped de preview devant le joueur
function spawnPreviewPed(modelName)
    local model = GetHashKey(modelName)
    if model == currentPreviewModel then return end
    currentPreviewModel = model

    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    deletePreviewPed()
    previewPed = CreatePed(4, model, 0.0, 0.0, 0.0, 0.0, false, true)
    SetEntityInvincible(previewPed, true)
    FreezeEntityPosition(previewPed, true)
    SetBlockingOfNonTemporaryEvents(previewPed, true)
    SetEntityAlpha(previewPed, 255, false)
    SetModelAsNoLongerNeeded(model)

    -- Thread de rotation
    CreateThread(function()
        while DoesEntityExist(previewPed) do
            Wait(0)
            previewRotation = (previewRotation + Config.RotationSpeed) % 360
            SetEntityHeading(previewPed, previewRotation)
        end
    end)

    -- 🔄 Thread de repositionnement : suit ton regard
    CreateThread(function()
        while DoesEntityExist(previewPed) and isOpen do
            Wait(0)
            local camCoords = GetFinalRenderedCamCoord()
            local forward = GetFinalRenderedCamRot(2)
            forward = vector3(
                -math.sin(math.rad(forward.z)) * math.cos(math.rad(forward.x)),
                 math.cos(math.rad(forward.z)) * math.cos(math.rad(forward.x)),
                 math.sin(math.rad(forward.x))
            )

            local targetPos = camCoords + forward * Config.PreviewDistance
            SetEntityCoordsNoOffset(previewPed, targetPos.x, targetPos.y, targetPos.z - 0.5, false, false, false)
        end
    end)
end


function deletePreviewPed()
    if DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
        previewPed = nil
    end
    currentPreviewModel = nil
end

-- Appliquer le ped au joueur
function applyPedToPlayer(modelName)
    local model = GetHashKey(modelName)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)

    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    NetworkResurrectLocalPlayer(coords, GetEntityHeading(playerPed), true, true, false)
    SetPlayerInvincible(PlayerId(), false)
    ClearPedTasksImmediately(playerPed)

    deletePreviewPed()
    print("[ped_selector] ✅ Ped appliqué :", modelName)
end

-- NUI Callbacks
RegisterNUICallback('previewPed', function(data, cb)
    spawnPreviewPed(data.ped)
    cb('ok')
end)

RegisterNUICallback('selectPed', function(data, cb)
    applyPedToPlayer(data.ped)
    cb('ok')
end)

RegisterNUICallback('closeMenu', function(_, cb)
    closeMenu()
    cb('ok')
end)

-- Nettoyage auto
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then deletePreviewPed() end
end)
