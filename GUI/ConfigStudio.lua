local ADDON_NAME, NS = ...

-- A separate, task-oriented settings surface. The original panel remains the
-- complete editor and can be reached from every page of this one.
NS.ConfigStudio = { page = "Overview" }
local Studio = NS.ConfigStudio
local WHITE = "Interface\\Buttons\\WHITE8X8"
local ART = "Interface\\AddOns\\BetterSBA\\IMG\\Button\\TalentSpendAll"
local C = {
    shell = { .075, .087, .115, 1 }, rail = { .055, .071, .095, 1 },
    body = { .085, .098, .125, 1 }, card = { .105, .122, .157, 1 },
    border = { .27, .31, .38, 1 }, gutter = { .025, .035, .055, 1 },
    accent = { .69, .50, .86, 1 }, bright = { .92, .88, .98, 1 },
    text = { .88, .90, .94, 1 }, dim = { .61, .66, .73, 1 },
    muted = { .43, .48, .56, 1 }, cyan = { .55, .82, .89, 1 },
}
local NAV = { "Overview", "Combat", "Button & Queue", "Motion", "Talents", "Profiles" }
local CLASSIC_SECTION = { Overview = 1, Combat = 1, ["Button & Queue"] = 3,
    Motion = 2, Talents = 5, Profiles = 9 }

local function Paint(parent, color, point, relative, x, y, w, h)
    local t = parent:CreateTexture(nil, "BACKGROUND")
    t:SetTexture(WHITE)
    t:SetVertexColor(NS.unpack(color))
    if point then t:SetPoint(point, relative or parent, point, x or 0, y or 0) end
    if w and h then t:SetSize(w, h) else t:SetAllPoints() end
    return t
end

local function Label(parent, value, size, color, width, point, relative, relativePoint, x, y)
    local f = parent:CreateFontString(nil, "OVERLAY")
    f:SetFont(NS.GetConfigFontPath(), size, "")
    f:SetTextColor(NS.unpack(color or C.text))
    f:SetText(value or "")
    if width then f:SetWidth(width) end
    f:SetJustifyH("LEFT")
    f:SetWordWrap(false)
    f:SetMaxLines(1)
    f:SetPoint(point or "TOPLEFT", relative or parent, relativePoint or point or "TOPLEFT", x or 0, y or 0)
    return f
end

local function FitText(label, value, width)
    value = tostring(value or "")
    label:SetText(value)
    if label:GetStringWidth() <= width then return end
    while #value > 1 do
        value = value:sub(1, -2)
        label:SetText(value .. "…")
        if label:GetStringWidth() <= width then return end
    end
end

local function Surface(parent, x, y, w, h, fill)
    local f = NS.CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    f:SetSize(w, h)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f:SetBackdropColor(NS.unpack(fill or C.card))
    f:SetBackdropBorderColor(NS.unpack(C.border))
    return f
end

local function Action(parent, value, x, y, w, h, callback, tone)
    local b = NS.CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetSize(w, h)
    b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    b:SetBackdropColor(NS.unpack(tone == "quiet" and C.body or C.card))
    b:SetBackdropBorderColor(NS.unpack(C.border))
    local label = Label(b, value, 12, C.text, w - 16, "CENTER", b, "CENTER", 0, 0)
    label:SetJustifyH("CENTER")
    b._label = label
    b:SetScript("OnClick", callback)
    b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(NS.unpack(C.accent)) end)
    b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(NS.unpack(C.border)) end)
    return b
end

local function Caption(parent, value, x, y)
    local tab = Surface(parent, x, y, 170, 22, C.accent)
    tab:SetBackdropBorderColor(NS.unpack(C.accent))
    Label(tab, value, 10, C.gutter, 148, "LEFT", tab, "LEFT", 9, 0)
    return tab
end

