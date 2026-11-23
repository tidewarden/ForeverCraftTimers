local _, FCT = ...
local Settings = {}
FCT.Settings = Settings

-- Saved in ForeverCraftTimersDB (FCT.db). An unset value means the default.
local DEFAULTS = {
    alerts = true,    -- on-screen notice when a cooldown is ready
    minimap = true,   -- show the minimap button
    x = 0,            -- notice offset from the top centre of the screen
    y = -217,         -- same height as ForeverRealsReminder
}
local LIMITS = {}
local listeners = {}

Settings.DEFAULTS, Settings.LIMITS = DEFAULTS, LIMITS

function Settings.Get(key)
    local value = FCT.db and FCT.db[key]
    if value == nil then return DEFAULTS[key] end
    return value
end

function Settings.Set(key, value)
    local default = DEFAULTS[key]
    if default == nil or type(value) ~= type(default) or not FCT.db then return end
    local limit = LIMITS[key]
    if limit then value = math.max(limit[1], math.min(limit[2], value)) end
    FCT.db[key] = value
    for _, fn in ipairs(listeners) do fn(key, value) end
end

function Settings.Toggle(key)
    Settings.Set(key, not Settings.Get(key))
end

function Settings.Reset()
    if not FCT.db then return end
    for key in pairs(DEFAULTS) do FCT.db[key] = nil end
    for key, value in pairs(DEFAULTS) do
        for _, fn in ipairs(listeners) do fn(key, value) end
    end
end

function Settings.OnChange(fn) table.insert(listeners, fn) end
