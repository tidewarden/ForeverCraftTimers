local T = ...

local function fresh()
    local FCT = { db = {} }
    assert(loadfile(T.root .. "/Settings.lua"))("ForeverCraftTimers", FCT)
    return FCT, FCT.Settings
end

T.test("settings_defaults", function()
    local _, S = fresh()
    T.eq(S.Get("alerts"), true)
    T.eq(S.Get("minimap"), true)
end)

T.test("settings_rejects_wrong_type_and_unknown_key", function()
    local _, S = fresh()
    S.Set("alerts", "no"); T.eq(S.Get("alerts"), true)
    S.Set("nope", 1); T.eq(S.Get("nope"), nil)
end)

T.test("settings_reset_and_listeners", function()
    local _, S = fresh()
    local seen = 0
    S.OnChange(function() seen = seen + 1 end)
    S.Set("alerts", false); T.eq(S.Get("alerts"), false)
    S.Reset(); T.eq(S.Get("alerts"), true)
    assert(seen >= 2)
end)
