-- Exercise real catalog sorting/refreshes through the existing UI mock.
local env = assert(loadfile("tests/test_config.lua"))()
local NS, ui = env.NS, env.ui
local createFrame, refreshFrame = NS.CreateFrame
NS.CreateFrame = function(...)
    local frame = createFrame(...)
    local register = frame.RegisterEvent
    frame.RegisterEvent = function(self, event, ...)
        if event == "TRAIT_CONFIG_UPDATED" then refreshFrame = self end
        return register(self, event, ...)
    end
    return frame
end
-- Fresh module locals let the mock observe the event registration without
-- reaching into production upvalues or replacing its refresh implementation.
assert(loadfile("GUI/TalentBuildsPanel.lua"))("BetterSBA", NS)
local owner = ui.createFrame("Frame", nil, ui.uiParent)
owner:SetSize(972, 900)
owner:SetPoint("CENTER", ui.uiParent, "CENTER", 0, 0)
local state = NS.BuildTalentBuildsConfigSection(owner)
NS.CreateFrame = createFrame
owner:Show()

NS.db.talentBuildUseDefaultSort = false
local function sorted(column, ascending)
    NS.db.talentBuildSortColumn, NS.db.talentBuildSortAscending = column, ascending
    return state:GetSortedRows({
        { name = "Zulu", rating = "B" }, { name = "Alpha", rating = "S" },
        { name = "Middle", rating = "A" }, { name = "Beta", rating = "A" },
    })
end
assert(sorted("name", true)[1].name == "Alpha" and sorted("name", false)[1].name == "Zulu")
local rated = sorted("rating", true)
assert(rated[1].rating == "S" and rated[2].name == "Beta" and rated[4].rating == "B")
assert(sorted("rating", false)[1].rating == "B", "rating direction must reverse without contradictory comparisons")

local copies, realCopy = 0, CopyTable
CopyTable = function(...) copies = copies + 1; return realCopy(...) end
state:Refresh()
CopyTable = realCopy
assert(copies == 0, "catalog refresh must not recursively copy build metadata")
local originals = {}
for _, row in ipairs(state.rows) do originals[row] = true end
for _, row in ipairs(state.filteredRows) do
    assert(originals[row], "sorting/filtering must preserve read-only row identities")
end

local timers, refreshes = {}, 0
NS.C_Timer_After = function(_, callback) timers[#timers + 1] = callback end
local refresh = state.Refresh
state.Refresh = function(self, ...) refreshes = refreshes + 1; return refresh(self, ...) end
local onEvent = assert(refreshFrame):GetScript("OnEvent")
for _ = 1, 100 do onEvent(refreshFrame, "TRAIT_CONFIG_UPDATED", 1) end
assert(#timers == 1 and refreshes == 0, "an event burst must schedule one deferred refresh")
timers[1](); timers = {}
assert(refreshes == 1, "one hundred trait events must produce one panel refresh")
owner:Hide()
onEvent(refreshFrame, "TRAIT_CONFIG_UPDATED", 1)
timers[1](); timers = {}
assert(refreshes == 1, "hidden panels must not rebuild on trait events")
owner:Show()
onEvent(refreshFrame, "TRAIT_CONFIG_UPDATED", 1)
NS.RefreshTalentBuildPanels()
assert(refreshes == 2, "explicit refreshes must remain synchronous")
timers[1]()
assert(refreshes == 2, "a synchronous refresh satisfies an already queued event refresh")
print("talent panel: 100 events -> 1 refresh; recursive row copies 0; name/rating directions valid")
