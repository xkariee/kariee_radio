Config = {}

-- ─── General ────────────────────────────────────────────────────────────────

-- Key that opens/closes the radio NUI (RegisterKeyMapping, rebindable in FiveM settings)
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

-- ─── DJ mixer (/createdj) ───────────────────────────────────────────────────

Config.DjMixerModel = `h4_prop_battle_dj_mixer_01c`

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

-- ─── Car radio (/radiocar) ──────────────────────────────────────────────────

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
    not_in_vehicle = 'You need to be in a vehicle to use /radiocar.',
    not_driver = 'Only the driver can start the car radio.',
}
