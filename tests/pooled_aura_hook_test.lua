-- The options preview must not leave a "hide on show" hook on POOLED nameplate unit frames:
-- the client releases the preview's frame to the shared pool and live nameplates reuse it, so a
-- permanent hook hides live debuffs. Runs the real hide/release code from data/options_preview.lua.
local f = assert(io.open("data/options_preview.lua", "r"))
local source = f:read("*a")
f:close()
local first = assert(source:find("local ownedDecorations = {}", 1, true), "ownedDecorations not found")
local marker = "previewFrame.ReleasePreviewDecorations = ReleasePreviewDecorations"
local last = assert(source:find(marker, first, true), "release marker not found") + #marker - 1
local chunk = assert(loadstring("local realPlate, previewFrame = ...\n" .. source:sub(first, last)
  .. "\nreturn HidePreviewDecorations, ReleasePreviewDecorations"))

local function check(cond, msg) if not cond then error("CHECK FAILED: " .. msg, 2) end end

-- A decoration frame that fires its OnShow hooks the way the client does.
local function decoration()
  local d = { shown = true, hooks = {} }
  function d:HookScript(name, fn) if name == "OnShow" then self.hooks[#self.hooks + 1] = fn end end
  function d:Hide() self.shown = false end
  function d:Show() self.shown = true; for _, h in ipairs(self.hooks) do h(self) end end
  return d
end

local unitFrame = { ClassificationFrame = decoration(), RaidTargetFrame = decoration(), AurasFrame = decoration() }
local realPlate = { UnitFrame = unitFrame }
local hide, release = chunk(realPlate, {})

-- While the preview owns the frame its decorations stay hidden, even if the client re-shows them.
hide()
check(not unitFrame.AurasFrame.shown, "preview hides the aura frame")
unitFrame.AurasFrame:Show()
check(not unitFrame.AurasFrame.shown, "the client re-showing it during the preview is suppressed")

-- The preview closes: the pooled frame must be handed back untouched.
release()
check(unitFrame.AurasFrame.shown and unitFrame.ClassificationFrame.shown and unitFrame.RaidTargetFrame.shown,
  "decorations are shown again when the preview releases the frame")

-- A live nameplate now acquires that same pooled frame; the client shows its auras.
unitFrame.AurasFrame.shown = false
unitFrame.AurasFrame:Show()
check(unitFrame.AurasFrame.shown, "a live nameplate reusing the frame keeps its debuffs (the original bug)")
unitFrame.RaidTargetFrame.shown = false
unitFrame.RaidTargetFrame:Show()
check(unitFrame.RaidTargetFrame.shown, "and its raid target icon")

-- Re-opening the preview takes ownership again without stacking hooks.
hide()
check(not unitFrame.AurasFrame.shown, "a second preview hides the decoration again")
check(#unitFrame.AurasFrame.hooks == 1, "the hook is installed only once")
release()

print("pooled_aura_hook_test OK")
