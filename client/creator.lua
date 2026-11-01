-- DJ booth creator: /createdj (new booth), /editdj or the admin panel (existing booth).
-- Four steps - Console, Sound, Lights, Save - previewed live in the world, with the current
-- step's keys shown in the NUI (web/src/components/CreatorHud.vue).

local STEPS = { 'Console', 'Sound', 'Lights', 'Save' }

local CTRL = {
    enter = 201,   -- Enter
    back = 73,     -- X
    cancel = 200,  -- Esc
    mode = 47,     -- G
    color = 26,    -- C
    place = 38,    -- E
    remove = 194,  -- Backspace
    model = 244,   -- M
    up = 172, down = 173, left = 174, right = 175,
    pgUp = 10, pgDown = 11,
    shift = 21,
}
local SCROLL_UP, SCROLL_DOWN = { 15, 241 }, { 14, 242 }

-- Everything the creator uses, plus combat/weapon-wheel so nothing fires while placing.
local DISABLED = {
    24, 25, 37, 14, 15, 16, 17, 140, 141, 142, 257, 263, 264, 81, 82, 99, 100,
    38, 44, 47, 26, 73, 244, 200, 194, 201, 191, 10, 11, 172, 173, 174, 175, 241, 242,
}

local CONSOLE_LABEL = { keep = 'Keep current', prop = 'New prop', entity = 'Existing object', zone = 'Interaction box' }
local CONSOLE_KIND = { prop = 'Prop', entity = 'Existing object', zone = 'Interaction box' }
local AUDIO_LABEL = { interior = 'Whole interior', radius = 'Radius', area = 'Custom area' }
local LIGHT_TYPES = { 'spot', 'laser', 'ball', 'strobe' }
local LIGHT_LABEL = { spot = 'Moving spotlight', laser = 'Laser fan', ball = 'Mirror ball', strobe = 'Strobe / wash' }

local session = nil

-- ─── input / geometry helpers ──────────────────────────────────────────────

local function pressed(c) return IsDisabledControlJustPressed(0, c) end
local function held(c) return IsDisabledControlPressed(0, c) end
local function fine() return IsControlPressed(0, CTRL.shift) end

local function scrolled()
    for _, c in ipairs(SCROLL_UP) do if IsDisabledControlJustPressed(0, c) then return 1 end end
    for _, c in ipairs(SCROLL_DOWN) do if IsDisabledControlJustPressed(0, c) then return -1 end end
    return 0
end

-- -1 / 0 / +1 while a left/right (or other) pair is held
local function axis(neg, pos)
    if held(pos) then return 1 end
    if held(neg) then return -1 end
    return 0
end

local function clamp(v, min, max) return math.min(max, math.max(min, v)) end

local function rotationToDirection(rotation)
    local rad = math.pi / 180
    local x, z = rotation.x * rad, rotation.z * rad
    return vector3(-math.sin(z) * math.abs(math.cos(x)), math.cos(z) * math.abs(math.cos(x)), math.sin(x))
end

---@return boolean hit, vector3 coords, number entity, vector3 dir
local function aimRay(distance, flags)
    local cam = GetGameplayCamCoord()
    local dir = rotationToDirection(GetGameplayCamRot(2))
    local dest = cam + dir * distance
    local handle = StartExpensiveSynchronousShapeTestLosProbe(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, flags, PlayerPedId(), 7)
    local _, hit, coords, _, entity = GetShapeTestResult(handle)
    return hit == 1, hit == 1 and coords or dest, entity, dir
end

local function line(a, b, r, g, bl, al)
    DrawLine(a.x, a.y, a.z, b.x, b.y, b.z, r, g, bl, al or 255)
end

local function quad(a, b, c, d, r, g, bl, al)
    -- both windings so the face shows from either side
    DrawPoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, r, g, bl, al)
    DrawPoly(c.x, c.y, c.z, b.x, b.y, b.z, a.x, a.y, a.z, r, g, bl, al)
    DrawPoly(a.x, a.y, a.z, c.x, c.y, c.z, d.x, d.y, d.z, r, g, bl, al)
    DrawPoly(d.x, d.y, d.z, c.x, c.y, c.z, a.x, a.y, a.z, r, g, bl, al)
