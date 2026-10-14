-- Read-only suggestion selection, provenance invalidation and uncertainty.
local ns = {}
local version, build = "12.1.0", "69933"
GetBuildInfo = function() return version, build end
assert(loadfile("Core/TalentBuildData.lua"))("BetterSBA", ns)
assert(loadfile("Core/SBATalentSearchData.lua"))("BetterSBA", ns)
ns.FindTalentBuildByID = function(id)
    for _, entry in ipairs(ns.TALENT_BUILD_CATALOG.entries) do if entry.id == id then return entry end end
end
local published = ns.GetBestTestedSBABuild(269, 1)
assert(published.state == "ready" and published.candidateCount == 2
    and published.choices[1].buildID == "USER-SBA-269-MID2-SPEC-20261012",
    "shipped single-target evidence must resolve the adapted catalog entry")
assert(ns.GetBestTestedSBABuild(269, 5).choices[1].buildID == "USER-SBA-269-META-20260924",
    "shipped five-target evidence must resolve the original user target")
version, build = "12.1.5", "70391"
for _, targets in ipairs({1, 5}) do
    local historical = ns.GetBestTestedSBABuild(269, targets)
    assert(historical.state == "stale" and #historical.choices == 0,
        "12.1.0 example results must not offer a recommended build on 12.1.5")
end
version, build = "12.1.0", "69933"
local entries = {
    a = { id = "a", specID = 269, classToken = "MONK", name = "Anchor", importString = "code-a" },
    b = { id = "b", specID = 269, classToken = "MONK", name = "Candidate", importString = "code-b" },
}
ns.FindTalentBuildByID = function(id) return entries[id] end
local results = {
    { buildID = "a", name = "Anchor", importString = "code-a", dps = 100, error = 2 },
    { buildID = "b", name = "Candidate", importString = "code-b", dps = 120, error = 2 },
}
local data = { patch = "12.1.0", clientBuild = "69933", classToken = "MONK", level = 90,
    seconds = 180, profileLabel = "Synthetic fixture", testedAt = "2026-10-12",
    scenarios = {
        [1] = { state = "ready", choices = { "b" }, results = results },
        [5] = { state = "tie", choices = { "a", "b" }, results = results },
    } }
ns.SBA_TALENT_SEARCH_DATA[269] = data
assert(ns.GetBestTestedSBABuild(270, 1).state == "unavailable")
assert(ns.GetBestTestedSBABuild(269, 2).state == "unavailable")
local best = ns.GetBestTestedSBABuild(269, 1)
assert(best.state == "ready" and best.choices[1].buildID == "b" and best.candidateCount == 2)
assert(best.details:find("cannot certify live talent legality", 1, true), "legality caveat must remain explicit")
local tied = ns.GetBestTestedSBABuild(269, 5)
assert(tied.state == "tie" and #tied.choices == 2, "ties retain explicit alternatives")
version = "12.1.5"
assert(ns.GetBestTestedSBABuild(269, 1).state == "stale")
version, build = "12.1.0", "69934"
assert(ns.GetBestTestedSBABuild(269, 1).state == "stale", "exact build matters")
build = nil
assert(ns.GetBestTestedSBABuild(269, 1).state == "stale", "unknown client build must fail closed")
version, build = "12.1.0junk", "69933"
assert(ns.GetBestTestedSBABuild(269, 1).state == "stale")
version = "12.1.0.69933"
assert(ns.GetBestTestedSBABuild(269, 1).state == "ready")
entries.a.importString = "edited"
assert(ns.GetBestTestedSBABuild(269, 1).state == "unavailable", "edits to any tested candidate invalidate comparisons")
entries.a.importString = "code-a"
entries.b.specID = 270
assert(ns.GetBestTestedSBABuild(269, 1).state == "unavailable", "candidate spec identity must match")
entries.b.specID = 269
data.scenarios[1].choices = { "missing" }
assert(ns.GetBestTestedSBABuild(269, 1).state == "unavailable")
data.scenarios[1].choices = {}
assert(ns.GetBestTestedSBABuild(269, 1).state == "unavailable", "empty ready choice must fail closed")
data.scenarios[1].results = { results[1] }
assert(ns.GetBestTestedSBABuild(269, 1).state == "single-candidate")
assert(entries.a.importString == "code-a" and entries.b.importString == "code-b",
    "viewing suggestions must never edit catalog entries or talent state")
print("PASS: current/stale/missing/tied/single-candidate suggestion evidence and exact import identity")
