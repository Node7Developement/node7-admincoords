local RESOURCE = GetCurrentResourceName()

local function notify(source, message, notificationType)
    if GetResourceState('node7-core') == 'started' then
        local ok = pcall(function()
            exports['node7-core']:Notify(
                source,
                message,
                notificationType or 'inform',
                Config.Notification.duration,
                Config.Notification.title
            )
        end)

        if ok then return end
    end

    TriggerClientEvent('chat:addMessage', source, {
        color = { 201, 164, 93 },
        args = { 'NODE7', message }
    })
end

local function hasPermission(source)
    source = tonumber(source)
    return source and source > 0 and IsPlayerAceAllowed(source, Config.Permission) or false
end

RegisterCommand(Config.Command, function(source)
    source = tonumber(source) or 0

    if source <= 0 then
        print(('^3[%s]^7 /%s must be used in-game.'):format(RESOURCE, Config.Command))
        return
    end

    if not hasPermission(source) then
        notify(source, ('Access denied. Missing ACE: %s'):format(Config.Permission), 'error')
        return
    end

    TriggerClientEvent('node7-admincoords:client:openMenu', source)
end, false)

exports('HasPermission', hasPermission)