end

---Rotated box (heading-only rotation, same convention as ox_target box zones).
local function drawBox(center, sx, sy, sz, rot, r, g, b)
    local rad = math.rad(rot)
    local c, s = math.cos(rad), math.sin(rad)
    local function corner(dx, dy, dz)
        return vector3(center.x + dx * c - dy * s, center.y + dx * s + dy * c, center.z + dz)
    end
    local hx, hy, hz = sx / 2, sy / 2, sz / 2
    local p = {
        corner(-hx, -hy, -hz), corner(hx, -hy, -hz), corner(hx, hy, -hz), corner(-hx, hy, -hz),
        corner(-hx, -hy, hz), corner(hx, -hy, hz), corner(hx, hy, hz), corner(-hx, hy, hz),
    }
    for _, e in ipairs({ { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 }, { 5, 6 }, { 6, 7 }, { 7, 8 }, { 8, 5 }, { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 } }) do
        line(p[e[1]], p[e[2]], r, g, b, 255)
    end
    quad(p[5], p[6], p[7], p[8], r, g, b, 45)
    quad(p[1], p[2], p[6], p[5], r, g, b, 30)
    quad(p[3], p[4], p[8], p[7], r, g, b, 30)
end

---Outline of an existing object using its model's bounds (handles any rotation).
local function drawEntityBox(entity, minV, maxV, r, g, b)
    local function corner(x, y, z) return GetOffsetFromEntityInWorldCoords(entity, x, y, z) end
    local p = {
        corner(minV.x, minV.y, minV.z), corner(maxV.x, minV.y, minV.z), corner(maxV.x, maxV.y, minV.z), corner(minV.x, maxV.y, minV.z),
        corner(minV.x, minV.y, maxV.z), corner(maxV.x, minV.y, maxV.z), corner(maxV.x, maxV.y, maxV.z), corner(minV.x, maxV.y, maxV.z),
    }
    for _, e in ipairs({ { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 }, { 5, 6 }, { 6, 7 }, { 7, 8 }, { 8, 5 }, { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 } }) do
        line(p[e[1]], p[e[2]], r, g, b, 255)
    end
    quad(p[5], p[6], p[7], p[8], r, g, b, 50)
end

local function drawRing(center, radius, r, g, b)
    DrawMarker(1, center.x, center.y, center.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, radius * 2.0, radius * 2.0, 1.6, r, g, b, 55, false, false, 2, false, nil, nil, false)
end

local function dot(p, size, r, g, b, a)
    DrawMarker(28, p.x, p.y, p.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size, size, r, g, b, a or 220, false, false, 2, false, nil, nil, false)
end

local function streetAt(p)
    local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(p.x, p.y, p.z))
    return street ~= '' and street or nil
end

local function describeSpot(pos)
    local interior = GetInteriorAtCoords(pos.x, pos.y, pos.z)
    local street = streetAt(pos)
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

local function copyList(list)
    local out = {}
    for i, v in ipairs(list or {}) do
        local item = {}
        for k, val in pairs(v) do item[k] = val end
        out[i] = item
    end
    return out
end

-- ─── console preview (ghost prop) ──────────────────────────────────────────

local function deleteGhost(s)
    if s.ghost and DoesEntityExist(s.ghost) then DeleteObject(s.ghost) end
    s.ghost, s.ghostModel = nil, nil
end

local function ensureGhost(s, model)
    if s.ghost and s.ghostModel == model and DoesEntityExist(s.ghost) then return s.ghost end
    deleteGhost(s)
    if not LoadModel(model) then return nil end
    local p = GetEntityCoords(PlayerPedId())
    s.ghost = CreateObject(model, p.x, p.y, p.z, false, false, false)
    s.ghostModel = model
    SetEntityAlpha(s.ghost, 170, false)
    SetEntityCollision(s.ghost, false, false)
    FreezeEntityPosition(s.ghost, true)
    SetModelAsNoLongerNeeded(model)
    return s.ghost
