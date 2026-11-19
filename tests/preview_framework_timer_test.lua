-- Exercise the real preview OnShow with the real framework scheduler, without
-- native timers. Rendering and real-client layout remain manual checks.
local function check(value, message)
    assert(value, message)
end

local file = assert(io.open("data/options_preview.lua"))
local source = file:read("*a")
file:close()
local first = assert(source:find('previewFrame:SetScript("OnShow", function(self)', 1, true))
local last = assert(source:find("\n    end)\n\n    -- Type-switcher", first, true))
local handlerSource = source:sub(first, last + #"\n    end)")

local RGX = {}
_G.RGXFramework = RGX
_G.C_Timer = nil
local errors = {}
_G.geterrorhandler = function()
    return function(message) errors[#errors + 1] = message end
end
_G.GetTimePreciseSec = function() return 0 end
_G.CreateFrame = function()
    return { SetScript = function(self, name, fn) self[name] = fn end }
end
local frameworkPath = os.getenv("RGXFW_PATH") or "../RGX-Framework"
assert(loadfile(frameworkPath .. "/core/systems/runtime.lua"))("RGX-Framework", RGX)

local updates, shown, failRefresh = 0, true, false
local previewFrame = {
    IsShown = function() return shown end,
    UpdatePreview = function()
        if failRefresh then error("preview refresh failed") end
        updates = updates + 1
    end,
    SetScript = function(self, name, fn) self[name] = fn end,
}
assert(loadstring("local previewFrame, RGX = ...\n" .. handlerSource))(previewFrame, RGX)

previewFrame:OnShow()
check(updates == 1 and #RGX.timers == 2, "show defers both follow-ups")
check(RGX.timers[1].label == "SQP preview refresh", "diagnostic label reaches the scheduler")
RGX.timerFrame:OnUpdate(0)
check(updates == 2 and #RGX.timers == 1, "zero-delay refresh runs on the next driver update")
-- Use exactly representable frame deltas on either side of the deadline.
-- Cumulative decimal subtraction can leave a nominal 0.15 tick just short.
RGX.timerFrame:OnUpdate(0.125)
check(updates == 2, "delayed refresh does not run early")
RGX.timerFrame:OnUpdate(0.03125)
check(updates == 3 and #RGX.timers == 0, "layout refresh runs once after 0.15 seconds")
check(RGX.timerFrame.OnUpdate == nil, "idle timer driver stops")

previewFrame:OnShow()
shown = false
RGX.timerFrame:OnUpdate(0.25)
check(updates == 4 and #RGX.timers == 0, "hidden previews are not refreshed by overdue timers")

shown = true
previewFrame:OnShow()
RGX.timerFrame:OnUpdate(0)
RGX.timerFrame:OnUpdate(0.15625)
check(updates == 7 and #RGX.timers == 0, "reopening restarts both refreshes")

previewFrame:OnShow()
failRefresh = true
local unrelated = false
RGX:After(0, function() unrelated = true end, "unrelated timer")
RGX.timerFrame:OnUpdate(0.25)
check(unrelated and #errors == 2 and #RGX.timers == 0,
    "failed preview callbacks remain isolated from other framework timers")

print("preview_framework_timer_test OK")