local function Setting(parent, name, note, y, getter, setter, copyWidth)
    local row = NS.CreateFrame("Button", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, y)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, y)
    row:SetHeight(52)
    Label(row, name, 12, C.text, copyWidth or 250, "TOPLEFT", row, "TOPLEFT", 0, -5)
    Label(row, note, 10, C.dim, copyWidth or 290, "TOPLEFT", row, "TOPLEFT", 0, -24)
    local track = Surface(row, 0, 0, 42, 22, C.rail)
    track:ClearAllPoints()
    track:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    local thumb = Paint(track, C.muted, "LEFT", track, 4, 0, 14, 14)
    row.Refresh = function()
        local on = getter() == true
        track:SetBackdropColor(NS.unpack(on and C.accent or C.rail))
        thumb:ClearAllPoints()
        thumb:SetPoint(on and "RIGHT" or "LEFT", track, on and "RIGHT" or "LEFT", on and -4 or 4, 0)
        thumb:SetVertexColor(NS.unpack(on and C.bright or C.muted))
    end
    row:SetScript("OnClick", function() setter(not getter()); row.Refresh() end)
    row.Refresh()
    return row
end

local function OpenClassic(section, makeDefault)
    if makeDefault then NS.db.configExperience = "classic" end
    Studio:Hide()
    NS.Config:Show()
    if NS.Config.SelectSection then NS.Config.SelectSection(section or 1) end
end

function NS.SwitchSettingsPanel(which)
    local studio = which == "studio"
    NS.db.configExperience = studio and "studio" or "classic"
    if studio then
        NS.Config:Hide()
        Studio:Show()
    else
        Studio:Hide()
        NS.Config:Show()
    end
end

function NS.ToggleSettingsPanel()
    if Studio.frame and Studio.frame:IsShown() then Studio:Hide(); return end
    if NS.Config.frame and NS.Config.frame:IsShown() then NS.Config:Hide(); return end
    if NS.db.configExperience == "studio" then Studio:Show() else NS.Config:Show() end
end

