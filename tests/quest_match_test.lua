-- Lua 5.1 test: objective name matching in data/quest.lua.
-- Usage: lua5.1 tests/quest_match_test.lua  (run from the repo root)
UnitName = function() return "Tester" end
local SQP = { db = { global = {} } }
local chunk = assert(loadfile("data/quest.lua"))
chunk("SimpleQuestPlates", SQP)

local N, M = SQP.NormalizeObjectiveText, SQP.ObjectiveTextMatchesUnit
local failed = 0
local function check(name, got, want)
    if got ~= want then
        failed = failed + 1
        print("FAIL " .. name .. ": got " .. tostring(got) .. ", want " .. tostring(want))
    end
end
local function match(obj, unit) return M(obj, N(unit)) end

check("exact", match("Kobold Worker slain: 0/10", "Kobold Worker"), true)
check("plural s", match("Kobold Workers slain: 0/10", "Kobold Worker"), true)
check("plural ves", match("Timber Wolves slain: 1/8", "Timber Wolf"), true)
check("plural ies", match("Bandit Lackies slain: 1/8", "Bandit Lacky"), true)
check("plural ies y", match("Harpies slain: 1/8", "Harpy"), true)
check("singular from plural plate", match("Kobold Worker slain: 0/10", "Kobold Workers"), true)
check("substring rejected", match("Direwolf slain: 0/5", "Wolf"), false)
check("percent text", match("Escort progress (45%)", "Escort"), true)
check("empty unit", match("Kobold Worker slain: 0/10", ""), false)
check("color codes", match("|cff00ff00Wolf Meat|r: 0/5", "Wolf Meat"), true)

if failed > 0 then os.exit(1) end
print("quest_match_test: ok")
