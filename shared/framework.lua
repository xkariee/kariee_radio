local IS_SERVER = IsDuplicityVersion()
local RESOURCE_NAME = GetCurrentResourceName()

local RESOURCES = { ESX = 'es_extended', QBCore = 'qb-core', QBox = 'qbx_core', VRP = 'vrp' }
local LOADED_EVENTS = { ESX = 'esx:playerLoaded', QBCore = 'QBCore:Client:OnPlayerLoaded', QBox = 'QBCore:Client:OnPlayerLoaded' }
local LOGOUT_EVENTS = { ESX = 'esx:onPlayerLogout', QBCore = 'QBCore:Client:OnPlayerUnload', QBox = 'QBCore:Client:OnPlayerUnload' }

FRAMEWORK = { name = nil }
ESX = {}
QBCore = {}
QBox = {}
VRP = {
    framework = {},
    client = {},
}

for _, name in ipairs({ 'ESX', 'QBCore', 'QBox', 'VRP' }) do
    local settings = Config.Frameworks[name]
    if settings and settings.enabled then
        FRAMEWORK.name = name
        break
    end
end

local function loadVrp()
    if not module then
        local utils = LoadResourceFile('vrp', 'lib/utils.lua')
        if not utils then return false end
        load(utils, '@vrp/lib/utils.lua')()
    end
    VRP.framework = module('vrp', 'lib/Proxy').getInterface('vRP')
    VRP.client = module('vrp', 'lib/Tunnel').getInterface('vRP', RESOURCE_NAME)
    return true
end

local function loadFramework(name)
    if GetResourceState(RESOURCES[name]) ~= 'started' then return false end
    if name == 'ESX' then
        ESX = exports.es_extended:getSharedObject()
    elseif name == 'QBCore' then
        QBCore = exports['qb-core']:GetCoreObject()
    elseif name == 'QBox' then
        QBox = exports.qbx_core
    elseif name == 'VRP' and IS_SERVER then
        return loadVrp()
    end
    return true
end

if not FRAMEWORK.name then
    print(('^1[%s] No framework is enabled in Config.Frameworks.^0'):format(RESOURCE_NAME))
elseif not loadFramework(FRAMEWORK.name) then
    print(('^1[%s] Could not load %s (%s). Make sure it starts before this resource.^0'):format(RESOURCE_NAME, FRAMEWORK.name, RESOURCES[FRAMEWORK.name]))
    FRAMEWORK.name = nil
end

