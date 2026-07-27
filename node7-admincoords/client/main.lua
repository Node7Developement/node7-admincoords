local RESOURCE = GetCurrentResourceName()

local State = {
    precision = math.max(Config.MinimumPrecision, math.min(Config.MaximumPrecision, Config.DefaultPrecision)),
    liveDisplay = Config.LiveDisplay.enabledByDefault == true,
    menu = nil,
    clipboardRequests = {},
    clipboardSequence = 0
}

local openMainMenu
local openPlayerMenu
local openCameraMenu
local openTargetMenu
local openSettingsMenu

local function notify(message, notificationType)
    if GetResourceState('node7-core') == 'started' then
        local ok = pcall(function()
            exports['node7-core']:Notify(
                message,
                notificationType or 'inform',
                Config.Notification.duration,
                Config.Notification.title
            )
        end)

        if ok then return end
    end

    TriggerEvent('chat:addMessage', {
        color = { 201, 164, 93 },
        args = { 'NODE7', message }
    })
end

local MENU_RESOURCE = 'node7-menu-base'

local function isMenuBaseReady()
    if GetResourceState(MENU_RESOURCE) ~= 'started' then
        return false
    end

    local ok, ready = pcall(function()
        return exports[MENU_RESOURCE]:IsMenuBaseReady()
    end)

    return ok and ready == true
end

local function closeCurrentMenu(silent)
    if not State.menu then return end

    local menuName = State.menu
    State.menu = nil

    if GetResourceState(MENU_RESOURCE) ~= 'started' then return end

    pcall(function()
        exports[MENU_RESOURCE]:CloseCallbackMenu(
            'default',
            RESOURCE,
            menuName,
            true,
            silent ~= true,
            false
        )
    end)
end

local function formatNumber(value, precision)
    precision = precision or State.precision
    value = tonumber(value) or 0.0
    return string.format('%.' .. precision .. 'f', value)
end

local function vector2Text(coords)
    return ('vector2(%s, %s)'):format(
        formatNumber(coords.x),
        formatNumber(coords.y)
    )
end

local function vector3Text(coords)
    return ('vector3(%s, %s, %s)'):format(
        formatNumber(coords.x),
        formatNumber(coords.y),
        formatNumber(coords.z)
    )
end

local function vector4Text(coords, heading)
    return ('vector4(%s, %s, %s, %s)'):format(
        formatNumber(coords.x),
        formatNumber(coords.y),
        formatNumber(coords.z),
        formatNumber(heading)
    )
end

local function raw3Text(coords)
    return ('%s, %s, %s'):format(
        formatNumber(coords.x),
        formatNumber(coords.y),
        formatNumber(coords.z)
    )
end

local function raw4Text(coords, heading)
    return ('%s, %s, %s, %s'):format(
        formatNumber(coords.x),
        formatNumber(coords.y),
        formatNumber(coords.z),
        formatNumber(heading)
    )
end

local function tableText(coords, heading)
    return ('{ x = %s, y = %s, z = %s, h = %s }'):format(
        formatNumber(coords.x),
        formatNumber(coords.y),
        formatNumber(coords.z),
        formatNumber(heading)
    )
end

local function jsonText(coords, heading)
    return json.encode({
        x = tonumber(formatNumber(coords.x)),
        y = tonumber(formatNumber(coords.y)),
        z = tonumber(formatNumber(coords.z)),
        h = tonumber(formatNumber(heading))
    })
end

local function copyText(label, text)
    State.clipboardSequence = State.clipboardSequence + 1
    local requestId = ('%s:%s:%s'):format(RESOURCE, GetGameTimer(), State.clipboardSequence)
    State.clipboardRequests[requestId] = { label = label, text = text, createdAt = GetGameTimer() }

    print(('^5[%s]^7 %s: %s'):format(RESOURCE, label, text))

    SendNUIMessage({
        action = 'copyText',
        requestId = requestId,
        text = text
    })
end

RegisterNUICallback('clipboardResult', function(data, cb)
    local requestId = tostring(data.requestId or '')
    local request = State.clipboardRequests[requestId]
    State.clipboardRequests[requestId] = nil

    if request then
        if data.success == true then
            notify(('Copied %s.'):format(request.label), 'success')
        else
            notify(('Clipboard failed. %s was printed to F8.'):format(request.label), 'error')
        end
    end

    cb({ ok = true })
end)

CreateThread(function()
    while true do
        Wait(5000)
        local now = GetGameTimer()
        for requestId, request in pairs(State.clipboardRequests) do
            if now - request.createdAt > 10000 then
                State.clipboardRequests[requestId] = nil
            end
        end
    end
end)

