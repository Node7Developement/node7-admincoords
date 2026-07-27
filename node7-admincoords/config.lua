Config = Config or {}

Config.Command = 'admin'
Config.Permission = 'node7.admincoords.use'

Config.DefaultPrecision = 4
Config.MinimumPrecision = 2
Config.MaximumPrecision = 8
Config.RaycastDistance = 150.0

Config.Menu = {
    title = 'NODE7 Admin Coordinates',
    subtext = 'Copy precise development coordinates.',
    align = 'left',
    enableCursor = true,
    maxVisibleItems = 10,
    hideRadar = false
}

Config.LiveDisplay = {
    enabledByDefault = false,
    x = 0.018,
    y = 0.075,
    width = 0.360,
    lineHeight = 0.025,
    scale = 0.285,
    backgroundAlpha = 205,
    borderAlpha = 235
}

Config.Notification = {
    title = 'ADMIN COORDS',
    duration = 3500
}
