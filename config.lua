Config = {}

-- ─── General ────────────────────────────────────────────────────────────────

-- Key that opens/closes the radio NUI (RegisterKeyMapping, rebindable in FiveM settings).
-- Opens your personal radio, or the car radio if you're currently in a vehicle.
Config.OpenKey = 'F6'

-- Max distance (metres) any broadcast (personal radio, DJ station, car radio) can be heard at.
-- Volume fades linearly from the broadcaster's chosen volume at 0m down to 0 at this distance.
Config.MaxRange = 15.0

-- How often (ms) each client recomputes distance/volume for every broadcast it can hear.
Config.TickInterval = 250

-- How often (ms) the source-player's own position is treated as "moved enough to matter" is not
-- needed separately - GetEntityCoords is cheap and called every tick above.

-- Multiplier applied to volume when the listener is on the "wrong side" of an interior boundary
-- (or, for car radios, outside a fully sealed vehicle). 0 = fully silent, 1 = no muffling.
Config.MuffleVolumeFactor = 0.28

-- ─── Playlists / favourites / recently played ──────────────────────────────

Config.MaxRecentlyPlayed = 30

-- ─── Personal radio (F6, out of a vehicle) ──────────────────────────────────

-- Spawns Config.BackModel on the player's back for as long as their personal radio is playing,
-- deletes it the moment it's paused/stopped. Set to false to disable entirely.
Config.ShowBackProp = true
Config.BackModel = `sm_prop_smug_radio_01`

-- Attachment bone + offset/rotation for the back prop. Tune these to fit BackModel.
Config.BackPropBone = 24818 -- SKEL_Spine2, the usual "on the back" bone
Config.BackPropOffset = { x = 0.02, y = -0.15, z = -0.1 }
Config.BackPropRotation = { x = 0.0, y = 45.0, z = 0.0 }

-- ─── DJ mixer (/createdj) ───────────────────────────────────────────────────

Config.DjMixerModel = `prop_dj_deck_02`

-- Max range (metres) for a DJ station placed outdoors (not inside any interior) - an open-air
-- rig should carry much further than Config.MaxRange. Indoor stations still use Config.MaxRange
-- once you leave their interior (they fill the room itself regardless of distance).
Config.DjOutdoorRange = 150.0

-- ACE permission required to use /createdj and /removedj. Set to false to allow everyone.
Config.DjPermission = 'group.admin'

-- Placement tool tuning
Config.Placement = {
    maxDistance = 10.0,  -- how far in front of the camera the console / interaction box can be placed
    farDistance = 40.0,  -- how far you can aim when drawing a sound area or placing lights
    rotateStep = 2.5,    -- degrees per tick while holding left/right
    heightStep = 0.02,   -- metres per tick while holding up/down
    interactRange = 5.0, -- how close you need to be to a station for /dj and /removedj
    targetDistance = 2.0, -- ox_target interaction range on the spawned DJ mixer prop
}

-- Console props the creator (/createdj) cycles through with [M]. Models that don't exist in your
-- game build are skipped automatically, so add your own (e.g. from an MLO) freely.
Config.DjModels = {
    'prop_dj_deck_02',
    'prop_dj_deck_01',
    'ba_prop_battle_dj_stand',
}

-- Limits for the "Sound" step of the creator.
Config.DjSound = {
    minRadius = 10.0,      -- outdoor radius
    maxRadius = 300.0,
    maxMuffled = 120.0,    -- how far outside its interior an indoor booth can still be heard (muffled)
    defaultMuffled = 15.0,
    maxAreaPoints = 24,    -- corners of a custom sound area
    defaultAreaHeight = 8.0,
    defaultAreaFade = 25.0, -- metres outside a custom area over which the music fades out
}

-- Disco lights attached to DJ booths (placed in the creator's "Lights" step). They're drawn by
-- every nearby client while the booth is playing - no props, so nothing to stream or collide with.
Config.DiscoLights = {
    enabled = true,
    maxPerBooth = 10,
    drawDistance = 80.0, -- also drawn within this many metres of the booth, even outside its sound area
    bpm = 124,           -- beat the strobes/pulses follow
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

-- ─── Car radio (F6, while in a vehicle) ─────────────────────────────────────

-- Ratio (0-1) above which a door is considered "open" for the purposes of muffling.
Config.DoorOpenThreshold = 0.08

-- ─── Nearby "now playing" widget ────────────────────────────────────────────

-- Small on-screen card (cover, title, artist, time) shown while you're in range of a DJ booth -
-- or inside its interior. Players can move/hide it in the radio's Settings, or toggle it with
-- /radiohud. Set to false to turn the widget off for everyone.
Config.NowPlayingWidget = true
Config.WidgetCommand = 'radiohud'

-- ─── Admin panel (/radioadmin) ──────────────────────────────────────────────

Config.AdminCommand = 'radioadmin'

-- Who counts as a radio admin: anyone with this ACE permission (false to skip the ACE check)...
Config.AdminAce = 'group.admin'
-- ...or anyone whose ESX group is in this list.
Config.AdminGroups = { 'admin', 'superadmin' }

-- Radius (metres) used for "players nearby" counts and the panel's "Stop music near me" button.
Config.AdminNearbyRadius = 50.0

-- How many recent radio events (plays, admin actions, bans, booth changes) the panel keeps in memory.
Config.ActivityLogSize = 150

-- ─── Notifications ──────────────────────────────────────────────────────────

Config.Messages = {
    placement_help = 'Move mouse to position ~ ~INPUT_FRONTEND_LEFT~/~INPUT_FRONTEND_RIGHT~ Rotate ~ ~INPUT_FRONTEND_UP~/~INPUT_FRONTEND_DOWN~ Height ~ ~INPUT_FRONTEND_ACCEPT~ Confirm ~ ~INPUT_FRONTEND_CANCEL~ Cancel',
    placement_saved = 'DJ station placed. Indoor playback will use this location\'s interior.',
    placement_cancelled = 'Placement cancelled.',
    no_permission = 'You don\'t have permission to do that.',
    no_station_nearby = 'No DJ station owned by you is nearby.',
    radio_forbidden_interior = 'Radio in this interior is forbidden.',
    dj_interior_occupied = 'There is already a DJ console in this interior.',
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
}