local function playerSnapshot()
    local ped = PlayerPedId()
    return {
        entity = ped,
        coords = GetEntityCoords(ped),
        heading = GetEntityHeading(ped),
        rotation = GetEntityRotation(ped, 2),
        forward = GetEntityForwardVector(ped),
        velocity = GetEntityVelocity(ped),
        model = GetEntityModel(ped),
        interior = GetInteriorFromEntity(ped)
    }
end

local function rotationToDirection(rotation)
    local x = math.rad(rotation.x)
    local z = math.rad(rotation.z)
    local cosine = math.abs(math.cos(x))

    return vector3(
        -math.sin(z) * cosine,
        math.cos(z) * cosine,
        math.sin(x)
    )
end

local function cameraSnapshot()
    local coords = GetGameplayCamCoord()
    local rotation = GetGameplayCamRot(2)
    local direction = rotationToDirection(rotation)

    return {
        coords = coords,
        rotation = rotation,
        direction = direction
    }
end

local function entityTypeLabel(entityType)
    if entityType == 1 then return 'Ped' end
    if entityType == 2 then return 'Vehicle/Wagon' end
    if entityType == 3 then return 'Object' end
    return 'Unknown'
end

local function raycastFromCamera(callback)
    CreateThread(function()
        local camera = cameraSnapshot()
        local destination = camera.coords + (camera.direction * Config.RaycastDistance)
        local handle = StartShapeTestRay(
            camera.coords.x,
            camera.coords.y,
            camera.coords.z,
            destination.x,
            destination.y,
            destination.z,
            -1,
            PlayerPedId(),
            7
        )

        local status, hit, endCoords, surfaceNormal, entity = GetShapeTestResult(handle)
        local attempts = 0

        while status == 1 and attempts < 20 do
            Wait(0)
            status, hit, endCoords, surfaceNormal, entity = GetShapeTestResult(handle)
            attempts = attempts + 1
        end

        if hit ~= 1 or not entity or entity == 0 or not DoesEntityExist(entity) then
            callback(nil, endCoords, surfaceNormal)
            return
        end

        callback({
            entity = entity,
            type = GetEntityType(entity),
            coords = GetEntityCoords(entity),
            heading = GetEntityHeading(entity),
            rotation = GetEntityRotation(entity, 2),
            velocity = GetEntityVelocity(entity),
            model = GetEntityModel(entity),
            networked = NetworkGetEntityIsNetworked(entity),
            networkId = NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity) or 0
        }, endCoords, surfaceNormal)
    end)
end

local function copyPlayerBundle(snapshot)
    copyText('complete player coordinate pack', table.concat({
        ('-- NODE7 player coordinate pack (%s decimals)'):format(State.precision),
        ('local coords2 = %s'):format(vector2Text(snapshot.coords)),
        ('local coords3 = %s'):format(vector3Text(snapshot.coords)),
        ('local coords4 = %s'):format(vector4Text(snapshot.coords, snapshot.heading)),
        ('local heading = %s'):format(formatNumber(snapshot.heading)),
        ('local rotation = %s'):format(vector3Text(snapshot.rotation)),
        ('local forward = %s'):format(vector3Text(snapshot.forward)),
        ('local velocity = %s'):format(vector3Text(snapshot.velocity)),
        ('local coordinates = %s'):format(tableText(snapshot.coords, snapshot.heading)),
        ('-- model: %s | interior: %s'):format(snapshot.model, snapshot.interior)
    }, '\n'))
end

local function openMenu(name, data, submit, cancel, change)
    if not isMenuBaseReady() then
        notify('NODE7 Menu Base is not ready.', 'error')
        return false
    end

    closeCurrentMenu(true)

    local ok, err = pcall(function()
        exports[MENU_RESOURCE]:OpenCallbackMenu(
            'default',
            RESOURCE,
            name,
            data,
            function(callbackData, menu)
                if submit then submit(callbackData, menu) end
            end,
            function(callbackData, menu)
                State.menu = nil
                menu.close(true, true, false)
                if cancel then cancel(callbackData, menu) end
            end,
            function(callbackData, menu)
                if change then change(callbackData, menu) end
            end,
            function()
                State.menu = nil
            end
        )
    end)

    if not ok then
        State.menu = nil
        print(('^1[%s]^7 OpenCallbackMenu failed: %s'):format(RESOURCE, tostring(err)))
        notify('NODE7 Menu Base could not open the admin coordinate menu.', 'error')
        return false
    end

    -- Track only the menu identifier. Do not cache or depend on a returned
    -- table containing cross-resource function references.
    State.menu = name
    return true
