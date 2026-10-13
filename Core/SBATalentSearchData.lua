local ADDON_NAME, NS = ...

-- Reviewed public example-profile searches only. Raw profiles/reports stay local.
-- This is best among tested full exports, never an exhaustive talent optimum.
NS.SBA_TALENT_SEARCH_DATA = {
    [269] = {
        classToken = "MONK", testedAt = "2026-10-12", patch = "12.1.0", clientBuild = "69933",
        level = 90, seconds = 180, iterations = 2000, candidateCount = 2,
        profileLabel = "Public MID2 example; Rune of Unleashed Fire omitted from Omnium talents.",
        profileURL = "https://github.com/simulationcraft/simc/blob/af05b9e2e1e50ad5b50f255d7189161dcc058554/profiles/MID2/MID2_Monk_Windwalker.simc",
        engineVersion = "1210-01", engineRevision = "af05b9e",
        hotfixHash = "d5e7cb8e06ef3d8e0435041537862ff3e70a48cff43dbd9e602e906149d69651",
        profileSHA256 = "a61992bf79afebac91ed28a25c620d90fdd6dbd697d5481a02db587985ae3e23", traitsSHA256 = "3f58211f59d4304f019f12c1e359a7862410c97461caa91b12398f4d00c46e2a",
        scenarios = {
            [1] = { state = "ready", choices = { "USER-SBA-269-MID2-SPEC-20261012" }, results = {
                { buildID = "USER-SBA-269-MID2-SPEC-20261012", name = "SimC MID2 Spec With Anchor Class And Hero",
                    importString = "C0QAAAAAAAAAAAAAAAAAAAAAAMzYw2MmhlZGbzAAAAAAAAAAAAsMMTYGGGwMGmZmZY2GmhZZmAAWMz2MDzMzMAA2AQzys0MzMLAYgZGAGLDED4DA",
                    dps = 167803.8502978563, error = 371.4662737694436, samples = 1999 },
                { buildID = "USER-SBA-269-META-20260924", name = "User Windwalker SBA Target",
                    importString = "C0QAAAAAAAAAAAAAAAAAAAAAAMzYAMGbzMz2MAAAAAAAAAAAALDzEmhhBMjhZmZGmthZYWmJAgFzsNzMmZmZAAsBgmlZpZmZWAwAzMAMWGIGwA",
                    dps = 155677.5477260031, error = 333.52957394166896, samples = 1999 },
            } },
            [5] = { state = "ready", choices = { "USER-SBA-269-META-20260924" }, results = {
                { buildID = "USER-SBA-269-META-20260924", name = "User Windwalker SBA Target",
                    importString = "C0QAAAAAAAAAAAAAAAAAAAAAAMzYAMGbzMz2MAAAAAAAAAAAALDzEmhhBMjhZmZGmthZYWmJAgFzsNzMmZmZAAsBgmlZpZmZWAwAzMAMWGIGwA",
                    dps = 377564.50954369066, error = 583.2489185006752, samples = 1999 },
                { buildID = "USER-SBA-269-MID2-SPEC-20261012", name = "SimC MID2 Spec With Anchor Class And Hero",
                    importString = "C0QAAAAAAAAAAAAAAAAAAAAAAMzYw2MmhlZGbzAAAAAAAAAAAAsMMTYGGGwMGmZmZY2GmhZZmAAWMz2MDzMzMAA2AQzys0MzMLAYgZGAGLDED4DA",
                    dps = 365005.296570497, error = 765.2874343412528, samples = 1999 },
            } },
        },
    },
}

