-- SQP's option pages use SQP's own green until the framework's beta global theme override is on; then the
-- framework's main colour. The brand is registered with the framework (2.19+), which re-resolves it on a theme
-- change so the options panel redraws live. Runs the real SQP:GetBrand / ResolveBrand / BrandHex.
local function check(c, m) if not c then error("CHECK FAILED: " .. m, 2) end end
local f = assert(io.open("data/options_core.lua")); local src = f:read("*a"); f:close()
local a = assert(src:find("SQP.OwnBrand = ", 1, true))
local b = assert(src:find("function SQP:CreateOptionsPanel()", a, true))
local SQP = {}
local GOLD = { 1, 0.843, 0 }
local on, listener = false, nil
_G.RGXDesign = { RegisterBrand = function(_, id, own)
  return { id = id, OnChange = function(_, fn) listener = fn end, Build = function(_, fn) return fn() end,
    Resolve = function() if on then return { primary = GOLD, accent = GOLD } end return { primary = own.primary, accent = own.accent } end }
end }
assert(loadstring("local SQP = ...\n" .. src:sub(a, b - 1), "brand"))(SQP)

local held = SQP.Brand.primary             -- a reference an option page holds
SQP:ResolveBrand()
check(held[1] == 0.345 and SQP:BrandHex() == "|cff58be81", "override off: SQP green")
check(SQP:GetBrand() and SQP:GetBrand().id == "SimpleQuestPlates", "the brand is registered with the framework")
check(type(listener) == "function", "the brand listens for theme changes")
on = true
listener()
check(held[1] == 1 and held[2] == 0.843, "a change re-resolves the live colour in place")
check(SQP:BrandHex() == "|cffffd700", "the hex follows (" .. SQP:BrandHex() .. ")")
on = false
listener()
check(held[1] == 0.345, "override off again: SQP green")
check(src:find("addonBrand   = SQP:GetBrand(),", 1, true), "the options panel is built with the brand, so it redraws itself")
check(not src:find("SetHighlightColor", 1, true), "SQP never changes the framework's shared theme")
io.write("BrandOverride OK\n")