end

openPlayerMenu = function()
    local snapshot = playerSnapshot()
    local heading = formatNumber(snapshot.heading)

    openMenu('player_coordinates', {
        title = 'Player Coordinates',
        subtext = ('H %s | %s'):format(heading, vector3Text(snapshot.coords)),
        align = Config.Menu.align,
        enableCursor = Config.Menu.enableCursor,
        maxVisibleItems = Config.Menu.maxVisibleItems,
        hideRadar = Config.Menu.hideRadar,
        elements = {
            { label = 'Copy vector2', value = 'vector2', desc = vector2Text(snapshot.coords) },
            { label = 'Copy vector3', value = 'vector3', desc = vector3Text(snapshot.coords) },
            { label = 'Copy vector4', value = 'vector4', desc = vector4Text(snapshot.coords, snapshot.heading) },
            { label = 'Copy Heading', value = 'heading', desc = heading },
            { label = 'Copy Raw X, Y, Z', value = 'raw3', desc = raw3Text(snapshot.coords) },
            { label = 'Copy Raw X, Y, Z, H', value = 'raw4', desc = raw4Text(snapshot.coords, snapshot.heading) },
            { label = 'Copy Lua Table', value = 'table', desc = tableText(snapshot.coords, snapshot.heading) },
            { label = 'Copy JSON', value = 'json', desc = jsonText(snapshot.coords, snapshot.heading) },
            { label = 'Copy Rotation vector3', value = 'rotation', desc = vector3Text(snapshot.rotation) },
            { label = 'Copy Forward vector3', value = 'forward', desc = vector3Text(snapshot.forward) },
            { label = 'Copy Velocity vector3', value = 'velocity', desc = vector3Text(snapshot.velocity) },
            { label = 'Copy Complete Player Pack', value = 'bundle', desc = 'Copies every player coordinate format as one Lua block.' },
            { label = 'Refresh Coordinates', value = 'refresh', desc = 'Read your current position again.' },
            { label = 'Back', value = 'back', desc = 'Return to the admin coordinate menu.' }
        }
    }, function(data, menu)
        local value = data.current and data.current.value
        if value == 'vector2' then copyText('vector2', vector2Text(snapshot.coords))
        elseif value == 'vector3' then copyText('vector3', vector3Text(snapshot.coords))
        elseif value == 'vector4' then copyText('vector4', vector4Text(snapshot.coords, snapshot.heading))
        elseif value == 'heading' then copyText('heading', heading)
        elseif value == 'raw3' then copyText('raw X, Y, Z', raw3Text(snapshot.coords))
        elseif value == 'raw4' then copyText('raw X, Y, Z, H', raw4Text(snapshot.coords, snapshot.heading))
        elseif value == 'table' then copyText('Lua coordinate table', tableText(snapshot.coords, snapshot.heading))
        elseif value == 'json' then copyText('JSON coordinates', jsonText(snapshot.coords, snapshot.heading))
        elseif value == 'rotation' then copyText('rotation vector3', vector3Text(snapshot.rotation))
        elseif value == 'forward' then copyText('forward vector3', vector3Text(snapshot.forward))
        elseif value == 'velocity' then copyText('velocity vector3', vector3Text(snapshot.velocity))
        elseif value == 'bundle' then copyPlayerBundle(snapshot)
        elseif value == 'refresh' then menu.close(false, false, false); State.menu = nil; openPlayerMenu()
        elseif value == 'back' then menu.close(false, false, false); State.menu = nil; openMainMenu()
        end
    end, function()
        openMainMenu()
    end)
end