end

local function showConsole(s, console)
    if console.mode == 'prop' then
        local ghost = ensureGhost(s, console.model)
        if ghost then
            SetEntityCoordsNoOffset(ghost, console.pos.x, console.pos.y, console.pos.z, false, false, false)
            SetEntityHeading(ghost, console.heading)
        end
    else
        deleteGhost(s)
        local z = console.zone
        drawBox(vector3(z.x, z.y, z.z), z.sx, z.sy, z.sz, z.rot, 120, 200, 255)
    end
end

-- ─── step 1: console ───────────────────────────────────────────────────────

local function consoleModes(s)
    local modes = {}
    if s.console then modes[#modes + 1] = 'keep' end
    modes[#modes + 1] = 'prop'
    modes[#modes + 1] = 'entity'
    modes[#modes + 1] = 'zone'
    return modes
end

local function cycle(list, current)
    for i, v in ipairs(list) do
        if v == current then return list[i % #list + 1] end
    end
    return list[1]
end

local function stepConsole(s, hud)
    if pressed(CTRL.mode) then s.mode = cycle(consoleModes(s), s.mode) end
    local candidate, warning
    local spin = scrolled()
    local step = fine() and 2.5 or 15.0

    if s.mode == 'keep' then
        candidate = s.console
        showConsole(s, candidate)
    elseif s.mode == 'prop' then
        if pressed(CTRL.model) then s.modelIndex = s.modelIndex % #s.models + 1 end
        local model = s.models[s.modelIndex]
        local _, aim = aimRay(Config.Placement.maxDistance, 1 + 16)
        s.heading = (s.heading + spin * step + axis(CTRL.right, CTRL.left) * Config.Placement.rotateStep) % 360
        s.lift = clamp(s.lift + axis(CTRL.down, CTRL.up) * Config.Placement.heightStep * (fine() and 0.25 or 1), -2.0, 3.0)
        candidate = { mode = 'prop', model = model.hash, modelName = model.name, pos = vector3(aim.x, aim.y, aim.z + s.lift), heading = s.heading }
        showConsole(s, candidate)
    elseif s.mode == 'entity' then
        deleteGhost(s)
        local hit, _, entity = aimRay(Config.Placement.maxDistance * 1.5, -1)
        if hit and entity ~= 0 and GetEntityType(entity) == 3 then
            local model = GetEntityModel(entity)
            local minV, maxV = GetModelDimensions(model)
            local mid = (minV + maxV) / 2
            local center = GetOffsetFromEntityInWorldCoords(entity, mid.x, mid.y, mid.z)
            local size = maxV - minV
            local heading = GetEntityHeading(entity)
            drawEntityBox(entity, minV, maxV, 120, 200, 255)
            local ok, name = pcall(GetEntityArchetypeName, entity)
            candidate = {
                mode = 'entity',
                pos = center,
                heading = heading,
                objectName = ok and name ~= '' and name or ('model %d'):format(model),
                zone = {
                    x = center.x, y = center.y, z = center.z,
                    sx = math.max(0.5, size.x + 0.3), sy = math.max(0.5, size.y + 0.3), sz = math.max(0.8, size.z + 0.3),
                    rot = heading,
                },
            }
        else
            warning = 'Aim at an object (a desk, speaker, DJ table…) to use it as the console.'
        end
    elseif s.mode == 'zone' then
        deleteGhost(s)
        local f = fine() and 0.005 or 0.02
        s.heading = (s.heading + spin * step) % 360
        s.box.sx = clamp(s.box.sx + axis(CTRL.left, CTRL.right) * f, 0.3, 12.0)
        s.box.sy = clamp(s.box.sy + axis(CTRL.down, CTRL.up) * f, 0.3, 12.0)
        s.box.sz = clamp(s.box.sz + axis(CTRL.pgDown, CTRL.pgUp) * f, 0.3, 8.0)
        local _, aim = aimRay(Config.Placement.maxDistance, 1 + 16)
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
    if candidate then
        location, interior = describeSpot(candidate.pos)
        if interiorTaken(interior, s.station and s.station.id) then
            warning = Config.Messages.dj_interior_occupied
            candidate.blocked = true
        end
    end

    -- HUD
    hud.title, hud.subtitle = 'Place the console', 'Where people walk up to start the music.'
    hud.options = {}
    for _, m in ipairs(consoleModes(s)) do hud.options[#hud.options + 1] = { label = CONSOLE_LABEL[m], active = m == s.mode } end
    hud.info = { { label = 'Location', value = location } }
    hud.keys = { { keys = { 'Enter' }, label = s.mode == 'keep' and 'Keep this console' or 'Confirm console' }, { keys = { 'G' }, label = 'Switch mode' } }
    if s.mode == 'prop' then
        table.insert(hud.info, { label = 'Prop', value = ('%s (%d/%d)'):format(s.models[s.modelIndex].name, s.modelIndex, #s.models) })
        table.insert(hud.info, { label = 'Rotation · height', value = ('%d° · %+.2f m'):format(math.floor(s.heading), s.lift) })
        table.insert(hud.keys, { keys = { 'M' }, label = 'Change prop' })
        table.insert(hud.keys, { keys = { 'Scroll' }, label = 'Rotate' })
        table.insert(hud.keys, { keys = { '↑', '↓' }, label = 'Raise / lower' })
        table.insert(hud.keys, { keys = { 'Shift' }, label = 'Fine adjust' })
    elseif s.mode == 'entity' then
        table.insert(hud.info, { label = 'Object', value = candidate and candidate.objectName or 'none' })
        table.insert(hud.info, { label = 'Players use', value = 'ox_target on that object' })
    elseif s.mode == 'zone' then
        table.insert(hud.info, { label = 'Box size', value = ('%.1f × %.1f × %.1f m'):format(s.box.sx, s.box.sy, s.box.sz) })
        table.insert(hud.keys, { keys = { 'Scroll' }, label = 'Rotate' })
        table.insert(hud.keys, { keys = { '←', '→' }, label = 'Width' })
        table.insert(hud.keys, { keys = { '↑', '↓' }, label = 'Depth' })
        table.insert(hud.keys, { keys = { 'PgUp', 'PgDn' }, label = 'Height' })
        table.insert(hud.keys, { keys = { 'Shift' }, label = 'Fine adjust' })
    elseif s.mode == 'keep' then
        table.insert(hud.info, { label = 'Console', value = CONSOLE_KIND[s.console.mode] })
    end
    hud.warning = warning

    if pressed(CTRL.enter) and candidate and not candidate.blocked then
        local moved = not s.console or #(s.console.pos - candidate.pos) > 0.05
        s.console = candidate
        s.mode = 'keep'
        if moved and s.audio and s.audio.type == 'interior' then s.audio = nil end -- re-detect the interior
        return 2
    end
end

-- ─── step 2: sound ─────────────────────────────────────────────────────────

local function initAudio(s)
    local c = s.console.pos
    s.interiorId = GetInteriorAtCoords(c.x, c.y, c.z)
    if not s.audio then
        local existing = s.station and s.station.settings and s.station.settings.audio
        if existing then
            s.audio = copyList({ existing })[1]
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
    s.audio.points = s.audio.points or {}
    if s.audio.type == 'interior' and s.interiorId == 0 then s.audio.type = 'radius' end
end

local function audioTypes(s)
    if s.interiorId ~= 0 then return { 'interior', 'radius', 'area' } end
    return { 'radius', 'area' }
end

local function areaBounds(s)
    local minZ = s.console.pos.z
    for _, p in ipairs(s.audio.points) do
        if p.z and p.z < minZ then minZ = p.z end
    end
    minZ = minZ - 1.5
    return minZ, minZ + s.areaHeight
end

local function drawArea(s, aim)
    local pts = s.audio.points
    local minZ, maxZ = areaBounds(s)
    local n = #pts
    for i, p in ipairs(pts) do
        local a1, a2 = vector3(p.x, p.y, minZ), vector3(p.x, p.y, maxZ)
        line(a1, a2, 120, 255, 170)
        dot(vector3(p.x, p.y, (p.z or minZ) + 0.2), 0.25, 120, 255, 170)
        local q = (i < n) and pts[i + 1] or (n >= 3 and pts[1] or nil)
        if q then
            local b1, b2 = vector3(q.x, q.y, minZ), vector3(q.x, q.y, maxZ)
            line(a1, b1, 120, 255, 170)
            line(a2, b2, 120, 255, 170)
            quad(a1, b1, b2, a2, 120, 255, 170, 35)
        end
    end
    if aim then
        dot(aim, 0.3, 255, 255, 255)
        if n > 0 then line(vector3(pts[n].x, pts[n].y, aim.z), aim, 255, 255, 255, 160) end
    end
end

local function stepSound(s, hud)
    local a = s.audio
    if pressed(CTRL.mode) then a.type = cycle(audioTypes(s), a.type) end
    local spin = scrolled()
    local console = s.console.pos
    showConsole(s, s.console)

    local location = describeSpot(console)
    hud.title, hud.subtitle = 'Sound area', 'Who hears the music, and how loud.'
    hud.options = {}
    for _, t in ipairs(audioTypes(s)) do hud.options[#hud.options + 1] = { label = AUDIO_LABEL[t], active = t == a.type } end
    hud.info = { { label = 'Console', value = location } }
    hud.keys = { { keys = { 'Enter' }, label = 'Next: lights' }, { keys = { 'G' }, label = 'Switch sound mode' } }

    if a.type == 'interior' then
        a.muffled = clamp(a.muffled + axis(CTRL.left, CTRL.right) * (fine() and 0.05 or 0.25) + spin * (fine() and 1 or 5), 0.0, Config.DjSound.maxMuffled)
        drawRing(console, math.max(0.5, a.muffled), 255, 190, 80)
        table.insert(hud.info, { label = 'Full volume in', value = ('Whole interior #%d'):format(s.interiorId) })
        table.insert(hud.info, { label = 'Muffled outside', value = a.muffled < 0.5 and 'Not heard outside' or ('up to %d m'):format(math.floor(a.muffled + 0.5)) })
        table.insert(hud.keys, { keys = { '←', '→' }, label = 'Muffled range outside' })
        table.insert(hud.keys, { keys = { 'Scroll' }, label = '±5 m' })
    elseif a.type == 'radius' then
        a.range = clamp(a.range + axis(CTRL.left, CTRL.right) * (fine() and 0.1 or 0.5) + spin * (fine() and 1 or 10), Config.DjSound.minRadius, Config.DjSound.maxRadius)
        drawRing(console, a.range, 80, 200, 255)
        table.insert(hud.info, { label = 'Heard up to', value = ('%d m, fading with distance'):format(math.floor(a.range + 0.5)) })
        table.insert(hud.keys, { keys = { '←', '→' }, label = 'Range' })
        table.insert(hud.keys, { keys = { 'Scroll' }, label = '±10 m' })
    else
        local _, aim = aimRay(Config.Placement.farDistance, 1 + 16)
        if pressed(CTRL.place) and #a.points < Config.DjSound.maxAreaPoints then
            a.points[#a.points + 1] = { x = aim.x, y = aim.y, z = aim.z }
        end
        if pressed(CTRL.remove) and #a.points > 0 then table.remove(a.points) end
        s.areaHeight = clamp(s.areaHeight + axis(CTRL.pgDown, CTRL.pgUp) * (fine() and 0.02 or 0.1), 2.0, 60.0)
        a.fade = clamp(a.fade + axis(CTRL.left, CTRL.right) * (fine() and 0.05 or 0.25), 0.0, 100.0)
        drawArea(s, aim)
        table.insert(hud.info, { label = 'Corners', value = ('%d / %d%s'):format(#a.points, Config.DjSound.maxAreaPoints, #a.points < 3 and ' · need at least 3' or '') })
        table.insert(hud.info, { label = 'Area height', value = ('%.1f m'):format(s.areaHeight) })
        table.insert(hud.info, { label = 'Fades out over', value = ('%d m outside'):format(math.floor(a.fade + 0.5)) })
        table.insert(hud.keys, 1, { keys = { 'E' }, label = 'Add corner where you aim' })
        table.insert(hud.keys, 2, { keys = { 'Backspace' }, label = 'Remove last corner' })
        table.insert(hud.keys, { keys = { 'PgUp', 'PgDn' }, label = 'Area height' })
        table.insert(hud.keys, { keys = { '←', '→' }, label = 'Fade distance' })
    end
    table.insert(hud.keys, { keys = { 'Shift' }, label = 'Fine adjust' })

    if pressed(CTRL.enter) then
        if a.type == 'area' and #a.points < 3 then
            hud.warning = 'Add at least 3 corners, or switch to a radius.'
            s.flash = GetGameTimer() + 2500
            return
        end
        return 3
    end
    if s.flash and GetGameTimer() < s.flash then hud.warning = 'Add at least 3 corners, or switch to a radius.' end
end

-- ─── step 3: lights ────────────────────────────────────────────────────────

local function stepLights(s, hud)
    local console = s.console.pos
    showConsole(s, s.console)
    hud.title, hud.subtitle = 'Disco lights', 'Optional. They come on whenever the booth is playing.'
    hud.keys = { { keys = { 'Enter' }, label = 'Next: review' } }

    if not Config.DiscoLights.enabled then
        hud.options = {}
        hud.info = { { label = 'Disco lights', value = 'Turned off on this server' } }
        if pressed(CTRL.enter) then return 4 end
        return
    end

    local colors = Config.DiscoLights.colors
    if pressed(CTRL.mode) then s.lightType = s.lightType % #LIGHT_TYPES + 1 end
    if pressed(CTRL.color) then s.colorIndex = s.colorIndex % #colors + 1 end
    if pressed(CTRL.right) then s.speed = clamp(s.speed + 0.25, 0.25, 3.0) end
    if pressed(CTRL.left) then s.speed = clamp(s.speed - 0.25, 0.25, 3.0) end

    local hit, aim, _, dir = aimRay(Config.Placement.farDistance, 1 + 16)
    -- Pull the fixture slightly off the surface you aimed at (ceilings, walls, trusses).
    local spot = hit and (aim - dir * 0.3) or aim
    local ms = GetGameTimer()
    local t, beat = ms / 1000.0, DjBeatPhase(ms)

    -- The light you're about to place, previewed where you aim.
    local pending = { type = LIGHT_TYPES[s.lightType], x = spot.x, y = spot.y, z = spot.z, color = colors[s.colorIndex].name, speed = s.speed }

    -- Nearest placed light to the aim point (what Backspace removes).
    local nearest, nearestDist
    for i, l in ipairs(s.lights) do
        local d = #(vector3(l.x, l.y, l.z) - spot)
        if d < 3.0 and (not nearestDist or d < nearestDist) then nearest, nearestDist = i, d end
    end

    DrawDjLights(s.lights, console, t, beat)
    if #s.lights < Config.DiscoLights.maxPerBooth then DrawDjLights({ pending }, console, t, beat) end
    for i, l in ipairs(s.lights) do
        local p = vector3(l.x, l.y, l.z)
        if i == nearest then dot(p, 0.45, 255, 80, 80, 160) end
        line(p, console, 255, 255, 255, 40)
    end
    dot(spot, 0.18, 255, 255, 255)

    if pressed(CTRL.place) then
        if #s.lights < Config.DiscoLights.maxPerBooth then
            s.lights[#s.lights + 1] = pending
        else
            s.flash = GetGameTimer() + 2000
        end
    end
    if pressed(CTRL.remove) and #s.lights > 0 then table.remove(s.lights, nearest or #s.lights) end

    hud.options = {}
    for i, lt in ipairs(LIGHT_TYPES) do hud.options[#hud.options + 1] = { label = LIGHT_LABEL[lt], active = i == s.lightType } end
    hud.info = {
        { label = 'Colour', value = colors[s.colorIndex].name, swatch = colors[s.colorIndex].rgb or 'rainbow' },
        { label = 'Speed', value = ('%.2f×'):format(s.speed) },
        { label = 'Lights placed', value = ('%d / %d'):format(#s.lights, Config.DiscoLights.maxPerBooth) },
    }
    table.insert(hud.keys, 1, { keys = { 'E' }, label = 'Place light where you aim' })
    table.insert(hud.keys, 2, { keys = { 'Backspace' }, label = nearest and 'Remove highlighted light' or 'Remove last light' })
    table.insert(hud.keys, { keys = { 'G' }, label = 'Light type' })
    table.insert(hud.keys, { keys = { 'C' }, label = 'Colour' })
    table.insert(hud.keys, { keys = { '←', '→' }, label = 'Speed' })
    if s.flash and GetGameTimer() < s.flash then hud.warning = ('That’s the maximum of %d lights.'):format(Config.DiscoLights.maxPerBooth) end

    if pressed(CTRL.enter) then return 4 end
end

-- ─── step 4: review & save ─────────────────────────────────────────────────

local function soundSummary(s)
    local a = s.audio
    if a.type == 'interior' then
        return a.muffled < 0.5 and ('Interior #%d only'):format(s.interiorId)
            or ('Interior #%d · muffled up to %d m outside'):format(s.interiorId, math.floor(a.muffled + 0.5))
    elseif a.type == 'area' then
        return ('Custom area · %d corners · fades over %d m'):format(#a.points, math.floor(a.fade + 0.5))
    end
    return ('Radius %d m'):format(math.floor(a.range + 0.5))
end

local function stepSave(s, hud)
    local console = s.console.pos
    showConsole(s, s.console)
    local ms = GetGameTimer()
    DrawDjLights(s.lights, console, ms / 1000.0, DjBeatPhase(ms))
    if s.audio.type == 'radius' then drawRing(console, s.audio.range, 80, 200, 255) end
    if s.audio.type == 'interior' and s.audio.muffled > 0.5 then drawRing(console, s.audio.muffled, 255, 190, 80) end
    if s.audio.type == 'area' then drawArea(s, nil) end

    local consoleText = CONSOLE_KIND[s.console.mode]
    if s.console.mode == 'prop' and s.console.modelName then consoleText = ('%s · %s'):format(consoleText, s.console.modelName) end
    if s.console.mode == 'entity' and s.console.objectName then consoleText = ('%s · %s'):format(consoleText, s.console.objectName) end

    hud.title = s.station and 'Save changes' or 'Review & save'
    hud.subtitle = s.station and ('Updating “%s” for everyone.'):format(s.station.label or 'DJ booth') or 'Everyone will see the booth as soon as you save.'
    hud.options = {}
    hud.info = {
        { label = 'Console', value = consoleText },
        { label = 'Location', value = (describeSpot(console)) },
        { label = 'Sound', value = soundSummary(s) },
        { label = 'Disco lights', value = #s.lights == 0 and 'None' or ('%d light%s'):format(#s.lights, #s.lights == 1 and '' or 's') },
    }
    hud.keys = { { keys = { 'Enter' }, label = s.station and 'Save changes' or 'Create booth' } }
    if pressed(CTRL.enter) then return 'save' end
end

-- ─── save / session ────────────────────────────────────────────────────────

local function buildSettings(s)
    local c, a = s.console, s.audio
    local audio = { type = a.type, range = a.range, muffled = a.muffled, fade = a.fade }
    if a.type == 'area' then
        audio.points = {}
        for i, p in ipairs(a.points) do audio.points[i] = { x = p.x, y = p.y } end
        audio.minZ, audio.maxZ = areaBounds(s)
    end
    return {
        mode = c.mode,
        model = c.mode == 'prop' and c.model or nil,
        zone = c.mode ~= 'prop' and c.zone or nil,
        audio = audio,
        lights = s.lights,
    }
end

local function save(s)
    local c = s.console
    local pos = { x = c.pos.x, y = c.pos.y, z = c.pos.z }
    local settings = buildSettings(s)

    if s.station then
        local ok, err = lib.callback.await('kariee_radio:dj:update', false, s.station.id, pos, c.heading, settings)
        ESX.ShowNotification(ok and Config.Messages.creator_updated or (err == 'no_permission' and Config.Messages.no_permission or 'Failed to update the DJ booth.'))
        return
    end

    local street = streetAt(c.pos)
    local label = street and ('DJ booth · %s'):format(street) or 'DJ booth'
    local station, err = lib.callback.await('kariee_radio:dj:create', false, pos, c.heading, label, settings)
    if not station then
        if err == 'banned' then return end -- the server already told them why
        ESX.ShowNotification(err == 'no_permission' and Config.Messages.no_permission or 'Failed to create DJ station.')
        return
    end
    ESX.ShowNotification(Config.Messages.creator_saved)
    OpenRadio({ kind = 'dj', id = ('dj:%s'):format(station.id), stationId = station.id })
end

local function consoleFromStation(station)
    local settings = station.settings or {}
    local model = settings.model or Config.DjMixerModel
    return {
        mode = settings.mode or 'prop',
        model = model,
        zone = settings.zone,
        pos = vector3(station.pos_x, station.pos_y, station.pos_z),
        heading = station.heading or 0.0,
    }
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
    while true do
        Wait(0)
        for _, c in ipairs(DISABLED) do DisableControlAction(0, c, true) end

        local hud = {
            editing = s.station ~= nil,
            label = s.station and s.station.label or nil,
            step = s.step,
            steps = STEPS,
            options = {},
            info = {},
            keys = {},
        }

        local nextStep
        if s.step == 1 then nextStep = stepConsole(s, hud)
        elseif s.step == 2 then nextStep = stepSound(s, hud)
        elseif s.step == 3 then nextStep = stepLights(s, hud)
        else nextStep = stepSave(s, hud) end

        if s.step > 1 then table.insert(hud.keys, { keys = { 'X' }, label = 'Back' }) end
        table.insert(hud.keys, { keys = { 'Esc' }, label = 'Cancel' })
        sendHud(s, hud, nextStep ~= nil)

        if nextStep == 'save' then
            result = 'save'
            break
        elseif nextStep then
            s.step = nextStep
            s.flash = nil
            if s.step == 2 then initAudio(s) end
        elseif pressed(CTRL.back) and s.step > 1 then
            s.step = s.step - 1
            s.flash = nil
        elseif pressed(CTRL.cancel) then
            result = 'cancel'
            break
        end
    end

    deleteGhost(s)
    SendNUIMessage({ action = 'creator', data = false })
    session = nil

    if result == 'save' then save(s) else ESX.ShowNotification(Config.Messages.placement_cancelled) end
end

---Opens the creator. `station` = edit that booth, nil = create a new one.
function StartDjCreator(station)
    if session then return end
    if not NetworkIsPlayerActive(PlayerId()) or not PlayerLoaded then
        ESX.ShowNotification(Config.Messages.not_ready)
        return
    end
    if IsRadioOpen and IsRadioOpen() then CloseRadio() end

    local models = {}
    for _, name in ipairs(Config.DjModels) do
        local hash = GetHashKey(name)
        if IsModelInCdimage(hash) then models[#models + 1] = { name = name, hash = hash } end
    end
    if #models == 0 then models[1] = { name = 'default', hash = Config.DjMixerModel } end

    local ped = PlayerPedId()
    session = {
        station = station,
        step = 1,
        mode = station and 'keep' or 'prop',
        console = station and consoleFromStation(station) or nil,
        models = models,
        modelIndex = 1,
        heading = GetEntityHeading(ped),
        lift = 0.0,
        box = { sx = 1.6, sy = 1.0, sz = 1.3 },
        areaHeight = Config.DjSound.defaultAreaHeight,
        audio = nil,
        lights = copyList(station and station.settings and station.settings.lights),
        lightType = 1,
        colorIndex = 1,
        speed = 1.0,
        hudSent = '',
        hudAt = 0,
    }
    CreateThread(function() run(session) end)
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() or not session then return end
    deleteGhost(session)
end)
