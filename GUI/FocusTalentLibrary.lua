local ADDON_NAME, NS = ...
local Simple = NS.ConfigSimple
local PAGE_SIZE = 4
local SORTS = { "Name A-Z", "Name Z-A", "Spec A-Z", "Source A-Z", "Rating Best" }
local RATINGS = { S = 5, A = 4, B = 3, C = 2, D = 1 }
local unpack = NS.unpack or unpack or table.unpack
local SetText = NS.ConfigStudio.UI.SetTextIfChanged

local function Source(entry)
    return NS.GetTalentBuildSourceInfo and NS.GetTalentBuildSourceInfo(entry)
        or { label = "Patch Unverified", summary = "Source patch is unverified." }
end

local function SourceName(entry)
    return entry.catalogSource or entry.source or "Unknown"
end

local function Selected(state)
    if state.selectedID == NS.TALENT_BUILD_CUSTOM_ID then
        return NS.GetTalentBuildCustomEntry(state.selectedSpecID, NS.GetTalentBuildSpecName(state.selectedSpecID))
    end
    return state.selectedID and NS.FindTalentBuildByID(state.selectedID)
end

local function Collect(state)
    local entries = NS.GetTalentBuildEntriesForClass(NS.GetTalentBuildClassToken()) or {}
    local current = NS.GetTalentBuildCurrentSpecID()
    local rows, sources, seen = {}, {}, {}
    if current then rows[1] = NS.GetTalentBuildCustomEntry(current, NS.GetTalentBuildSpecName(current)) end
    for _, entry in ipairs(entries) do
        rows[#rows + 1] = entry
        local source = SourceName(entry)
        if not seen[source] then seen[source] = true; sources[#sources + 1] = source end
    end
    table.sort(sources)
    state.sources = sources
    if state.sourceFilter and not seen[state.sourceFilter] then state.sourceFilter = nil end
    local spec = state.specFilter == "current" and current or state.specFilter
    local query, matches = (state.search or ""):lower():match("^%s*(.-)%s*$"), {}
    for _, entry in ipairs(rows) do
        local source = Source(entry)
        local search = table.concat({ entry.name or "", NS.GetTalentBuildSpecName(entry.specID) or "",
            SourceName(entry), entry.author or "", entry.notes or "", entry.category or "",
            entry.rating or "", source.label or "", source.summary or "" }, " "):lower()
        local custom = entry.id == NS.TALENT_BUILD_CUSTOM_ID
        local typeMatch = state.typeFilter == "all" or custom
            or (state.typeFilter == "personal" and entry.buildType == NS.TALENT_BUILD_TYPE_USER)
            or (state.typeFilter == "catalog" and entry.buildType == NS.TALENT_BUILD_TYPE_BUILTIN)
        if (spec == "all" or entry.specID == spec) and typeMatch
            and (not state.sourceFilter or SourceName(entry) == state.sourceFilter)
            and (query == "" or search:find(query, 1, true)) then matches[#matches + 1] = entry end
    end
    table.sort(matches, function(a, b)
        local av, bv = a.name or "", b.name or ""
        if state.sort == 3 then av, bv = NS.GetTalentBuildSpecName(a.specID) or "", NS.GetTalentBuildSpecName(b.specID) or ""
        elseif state.sort == 4 then av, bv = SourceName(a), SourceName(b)
        elseif state.sort == 5 then av, bv = RATINGS[a.rating] or 0, RATINGS[b.rating] or 0 end
        if type(av) == "string" then av, bv = av:lower(), bv:lower() end
        if av ~= bv then
            if state.sort == 2 or state.sort == 5 then return av > bv end
            return av < bv
        end
        return tostring(a.id) < tostring(b.id)
    end)
    state.matches = matches
    state.pages = math.max(1, math.ceil(#matches / PAGE_SIZE))
    state.page = math.max(1, math.min(state.page, state.pages))
end

local function RefreshBrowse(state)
    Collect(state)
    local current = NS.GetTalentBuildCurrentSpecID()
    local specText = state.specFilter == "current" and "Current Specialization"
        or state.specFilter == "all" and "All Specializations" or NS.GetTalentBuildSpecName(state.specFilter)
    SetText(state.spec._label, specText or "Specialization Unavailable")
    SetText(state.kind._label, state.typeFilter == "all" and "All Builds" or state.typeFilter == "personal" and "My Builds" or "Catalog Builds")
    SetText(state.source._label, state.sourceFilter or "All Sources")
    SetText(state.sortButton._label, SORTS[state.sort])
    for index, row in ipairs(state.rows) do
        local entry = state.matches[(state.page - 1) * PAGE_SIZE + index]
        row.entry = entry
        row:SetShown(entry ~= nil)
        if entry then
            SetText(row._label, entry.name or "Unnamed Build")
            SetText(row.meta, (NS.GetTalentBuildSpecName(entry.specID) or "Unknown Spec") .. " · " .. Source(entry).label
                .. (entry.specID ~= current and " · Other Spec" or ""))
        end
    end
    state.empty:SetShown(#state.matches == 0)
    SetText(state.pageLabel, ("%d builds · Page %d of %d"):format(#state.matches, state.page, state.pages))
    Simple.UI.SetEnabled(state.previous, state.page > 1)
    Simple.UI.SetEnabled(state.next, state.page < state.pages)
end

local function RefreshDetail(state)
    local entry = Selected(state)
    state.entry = entry
    local current = entry and entry.specID == NS.GetTalentBuildCurrentSpecID()
    local custom = entry and entry.id == NS.TALENT_BUILD_CUSTOM_ID
    local info = NS.GetTalentLevelingInfo() or {}
    SetText(state.title, entry and entry.name or "This build is no longer available.")
    local text = "Return to the library to choose another build."
    if entry then
        local source = Source(entry)
        text = source.summary .. "\n" .. (NS.GetTalentBuildSpecName(entry.specID) or "Unknown Spec")
            .. " · " .. SourceName(entry) .. " · " .. (entry.buildType or "Build")
        if entry.author and entry.author ~= "" then text = text .. "\nAuthor: " .. entry.author end
        if entry.rating and entry.rating ~= "" then text = text .. " · Source Rating: " .. entry.rating end
        if entry.verificationStatus == "simulation-tested" then
            text = text .. "\nSimulated estimates with example gear. Not a player-specific result or a proven best build."
        elseif not custom then text = text .. "\nA current patch label does not verify SBA performance." end
        if entry.notes and entry.notes ~= "" then text = text .. "\n\n" .. entry.notes end
    end
    if SetText(state.body, text) then
        local height = math.max(108, state.body:GetStringHeight() + 6)
        state.body:SetHeight(height)
        state.bodyChild:SetHeight(height)
        state.bodyScroll:SetVerticalScroll(math.min(state.bodyScroll:GetVerticalScroll(), height - 108))
    end
    state.scrollHint:SetShown(state.bodyChild:GetHeight() > 108)
    SetText(state.leveling._label, custom and "Stop Automatic Points" or "Use for Leveling")
    SetText(state.apply._label, custom and "Keep Current Talents" or current and "Apply Full Build" or "Switch Spec & Apply")
    SetText(state.consent, not entry and "" or custom and "Keeps your current talents. Stopping Automatic Points turns off talent spending."
        or not current and "Switch Spec & Apply changes specialization and imports the full build. Leveling requires your current specialization."
        or (info.enabled and "Automatic Points is ON: choosing a leveling target may spend available points. "
            or "Automatic Points is OFF: choosing a leveling target leaves it off. ")
            .. "Apply Full Build imports the full talent build.")
    Simple.UI.SetEnabled(state.leveling, current == true)
    Simple.UI.SetEnabled(state.apply, entry ~= nil)
    Simple.UI.SetEnabled(state.sourceDetails, entry ~= nil and not custom)
    Simple.UI.SetEnabled(state.copy, entry ~= nil and not custom)
    Simple.UI.SetEnabled(state.edit, entry ~= nil and entry.buildType == NS.TALENT_BUILD_TYPE_USER)
    Simple.UI.SetEnabled(state.delete, entry ~= nil and entry.buildType == NS.TALENT_BUILD_TYPE_USER)
    Simple.UI.SetEnabled(state.classInfo, entry ~= nil and NS.ShowTalentClassInfo ~= nil)
end

local function CreateLibrary()
    local UI = Simple.UI
    local browse, detail = Simple:CreateView("library"), Simple:CreateView("libraryDetail")
    local state = { page = 1, specFilter = "current", typeFilter = "all", sort = 1, rows = {} }
    Simple.talentLibrary = state
    state.browse, state.detail = browse, detail
    local function refreshFilter() state.page = 1; RefreshBrowse(state) end
    local function inspect(entry)
        state.selectedID, state.selectedSpecID = entry.id, entry.specID
        state.bodyScroll:SetVerticalScroll(0)
        Simple:SelectView("libraryDetail")
    end
    state.editorState = { Refresh = function(editor)
        state.selectedID, state.selectedSpecID = editor.selectedID, editor.selectedSpecID
        state.bodyScroll:SetVerticalScroll(0)
        Simple:SelectView("libraryDetail")
        Simple:Report(true, "Saved to your personal library. No talents were applied.")
    end }
    for _, view in ipairs({ browse, detail }) do
        view:HookScript("OnHide", function()
            if state.searchBox then state.searchBox:ClearFocus() end
            if GameTooltip then GameTooltip:Hide() end
        end)
    end
    UI.Label(browse, "Talent Library", 0, 0, 410, 20)
    state.create = UI.Button(browse, "Create / Import", 450, 0, 150, function()
        NS.ShowTalentBuildEditor(browse, state.editorState, "create")
    end)
    state.spec = UI.Button(browse, "", 0, -40, 194, function()
        local choices = { "current", "all" }
        for _, spec in ipairs(NS.GetTalentBuildSpecsForCurrentClass()) do choices[#choices + 1] = spec.specID end
        local index = 1
        for i, choice in ipairs(choices) do if choice == state.specFilter then index = i; break end end
        state.specFilter = choices[index % #choices + 1]; refreshFilter()
    end)
    state.kind = UI.Button(browse, "", 206, -40, 130, function()
        state.typeFilter = state.typeFilter == "all" and "catalog" or state.typeFilter == "catalog" and "personal" or "all"
        refreshFilter()
    end)
    state.source = UI.Button(browse, "", 348, -40, 252, function()
        local nextSource = state.sources[1]
        for i, value in ipairs(state.sources) do if value == state.sourceFilter then nextSource = state.sources[i + 1]; break end end
        state.sourceFilter = nextSource; refreshFilter()
    end)
    UI.Label(browse, "Search", 0, -87, 56, 12, "muted")
    local search = NS.CreateFrame("EditBox", nil, browse, "BackdropTemplate")
    search:SetPoint("TOPLEFT", browse, "TOPLEFT", 62, -80)
    search:SetSize(352, 32)
    search:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
    search:SetTextInsets(8, 8, 0, 0)
    search:SetAutoFocus(false)
    search:SetMaxLetters(160)
    search:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    search:SetBackdropColor(unpack(UI.colors.background))
    search:SetBackdropBorderColor(unpack(UI.colors.border))
    search:SetTextColor(unpack(UI.colors.text))
    search:SetScript("OnEscapePressed", search.ClearFocus)
    search:SetScript("OnTextChanged", function() state.search = search:GetText(); refreshFilter() end)
    state.searchBox = search
    state.sortButton = UI.Button(browse, "", 426, -80, 174, function()
        state.sort = state.sort % #SORTS + 1; refreshFilter()
    end)
    for index = 1, PAGE_SIZE do
        local row = UI.Button(browse, "", 0, -124 - (index - 1) * 52, 600, function()
            local entry = state.rows[index].entry
            if entry then inspect(entry) end
        end)
        row:SetHeight(46)
        row._label:SetJustifyH("LEFT")
        row.meta = UI.Label(row, "", 8, -26, 584, 11, "muted")
        row:HookScript("OnEnter", function()
            if row.entry and GameTooltip then
                GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                GameTooltip:SetText(row.entry.name, nil, nil, nil, nil, true)
                GameTooltip:AddLine("Select to inspect. This does not apply talents.", .64, .70, .76, true)
                GameTooltip:Show()
            end
        end)
        row:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        state.rows[index] = row
    end
    state.empty = UI.Label(browse, "No matching builds. Change the filters or search.", 8, -144, 584, 13, "muted", 2)
    state.previous = UI.Button(browse, "Previous", 0, -350, 96, function() state.page = math.max(1, state.page - 1); RefreshBrowse(state) end)
    state.next = UI.Button(browse, "Next", 106, -350, 76, function() state.page = math.min(state.pages, state.page + 1); RefreshBrowse(state) end)
    state.pageLabel = UI.Label(browse, "", 198, -358, 304, 12, "muted")
    state.back = UI.Button(browse, "Back", 512, -350, 88, function() Simple:SelectView("main") end)

    UI.Label(detail, "Build Details", 0, 0, 400, 20)
    state.detailBack = UI.Button(detail, "Back", 512, 0, 88, function() Simple:SelectView("library") end)
    state.title = UI.Label(detail, "", 0, -46, 600, 16, "text", 2)
    local scroll = NS.CreateFrame("ScrollFrame", nil, detail)
    scroll:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -100)
    scroll:SetSize(600, 108)
    scroll:EnableMouseWheel(true)
    local child = NS.CreateFrame("Frame", nil, scroll)
    child:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    child:SetSize(584, 108)
    scroll:SetScrollChild(child)
    state.body = UI.Label(child, "", 0, 0, 584, 12, "muted", 30)
    state.body:SetMaxLines(0)
    state.bodyScroll, state.bodyChild = scroll, child
    scroll:SetScript("OnMouseWheel", function(_, delta)
        scroll:SetVerticalScroll(math.max(0, math.min(child:GetHeight() - 108, scroll:GetVerticalScroll() - delta * 40)))
    end)
    state.scrollHint = UI.Label(detail, "Scroll for source notes.", 0, -212, 600, 11, "muted")
    state.leveling = UI.Button(detail, "", 0, -238, 194, function()
        local entry = Selected(state)
        if not entry or entry.specID ~= NS.GetTalentBuildCurrentSpecID() then return end
        Simple:SelectTalentTarget(entry)
    end)
    state.apply = UI.Button(detail, "", 206, -238, 194, function()
        local entry = Selected(state)
        if not entry then return end
        local ok = NS.RequestTalentBuildApply(entry.id, { specID = entry.specID, reason = "focus-library-apply",
            loadAnyway = entry.specID ~= NS.GetTalentBuildCurrentSpecID() })
        local status = NS.GetTalentBuildLastStatus and NS.GetTalentBuildLastStatus(entry.specID)
        Simple:Report(ok, ok and status and status.text or (ok and "Talent change requested."
            or "Unable to apply. Check the build and wait for any current talent change to finish."))
    end)
    state.sourceDetails = UI.Button(detail, "Source & Notes", 412, -238, 188, function()
        local entry = Selected(state)
        if entry then NS.ShowTalentBuildSource(detail, entry) end
    end)
    state.consent = UI.Label(detail, "", 0, -282, 600, 12, "text", 3)
    state.edit = UI.Button(detail, "Edit", 0, -350, 90, function()
        local entry = Selected(state)
        if entry and entry.buildType == NS.TALENT_BUILD_TYPE_USER then NS.ShowTalentBuildEditor(detail, state.editorState, "edit", entry) end
    end)
    state.copy = UI.Button(detail, "Copy Build", 100, -350, 110, function()
        local entry = Selected(state)
        if entry and entry.id ~= NS.TALENT_BUILD_CUSTOM_ID then NS.ShowTalentBuildEditor(detail, state.editorState, "copy", entry) end
    end)
    state.delete = UI.Button(detail, "Delete", 220, -350, 90, function()
        NS.RequestTalentBuildDelete(detail, Selected(state), function(ok)
            if ok then state.selectedID = nil; Simple:SelectView("library") end
            Simple:Report(ok, ok and "Deleted from your personal library." or "Unable to delete this build.")
        end)
    end)
    state.classInfo = UI.Button(detail, "Class Info", 412, -350, 188, function()
        local entry = Selected(state)
        if entry and NS.ShowTalentClassInfo then NS.ShowTalentClassInfo(detail, entry.specID) end
    end)
    Simple:RegisterView("library", browse, function() RefreshBrowse(state) end)
    Simple:RegisterView("libraryDetail", detail, function() RefreshDetail(state) end)
end

function Simple:OpenTalentLibrary()
    if not self.frame or not self.frame:IsShown() then self:Show() end
    if not self.talentLibrary then CreateLibrary() end
    self:SelectView("library")
end