openCameraMenu = function()
    local snapshot = cameraSnapshot()

    openMenu('camera_coordinates', {
        title = 'Camera Coordinates',
        subtext = vector3Text(snapshot.coords),
        align = Config.Menu.align,
        enableCursor = Config.Menu.enableCursor,
        maxVisibleItems = Config.Menu.maxVisibleItems,
        hideRadar = Config.Menu.hideRadar,
        elements = {
            { label = 'Copy Camera vector3', value = 'coords', desc = vector3Text(snapshot.coords) },
            { label = 'Copy Camera Rotation', value = 'rotation', desc = vector3Text(snapshot.rotation) },
            { label = 'Copy Camera Direction', value = 'direction', desc = vector3Text(snapshot.direction) },
            { label = 'Copy Complete Camera Pack', value = 'bundle', desc = 'Copies camera position, rotation and direction.' },
            { label = 'Refresh Camera', value = 'refresh', desc = 'Read the gameplay camera again.' },
            { label = 'Back', value = 'back', desc = 'Return to the admin coordinate menu.' }
        }
    }, function(data, menu)
        local value = data.current and data.current.value
        if value == 'coords' then copyText('camera vector3', vector3Text(snapshot.coords))
        elseif value == 'rotation' then copyText('camera rotation', vector3Text(snapshot.rotation))
        elseif value == 'direction' then copyText('camera direction', vector3Text(snapshot.direction))
        elseif value == 'bundle' then
            copyText('complete camera coordinate pack', table.concat({
                ('-- NODE7 camera coordinate pack (%s decimals)'):format(State.precision),
                ('local cameraCoords = %s'):format(vector3Text(snapshot.coords)),
                ('local cameraRotation = %s'):format(vector3Text(snapshot.rotation)),
                ('local cameraDirection = %s'):format(vector3Text(snapshot.direction))
            }, '\n'))
        elseif value == 'refresh' then menu.close(false, false, false); State.menu = nil; openCameraMenu()
        elseif value == 'back' then menu.close(false, false, false); State.menu = nil; openMainMenu()
        end
    end, function()
        openMainMenu()
    end)
end

openTargetMenu = function()
    closeCurrentMenu(true)
    notify('Aim at an entity. Reading target coordinates...', 'inform')

    raycastFromCamera(function(snapshot, hitCoords, surfaceNormal)
        if not snapshot then
            local elements = {
                { label = 'Copy Ray Hit vector3', value = 'hit', desc = vector3Text(hitCoords) },
                { label = 'Copy Surface Normal', value = 'normal', desc = vector3Text(surfaceNormal) },
                { label = 'Scan Again', value = 'refresh', desc = 'Aim at a ped, wagon, vehicle or object.' },
                { label = 'Back', value = 'back', desc = 'Return to the admin coordinate menu.' }
            }

            openMenu('target_coordinates_empty', {
                title = 'Target Coordinates',
                subtext = 'No entity hit. World impact coordinates are available.',
                align = Config.Menu.align,
                enableCursor = Config.Menu.enableCursor,
                maxVisibleItems = Config.Menu.maxVisibleItems,
                hideRadar = Config.Menu.hideRadar,
                elements = elements
            }, function(data, menu)
                local value = data.current and data.current.value
                if value == 'hit' then copyText('ray hit vector3', vector3Text(hitCoords))
                elseif value == 'normal' then copyText('surface normal vector3', vector3Text(surfaceNormal))
                elseif value == 'refresh' then menu.close(false, false, false); State.menu = nil; openTargetMenu()
                elseif value == 'back' then menu.close(false, false, false); State.menu = nil; openMainMenu()
                end
            end, function()
                openMainMenu()
            end)
            return
        end

        local typeLabel = entityTypeLabel(snapshot.type)
        local heading = formatNumber(snapshot.heading)

        openMenu('target_coordinates', {
            title = 'Target Entity Coordinates',
            subtext = ('%s | Model %s | Entity %s'):format(typeLabel, snapshot.model, snapshot.entity),
            align = Config.Menu.align,
            enableCursor = Config.Menu.enableCursor,
            maxVisibleItems = Config.Menu.maxVisibleItems,
            hideRadar = Config.Menu.hideRadar,
            elements = {
                { label = 'Copy Entity vector3', value = 'vector3', desc = vector3Text(snapshot.coords) },
                { label = 'Copy Entity vector4', value = 'vector4', desc = vector4Text(snapshot.coords, snapshot.heading) },
                { label = 'Copy Entity Heading', value = 'heading', desc = heading },
                { label = 'Copy Entity Rotation', value = 'rotation', desc = vector3Text(snapshot.rotation) },
                { label = 'Copy Entity Velocity', value = 'velocity', desc = vector3Text(snapshot.velocity) },
                { label = 'Copy Model Hash', value = 'model', desc = tostring(snapshot.model) },
                { label = 'Copy Entity Handle', value = 'entity', desc = tostring(snapshot.entity) },
                { label = 'Copy Network ID', value = 'network', desc = snapshot.networked and tostring(snapshot.networkId) or 'Entity is not networked.' },
                { label = 'Copy Complete Entity Pack', value = 'bundle', desc = 'Copies coordinates and entity metadata.' },
                { label = 'Scan Again', value = 'refresh', desc = 'Aim at another entity.' },
                { label = 'Back', value = 'back', desc = 'Return to the admin coordinate menu.' }
            }
        }, function(data, menu)
            local value = data.current and data.current.value
            if value == 'vector3' then copyText('entity vector3', vector3Text(snapshot.coords))
            elseif value == 'vector4' then copyText('entity vector4', vector4Text(snapshot.coords, snapshot.heading))
            elseif value == 'heading' then copyText('entity heading', heading)
            elseif value == 'rotation' then copyText('entity rotation', vector3Text(snapshot.rotation))
            elseif value == 'velocity' then copyText('entity velocity', vector3Text(snapshot.velocity))
            elseif value == 'model' then copyText('entity model hash', tostring(snapshot.model))
            elseif value == 'entity' then copyText('entity handle', tostring(snapshot.entity))
            elseif value == 'network' then
                if snapshot.networked then copyText('entity network ID', tostring(snapshot.networkId))
                else notify('The targeted entity is not networked.', 'error') end
            elseif value == 'bundle' then
                copyText('complete entity coordinate pack', table.concat({
                    ('-- NODE7 target entity pack (%s)'):format(typeLabel),
                    ('local entityCoords = %s'):format(vector3Text(snapshot.coords)),
                    ('local entityPlacement = %s'):format(vector4Text(snapshot.coords, snapshot.heading)),
                    ('local entityRotation = %s'):format(vector3Text(snapshot.rotation)),
                    ('local entityVelocity = %s'):format(vector3Text(snapshot.velocity)),
                    ('local entityModel = %s'):format(snapshot.model),
                    ('local entityHandle = %s'):format(snapshot.entity),
                    ('local networkId = %s'):format(snapshot.networked and snapshot.networkId or 'nil')
                }, '\n'))
            elseif value == 'refresh' then menu.close(false, false, false); State.menu = nil; openTargetMenu()
            elseif value == 'back' then menu.close(false, false, false); State.menu = nil; openMainMenu()
            end
        end, function()
            openMainMenu()
        end)
    end)
