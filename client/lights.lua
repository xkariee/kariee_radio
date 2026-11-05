-- Disco lights attached to DJ booths. Pure draw natives (spot lights, point lights, laser lines):
-- every nearby client animates them locally while the booth is playing, so there's nothing to
-- network. A light can be mounted on a fixture prop instead of its glowing dot - those are local
-- objects spawned near the booth (bottom of this file). The creator uses DrawDjLights() and
-- PlaceDjFixture() for its live preview.
--
-- Everything moves in musical time: `beats` counts beats into the song, from where this client's
-- player actually is in it (BroadcastSongTime) and the booth's tempo - tapped in by the DJ, or the
-- default below from the start of the song. Sweeps span whole bars, colours change on the beat and
-- strobes hit on it, and since it's all song time everyone in the room sees the same show.

local DEFAULT_BPM = Config.DiscoLights.bpm or 124
local PI = math.pi

local colorsByName = {}
for _, c in ipairs(Config.DiscoLights.colors) do colorsByName[c.name] = c.rgb end

local function hsv(h)
    local i = math.floor(h * 6) % 6
    local f = h * 6 - math.floor(h * 6)
    local q = 1 - f
    local r, g, b
    if i == 0 then r, g, b = 1, f, 0
    elseif i == 1 then r, g, b = q, 1, 0
    elseif i == 2 then r, g, b = 0, 1, f
    elseif i == 3 then r, g, b = 0, q, 1
    elseif i == 4 then r, g, b = f, 0, 1
    else r, g, b = 1, 0, q end
    return math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)
end

local function colorOf(light, beats, offset)
    local rgb = colorsByName[light.color]
    if rgb then return rgb[1], rgb[2], rgb[3] end
    -- 'Rainbow' / unknown: a new hue on every beat, all the way round every 4 bars.
    return hsv((math.floor(beats) / 16.0 * (light.speed or 1.0) + (offset or 0.0)) % 1.0)
end

-- GTA heading convention: 0 = north (+Y), forward = (-sin h, cos h). pitch < 0 points down.
local function direction(yawDeg, pitchDeg)
    local yaw, pitch = math.rad(yawDeg), math.rad(pitchDeg)
    return vector3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
end

-- Fixtures face the booth's console, i.e. the dance floor in front of it.
local function yawTowards(from, to)
    return math.deg(math.atan(-(to.x - from.x), to.y - from.y))
end

local function glow(p, size, r, g, b, a)
    DrawMarker(28, p.x, p.y, p.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size, size, r, g, b, a, false, false, 2, false, nil, nil, false)
end
local function noGlow() end