-- Adapt a complete source specialization plan while retaining the user's class
-- and hero allocations. Choosing/spending still goes through live client APIs.
local catalog = NS.TALENT_BUILD_CATALOG and NS.TALENT_BUILD_CATALOG.entries
if catalog then
    catalog[#catalog + 1] = {
        id = "USER-SBA-269-MID2-SPEC-20261012", classToken = "MONK", specID = 269,
        name = "Windwalker Monk - Shado-Pan (SBA One-Target Candidate)",
        author = "BetterSBA", rating = "", source = "Custom", catalogSource = "Custom",
        patch = "12.1.0", checkedAt = "2026-10-12", sourcePublishedAt = "2026-10-12",
        verificationStatus = "simulation-tested", heroTree = "Shado-Pan", contentType = "One Target / Example Gear",
        category = "SBA tested candidates", buildType = NS.TALENT_BUILD_TYPE_BUILTIN,
        sourceURL = "https://github.com/simulationcraft/simc/blob/af05b9e2e1e50ad5b50f255d7189161dcc058554/profiles/MID2/MID2_Monk_Windwalker.simc",
        importString = "C0QAAAAAAAAAAAAAAAAAAAAAAMzYw2MmhlZGbzAAAAAAAAAAAAsMMTYGGGwMGmZmZY2GmhZZmAAWMz2MDzMzMAA2AQzys0MzMLAYgZGAGLDED4DA",
        notes = "Complete specialization plan adapted from the pinned official SimC MID2 profile, retaining the September 10 target's class and hero allocation. Tested against that target for SBA with fixed example gear and Rune of Unleashed Fire omitted. Leads on one target; original target leads on five. Not an exhaustive optimum, not personalized DPS, and full live prerequisites remain unverified. Choosing a route and Automatic Points remain separate user decisions.",
    }
end

function NS.GetBestTestedSBABuild(specID, targets)
    targets = targets or 1
    local result = { state = "unavailable", scenario = targets, candidateCount = 0, choices = {},
        reason = "No matching talent comparison yet.",
        details = "Builds need a separate SBA comparison for this specialization and encounter. You can still choose a build manually." }
    local data = NS.SBA_TALENT_SEARCH_DATA[specID]
    local scenario = data and data.scenarios and data.scenarios[targets]
    if not data or not scenario then return result end

    result.candidateCount = #(scenario.results or {})
    local lines = {
        "Best Among Tested SBA Builds", "",
        targets == 1 and "One Target" or "Five Targets",
        "Compared using example gear at level " .. data.level .. "; " .. data.seconds .. " second fights.",
        data.profileLabel,
        "Tested " .. data.testedAt .. " with " .. data.patch .. " build " .. data.clientBuild .. ".",
        "Class and hero talents match the anchor build. Specialization utility can differ.",
        "These supplied full exports are source-qualified; SimulationCraft cannot certify live talent legality.",
        "This did not scan every possible allocation, and another character's gear can change the result.",
        "Results include simultaneous 95% confidence intervals for mean simulated DPS, not individual fights.",
    }
    for _, row in ipairs(scenario.results or {}) do
        lines[#lines + 1] = (row.name or row.buildID) .. ": " .. ("%.0f +/- %.0f DPS"):format(row.dps, row.error)
    end
    result.details = table.concat(lines, "\n")

    local version, build
    if GetBuildInfo then version, build = GetBuildInfo() end
    local patch = type(version) == "string" and (version:match("^(%d+%.%d+%.%d+)$")
        or version:match("^(%d+%.%d+%.%d+)%.%d+$"))
    if patch ~= data.patch or not build or tostring(build) ~= data.clientBuild then
        result.state, result.reason = "stale", "These tests do not match your current client patch and build."
        return result
    end
    if result.candidateCount < 2 then
        result.state, result.reason = "single-candidate", "Only one build was tested; there is no winner to compare."
        return result
    end
    -- Catalog edits/removals invalidate evidence instead of silently applying
    -- an export that was not actually simulated. Check every tested candidate.
    local candidates = {}
    for _, row in ipairs(scenario.results) do
        local entry = NS.FindTalentBuildByID and NS.FindTalentBuildByID(row.buildID)
        if not entry or entry.specID ~= specID or entry.classToken ~= data.classToken
            or entry.importString ~= row.importString then
            result.reason = "A tested build changed or is missing. New comparison tests are needed."
            return result
        end
        candidates[row.buildID] = { buildID = row.buildID, name = entry.name, importString = row.importString }
    end
    if scenario.state ~= "ready" and scenario.state ~= "tie" then
        result.reason = "The comparison is incomplete or its model warnings need review."
        return result
    end
    for _, buildID in ipairs(scenario.choices or {}) do
        if not candidates[buildID] then
            result.reason = "The comparison's selected candidate is missing."
            result.choices = {}
            return result
        end
        result.choices[#result.choices + 1] = candidates[buildID]
    end
    if (scenario.state == "ready" and #result.choices ~= 1)
        or (scenario.state == "tie" and #result.choices < 2) then
        result.reason, result.choices = "The comparison result is incomplete.", {}
        return result
    end
    result.state = scenario.state
    result.reason = result.state == "tie" and "These builds are too close to call. Choose explicitly if you prefer one."
        or "One build leads among the tested candidates for this example setup."
    return result
end
