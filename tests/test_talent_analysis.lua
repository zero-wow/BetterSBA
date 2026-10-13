local NS = {}
assert(loadfile("Core/TalentAnalysisData.lua"))("BetterSBA", NS)

local function contains(text, expected)
    assert(text:find(expected, 1, true), "missing: " .. expected)
end

local data = NS.TALENT_ANALYSIS_DATA[269]
assert(data.candidateCount == 1 and data.iterations == 1000 and data.measuredSamples == 999)
assert(data.seconds == 180 and data.patch == "12.1.0" and data.clientBuild == "69933")
assert(data.engineRevision == "af05b9e" and data.hotfixDate == "2026-10-07")
assert(data.testedAt == "2026-10-12" and data.confidence == 0.95)
assert(data.scenarios[1].targets == 1 and data.scenarios[2].targets == 5)
assert(data.scenarios[1].results[1].dps == 160211.6026486126)
assert(data.scenarios[2].results[3].dps == 807888.0377972396)
for specID in pairs(NS.TALENT_ANALYSIS_DATA) do assert(specID == 269, "Do not invent untested specialization results") end

GetBuildInfo = function() return "12.1.0", "69933" end
local matching = NS.GetTalentClassInfoText(269)
contains(matching, "Status: Matching Patch")
contains(matching, "Simulated Estimates")
contains(matching, "160,212 DPS (+/- 440)")
contains(matching, "807,888 DPS (+/- 1,225)")
contains(matching, "did not search for the best talents")
contains(matching, "Custom Button Layouts - Not Tested")
contains(matching, "does not prove a two-button setup works")
contains(matching, "does not select this build or spend points")
contains(matching, "Rune of Unleashed Fire")
contains(matching, "confidence intervals for mean simulated DPS")
GetBuildInfo = function() return "12.1.0", "69934" end
contains(NS.GetTalentClassInfoText(269), "Status: Needs Retest")

GetBuildInfo = function() return "12.1.5" end
local newer = NS.GetTalentClassInfoText(269)
contains(newer, "Status: Needs Retest")
contains(newer, "historical results are not a current recommendation")
GetBuildInfo = function() return "12.0.5" end
contains(NS.GetTalentClassInfoText(269), "Status: Needs Retest")
GetBuildInfo = function() return "12.1.0.69933" end
contains(NS.GetTalentClassInfoText(269), "Status: Matching Patch")

GetBuildInfo = nil
contains(NS.GetTalentClassInfoText(269), "Status: Client Patch Unverified")
GetBuildInfo = function() return nil end
contains(NS.GetTalentClassInfoText(269), "Status: Client Patch Unverified")

local untested = NS.GetTalentClassInfoText(250)
contains(untested, "Not Tested")
assert(not untested:find("DPS", 1, true), "Untested specs must not show numeric damage results")
contains(NS.GetTalentClassInfoText(), "Not Tested")
NS.GetTalentBuildCurrentSpecID = function() return 269 end
contains(NS.GetTalentClassInfoText(), "Windwalker Monk")
print("talent analysis tests passed")