---Draws one light for the current frame.
---@param light table { type, x, y, z, color, speed, fixture?, prop? }
---@param center vector3 the booth console (lights aim at it)
---@param beats number beats into the song (the fraction is the position inside the current beat)
local function drawLight(light, center, beats)
    local p = vector3(light.x, light.y, light.z)
    local s = light.speed or 1.0
    local base = yawTowards(p, center)
    local seed = (light.x + light.y) % 7
    local beat = beats % 1.0
    local pulse = (1.0 - beat) ^ 3 -- 1 right on the beat, gone by the next one
    local downbeat = math.floor(beats) % 4 == 0
    -- The dot stands in for the fixture; a prop (or 'none') replaces it.
    local glow = (light.fixture == nil or light.fixture == 'glow') and glow or noGlow

    if light.type == 'spot' then
        -- Moving head: one sweep across the floor every 4 bars, dipping every 2, kicking on the beat.
        local yaw = base + math.sin(beats * PI / 8.0 * s + seed) * 55.0
        local pitch = -55.0 + math.sin(beats * PI / 4.0 * s + seed * 1.7) * 22.0
        local d = direction(yaw, pitch)
        local r, g, b = colorOf(light, beats)
        DrawSpotLight(p.x, p.y, p.z, d.x, d.y, d.z, r, g, b, 32.0, 14.0 + 14.0 * pulse, 0.0, 9.0, 1.0)
        glow(p, 0.14, r, g, b, math.floor(170 + 85 * pulse))
    elseif light.type == 'laser' then
        -- Fan of beams sweeping across the room every 2 bars, cut just before each beat.
        if beat > 0.85 then return end
        local sweep = math.sin(beats * PI / 4.0 * s + seed) * 35.0
        local pitch = -10.0 + math.sin(beats * PI / 8.0 * s) * 8.0
        local beams = 7
        for i = 0, beams - 1 do
            local yaw = base + sweep + (i / (beams - 1) - 0.5) * 60.0
            local d = direction(yaw, pitch)
            local e = p + d * 22.0
            local r, g, b = colorOf(light, beats, i * 0.05)
            DrawLine(p.x, p.y, p.z, e.x, e.y, e.z, r, g, b, 255)
        end
        local r, g, b = colorOf(light, beats)
        glow(p, 0.1, r, g, b, 255)
    elseif light.type == 'ball' then
        -- Mirror ball: turns one dot-spacing (60 degrees) per bar, scattering dots around the room.
        local r, g, b = colorOf(light, beats)
        glow(p, 0.38, 235, 235, 245, 255)
        DrawLightWithRange(p.x, p.y, p.z, r, g, b, 3.5, 2.0 + 1.5 * pulse)
        for i = 0, 5 do
            local yaw = beats * 15.0 * s + i * 60.0
            local pitch = -20.0 - (i % 2) * 22.0
            local d = direction(yaw, pitch)
            local cr, cg, cb = colorOf(light, beats, i * 0.16)
            DrawSpotLight(p.x, p.y, p.z, d.x, d.y, d.z, cr, cg, cb, 25.0, 14.0, 0.0, 3.5, 1.0)
        end
    elseif light.type == 'strobe' then
        -- Wash that pulses on every beat, with a hard white flash on it - harder on each bar's 1.
        local r, g, b = colorOf(light, beats)
        if beat < 0.08 then
            if downbeat then
                DrawLightWithRange(p.x, p.y, p.z, 255, 255, 255, 22.0, 20.0)
            else
                DrawLightWithRange(p.x, p.y, p.z, 255, 255, 255, 16.0, 14.0)
            end
        end
        DrawLightWithRange(p.x, p.y, p.z, r, g, b, 14.0, 1.5 + 7.0 * pulse)
        glow(p, 0.12, r, g, b, math.floor(120 + 135 * pulse))
    end
end

