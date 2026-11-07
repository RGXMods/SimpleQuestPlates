-- Minimap icon choice must survive a reload, using the REAL framework database and
-- minimap button plus SQP's real minimap functions. Two sessions share one saved table.
-- RGXFW_PATH points at an RGX-Framework checkout (default ../RGX-Framework).
local FW = (os.getenv("RGXFW_PATH") or "../RGX-Framework"):gsub("\\", "/")
if not FW:find("/$") then FW = FW .. "/" end
local function check(c, m) if not c then error("CHECK FAILED: " .. m, 2) end end
local function rd(p) local f = assert(io.open(p)); local s = f:read("*a"); f:close(); return s end

function UnitName() return "T" end
function GetRealmName() return "R" end
function InCombatLockdown() return false end
function IsControlKeyDown() return false end
local function newFrame()
  local f = { shown = true, hooks = {} }
  return setmetatable(f, { __index = function(_, k)
    if type(k) == "string" and (k:sub(1, 1) == "_" or k == "ring" or k == "icon" or k == "backgroundTexture") then return nil end
    if k == "Show" then return function(s) s.shown = true; for _, h in ipairs(s.hooks) do h(s) end end end
    if k == "Hide" then return function(s) s.shown = false end end
    if k == "IsShown" then return function(s) return s.shown end end
    if k == "HookScript" then return function(s, ev, fn) if ev == "OnShow" then s.hooks[#s.hooks + 1] = fn end end end
    if k == "GetCenter" or k == "GetWidth" or k == "GetHeight" or k == "GetFrameLevel" or k == "GetScale" then return function() return 1 end end
    return function(s) return s end
  end })
end
function CreateFrame(_, n) local f = newFrame(); if n then _G[n] = f end return f end
_G.Minimap = newFrame(); UIParent = newFrame()
local RGX = { _databases = {} }
function RGX:Print() end function RGX:Error() end function RGX:Debug() end
function RGX:RegisterModule(n, m) self.modules = self.modules or {}; self.modules[n] = m end
function RGX:GetMinimap() return self.modules.minimap end
_G.RGXFramework = RGX
local function load(path, ...) return assert(loadstring(rd(path), "@" .. path))(...) end
load(FW .. "core/systems/database.lua", "RGX-Framework", RGX)
load(FW .. "libraries/minimap/minimap.lua", "RGX-Framework", RGX)

GetAddOnMetadata = function() return nil end
C_AddOns = { GetAddOnMetadata = function() end }
function GetLocale() return "enUS" end function GetAddOnInfo() return nil end
RGX.interfaceVersion = "120100"
local core = rd("data/core.lua")
local head = core:sub(1, core:find("function SQP:GetSettingBaseline", 1, true) - 1)
local a = core:find("function SQP:SetupMinimapButton", 1, true)
local b = core:find("function SQP:InitializeFrameworkUI", 1, true)

local function deep(t) if type(t) ~= "table" then return t end local r = {} for k, v in pairs(t) do r[k] = deep(v) end return r end

local function session(saved)
  _G.SQPSettings = nil; _G.SQP_MinimapButton = nil; RGX.modules.minimap._buttons = {}; RGX._databases = {}
  local SQP = {}
  assert(loadstring(head, "@head"))("SimpleQuestPlates", SQP)
  SQP.db = RGX:NewDatabase("SQPSettings", SQP.DEFAULTS, { legacyFlat = true, profileIsGlobal = true })
  local settings = SQP.db.global
  _G.SQPSettings = deep(saved)          -- the client loads the saved file
  SQP.db:Adopt()
  assert(loadstring("local SQP, SQPSettings, RGX = ...\nSQP.defaultMinimapAngle = 220\nfunction SQP:PrintMessage() end\n" .. core:sub(a, b - 1)))(SQP, settings, RGX)
  return SQP
end

-- First session: default (shown), the player hides the icon.
local s1 = session(nil)
s1:ApplyMinimapVisibility()
check(s1.minimapBtn.frame.shown == true, "a fresh profile shows the icon")
s1:ToggleMinimapIcon(false, true)
check(s1.minimapBtn.frame.shown == false, "hiding works")
local saved = deep(_G.SQPSettings)

-- Reload: the icon stays hidden.
local s2 = session(saved)
s2:ApplyMinimapVisibility()
check(s2.minimapBtn.frame.shown == false, "the icon stays hidden after a reload")

-- Another addon re-showing the button must not undo it, and the next loading screen re-applies it.
s2.minimapBtn.frame:Show()
check(s2.minimapBtn.frame.shown == false, "a re-show by another addon is undone")
s2.minimapBtn.frame.shown = true
s2:ApplyMinimapVisibility()
check(s2.minimapBtn.frame.shown == false, "re-applying hides a button that was re-shown")

-- Showing it again also persists.
s2:ToggleMinimapIcon(true, true)
local s3 = session(deep(_G.SQPSettings))
s3:ApplyMinimapVisibility()
check(s3.minimapBtn.frame.shown == true, "showing the icon persists across a reload")

-- The choice is saved even if the button was never built.
local s4 = session(nil)
s4.SetupMinimapButton = function() end
s4:ToggleMinimapIcon(false, true)
check(_G.SQPSettings.profiles.Default.minimapIconEnabled == false, "the choice is saved without a button")

-- A button taken over by a collector addon is not force-shown by the re-apply.
local s5 = session(nil)
s5:ApplyMinimapVisibility()
local collectorBar = newFrame()
s5.minimapBtn.frame.GetParent = function() return collectorBar end
s5.minimapBtn.frame.shown = false          -- the collector's bar is hidden
s5:ApplyMinimapVisibility()
check(s5.minimapBtn.frame.shown == false, "a collected button is not force-shown on a loading screen")

print("minimap_persist_test OK")
