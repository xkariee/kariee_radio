local STEPS = { 'Console', 'Sound', 'Lights', 'Access', 'Save' }

local CTRL = {
    enter = 201,
    back = 73,
    cancel = 200,
    mode = 47,
    color = 26,
    place = 38,
    remove = 194,
    model = 244,
    up = 172,
    down = 173,
    left = 174,
    right = 175,
    pgUp = 10,
    pgDown = 11,
    shift = 21,
}

local SCROLL_UP = { 15, 241 }
local SCROLL_DOWN = { 14, 242 }

local DISABLED = {
    24, 25, 37, 14, 15, 16, 17, 140, 141, 142, 257, 263, 264, 81, 82, 99, 100,
    38, 44, 47, 26, 73, 244, 200, 194, 201, 191, 10, 11, 172, 173, 174, 175, 241, 242,
}

local BOX_EDGES = {
    { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 },
    { 5, 6 }, { 6, 7 }, { 7, 8 }, { 8, 5 },
    { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 },
}

local AIM_FLAGS = 1 + 16

local COLORS = {
    console = { 120, 200, 255 },
    area = { 120, 255, 170 },
    muffled = { 255, 190, 80 },
    radius = { 80, 200, 255 },
    highlight = { 255, 80, 80 },
    white = { 255, 255, 255 },
}

local CONSOLE_LABEL = { keep = 'Keep current', prop = 'New prop', entity = 'Existing object', zone = 'Interaction box' }
local CONSOLE_KIND = { prop = 'Prop', entity = 'Existing object', zone = 'Interaction box' }
local AUDIO_LABEL = { interior = 'Whole interior', radius = 'Radius', area = 'Custom area' }
local LIGHT_TYPES = { 'spot', 'laser', 'ball', 'strobe' }
local LIGHT_LABEL = { spot = 'Moving spotlight', laser = 'Laser fan', ball = 'Mirror ball', strobe = 'Strobe / wash' }
local AREA_WARNING = 'Add at least 3 corners, or switch to a radius.'

local session = nil
local muted = false

local function pressed(control)
    return not muted and IsDisabledControlJustPressed(0, control)
end

local function held(control)
    return not muted and IsDisabledControlPressed(0, control)
end

local function tune(coarse, precise)
    return IsControlPressed(0, CTRL.shift) and precise or coarse
end

local function scrolled()
    if muted then return 0 end
    for _, control in ipairs(SCROLL_UP) do
        if IsDisabledControlJustPressed(0, control) then return 1 end
    end
    for _, control in ipairs(SCROLL_DOWN) do
        if IsDisabledControlJustPressed(0, control) then return -1 end
    end
    return 0
end

local function axis(negative, positive)
    if held(positive) then return 1 end
    if held(negative) then return -1 end
    return 0
end

local function clamp(value, min, max)
    return math.min(max, math.max(min, value))
end

