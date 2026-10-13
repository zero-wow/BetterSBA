local NS = {}
assert(loadfile("Core/TalentBuildData.lua"))("BetterSBA", NS)
assert(loadfile("Core/TalentBuildProvenance.lua"))("BetterSBA", NS)
GetBuildInfo = function() return "12.1.0", "69933" end

-- A date identifies publication-era patch, never demonstrated compatibility.
assert(NS.GetTalentPatchAtPublication("2026-06-23") == "12.0.7")
assert(NS.GetTalentPatchAtPublication("2026-08-26") == "12.1.0")
assert(NS.GetTalentPatchAtPublication("2026-09-10") == "12.1.0")
assert(NS.GetTalentPatchAtPublication("2026-01-19") == nil)
assert(NS.GetTalentPatchAtPublication("2026-02-30") == nil)
assert(NS.GetTalentPatchAtPublication("2026-2-2") == nil)
assert(NS.GetTalentPatchAtPublication("2026-09-10", "KR") == nil)
assert(NS.GetTalentPatchAtPublication("2026-08-11") == nil)
assert(NS.GetTalentPatchAtPublication("2026-08-12") == nil)
assert(NS.GetTalentPatchAtPublication("2026-08-12", "US") == "12.1.0")
assert(NS.GetTalentPatchAtPublication("2026-08-11", "EU") == "12.0.7")
assert(NS.GetTalentPatchAtPublication("2026-10-14") == nil,
    "announced patches and future dates must not become confirmed publication metadata")

local byID = {}
for _, entry in ipairs(NS.TALENT_BUILD_CATALOG.entries) do byID[entry.id] = entry end
local current = assert(byID["USER-SBA-269-META-20260924"])
assert(current.importString == "C0QAAAAAAAAAAAAAAAAAAAAAAMzYAMGbzMz2MAAAAAAAAAAAALDzEmhhBMjhZmZGmthZYWmJAgFzsNzMmZmZAAsBgmlZpZmZWAwAzMAMWGIGwA",
    "keep the selected route ID and exact supplied import")
local info = NS.GetTalentBuildSourceInfo(current)
assert(info.label == "Current Patch" and info.dateOnly and info.targetPatch == "12.1.0")
assert(info.publishedAt == "2026-09-10" and not info.declaredPatch)
assert(info.summary:find("meta performance are unverified", 1, true))
assert(NS.GetTalentBuildSourceInfo(current, "12.1.5").outdated,
    "freshness must change with the actual client patch, not a frozen cutoff")
for _, kind in ipairs({"DUNGEONS", "RAIDS"}) do
    local old = assert(byID["USER-SBA-269-SHADOPAN-" .. kind .. "-20260623"])
    local source = NS.GetTalentBuildSourceInfo(old)
    assert(source.outdated and source.label == "Outdated")
    assert(source.declaredPatch == "12.0.5" and source.postedPatch == "12.0.7")
    assert(source.publishedAt == "2026-06-23")
    assert(source.summary:find("different patch", 1, true))
    assert(NS.GetTalentBuildDisplayName(old):match("^%[Outdated%] "))
    assert(#old.importString == 110 and old.heroTree == "Shado-Pan")
end
assert(NS.GetTalentBuildSourceInfo({patch="12.1"}).label == "Current Patch")
assert(NS.GetTalentBuildSourceInfo({patch="12.1.5"}).label == "Newer Patch")
assert(NS.GetTalentBuildSourceInfo({checkedAt="2026-10-12"}).label == "Patch Unverified")
assert(NS.GetTalentBuildSourceInfo({checkedAt="2026-10-12"}).publishedAt == nil)
GetBuildInfo = nil
assert(NS.GetTalentBuildSourceInfo(current).label == "Client Patch Unknown")
assert(NS.GetTalentBuildSourceInfo({id=NS.TALENT_BUILD_CUSTOM_ID}).label == "Custom Talents")
print("talent provenance: publication dates, patch boundaries, unknowns and archived routes passed")