end

openSettingsMenu = function()
    openMenu('coordinate_settings', {
        title = 'Coordinate Settings',
        subtext = 'Configure output precision and live display.',
        align = Config.Menu.align,
        enableCursor = Config.Menu.enableCursor,
        maxVisibleItems = Config.Menu.maxVisibleItems,
        hideRadar = Config.Menu.hideRadar,
        elements = {
            {
                label = 'Decimal Precision',
                value = State.precision,
                min = Config.MinimumPrecision,
                max = Config.MaximumPrecision,
                hop = 1,
                type = 'slider',
                quantity = true,
                coordinatePrecision = true,
                desc = 'Number of decimal places used in copied coordinates.'
            },
            {
                label = State.liveDisplay and 'Disable Live Coordinate Display' or 'Enable Live Coordinate Display',
                value = 'toggle_live',
                desc = 'Shows current vector3, vector4, heading and rotation on screen.'
            },
            { label = 'Back', value = 'back', desc = 'Return to the admin coordinate menu.' }
        }
    }, function(data, menu)
        local current = data.current
        if not current then return end

        if current.coordinatePrecision then
            State.precision = math.max(Config.MinimumPrecision, math.min(Config.MaximumPrecision, tonumber(current.value) or State.precision))
            notify(('Coordinate precision set to %s decimals.'):format(State.precision), 'success')
        elseif current.value == 'toggle_live' then
            State.liveDisplay = not State.liveDisplay
            notify(State.liveDisplay and 'Live coordinate display enabled.' or 'Live coordinate display disabled.', 'success')
            menu.close(false, false, false)
            State.menu = nil
            openSettingsMenu()
        elseif current.value == 'back' then
            menu.close(false, false, false)
            State.menu = nil
            openMainMenu()
        end
    end, function()
        openMainMenu()
    end, function(data)
        local current = data.current
        if current and current.coordinatePrecision then
            State.precision = math.max(Config.MinimumPrecision, math.min(Config.MaximumPrecision, tonumber(current.value) or State.precision))
        end
    end)
end

