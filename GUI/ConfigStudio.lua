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
local NAV = { "Overview", "Combat", "Button & Queue", "Motion", "Talents",
    "Visibility", "Colors & Fonts", "Advanced", "Profiles" }
local CLASSIC_SECTION = { Overview = 1, Combat = 1, ["Button & Queue"] = 3,
    Motion = 2, Talents = 5, Visibility = 6, ["Colors & Fonts"] = 7,
    Advanced = 8, Profiles = 9 }

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

local function WrapRouteName(label, measure, value, width)
    value = tostring(value or "No Build Selected")
    measure:SetText(value)
    if measure:GetStringWidth() <= width then label:SetText(value); return end
    local lines = { "", "" }
    local current = 1
    for word in value:gmatch("%S+") do
        local candidate = lines[current] == "" and word or (lines[current] .. " " .. word)
        measure:SetText(candidate)
        if measure:GetStringWidth() > width and lines[current] ~= "" and current == 1 then
            current = 2
            candidate = word
        end
        lines[current] = candidate
    end
    measure:SetText(lines[2])
    while measure:GetStringWidth() > width and #lines[2] > 1 do
        lines[2] = lines[2]:sub(1, -2)
        measure:SetText(lines[2] .. "…")
    end
    label:SetText(lines[1] .. "\n" .. lines[2])
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
    local width = math.max(100, math.min(160, #value * 6 + 18))
    local tab = Surface(parent, x, y, width, 20, C.accent)
    tab:SetBackdropBorderColor(NS.unpack(C.accent))
    Label(tab, value, 10, C.gutter, width - 16, "LEFT", tab, "LEFT", 8, 0)
    return tab
end

local function Setting(parent, name, note, y, getter, setter, copyWidth)
    local row = NS.CreateFrame("Button", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, y)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, y)
    row:SetHeight(46)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp")
    Label(row, name, 12, C.text, copyWidth or 250, "TOPLEFT", row, "TOPLEFT", 0, -5)
    Label(row, note, 10, C.dim, copyWidth or 290, "TOPLEFT", row, "TOPLEFT", 0, -24)
    local track = Surface(row, 0, 0, 42, 22, C.rail)
    track:ClearAllPoints()
    track:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    track:EnableMouse(false)
    local stateText = Label(track, "Off", 10, C.dim, 34, "CENTER", track, "CENTER", 0, 0)
    stateText:SetJustifyH("CENTER")
    row.Refresh = function()
        local on = getter() == true
        track:SetBackdropColor(NS.unpack(on and C.accent or C.rail))
        stateText:SetText(on and "On" or "Off")
        stateText:SetTextColor(NS.unpack(on and C.gutter or C.dim))
    end
    row:SetScript("OnClick", function() setter(not getter()); row.Refresh() end)
    row._track = track
    row._stateText = stateText
    row.Refresh()
    return row
end

Studio.UI = { Surface = Surface, Action = Action, Label = Label,
    Paint = Paint, FitText = FitText, colors = C }

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

local function BuildTalentPage(self)
    local view = NS.CreateFrame("Frame", nil, self.content)
    view:SetAllPoints()
    self.pages.Talents = view
    Caption(view, "Talents", 26, -8)
    Label(view, "Leveling Talents", 24, C.bright, 500, "TOPLEFT", view, "TOPLEFT", 26, -35)
    Label(view, "Choose a route once. BetterSBA spends only points your level can use.", 11,
        C.dim, 610, "TOPLEFT", view, "TOPLEFT", 26, -69)

    local route = Surface(view, 26, -96, 622, 112)
    view._route = route
    Paint(route, C.accent, "TOPLEFT", route, 0, 0, 3, 112)
    Label(route, "Current Route", 10, C.accent, 120, "TOPLEFT", route, "TOPLEFT", 16, -10)
    local routeName = Label(route, "No Build Selected", 16, C.bright, 365,
        "TOPLEFT", route, "TOPLEFT", 16, -28)
    routeName:SetWordWrap(true)
    routeName:SetMaxLines(2)
    routeName:SetHeight(39)
    local routeNameMeasure = route:CreateFontString(nil, "OVERLAY")
    routeNameMeasure:SetFont(NS.GetConfigFontPath(), 16, "")
    routeNameMeasure:SetTextColor(1, 1, 1, 0)
    routeNameMeasure:SetPoint("TOPLEFT", route, "TOPLEFT", 0, 0)
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
    local routeDetail = Label(route, "Current specialization", 10, C.dim,
        365, "TOPLEFT", route, "TOPLEFT", 16, -75)
    local routeMeta = Label(route, "Only talents available at your level are purchased.", 10, C.muted,
        365, "TOPLEFT", route, "TOPLEFT", 16, -94)
    local spend = NS.CreateFrame("Button", nil, route)
    spend:SetSize(205, 44)
    spend:SetPoint("TOPRIGHT", route, "TOPRIGHT", -13, -17)
    local art = spend:CreateTexture(nil, "BACKGROUND")
    art:SetAllPoints()
    art:SetTexture(ART)
    Label(spend, "Spend Available Points", 11, C.bright, 185, "CENTER", spend, "CENTER", 0, 0):SetJustifyH("CENTER")
    local change = Action(route, "Change Build", 0, 0, 128, 25, function() end, "quiet")
    view._change = change
    change:ClearAllPoints()
    change:SetPoint("TOPRIGHT", route, "TOPRIGHT", -51, -75)

    local left = Surface(view, 26, -220, 305, 216)
    local right = Surface(view, 343, -220, 305, 216)
    view._left, view._right = left, right
    Caption(left, "What Happens Next", 0, 0)
    Caption(right, "Automation & Safety", 0, 0)
    local state = Label(left, "Route Status", 14, C.text, 270, "TOPLEFT", left, "TOPLEFT", 16, -30)
    local status = Label(left, "", 11, C.dim, 270, "TOPLEFT", left, "TOPLEFT", 16, -56)
    view._status = status
    status:SetWordWrap(true)
    status:SetMaxLines(3)
    local divider = Paint(left, C.border)
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", left, "TOPLEFT", 16, -111)
    divider:SetPoint("TOPRIGHT", left, "TOPRIGHT", -16, -111)
    divider:SetHeight(1)
    local next = Label(left, "Next Talent: —", 11, C.cyan, 270, "TOPLEFT", left, "TOPLEFT", 16, -127)
    local levelNote = Label(left, "Class and spec points spend when legal.\nHero talents wait for their level unlock.",
        10, C.dim, 270, "TOPLEFT", left, "TOPLEFT", 16, -157)
    levelNote:SetWordWrap(true)
    levelNote:SetMaxLines(3)
    view._stepLabels = { state, status, next, levelNote }
    local auto = Setting(right, "Auto-Spend New Points", "No approval for each rank.", -27,
        function() return NS.GetTalentLevelingInfo().enabled end,
        function(value)
            local ok, err = NS.SetTalentLevelingEnabled(value)
            self.notice:SetText(ok and (value and "Auto-Spend is On for this route."
                or "Auto-Spend is Off for this route.") or (err or "Unable to change Auto-Spend."))
            self:Refresh()
        end, 200)
    view._auto = auto
    local warn = Setting(right, "Warn If Talents Differ", "Alert before a rebuild.", -71,
        function() return NS.GetTalentLevelingInfo().warningEnabled end,
        function(value) NS.SetTalentSBAWarningEnabled(value); self:Refresh() end, 200)
    local autoRebuild = Setting(right, "Auto-Rebuild On Mismatch", "Runs when Auto-Spend is on.", -115,
        function() return NS.GetTalentLevelingInfo().autoRespecEnabled end,
        function(value) NS.SetTalentAutoRespecEnabled(value); self:Refresh() end, 200)
    view._autoRebuild = autoRebuild
    local rebuild = Action(right, "Reset & Rebuild", 18, -177, 133, 28, function()
        local ok, message = NS.RequestTalentSBARespec()
        self.notice:SetText(message or (ok and "Rebuild started." or "Unable to rebuild talents."))
        self:Refresh()
    end)
    local undo = Action(right, "Undo Respec", 161, -177, 125, 28, function()
        local ok, message = NS.RequestTalentSBAUndo()
        self.notice:SetText(message or (ok and "Undo started." or "Nothing to undo."))
        self:Refresh()
    end, "quiet")
    Caption(view, "Build Library", 26, -448)
    local browse = Action(view, "Browse Builds and Imports", 26, -474, 219, 30,
        function() self:SelectPage("Build Library") end)
    view._browse = browse

    local pickerOverlay = NS.CreateFrame("Frame", nil, self.content)
    pickerOverlay:SetAllPoints()
    pickerOverlay:SetFrameLevel(view:GetFrameLevel() + 12)
    pickerOverlay:EnableMouse(true)
    Paint(pickerOverlay, { .02, .025, .045, .84 })
    pickerOverlay:Hide()
    local picker = Surface(pickerOverlay, 0, 0, 500, 185, C.card)
    picker:ClearAllPoints()
    picker:SetPoint("CENTER", pickerOverlay, "CENTER", 0, 0)
    picker:SetFrameLevel(pickerOverlay:GetFrameLevel() + 1)
    picker:EnableMouse(true)
    Label(picker, "Choose a Build", 18, C.bright, 350, "TOPLEFT", picker, "TOPLEFT", 16, -15)
    Label(picker, "Builds for your current specialization", 10, C.dim, 400,
        "TOPLEFT", picker, "TOPLEFT", 16, -39)
    local pickerMessage = Label(picker, "", 10, C.accent, 460,
        "TOPLEFT", picker, "TOPLEFT", 16, -117)
    pickerOverlay:SetScript("OnHide", function()
        view._selectionError = nil
        pickerMessage:SetText("")
    end)
    local rows = {}
    local pickerPage = 1
    for i = 1, 4 do
        local rowIndex = i
        rows[i] = Action(picker, "", 16, -62 - (i - 1) * 46, 468, 38, function()
            local entry = rows[rowIndex].entry
            if not entry then return end
            local ok, err = NS.SetTalentLevelingTarget(entry.id)
            if ok then
                pickerOverlay:Hide()
                view._selectionError = nil
                pickerMessage:SetText("")
            else
                view._selectionError = err or "Unable to choose build."
                pickerMessage:SetText(view._selectionError)
            end
            self.notice:SetText(ok and ("Selected " .. entry.name .. ".") or (err or "Unable to choose build."))
            self:Refresh()
        end, "quiet")
    end
    view._pickerRows = rows
    local previous = Action(picker, "Previous", 16, -147, 94, 26,
        function() pickerPage = math.max(1, pickerPage - 1); picker.Refresh() end)
    local nextPage = Action(picker, "Next", 122, -147, 74, 26,
        function() pickerPage = pickerPage + 1; picker.Refresh() end)
    local pickerClose = Action(picker, "Close", 388, -147, 96, 26,
        function() pickerOverlay:Hide() end, "quiet")
    local pageLabel = Label(picker, "", 10, C.dim, 90, "BOTTOM", picker, "BOTTOM", 0, 19)
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
        local visibleRows = math.max(1, math.min(4, #matches - (pickerPage - 1) * 4))
        local extra = (visibleRows - 1) * 46
        picker:SetHeight(185 + extra)
        pickerMessage:ClearAllPoints()
        pickerMessage:SetPoint("TOPLEFT", picker, "TOPLEFT", 16, -117 - extra)
        for _, control in ipairs({ previous, nextPage, pickerClose }) do
            control:ClearAllPoints()
            control:SetPoint("TOPLEFT", picker, "TOPLEFT",
                control == previous and 16 or (control == nextPage and 122 or 388), -147 - extra)
        end
        for i, row in ipairs(rows) do
            local entry = matches[(pickerPage - 1) * 4 + i]
            row.entry = entry
            row:SetShown(entry ~= nil)
            if entry then FitText(row._label, entry.name, row._label:GetWidth()) end
        end
        pageLabel:SetText(pickerPage .. " / " .. pages)
        if #matches == 0 then pickerMessage:SetText("No builds for this specialization. Open the Build Library to import one.") end
        previous:SetShown(pickerPage > 1)
        nextPage:SetShown(pickerPage < pages)
    end
    change:SetScript("OnClick", function()
        if pickerOverlay:IsShown() then
            pickerOverlay:Hide()
        else
            pickerMessage:SetText("")
            picker.Refresh()
            pickerOverlay:Show()
        end
    end)
    spend:SetScript("OnClick", function()
        local ok, message = NS.SpendAllOrRespecTalentPoints()
        self.notice:SetText(message or (ok and "Spending available talent points." or "No eligible points to spend."))
        self:Refresh()
    end)
    view._spend = spend
    view._picker = pickerOverlay
    view._pickerCard = picker
    self.pickerOverlay = pickerOverlay
    spend:SetScript("OnEnter", function() art:SetVertexColor(1, 1, 1, .82) end)
    spend:SetScript("OnLeave", function() art:SetVertexColor(1, 1, 1, 1) end)
    view.Refresh = function()
        local info = NS.GetTalentLevelingInfo()
        WrapRouteName(routeName, routeNameMeasure, info.targetName, routeName:GetWidth())
        change._label:SetText(info.buildID and info.targetName ~= "No Build Selected"
            and "Change Build" or "Choose a Build")
        routeDetail:SetText(info.specName and ("Active Specialization: " .. info.specName) or "Current specialization")
        routeMeta:SetText(info.enabled and "Auto-Spend: On" or "Auto-Spend: Off")
        local headline
        if not info.buildID or info.targetName == "No Build Selected" then
            headline = "Choose a Build"
        elseif info.hasMismatch then
            headline = "Talents Need Rebuilding"
        elseif info.canSpend then
            headline = "Point Ready to Spend"
        elseif info.hasPoints then
            headline = "Point Waiting for Unlock"
        elseif not info.settled then
            headline = "Spending Paused"
        else
            headline = "No Unspent Points"
        end
        FitText(state, headline, state:GetWidth())
        status:SetText(view._selectionError or info.status or "Choose a build to get started.")
        FitText(next, "Next Talent: " .. (info.nextName or "—"), next:GetWidth())
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
    local savedHeight = tonumber(NS.db.configStudioHeight) or 620
    if savedHeight == 700 or savedHeight == 760 or savedHeight == 790 then savedHeight = 620 end
    local h = math.max(600, math.min(900, savedHeight))
    NS.db.configStudioHeight = h
    local f = NS.CreatePanel("BetterSBA_ConfigStudio", NS.UIParent, w, h)
    self.frame = f
    f:SetBackdropColor(NS.unpack(C.shell))
    f:SetBackdropBorderColor(NS.unpack(C.border))
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:SetResizable(true)
    f:SetResizeBounds(900, 600, 1300, 900)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:EnableMouse(true)
    local header = NS.CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(48)
    Paint(header, C.card)
    local topLine = Paint(header, C.accent, "TOPLEFT", header, 0, 0, w, 3)
    topLine:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 0)
    Label(header, "BetterSBA", 18, C.bright, 150, "LEFT", header, "LEFT", 16, 0)
    Label(header, "Settings", 10, C.muted, 100, "LEFT", header, "LEFT", 165, 0)
    local profile = Label(header, "", 11, C.dim, 220, "RIGHT", header, "RIGHT", -50, 0)
    profile:SetJustifyH("RIGHT")
    self.profileLabel = profile
    local close = Action(header, "X", 0, 0, 28, 28, function() f:Hide() end)
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", header, "TOPRIGHT", -10, -10)

    local rail = NS.CreateFrame("Frame", nil, f)
    rail:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -54)
    rail:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    rail:SetWidth(210)
    Paint(rail, C.rail)
    Label(rail, "Your Addon", 10, C.muted, 155, "TOPLEFT", rail, "TOPLEFT", 16, -12)
    local navButtons = {}
    for i, page in ipairs(NAV) do
        local button = NS.CreateFrame("Button", nil, rail)
        button:SetPoint("TOPLEFT", rail, "TOPLEFT", 0, -34 - (i - 1) * 36)
        button:SetSize(204, 34)
        local bg = Paint(button, C.rail)
        local stripe = Paint(button, C.accent, "TOPLEFT", button, 0, 0, 3, 34)
        local number = Label(button, string.format("%02d", i), 10, C.muted, 26, "LEFT", button, "LEFT", 15, 0)
        local name = Label(button, page, 11, C.text, 145, "LEFT", button, "LEFT", 40, 0)
        button:SetScript("OnClick", function() self:SelectPage(page) end)
        button._bg, button._stripe, button._number, button._name = bg, stripe, number, name
        navButtons[page] = button
    end
    self.navButtons = navButtons
    local classic = Action(rail, "Classic Settings", 14, 0, 180, 28,
        function() OpenClassic(CLASSIC_SECTION[self.page], true) end, "quiet")
    classic:ClearAllPoints()
    classic:SetPoint("BOTTOMLEFT", rail, "BOTTOMLEFT", 14, 23)

    local content = NS.CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", 218, -54)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 28)
    Paint(content, C.body)
    self.content = content
    local footer = NS.CreateFrame("Frame", nil, f)
    footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 218, 0)
    footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    footer:SetHeight(28)
    Paint(footer, C.rail)
    self.notice = Label(footer, "Changes Save Automatically", 10, C.muted, 475,
        "LEFT", footer, "LEFT", 20, 0)
    local grip = Action(f, "\\", 0, 0, 23, 23, function() end, "quiet")
    grip:ClearAllPoints()
    grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 5)
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)

    self.pages = {}
    BuildTalentPage(self)
    self:BuildSettingsPages()
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
        local inner = width - 218
        local usable = inner - 52
        for _, page in pairs(self.pages) do
            if page._studioScroll then
                page._studioScroll:SetSize(usable, math.max(200, height - 54 - 28 - 74))
                if page._studioChild and not page._fixedStudioChildWidth then
                    page._studioChild:SetWidth(usable - 14)
                end
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
            talents._stepLabels[1]:SetWidth(half - 32)
            talents._stepLabels[2]:SetWidth(half - 32)
            talents._stepLabels[3]:SetWidth(half - 32)
            for i = 4, #talents._stepLabels do
                talents._stepLabels[i]:SetWidth(half - 32)
            end
            talents._right:ClearAllPoints()
            talents._right:SetPoint("TOPLEFT", talents, "TOPLEFT", 26 + half + 12, -220)
            if talents.Refresh then talents.Refresh() end
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
    if self.page ~= "Talents" and self.pickerOverlay then self.pickerOverlay:Hide() end
    if self._choicePopup then self._choicePopup.overlay:Hide() end
    if self._confirmPopup then self._confirmPopup.overlay:Hide() end
    for key, view in pairs(self.pages) do view:SetShown(key == self.page) end
    local navPage = (self.page == "Build Library" or self.page == "Talent Options")
        and "Talents" or self.page
    for key, button in pairs(self.navButtons) do
        local active = key == navPage
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
    if self.pickerOverlay then self.pickerOverlay:Hide() end
    if self._choicePopup then self._choicePopup.overlay:Hide() end
    if self._confirmPopup then self._confirmPopup.overlay:Hide() end
    if self.frame then self.frame:Hide() end
end

function Studio:Toggle()
    if self.frame and self.frame:IsShown() then self:Hide() else self:Show() end
end