---Draws a set of lights for this frame (also used for the creator's preview).
---@param beats number beats into the song, see drawLight()
function DrawDjLights(lights, center, beats)
    for _, light in ipairs(lights) do drawLight(light, center, beats) end
end

---Puts a fixture prop in place: the bottom of its model on `base`, turned to `heading`, and upside
---down when `flip` (hung from a ceiling).
---@return vector3 where its light comes out - just past the other end of the model
function PlaceDjFixture(obj, base, heading, flip)
    local minV, maxV = GetModelDimensions(GetEntityModel(obj))
    local cx, cy = (minV.x + maxV.x) / 2, (minV.y + maxV.y) / 2
    SetEntityRotation(obj, 0.0, flip and 180.0 or 0.0, heading, 2, false)
    SetEntityCoordsNoOffset(obj, base.x, base.y, base.z, false, false, false)
    local anchor = GetOffsetFromEntityInWorldCoords(obj, cx, cy, minV.z)
    SetEntityCoordsNoOffset(obj, base.x * 2 - anchor.x, base.y * 2 - anchor.y, base.z * 2 - anchor.z, false, false, false)
    return GetOffsetFromEntityInWorldCoords(obj, cx, cy, maxV.z + 0.1)
end

---Spawns a light's fixture prop as a local object, or nil if the model isn't in this game build.
---@param prop table { model, x, y, z, h, flip } (a light's `prop`)
---@param ghost boolean|nil creator preview: see-through and no collision (so aiming ignores it)
function SpawnDjFixture(prop, ghost)
    local hash = GetHashKey(prop.model)
    if not IsModelInCdimage(hash) or not LoadModel(hash) then return nil end
    local obj = CreateObject(hash, prop.x, prop.y, prop.z, false, false, false)
    FreezeEntityPosition(obj, true)
    if ghost then
        SetEntityAlpha(obj, 200, false)
        SetEntityCollision(obj, false, false)
    end
    PlaceDjFixture(obj, vector3(prop.x, prop.y, prop.z), prop.h or 0.0, prop.flip == true)
    SetModelAsNoLongerNeeded(hash)
    return obj
end

---Free-running beat clock for the creator's preview, where there's no song to follow.
function DjPreviewBeats(ms)
    return ms / 1000.0 * DEFAULT_BPM / 60.0
end

---Beats into the song playing at a booth: its tapped tempo when set, else the default from the
---start of the song.
local function boothBeats(broadcastId)
    local songTime = BroadcastSongTime(broadcastId) or 0.0
    local tempo = BroadcastTempo(broadcastId)
    local bpm = tempo and tonumber(tempo.bpm) or DEFAULT_BPM
    local offset = tempo and tonumber(tempo.offset) or 0.0
    return (songTime - offset) * bpm / 60.0
end

-- Which booths are worth drawing is decided twice a second; drawing itself is every frame.
CreateThread(function()
    if not Config.DiscoLights.enabled then return end
    while true do
        local active = {}
        local myCoords = GetEntityCoords(PlayerPedId())
        for id, station in pairs(DjStations or {}) do
            local lights = station.settings and station.settings.lights
            local broadcastId = ('dj:%s'):format(id)
            if lights and #lights > 0 and IsBroadcastPlaying(broadcastId) then
                local center = vector3(station.pos_x, station.pos_y, station.pos_z)
                if IsBroadcastNear(broadcastId) or #(myCoords - center) <= Config.DiscoLights.drawDistance then
                    active[#active + 1] = { id = broadcastId, lights = lights, center = center }
                end
            end
        end

        if #active == 0 then
            Wait(500)
        else
            local untilMs = GetGameTimer() + 500
            while GetGameTimer() < untilMs do
                for _, a in ipairs(active) do DrawDjLights(a.lights, a.center, boothBeats(a.id)) end
                Wait(0)
            end
        end
    end
end)

-- ─── Fixture props ─────────────────────────────────────────────────────────
-- Unlike the show itself these stay up when nothing is playing. Spawned for players near the
-- booth, and rebuilt when its setup changes (the update replaces station.settings).

local fixtureObjs = {} -- stationId -> { settings = the table they were built from, objs }

local function clearFixtures(id)
    for _, obj in ipairs(fixtureObjs[id].objs) do
        if DoesEntityExist(obj) then DeleteObject(obj) end
    end
    fixtureObjs[id] = nil
end

local function hasFixtures(station)
    for _, light in ipairs(station.settings and station.settings.lights or {}) do
        if light.fixture == 'prop' and light.prop then return true end
    end
    return false
end

CreateThread(function()
    if not Config.DiscoLights.enabled then return end
    local range = Config.DiscoLights.fixtureDistance or 120.0
    while true do
        local me = GetEntityCoords(PlayerPedId())
        for id, f in pairs(fixtureObjs) do
            local station = DjStations[id]
            -- The creator shows its own copies while that booth is being edited.
            if not station or station.settings ~= f.settings or DjEditingStationId == id
                or #(me - vector3(station.pos_x, station.pos_y, station.pos_z)) > range + 20.0 then
                clearFixtures(id)
            end
        end
        for id, station in pairs(DjStations or {}) do
            if not fixtureObjs[id] and DjEditingStationId ~= id and hasFixtures(station)
                and #(me - vector3(station.pos_x, station.pos_y, station.pos_z)) <= range then
                local objs = {}
                for _, light in ipairs(station.settings.lights) do
                    if light.fixture == 'prop' and light.prop then objs[#objs + 1] = SpawnDjFixture(light.prop) end
                end
                fixtureObjs[id] = { settings = station.settings, objs = objs }
            end
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for id in pairs(fixtureObjs) do clearFixtures(id) end
end)