if IS_SERVER then
    local function decode(raw)
        if type(raw) == 'table' then return raw end
        local ok, value = pcall(json.decode, raw or '')
        return ok and type(value) == 'table' and value or nil
    end

    local function fullName(first, last)
        local name = ('%s %s'):format(first or '', last or ''):match('^%s*(.-)%s*$')
        return name ~= '' and name or nil
    end

    local function fromEsx(xPlayer)
        if not xPlayer then return nil end
        return {
            source = xPlayer.source,
            identifier = xPlayer.identifier,
            hasJob = function(name, grade)
                local job = xPlayer.getJob and xPlayer.getJob() or xPlayer.job
                return job ~= nil and job.name == name and (tonumber(job.grade) or 0) >= grade
            end,
            hasGroup = function(group)
                return xPlayer.getGroup ~= nil and xPlayer.getGroup() == group
            end,
        }
    end

    local function fromQb(player)
        if not player then return nil end
        local source = player.PlayerData.source
        return {
            source = source,
            identifier = player.PlayerData.citizenid,
            hasJob = function(name, grade)
                local job = player.PlayerData.job
                return job ~= nil and job.name == name and (tonumber(job.grade and job.grade.level) or 0) >= grade
            end,
            hasGroup = function(group)
                if FRAMEWORK.name == 'QBox' then return IsPlayerAceAllowed(source, group) end
                return QBCore.Functions.HasPermission(source, group) == true
            end,
        }
    end

    local function fromVrp(source, userId)
        if not source or not userId then return nil end
        return {
            source = source,
            identifier = tostring(userId),
            hasJob = function(name)
                return VRP.framework.hasGroup({ userId, name }) == true
            end,
            hasGroup = function(group)
                return VRP.framework.hasGroup({ userId, group }) == true
            end,
        }
    end

    local function esxJobs()
        local jobs = ESX.GetJobs and ESX.GetJobs()
        if type(jobs) == 'table' and next(jobs) then return jobs end

        jobs = {}
        local okJobs, rows = pcall(MySQL.query.await, 'SELECT name, label FROM jobs')
        local okGrades, grades = pcall(MySQL.query.await, 'SELECT job_name, grade, label FROM job_grades')
        for _, job in ipairs(okJobs and rows or {}) do jobs[job.name] = { name = job.name, label = job.label, grades = {} } end
        for _, grade in ipairs(okGrades and grades or {}) do
            local job = jobs[grade.job_name]
            if job then job.grades[#job.grades + 1] = grade end
        end
        return jobs
    end

    FRAMEWORK.GetPlayerFromId = function(playerId)
        playerId = tonumber(playerId)
        if not playerId then return nil end
        if FRAMEWORK.name == 'ESX' then return fromEsx(ESX.GetPlayerFromId(playerId)) end
        if FRAMEWORK.name == 'QBCore' then return fromQb(QBCore.Functions.GetPlayer(playerId)) end
        if FRAMEWORK.name == 'QBox' then return fromQb(QBox:GetPlayer(playerId)) end
        if FRAMEWORK.name == 'VRP' then return fromVrp(playerId, VRP.framework.getUserId({ playerId })) end
    end

    FRAMEWORK.GetPlayerFromIdentifier = function(identifier)
        if not identifier then return nil end
        if FRAMEWORK.name == 'ESX' then return fromEsx(ESX.GetPlayerFromIdentifier(identifier)) end
        if FRAMEWORK.name == 'QBCore' then return fromQb(QBCore.Functions.GetPlayerByCitizenId(identifier)) end
        if FRAMEWORK.name == 'QBox' then return fromQb(QBox:GetPlayerByCitizenId(identifier)) end
        if FRAMEWORK.name == 'VRP' then
            local userId = tonumber(identifier)
            return fromVrp(userId and VRP.framework.getUserSource({ userId }), userId)
        end
    end

    FRAMEWORK.GetOfflineName = function(identifier)
        if FRAMEWORK.name == 'ESX' then
            local ok, row = pcall(MySQL.single.await, 'SELECT firstname, lastname FROM users WHERE identifier = ?', { identifier })
            return ok and row and fullName(row.firstname, row.lastname) or nil
        end
        if FRAMEWORK.name == 'QBCore' or FRAMEWORK.name == 'QBox' then
            local ok, row = pcall(MySQL.single.await, 'SELECT charinfo FROM players WHERE citizenid = ?', { identifier })
            local charinfo = ok and row and decode(row.charinfo)
            return charinfo and fullName(charinfo.firstname, charinfo.lastname) or nil
        end
        if FRAMEWORK.name == 'VRP' then
            local ok, row = pcall(MySQL.single.await, 'SELECT firstname, name FROM vrp_user_identities WHERE user_id = ?', { tonumber(identifier) })
            return ok and row and fullName(row.firstname, row.name) or nil
        end
    end

    FRAMEWORK.GetJobs = function()
        local raw = {}
        if FRAMEWORK.name == 'ESX' then
            raw = esxJobs()
        elseif FRAMEWORK.name == 'QBCore' then
            raw = QBCore.Shared.Jobs
        elseif FRAMEWORK.name == 'QBox' then
            raw = QBox:GetJobs()
        end

        local list = {}
        for name, job in pairs(raw or {}) do
            local grades = {}
            for key, grade in pairs(job.grades or {}) do
                local level = tonumber(grade.grade) or tonumber(key)
                if level then grades[#grades + 1] = { grade = level, label = tostring(grade.label or grade.name or level) } end
            end
            table.sort(grades, function(a, b) return a.grade < b.grade end)
            list[#list + 1] = { name = job.name or name, label = tostring(job.label or name), grades = grades }
        end
        table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
        return list
    end
else
    FRAMEWORK.IsPlayerLoaded = function()
        if FRAMEWORK.name == 'ESX' then return ESX.IsPlayerLoaded() end
        if FRAMEWORK.name == 'QBCore' or FRAMEWORK.name == 'QBox' then return LocalPlayer.state.isLoggedIn == true end
        return FRAMEWORK.name == 'VRP'
    end

    FRAMEWORK.ShowNotification = function(message)
        if FRAMEWORK.name == 'ESX' then return ESX.ShowNotification(message) end
        if FRAMEWORK.name == 'QBCore' then return QBCore.Functions.Notify(message) end
        if FRAMEWORK.name == 'QBox' then return QBox:Notify(message) end
        lib.notify({ description = message })
    end

    FRAMEWORK.OnPlayerLoaded = function(cb)
        local event = LOADED_EVENTS[FRAMEWORK.name]
        if event then RegisterNetEvent(event, cb) end
    end

    FRAMEWORK.OnPlayerLogout = function(cb)
        local event = LOGOUT_EVENTS[FRAMEWORK.name]
        if event then RegisterNetEvent(event, cb) end
    end
end
