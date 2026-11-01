-- Disco lights attached to DJ booths. Pure draw natives (spot lights, point lights, laser lines),
-- no props: every nearby client animates them locally while the booth is playing, so there's
-- nothing to network, stream or bump into. The creator uses DrawDjLights() for its live preview.

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

local function colorOf(light, t, offset)
    local rgb = colorsByName[light.color]
    if rgb then return rgb[1], rgb[2], rgb[3] end
    return hsv((t * 0.12 * (light.speed or 1.0) + (offset or 0.0)) % 1.0) -- 'Rainbow' / unknown
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

---Draws one light for the current frame.
---@param light table { type, x, y, z, color, speed }
---@param center vector3 the booth console (lights aim at it)
---@param t number seconds (animation clock)
---@param beat number 0..1 position inside the current beat
local function drawLight(light, center, t, beat)
    local p = vector3(light.x, light.y, light.z)
    local s = light.speed or 1.0
    local base = yawTowards(p, center)
    local seed = (light.x + light.y) % 7

    if light.type == 'spot' then
        -- Moving head: sweeps left/right and up/down over the floor.
        local yaw = base + math.sin(t * 0.8 * s + seed) * 55.0
        local pitch = -55.0 + math.sin(t * 1.25 * s + seed * 1.7) * 22.0
        local d = direction(yaw, pitch)
        local r, g, b = colorOf(light, t)
        DrawSpotLight(p.x, p.y, p.z, d.x, d.y, d.z, r, g, b, 32.0, 22.0, 0.0, 9.0, 1.0)
        glow(p, 0.14, r, g, b, 230)
    elseif light.type == 'laser' then
        -- Fan of beams sweeping across the room, blinking on the off-beat.
        if beat > 0.85 then return end
        local sweep = math.sin(t * 1.1 * s + seed) * 35.0
        local pitch = -10.0 + math.sin(t * 0.7 * s) * 8.0
        local beams = 7
        for i = 0, beams - 1 do
            local yaw = base + sweep + (i / (beams - 1) - 0.5) * 60.0
            local d = direction(yaw, pitch)
            local e = p + d * 22.0
            local r, g, b = colorOf(light, t, i * 0.05)
            DrawLine(p.x, p.y, p.z, e.x, e.y, e.z, r, g, b, 255)
        end
        local r, g, b = colorOf(light, t)
        glow(p, 0.1, r, g, b, 255)
    elseif light.type == 'ball' then
        -- Mirror ball: a slowly spinning ring of small spots scattering dots around the room.
        local r, g, b = colorOf(light, t)
        glow(p, 0.38, 235, 235, 245, 255)
        DrawLightWithRange(p.x, p.y, p.z, r, g, b, 3.5, 2.0)
        for i = 0, 5 do
            local yaw = t * 35.0 * s + i * 60.0
            local pitch = -20.0 - (i % 2) * 22.0
            local d = direction(yaw, pitch)
            local cr, cg, cb = colorOf(light, t, i * 0.16)
            DrawSpotLight(p.x, p.y, p.z, d.x, d.y, d.z, cr, cg, cb, 25.0, 14.0, 0.0, 3.5, 1.0)
        end
    elseif light.type == 'strobe' then
        -- Wash that pulses on every beat, with a hard flash at the start of it.
        local r, g, b = colorOf(light, t)
        local pulse = (1.0 - beat) ^ 3
        if beat < 0.08 then
            DrawLightWithRange(p.x, p.y, p.z, 255, 255, 255, 16.0, 14.0)
        end
        DrawLightWithRange(p.x, p.y, p.z, r, g, b, 14.0, 1.5 + 7.0 * pulse)
        glow(p, 0.12, r, g, b, math.floor(120 + 135 * pulse))
    end
end

---Draws a set of lights for this frame (also used for the creator's preview).
function DrawDjLights(lights, center, t, beat)
    for _, light in ipairs(lights) do drawLight(light, center, t, beat) end
end

local function beatPhase(ms)
    return (ms / 1000.0 * (Config.DiscoLights.bpm or 124) / 60.0) % 1.0
end
DjBeatPhase = beatPhase

-- Which booths are worth drawing is decided twice a second; drawing itself is every frame.
CreateThread(function()
    if not Config.DiscoLights.enabled then return end
    while true do
        local active = {}
        local myCoords = GetEntityCoords(PlayerPedId())
        for id, station in pairs(DjStations or {}) do
            local lights = station.settings and station.settings.lights
            if lights and #lights > 0 and IsBroadcastPlaying(('dj:%s'):format(id)) then
                local center = vector3(station.pos_x, station.pos_y, station.pos_z)
                if IsBroadcastNear(('dj:%s'):format(id)) or #(myCoords - center) <= Config.DiscoLights.drawDistance then
                    active[#active + 1] = { lights = lights, center = center }
                end
            end
        end

        if #active == 0 then
            Wait(500)
        else
            local untilMs = GetGameTimer() + 500
            while GetGameTimer() < untilMs do
                local ms = GetGameTimer()
                local t, beat = ms / 1000.0, beatPhase(ms)
                for _, a in ipairs(active) do DrawDjLights(a.lights, a.center, t, beat) end
                Wait(0)
            end
        end
    end
end)
