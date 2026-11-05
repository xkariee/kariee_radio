local RESOURCE_NAME = 'ax_radio'
local VERSION_URL = 'https://raw.githubusercontent.com/xkariee/versions/main/%s.json'

local BANNER = {
    '\n',
    '        :::     :::    ::: ::::::::::: :::::::::: ::::::::::',
    '        :+: :+:   :+:    :+:     :+:     :+:        :+:',
    '       +:+   +:+   +:+  +:+      +:+     +:+        +:+',
    '      +#++:++#++:   +#++:+       +#+     +#++:++#   +#++:++#',
    '      +#+     +#+  +#+  +#+      +#+     +#+        +#+',
    '      #+#     #+# #+#    #+#     #+#     #+#        #+#',
    '      ###     ### ###    ### ########### ########## ##########',
}

local resourceName = GetCurrentResourceName()
local currentVersion = GetResourceMetadata(resourceName, 'version', 0)

local function report(...)
    for _, line in ipairs(BANNER) do print('^4' .. line) end
    for _, line in ipairs({ ... }) do print(line) end
end

local function versionParts(version)
    local parts = {}
    for part in tostring(version):gmatch('%d+') do parts[#parts + 1] = tonumber(part) end
    return parts
end

local function compareVersions(a, b)
    local left, right = versionParts(a), versionParts(b)
    for i = 1, math.max(#left, #right) do
        local x, y = left[i] or 0, right[i] or 0
        if x ~= y then return x > y and 1 or -1 end
    end
    return 0
end

local function onResponse(code, body)
    local data = code == 200 and DecodeJson(body)
    if type(data) ~= 'table' or not data.version then
        return report('\n^1API unavailable – unable to check version!^0')
    end

    report(('\n^3Checking version for %s...^0'):format(resourceName))
    local difference = compareVersions(data.version, currentVersion)
    if difference == 0 then
        print(('> ^2You are using the latest version (%s)!^0'):format(currentVersion))
    elseif difference > 0 then
        print('> ^3New version available!^0')
        for _, line in pairs(data.descriptions or {}) do print(('^3• %s^0'):format(line)) end
        print(('> ^3Update from ^7%s ^3to ^7%s^0'):format(currentVersion, data.version))
    else
        print(('> ^1You are using a newer version (%s) than the one available on the Keymaster (%s).^0'):format(currentVersion, data.version))
    end
    print('\n')
end

if not currentVersion then
    report(('^1Unable to read version info for:^0 ^7%s^0'):format(resourceName), '^1Make sure ^7version^1 is defined in your fxmanifest.lua^0')
elseif resourceName ~= RESOURCE_NAME then
    report('\n^1Resource name mismatch!^0', ('^1Please rename this resource to:^0 ^7%s^0\n\n'):format(RESOURCE_NAME))
else
    PerformHttpRequest(VERSION_URL:format(resourceName), onResponse, 'GET', '', {}, {})
end
