local DEFAULT_BPM = Config.DiscoLights.bpm or 124
local PI = math.pi

local colorsByName = {}
local fixtureObjs = {}

for _, color in ipairs(Config.DiscoLights.colors) do colorsByName[color.name] = color.rgb end

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
    return hsv((math.floor(beats) / 16.0 * (light.speed or 1.0) + (offset or 0.0)) % 1.0)
end

local function direction(yawDeg, pitchDeg)
    local yaw, pitch = math.rad(yawDeg), math.rad(pitchDeg)
    return vector3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
end

local function glow(light, p, size, r, g, b, a)
    if light.fixture == nil or light.fixture == 'glow' then Utils:DrawSphere(p, size, r, g, b, a) end
end

local function drawLight(light, center, beats)
    local p = vector3(light.x, light.y, light.z)
    local speed = light.speed or 1.0
    local base = Utils:HeadingTo(p, center)
    local seed = (light.x + light.y) % 7
    local beat = beats % 1.0
    local pulse = (1.0 - beat) ^ 3

    if light.type == 'spot' then
        local yaw = base + math.sin(beats * PI / 8.0 * speed + seed) * 55.0
        local pitch = -55.0 + math.sin(beats * PI / 4.0 * speed + seed * 1.7) * 22.0
        local d = direction(yaw, pitch)
        local r, g, b = colorOf(light, beats)
        DrawSpotLight(p.x, p.y, p.z, d.x, d.y, d.z, r, g, b, 32.0, 14.0 + 14.0 * pulse, 0.0, 9.0, 1.0)
        glow(light, p, 0.14, r, g, b, math.floor(170 + 85 * pulse))
    elseif light.type == 'laser' then
        if beat > 0.85 then return end
        local sweep = math.sin(beats * PI / 4.0 * speed + seed) * 35.0
        local pitch = -10.0 + math.sin(beats * PI / 8.0 * speed) * 8.0
        local beams = 7
        for i = 0, beams - 1 do
            local d = direction(base + sweep + (i / (beams - 1) - 0.5) * 60.0, pitch)
            local e = p + d * 22.0
            local r, g, b = colorOf(light, beats, i * 0.05)
            DrawLine(p.x, p.y, p.z, e.x, e.y, e.z, r, g, b, 255)
        end
        local r, g, b = colorOf(light, beats)
        glow(light, p, 0.1, r, g, b, 255)
    elseif light.type == 'ball' then
        local r, g, b = colorOf(light, beats)
        glow(light, p, 0.38, 235, 235, 245, 255)
        DrawLightWithRange(p.x, p.y, p.z, r, g, b, 3.5, 2.0 + 1.5 * pulse)
        for i = 0, 5 do
            local d = direction(beats * 15.0 * speed + i * 60.0, -20.0 - (i % 2) * 22.0)
            local cr, cg, cb = colorOf(light, beats, i * 0.16)
            DrawSpotLight(p.x, p.y, p.z, d.x, d.y, d.z, cr, cg, cb, 25.0, 14.0, 0.0, 3.5, 1.0)
        end
    elseif light.type == 'strobe' then
        local r, g, b = colorOf(light, beats)
        if beat < 0.08 then
            local downbeat = math.floor(beats) % 4 == 0
            DrawLightWithRange(p.x, p.y, p.z, 255, 255, 255, downbeat and 22.0 or 16.0, downbeat and 20.0 or 14.0)
        end
        DrawLightWithRange(p.x, p.y, p.z, r, g, b, 14.0, 1.5 + 7.0 * pulse)
        glow(light, p, 0.12, r, g, b, math.floor(120 + 135 * pulse))
    end
end

local function boothBeats(broadcastId)
    local songTime = BroadcastSongTime(broadcastId) or 0.0
    local tempo = BroadcastTempo(broadcastId)
    local bpm = tempo and tonumber(tempo.bpm) or DEFAULT_BPM
    local offset = tempo and tonumber(tempo.offset) or 0.0
    return (songTime - offset) * bpm / 60.0
end

local function clearFixtures(id)
    for _, obj in ipairs(fixtureObjs[id].objs) do Utils:DeleteProp(obj) end
    fixtureObjs[id] = nil
end

function DrawDjLights(lights, center, beats)
    for _, light in ipairs(lights) do drawLight(light, center, beats) end
end

function DjPreviewBeats(ms)
    return ms / 1000.0 * DEFAULT_BPM / 60.0
end

function DjFixtureProps(lights)
    local props = {}
    for _, light in ipairs(lights or {}) do
        if light.fixture == 'prop' and light.prop then props[#props + 1] = light.prop end
    end
    return props
end

function PlaceDjFixture(obj, base, heading, flip)
    local minV, maxV = GetModelDimensions(GetEntityModel(obj))
    local cx, cy = (minV.x + maxV.x) / 2, (minV.y + maxV.y) / 2
    SetEntityRotation(obj, 0.0, flip and 180.0 or 0.0, heading, 2, false)
    SetEntityCoordsNoOffset(obj, base.x, base.y, base.z, false, false, false)
    local anchor = GetOffsetFromEntityInWorldCoords(obj, cx, cy, minV.z)
    SetEntityCoordsNoOffset(obj, base.x * 2 - anchor.x, base.y * 2 - anchor.y, base.z * 2 - anchor.z, false, false, false)
    return GetOffsetFromEntityInWorldCoords(obj, cx, cy, maxV.z + 0.1)
end

function SpawnDjFixture(prop, ghost)
    local base = vector3(prop.x, prop.y, prop.z)
    local obj = Utils:SpawnProp(GetHashKey(prop.model), base, ghost and 200 or nil)
    if obj then PlaceDjFixture(obj, base, prop.h or 0.0, prop.flip == true) end
    return obj
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for id in pairs(fixtureObjs) do clearFixtures(id) end
end)

CreateThread(function()
    if not Config.DiscoLights.enabled then return end
    while true do
        local active = {}
        local coords = Utils:GetCoords()
        for id, station in pairs(DjStations) do
            local lights = station.settings and station.settings.lights
            local broadcastId = ('dj:%s'):format(id)
            if lights and #lights > 0 and IsBroadcastPlaying(broadcastId)
                and (IsBroadcastNear(broadcastId) or #(coords - station.coords) <= Config.DiscoLights.drawDistance) then
                active[#active + 1] = { id = broadcastId, lights = lights, center = station.coords }
            end
        end

        if #active == 0 then
            Wait(500)
        else
            local untilMs = GetGameTimer() + 500
            while GetGameTimer() < untilMs do
                for _, booth in ipairs(active) do DrawDjLights(booth.lights, booth.center, boothBeats(booth.id)) end
                Wait(0)
            end
        end
    end
end)

CreateThread(function()
    if not Config.DiscoLights.enabled then return end
    local range = Config.DiscoLights.fixtureDistance or 120.0
    while true do
        local coords = Utils:GetCoords()

        for id, entry in pairs(fixtureObjs) do
            local station = DjStations[id]
            if not station or station.settings ~= entry.settings or DjEditingStationId == id
                or #(coords - station.coords) > range + 20.0 then
                clearFixtures(id)
            end
        end

        for id, station in pairs(DjStations) do
            if not fixtureObjs[id] and DjEditingStationId ~= id and #(coords - station.coords) <= range then
                local props = DjFixtureProps(station.settings and station.settings.lights)
                if #props > 0 then
                    local objs = {}
                    for _, prop in ipairs(props) do objs[#objs + 1] = SpawnDjFixture(prop) end
                    fixtureObjs[id] = { settings = station.settings, objs = objs }
                end
            end
        end

        Wait(1000)
    end
end)
