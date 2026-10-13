local ADDON_NAME, NS = ...

-- An optional calm view of the same settings and talent actions as Studio.
local Simple = {}
NS.ConfigSimple = Simple
local SetTextIfChanged = NS.ConfigStudio.UI.SetTextIfChanged
local WHITE = "Interface\\Buttons\\WHITE8X8"
local COLOR = {
    background = { .055, .065, .08, 1 }, button = { .10, .13, .17, 1 },
    border = { .24, .30, .36, 1 }, text = { .91, .93, .95, 1 },
    muted = { .64, .70, .76, 1 }, accent = { .47, .77, .80, 1 },
}
local unpack = NS.unpack or unpack or table.unpack

local function Label(parent, text, x, y, width, size, color, lines)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", size or 13, "")
    label:SetTextColor(unpack(COLOR[color or "text"]))
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    label:SetWordWrap((lines or 1) > 1)
    label:SetMaxLines(lines or 1)
    label:SetHeight(math.ceil((size or 13) * 1.2) * (lines or 1) + 4)
    label:SetText(text)
    return label
end

local function Button(parent, text, x, y, width, callback)
    local button = NS.CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetSize(width, 32)
    button:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    button:SetBackdropColor(unpack(COLOR.button))
    button:SetBackdropBorderColor(unpack(COLOR.border))
    button:RegisterForClicks("LeftButtonUp")
    local textLabel = Label(button, text, 8, -6, width - 16, 13)
    textLabel:SetJustifyH("CENTER")
    button._label = textLabel
    button:SetScript("OnClick", callback)
    button:SetScript("OnEnter", function() button:SetBackdropBorderColor(unpack(COLOR.accent)) end)
    button:SetScript("OnLeave", function() button:SetBackdropBorderColor(unpack(COLOR.border)) end)
    return button
end

local function SetEnabled(button, enabled)
    enabled = enabled == true
    if button._simpleEnabled == enabled then return end
    button._simpleEnabled = enabled
    button:SetEnabled(enabled)
    button:SetAlpha(enabled and 1 or .5)
end

Simple.UI = { Label = Label, Button = Button, SetEnabled = SetEnabled, colors = COLOR }

function Simple:RegisterView(name, view, refresh)
    self.views[name] = view
    if not view._focusDialogCleanup then
        view._focusDialogCleanup = true
        view:HookScript("OnHide", function()
            if NS.HideTalentBuildDialogs then NS.HideTalentBuildDialogs(view) end
        end)
    end
    self.viewRefreshers = self.viewRefreshers or {}
    self.viewRefreshers[name] = refresh
    view:SetShown(self.view == name)
    return view
end

function Simple:CreateView(name)
    if not self.frame then self:Create() end
    if self.views[name] then return self.views[name] end
    local view = NS.CreateFrame("Frame", nil, self.frame)
    view:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 20, -78)
    view:SetSize(600, 382)
    return self:RegisterView(name, view)
end

local function Info()
    return NS.GetTalentLevelingInfo and NS.GetTalentLevelingInfo() or {}
end

local function SelectedEntry(info)
    if not info.buildID then return end
    if NS.FindTalentBuildByID then return NS.FindTalentBuildByID(info.buildID) end
    if not NS.GetTalentBuildEntriesForClass then return end
    for _, entry in ipairs(NS.GetTalentBuildEntriesForClass(NS.GetTalentBuildClassToken()) or {}) do
        if entry.id == info.buildID then return entry end
    end
end

function Simple:RequestSpendTalentPoints()
    local info = NS.GetTalentSpendAllInfo()
    if info.hasMismatch and info.canRespec then
        if not self.Confirm then self:Report(false, "Open Points and Rebuilding to review a talent reset."); return end
        self:Confirm("Your learned talents differ from the chosen route. Reset your talents and rebuild that route using only points your current level can spend?", function()
            local ok, message = NS.RequestTalentSBARespec()
            self:Report(ok, message)
        end)
        return
    end
    -- A spend-only click must never become a reset if the tree changes.
    local ok, message = NS.SpendAllTalentPoints()
    self:Report(ok, message)
end

function Simple:SelectTalentTarget(entry, onSelected)
    if not entry then return end
    local id, specID, importString = entry.id, entry.specID, entry.importString
    local custom = id == NS.TALENT_BUILD_CUSTOM_ID
    local function Select()
        local current = not custom and NS.FindTalentBuildByID(id)
        if not custom and (not current or current.specID ~= specID or current.importString ~= importString) then
            self:Report(false, "That build changed. Choose it again to review the updated route.")
            return
        end
        local ok, message = NS.SetTalentLevelingTarget(id)
        if ok and onSelected then onSelected() end
        local enabled = Info().enabled
        self:Report(ok, message or (ok and (custom and "Automatic Points turned off. Your current talents are unchanged."
            or enabled and "Build selected. Automatic Points is still on." or "Build selected. Automatic Points is off.")))
    end
    local info = Info()
    if info.enabled and not custom then
        if not self.Confirm then self:Report(false, "Turn off Automatic Points before choosing another route."); return end
        local prompt = "Automatic Points is on. Choosing this route may spend available points right away."
        if info.autoRespecEnabled then prompt = prompt .. " Automatic rebuilding is also on, so conflicting talents may be reset." end
        self:Confirm(prompt .. " Choose this route and leave Automatic Points on?", Select)
    else
        Select()
    end
