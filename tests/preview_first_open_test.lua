-- Opening the options preview must keep refreshing after the client has laid out
-- the preview nameplate, otherwise the questplate stays blank until a control is clicked.
-- Runs the real OnShow handler from data/options_preview.lua.
local f = assert(io.open("data/options_preview.lua", "r"))
local source = f:read("*a")
f:close()
local first = assert(source:find('previewFrame:SetScript("OnShow", function(self)', 1, true), "OnShow handler not found")
local last = assert(source:find("    end)", first, true), "end of handler not found")
-- the handler contains nested 'end)' for the timer callback; take up to the one that closes SetScript
local depth_end = first
do
  local idx = first
  local opens, closes = 0, 0
  local text = source:sub(first)
  local pos = 1
  -- crude balance on 'function(' and 'end)' / 'end' within the handler
  local stop
  for line_start, line in text:gmatch("()([^\n]*)\n") do
    if line:find("function", 1, true) then opens = opens + 1 end
    if line:match("^%s*end%)%s*$") or line:match("^%s*end,?%s*$") then closes = closes + 1 end
    if line:match("^    end%)%s*$") and closes >= 1 and closes >= opens - 0 then stop = line_start + #line; break end
  end
  last = first + (stop or 0)
end
local handlerSource = source:sub(first, last)

local function check(cond, msg) if not cond then error("CHECK FAILED: " .. msg, 2) end end

local timers = {}
_G.C_Timer = { After = function(delay, fn) timers[#timers + 1] = { delay = delay, fn = fn } end }

local updates, shown = 0, true
local previewFrame = {
  plate = { Show = function() end },
  IsShown = function() return shown end,
  UpdatePreview = function() updates = updates + 1 end,
  SetScript = function(self, name, fn) self[name] = fn end,
}
local chunk = assert(loadstring("local previewFrame = ...\n" .. handlerSource))
chunk(previewFrame)

previewFrame.OnShow(previewFrame)
check(updates == 1, "an immediate update runs on show")
check(#timers >= 2, "follow-up updates are scheduled after the client lays the plate out")
for _, t in ipairs(timers) do t.fn() end
check(updates == 1 + #timers, "each follow-up refreshes the preview while it is open")

-- Closing the panel before the follow-ups fire must not touch a hidden preview.
timers, updates, shown = {}, 0, true
previewFrame.OnShow(previewFrame)
shown = false
for _, t in ipairs(timers) do t.fn() end
check(updates == 1, "no follow-up refresh once the preview is hidden")

print("preview_first_open_test OK")