local function cycle(list, current)
    for i, value in ipairs(list) do
        if value == current then return list[i % #list + 1] end
    end
    return list[1]
end

local function copy(t)
    local out = {}
    for key, value in pairs(t) do out[key] = value end
    return out
end

local function copyList(list)
    local out = {}
    for i, item in ipairs(list or {}) do out[i] = copy(item) end
    return out
end

local function flashing(s)
    return s.flash ~= nil and GetGameTimer() < s.flash
end

local function addOption(hud, label, active)
    hud.options[#hud.options + 1] = { label = label, active = active }
end

local function addInfo(hud, label, value, swatch)
    hud.info[#hud.info + 1] = { label = label, value = value, swatch = swatch }
end

local function addKey(hud, label, ...)
    hud.keys[#hud.keys + 1] = { keys = { ... }, label = label }
end

local function rotationToDirection(rotation)
    local pitch, yaw = math.rad(rotation.x), math.rad(rotation.z)
    local flat = math.abs(math.cos(pitch))
    return vector3(-math.sin(yaw) * flat, math.cos(yaw) * flat, math.sin(pitch))
end

local function aimRay(distance, flags)
    local cam = GetGameplayCamCoord()
    local dir = rotationToDirection(GetGameplayCamRot(2))
    local dest = cam + dir * distance
    local handle = StartExpensiveSynchronousShapeTestLosProbe(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, flags, Utils.ped, 7)
    local _, hit, coords, normal, entity = GetShapeTestResult(handle)
    return hit == 1, hit == 1 and coords or dest, entity, dir, normal
end

local function line(a, b, color, alpha)
    DrawLine(a.x, a.y, a.z, b.x, b.y, b.z, color[1], color[2], color[3], alpha or 255)
end

local function quad(a, b, c, d, color, alpha)
    local r, g, bl = color[1], color[2], color[3]
    DrawPoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, r, g, bl, alpha)
    DrawPoly(c.x, c.y, c.z, b.x, b.y, b.z, a.x, a.y, a.z, r, g, bl, alpha)
    DrawPoly(a.x, a.y, a.z, c.x, c.y, c.z, d.x, d.y, d.z, r, g, bl, alpha)
    DrawPoly(d.x, d.y, d.z, c.x, c.y, c.z, a.x, a.y, a.z, r, g, bl, alpha)
end

local function sphere(p, size, color, alpha)
    Utils:DrawSphere(p, size, color[1], color[2], color[3], alpha)
end

local function drawEdges(corners, color)
    for _, edge in ipairs(BOX_EDGES) do line(corners[edge[1]], corners[edge[2]], color) end
end

local function drawZone(zone, color)
    local rad = math.rad(zone.rot)
    local cos, sin = math.cos(rad), math.sin(rad)
    local hx, hy, hz = zone.sx / 2, zone.sy / 2, zone.sz / 2
    local function corner(dx, dy, dz)
        return vector3(zone.x + dx * cos - dy * sin, zone.y + dx * sin + dy * cos, zone.z + dz)
    end
    local p = {
        corner(-hx, -hy, -hz), corner(hx, -hy, -hz), corner(hx, hy, -hz), corner(-hx, hy, -hz),
        corner(-hx, -hy, hz), corner(hx, -hy, hz), corner(hx, hy, hz), corner(-hx, hy, hz),
    }
    drawEdges(p, color)
    quad(p[5], p[6], p[7], p[8], color, 45)
    quad(p[1], p[2], p[6], p[5], color, 30)
    quad(p[3], p[4], p[8], p[7], color, 30)
end

local function drawEntityBox(entity, minV, maxV, color)
    local function corner(x, y, z)
        return GetOffsetFromEntityInWorldCoords(entity, x, y, z)
    end
    local p = {
        corner(minV.x, minV.y, minV.z), corner(maxV.x, minV.y, minV.z), corner(maxV.x, maxV.y, minV.z), corner(minV.x, maxV.y, minV.z),
        corner(minV.x, minV.y, maxV.z), corner(maxV.x, minV.y, maxV.z), corner(maxV.x, maxV.y, maxV.z), corner(minV.x, maxV.y, maxV.z),
    }
    drawEdges(p, color)
    quad(p[5], p[6], p[7], p[8], color, 50)
end

local function drawRing(center, radius, color)
    DrawMarker(1, center.x, center.y, center.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, radius * 2.0, radius * 2.0, 1.6, color[1], color[2], color[3], 55, false, false, 2, false, nil, nil, false)
end

local function describeSpot(pos)
    local interior = GetInteriorAtCoords(pos.x, pos.y, pos.z)
    local street = Utils:GetStreet(pos)
    local where = interior ~= 0 and ('Indoors · interior #%d'):format(interior) or 'Outdoors'
    return street and ('%s · %s'):format(where, street) or where, interior
end

local function interiorTaken(interior, ignoreId)
    if interior == 0 then return false end
    for id, station in pairs(DjStations) do
        if id ~= ignoreId and station.interiorId == interior then return true end
    end
    return false
end

local function deleteGhost(s, slot)
    local ghost = s.ghosts[slot]
    if ghost then Utils:DeleteProp(ghost.obj) end
    s.ghosts[slot] = nil
end

local function ensureGhost(s, slot, model, coords)
    local ghost = s.ghosts[slot]
    if ghost and ghost.model == model and DoesEntityExist(ghost.obj) then return ghost.obj end
    deleteGhost(s, slot)
    local obj = Utils:SpawnProp(model, coords, 170)
    if obj then s.ghosts[slot] = { obj = obj, model = model } end
    return obj
end

local function deletePreviews(s)
    for _, obj in ipairs(s.previews) do Utils:DeleteProp(obj) end
    s.previews = {}
end

local function syncPreviews(s)
    if s.previewRev == s.lightsRev then return end
    deletePreviews(s)
    for _, prop in ipairs(DjFixtureProps(s.lights)) do s.previews[#s.previews + 1] = SpawnDjFixture(prop, true) end
    s.previewRev = s.lightsRev
end

local function cleanup(s)
    deleteGhost(s, 'console')
    deleteGhost(s, 'light')
    deletePreviews(s)
    if s.picking then SetNuiFocus(false, false) end
end

local function showConsole(s, console)
    if console.mode ~= 'prop' then
        deleteGhost(s, 'console')
        return drawZone(console.zone, COLORS.console)
    end
    local ghost = ensureGhost(s, 'console', console.model, console.pos)
    if not ghost then return end
    SetEntityCoordsNoOffset(ghost, console.pos.x, console.pos.y, console.pos.z, false, false, false)
    SetEntityHeading(ghost, console.heading)
end

local function consoleModes(s)
    if s.console then return { 'keep', 'prop', 'entity', 'zone' } end
    return { 'prop', 'entity', 'zone' }
end

local function aimedObject()
    local hit, _, entity = aimRay(Config.Placement.maxDistance * 1.5, -1)
    if not hit or entity == 0 or GetEntityType(entity) ~= 3 then return nil end

    local model = GetEntityModel(entity)
    local minV, maxV = GetModelDimensions(model)
    local mid = (minV + maxV) / 2
    local center = GetOffsetFromEntityInWorldCoords(entity, mid.x, mid.y, mid.z)
    local size = maxV - minV
    local heading = GetEntityHeading(entity)
    local ok, name = pcall(GetEntityArchetypeName, entity)
    drawEntityBox(entity, minV, maxV, COLORS.console)

    return {
        mode = 'entity',
        pos = center,
        heading = heading,
        objectName = ok and name ~= '' and name or ('model %d'):format(model),
        zone = {
            x = center.x,
            y = center.y,
            z = center.z,
            sx = math.max(0.5, size.x + 0.3),
            sy = math.max(0.5, size.y + 0.3),
            sz = math.max(0.8, size.z + 0.3),
            rot = heading,
        },
    }
end

local function stepConsole(s, hud)
    if pressed(CTRL.mode) then s.mode = cycle(consoleModes(s), s.mode) end
    local spin = scrolled() * tune(15.0, 2.5)
    local candidate

    if s.mode == 'keep' then
        candidate = s.console
        showConsole(s, candidate)
    elseif s.mode == 'prop' then
        if pressed(CTRL.model) then s.modelIndex = s.modelIndex % #s.models + 1 end
        local model = s.models[s.modelIndex]
        local _, aim = aimRay(Config.Placement.maxDistance, AIM_FLAGS)
        s.heading = (s.heading + spin + axis(CTRL.right, CTRL.left) * Config.Placement.rotateStep) % 360
        s.lift = clamp(s.lift + axis(CTRL.down, CTRL.up) * Config.Placement.heightStep * tune(1.0, 0.25), -2.0, 3.0)
        candidate = { mode = 'prop', model = model.hash, modelName = model.name, pos = vector3(aim.x, aim.y, aim.z + s.lift), heading = s.heading }
        showConsole(s, candidate)
    elseif s.mode == 'entity' then
        deleteGhost(s, 'console')
        candidate = aimedObject()
    else
        local step = tune(0.02, 0.005)
        s.heading = (s.heading + spin) % 360
        s.box.sx = clamp(s.box.sx + axis(CTRL.left, CTRL.right) * step, 0.3, 12.0)
        s.box.sy = clamp(s.box.sy + axis(CTRL.down, CTRL.up) * step, 0.3, 12.0)
        s.box.sz = clamp(s.box.sz + axis(CTRL.pgDown, CTRL.pgUp) * step, 0.3, 8.0)
        local _, aim = aimRay(Config.Placement.maxDistance, AIM_FLAGS)
        local center = vector3(aim.x, aim.y, aim.z + s.box.sz / 2)
        candidate = {
            mode = 'zone',
            pos = center,
            heading = s.heading,
            zone = { x = center.x, y = center.y, z = center.z, sx = s.box.sx, sy = s.box.sy, sz = s.box.sz, rot = s.heading },
        }
        showConsole(s, candidate)
    end

    local location, interior = 'Aim somewhere', 0
    if candidate then location, interior = describeSpot(candidate.pos) end
    local blocked = interiorTaken(interior, s.station and s.station.id)

    hud.title, hud.subtitle = 'Place the console', 'Where people walk up to start the music.'
    for _, mode in ipairs(consoleModes(s)) do addOption(hud, CONSOLE_LABEL[mode], mode == s.mode) end
    addInfo(hud, 'Location', location)
    addKey(hud, s.mode == 'keep' and 'Keep this console' or 'Confirm console', 'Enter')
    addKey(hud, 'Switch mode', 'G')

    if s.mode == 'keep' then
        addInfo(hud, 'Console', CONSOLE_KIND[s.console.mode])
    elseif s.mode == 'prop' then
        addInfo(hud, 'Prop', ('%s (%d/%d)'):format(s.models[s.modelIndex].name, s.modelIndex, #s.models))
        addInfo(hud, 'Rotation · height', ('%d° · %+.2f m'):format(math.floor(s.heading), s.lift))
        addKey(hud, 'Change prop', 'M')
        addKey(hud, 'Rotate', 'Scroll')
        addKey(hud, 'Raise / lower', '↑', '↓')
        addKey(hud, 'Fine adjust', 'Shift')
    elseif s.mode == 'entity' then
        addInfo(hud, 'Object', candidate and candidate.objectName or 'none')
        addInfo(hud, 'Players use', 'ox_target on that object')
    else
        addInfo(hud, 'Box size', ('%.1f × %.1f × %.1f m'):format(s.box.sx, s.box.sy, s.box.sz))
        addKey(hud, 'Rotate', 'Scroll')
        addKey(hud, 'Width', '←', '→')
        addKey(hud, 'Depth', '↑', '↓')
        addKey(hud, 'Height', 'PgUp', 'PgDn')
        addKey(hud, 'Fine adjust', 'Shift')
    end

    if blocked then
        hud.warning = Config.Messages.dj_interior_occupied
    elseif s.mode == 'entity' and not candidate then
        hud.warning = 'Aim at an object (a desk, speaker, DJ table…) to use it as the console.'
    end

    if candidate and not blocked and pressed(CTRL.enter) then
        local moved = not s.console or #(s.console.pos - candidate.pos) > 0.05
        s.console = candidate
        s.mode = 'keep'
        if moved and s.audio and s.audio.type == 'interior' then s.audio = nil end
        return 2
    end
end

local function initAudio(s)
    local pos = s.console.pos
    s.interiorId = GetInteriorAtCoords(pos.x, pos.y, pos.z)

    if not s.audio then
        local existing = s.station and s.station.settings and s.station.settings.audio
        if existing then
            s.audio = copy(existing)
            s.audio.points = copyList(existing.points)
            if existing.maxZ and existing.minZ then s.areaHeight = existing.maxZ - existing.minZ end
        else
            s.audio = {
                type = s.interiorId ~= 0 and 'interior' or 'radius',
                range = Config.DjOutdoorRange,
                muffled = Config.DjSound.defaultMuffled,
                fade = Config.DjSound.defaultAreaFade,
                points = {},
            }
        end
    end

    if s.audio.type == 'interior' and s.interiorId == 0 then s.audio.type = 'radius' end
end

local function audioTypes(s)
    if s.interiorId ~= 0 then return { 'interior', 'radius', 'area' } end
    return { 'radius', 'area' }
end

local function areaBounds(s)
    local minZ = s.console.pos.z
    for _, point in ipairs(s.audio.points) do
        if point.z and point.z < minZ then minZ = point.z end
    end
    minZ = minZ - 1.5
    return minZ, minZ + s.areaHeight
end

local function drawArea(s, aim)
    local points = s.audio.points
    local count = #points
    local minZ, maxZ = areaBounds(s)

    for i, point in ipairs(points) do
        local bottom, top = vector3(point.x, point.y, minZ), vector3(point.x, point.y, maxZ)
        line(bottom, top, COLORS.area)
        sphere(vector3(point.x, point.y, (point.z or minZ) + 0.2), 0.25, COLORS.area)

        local nextPoint = i < count and points[i + 1] or (count >= 3 and points[1] or nil)
        if nextPoint then
            local nextBottom, nextTop = vector3(nextPoint.x, nextPoint.y, minZ), vector3(nextPoint.x, nextPoint.y, maxZ)
            line(bottom, nextBottom, COLORS.area)
            line(top, nextTop, COLORS.area)
            quad(bottom, nextBottom, nextTop, top, COLORS.area, 35)
        end
    end

    if aim then
        sphere(aim, 0.3, COLORS.white)
        if count > 0 then line(vector3(points[count].x, points[count].y, aim.z), aim, COLORS.white, 160) end
    end
end

local function stepSound(s, hud)
    local audio = s.audio
    if pressed(CTRL.mode) then audio.type = cycle(audioTypes(s), audio.type) end
    local spin = scrolled()
    local console = s.console.pos
    showConsole(s, s.console)

    hud.title, hud.subtitle = 'Sound area', 'Who hears the music, and how loud.'
    for _, kind in ipairs(audioTypes(s)) do addOption(hud, AUDIO_LABEL[kind], kind == audio.type) end
    addInfo(hud, 'Console', (describeSpot(console)))
    if audio.type == 'area' then
        addKey(hud, 'Add corner where you aim', 'E')
        addKey(hud, 'Remove last corner', 'Backspace')
    end
    addKey(hud, 'Next: lights', 'Enter')
    addKey(hud, 'Switch sound mode', 'G')

    if audio.type == 'interior' then
        audio.muffled = clamp(audio.muffled + axis(CTRL.left, CTRL.right) * tune(0.25, 0.05) + spin * tune(5, 1), 0.0, Config.DjSound.maxMuffled)
        drawRing(console, math.max(0.5, audio.muffled), COLORS.muffled)
        addInfo(hud, 'Full volume in', ('Whole interior #%d'):format(s.interiorId))
        addInfo(hud, 'Muffled outside', audio.muffled < 0.5 and 'Not heard outside' or ('up to %d m'):format(math.floor(audio.muffled + 0.5)))
        addKey(hud, 'Muffled range outside', '←', '→')
        addKey(hud, '±5 m', 'Scroll')
    elseif audio.type == 'radius' then
        audio.range = clamp(audio.range + axis(CTRL.left, CTRL.right) * tune(0.5, 0.1) + spin * tune(10, 1), Config.DjSound.minRadius, Config.DjSound.maxRadius)
        drawRing(console, audio.range, COLORS.radius)
        addInfo(hud, 'Heard up to', ('%d m, fading with distance'):format(math.floor(audio.range + 0.5)))
        addKey(hud, 'Range', '←', '→')
        addKey(hud, '±10 m', 'Scroll')
    else
        local _, aim = aimRay(Config.Placement.farDistance, AIM_FLAGS)
        if pressed(CTRL.place) and #audio.points < Config.DjSound.maxAreaPoints then
            audio.points[#audio.points + 1] = { x = aim.x, y = aim.y, z = aim.z }
        end
        if pressed(CTRL.remove) and #audio.points > 0 then table.remove(audio.points) end
        s.areaHeight = clamp(s.areaHeight + axis(CTRL.pgDown, CTRL.pgUp) * tune(0.1, 0.02), 2.0, 60.0)
        audio.fade = clamp(audio.fade + axis(CTRL.left, CTRL.right) * tune(0.25, 0.05), 0.0, 100.0)
        drawArea(s, aim)
        addInfo(hud, 'Corners', ('%d / %d%s'):format(#audio.points, Config.DjSound.maxAreaPoints, #audio.points < 3 and ' · need at least 3' or ''))
        addInfo(hud, 'Area height', ('%.1f m'):format(s.areaHeight))
        addInfo(hud, 'Fades out over', ('%d m outside'):format(math.floor(audio.fade + 0.5)))
        addKey(hud, 'Area height', 'PgUp', 'PgDn')
        addKey(hud, 'Fade distance', '←', '→')
    end
    addKey(hud, 'Fine adjust', 'Shift')

    if pressed(CTRL.enter) then
        if audio.type ~= 'area' or #audio.points >= 3 then return 3 end
        s.flash = GetGameTimer() + 2500
    end
    if flashing(s) then hud.warning = AREA_WARNING end
end

local function aimFixture(s, fixture, hit, aim, normal, console)
    local ghost = ensureGhost(s, 'light', fixture.hash, aim)
    if not ghost then return nil end

    local flip = hit and normal.z < -0.5
    local base = aim
    if hit and math.abs(normal.z) <= 0.5 then
        local minV, maxV = GetModelDimensions(fixture.hash)
        base = aim + normal * ((maxV.y - minV.y) / 2 + 0.05)
    end
    local heading = (Utils:HeadingTo(base, console) + s.fixtureSpin) % 360

    return {
        lamp = PlaceDjFixture(ghost, base, heading, flip),
        prop = { model = fixture.name, x = base.x, y = base.y, z = base.z, h = heading, flip = flip },
    }
end

local function stepLights(s, hud)
    local console = s.console.pos
    showConsole(s, s.console)
    hud.title, hud.subtitle = 'Disco lights', 'Optional. They come on whenever the booth is playing.'

    if not Config.DiscoLights.enabled then
        addInfo(hud, 'Disco lights', 'Turned off on this server')
        addKey(hud, 'Next: access', 'Enter')
        if pressed(CTRL.enter) then return 4 end
        return
    end

    local colors = Config.DiscoLights.colors
    local maxLights = Config.DiscoLights.maxPerBooth
    if pressed(CTRL.mode) then s.lightType = s.lightType % #LIGHT_TYPES + 1 end
    if pressed(CTRL.color) then s.colorIndex = s.colorIndex % #colors + 1 end
    if pressed(CTRL.model) then s.fixtureIndex = s.fixtureIndex % #s.fixtures + 1 end
    if pressed(CTRL.right) then s.speed = clamp(s.speed + 0.25, 0.25, 3.0) end
    if pressed(CTRL.left) then s.speed = clamp(s.speed - 0.25, 0.25, 3.0) end

    local fixture = s.fixtures[s.fixtureIndex]
    local color = colors[s.colorIndex]
    local hit, aim, _, dir, normal = aimRay(Config.Placement.farDistance, AIM_FLAGS)
    local spot = hit and (aim - dir * 0.3) or aim
    local pending = { type = LIGHT_TYPES[s.lightType], x = spot.x, y = spot.y, z = spot.z, color = color.name, speed = s.speed, fixture = fixture.kind }

    if fixture.kind == 'prop' then
        s.fixtureSpin = (s.fixtureSpin + scrolled() * tune(15.0, 2.5)) % 360
        local placed = aimFixture(s, fixture, hit, aim, normal, console)
        if placed then
            spot = placed.lamp
            pending.x, pending.y, pending.z, pending.prop = spot.x, spot.y, spot.z, placed.prop
        else
            pending.fixture = 'glow'
        end
    else
        deleteGhost(s, 'light')
    end

    local nearest, nearestDist = nil, 3.0
    for i, light in ipairs(s.lights) do
        local dist = #(vector3(light.x, light.y, light.z) - spot)
        if dist < nearestDist then nearest, nearestDist = i, dist end
    end

    local beats = DjPreviewBeats(GetGameTimer())
    DrawDjLights(s.lights, console, beats)
    if #s.lights < maxLights then DrawDjLights({ pending }, console, beats) end
    for i, light in ipairs(s.lights) do
        local p = vector3(light.x, light.y, light.z)
        if i == nearest then sphere(p, 0.45, COLORS.highlight, 160) end
        line(p, console, COLORS.white, 40)
    end
    if fixture.kind ~= 'prop' then sphere(spot, 0.18, COLORS.white) end

    if pressed(CTRL.place) then
        if #s.lights < maxLights then
            s.lights[#s.lights + 1] = pending
            s.lightsRev = s.lightsRev + 1
        else
            s.flash = GetGameTimer() + 2000
        end
    end
    if pressed(CTRL.remove) and #s.lights > 0 then
        table.remove(s.lights, nearest or #s.lights)
        s.lightsRev = s.lightsRev + 1
    end

    for i, kind in ipairs(LIGHT_TYPES) do addOption(hud, LIGHT_LABEL[kind], i == s.lightType) end
    addInfo(hud, 'Colour', color.name, color.rgb or 'rainbow')
    addInfo(hud, 'Speed', ('%.2f×'):format(s.speed))
    addInfo(hud, 'Fixture', ('%s (%d/%d)'):format(fixture.label, s.fixtureIndex, #s.fixtures))
    if fixture.kind == 'prop' then
        addInfo(hud, 'Mounted', pending.prop and pending.prop.flip and 'Hanging from the ceiling' or 'Standing')
    end
    addInfo(hud, 'Lights placed', ('%d / %d'):format(#s.lights, maxLights))

    addKey(hud, 'Place light where you aim', 'E')
    addKey(hud, nearest and 'Remove highlighted light' or 'Remove last light', 'Backspace')
    addKey(hud, 'Next: access', 'Enter')
    addKey(hud, 'Light type', 'G')
    addKey(hud, 'Colour', 'C')
    addKey(hud, 'Fixture: dot, nothing or a prop', 'M')
    if fixture.kind == 'prop' then addKey(hud, 'Rotate fixture', 'Scroll') end
    addKey(hud, 'Speed', '←', '→')
    if flashing(s) then hud.warning = ('That’s the maximum of %d lights.'):format(maxLights) end

    if pressed(CTRL.enter) then return 4 end
end

local function jobLabel(s, name)
    local job = s.jobs and s.jobs.byName[name]
    return job and job.label or name
end

local function gradeLabel(s, rule)
    local job = s.jobs and s.jobs.byName[rule.job]
    local grades = job and job.grades or {}
    if rule.grade <= (grades[1] and grades[1].grade or 0) then return 'Any grade' end
    for _, grade in ipairs(grades) do
        if grade.grade == rule.grade then return ('%s and up'):format(grade.label) end
    end
    return ('Grade %d and up'):format(rule.grade)
end

local function accessSummary(s)
    if #s.access == 0 then return 'Everyone' end
    local names = {}
    for i, rule in ipairs(s.access) do
        if i > 3 then
            names[#names + 1] = ('+%d more'):format(#s.access - 3)
            break
        end
        names[i] = jobLabel(s, rule.job)
    end
    return table.concat(names, ', ')
end

local function openAccessPicker(s)
    s.picking = true
    SendNUIMessage({ action = 'creatorAccess', data = { jobs = s.jobs.list, access = s.access } })
    SetNuiFocus(true, true)
end

local function stepAccess(s, hud)
    showConsole(s, s.console)
    DrawDjLights(s.lights, s.console.pos, DjPreviewBeats(GetGameTimer()))

    hud.title, hud.subtitle = 'Who can use it', 'Only the jobs you pick can play music here. Pick none and everyone can.'
    addOption(hud, 'Everyone', #s.access == 0)
    addOption(hud, 'Selected jobs', #s.access > 0)
    if #s.access == 0 then addInfo(hud, 'Console', 'Open to every player') end
    for i, rule in ipairs(s.access) do
        if i > 6 then
            local more = #s.access - 6
            addInfo(hud, 'And', ('%d more job%s'):format(more, more == 1 and '' or 's'))
            break
        end
        addInfo(hud, jobLabel(s, rule.job), gradeLabel(s, rule))
    end

    addKey(hud, 'Next: review', 'Enter')
    addKey(hud, s.picking and 'Picking jobs…' or 'Choose jobs & grades', 'E')
    if #s.access > 0 then addKey(hud, 'Allow everyone', 'Backspace') end
    if not s.jobs then hud.warning = 'Loading jobs…' end

    if pressed(CTRL.place) and s.jobs then openAccessPicker(s) end
    if pressed(CTRL.remove) then s.access = {} end
    if pressed(CTRL.enter) then return 5 end
end

local function soundSummary(s)
    local audio = s.audio
    if audio.type == 'interior' then
        if audio.muffled < 0.5 then return ('Interior #%d only'):format(s.interiorId) end
        return ('Interior #%d · muffled up to %d m outside'):format(s.interiorId, math.floor(audio.muffled + 0.5))
    end
    if audio.type == 'area' then
        return ('Custom area · %d corners · fades over %d m'):format(#audio.points, math.floor(audio.fade + 0.5))
    end
    return ('Radius %d m'):format(math.floor(audio.range + 0.5))
end

local function consoleSummary(console)
    local kind = CONSOLE_KIND[console.mode]
    local name = console.mode == 'prop' and console.modelName or console.mode == 'entity' and console.objectName
    return name and ('%s · %s'):format(kind, name) or kind
end

local function stepSave(s, hud)
    local console = s.console.pos
    local audio = s.audio
    showConsole(s, s.console)
    DrawDjLights(s.lights, console, DjPreviewBeats(GetGameTimer()))
    if audio.type == 'radius' then
        drawRing(console, audio.range, COLORS.radius)
    elseif audio.type == 'interior' and audio.muffled > 0.5 then
        drawRing(console, audio.muffled, COLORS.muffled)
    elseif audio.type == 'area' then
        drawArea(s)
    end

    hud.title = s.station and 'Save changes' or 'Review & save'
    hud.subtitle = s.station and ('Updating “%s” for everyone.'):format(s.station.label or 'DJ booth') or 'Everyone will see the booth as soon as you save.'
    addInfo(hud, 'Console', consoleSummary(s.console))
    addInfo(hud, 'Location', (describeSpot(console)))
    addInfo(hud, 'Sound', soundSummary(s))
    addInfo(hud, 'Disco lights', #s.lights == 0 and 'None' or ('%d light%s'):format(#s.lights, #s.lights == 1 and '' or 's'))
    addInfo(hud, 'Who can use it', accessSummary(s))
    addKey(hud, s.station and 'Save changes' or 'Create booth', 'Enter')

    if pressed(CTRL.enter) then return 'save' end
end

local STEP_HANDLERS = { stepConsole, stepSound, stepLights, stepAccess, stepSave }

local function buildSettings(s)
    local console, current = s.console, s.audio
    local audio = { type = current.type, range = current.range, muffled = current.muffled, fade = current.fade }
    if current.type == 'area' then
        audio.points = {}
        for i, point in ipairs(current.points) do audio.points[i] = { x = point.x, y = point.y } end
        audio.minZ, audio.maxZ = areaBounds(s)
    end
    return {
        mode = console.mode,
        model = console.mode == 'prop' and console.model or nil,
        zone = console.mode ~= 'prop' and console.zone or nil,
        audio = audio,
        lights = s.lights,
        access = s.access,
    }
end

local function save(s)
    local console = s.console
    local pos = { x = console.pos.x, y = console.pos.y, z = console.pos.z }
    local settings = buildSettings(s)

    if s.station then
        local ok, err = Utils:Callback('dj:update', s.station.id, pos, console.heading, settings)
        if ok then return Utils:Notify('creator_updated') end
        return Utils:Notify(err == 'no_permission' and 'no_permission' or 'creator_update_failed')
    end

    local street = Utils:GetStreet(console.pos)
    local label = street and ('DJ booth · %s'):format(street) or 'DJ booth'
    local station, err = Utils:Callback('dj:create', pos, console.heading, label, settings)
    if station then
        Utils:Notify('creator_saved')
        return OpenDjStation(station.id)
    end
    if err ~= 'banned' then Utils:Notify(err == 'no_permission' and 'no_permission' or 'creator_create_failed') end
end

local function sendHud(s, hud, force)
    local encoded = json.encode(hud)
    local now = GetGameTimer()
    if not force and (encoded == s.hudSent or now - s.hudAt < 80) then return end
    s.hudSent, s.hudAt = encoded, now
    SendNUIMessage({ action = 'creator', data = hud })
end

local function run(s)
    local result
    while not result do
        Wait(0)
        for _, control in ipairs(DISABLED) do DisableControlAction(0, control, true) end
        muted = s.picking or GetGameTimer() < (s.unmuteAt or 0)

        local hud = {
            editing = s.station ~= nil,
            label = s.station and s.station.label or nil,
            step = s.step,
            steps = STEPS,
            options = {},
            info = {},
            keys = {},
        }

        syncPreviews(s)
        if s.step ~= 3 then deleteGhost(s, 'light') end
        local nextStep = STEP_HANDLERS[s.step](s, hud)

        if s.step > 1 then addKey(hud, 'Back', 'X') end
        addKey(hud, 'Cancel', 'Esc')
        sendHud(s, hud, nextStep ~= nil)

        if nextStep == 'save' then
            result = 'save'
        elseif nextStep then
            s.step, s.flash = nextStep, nil
            if s.step == 2 then initAudio(s) end
        elseif pressed(CTRL.back) and s.step > 1 then
            s.step, s.flash = s.step - 1, nil
        elseif pressed(CTRL.cancel) then
            result = 'cancel'
        end
    end

    cleanup(s)
    DjEditingStationId = nil
    SendNUIMessage({ action = 'creatorAccess', data = false })
    SendNUIMessage({ action = 'creator', data = false })
    session = nil
    muted = false

    if result == 'save' then
        save(s)
    else
        Utils:Notify('placement_cancelled')
    end
end

local function streamable(names)
    local models = {}
    for _, name in ipairs(names or {}) do
        local hash = GetHashKey(name)
        if IsModelInCdimage(hash) then models[#models + 1] = { name = name, hash = hash } end
    end
    return models
end

local function consoleFromStation(station)
    local settings = station.settings or {}
    return {
        mode = settings.mode or 'prop',
        model = settings.model or Config.DjMixerModel,
        zone = settings.zone,
        pos = station.coords,
        heading = station.heading or 0.0,
    }
end

local function fetchJobs(s)
    local list = Utils:Callback('dj:getJobs') or {}
    local byName = {}
    for _, job in ipairs(list) do byName[job.name] = job end
    s.jobs = { list = list, byName = byName }
end

RegisterNUICallback('creatorAccess', function(data, cb)
    cb({})
    local s = session
    if not s or not s.picking then return end
    SetNuiFocus(false, false)
    s.picking = false
    s.unmuteAt = GetGameTimer() + 300

    if type(data) ~= 'table' or type(data.access) ~= 'table' then return end
    local access, seen = {}, {}
    for _, rule in ipairs(data.access) do
        local job = type(rule) == 'table' and s.jobs.byName[rule.job]
        if job and not seen[job.name] then
            seen[job.name] = true
            access[#access + 1] = { job = job.name, grade = math.floor(tonumber(rule.grade) or 0) }
        end
    end
    s.access = access
end)

function StartDjCreator(station)
    if session then return end
    if not Utils:IsReady() then return Utils:Notify('not_ready') end
    if IsRadioOpen() then CloseRadio() end

    local models = streamable(Config.DjModels)
    if #models == 0 then models[1] = { name = 'default', hash = Config.DjMixerModel } end

    local fixtures = { { kind = 'glow', label = 'Glowing dot' }, { kind = 'none', label = 'Nothing, beam only' } }
    for _, model in ipairs(streamable(Config.DiscoLights.fixtures)) do
        fixtures[#fixtures + 1] = { kind = 'prop', name = model.name, hash = model.hash, label = model.name }
    end

    local settings = station and station.settings or {}
    local s = {
        station = station,
        step = 1,
        mode = station and 'keep' or 'prop',
        console = station and consoleFromStation(station) or nil,
        models = models,
        modelIndex = 1,
        heading = GetEntityHeading(Utils.ped),
        lift = 0.0,
        box = { sx = 1.6, sy = 1.0, sz = 1.3 },
        areaHeight = Config.DjSound.defaultAreaHeight,
        audio = nil,
        lights = copyList(settings.lights),
        lightType = 1,
        colorIndex = 1,
        speed = 1.0,
        fixtures = fixtures,
        fixtureIndex = 1,
        fixtureSpin = 0.0,
        lightsRev = 0,
        previewRev = -1,
        previews = {},
        ghosts = {},
        access = copyList(settings.access),
        jobs = nil,
        picking = false,
        hudSent = '',
        hudAt = 0,
    }

    session = s
    DjEditingStationId = station and station.id or nil
    CreateThread(function() fetchJobs(s) end)
    CreateThread(function() run(s) end)
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and session then cleanup(session) end
end)
