local ADDON_NAME, NS = ...

-- Regional live-release dates, reviewed against Blizzard announcements.
-- Never use catalog ingestion/review dates as source publication dates.
NS.TALENT_PATCH_TIMELINE = {
    reviewedThrough = "2026-10-14",
    releases = {
        { patch = "12.0.0", us = "2026-01-20", eu = "2026-01-21", article = "24244455" },
        { patch = "12.0.1", us = "2026-02-10", eu = "2026-02-11", article = "24247153", euArticle = "24257263" },
        { patch = "12.0.5", us = "2026-04-21", eu = "2026-04-22", article = "24272610" },
        { patch = "12.0.7", us = "2026-06-16", eu = "2026-06-17", article = "24280281" },
        { patch = "12.1.0", us = "2026-08-11", eu = "2026-08-12", article = "24294370", euArticle = "24295086" },
        { patch = "12.1.5", us = "2026-10-13", eu = "2026-10-14", article = "24307306" },
    },
}

local function Patch(value)
    if type(value) ~= "string" then return nil end
    local major, minor, revision = value:match("^(%d+)%.(%d+)%.(%d+)$")
    if not major then major, minor = value:match("^(%d+)%.(%d+)$"); revision = "0" end
    if not major then return nil end
    major, minor, revision = tonumber(major), tonumber(minor), tonumber(revision)
    return ("%d.%d.%d"):format(major, minor, revision), major * 1000000 + minor * 1000 + revision
end

local function Date(value)
    if type(value) ~= "string" then return nil end
    local year, month, day = value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    if not year or month < 1 or month > 12 then return nil end
    local leap = year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
    local days = {31, leap and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
    return day >= 1 and day <= days[month] and value or nil
end

function NS.GetTalentPatchAtPublication(publishedAt, region)
    local date = Date(publishedAt)
    local timeline = NS.TALENT_PATCH_TIMELINE
    if not date then return nil, "Post Date Unknown" end
    if date > timeline.reviewedThrough then return nil, "Release Timeline Needs Review" end
    if region and region ~= "US" and region ~= "EU" then return nil, "Region Not Reviewed" end
    local found
    for _, release in ipairs(timeline.releases) do
        local boundary = region == "US" and release.us or region == "EU" and release.eu
        -- Screenshots show local dates, without server region/timezone.
        -- A maintenance-day post alone cannot establish pre/post-update.
        if boundary and date == boundary or not boundary and date >= release.us and date <= release.eu then
            return nil, "Patch Transition Date"
        end
        if release.scheduled then
            -- Reviewing today must not silently assign yesterday's patch when
            -- an announced release has not yet been confirmed.
            if date > (boundary or release.eu) then return nil, "Release Date Unverified" end
        else
            if date > (boundary or release.eu) then found = release.patch end
        end
    end
    if found then return found end
    return nil, "Release Date Unverified"
end

function NS.GetTalentBuildSourceInfo(entry, clientVersion)
    entry = entry or {}
    local info = { label = "Patch Unverified", summary = "Patch Unverified", outdated = false }
    if entry.id == NS.TALENT_BUILD_CUSTOM_ID then
        info.label, info.summary = "Custom Talents", "Your current talent choices."
        return info
    end
    info.publishedAt = Date(entry.sourcePublishedAt)
    info.postedPatch, info.dateStatus = NS.GetTalentPatchAtPublication(info.publishedAt, entry.sourceRegion)
    info.declaredPatch = entry.patchBasis ~= "publication-date" and Patch(entry.patch) or nil
    info.targetPatch = info.declaredPatch or info.postedPatch
    info.dateOnly = not info.declaredPatch and info.postedPatch ~= nil
    if clientVersion == nil and GetBuildInfo then clientVersion = GetBuildInfo() end
    info.clientPatch = Patch(clientVersion)
    local _, target = Patch(info.targetPatch)
    local _, current = Patch(info.clientPatch)
    if target and current then
        info.outdated = target < current
        info.label = target < current and "Outdated" or target > current and "Newer Patch" or "Current Patch"
    elseif target then
        info.label = "Client Patch Unknown"
    end
    local details = { info.label }
    details[#details + 1] = "Posted: " .. (info.publishedAt or "Unknown")
    if info.declaredPatch then details[#details + 1] = "Guide Patch: " .. info.declaredPatch end
    details[#details + 1] = info.postedPatch and ("Posted During: " .. info.postedPatch) or info.dateStatus
    if info.dateOnly then details[#details + 1] = "Patch inferred from date; compatibility and meta performance are unverified."
    elseif info.declaredPatch and info.postedPatch and info.declaredPatch ~= info.postedPatch then
        details[#details + 1] = "The guide names an older or different patch than its posting date."
    end
    if info.clientPatch then details[#details + 1] = "Your Client: " .. info.clientPatch end
    info.summary = table.concat(details, " · ")
    return info
end

function NS.GetTalentBuildDisplayName(entry)
    local info = NS.GetTalentBuildSourceInfo(entry)
    return (info.outdated and "[Outdated] " or "") .. (entry.name or "Custom")
end