local function BuildGeneralPage(self, page, headline, intro, entries, advancedSection)
    local content = self.content
    local view = NS.CreateFrame("Frame", nil, content)
    view:SetAllPoints()
    self.pages[page] = view
    Caption(view, page, 26, -27)
    Label(view, headline, 27, C.bright, 610, "TOPLEFT", view, "TOPLEFT", 26, -64)
    Label(view, intro, 12, C.dim, 620, "TOPLEFT", view, "TOPLEFT", 26, -101)
    local box = Surface(view, 26, -156, 622, 400)
    view._quickBox = box
    Label(box, "Quick Controls", 10, C.accent, 290, "TOPLEFT", box, "TOPLEFT", 18, -19)
    Paint(box, C.border, "TOPLEFT", box, 18, -43, 585, 1)
    local refreshers = {}
    for i, entry in ipairs(entries) do
        local y = -56 - (i - 1) * 72
        local getter = type(entry[3]) == "function" and entry[3]
            or function() return NS.db[entry[3]] end
        local setter = type(entry[3]) == "function" and entry[4]
            or function(value)
                NS.db[entry[3]] = value
                if entry[4] then entry[4]() end
            end
        local row = Setting(box, entry[1], entry[2], y, getter, setter)
        refreshers[#refreshers + 1] = row.Refresh
    end
    local more = Action(view, "Open Detailed Settings", 26, -580, 210, 34,
        function() OpenClassic(advancedSection) end)
    Label(view, "Every setting remains available in Classic Settings.", 11, C.muted, 350,
        "LEFT", more, "RIGHT", 16, 0)
    view.Refresh = function() for _, fn in ipairs(refreshers) do fn() end end
    return view
end

local function BuildTalentPage(self)
    local view = NS.CreateFrame("Frame", nil, self.content)
    view:SetAllPoints()
    self.pages.Talents = view
    Caption(view, "Talents", 26, -24)
    Label(view, "Leveling Talents", 28, C.bright, 500, "TOPLEFT", view, "TOPLEFT", 26, -62)
    Label(view, "Choose a route once. BetterSBA spends only points your level can use.", 11,
        C.dim, 610, "TOPLEFT", view, "TOPLEFT", 26, -102)

    local route = Surface(view, 26, -128, 622, 124)
    view._route = route
    Paint(route, C.accent, "TOPLEFT", route, 0, 0, 3, 124)
    Label(route, "Current Route", 10, C.accent, 120, "TOPLEFT", route, "TOPLEFT", 16, -14)
    local routeName = Label(route, "Choose a Build", 18, C.bright, 365, "TOPLEFT", route, "TOPLEFT", 16, -38)
    view._routeName = routeName
    route:EnableMouse(true)
    route:SetScript("OnEnter", function()
        local info = NS.GetTalentLevelingInfo()
        if not info.targetName then return end
        GameTooltip:SetOwner(route, "ANCHOR_RIGHT")
        GameTooltip:SetText(info.targetName)
        GameTooltip:Show()
    end)
    route:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local routeDetail = Label(route, "Select a build for your current specialization.", 10, C.dim,
        365, "TOPLEFT", route, "TOPLEFT", 16, -71)
    local routeMeta = Label(route, "Class and spec points are handled together.", 10, C.muted,
        365, "TOPLEFT", route, "TOPLEFT", 16, -96)
    local spend = NS.CreateFrame("Button", nil, route)
    spend:SetSize(205, 48)
    spend:SetPoint("TOPRIGHT", route, "TOPRIGHT", -13, -22)
    local art = spend:CreateTexture(nil, "BACKGROUND")
    art:SetAllPoints()
    art:SetTexture(ART)
    Label(spend, "Spend Available Points", 11, C.bright, 185, "CENTER", spend, "CENTER", 0, 0):SetJustifyH("CENTER")
    local change = Action(route, "Change Build", 0, 0, 128, 25, function() end, "quiet")
    view._change = change
    change:ClearAllPoints()
    change:SetPoint("TOPRIGHT", route, "TOPRIGHT", -51, -85)

    local left = Surface(view, 26, -270, 305, 286)
    local right = Surface(view, 343, -270, 305, 286)
    view._left, view._right = left, right
    Caption(left, "What Happens Next", 0, 0)
    Caption(right, "Automation & Safety", 0, 0)
    local state = Label(left, "Choose a Build", 16, C.text, 270, "TOPLEFT", left, "TOPLEFT", 16, -43)
    local status = Label(left, "", 11, C.dim, 270, "TOPLEFT", left, "TOPLEFT", 16, -75)
    view._status = status
    status:SetWordWrap(true)
    status:SetMaxLines(3)
    local next = Label(left, "Next Talent: —", 11, C.cyan, 270, "TOPLEFT", left, "TOPLEFT", 16, -142)
    Label(left, "Class and spec points spend when legal.", 10, C.dim, 270,
        "TOPLEFT", left, "TOPLEFT", 16, -195)
    Label(left, "Hero talents wait for their unlock.", 10, C.dim, 270,
        "TOPLEFT", left, "TOPLEFT", 16, -222)
    local auto = Setting(right, "Auto-Spend New Points", "No approval for each rank.", -36,
        function() return NS.GetTalentLevelingInfo().enabled end,
        function(value)
            local ok, err = NS.SetTalentLevelingEnabled(value)
            if not ok then self.notice:SetText(err or "Unable to change auto-spend.") end
            self:Refresh()
        end, 200)
    view._auto = auto
    local warn = Setting(right, "Warn If Talents Differ", "Alert before a rebuild.", -99,
        function() return NS.GetTalentLevelingInfo().warningEnabled end,
        function(value) NS.SetTalentSBAWarningEnabled(value); self:Refresh() end, 200)
    local autoRebuild = Setting(right, "Auto-Rebuild on Mismatch", "Runs when Auto-Spend is on.", -162,
        function() return NS.GetTalentLevelingInfo().autoRespecEnabled end,
        function(value) NS.SetTalentAutoRespecEnabled(value); self:Refresh() end, 200)
    view._autoRebuild = autoRebuild
    local rebuild = Action(right, "Reset & Rebuild", 18, -237, 133, 32, function()
        local ok, message = NS.RequestTalentSBARespec()
        self.notice:SetText(message or (ok and "Rebuild started." or "Unable to rebuild talents."))
        self:Refresh()
    end)
    local undo = Action(right, "Undo Respec", 161, -237, 125, 32, function()
        local ok, message = NS.RequestTalentSBAUndo()
        self.notice:SetText(message or (ok and "Undo started." or "Nothing to undo."))
        self:Refresh()
    end, "quiet")
    Caption(view, "Build Library", 26, -574)
    local browse = Action(view, "Browse Builds and Imports", 26, -606, 219, 32,
        function() OpenClassic(5) end)
    view._browse = browse
    Label(view, "Review source and build details before choosing.", 11, C.muted, 325,
        "LEFT", browse, "RIGHT", 14, 0)

    local picker = Surface(view, 26, -128, 425, 240, C.shell)
    picker:SetFrameLevel(view:GetFrameLevel() + 12)
    picker:Hide()
    Label(picker, "Builds for This Spec", 10, C.accent, 260, "TOPLEFT", picker, "TOPLEFT", 14, -12)
    local rows = {}
    local pickerPage = 1
    for i = 1, 4 do
        local rowIndex = i
        rows[i] = Action(picker, "", 14, -35 - (i - 1) * 42, 397, 36, function()
            local entry = rows[rowIndex].entry
            if not entry then return end
            local ok, err = NS.SetTalentLevelingTarget(entry.id)
            if ok then
                picker:Hide()
                view._selectionError = nil
            else
                view._selectionError = err or "Unable to choose build."
            end
            self.notice:SetText(ok and ("Selected " .. entry.name .. ".") or (err or "Unable to choose build."))
            self:Refresh()
        end, "quiet")
    end
    view._pickerRows = rows
    local previous = Action(picker, "Previous", 14, -207, 85, 24, function() pickerPage = math.max(1, pickerPage - 1); picker.Refresh() end)
    local nextPage = Action(picker, "Next", 326, -207, 85, 24, function() pickerPage = pickerPage + 1; picker.Refresh() end)
    local pageLabel = Label(picker, "", 10, C.dim, 180, "CENTER", picker, "CENTER", 0, -98)
    pageLabel:SetJustifyH("CENTER")
    picker.Refresh = function()
        local all = NS.GetTalentBuildEntriesForClass(NS.GetTalentBuildClassToken()) or {}
        local spec = NS.GetTalentBuildCurrentSpecID()
        local matches = {}
        for _, entry in ipairs(all) do
            if entry.specID == spec then matches[#matches + 1] = entry end
        end
        local pages = math.max(1, math.ceil(#matches / 4))
        pickerPage = math.min(pickerPage, pages)
        for i, row in ipairs(rows) do
            local entry = matches[(pickerPage - 1) * 4 + i]
            row.entry = entry
            row:SetShown(entry ~= nil)
            if entry then row._label:SetText(entry.name) end
        end
        pageLabel:SetText(pickerPage .. " / " .. pages)
        previous:SetShown(pickerPage > 1)
        nextPage:SetShown(pickerPage < pages)
    end
    change:SetScript("OnClick", function()
        if picker:IsShown() then picker:Hide() else picker.Refresh(); picker:Show() end
    end)
    spend:SetScript("OnClick", function()
        local ok, message = NS.SpendAllOrRespecTalentPoints()
        self.notice:SetText(message or (ok and "Spending available talent points." or "No eligible points to spend."))
        self:Refresh()
    end)
    view._spend = spend
    view._picker = picker
    spend:SetScript("OnEnter", function() art:SetVertexColor(1, 1, 1, .82) end)
    spend:SetScript("OnLeave", function() art:SetVertexColor(1, 1, 1, 1) end)
    view.Refresh = function()
        local info = NS.GetTalentLevelingInfo()
        FitText(routeName, info.targetName or "Choose a Build", routeName:GetWidth())
        routeDetail:SetText(info.specName and ("Active Specialization: " .. info.specName) or "Current specialization")
        routeMeta:SetText(info.enabled and "Auto-spend is on for this route." or "Hero points wait until they unlock.")
        state:SetText(info.canSpend and "Points Ready to Spend" or (info.hasMismatch and "Talents Differ From Route" or "Current Status"))
        status:SetText(view._selectionError or info.status or "Choose a build to get started.")
        next:SetText("Next Talent: " .. (info.nextName or "—"))
        auto.Refresh()
        warn.Refresh()
        autoRebuild.Refresh()
        local undoInfo = NS.GetTalentSBAUndoInfo()
        undo:SetAlpha(undoInfo.canUndo and 1 or .45)
        undo:SetEnabled(undoInfo.canUndo == true)
        rebuild:SetAlpha(info.canRespec and 1 or .45)
        rebuild:SetEnabled(info.canRespec == true)
        spend:SetAlpha((info.canSpend or info.canRespec) and 1 or .55)
        spend:SetEnabled(info.canSpend or info.canRespec)
    end
    return view
end

function Studio:Create()
    local w = math.max(900, math.min(1300, tonumber(NS.db.configStudioWidth) or 1120))
    local h = math.max(760, math.min(900, tonumber(NS.db.configStudioHeight) or 790))
    local f = NS.CreatePanel("BetterSBA_ConfigStudio", NS.UIParent, w, h)
    self.frame = f
    f:SetBackdropColor(NS.unpack(C.shell))
    f:SetBackdropBorderColor(NS.unpack(C.border))
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:SetResizable(true)
    f:SetResizeBounds(900, 760, 1300, 900)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:EnableMouse(true)
    local header = NS.CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(66)
    Paint(header, C.card)
    local topLine = Paint(header, C.accent, "TOPLEFT", header, 0, 0, w, 3)
    topLine:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 0)
    Label(header, "BetterSBA", 20, C.bright, 165, "LEFT", header, "LEFT", 19, 0)
    Label(header, "Settings", 10, C.muted, 100, "LEFT", header, "LEFT", 180, -2)
    local profile = Label(header, "", 11, C.dim, 220, "RIGHT", header, "RIGHT", -50, 0)
    profile:SetJustifyH("RIGHT")
    self.profileLabel = profile
    local close = Action(header, "X", 0, 0, 28, 28, function() f:Hide() end)
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", header, "TOPRIGHT", -12, -13)

    local rail = NS.CreateFrame("Frame", nil, f)
    rail:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -72)
    rail:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    rail:SetWidth(230)
    Paint(rail, C.rail)
    Label(rail, "Your Addon", 10, C.muted, 155, "TOPLEFT", rail, "TOPLEFT", 20, -19)
    local navButtons = {}
    for i, page in ipairs(NAV) do
        local button = NS.CreateFrame("Button", nil, rail)
        button:SetPoint("TOPLEFT", rail, "TOPLEFT", 0, -50 - (i - 1) * 53)
        button:SetSize(224, 49)
        local bg = Paint(button, C.rail)
        local stripe = Paint(button, C.accent, "TOPLEFT", button, 0, 0, 3, 49)
        local number = Label(button, string.format("%02d", i), 10, C.muted, 28, "LEFT", button, "LEFT", 18, 0)
        local name = Label(button, page, 12, C.text, 133, "LEFT", button, "LEFT", 48, 0)
        button:SetScript("OnClick", function() self:SelectPage(page) end)
        button._bg, button._stripe, button._number, button._name = bg, stripe, number, name
        navButtons[page] = button
    end
    self.navButtons = navButtons
    local classic = Action(rail, "Classic Settings", 16, 0, 190, 33,
        function() OpenClassic(CLASSIC_SECTION[self.page], true) end, "quiet")
    classic:ClearAllPoints()
    classic:SetPoint("BOTTOMLEFT", rail, "BOTTOMLEFT", 16, 34)
    Label(rail, "Switch back any time", 10, C.muted, 158, "BOTTOMLEFT", rail, "BOTTOMLEFT", 16, 18)

    local content = NS.CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", 238, -72)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 36)
    Paint(content, C.body)
    self.content = content
    local footer = NS.CreateFrame("Frame", nil, f)
    footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 238, 0)
    footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    footer:SetHeight(36)
    Paint(footer, C.rail)
    self.notice = Label(footer, "Changes Save Automatically", 10, C.muted, 475,
        "LEFT", footer, "LEFT", 20, 0)
    local grip = Action(f, "\\", 0, 0, 23, 23, function() end, "quiet")
    grip:ClearAllPoints()
    grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 5)
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)

    self.pages = {}
    BuildGeneralPage(self, "Overview", "Make BetterSBA Yours",
        "The essentials in one place. Choose a section for more detail.", {
            { "Enable BetterSBA", "Run the assistant and its display.", "enabled", function()
                if NS.db.enabled then NS.StartTicker() else NS.StopTicker() end
                if NS.RefreshSBAInterception then NS.RefreshSBAInterception() end
                NS.UpdateNow()
            end },
            { "Show Priority Queue", "See upcoming suggestions beside the button.", "showPriority", function() NS.UpdatePriorityDisplay() end },
            { "Lock Button Position", "Prevent accidental dragging.", "locked" },
        }, 1)
    BuildGeneralPage(self, "Combat", "Combat Assistance",
        "Control what BetterSBA adds around the Single Button Assistant.", {
            { "Auto-Target Enemies", "Find a nearby target when needed.", "enableTargeting", function() NS.RebuildMacroText() end },
            { "Pet Attack", "Send your pet to your target.", "enablePetAttack", function() NS.RebuildMacroText() end },
            { "Channel Protection", "Avoid interrupting a protected channel.", "enableChannelProtection", function() NS.RebuildMacroText() end },
            { "Auto-Dismount", "Dismount when casting requires it.", "enableDismount", function() NS.RebuildMacroText() end },
        }, 1)
    BuildGeneralPage(self, "Button & Queue", "Button & Queue",
        "Keep the primary action and its next suggestions easy to read.", {
            { "Show Keybind", "Display the current activation key.", "showKeybind", function() NS.ApplyButtonSettings() end },
            { "Show Cooldown", "Display remaining cooldown time.", "showCooldown", function() NS.ApplyButtonSettings() end },
            { "Show Priority Queue", "Show the upcoming spell icons.", "showPriority", function() NS.UpdatePriorityDisplay() end },
            { "Show Active Glow", "Highlight the active suggestion.", "showActiveGlow", function() NS.UpdatePriorityDisplay() end },
        }, 3)
    local motion = BuildGeneralPage(self, "Motion", "Motion & Feedback",
        "Choose a restrained response when your SBA action fires.", {
            { "Use Motion Feedback", "Animate the button after a cast.",
                function() return NS.db.castFeedback == "Motion" end, function(value)
                NS.db.castFeedback = value and "Motion" or "Off"
                if NS.RefreshCastFeedbackSettings then NS.RefreshCastFeedbackSettings() end
            end },
            { "Reduced Motion", "Keep effects quieter and shorter.", "motionReduced", function()
                if NS.RefreshCastFeedbackSettings then NS.RefreshCastFeedbackSettings() end
            end },
        }, 2)
    local motionPresets = { "Pulse", "Echo", "Sweep", "Sheen", "Snap", "Orbit" }
    Label(motion._quickBox, "Motion Preset", 12, C.text, 200,
        "TOPLEFT", motion._quickBox, "TOPLEFT", 18, -184)
    local preset = Action(motion._quickBox, "", 18, -207, 178, 34, function()
        local current = NS.db.motionPreset
        local nextIndex = 1
        for i, name in ipairs(motionPresets) do
            if name == current then nextIndex = i % #motionPresets + 1; break end
        end
        NS.db.motionPreset = motionPresets[nextIndex]
        if NS.RefreshCastFeedbackSettings then NS.RefreshCastFeedbackSettings() end
        motion.Refresh()
    end)
    Action(motion._quickBox, "Preview Motion", 208, -207, 140, 34, function()
        if NS.PreviewMotionFeedback then NS.PreviewMotionFeedback() end
    end, "quiet")
    local motionRefresh = motion.Refresh
    motion.Refresh = function()
        motionRefresh()
        preset._label:SetText(NS.db.motionPreset or "Pulse")
    end
    BuildTalentPage(self)
    BuildGeneralPage(self, "Profiles", "Profiles & Visibility",
        "Keep your setup readable and available where you need it.", {
            { "Show Minimap Button", "Open settings from the minimap.", "showMinimapButton", function()
                if NS.SetMinimapVisible then NS.SetMinimapVisible(NS.db.showMinimapButton) end
            end },
            { "Hide in Vehicle", "Keep the display out of vehicle UI.", "hideInVehicle", function() NS.UpdateNow() end },
            { "Only in Combat", "Hide the display between fights.", "onlyInCombat", function() NS.UpdateNow() end },
        }, 9)
    -- The generic quick controls are deliberately a preview of the common
    -- actions; the complete profile manager stays in Classic Settings.
    f:SetScript("OnShow", function() self:Refresh() end)
    local elapsed = 0
    f:SetScript("OnUpdate", function(_, delta)
        if self.page ~= "Talents" then return end
        elapsed = elapsed + delta
        if elapsed >= 1 then elapsed = 0; self:Refresh() end
    end)
    local function Relayout(_, width, height)
        NS.db.configStudioWidth = width
        NS.db.configStudioHeight = height
        local inner = width - 238
        local usable = inner - 52
        for _, page in pairs(self.pages) do
            if page ~= self.pages.Talents then
                local box = page._quickBox
                if box then box:SetWidth(usable) end
            end
        end
        local talents = self.pages.Talents
        local route = talents._route
        if route then
            route:SetWidth(usable)
            talents._routeName:SetWidth(usable - 285)
            local half = math.floor((usable - 12) / 2)
            talents._left:SetWidth(half)
            talents._right:SetWidth(usable - half - 12)
            talents._right:ClearAllPoints()
            talents._right:SetPoint("TOPLEFT", talents, "TOPLEFT", 26 + half + 12, -270)
        end
        self:ApplyScale()
    end
    f:SetScript("OnSizeChanged", Relayout)
    Relayout(f, w, h)
    self:SelectPage(self.page)
    f:Hide()
    self:ApplyScale()