end

function Simple:SelectView(name)
    if self.CloseDialog then self:CloseDialog() end
    self.view = name
    self.message:SetText("")
    if name == "details" then self.detailScroll:SetVerticalScroll(0) end
    for key, view in pairs(self.views) do view:SetShown(key == name) end
    if self.home then self.home:SetShown(name ~= "main") end
    self:Refresh()
end

function Simple:Report(ok, message)
    self:Refresh()
    self.message:SetText(message or (ok and "Saved." or "Unable to make that change. Open Details for help."))
end

function Simple:Create()
    local frame = NS.CreateFrame("Frame", "BetterSBA_ConfigSimple", NS.UIParent, "BackdropTemplate")
    self.frame = frame
    frame:SetSize(640, 534)
    frame:SetPoint("CENTER", NS.UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame:SetBackdropColor(unpack(COLOR.background))
    frame:SetBackdropBorderColor(unpack(COLOR.border))
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    if type(UISpecialFrames) == "table" then UISpecialFrames[#UISpecialFrames + 1] = "BetterSBA_ConfigSimple" end
    Label(frame, "BetterSBA", 20, -16, 230, 22)
    Label(frame, "Focus Mode", 20, -44, 260, 12, "muted")
    self.close = Button(frame, "Close", 542, -18, 78, function() self:Hide() end)
    self.home = Button(frame, "Home", 454, -18, 78, function() self:SelectView("main") end)
    self.views = {}
    for _, name in ipairs({ "main", "picker", "details" }) do
        local view = NS.CreateFrame("Frame", nil, frame)
        view:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -78)
        view:SetSize(600, 382)
        self:RegisterView(name, view)
    end
    self.message = Label(frame, "", 20, -475, 600, 12, "accent", 3)
    local main, picker, details = self.views.main, self.views.picker, self.views.details
    Label(main, "Your Talent Build", 0, 0, 440, 15, "muted")
    self.buildName = Label(main, "Choose a build to get started.", 0, -26, 600, 16, "text", 2)
    self.choose = Button(main, "Choose a Build", 0, -80, 150, function()
        self.pickerPage = 1
        self:SelectView("picker")
    end)
    Label(main, "Automatic Points", 180, -88, 295, 14)
    self.auto = Button(main, "Off", 526, -80, 74, function()
        local info = Info()
        if not info.buildID then self:SelectView("picker"); return end
        local enabled = not info.enabled
        local ok, message = NS.SetTalentLevelingEnabled(enabled)
        self:Report(ok, message or (ok and (enabled and "New points will be spent when your level allows."
            or "Automatic points turned off.")))
    end)
    self.spend = Button(main, "Spend Points Now", 0, -124, 170, function()
        self:RequestSpendTalentPoints()
    end)
    self.status = Label(main, "", 190, -125, 410, 13, "text", 2)
    self.nextTalent = Label(main, "", 0, -174, 600, 13, "accent")
    Label(main, "Your Button", 0, -212, 440, 15, "muted")
    self.settings = {}
    for index, setting in ipairs({
        { "enabled", "Enable BetterSBA" }, { "locked", "Lock Button Position" },
        { "showPriority", "Show Next Spells" },
    }) do
        local key, title = setting[1], setting[2]
        local y = -239 - (index - 1) * 36
        Label(main, title, 0, y - 8, 490, 14)
        self.settings[key] = Button(main, "Off", 526, y, 74, function()
            NS.db[key] = not NS.db[key]
            if key == "showPriority" and NS.UpdatePriorityDisplay then NS.UpdatePriorityDisplay() end
            if NS.ApplyProfileVisuals then NS:ApplyProfileVisuals() end
            self:Report(true)
        end)
    end
    self.detailsButton = Button(main, "Details", 0, -350, 94, function() self:SelectView("details") end)
    self.classInfo = Button(main, "Class Info", 104, -350, 104, function()
        if NS.ShowTalentClassInfo then
            NS.ShowTalentClassInfo(main, NS.GetTalentBuildCurrentSpecID())
        end
    end)
    self.allSettings = Button(main, "All Settings", 220, -350, 150, function()
        if self.OpenSettings then self:OpenSettings() end
    end)
    self.advanced = Button(main, "Advanced Settings", 422, -350, 178, function()
        self:Hide()
        NS.SwitchSettingsPanel("studio")
        NS.ConfigStudio:SelectPage("Overview")
    end)

    Label(picker, "Choose a Build", 0, 0, 330, 20)
    self.suggestions = Button(picker, "Best Tested for SBA", 400, 0, 200, function()
        if NS.ShowSBATalentSuggestions then
            NS.ShowSBATalentSuggestions(picker, NS.GetTalentBuildCurrentSpecID(), function(_, enabled)
                self:SelectView("main")
                self:Report(true, enabled and "Build selected. Automatic Points is still on."
                    or "Build selected. Turn on Automatic Points when you are ready.")
            end)
        end
    end)
    Label(picker, "Builds for the specialization you are playing.", 0, -40, 600, 12, "muted")
    self.pickerRows = {}
    for index = 1, 4 do
        local row = Button(picker, "", 0, -66 - (index - 1) * 60, 600, function()
            local entry = self.pickerRows[index].entry
            if not entry then return end
            self:SelectTalentTarget(entry, function() self:SelectView("main") end)
        end)
        row:SetHeight(50)
        row._label:SetJustifyH("LEFT")
        row._label:SetWordWrap(true)
        row._label:SetMaxLines(2)
        row._label:SetHeight(38)
        row:HookScript("OnEnter", function()
            if not row.entry or not GameTooltip then return end
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:SetText(row.entry.name, nil, nil, nil, nil, true)
            local source = NS.GetTalentBuildSourceInfo and NS.GetTalentBuildSourceInfo(row.entry)
            if source then GameTooltip:AddLine(source.label, .64, .70, .76, true) end
            GameTooltip:Show()
        end)
        row:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        self.pickerRows[index] = row
    end
    self.previous = Button(picker, "Previous", 0, -318, 96, function()
        self.pickerPage = math.max(1, self.pickerPage - 1); self:Refresh()
    end)
    self.nextPage = Button(picker, "Next", 106, -318, 78, function()
        self.pickerPage = self.pickerPage + 1; self:Refresh()
    end)
    self.pageLabel = Label(picker, "", 205, -327, 195, 12, "muted")
    self.pickerBack = Button(picker, "Back", 512, -318, 88, function() self:SelectView("main") end)

    Label(details, "Talent Details", 0, 0, 420, 20)
    local scroll = NS.CreateFrame("ScrollFrame", nil, details)
    scroll:SetPoint("TOPLEFT", details, "TOPLEFT", 0, -42)
    scroll:SetSize(584, 272)
    scroll:EnableMouseWheel(true)
    local child = NS.CreateFrame("Frame", nil, scroll)
    child:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    child:SetSize(568, 1)
    scroll:SetScrollChild(child)
    self.detailText = Label(child, "", 0, 0, 568, 13, "text", 40)
    self.detailText:SetMaxLines(0)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        scroll:SetVerticalScroll(math.max(0, math.min(math.max(0, child:GetHeight() - scroll:GetHeight()),
            scroll:GetVerticalScroll() - delta * 50)))
    end)
    self.detailScroll, self.detailChild = scroll, child
    self.scrollHint = Label(details, "Scroll for more.", 0, -320, 400, 12, "muted")
    self.detailsBack = Button(details, "Back", 512, -350, 88, function() self:SelectView("main") end)
    self.talentOptions = Button(details, "Talent Options", 0, -350, 146, function()
        if self.OpenSettingsTopic then self:OpenSettingsTopic("Talents"); return end
        self:Hide()
        NS.SwitchSettingsPanel("studio")
        NS.ConfigStudio:SelectPage("Talents")
    end)
    local elapsed = 0
    frame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 1 then elapsed = 0; self:Refresh() end
    end)
    frame:Hide()
    self:SelectView("main")
