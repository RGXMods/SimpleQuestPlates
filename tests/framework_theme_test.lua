-- SQP's options follow the main colour chosen on the RGX-Framework settings page, and keep SQP's own green
-- until one is chosen. Runs the real colour-selection block from data/options_core.lua.
local function check(c, m) if not c then error("CHECK FAILED: " .. m, 2) end end
local function rd(p) local f = assert(io.open(p)); local s = f:read("*a"); f:close(); return s end

local src = rd("data/options_core.lua")
local a = assert(src:find("    local function ChosenFrameworkTheme()", 1, true))
local b = assert(src:find("    if RGX and type(RGX.SetHighlightColor)", a, true))
local block = src:sub(a, b - 1)

local function run(db, presets)
  _G.RGXFrameworkDB = db
  _G.RGXDesign = presets and { THEME_PRESETS = presets } or nil
  local chunk = assert(loadstring(block .. "\nreturn PRIMARY, ACCENT"))
  return chunk()
end

local GREEN, PURPLE = { 0.345, 0.745, 0.506 }, { 0.737, 0.435, 0.659 }
local presets = { gold = { primary = { 1, 0.843, 0 }, accent = { 0.737, 0.435, 0.659 } }, cyan = { primary = { 0, 0.902, 1 }, accent = { 0.1, 0.2, 0.3 } } }

local p, acc = run(nil, presets)
check(p[1] == GREEN[1] and p[2] == GREEN[2] and p[3] == GREEN[3], "no saved framework settings: SQP green")
check(acc[1] == PURPLE[1], "no saved framework settings: SQP accent")
p = run({}, presets)
check(p[1] == GREEN[1], "no colour chosen yet: SQP green")
p, acc = run({ themePreset = "gold" }, presets)
check(p[1] == 1 and p[2] == 0.843 and p[3] == 0, "a chosen framework preset becomes the primary colour")
check(acc[1] == 0.737, "the preset's accent is used")
p, acc = run({ themePreset = "cyan" }, presets)
check(p[3] == 1 and acc[3] == 0.3, "another preset: its own primary and accent")
p = run({ themePreset = "no-such-preset" }, presets)
check(p[1] == GREEN[1], "an unknown preset falls back to SQP green")
p = run({ themePreset = "gold" }, nil)
check(p[1] == GREEN[1], "no framework design module: SQP green")
-- the colours are copies: editing one must not change the framework's preset
p = run({ themePreset = "gold" }, presets)
p[1] = 0
check(presets.gold.primary[1] == 1, "the framework preset table is not shared")
print("framework_theme_test OK")