end

function Studio:ApplyScale()
    if not self.frame then return end
    local f = self.frame
    local preferred = math.max(.5, math.min(2, tonumber(NS.db.configPanelScale) or 1))
    local scale = math.min(preferred, (NS.UIParent:GetWidth() - 48) / f:GetWidth(),
        (NS.UIParent:GetHeight() - 48) / f:GetHeight())
    f:SetScale(scale)
end

function Studio:SelectPage(page)
    self.page = self.pages[page] and page or "Overview"
    for key, view in pairs(self.pages) do view:SetShown(key == self.page) end
    for key, button in pairs(self.navButtons) do
        local active = key == self.page
        button._bg:SetVertexColor(NS.unpack(active and C.card or C.rail))
        button._stripe:SetAlpha(active and 1 or 0)
        button._number:SetTextColor(NS.unpack(active and C.accent or C.muted))
        button._name:SetTextColor(NS.unpack(active and C.bright or C.dim))
    end
    self:Refresh()
end

function Studio:Refresh()
    if not self.frame then return end
    if self.profileLabel and NS.GetActiveProfileName then
        self.profileLabel:SetText("Profile: " .. NS.GetActiveProfileName())
    end
    local current = self.pages[self.page]
    if current and current.Refresh then current.Refresh() end
end

function Studio:Show()
    if not self.frame then self:Create() end
    self.frame:Show()
    self:Refresh()
end

function Studio:Hide()
    if self.frame then self.frame:Hide() end
end

function Studio:Toggle()
    if self.frame and self.frame:IsShown() then self:Hide() else self:Show() end
end
