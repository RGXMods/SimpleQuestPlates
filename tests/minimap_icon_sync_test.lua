-- Hiding/showing the minimap icon from anywhere (options checkbox, /sqp icon,
-- Ctrl+Right-click) must leave the options checkbox showing the saved state.
-- Runs the real SQP:ToggleMinimapIcon from data/core.lua.
local f = assert(io.open("data/core.lua", "r"))
local source = f:read("*a")
f:close()

local first = assert(source:find("function SQP:ToggleMinimapIcon", 1, true), "ToggleMinimapIcon not found")
local last = assert(source:find("function SQP:ApplyMinimapVisibility", first, true), "ApplyMinimapVisibility not found")
local chunk = assert(loadstring("local SQP = ...\n" .. source:sub(first, last - 1) .. "\nreturn SQP"))

local function check(cond, msg) if not cond then error("CHECK FAILED: " .. msg, 2) end end

local SQP = { messages = {} }
function SQP:PrintMessage(m) self.messages[#self.messages + 1] = m end
local visible = true
SQP.minimapBtn = { SetVisible = function(_, show) visible = show end }
local checked = true
SQP.optionControls = { minimapIconEnabled = { SetChecked = function(_, v) checked = v end } }
chunk(SQP)

SQP:ToggleMinimapIcon(false, true)   -- Ctrl+Right-click path
check(visible == false, "icon hidden")
check(checked == false, "checkbox must follow a hide done outside the options panel")

SQP:ToggleMinimapIcon(true, true)    -- /sqp icon on
check(visible == true and checked == true, "checkbox follows a show")

SQP.optionControls = nil             -- options panel never opened
SQP:ToggleMinimapIcon(false)
check(visible == false, "toggle works before the options panel exists")

print("minimap_icon_sync_test OK")