end

function Simple:Refresh()
    if not self.frame then return end
    if self._profileDB ~= NS.db then
        self._profileDB = NS.db
        if self.CloseDialog then self:CloseDialog() end
        self:ApplyScale()
    end
    local refresh = self.viewRefreshers and self.viewRefreshers[self.view]
    if refresh then refresh(); return end
    if self.view == "picker" then
        local matches = self._pickerMatches or {}
        self._pickerMatches = matches
        for index = #matches, 1, -1 do matches[index] = nil end
        local spec = NS.GetTalentBuildCurrentSpecID()
        for _, entry in ipairs(NS.GetTalentBuildEntriesForClass(NS.GetTalentBuildClassToken()) or {}) do
            if entry.specID == spec then matches[#matches + 1] = entry end
        end
        local pages = math.max(1, math.ceil(#matches / 4))
        self.pickerPage = math.min(pages, self.pickerPage or 1)
        for index, row in ipairs(self.pickerRows) do
            local entry = matches[(self.pickerPage - 1) * 4 + index]
            row.entry = entry
            row:SetShown(entry ~= nil)
            if entry then
                local source = NS.GetTalentBuildSourceInfo and NS.GetTalentBuildSourceInfo(entry)
                SetTextIfChanged(row._label, (source and (source.label .. "  ·  ") or "") .. entry.name)
            end
        end
        SetTextIfChanged(self.pageLabel, #matches == 0 and "No builds available." or (self.pickerPage .. " / " .. pages))
        SetEnabled(self.previous, self.pickerPage > 1)
        SetEnabled(self.nextPage, self.pickerPage < pages)
        return
    end
    local info = Info()
    local entry = SelectedEntry(info)
    if self.view == "details" then
        local source = entry and NS.GetTalentBuildSourceInfo and NS.GetTalentBuildSourceInfo(entry)
        local changed = SetTextIfChanged(self.detailText, table.concat({ info.targetName or "No build selected.",
            info.status or "Choose a build to get started.",
            source and source.summary or "Source information is unavailable.",
            info.detail or "", "Automatic points use only talents your level can learn. Higher-level talents wait until they unlock.",
            "Talent Options includes rebuild, undo and warning settings." }, "\n\n"))
        if changed then
            local height = self.detailText:GetStringHeight() + 12
            self.detailText:SetHeight(height)
            self.detailChild:SetHeight(height)
            self.scrollHint:SetShown(height > self.detailScroll:GetHeight())
            self.detailScroll:SetVerticalScroll(math.min(self.detailScroll:GetVerticalScroll(),
                math.max(0, height - self.detailScroll:GetHeight())))
        end
        return
    end
    local selected = info.buildID ~= nil and info.targetName ~= "No Build Selected"
    SetTextIfChanged(self.buildName, selected and (info.targetName or "Selected Build") or "Choose a build to get started.")
    SetTextIfChanged(self.choose._label, selected and "Change Build" or "Choose a Build")
    SetTextIfChanged(self.auto._label, info.enabled and "On" or "Off")
    SetTextIfChanged(self.status, not selected and "Choose a build, then turn on Automatic Points."
        or info.hasMismatch and "Your talents need attention. Open Details."
        or info.canSpend and (info.enabled and "A point is ready to spend automatically." or "You have a point ready to spend.")
        or info.hasPoints and "Your next talent unlocks later. Your points will wait."
        or not info.settled and "Talents are paused. Open Details to see why."
        or info.enabled and "All set. New points will be spent automatically."
        or "Automatic points are off. You can turn them on above.")
    local source = entry and NS.GetTalentBuildSourceInfo and NS.GetTalentBuildSourceInfo(entry)
    SetTextIfChanged(self.nextTalent, source and source.outdated and "Outdated build — open Details before using it."
        or (info.nextName and info.nextName ~= "—" and ("Next: " .. info.nextName) or ""))
    SetEnabled(self.spend, info.canSpend or info.canRespec)
    SetEnabled(self.classInfo, NS.ShowTalentClassInfo ~= nil)
    for key, button in pairs(self.settings) do SetTextIfChanged(button._label, NS.db[key] and "On" or "Off") end
end

function Simple:ApplyScale()
    if not self.frame then return end
    local preferred = tonumber(NS.db.configPanelScale) or 1
    self.frame:SetScale(math.max(.1, math.min(preferred, (NS.UIParent:GetWidth() - 32) / 640,
        (NS.UIParent:GetHeight() - 32) / 534)))
end

function Simple:Show()
    if not self.frame then self:Create() end
    NS.ConfigStudio:Hide()
    if NS.Config and NS.Config.Hide then NS.Config:Hide() end
    NS.db.configExperience = "focus"
    self:ApplyScale()
    self:SelectView("main")
    self.frame:Show()
end

function Simple:Hide()
    if self.CloseDialog then self:CloseDialog() end
    if self.frame then self.frame:Hide() end
end

function NS.ConfigStudio:OpenFocusMode()
    Simple:Show()
end

local toggleSettings = NS.ToggleSettingsPanel
if toggleSettings then
    function NS.ToggleSettingsPanel(...)
        if Simple.frame and Simple.frame:IsShown() then Simple:Hide(); return end
        if NS.db and NS.db.configExperience == "focus" then Simple:Show(); return end
        return toggleSettings(...)
    end
end

local switchSettings = NS.SwitchSettingsPanel
if switchSettings then
    function NS.SwitchSettingsPanel(experience, ...)
        if experience == "focus" then Simple:Show(); return end
        Simple:Hide()
        return switchSettings(experience, ...)
    end
end
