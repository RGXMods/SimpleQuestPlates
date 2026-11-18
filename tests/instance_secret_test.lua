-- Lua 5.1 test: quest plates inside dungeons, where the client hands addons a secret unit name (and secret tooltip
-- text) instead of the mob's name. The plate must still show the remaining count instead of "?".
-- Usage: lua5.1 tests/instance_secret_test.lua  (run from the repo root)

-- A secret value: any comparison or concatenation errors, like the client's.
local SECRET = setmetatable({}, {
    __eq = function() error("attempt to compare a secret value") end,
    __concat = function() error("attempt to concatenate a secret value") end,
    __tostring = function() return "<secret>" end,
})
issecretvalue = function(v) return v == nil and false or rawequal(v, SECRET) end

local secretName = true
UnitName = function(unit)
    if unit == "player" then return "Tester" end
    if secretName then return SECRET end
    return "Defias Pillager"
end
UnitExists = function() return true end
UnitGUID = function() return SECRET end
UnitCanAttack = function() return true end
UnitIsPlayer = function() return false end
GetTimePreciseSec = function() return 100 end

local tooltipText = SECRET
C_TooltipInfo = { GetUnit = function() return { lines = { { leftText = SECRET }, { leftText = tooltipText } } } end }
Enum = nil

-- Quest log: quest 1 is the dungeon quest (on this map), quest 2 is an outdoor quest (elsewhere).
local onMap = { [101] = true }
C_QuestLog = { IsOnMap = function(questID) return onMap[questID] == true, false end }
local log = {
    { questID = 101, objectives = { { text = "Edwin VanCleef slain: 0/1", type = "monster", finished = false },
                                    { text = "Defias Pillager slain: 3/10", type = "monster", finished = false } } },
    { questID = 202, objectives = { { text = "Kobold Worker slain: 2/8", type = "monster", finished = false } } },
}

SQPSettings = {}
local SQP = { db = { global = {} } }
SQP.ActiveWorldQuests = {}
local chunk = assert(loadfile("data/quest.lua"))
chunk("SimpleQuestPlates", SQP)
SQP.Compat = {
    GetNumQuestLogEntries = function() return #log end,
    GetInfo = function(i) local q = log[i]; return q and { questID = q.questID, isHeader = false, isHidden = false, isComplete = false } end,
    GetQuestObjectives = function(questID)
        for _, q in ipairs(log) do if q.questID == questID then return q.objectives end end
        return {}
    end,
    IsQuestRelatedUnit = function() return true end,
}
SQP.PrintMessage = function() end

local failed = 0
local function check(name, cond, detail)
    if not cond then failed = failed + 1; print("FAIL " .. name .. (detail and (": " .. detail) or "")) end
end

-- 1. Secret name, secret tooltip, two kill objectives on the dungeon map: still ambiguous (no guessing), but the
--    outdoor quest must not count against it, and the call must not error.
local ok, glob, qtype, kills, items = pcall(SQP.GetQuestProgress, SQP, "nameplate1")
check("secret name does not error", ok, tostring(glob))

-- 2. One kill objective left on this map: the dungeon quest's count is shown, the outdoor quest is ignored.
log[1].objectives[1].finished = true
SQP._questCacheRev = (SQP._questCacheRev or 0) + 1
ok, glob, qtype, kills, items = pcall(SQP.GetQuestProgress, SQP, "nameplate1")
check("on-map objective resolves", ok and kills == 7, "kills=" .. tostring(kills) .. " glob=" .. tostring(glob))
check("outdoor quest ignored", ok and glob == "Defias Pillager slain: 3/10", tostring(glob))

-- 3. Secret name but readable tooltip text: the tooltip's objective line is used.
log[1].objectives[1].finished = false
tooltipText = "Edwin VanCleef slain: 0/1"
SQP._questCacheRev = SQP._questCacheRev + 1
ok, glob, qtype, kills = pcall(SQP.GetQuestProgress, SQP, "nameplate1")
check("tooltip read despite secret name", ok and glob == "Edwin VanCleef slain: 0/1" and kills == 1, tostring(glob))

-- 4. Outside instances (readable name), name matching still picks the right objective.
secretName = false
tooltipText = SECRET
SQP._questCacheRev = SQP._questCacheRev + 1
ok, glob, qtype, kills = pcall(SQP.GetQuestProgress, SQP, "nameplate1")
check("readable name matches its objective", ok and glob == "Defias Pillager slain: 3/10" and kills == 7, tostring(glob))

if failed > 0 then os.exit(1) end
print("instance_secret_test: ok")
