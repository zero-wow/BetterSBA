local ADDON_NAME, NS = ...
local Simple = NS.ConfigSimple
local Model = NS.StudioSettingsModel
local UI = Simple.UI
local Label, Button, SetEnabled = UI.Label, UI.Button, UI.SetEnabled
local colors = UI.colors
local unpack = NS.unpack or unpack or table.unpack
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT = "Fonts\\FRIZQT__.TTF"
local PAGE_SIZE = 5

-- Calm navigation over Studio's existing settings model. No second set of
-- saved options, talent mutation logic, or profile operations lives here.
local TOPICS = {
    { "Talents", "Builds and Automatic Points" },
    { "Combat", "Combat Helpers" },
    { "Button & Queue", "Your Button and Next Spells" },
    { "Motion", "Movement and Effects" },
    { "Visibility", "When Things Appear" },
    { "Colors & Fonts", "Colors and Text" },
    { "Profiles", "Saved Profiles" },
    { "Advanced", "Help and Troubleshooting" },
}
local HELP = {
    Talents = "Choose a route, manage builds, or change how points are spent.",
    Combat = "Choose which actions the assistant helps with.",
    ["Button & Queue"] = "Change the button, nearby spell icons, and their placement.",
    Motion = "Choose an effect, tune it, and try it on your button.",
    Visibility = "Choose when the button and nearby icons appear.",
    ["Colors & Fonts"] = "Adjust one part of the appearance at a time.",
    Profiles = "Save different setups and choose which one this character uses.",
    Advanced = "Extra controls and tools for checking a problem.",
}
local CLASS_KEYS = {
    enableDemonSpikes = "DEMONHUNTER", enableConvokeTheSpirits = "DRUID",
    enableShieldBlock = "WARRIOR", enableIgnorePain = "WARRIOR", enableIronfur = "DRUID",
    enableShieldOfRighteous = "PALADIN", enableRuneTap = "DEATHKNIGHT", enablePurifyingBrew = "MONK",
}

local function Fit(label, value, width)
    NS.ConfigStudio.UI.FitText(label, value, width)
end

local function Edit(parent, x, y, width, height)
    local edit = NS.CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    edit:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    edit:SetSize(width, height or 30)
    edit:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    edit:SetBackdropColor(unpack(colors.background))
    edit:SetBackdropBorderColor(unpack(colors.border))
    edit:SetFont(FONT, 13, "")
    edit:SetTextColor(unpack(colors.text))
    edit:SetTextInsets(8, 8, 4, 4)
    edit:SetAutoFocus(false)
    return edit
end

local function Ready()
    if not Simple.frame then Simple:Create() end
end

local function Context()
    local info = NS.GetTalentLevelingInfo and NS.GetTalentLevelingInfo() or {}
    local entry = info.buildID and NS.FindTalentBuildByID and NS.FindTalentBuildByID(info.buildID)
    local state = NS.GetTalentLevelingState and NS.GetTalentLevelingState() or {}
    return { db = NS.db, profile = NS.GetActiveProfileName and NS:GetActiveProfileName(),
        spec = NS.GetTalentBuildCurrentSpecID and NS.GetTalentBuildCurrentSpecID(),
        build = info.buildID, automatic = info.enabled, rebuild = info.autoRespecEnabled,
        target = entry and entry.importString or state.importString }
end

local function SameContext(before)
    if not before then return false end
    local now = Context()
    for _, key in ipairs({ "db", "profile", "spec", "build", "automatic", "rebuild", "target" }) do
        if before[key] ~= now[key] then return false end
    end
    return true
end

local function InvokeDialog(dialog, value)
    local callback, context = dialog.callback, dialog.context
    Simple:CloseDialog()
    if not callback then return end
    if not SameContext(context) then
        Simple:Report(false, "Your profile or talent setup changed. Open that action again to review it.")
        return
    end
    callback(value)
end

function Simple:CloseDialog()
    local dialog = self._focusDialog
    if dialog then dialog.overlay:Hide() end
end