openMainMenu = function()
    local snapshot = playerSnapshot()

    openMenu('main', {
        title = Config.Menu.title,
        subtext = Config.Menu.subtext,
        align = Config.Menu.align,
        enableCursor = Config.Menu.enableCursor,
        maxVisibleItems = Config.Menu.maxVisibleItems,
        hideRadar = Config.Menu.hideRadar,
        elements = {
            { label = 'Player Coordinates', value = 'player', desc = 'Copy vector2, vector3, vector4, heading, rotation and full coordinate packs.' },
            { label = 'Camera Coordinates', value = 'camera', desc = 'Copy gameplay camera position, rotation and direction.' },
            { label = 'Target Entity Coordinates', value = 'target', desc = 'Aim at a ped, wagon, vehicle or object and copy its data.' },
            { label = 'Copy Current vector3', value = 'quick_vector3', desc = vector3Text(snapshot.coords) },
            { label = 'Copy Current vector4', value = 'quick_vector4', desc = vector4Text(snapshot.coords, snapshot.heading) },
            { label = 'Copy Current Heading', value = 'quick_heading', desc = formatNumber(snapshot.heading) },
            { label = 'Copy Complete Player Pack', value = 'quick_bundle', desc = 'Copies every player coordinate format immediately.' },
            { label = 'Coordinate Settings', value = 'settings', desc = ('Precision: %s | Live display: %s'):format(State.precision, State.liveDisplay and 'ON' or 'OFF') },
            { label = 'Close', value = 'close', desc = 'Close NODE7 Admin Coordinates.' }
        }
    }, function(data, menu)
        local value = data.current and data.current.value
        if value == 'player' then menu.close(false, false, false); State.menu = nil; openPlayerMenu()
        elseif value == 'camera' then menu.close(false, false, false); State.menu = nil; openCameraMenu()
        elseif value == 'target' then menu.close(false, false, false); State.menu = nil; openTargetMenu()
        elseif value == 'quick_vector3' then copyText('vector3', vector3Text(playerSnapshot().coords))
        elseif value == 'quick_vector4' then local current = playerSnapshot(); copyText('vector4', vector4Text(current.coords, current.heading))
        elseif value == 'quick_heading' then copyText('heading', formatNumber(playerSnapshot().heading))
        elseif value == 'quick_bundle' then copyPlayerBundle(playerSnapshot())
        elseif value == 'settings' then menu.close(false, false, false); State.menu = nil; openSettingsMenu()
        elseif value == 'close' then State.menu = nil; menu.close(true, true, true)
        end
    end)
end

RegisterNetEvent('node7-admincoords:client:openMenu', function()
    if not isMenuBaseReady() then
        notify('NODE7 Menu Base is not ready. Ensure node7-menu-base v2.1.0 or newer is running.', 'error')
        return
    end

    openMainMenu()
end)

local function drawText(text, x, y, scale, color, centered)
    SetTextScale(scale, scale)
    SetTextColor(color.r, color.g, color.b, color.a or 255)
    SetTextCentre(centered == true)
    SetTextFontForCurrentCommand(9)
    SetTextDropshadow(2, 0, 0, 0, 220)
    DisplayText(CreateVarString(10, 'LITERAL_STRING', tostring(text)), x, y)
end

CreateThread(function()
    local gold = { r = 201, g = 164, b = 93, a = 255 }
    local white = { r = 245, g = 239, b = 223, a = 255 }

    while true do
        if not State.liveDisplay or IsPauseMenuActive() then
            Wait(250)
        else
            Wait(0)
            local snapshot = playerSnapshot()
            local cfg = Config.LiveDisplay
            local lines = {
                'NODE7 ADMIN COORDINATES',
                ('vector3: %s'):format(vector3Text(snapshot.coords)),
                ('vector4: %s'):format(vector4Text(snapshot.coords, snapshot.heading)),
                ('heading: %s'):format(formatNumber(snapshot.heading)),
                ('rotation: %s'):format(vector3Text(snapshot.rotation))
            }

            local height = (cfg.lineHeight * #lines) + 0.024
            DrawRect(cfg.x + (cfg.width * 0.5), cfg.y + (height * 0.5), cfg.width + 0.004, height + 0.004, 201, 164, 93, cfg.borderAlpha)
            DrawRect(cfg.x + (cfg.width * 0.5), cfg.y + (height * 0.5), cfg.width, height, 8, 8, 8, cfg.backgroundAlpha)

            for index, line in ipairs(lines) do
                drawText(line, cfg.x + 0.010, cfg.y + 0.008 + ((index - 1) * cfg.lineHeight), cfg.scale, index == 1 and gold or white, false)
            end
        end
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == RESOURCE then
        closeCurrentMenu(true)
        State.liveDisplay = false
        SetNuiFocus(false, false)
    elseif resourceName == MENU_RESOURCE then
        State.menu = nil
    end
end)
