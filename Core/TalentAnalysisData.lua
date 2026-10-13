local ADDON_NAME, NS = ...

-- Public example-profile evidence only. Never character data or a talent ranking.
NS.TALENT_ANALYSIS_DATA = {
    [269] = {
        specName = "Windwalker Monk",
        testedAt = "2026-10-12",
        patch = "12.1.0",
        clientBuild = "69933",
        hotfixDate = "2026-10-07",
        engineVersion = "1210-01",
        engineRevision = "af05b9e",
        profile = "MID2_Monk_Windwalker",
        profileURL = "https://github.com/simulationcraft/simc/blob/af05b9e/profiles/MID2/MID2_Monk_Windwalker.simc",
        engineURL = "https://github.com/simulationcraft/simc/commit/af05b9e",
        level = 90,
        candidateCount = 1,
        importString = "C0QAAAAAAAAAAAAAAAAAAAAAAMzYAMGbzMz2MAAAAAAAAAAAALDzEmhhBMjhZmZGmthZYWmJAgFzsNzMmZmZAAsBgmlZpZmZWAwAzMAMWGIGwA",
        iterations = 1000,
        measuredSamples = 999,
        seconds = 180,
        confidence = 0.95,
        fightStyle = "Patchwerk",
        raidBuffs = true,
        spellQueue = false,
        scenarios = {
            { targets = 1, label = "One Target", results = {
                { mode = "sba", dps = 160211.6026486126, error = 439.6443990594449 },
                { mode = "sba-cooldowns", dps = 212345.3882299677, error = 483.9471780554814 },
                { mode = "optimized", dps = 252963.91934643118, error = 539.4320607916846 },
            } },
            { targets = 5, label = "Five Targets", results = {
                { mode = "sba", dps = 388037.7829622155, error = 731.9612181543827 },
                { mode = "sba-cooldowns", dps = 543426.9762208263, error = 984.6824026573248 },
                { mode = "optimized", dps = 807888.0377972396, error = 1224.961525627128 },
            } },
        },
    },
}

local modes = {
    sba = "Single-Button Assistant",
    ["sba-cooldowns"] = "SBA With SimC Cooldowns",
    optimized = "SimC Default Rotation",
}

local function Number(value)
    return ("%.0f"):format(value):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function ClientPatch()
    local version, build
    if GetBuildInfo then version, build = GetBuildInfo() end
    if type(version) ~= "string" then return nil end
    return version:match("^(%d+%.%d+%.%d+)$") or version:match("^(%d+%.%d+%.%d+)%.%d+$"),
        build and tostring(build) or version:match("^%d+%.%d+%.%d+%.(%d+)$")
end

function NS.GetTalentClassInfoText(specID)
    specID = specID or (NS.GetTalentBuildCurrentSpecID and NS.GetTalentBuildCurrentSpecID())
    local data = specID and NS.TALENT_ANALYSIS_DATA[specID]
    if not data then
        return table.concat({
            "Class Info", "", "Not Tested", "",
            "No simulation comparison has been recorded for this specialization.",
            "A listed talent build can still be selected for leveling. Its source and patch labels describe what is known about it.",
            "", "What Needs Testing",
            "Compare the same gear and talents with SBA, cooldown handling, and the SimC default rotation in a chosen encounter.",
            "Custom one-button, two-button, GSE, and GRIP-EMS layouts need their own faithful model before comparing them.",
            "", "Your Choice",
            "Class Info does not choose a build, spend points, or change your settings.",
        }, "\n")
    end

    local patch, build = ClientPatch()
    local needsRetest = patch and (patch ~= data.patch or build and build ~= data.clientBuild)
    local status = not patch and "Client Patch Unverified" or needsRetest and "Needs Retest" or "Matching Patch"
    local text = {
        data.specName .. " - Class Info", "", "Simulated Estimates",
        "Status: " .. status,
        "Tested: " .. data.testedAt .. " | Simulation Patch: " .. data.patch,
    }
    if needsRetest then
        text[#text + 1] = "Your client is on " .. patch .. (build and (" build " .. build) or "") .. ". These historical results are not a current recommendation."
    elseif not patch then
        text[#text + 1] = "The client patch could not be read. These results are unverified for your game version."
    else
        text[#text + 1] = build and "The patch and build match; later hotfixes can still change these results."
            or "The patch matches, but the client build is unknown. Hotfixes may change these results."
    end
    text[#text + 1] = "\nWhat This Shows"
    text[#text + 1] = "One talent build, the same example gear, and three ways to use damage abilities. This did not search for the best talents."
    text[#text + 1] = "These are example-gear estimates, not your character's predicted DPS or a winning build."
    for _, scenario in ipairs(data.scenarios) do
        text[#text + 1] = "\n" .. scenario.label .. " - " .. data.seconds .. " Seconds"
        for _, result in ipairs(scenario.results) do
            text[#text + 1] = modes[result.mode] .. ": " .. Number(result.dps) .. " DPS (+/- " .. Number(result.error) .. ")"
        end
    end
    text[#text + 1] = "The +/- values are 95% confidence intervals for mean simulated DPS, not a range for individual fights. They do not cover differences between the simulator and the game."
    text[#text + 1] = "Model Warning: SimulationCraft marks this example gear's Rune of Unleashed Fire behavior as not yet verified. These results remain provisional."
    text[#text + 1] = "\nWhat The Modes Mean"
    text[#text + 1] = "SBA includes the single-button global cooldown penalty. SimC Cooldowns adds the simulator's cooldown handling; it does not prove a two-button setup works."
    text[#text + 1] = "SimC Default Rotation is its normal damage rotation. It is not GSE, GRIP-EMS, or a measurement of how a player performs."
    text[#text + 1] = "\nCustom Button Layouts - Not Tested"
    text[#text + 1] = "One-button and two-button macro layouts, GSE, and GRIP-EMS have not been modeled or compared."
    text[#text + 1] = "\nTest Conditions"
    text[#text + 1] = "Level " .. data.level .. " with the public " .. data.profile .. " example gear; " .. data.fightStyle .. " fights, full raid buffs, and spell queue disabled."
    text[#text + 1] = data.iterations .. " requested iterations; " .. data.measuredSamples .. " measured samples per mode."
    text[#text + 1] = "SimulationCraft " .. data.engineVersion .. " (" .. data.engineRevision .. "); live build " .. data.patch .. "." .. data.clientBuild .. "; hotfix " .. data.hotfixDate .. "."
    text[#text + 1] = "Talents: the supplied September 10 Windwalker SBA Meta Target replaces the example profile's original talents. The exact export is stored with these results. Selecting another build does not update this comparison."
    text[#text + 1] = "\nYour Choice"
    text[#text + 1] = "Class Info does not select this build or spend points. Choose a route and Auto-Spend separately."
    return table.concat(text, "\n")
end
