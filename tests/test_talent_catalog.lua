-- Offline catalog integrity: WoW exports pack little-endian bits into base64
-- characters, not the conventional byte-oriented base64 encoding.
local NS = {}
assert(loadfile("Core/TalentBuildData.lua"))("BetterSBA", NS)
assert(loadfile("Core/LazyGripTalentBuildData.lua"))("BetterSBA", NS)
assert(loadfile("Core/TalentPriorityData.lua"))("BetterSBA", NS)
local hasLazyGripSource = false
for _, source in ipairs(NS.TALENT_BUILD_SOURCES) do
    if source == "LazyGrip" then hasLazyGripSource = true end
end
assert(hasLazyGripSource and NS.TALENT_BUILD_SOURCE_URLS.LazyGrip == "https://lazygrip.net/",
    "LazyGrip talent exports need a visible source filter and source link")
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local values = {}
for i = 1, #alphabet do values[alphabet:sub(i, i)] = i - 1 end
local function header(code)
    assert(type(code) == "string" and #code >= 26 and not code:find("[^A-Za-z0-9+/]"), "invalid export characters/header")
    local bit = 0
    local function read(width)
        local number = 0
        for i = 0, width - 1 do
            local char = code:sub(math.floor(bit / 6) + 1, math.floor(bit / 6) + 1)
            number = number + (math.floor(values[char] / 2 ^ (bit % 6)) % 2) * 2 ^ i
            bit = bit + 1
        end
        return number
    end
    return read(8), read(16)
end
local classes = {
    DEATHKNIGHT={250,251,252}, DEMONHUNTER={577,581,1480}, DRUID={102,103,104,105},
    EVOKER={1467,1468,1473}, HUNTER={253,254,255}, MAGE={62,63,64}, MONK={268,269,270},
    PALADIN={65,66,70}, PRIEST={256,257,258}, ROGUE={259,260,261}, SHAMAN={262,263,264},
    WARLOCK={265,266,267}, WARRIOR={71,72,73},
}
local classBySpec = {}
for class, specs in pairs(classes) do for _, id in ipairs(specs) do classBySpec[id] = class end end
local ids, count, inferred, supplied, legacy, lazygrip = {}, 0, 0, 0, 0, 0
local lazygripCodes = {}
for _, entry in ipairs(NS.TALENT_BUILD_CATALOG.entries) do
    assert(not ids[entry.id], "duplicate catalog ID: " .. entry.id)
    ids[entry.id] = entry
    local version, spec = header(entry.importString)
    assert(version == 2 and spec == entry.specID, "export header/spec mismatch: " .. entry.id)
    assert(classBySpec[spec] == entry.classToken, "class/spec mismatch: " .. entry.id)
    if entry.verificationStatus == "user-provided" then
        assert(entry.notes and entry.notes ~= "", "supplied target needs its limitations recorded")
        assert(entry.checkedAt and entry.checkedAt:match("^%d%d%d%d%-%d%d%-%d%d$"),
            "supplied target needs a catalog review date")
        assert(entry.rating == "", "a player-supplied target is not a comparative ranking")
        supplied = supplied + 1
    elseif entry.verificationStatus == "source-talent" then
        assert(entry.source == "LazyGrip" and entry.catalogSource == "LazyGrip"
            and entry.sourceURL:match("^https://lazygrip%.net/sequences/")
            and entry.patch == "12.1" and entry.checkedAt == "2026-09-24",
            "LazyGrip snapshot needs exact current-patch provenance")
        assert(entry.notes:find("not independently verified for Blizzard SBA", 1, true)
            and not entry.importString:match("^!GRIP") and not entry.importString:match("^!EMS"),
            "GRIP sequence exports must not be presented as SBA talent imports")
        assert(not lazygripCodes[entry.importString], "duplicate LazyGrip talent export")
        lazygripCodes[entry.importString] = true
        lazygrip = lazygrip + 1
    elseif entry.verificationStatus == "source-sba" or entry.verificationStatus == "source-compatible"
        or entry.verificationStatus == "guide-adapted" or entry.verificationStatus == "guide-inferred" then
        assert(entry.sourceURL:match("^https://"), "reviewed entry needs its exact guide URL")
        assert(entry.patch ~= "" and entry.checkedAt:match("^%d%d%d%d%-%d%d%-%d%d$"), "review metadata missing")
        assert(entry.heroTree and entry.notes ~= "", "hero and SBA limitations must be recorded")
        assert(entry.rating == "", "source evidence is not a comparative letter rating")
        if entry.verificationStatus == "guide-inferred" then
            assert(entry.evidenceURL:match("^https://"), "inferred entry needs the related SBA guidance URL")
            inferred = inferred + 1
        else
            count = count + 1
        end
    else
        assert(entry.verificationStatus == "legacy-unverified", "unclassified catalog evidence")
        legacy = legacy + 1
    end
end
assert(legacy == 6, "preserve the six existing Druid imports")
assert(count == 9 and inferred == 14, "reviewed and inferred catalog coverage changed; update the audit alongside the data")
assert(lazygrip == 28, "the current LazyGrip 12.1 talent snapshot changed; review its source audit")
print(("talent catalog: %d source-supported, %d guide-inferred, %d LazyGrip 12.1 talent exports, %d user-provided, and %d legacy exports have valid identities and provenance"):format(count, inferred, lazygrip, supplied, legacy))

local rules, profiles = 0, 0
for spec, guidance in pairs(NS.TALENT_SBA_PRIORITIES) do
    assert(classBySpec[spec], "priority profile needs a real spec")
    assert(guidance.patch:match("^%d+%.%d+$"), "guidance must name its applicable patch")
    local targets = 0
    for id, allowed in pairs(guidance.buildIDs) do
        assert(allowed and ids[id] and ids[id].specID == spec, "priority scope refers to wrong/missing build: " .. id)
        targets = targets + 1
    end
    assert(targets > 0, "guidance may not silently apply to every custom build")
    for spell, rule in pairs(guidance.spells) do
        assert(type(spell) == "number" and spell > 0, "priority requires a spell identity")
        assert(rule.priority > 0 and rule.priority <= 100, "priority outside reviewed range")
        assert(type(rule.name) == "string" and rule.name ~= "", "priority needs a talent name")
        assert(type(rule.reason) == "string" and #rule.reason <= 160, "priority needs a short user-facing reason")
        assert(rule.sourceURL:match("^https://"), "priority needs its supporting source")
        rules = rules + 1
    end
    profiles = profiles + 1
end
assert(profiles == 11 and rules == 78, "reviewed priority coverage changed; update the audit alongside the data")

-- This project adaptation changes only the documented choice bit, leaving
-- the author's remaining export exactly intact. This is not a DPS assertion.
local fire = ids["BSBA-WH-SBA-COMPATIBLE-63-TARGETED-20260924"]
local original = "C8DAAAAAAAAAAAAAAAAAAAAAAYGGLzMzswMzIzMzAAAwAAmZmmltlZAA2MzM2mZmZGLAAAAAYxMjZAAgZMmZmZMzsMAMzQGjBMDjB"
assert(fire and fire.verificationStatus == "guide-adapted", "the Fire adaptation must be identified honestly")
assert(#fire.importString == #original, "Fire adaptation changed the export length")
for bit = 0, #original * 6 - 1 do
    local index, shift = math.floor(bit / 6) + 1, bit % 6
    local before = math.floor(values[original:sub(index, index)] / 2 ^ shift) % 2
    local after = math.floor(values[fire.importString:sub(index, index)] / 2 ^ shift) % 2
    assert((before ~= after) == (bit == 534), "Fire adaptation changed an unintended talent bit")
end
assert(NS.TALENT_SBA_PRIORITIES[63].spells[1254851], "adapted targeted Flamestrike needs its reviewed guidance")
print(("talent priorities: %d rules for %d specs have bounded target scope and source links"):format(rules, profiles))
