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
    maxDistance = 10.0,  -- how far in front of the camera the ghost prop can be placed
    rotateStep = 2.5,    -- degrees per tick while holding left/right
    heightStep = 0.02,   -- metres per tick while holding up/down
    interactRange = 5.0, -- how close you need to be to a station for /dj and /removedj
    targetDistance = 2.0, -- ox_target interaction range on the spawned DJ mixer prop
}

-- ─── Car radio (F6, while in a vehicle) ─────────────────────────────────────

-- Ratio (0-1) above which a door is considered "open" for the purposes of muffling.
Config.DoorOpenThreshold = 0.08

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
}