local function Dialog()
    Ready()
    if Simple._focusDialog then return Simple._focusDialog end
    local overlay = NS.CreateFrame("Frame", "BetterSBA_FocusDialog", Simple.frame, "BackdropTemplate")
    overlay:SetAllPoints()
    overlay:SetFrameLevel(Simple.frame:GetFrameLevel() + 50)
    overlay:SetBackdrop({ bgFile = WHITE })
    overlay:SetBackdropColor(0, 0, 0, .8)
    overlay:EnableMouse(true)
    local card = NS.CreateFrame("Frame", nil, overlay, "BackdropTemplate")
    card:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    card:SetSize(580, 376)
    card:SetFrameLevel(overlay:GetFrameLevel() + 1)
    card:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    card:SetBackdropColor(unpack(colors.background))
    card:SetBackdropBorderColor(unpack(colors.border))
    local dialog = { overlay = overlay, card = card, choices = {}, page = 1 }
    Simple._focusDialog = dialog
    dialog.title = Label(card, "", 16, -16, 440, 18)
    dialog.close = Button(card, "Close", 486, -12, 78, function() Simple:CloseDialog() end)
    for index = 1, 6 do
        local row = Button(card, "", 16, -58 - (index - 1) * 42, 548, function()
            local value = dialog.rows[index]._value
            if value ~= nil then InvokeDialog(dialog, value) end
        end)
        dialog.rows = dialog.rows or {}
        dialog.rows[index] = row
    end
    dialog.previous = Button(card, "Previous", 16, -326, 100, function()
        dialog.page = math.max(1, dialog.page - 1); dialog.Refresh()
    end)
    dialog.next = Button(card, "Next", 126, -326, 80, function()
        dialog.page = dialog.page + 1; dialog.Refresh()
    end)
    dialog.pageText = Label(card, "", 226, -333, 170, 12, "muted")
    dialog.prompt = Label(card, "", 16, -64, 548, 15, "text", 10)
    dialog.cancel = Button(card, "Cancel", 336, -326, 100, function() Simple:CloseDialog() end)
    dialog.confirm = Button(card, "Confirm", 446, -326, 118, function()
        InvokeDialog(dialog)
    end)
    overlay:SetScript("OnHide", function()
        dialog.callback = nil
        dialog.context = nil
        for _, row in ipairs(dialog.rows) do row._value = nil end
    end)
    Simple.frame:HookScript("OnHide", function() overlay:Hide() end)
    if type(UISpecialFrames) == "table" then UISpecialFrames[#UISpecialFrames + 1] = "BetterSBA_FocusDialog" end
    overlay:Hide()
    return dialog
end

function Simple:OpenChoices(title, choices, current, callback, formatter)
    if not choices or #choices == 0 then self:Report(false, "No choices are available here yet."); return end
    self:CloseDialog()
    local dialog = Dialog()
    dialog.title:SetText(title)
    dialog.callback, dialog.choices, dialog.current, dialog.page = callback, choices, current, 1
    dialog.context = Context()
    dialog.prompt:Hide(); dialog.confirm:Hide(); dialog.cancel:Hide()
    dialog.previous:Show(); dialog.next:Show(); dialog.pageText:Show()
    dialog.Refresh = function()
        local pages = math.max(1, math.ceil(#dialog.choices / 6))
        dialog.page = math.max(1, math.min(pages, dialog.page))
        for index, row in ipairs(dialog.rows) do
            local value = dialog.choices[(dialog.page - 1) * 6 + index]
            row._value = value
            row:SetShown(value ~= nil)
            if value ~= nil then
                local text = formatter and formatter(value) or Model.ChoiceLabel(value)
                Fit(row._label, (value == dialog.current and "Selected: " or "") .. text, row._label:GetWidth())
            end
        end
        dialog.pageText:SetText(dialog.page .. " / " .. pages)
        SetEnabled(dialog.previous, dialog.page > 1)
        SetEnabled(dialog.next, dialog.page < pages)
    end
    dialog.Refresh()
    dialog.overlay:Show()
end

function Simple:Confirm(prompt, callback)
    self:CloseDialog()
    local dialog = Dialog()
    dialog.title:SetText("Confirm Change")
    dialog.prompt:SetText(prompt)
    dialog.prompt:Show(); dialog.confirm:Show(); dialog.cancel:Show()
    dialog.previous:Hide(); dialog.next:Hide(); dialog.pageText:Hide()
    for _, row in ipairs(dialog.rows) do row:Hide() end
    dialog.callback = callback
    dialog.context = Context()
    dialog.overlay:Show()
end

function Simple:ShowText(title, text)
    Ready()
    self._textReturn = self.view ~= "text" and self.view or (self._textReturn or "main")
    local view = self.views.text
    if not view then
        view = self:CreateView("text")
        view._title = Label(view, "", 0, 0, 590, 20)
        Label(view, "Select text to copy. Scroll for more.", 0, -31, 590, 12, "muted")
        local scroll = NS.CreateFrame("ScrollFrame", nil, view)
        scroll:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -62)
        scroll:SetSize(590, 266); scroll:EnableMouseWheel(true)
        local edit = Edit(scroll, 0, 0, 574, 266)
        edit:SetMultiLine(true); edit:SetMaxLetters(0)
        scroll:SetScrollChild(edit)
        view._edit, view._scroll = edit, scroll
        scroll:SetScript("OnMouseWheel", function(_, delta)
            scroll:SetVerticalScroll(math.max(0, math.min(math.max(0, edit:GetHeight() - scroll:GetHeight()),
                scroll:GetVerticalScroll() - delta * 48)))
        end)
        edit:SetScript("OnEscapePressed", function() edit:ClearFocus(); self:SelectView(self._textReturn) end)
        Button(view, "Back", 512, -350, 88, function() edit:ClearFocus(); self:SelectView(self._textReturn) end)
        view:HookScript("OnHide", function() edit:ClearFocus() end)
        self:RegisterView("text", view, function() end)
    end
    view._title:SetText(title)
    view._edit:SetText(text or "")
    local height = view._edit.GetTextHeight and view._edit:GetTextHeight()
    if not height or height <= 0 then
        local lines = 0
        for line in ((text or "") .. "\n"):gmatch("(.-)\n") do lines = lines + math.max(1, math.ceil(#line / 68)) end
        height = lines * 18
    end
    view._edit:SetHeight(math.max(266, height + 20))
    view._edit:SetCursorPosition(0)
    view._scroll:SetVerticalScroll(0)
    self:SelectView("text")
end

local Plain = { colors = {
    text = colors.text, bright = colors.text, dim = colors.muted, muted = colors.muted,
    accent = colors.accent, rail = colors.background, border = colors.border,
} }
function Plain.Label(parent, text, size, color, width, point, relative, relativePoint, x, y)
    local label = Label(parent, text, 0, 0, width or 280, math.max(12, size or 13))
    label:ClearAllPoints()
    label:SetPoint(point or "TOPLEFT", relative or parent, relativePoint or point or "TOPLEFT", x or 0, y or 0)
    if color then label:SetTextColor(unpack(color)) end
    return label
end
function Plain.Action(parent, text, x, y, width, height, callback)
    local button = Button(parent, text, x, y, width, callback)
    button:SetHeight(math.max(30, height or 32))
    return button
end
function Plain.SetActionText(button, text) Fit(button._label, text, button._label:GetWidth()) end
Plain.FitText = Fit
Plain.SetTextIfChanged = NS.ConfigStudio.UI.SetTextIfChanged

local function Host(content)
    return {
        frame = Simple.frame, content = content, pages = {}, notice = Simple.message,
        settingsUI = Plain, settingsFontPath = FONT, settingsFontSize = 13,
        settingsRowHeight = 52, settingsLabelWidth = 320, settingsControlHeight = 30,
        ApplyScale = function() Simple:ApplyScale() end,
        Refresh = function() Simple:Refresh() end,
        OpenStudioChoices = function(_, ...) Simple:OpenChoices(...) end,
        ConfirmStudioAction = function(_, ...) Simple:Confirm(...) end,
    }
end

local function Relevant(key)
    local class = NS.GetTalentBuildClassToken and NS.GetTalentBuildClassToken()
    return not CLASS_KEYS[key] or not class or CLASS_KEYS[key] == class
end

local function CreateMenu()
    local view = Simple:CreateView("settingsMenu")
    view._title = Label(view, "All Settings", 0, 0, 590, 20)
    view._description = Label(view, "Choose a topic. Each page shows only a few controls.", 0, -31, 590, 12, "muted")
    view._rows = {}
    for index = 1, PAGE_SIZE do
        local row = Button(view, "", 0, -66 - (index - 1) * 50, 600, function()
            local item = view._rows[index]._item
            if item then item.open() end
        end)
        row:SetHeight(40); row._label:SetJustifyH("LEFT")
        row._label:ClearAllPoints(); row._label:SetPoint("LEFT", row, "LEFT", 14, 0)
        view._rows[index] = row
    end
    view._previous = Button(view, "Previous", 0, -350, 100, function()
        Simple._menuPage = Simple._menuPage - 1; Simple:Refresh()
    end)
    view._next = Button(view, "Next", 110, -350, 80, function()
        Simple._menuPage = Simple._menuPage + 1; Simple:Refresh()
    end)
    view._page = Label(view, "", 212, -359, 110, 12, "muted")
    view._find = Button(view, "Find a Setting", 338, -350, 150, function() Simple:FindSetting() end)
    view._back = Button(view, "Back", 512, -350, 88, function()
        if Simple._topic then Simple:OpenSettings() else Simple:SelectView("main") end
    end)
    Simple:RegisterView("settingsMenu", view, function()
        local items = Simple._menuItems or {}
        local pages = math.max(1, math.ceil(#items / PAGE_SIZE))
        Simple._menuPage = math.max(1, math.min(Simple._menuPage or 1, pages))
        for index, row in ipairs(view._rows) do
            local item = items[(Simple._menuPage - 1) * PAGE_SIZE + index]
            row._item = item; row:SetShown(item ~= nil)
            if item then Fit(row._label, item.title, row._label:GetWidth()) end
        end
        view._page:SetText(Simple._menuPage .. " / " .. pages)
        SetEnabled(view._previous, Simple._menuPage > 1); SetEnabled(view._next, Simple._menuPage < pages)
    end)
    return view
end

function Simple:OpenSettings()
    Ready()
    local view = self.views.settingsMenu or CreateMenu()
    self._topic, self._menuPage, self._menuItems = nil, 1, {}
    for _, topic in ipairs(TOPICS) do
        local key = topic[1]
        self._menuItems[#self._menuItems + 1] = { title = topic[2], open = function() self:OpenSettingsTopic(key) end }
    end
    view._title:SetText("All Settings")
    view._description:SetText("Choose a topic. Each page shows only a few controls.")
    self:SelectView("settingsMenu")
end

function Simple:OpenSettingsTopic(topic)
    Ready()
    if topic == "Profiles" then return self:OpenProfiles() end
    local view = self.views.settingsMenu or CreateMenu()
    self._topic, self._menuPage, self._menuItems = topic, 1, {}
    local function Add(title, action) self._menuItems[#self._menuItems + 1] = { title = title, open = action } end
    if topic == "Talents" then
        Add("Points, Warnings and Rebuilding", function() self:OpenTalentActions() end)
        Add("Build Library and Imports", function() if self.OpenTalentLibrary then self:OpenTalentLibrary() end end)
        Add("Class Info and Simulations", function()
            if NS.ShowTalentClassInfo then NS.ShowTalentClassInfo(view, NS.GetTalentBuildCurrentSpecID()) end
        end)
    end
    local groups = Model.CompileGroups()
    for _, group in ipairs(groups[topic] or {}) do
        local keys = {}
        for _, key in ipairs(group[2]) do if Relevant(key) then keys[#keys + 1] = key end end
        if #keys > 0 then
            local selected = { group[1], keys }
            Add(group[1], function() self:OpenSettingsGroup(topic, selected) end)
        end
    end
    if topic == "Motion" or topic == "Advanced" then
        Add(topic == "Motion" and "Try Effects and Edit Palettes" or "Reports and Reset Tools", function()
            if self.OpenTools then self:OpenTools(topic) end
        end)
    end
    for _, item in ipairs(TOPICS) do if item[1] == topic then view._title:SetText(item[2]); break end end
    view._description:SetText(HELP[topic] or "Choose a group of settings.")
    self:SelectView("settingsMenu")
end

function Simple:OpenSettingsGroup(topic, group, page)
    Ready()
    self._topic = topic
    local name = "settings:" .. topic .. ":" .. group[1]
    local view = self.views[name]
    if not view then
        view = self:CreateView(name)
        view._title = Label(view, group[1], 0, 0, 590, 20)
        view._hint = Label(view, "Changes save as you make them. Press Enter after typing a value.", 0, -31, 590, 12, "muted")
        view._rows, view._keys, view._host = {}, group[2], Host(view)
        for index, key in ipairs(group[2]) do
            local row = Model.MakeSetting(view._host, view, key, -66 - ((index - 1) % PAGE_SIZE) * 52, {})
            if row then
                row._label:SetWordWrap(true); row._label:SetMaxLines(2); row._label:SetHeight(36)
                row._label:SetWidth(320)
                view._rows[#view._rows + 1] = row
                self.settingsCoverage = self.settingsCoverage or {}
                self.settingsCoverage[key] = true
            end
        end
        view._previous = Button(view, "Previous", 0, -350, 100, function() view._page = view._page - 1; self:Refresh() end)
        view._next = Button(view, "Next", 110, -350, 80, function() view._page = view._page + 1; self:Refresh() end)
        view._pageText = Label(view, "", 214, -359, 130, 12, "muted")
        Button(view, "Back", 512, -350, 88, function() self:OpenSettingsTopic(topic) end)
        self:RegisterView(name, view, function()
            local pages = math.max(1, math.ceil(#view._rows / PAGE_SIZE))
            view._page = math.max(1, math.min(view._page or 1, pages))
            for index, row in ipairs(view._rows) do
                local visible = math.ceil(index / PAGE_SIZE) == view._page
                row:SetShown(visible)
                if visible then row.Refresh() end
            end
            view._pageText:SetText(view._page .. " / " .. pages)
            SetEnabled(view._previous, view._page > 1); SetEnabled(view._next, view._page < pages)
        end)
    end
    view._page = page or 1
    self:SelectView(name)
end

function Simple:FindSetting()
    Ready()
    local view = self.views.findSetting
    if not view then
        view = self:CreateView("findSetting")
        Label(view, "Find a Setting", 0, 0, 590, 20)
        Label(view, "Type a word, then press Enter. Choose a result to open its controls.", 0, -31, 590, 12, "muted")
        view._edit = Edit(view, 0, -66, 600, 34)
        view._status = Label(view, "", 0, -115, 590, 13, "muted", 3)
        local function Search()
            local query = (view._edit:GetText() or ""):lower():match("^%s*(.-)%s*$")
            view._edit:ClearFocus()
            if query == "" then view._status:SetText("Try a word such as size, trinket, font, or particles."); return end
            local found, seen = {}, {}
            for topic, groups in pairs(Model.CompileGroups()) do
                if topic ~= "Overview" then
                    for _, group in ipairs(groups) do
                        for index, key in ipairs(group[2]) do
                            local title = Model.Title(key)
                            if not seen[key] and Relevant(key) and (title .. " " .. group[1] .. " " .. topic):lower():find(query, 1, true) then
                                local keys = {}
                                for _, k in ipairs(group[2]) do if Relevant(k) then keys[#keys + 1] = k end end
                                local at = 1
                                for i, k in ipairs(keys) do if k == key then at = i; break end end
                                found[#found + 1] = { title = title, topic = topic, group = {group[1], keys}, page = math.ceil(at / PAGE_SIZE) }
                                seen[key] = true
                            end
                        end
                    end
                end
            end
            table.sort(found, function(a, b) return a.title < b.title end)
            view._status:SetText(#found .. " matching settings.")
            if #found > 0 then self:OpenChoices("Matching Settings", found, nil, function(item)
                self:OpenSettingsGroup(item.topic, item.group, item.page)
            end, function(item) return item.title .. " · " .. item.topic end) end
        end
        view._edit:SetScript("OnEnterPressed", Search)
        view._edit:SetScript("OnEscapePressed", function() view._edit:ClearFocus(); self:OpenSettings() end)
        Button(view, "Search", 0, -350, 100, Search)
        Button(view, "Back", 512, -350, 88, function() self:OpenSettings() end)
        view:HookScript("OnHide", function() view._edit:ClearFocus() end)
        self:RegisterView("findSetting", view, function() end)
    end
    self:SelectView("findSetting")
end

function Simple:OpenProfiles()
    Ready()
    if not self.views.profiles then
        local content = self:CreateView("profiles")
        local host = Host(content)
        local view = Model.BuildProfiles(host)
        content._profileHost, content._profileView = host, view
        Button(content, "Back", 512, -350, 88, function() self:OpenSettings() end)
        self:RegisterView("profiles", content, view.Refresh)
    end
    self:SelectView("profiles")
end

function Simple:OpenTalentActions()
    Ready()
    local view = self.views.talentActions
    if not view then
        view = self:CreateView("talentActions")
        Label(view, "Points and Rebuilding", 0, 0, 590, 20)
        view._status = Label(view, "", 0, -35, 590, 13, "muted", 2)
        local function Run(fn)
            local ok, message = fn()
            self:Report(ok, message)
        end
        view._spend = Button(view, "Spend One Point", 0, -90, 282, function() Run(NS.SpendNextTalentPoint) end)
        view._all = Button(view, "Spend Available Points", 306, -90, 294, function() self:RequestSpendTalentPoints() end)
        Label(view, "Warn When Talents Differ", 0, -145, 450, 14)
        view._warn = Button(view, "Off", 526, -138, 74, function()
            local info = NS.GetTalentLevelingInfo()
            Run(function() return NS.SetTalentSBAWarningEnabled(not info.warningEnabled) end)
        end)
        Label(view, "Rebuild Automatically", 0, -195, 450, 14)
        view._autoRebuild = Button(view, "Off", 526, -188, 74, function()
            local info = NS.GetTalentLevelingInfo()
            local function Set() Run(function() return NS.SetTalentAutoRespecEnabled(not info.autoRespecEnabled) end) end
            if info.autoRespecEnabled then Set() else
                self:Confirm("When Automatic Points is on, conflicting talents may be reset and rebuilt to your chosen route. Turn on automatic rebuilding?", Set)
            end
        end)
        view._reset = Button(view, "Reset and Rebuild", 0, -250, 282, function()
            self:Confirm("Reset your talents and rebuild the chosen route using only points your current level can spend?", function() Run(NS.RequestTalentSBARespec) end)
        end)
        view._undo = Button(view, "Undo Last Rebuild", 306, -250, 294, function()
            self:Confirm("Restore the talents saved immediately before the last rebuild?", function() Run(NS.RequestTalentSBAUndo) end)
        end)
        Label(view, "Rebuilding changes learned talents. Review your route first.", 0, -299, 590, 12, "muted")
        Button(view, "Back", 512, -350, 88, function() self:OpenSettingsTopic("Talents") end)
        self:RegisterView("talentActions", view, function()
            local info = NS.GetTalentLevelingInfo()
            local undo = NS.GetTalentSBAUndoInfo and NS.GetTalentSBAUndoInfo() or {}
            SetEnabled(view._spend, info.canSpend); SetEnabled(view._all, info.canSpend or info.canRespec)
            SetEnabled(view._reset, info.canRespec); SetEnabled(view._undo, undo.canUndo)
            Plain.SetActionText(view._warn, info.warningEnabled and "On" or "Off")
            Plain.SetActionText(view._autoRebuild, info.autoRespecEnabled and "On" or "Off")
            NS.ConfigStudio.UI.SetTextIfChanged(view._status, info.status or "Choose a build first.")
        end)
    end
    self:SelectView("talentActions")
end
