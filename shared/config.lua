Config = {}

Config.Frameworks = {
    ESX = { enabled = true },
    QBCore = { enabled = false },
    QBox = { enabled = false },
    VRP = { enabled = false },
}

Config.OpenKey = 'F6'
Config.MaxRange = 15.0
Config.TickInterval = 250
Config.MuffleVolumeFactor = 0.28
Config.MaxRecentlyPlayed = 30

Config.ShowBackProp = true
Config.BackModel = `sm_prop_smug_radio_01`
Config.BackPropBone = 24818
Config.BackPropOffset = { x = 0.02, y = -0.15, z = -0.1 }
Config.BackPropRotation = { x = 0.0, y = 45.0, z = 0.0 }

Config.DjMixerModel = `prop_dj_deck_02`
Config.DjOutdoorRange = 150.0
Config.DjPermission = false

Config.Placement = {
    maxDistance = 10.0,
    farDistance = 40.0,
    rotateStep = 2.5,
    heightStep = 0.02,
    interactRange = 5.0,
    targetDistance = 2.0,
    controlRange = 25.0,
}

Config.DjModels = {
    'prop_dj_deck_02',
    'prop_dj_deck_01',
    'ba_prop_battle_dj_stand',
}

Config.DjSound = {
    minRadius = 10.0,
    maxRadius = 300.0,
    maxMuffled = 120.0,
    defaultMuffled = 15.0,
    maxAreaPoints = 24,
    defaultAreaHeight = 8.0,
    defaultAreaFade = 25.0,
}

Config.DiscoLights = {
    enabled = true,
    maxPerBooth = 10,
    drawDistance = 80.0,
    bpm = 124,
    fixtureDistance = 120.0,
    fixtures = {
        'prop_worklight_03b',
        'prop_worklight_04b',
        'prop_studio_light_02',
        'prop_studio_light_03',
        'prop_kino_light_03',
        'tr_prop_wall_light_02a',
        'vb_39_lightnw_03',
        'tr_prop_tr_serv_tu_light3',
        'hw1_04_lightfittings',
    },
    colors = {
        { name = 'Rainbow', rgb = false },
        { name = 'Red', rgb = { 255, 40, 70 } },
        { name = 'Pink', rgb = { 255, 70, 190 } },
        { name = 'Purple', rgb = { 160, 70, 255 } },
        { name = 'Blue', rgb = { 50, 110, 255 } },
        { name = 'Cyan', rgb = { 40, 230, 255 } },
        { name = 'Green', rgb = { 60, 255, 110 } },
        { name = 'Yellow', rgb = { 255, 220, 40 } },
        { name = 'White', rgb = { 255, 255, 255 } },
    },
}

Config.DoorOpenThreshold = 0.08

Config.NowPlayingWidget = true
Config.WidgetCommand = 'radiohud'

Config.AdminCommand = 'radioadmin'
Config.AdminAce = 'group.admin'
Config.AdminGroups = { 'admin', 'superadmin' }
Config.AdminNearbyRadius = 50.0
Config.ActivityLogSize = 150

Config.Messages = {
    placement_help = 'Move mouse to position ~ ~INPUT_FRONTEND_LEFT~/~INPUT_FRONTEND_RIGHT~ Rotate ~ ~INPUT_FRONTEND_UP~/~INPUT_FRONTEND_DOWN~ Height ~ ~INPUT_FRONTEND_ACCEPT~ Confirm ~ ~INPUT_FRONTEND_CANCEL~ Cancel',
    placement_saved = "DJ station placed. Indoor playback will use this location's interior.",
    placement_cancelled = 'Placement cancelled.',
    no_permission = "You don't have permission to do that.",
    no_station_nearby = 'No DJ station owned by you is nearby.',
    radio_forbidden_interior = 'Radio in this interior is forbidden.',
    dj_interior_occupied = 'There is already a DJ console in this interior.',
    dj_no_access = "Your job can't use this DJ console.",
    station_removed = 'DJ station removed.',
    not_ready = 'Still connecting, try again in a moment.',
    admin_stopped = 'An admin stopped your music.',
    banned_dj = 'You are banned from using DJ booths.',
    banned_all = 'You are banned from using the radio.',
    unbanned = 'Your radio ban was lifted.',
    widget_on = 'Now playing widget shown.',
    widget_off = 'Now playing widget hidden. Use /radiohud to bring it back.',
    creator_saved = 'DJ booth saved.',
    creator_updated = 'DJ booth updated.',
    creator_create_failed = 'Failed to create DJ station.',
    creator_update_failed = 'Failed to update the DJ booth.',
}
