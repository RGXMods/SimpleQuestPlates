-- SQP's option pages use SQP's own green until the framework's beta global theme override is on; then the
-- framework's main colour preset. Runs the real SQP:ResolveBrand / SQP:BrandHex from data/options_core.lua.
local function check(c, m) if not c then error("CHECK FAILED: " .. m, 2) end end
local f = assert(io.open("data/options_core.lua")); local src = f:read("*a"); f:close()
local a = assert(src:find("SQP.OwnBrand = ", 1, true))
local b = assert(src:find("function SQP:CreateOptionsPanel()", a, true))
local SQP = {}
assert(loadstring("local SQP = ...\n" .. src:sub(a, b - 1), "brand"))(SQP)

local GREEN = { 0.345, 0.745, 0.506 }
local presets = { gold = { primary = { 1, 0.843, 0 }, accent = { 0.737, 0.435, 0.659 } } }
local held = SQP.Brand.primary             -- a reference an option page holds
local function run(db, design) _G.RGXFrameworkDB = db; _G.RGXDesign = design; return SQP:ResolveBrand() end

-- A framework without ResolveAddonTheme (older): the saved preset only while the override is on.
local old = { THEME_PRESETS = presets }
run(nil, old);                                         check(held[1] == GREEN[1], "no framework settings: SQP green")
run({ themePreset = "gold" }, old);                    check(held[1] == GREEN[1], "override unset: SQP green")
run({ themePreset = "gold", themeOverride = false }, old); check(held[1] == GREEN[1], "override off: SQP green")
run({ themePreset = "gold", themeOverride = true }, old);  check(held[1] == 1 and held[2] == 0.843, "override on: the chosen preset")
check(SQP:BrandHex() == "|cffffd700", "the hex follows the live colour (" .. SQP:BrandHex() .. ")")
check(presets.gold.primary[1] == 1, "the framework preset table is never written")
run({ themePreset = "no-such", themeOverride = true }, old); check(held[1] == GREEN[1], "an unknown preset: SQP green")
run({ themePreset = "gold", themeOverride = true }, nil); check(held[1] == GREEN[1], "no design module: SQP green")

-- The current framework answers through ResolveAddonTheme.
local on = false
local modern = { ResolveAddonTheme = function(_, brand) if on then return presets.gold end return brand end }
run({}, modern);  check(held[1] == GREEN[1] and SQP:BrandHex() == "|cff58be81", "framework says off: SQP green")
on = true
run({}, modern);  check(held[1] == 1, "framework says on: its colour")
check(not src:find("SetHighlightColor", 1, true), "SQP never changes the framework's shared theme")
io.write("BrandOverride OK\n")
