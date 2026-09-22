local ADDON_NAME, NS = ...

local T = NS.THEME
local panelStates = setmetatable({}, { __mode = "k" })
local refreshFrame
local TITLE_FONT_SIZE = 14
local SUBTITLE_FONT_SIZE = 9
local LABEL_FONT_SIZE = 10
local VALUE_FONT_SIZE = 11
local BUTTON_FONT_SIZE = 11
local CHIP_FONT_SIZE = 10
local HEADER_FONT_SIZE = 10
local ROW_FONT_SIZE = 10
local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

local function CopyColor(color, alpha)
    return {
        color[1],
        color[2],
        color[3],
        alpha or color[4] or 1,
    }
end

local function MultiplyColor(color, factor, alpha)
    return {
        math.max(0, math.min(1, color[1] * factor)),
        math.max(0, math.min(1, color[2] * factor)),
        math.max(0, math.min(1, color[3] * factor)),
        alpha or color[4] or 1,
    }
end

local function BrightenColor(color, amount, alpha)
    amount = amount or 0.25
    return {
        math.max(0, math.min(1, color[1] + (1 - color[1]) * amount)),
        math.max(0, math.min(1, color[2] + (1 - color[2]) * amount)),
        math.max(0, math.min(1, color[3] + (1 - color[3]) * amount)),
        alpha or color[4] or 1,
    }
end

local function GetSpecOrderMap()
    local map = {}
    local specs = NS.GetTalentBuildSpecsForCurrentClass()
    for i = 1, #specs do
        local spec = specs[i]
        map[spec.specID] = spec.index or i
    end
    return map
end

local function CreateBackdropFrame(parent)
    local frame = NS.CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetBackdrop(BACKDROP)
    return frame
end

local function NormalizeText(value)
    if not value then
        return ""
    end
    return tostring(value):lower()
end

local function CreateTextButton(parent, label, width, onClick)
    local btn = NS.CreateFrame("Button", nil, parent)
    btn:SetSize(width, 18)

    local text = btn:CreateFontString(nil, "OVERLAY")
    text:SetFont(NS.GetConfigFontPath(), BUTTON_FONT_SIZE, "OUTLINE")
    text:SetPoint("LEFT", 0, 0)
    text:SetText(label)

    btn._text = text
    btn._enabled = true
    btn._handler = onClick

    function btn:SetCallback(handler)
        self._handler = handler
    end

    function btn:SetEnabledState(enabled, activeColor, disabledColor)
        self._enabled = enabled and true or false
        self:SetEnabled(self._enabled)
        local color = self._enabled and (activeColor or (parent._sectionColor or T.ACCENT)) or (disabledColor or T.TEXT_MUTED)
        self._text:SetTextColor(color[1], color[2], color[3])
    end

    btn:SetScript("OnEnter", function(self)
        if not self._enabled then return end
        local color = BrightenColor(parent._sectionColor or T.ACCENT, 0.35, 1)
        self._text:SetTextColor(color[1], color[2], color[3])
    end)
    btn:SetScript("OnLeave", function(self)
        if not self._enabled then
            local color = T.TEXT_MUTED
            self._text:SetTextColor(color[1], color[2], color[3])
            return
        end
        local color = parent._sectionColor or T.ACCENT
        self._text:SetTextColor(color[1], color[2], color[3])
    end)
    btn:SetScript("OnMouseDown", function(self)
        if not self._enabled then return end
        local color = MultiplyColor(parent._sectionColor or T.ACCENT, 0.75, 1)
        self._text:SetTextColor(color[1], color[2], color[3])
    end)
    btn:SetScript("OnMouseUp", function(self)
        if not self._enabled then return end
        local color = BrightenColor(parent._sectionColor or T.ACCENT, 0.2, 1)
        self._text:SetTextColor(color[1], color[2], color[3])
    end)
    btn:SetScript("OnClick", function(self)
        if not self._enabled or not self._handler then return end
        self._handler(self)
    end)

    btn:SetEnabledState(true)
    return btn
end

local function CreateChipButton(parent, label, width, onClick)
    local btn = CreateBackdropFrame(parent)
    btn:SetSize(width, 24)
    btn:EnableMouse(true)

    local text = btn:CreateFontString(nil, "OVERLAY")
    text:SetFont(NS.GetConfigFontPath(), CHIP_FONT_SIZE, "OUTLINE")
    text:SetPoint("CENTER")
    text:SetText(label)

    btn._text = text
    btn._active = false
    btn._handler = onClick

    function btn:SetCallback(handler)
        self._handler = handler
    end

    function btn:SetActive(active)
        self._active = active and true or false
        local sc = parent._sectionColor or T.ACCENT
        if self._active then
            self:SetBackdropColor(sc[1] * 0.32, sc[2] * 0.32, sc[3] * 0.32, 0.9)
            self:SetBackdropBorderColor(sc[1], sc[2], sc[3], 0.8)
            self._text:SetTextColor(sc[1], sc[2], sc[3])
        else
            self:SetBackdropColor(T.TOGGLE_OFF[1], T.TOGGLE_OFF[2], T.TOGGLE_OFF[3], 0.96)
            self:SetBackdropBorderColor(T.BORDER[1], T.BORDER[2], T.BORDER[3], 0.9)
            self._text:SetTextColor(T.TEXT_SOFT and T.TEXT_SOFT[1] or T.TEXT_DIM[1], T.TEXT_SOFT and T.TEXT_SOFT[2] or T.TEXT_DIM[2], T.TEXT_SOFT and T.TEXT_SOFT[3] or T.TEXT_DIM[3])
        end
    end

    btn:SetScript("OnEnter", function(self)
        if self._active then return end
        local sc = parent._sectionColor or T.ACCENT
        self:SetBackdropBorderColor(sc[1], sc[2], sc[3], 0.6)
    end)
    btn:SetScript("OnLeave", function(self)
        if self._active then return end
        self:SetBackdropBorderColor(T.BORDER[1], T.BORDER[2], T.BORDER[3], 0.9)
    end)
    btn:SetScript("OnMouseDown", function(self)
        if self._active then return end
        self:SetBackdropColor(T.BG_HOVER[1], T.BG_HOVER[2], T.BG_HOVER[3], 0.5)
    end)
    btn:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self._handler then
            self._handler(self)
        end
        if not self._active then
            self:SetBackdropColor(T.TOGGLE_OFF[1], T.TOGGLE_OFF[2], T.TOGGLE_OFF[3], 0.96)
        end
    end)

    btn:SetActive(false)
    return btn
end

local function EnsureURLPopup(owner)
    if owner._talentBuildURLPopup then
        return owner._talentBuildURLPopup
    end

    local popup = CreateBackdropFrame(NS.UIParent)
    popup:SetSize(560, 118)
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(100)
    popup:SetBackdropColor(T.BG_DARK[1], T.BG_DARK[2], T.BG_DARK[3], 0.98)
    popup:SetBackdropBorderColor(T.BORDER_ACCENT[1], T.BORDER_ACCENT[2], T.BORDER_ACCENT[3], 0.8)
    popup:Hide()

    local title = popup:CreateFontString(nil, "OVERLAY")
    title:SetFont(NS.GetConfigFontPath(), 10, "OUTLINE")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetTextColor(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3])
    title:SetText("Source Page")

    local editBox = NS.CreateFrame("EditBox", nil, popup, "BackdropTemplate")
    editBox:SetSize(532, 26)
    editBox:SetPoint("TOPLEFT", 12, -34)
    editBox:SetBackdrop(BACKDROP)
    editBox:SetBackdropColor(T.TOGGLE_OFF[1], T.TOGGLE_OFF[2], T.TOGGLE_OFF[3], 1)
    editBox:SetBackdropBorderColor(T.BORDER[1], T.BORDER[2], T.BORDER[3], 1)
    editBox:SetFont(NS.GetConfigFontPath(), VALUE_FONT_SIZE, "")
    editBox:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])
    editBox:SetTextInsets(6, 6, 0, 0)
    editBox:SetAutoFocus(true)
    editBox:SetMultiLine(false)
    editBox:SetMaxLetters(1024)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        popup:Hide()
    end)
    editBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)

    local hint = popup:CreateFontString(nil, "OVERLAY")
    hint:SetFont(NS.GetConfigFontPath(), LABEL_FONT_SIZE, "")
    hint:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 0, -10)
    hint:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
    hint:SetText("Ctrl+C copies the page URL for manual review.")

    local close = CreateTextButton(popup, "CLOSE", 54, function()
        popup:Hide()
    end)
    close:SetPoint("BOTTOMRIGHT", -12, 10)

    popup._title = title
    popup._editBox = editBox
    owner._talentBuildURLPopup = popup
    return popup
end

local function ShowURLPopup(owner, row)
    if not row or not row.sourceURL or row.sourceURL == "" then
        return
    end
    local popup = EnsureURLPopup(owner)
    popup._title:SetText((row.name or "Source Page") .. " - Source Page")
    popup._editBox:SetText(row.sourceURL)
    popup._editBox:SetCursorPosition(0)
    popup:ClearAllPoints()
    popup:SetPoint("CENTER", owner, "CENTER", 0, 0)
    popup:Show()
    popup._editBox:SetFocus()
    popup._editBox:HighlightText()
end

local function CreateSortResetButton(parent, onClick)
    local btn = CreateBackdropFrame(parent)
    btn:SetSize(36, 24)
    btn:EnableMouse(true)

    local lineH = btn:CreateTexture(nil, "ARTWORK")
    lineH:SetColorTexture(1, 1, 1, 1)
    lineH:SetSize(12, 2)
    lineH:SetPoint("CENTER", 0, 2)

    local lineV = btn:CreateTexture(nil, "ARTWORK")
    lineV:SetColorTexture(1, 1, 1, 1)
    lineV:SetSize(2, 12)
    lineV:SetPoint("CENTER", 0, 0)

    local diagL = btn:CreateTexture(nil, "ARTWORK")
    diagL:SetColorTexture(1, 1, 1, 1)
    diagL:SetSize(2, 6)
    diagL:SetPoint("CENTER", -4, -3)
    diagL:SetRotation(-0.78)

    local diagR = btn:CreateTexture(nil, "ARTWORK")
    diagR:SetColorTexture(1, 1, 1, 1)
    diagR:SetSize(2, 6)
    diagR:SetPoint("CENTER", 4, -3)
    diagR:SetRotation(0.78)

    btn._parts = { lineH, lineV, diagL, diagR }
    btn._active = true
    btn._handler = onClick

    function btn:SetCallback(handler)
        self._handler = handler
    end

    function btn:SetActive(active)
        self._active = active and true or false
        local sc = parent._sectionColor or T.ACCENT
        local border = self._active and sc or T.BORDER
        local fill = self._active and { sc[1] * 0.18, sc[2] * 0.18, sc[3] * 0.18, 0.9 } or T.TOGGLE_OFF
        self:SetBackdropColor(fill[1], fill[2], fill[3], fill[4] or 1)
        self:SetBackdropBorderColor(border[1], border[2], border[3], self._active and 0.8 or 0.9)
        local icon = self._active and sc or T.TEXT_MUTED
        for i = 1, #self._parts do
            self._parts[i]:SetVertexColor(icon[1], icon[2], icon[3], self._active and 1 or 0.75)
        end
    end

    btn:SetScript("OnEnter", function(self)
        if self._active then return end
        local sc = parent._sectionColor or T.ACCENT
        self:SetBackdropBorderColor(sc[1], sc[2], sc[3], 0.6)
    end)
    btn:SetScript("OnLeave", function(self)
        if self._active then return end
        self:SetBackdropBorderColor(T.BORDER[1], T.BORDER[2], T.BORDER[3], 0.9)
    end)
    btn:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and btn._handler then
            btn._handler()
        end
    end)

    btn:SetActive(true)
    return btn
end

local function GetColumnValue(row, key)
    if key == "name" then
        return row.name or ""
    elseif key == "spec" then
        return row.specName or NS.GetTalentBuildSpecName(row.specID) or ""
    elseif key == "author" then
        return row.author or ""
    elseif key == "rating" then
        return row.rating or ""
    elseif key == "source" then
        return row.source or row.catalogSource or ""
    elseif key == "type" then
        return row.buildType or ""
    end
    return ""
end

local function GetBuildSourceColor(row, sectionColor)
    if row.id == NS.TALENT_BUILD_CUSTOM_ID then
        return { 0.36, 0.78, 0.48, 1 }
    end
    local source = row.catalogSource or row.source or ""
    if source == "Icy Veins" then
        return sectionColor
    end
    if row.buildType == NS.TALENT_BUILD_TYPE_USER then
        return { 0.42, 0.62, 0.94, 1 }
    end
    if source == "Wowhead" then
        return { 0.85, 0.55, 0.25, 1 }
    end
    return { 0.50, 0.64, 0.90, 1 }
end

local function GetStatusColor(kind, sectionColor)
    if kind == "applied" or kind == "success" or kind == "custom" then
        return BrightenColor(sectionColor, 0.12, 1)
    end
    if kind == "applying" then
        return BrightenColor(sectionColor, 0.22, 1)
    end
    if kind == "queued" then
        return { 0.90, 0.72, 0.26, 1 }
    end
    if kind == "failed" or kind == "error" then
        return { 0.95, 0.42, 0.42, 1 }
    end
    if kind == "prompt" or kind == "waiting" then
        return { 0.86, 0.80, 0.34, 1 }
    end
    if kind == "selected" then
        return { 0.52, 0.68, 0.96, 1 }
    end
    return T.TEXT_DIM
end

local function GetSpecTextColor(specID, fallbackColor, isOffSpec, isSelected)
    local color = NS.GetSpecThemeColor and NS.GetSpecThemeColor(specID, fallbackColor) or fallbackColor
    if isSelected then
        return BrightenColor(color, 0.1, 1)
    end
    if isOffSpec then
        return MultiplyColor(color, 0.74, 1)
    end
    return color
end

local function BuildSearchText(row)
    return table.concat({
        NormalizeText(row.name),
        NormalizeText(row.specName or NS.GetTalentBuildSpecName(row.specID)),
        NormalizeText(row.author),
        NormalizeText(row.source),
        NormalizeText(row.catalogSource),
        NormalizeText(row.rating),
        NormalizeText(row.buildType),
    }, "\n")
end

local function EnsureDeletePopup(owner)
    if owner._talentBuildDeletePopup then
        return owner._talentBuildDeletePopup
    end

    local popup = CreateBackdropFrame(NS.UIParent)
    popup:SetSize(420, 120)
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(110)
    popup:SetBackdropColor(T.BG_DARK[1], T.BG_DARK[2], T.BG_DARK[3], 0.98)
    popup:SetBackdropBorderColor(T.BORDER_ACCENT[1], T.BORDER_ACCENT[2], T.BORDER_ACCENT[3], 0.8)
    popup:Hide()

    local title = popup:CreateFontString(nil, "OVERLAY")
    title:SetFont(NS.GetConfigFontPath(), 10, "OUTLINE")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetTextColor(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3])
    title:SetText("Delete Custom Build")

    local body = popup:CreateFontString(nil, "OVERLAY")
    body:SetFont(NS.GetConfigFontPath(), VALUE_FONT_SIZE, "")
    body:SetPoint("TOPLEFT", 12, -34)
    body:SetPoint("RIGHT", -12, 0)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])
    body:SetText("")

    local cancel = CreateTextButton(popup, "CANCEL", 52, function()
        popup:Hide()
    end)
    cancel:SetPoint("BOTTOMRIGHT", -12, 10)

    local confirm = CreateTextButton(popup, "DELETE", 52, function()
        if popup._onConfirm then
            popup._onConfirm()
        end
        popup:Hide()
    end)
    confirm:SetPoint("RIGHT", cancel, "LEFT", -18, 0)

    popup._body = body
    popup._confirm = confirm
    owner._talentBuildDeletePopup = popup
    return popup
end

local function ShowDeletePopup(owner, row, onConfirm)
    local popup = EnsureDeletePopup(owner)
    popup._body:SetText(("Delete \"%s\"?\nThis cannot be undone. If it is currently selected, that specialization will switch back to Custom."):format(row.name or "this build"))
    popup._onConfirm = onConfirm
    popup:ClearAllPoints()
    popup:SetPoint("CENTER", owner, "CENTER", 0, 0)
    popup:Show()
end

local function TrimText(value)
    value = value or ""
    return (tostring(value):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function CreatePopupField(parent, labelText, x, y, width, height, multiLine)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont(NS.GetConfigFontPath(), LABEL_FONT_SIZE, "OUTLINE")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
    label:SetText(labelText)

    local box = NS.CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetSize(width, height)
    box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
    box:SetBackdrop(BACKDROP)
    box:SetBackdropColor(T.TOGGLE_OFF[1], T.TOGGLE_OFF[2], T.TOGGLE_OFF[3], 1)
    box:SetBackdropBorderColor(T.BORDER[1], T.BORDER[2], T.BORDER[3], 1)
    box:SetFont(NS.GetConfigFontPath(), VALUE_FONT_SIZE, "")
    box:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])
    box:SetAutoFocus(false)
    box:SetMultiLine(multiLine and true or false)
    box:SetTextInsets(8, 8, multiLine and 6 or 0, multiLine and 6 or 0)
    if multiLine then
        box:SetJustifyH("LEFT")
        box:SetJustifyV("TOP")
    else
        box:SetMaxLetters(2048)
    end
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        parent:Hide()
    end)
    box:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)

    return label, box
end

local function EnsureTalentBuildEditorPopup(owner)
    if owner._talentBuildEditorPopup then
        return owner._talentBuildEditorPopup
    end

    local popup = CreateBackdropFrame(NS.UIParent)
    popup:SetSize(560, 404)
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(115)
    popup:SetClampedToScreen(true)
    popup:SetBackdropColor(T.BG_DARK[1], T.BG_DARK[2], T.BG_DARK[3], 0.985)
    popup:SetBackdropBorderColor(T.BORDER_ACCENT[1], T.BORDER_ACCENT[2], T.BORDER_ACCENT[3], 0.8)
    popup:Hide()

    local title = popup:CreateFontString(nil, "OVERLAY")
    title:SetFont(NS.GetConfigFontPath(), 10, "OUTLINE")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetTextColor(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3])
    title:SetText("Create Talent Build")

    local closeBtn = CreateTextButton(popup, "x", 12, function()
        popup:Hide()
    end)
    closeBtn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -12, -10)

    local subtitle = popup:CreateFontString(nil, "OVERLAY")
    subtitle:SetFont(NS.GetConfigFontPath(), VALUE_FONT_SIZE, "")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetPoint("RIGHT", -18, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetTextColor(T.TEXT_DIM[1], T.TEXT_DIM[2], T.TEXT_DIM[3])
    subtitle:SetText("Save a personal talent build for BetterSBA. SAVE stores only your own build entry and closes this panel.")

    local _, nameBox = CreatePopupField(popup, "Build Name", 14, -58, 248, 24, false)
    local _, sourceBox = CreatePopupField(popup, "Source", 14, -118, 248, 24, false)
    local _, urlBox = CreatePopupField(popup, "Source URL", 280, -118, 266, 24, false)
    local _, importBox = CreatePopupField(popup, "Import String", 14, -178, 532, 24, false)
    local importHint = popup:CreateFontString(nil, "OVERLAY")
    importHint:SetFont(NS.GetConfigFontPath(), LABEL_FONT_SIZE, "")
    importHint:SetPoint("TOPLEFT", importBox, "BOTTOMLEFT", 0, -4)
    importHint:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3], 0.9)
    importHint:SetText("Paste the in-game talent export string for the selected specialization.")

    local _, notesBox = CreatePopupField(popup, "Notes", 14, -238, 532, 76, true)

    local specLabel = popup:CreateFontString(nil, "OVERLAY")
    specLabel:SetFont(NS.GetConfigFontPath(), LABEL_FONT_SIZE, "OUTLINE")
    specLabel:SetPoint("TOPLEFT", popup, "TOPLEFT", 280, -58)
    specLabel:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
    specLabel:SetText("Specialization")

    local specButtons = {}
    local specs = NS.GetTalentBuildSpecsForCurrentClass()
    local lastSpecBtn
    for i = 1, #specs do
        local spec = specs[i]
        local width = math.max(72, math.floor((#(spec.name or "") * 4.6) + 18))
        local btn = CreateChipButton(popup, (spec.name or ("Spec " .. i)):upper(), width, function()
            popup:SetSelectedSpec(spec.specID)
        end)
        if i == 1 then
            btn:SetPoint("TOPLEFT", specLabel, "BOTTOMLEFT", 0, -4)
        else
            btn:SetPoint("LEFT", lastSpecBtn, "RIGHT", 8, 0)
        end
        btn._specID = spec.specID
        specButtons[#specButtons + 1] = btn
        lastSpecBtn = btn
    end

    local statusText = popup:CreateFontString(nil, "OVERLAY")
    statusText:SetFont(NS.GetConfigFontPath(), VALUE_FONT_SIZE, "")
    statusText:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 14, 38)
    statusText:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -14, 38)
    statusText:SetJustifyH("LEFT")
    statusText:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
    statusText:SetText("")

    local cancelBtn = CreateTextButton(popup, "CANCEL", 48, function()
        popup:Hide()
    end)
    cancelBtn:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -14, 12)

    local saveBtn = CreateTextButton(popup, "SAVE", 34, function()
        if not popup._selectedSpecID then
            popup:SetStatus("Pick a specialization before saving.", "error")
            return
        end

        local name = TrimText(nameBox:GetText())
        local source = TrimText(sourceBox:GetText())
        local sourceURL = TrimText(urlBox:GetText())
        local importString = TrimText(importBox:GetText())
        local notes = TrimText(notesBox:GetText())

        if name == "" then
            popup:SetStatus("Build name is required.", "error")
            nameBox:SetFocus()
            return
        end
        if importString == "" then
            popup:SetStatus("Import string is required.", "error")
            importBox:SetFocus()
            return
        end

        if NS.ValidateTalentBuildImportString then
            local ok, errorText = NS.ValidateTalentBuildImportString(importString, popup._selectedSpecID)
            if not ok then
                popup:SetStatus(errorText or "Invalid build string.", "error")
                importBox:SetFocus()
                return
            end
        end

        local seed = popup._seedEntry
        local isEdit = popup._mode == "edit" and seed and seed.buildType == NS.TALENT_BUILD_TYPE_USER
        local entry = {
            id = isEdit and seed.id or nil,
            classToken = NS.GetTalentBuildClassToken(),
            specID = popup._selectedSpecID,
            name = name,
            author = (seed and seed.author and seed.author ~= "") and seed.author or (UnitName("player") or "Unknown"),
            rating = (seed and seed.rating) or "",
            source = source ~= "" and source or "Custom",
            catalogSource = source ~= "" and source or "Custom",
            sourceURL = sourceURL,
            patch = (seed and seed.patch) or "",
            importString = importString,
            notes = notes,
            category = (seed and seed.category) or "",
        }

        local buildID = NS.SaveUserTalentBuild(entry)
        if not buildID then
            popup:SetStatus("Failed to save build.", "error")
            return
        end

        if NS.db then
            NS.db.talentBuildShowUser = true
            NS.db.talentBuildSourceFilter = NS.TALENT_BUILD_FILTER_ALL
        end
        NS.SetSelectedTalentBuildID(entry.specID, buildID)
        if NS.SetTalentBuildLastStatus then
            NS.SetTalentBuildLastStatus(entry.specID, {
                kind = "selected",
                text = ((isEdit and "Saved ") or "Created ") .. entry.name,
                buildID = buildID,
                time = GetTime(),
            })
        end
        if NS.ShowConfigStatusMessage then
            NS.ShowConfigStatusMessage(((isEdit and "Saved ") or "Created ") .. entry.name, "success", 4)
        end

        popup:Hide()

        if popup._state and popup._state.Refresh then
            popup._state.selectedID = buildID
            popup._state.selectedSpecID = entry.specID
            popup._state:Refresh()
        end
    end)
    saveBtn:SetPoint("RIGHT", cancelBtn, "LEFT", -20, 0)

    function popup:SetStatus(text, kind)
        local color = T.TEXT_MUTED
        if kind == "error" then
            color = T.DANGER or { 0.95, 0.42, 0.42, 1 }
        elseif kind == "success" then
            color = popup._sectionColor or T.ACCENT
        end
        statusText:SetTextColor(color[1], color[2], color[3], color[4] or 1)
        statusText:SetText(text or "")
    end

    function popup:SetSelectedSpec(specID)
        self._selectedSpecID = specID
        for i = 1, #specButtons do
            specButtons[i]:SetActive(specButtons[i]._specID == specID)
        end
    end

    popup:SetScript("OnHide", function()
        nameBox:ClearFocus()
        sourceBox:ClearFocus()
        urlBox:ClearFocus()
        importBox:ClearFocus()
        notesBox:ClearFocus()
        popup:SetStatus("")
    end)

    popup._title = title
    popup._subtitle = subtitle
    popup._nameBox = nameBox
    popup._sourceBox = sourceBox
    popup._urlBox = urlBox
    popup._importBox = importBox
    popup._notesBox = notesBox
    popup._specButtons = specButtons
    popup._saveBtn = saveBtn
    popup._cancelBtn = cancelBtn
    popup._closeBtn = closeBtn
    owner._talentBuildEditorPopup = popup
    return popup
end

local function ShowTalentBuildEditor(owner, state, mode, seed)
    local popup = EnsureTalentBuildEditorPopup(owner)
    popup._sectionColor = owner._sectionColor or T.ACCENT
    popup:SetBackdropBorderColor(popup._sectionColor[1], popup._sectionColor[2], popup._sectionColor[3], 0.8)
    popup._title:SetText((mode == "edit" and "Edit Talent Build") or (mode == "copy" and "Copy Talent Build") or "Create Talent Build")
    popup._subtitle:SetText((mode == "edit" and "Update your saved build, then SAVE to keep the changes.")
        or (mode == "copy" and "Review the copied values, then SAVE to create a new personal build.")
        or "Create a new personal talent build, then SAVE to store it and close this panel.")

    popup._mode = mode or "create"
    popup._seedEntry = seed
    popup._state = state

    local currentSpecID = NS.GetTalentBuildCurrentSpecID()
    local defaultName = ""
    local defaultSpecID = currentSpecID
    local defaultSource = "Custom"
    local defaultURL = ""
    local defaultImport = ""
    local defaultNotes = ""

    if seed then
        defaultSpecID = seed.specID or currentSpecID
        defaultSource = seed.source or seed.catalogSource or "Custom"
        defaultURL = seed.sourceURL or ""
        defaultImport = seed.importString or ""
        defaultNotes = seed.notes or ""
        if mode == "edit" then
            defaultName = seed.name or ""
        elseif mode == "copy" then
            defaultName = ((seed.name and seed.name ~= "") and seed.name or "Build") .. " Copy"
        end
    end

    popup._nameBox:SetText(defaultName)
    popup._sourceBox:SetText(defaultSource)
    popup._urlBox:SetText(defaultURL)
    popup._importBox:SetText(defaultImport)
    popup._notesBox:SetText(defaultNotes)
    popup:SetSelectedSpec(defaultSpecID)
    popup:SetStatus("")

    popup:ClearAllPoints()
    popup:SetPoint("CENTER", owner, "CENTER", 0, 0)
    popup:Show()
    popup._nameBox:SetFocus()
    popup._nameBox:HighlightText()
end

local function CreateSubHeader(parent, text, yPos)
    local col = parent._sectionColor or T.TEXT_DIM
    local hdr = parent:CreateFontString(nil, "OVERLAY")
    hdr:SetFont(NS.GetConfigFontPath(), HEADER_FONT_SIZE, "OUTLINE")
    hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, yPos)
    hdr:SetTextColor(col[1], col[2], col[3])
    hdr:SetText(text)
    hdr._sectionIndex = parent._sectionIndex
    hdr._navY = yPos
    hdr._baseColor = { col[1], col[2], col[3] }
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetColorTexture(col[1], col[2], col[3], 0.4)
    line:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -3)
    line:SetPoint("RIGHT", parent, "RIGHT", -14, 0)
    hdr._line = line
    if parent._subsections then
        parent._subsections[#parent._subsections + 1] = {
            label = text,
            y = yPos,
            header = hdr,
        }
    end
    return hdr
end

local function GetDynamicSources(rows)
    local seen = {}
    local available = {}
    for i = 1, #rows do
        local row = rows[i]
        local source = row.source or row.catalogSource or ""
        if source ~= "" then
            available[source] = true
        end
    end
    local ordered = {}
    for i = 1, #NS.TALENT_BUILD_SOURCES do
        local source = NS.TALENT_BUILD_SOURCES[i]
        if source ~= NS.TALENT_BUILD_FILTER_ALL and available[source] and not seen[source] then
            seen[source] = true
            ordered[#ordered + 1] = source
        end
    end
    for source in pairs(available) do
        if not seen[source] then
            seen[source] = true
            ordered[#ordered + 1] = source
        end
    end
    return ordered
end

local function RefreshAllPanels()
    for parent, state in pairs(panelStates) do
        if state and state.Refresh and parent and parent:IsVisible() then
            state:Refresh()
        end
    end
end

local function EnsureRefreshFrame()
    if refreshFrame then
        return
    end
    refreshFrame = NS.CreateFrame("Frame")
    refreshFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    refreshFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    refreshFrame:RegisterEvent("PLAYER_LEVEL_UP")
    refreshFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    refreshFrame:SetScript("OnEvent", function()
        RefreshAllPanels()
    end)
end

function NS.RefreshTalentBuildPanels()
    RefreshAllPanels()
end

function NS.BuildTalentBuildsConfigSection(parent)
    EnsureRefreshFrame()

    local state = panelStates[parent]
    if state and state.Refresh then
        state:Refresh()
        return state
    end

    state = {}
    panelStates[parent] = state

    local width = parent._contentWidth or parent:GetWidth()
    local sectionColor = parent._sectionColor or T.ACCENT
    local sectionBright = parent._sectionColorBright or BrightenColor(sectionColor, 0.3, 1)
    local sectionDim = parent._sectionColorDim or MultiplyColor(sectionColor, 0.82, 0.7)
    local innerW = width - 28
    local detailsW = 200
    local gutter = 12
    local tableW = innerW - detailsW - gutter
    local headerY = -8
    local actionY = -506
    local bottomNoteY = -528
    local sectionH = 560
    local rowH = 24
    local searchW = math.max(260, tableW - 340)
    local chipStartX = 14 + searchW + 16

    parent._sectionColor = sectionColor
    parent._sectionColorBright = sectionBright
    parent._sectionColorDim = sectionDim

    CreateSubHeader(parent, "BUILD CATALOG", headerY)
    local selectedHdr = CreateSubHeader(parent, "SELECTED BUILD", -76)

    local title = parent:CreateFontString(nil, "OVERLAY")
    title:SetFont(NS.GetConfigFontPath(), TITLE_FONT_SIZE, "OUTLINE")
    title:SetPoint("TOPLEFT", 14, -30)
    title:SetTextColor(sectionColor[1], sectionColor[2], sectionColor[3])
    title:SetText("TALENT BUILDS")

    local subtitle = parent:CreateFontString(nil, "OVERLAY")
    subtitle:SetFont(NS.GetConfigFontPath(), SUBTITLE_FONT_SIZE, "")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -7)
    subtitle:SetTextColor(T.TEXT_DIM[1], T.TEXT_DIM[2], T.TEXT_DIM[3])
    subtitle:SetText("")

    local topRule = parent:CreateTexture(nil, "ARTWORK")
    topRule:SetHeight(2)
    topRule:SetColorTexture(sectionColor[1], sectionColor[2], sectionColor[3], 0.7)
    topRule:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -4, -24)
    topRule:SetPoint("RIGHT", parent, "LEFT", math.min(width - 150, 760), 0)

    local searchLabel = NS.CreateFrame("Frame", nil, parent)
    searchLabel:SetSize(searchW, 14)
    searchLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -94)
    local searchLabelText = searchLabel:CreateFontString(nil, "OVERLAY")
    searchLabelText:SetFont(NS.GetConfigFontPath(), LABEL_FONT_SIZE, "OUTLINE")
    searchLabelText:SetPoint("BOTTOMLEFT", searchLabel, "TOPLEFT", 0, 2)
    searchLabelText:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
    searchLabelText:SetText("Search Builds")

    local searchBox = NS.CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    searchBox:SetSize(searchW, 24)
    searchBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -110)
    searchBox:SetBackdrop(BACKDROP)
    searchBox:SetBackdropColor(T.TOGGLE_OFF[1], T.TOGGLE_OFF[2], T.TOGGLE_OFF[3], 1)
    searchBox:SetBackdropBorderColor(T.BORDER[1], T.BORDER[2], T.BORDER[3], 1)
    searchBox:SetFont(NS.GetConfigFontPath(), VALUE_FONT_SIZE, "")
    searchBox:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])
    searchBox:SetTextInsets(8, 8, 0, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(80)
    searchBox:SetText(NS.db.talentBuildSearchText or "")

    local searchPlaceholder = searchBox:CreateFontString(nil, "OVERLAY")
    searchPlaceholder:SetFont(NS.GetConfigFontPath(), VALUE_FONT_SIZE, "")
    searchPlaceholder:SetPoint("LEFT", 8, 0)
    searchPlaceholder:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
    searchPlaceholder:SetText("Search builds, author, source...")
    searchPlaceholder:SetShown((NS.db.talentBuildSearchText or "") == "")

    local filterLabel = parent:CreateFontString(nil, "OVERLAY")
    filterLabel:SetFont(NS.GetConfigFontPath(), LABEL_FONT_SIZE, "OUTLINE")
    filterLabel:SetPoint("BOTTOMLEFT", searchBox, "TOPLEFT", chipStartX - 14, 2)
    filterLabel:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
    filterLabel:SetText("Filters")

    local allChip = CreateChipButton(parent, "ALL", 44, function() end)
    allChip:SetPoint("TOPLEFT", parent, "TOPLEFT", chipStartX, -110)
    local builtInChip = CreateChipButton(parent, "BUILT-IN", 74, function() end)
    builtInChip:SetPoint("LEFT", allChip, "RIGHT", 8, 0)
    local userChip = CreateChipButton(parent, "USER", 52, function() end)
    userChip:SetPoint("LEFT", builtInChip, "RIGHT", 8, 0)

    local typeButtons = {
        all = allChip,
        builtIn = builtInChip,
        user = userChip,
    }

    -- Source chips are created on demand and wrapped to the next row.
    local sourceButtons = {}

    local defaultSortLabel = parent:CreateFontString(nil, "OVERLAY")
    defaultSortLabel:SetFont(NS.GetConfigFontPath(), LABEL_FONT_SIZE, "OUTLINE")
    defaultSortLabel:SetPoint("LEFT", userChip, "RIGHT", 16, 0)
    defaultSortLabel:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
    defaultSortLabel:SetText("Default sort")

    local sortReset = CreateSortResetButton(parent, function() end)
    sortReset:SetPoint("LEFT", defaultSortLabel, "RIGHT", 8, 0)

    local tablePanel = CreateBackdropFrame(parent)
    tablePanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -158)
    tablePanel:SetSize(tableW, 330)
    tablePanel:SetBackdropColor(T.BG[1], T.BG[2], T.BG[3], 0.92)
    tablePanel:SetBackdropBorderColor(T.BORDER[1], T.BORDER[2], T.BORDER[3], 0.85)

    local detailsPanel = CreateBackdropFrame(parent)
    detailsPanel:SetPoint("TOPLEFT", tablePanel, "TOPRIGHT", gutter, 0)
    detailsPanel:SetSize(detailsW, 248)
    detailsPanel:SetBackdropColor(T.BG[1], T.BG[2], T.BG[3], 0.92)
    detailsPanel:SetBackdropBorderColor(T.BORDER[1], T.BORDER[2], T.BORDER[3], 0.85)

    local detailsTitle = detailsPanel:CreateFontString(nil, "OVERLAY")
    detailsTitle:SetFont(NS.GetConfigFontPath(), 8, "OUTLINE")
    detailsTitle:SetPoint("TOPLEFT", 14, -12)
    detailsTitle:SetTextColor(sectionColor[1], sectionColor[2], sectionColor[3])
    detailsTitle:SetText("SELECTED BUILD")

    local detailsName = detailsPanel:CreateFontString(nil, "OVERLAY")
    detailsName:SetFont(NS.GetConfigFontPath(), 10, "OUTLINE")
    detailsName:SetPoint("TOPLEFT", detailsTitle, "BOTTOMLEFT", 0, -12)
    detailsName:SetPoint("RIGHT", -14, 0)
    detailsName:SetJustifyH("LEFT")
    detailsName:SetJustifyV("TOP")
    detailsName:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])
    detailsName:SetText("")

    local fieldLabels = {}
    local fieldValues = {}
    local fields = {
        { key = "spec", label = "Spec" },
        { key = "author", label = "Author" },
        { key = "source", label = "Source" },
        { key = "rating", label = "Rating" },
        { key = "type", label = "Type" },
        { key = "status", label = "Status" },
    }
    local lastField
    for i = 1, #fields do
        local meta = fields[i]
        local label = detailsPanel:CreateFontString(nil, "OVERLAY")
        label:SetFont(NS.GetConfigFontPath(), LABEL_FONT_SIZE, "OUTLINE")
        if i == 1 then
            label:SetPoint("TOPLEFT", detailsName, "BOTTOMLEFT", 0, -16)
        else
            label:SetPoint("TOPLEFT", lastField, "BOTTOMLEFT", 0, -12)
        end
        label:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
        label:SetText(meta.label)

        local value = detailsPanel:CreateFontString(nil, "OVERLAY")
        value:SetFont(NS.GetConfigFontPath(), VALUE_FONT_SIZE, "OUTLINE")
        value:SetPoint("LEFT", label, "RIGHT", 16, 0)
        value:SetPoint("RIGHT", -14, 0)
        value:SetJustifyH("LEFT")
        value:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])
        value:SetText("")

        fieldLabels[meta.key] = label
        fieldValues[meta.key] = value
        lastField = label
    end

    local behaviorLabel = detailsPanel:CreateFontString(nil, "OVERLAY")
    behaviorLabel:SetFont(NS.GetConfigFontPath(), LABEL_FONT_SIZE, "OUTLINE")
    behaviorLabel:SetPoint("TOPLEFT", fieldLabels.status, "BOTTOMLEFT", 0, -14)
    behaviorLabel:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
    behaviorLabel:SetText("Behavior")

    local behaviorText = detailsPanel:CreateFontString(nil, "OVERLAY")
    behaviorText:SetFont(NS.GetConfigFontPath(), VALUE_FONT_SIZE, "OUTLINE")
    behaviorText:SetPoint("TOPLEFT", behaviorLabel, "BOTTOMLEFT", 0, -4)
    behaviorText:SetPoint("RIGHT", -14, 0)
    behaviorText:SetJustifyH("LEFT")
    behaviorText:SetJustifyV("TOP")
    behaviorText:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])
    behaviorText:SetText("")

    local sourceBtn = CreateTextButton(parent, "VIEW SOURCE", 78, function() end)
    sourceBtn:SetPoint("TOPLEFT", detailsPanel, "BOTTOMLEFT", 4, -10)

    local tableHeader = CreateBackdropFrame(tablePanel)
    tableHeader:SetPoint("TOPLEFT", 1, -1)
    tableHeader:SetPoint("TOPRIGHT", -1, -1)
    tableHeader:SetHeight(28)
    tableHeader:SetBackdropColor(T.BG_DARK[1], T.BG_DARK[2], T.BG_DARK[3], 0.98)
    tableHeader:SetBackdropBorderColor(0, 0, 0, 0)

    local listScroll = NS.CreateFrame("ScrollFrame", nil, tablePanel)
    listScroll:SetPoint("TOPLEFT", tablePanel, "TOPLEFT", 1, -29)
    listScroll:SetPoint("BOTTOMRIGHT", tablePanel, "BOTTOMRIGHT", -10, 0)
    listScroll:EnableMouseWheel(true)

    local listChild = NS.CreateFrame("Frame", nil, listScroll)
    listChild:SetPoint("TOPLEFT")
    listChild:SetWidth(tableW - 12)
    listChild:SetHeight(10)
    listScroll:SetScrollChild(listChild)

    local listTrack = CreateBackdropFrame(tablePanel)
    listTrack:SetWidth(8)
    listTrack:SetPoint("TOPRIGHT", tablePanel, "TOPRIGHT", -1, -29)
    listTrack:SetPoint("BOTTOMRIGHT", tablePanel, "BOTTOMRIGHT", -1, 1)
    listTrack:SetBackdropColor(T.BG_DARK[1], T.BG_DARK[2], T.BG_DARK[3], 0.55)
    listTrack:SetBackdropBorderColor(0, 0, 0, 0)

    local listThumb = CreateBackdropFrame(listTrack)
    listThumb:SetWidth(8)
    listThumb:SetPoint("TOP", 0, 0)
    listThumb:SetBackdropColor(sectionDim[1], sectionDim[2], sectionDim[3], 0.88)
    listThumb:SetBackdropBorderColor(0, 0, 0, 0)
    listThumb:EnableMouse(true)
    listThumb:SetMovable(true)

    local columns = {
        { key = "name", label = "BUILD NAME", width = math.floor((tableW - 18) * 0.32), justify = "LEFT" },
        { key = "spec", label = "SPEC", width = math.floor((tableW - 18) * 0.21), justify = "LEFT" },
        { key = "author", label = "AUTHOR", width = math.floor((tableW - 18) * 0.11), justify = "LEFT" },
        { key = "rating", label = "RATING", width = 44, justify = "CENTER" },
        { key = "source", label = "SOURCE", width = math.floor((tableW - 18) * 0.12), justify = "LEFT" },
        { key = "type", label = "TYPE", width = 0, justify = "LEFT" },
    }
    local usedWidth = 0
    for i = 1, #columns - 1 do
        usedWidth = usedWidth + columns[i].width
    end
    columns[#columns].width = (tableW - 18) - usedWidth

    state.parent = parent
    state.columns = columns
    state.rows = {}
    state.filteredRows = {}
    state.rowButtons = {}
    state.selectedID = nil
    state.sourceButtons = {}
    state.typeButtons = typeButtons
    state.tablePanel = tablePanel
    state.listScroll = listScroll
    state.listChild = listChild
    state.listTrack = listTrack
    state.listThumb = listThumb
    state.subtitle = subtitle
    state.detailsName = detailsName
    state.fieldValues = fieldValues
    state.behaviorText = behaviorText
    state.sourceBtn = sourceBtn
    state.sortReset = sortReset
    state.sectionColor = sectionColor
    state.defaultSortLabel = defaultSortLabel
    state.selectedHdr = selectedHdr

    local headerButtons = {}
    local headerArrows = {}
    local headerX = 0
    for i = 1, #columns do
        local column = columns[i]
        local btn = NS.CreateFrame("Button", nil, tableHeader)
        btn:SetSize(column.width, 28)
        btn:SetPoint("TOPLEFT", headerX, 0)
        btn._columnKey = column.key

        local label = btn:CreateFontString(nil, "OVERLAY")
        label:SetFont(NS.GetConfigFontPath(), HEADER_FONT_SIZE, "OUTLINE")
        if column.justify == "CENTER" then
            label:SetPoint("CENTER")
            label:SetJustifyH("CENTER")
        else
            label:SetPoint("LEFT", 12, 0)
            label:SetPoint("RIGHT", -14, 0)
            label:SetJustifyH("LEFT")
        end
        label:SetTextColor(T.TEXT_DIM[1], T.TEXT_DIM[2], T.TEXT_DIM[3])
        label:SetText(column.label)

        local arrow = btn:CreateFontString(nil, "OVERLAY")
        arrow:SetFont(NS.GetConfigFontPath(), 6, "OUTLINE")
        arrow:SetPoint("RIGHT", -8, 0)
        arrow:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3], 0.55)
        arrow:SetText("")

        local sep = btn:CreateTexture(nil, "ARTWORK")
        sep:SetColorTexture(T.BORDER[1], T.BORDER[2], T.BORDER[3], 0.65)
        sep:SetWidth(1)
        sep:SetPoint("TOPRIGHT", 0, -6)
        sep:SetPoint("BOTTOMRIGHT", 0, 6)
        if i == #columns then
            sep:Hide()
        end

        btn._label = label
        btn._arrow = arrow
        btn._sep = sep
        headerButtons[i] = btn
        headerArrows[column.key] = arrow
        headerX = headerX + column.width
    end

    local actionsRule = parent:CreateTexture(nil, "ARTWORK")
    actionsRule:SetHeight(2)
    actionsRule:SetColorTexture(sectionColor[1], sectionColor[2], sectionColor[3], 0.6)
    actionsRule:SetPoint("TOPLEFT", tablePanel, "BOTTOMLEFT", 0, -8)
    actionsRule:SetPoint("RIGHT", detailsPanel, "LEFT", -12, 0)

    local applyBtn = CreateTextButton(parent, "APPLY", 36, function() end)
    applyBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, actionY)
    local createBtn = CreateTextButton(parent, "CREATE", 46, function() end)
    createBtn:SetPoint("LEFT", applyBtn, "RIGHT", 28, 0)
    local editBtn = CreateTextButton(parent, "EDIT", 28, function() end)
    editBtn:SetPoint("LEFT", createBtn, "RIGHT", 28, 0)
    local deleteBtn = CreateTextButton(parent, "DELETE", 42, function() end)
    deleteBtn:SetPoint("LEFT", editBtn, "RIGHT", 28, 0)
    local copyBtn = CreateTextButton(parent, "COPY", 30, function() end)
    copyBtn:SetPoint("LEFT", deleteBtn, "RIGHT", 28, 0)

    local loadAnywayBtn = CreateTextButton(parent, "LOAD ANYWAY", 92, function() end)
    loadAnywayBtn:SetPoint("TOPRIGHT", tablePanel, "BOTTOMRIGHT", 0, -10)
    loadAnywayBtn:Hide()

    local footerNote = parent:CreateFontString(nil, "OVERLAY")
    footerNote:SetFont(NS.GetConfigFontPath(), LABEL_FONT_SIZE, "")
    footerNote:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, bottomNoteY)
    footerNote:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3], 0.85)
    footerNote:SetText("Single click applies active-spec rows. LOAD ANYWAY appears only for an off-spec selection.")

    local bottomRule = parent:CreateTexture(nil, "ARTWORK")
    bottomRule:SetHeight(2)
    local bottomColor = MultiplyColor(sectionColor, 0.62, 0.65)
    bottomRule:SetColorTexture(bottomColor[1], bottomColor[2], bottomColor[3], bottomColor[4] or 0.65)
    bottomRule:SetPoint("TOPLEFT", footerNote, "BOTTOMLEFT", 0, -10)
    bottomRule:SetPoint("RIGHT", parent, "RIGHT", -14, 0)

    parent._searchTargets = {
        searchBox = searchBox,
        applyBtn = applyBtn,
        loadAnywayBtn = loadAnywayBtn,
        createBtn = createBtn,
        editBtn = editBtn,
        deleteBtn = deleteBtn,
        copyBtn = copyBtn,
        sourceBtn = sourceBtn,
    }

    local thumbDragging = false
    local thumbDragStart = 0
    local thumbScrollStart = 0

    local function UpdateListScrollbar()
        local contentH = listChild:GetHeight()
        local viewH = listScroll:GetHeight()
        if contentH <= viewH then
            listTrack:Hide()
            return
        end
        listTrack:Show()
        local trackH = listTrack:GetHeight()
        local ratio = viewH / contentH
        local thumbH = math.max(24, trackH * ratio)
        listThumb:SetHeight(thumbH)
        local scrollRange = contentH - viewH
        local scroll = listScroll:GetVerticalScroll()
        local pct = scrollRange > 0 and (scroll / scrollRange) or 0
        local travel = trackH - thumbH
        listThumb:ClearAllPoints()
        listThumb:SetPoint("TOP", listTrack, "TOP", 0, -pct * travel)
    end

    listThumb:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        thumbDragging = true
        self:SetScript("OnUpdate", function(frame)
            if not thumbDragging then return end
            local _, cursorY = GetCursorPosition()
            local scale = frame:GetEffectiveScale()
            cursorY = cursorY / scale
            local delta = thumbDragStart - cursorY
            local trackH = listTrack:GetHeight()
            local thumbH = frame:GetHeight()
            local scrollRange = listChild:GetHeight() - listScroll:GetHeight()
            if scrollRange <= 0 or trackH <= thumbH then return end
            local scrollPerPixel = scrollRange / (trackH - thumbH)
            local newScroll = math.max(0, math.min(scrollRange, thumbScrollStart + delta * scrollPerPixel))
            listScroll:SetVerticalScroll(newScroll)
        end)
        local _, cursorY = GetCursorPosition()
        local scale = self:GetEffectiveScale()
        thumbDragStart = cursorY / scale
        thumbScrollStart = listScroll:GetVerticalScroll()
    end)
    listThumb:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            thumbDragging = false
            listThumb:SetScript("OnUpdate", nil)
        end
    end)
    listThumb:SetScript("OnHide", function(self)
        thumbDragging = false
        self:SetScript("OnUpdate", nil)
    end)
    listScroll:SetScript("OnScrollRangeChanged", UpdateListScrollbar)
    listScroll:SetScript("OnVerticalScroll", UpdateListScrollbar)
    listScroll:SetScript("OnMouseWheel", function(_, delta)
        local maxScroll = math.max(0, listChild:GetHeight() - listScroll:GetHeight())
        local nextScroll = math.max(0, math.min(maxScroll, listScroll:GetVerticalScroll() - delta * 26))
        listScroll:SetVerticalScroll(nextScroll)
    end)

    function state:GetTypeFilter()
        if NS.db.talentBuildShowBuiltIn and NS.db.talentBuildShowUser then
            return "all"
        end
        if NS.db.talentBuildShowBuiltIn and not NS.db.talentBuildShowUser then
            return "builtIn"
        end
        if not NS.db.talentBuildShowBuiltIn and NS.db.talentBuildShowUser then
            return "user"
        end
        return "all"
    end

    function state:SetTypeFilter(filter)
        if filter == "builtIn" then
            NS.db.talentBuildShowBuiltIn = true
            NS.db.talentBuildShowUser = false
        elseif filter == "user" then
            NS.db.talentBuildShowBuiltIn = false
            NS.db.talentBuildShowUser = true
        else
            NS.db.talentBuildShowBuiltIn = true
            NS.db.talentBuildShowUser = true
        end
        self:Refresh()
    end

    function state:SetSourceFilter(source)
        NS.db.talentBuildSourceFilter = source or NS.TALENT_BUILD_FILTER_ALL
        self:Refresh()
    end

    function state:UseDefaultSort()
        NS.db.talentBuildUseDefaultSort = true
        self:Refresh()
    end

    function state:SetSort(columnKey)
        if NS.db.talentBuildUseDefaultSort then
            NS.db.talentBuildUseDefaultSort = false
            NS.db.talentBuildSortColumn = columnKey
            NS.db.talentBuildSortAscending = true
        elseif NS.db.talentBuildSortColumn == columnKey then
            NS.db.talentBuildSortAscending = not NS.db.talentBuildSortAscending
        else
            NS.db.talentBuildSortColumn = columnKey
            NS.db.talentBuildSortAscending = true
        end
        self:Refresh()
    end

    function state:CollectRows()
        local rows = {}
        local activeSpecID = NS.GetTalentBuildCurrentSpecID()
        local activeSpecName = NS.GetTalentBuildSpecName(activeSpecID)
        if activeSpecID then
            rows[#rows + 1] = NS.GetTalentBuildCustomEntry(activeSpecID, activeSpecName)
        end
        local classToken = NS.GetTalentBuildClassToken()
        local entries = NS.GetTalentBuildEntriesForClass(classToken)
        for i = 1, #entries do
            local row = entries[i]
            row.specName = row.specName or NS.GetTalentBuildSpecName(row.specID)
            row._searchText = BuildSearchText(row)
            rows[#rows + 1] = row
        end
        for i = 1, #rows do
            local row = rows[i]
            row.specName = row.specName or NS.GetTalentBuildSpecName(row.specID)
            row._searchText = row._searchText or BuildSearchText(row)
        end
        return rows
    end

    function state:GetSortedRows(rows)
        local activeSpecID = NS.GetTalentBuildCurrentSpecID()
        local specOrder = GetSpecOrderMap()
        local useDefaultSort = NS.db.talentBuildUseDefaultSort
        local sortColumn = NS.db.talentBuildSortColumn or "name"
        local sortAscending = NS.db.talentBuildSortAscending ~= false

        table.sort(rows, function(a, b)
            if useDefaultSort then
                local aActive = a.specID == activeSpecID and 0 or 1
                local bActive = b.specID == activeSpecID and 0 or 1
                if aActive ~= bActive then
                    return aActive < bActive
                end
                if a.specID ~= b.specID then
                    return (specOrder[a.specID] or 99) < (specOrder[b.specID] or 99)
                end
                local aCustom = a.id == NS.TALENT_BUILD_CUSTOM_ID and 0 or 1
                local bCustom = b.id == NS.TALENT_BUILD_CUSTOM_ID and 0 or 1
                if aCustom ~= bCustom then
                    return aCustom < bCustom
                end
                if a.buildType ~= b.buildType then
                    if a.buildType == NS.TALENT_BUILD_TYPE_USER then
                        return true
                    end
                    if b.buildType == NS.TALENT_BUILD_TYPE_USER then
                        return false
                    end
                end
                return NormalizeText(a.name) < NormalizeText(b.name)
            end

            local aValue = NormalizeText(GetColumnValue(a, sortColumn))
            local bValue = NormalizeText(GetColumnValue(b, sortColumn))
            if sortColumn == "rating" then
                local weights = { S = 5, A = 4, B = 3, C = 2, D = 1 }
                aValue = weights[a.rating or ""] or 0
                bValue = weights[b.rating or ""] or 0
                if aValue ~= bValue then
                    return sortAscending and (aValue > bValue) or (aValue < bValue)
                end
            end
            if aValue ~= bValue then
                return sortAscending and (aValue < bValue) or (aValue > bValue)
            end
            return NormalizeText(a.name) < NormalizeText(b.name)
        end)

        return rows
    end

    function state:FilterRows(rows)
        local filtered = {}
        local searchText = NormalizeText(NS.db.talentBuildSearchText)
        local typeFilter = self:GetTypeFilter()
        local sourceFilter = NS.db.talentBuildSourceFilter or NS.TALENT_BUILD_FILTER_ALL

        for i = 1, #rows do
            local row = rows[i]
            local isCustom = row.id == NS.TALENT_BUILD_CUSTOM_ID
            local matchesSearch = searchText == "" or row._searchText:find(searchText, 1, true)
            local matchesType = true
            if not isCustom then
                if typeFilter == "builtIn" then
                    matchesType = row.buildType == NS.TALENT_BUILD_TYPE_BUILTIN
                elseif typeFilter == "user" then
                    matchesType = row.buildType == NS.TALENT_BUILD_TYPE_USER
                end
            end
            local matchesSource = sourceFilter == NS.TALENT_BUILD_FILTER_ALL or (row.source == sourceFilter or row.catalogSource == sourceFilter)
            if isCustom and sourceFilter == NS.TALENT_BUILD_FILTER_ALL then
                matchesSource = true
            end
            if matchesSearch and matchesType and matchesSource then
                filtered[#filtered + 1] = row
            end
        end
        return filtered
    end

    function state:EnsureSelectedRow()
        if self.selectedID then
            for i = 1, #self.filteredRows do
                if self.filteredRows[i].id == self.selectedID and self.filteredRows[i].specID == self.selectedSpecID then
                    return self.filteredRows[i]
                end
            end
        end

        local activeSpecID = NS.GetTalentBuildCurrentSpecID()
        local selectedID = NS.GetSelectedTalentBuildID(activeSpecID)
        self.selectedID = selectedID or NS.TALENT_BUILD_CUSTOM_ID
        self.selectedSpecID = activeSpecID

        for i = 1, #self.filteredRows do
            local row = self.filteredRows[i]
            if row.specID == activeSpecID and row.id == self.selectedID then
                return row
            end
        end

        for i = 1, #self.filteredRows do
            local row = self.filteredRows[i]
            if row.specID == activeSpecID and row.id == NS.TALENT_BUILD_CUSTOM_ID then
                self.selectedID = row.id
                return row
            end
        end

        local row = self.filteredRows[1]
        if row then
            self.selectedID = row.id
            self.selectedSpecID = row.specID
        end
        return row
    end

    function state:UpdateFilterButtons()
        local typeFilter = self:GetTypeFilter()
        typeButtons.all:SetActive(typeFilter == "all")
        typeButtons.builtIn:SetActive(typeFilter == "builtIn")
        typeButtons.user:SetActive(typeFilter == "user")

        local sources = GetDynamicSources(self.rows)
        self.dynamicSources = sources
        local rightEdge = width - 14
        local cursorX, rowIndex = chipStartX, 1
        local lastVisible = userChip
        for i = 1, #sources do
            local source = sources[i]
            local btn = sourceButtons[i]
            if not btn then
                btn = CreateChipButton(parent, "", 72, function() end)
                btn:SetCallback(function(self)
                    if self._source then state:SetSourceFilter(self._source) end
                end)
                sourceButtons[i] = btn
            end
            btn._source = source
            btn._text:SetText(source:upper())
            local btnW = math.min(math.max(56, btn._text:GetStringWidth() + 20), rightEdge - chipStartX)
            if cursorX + btnW > rightEdge and cursorX > chipStartX then
                rowIndex = rowIndex + 1
                cursorX = chipStartX
            end
            btn:SetWidth(btnW)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", parent, "TOPLEFT", cursorX, -110 - (rowIndex - 1) * 30)
            btn:SetActive((NS.db.talentBuildSourceFilter or NS.TALENT_BUILD_FILTER_ALL) == source)
            btn:Show()
            lastVisible = btn
            cursorX = cursorX + btnW + 8
        end
        for i = #sources + 1, #sourceButtons do
            sourceButtons[i]:Hide()
        end
        if cursorX + 110 > rightEdge then
            rowIndex = rowIndex + 1
            cursorX = chipStartX
        end
        defaultSortLabel:ClearAllPoints()
        defaultSortLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", cursorX, -110 - (rowIndex - 1) * 30)
        sortReset:ClearAllPoints()
        sortReset:SetPoint("LEFT", defaultSortLabel, "RIGHT", 8, 0)
        local delta = (rowIndex - 1) * 30
        tablePanel:ClearAllPoints()
        tablePanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -158 - delta)
        applyBtn:ClearAllPoints()
        applyBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -506 - delta)
        createBtn:ClearAllPoints()
        createBtn:SetPoint("LEFT", applyBtn, "RIGHT", 28, 0)
        editBtn:ClearAllPoints()
        editBtn:SetPoint("LEFT", createBtn, "RIGHT", 28, 0)
        deleteBtn:ClearAllPoints()
        deleteBtn:SetPoint("LEFT", editBtn, "RIGHT", 28, 0)
        copyBtn:ClearAllPoints()
        copyBtn:SetPoint("LEFT", deleteBtn, "RIGHT", 28, 0)
        parent._contentH = sectionH + delta
        parent:SetHeight(parent._contentH)
    end

    function state:UpdateHeaderSort()
        for i = 1, #columns do
            local key = columns[i].key
            local arrow = headerArrows[key]
            if NS.db.talentBuildUseDefaultSort then
                arrow:SetText("")
                arrow:SetAlpha(0.35)
            elseif (NS.db.talentBuildSortColumn or "name") == key then
                arrow:SetText((NS.db.talentBuildSortAscending ~= false) and "UP" or "DN")
                arrow:SetTextColor(sectionColor[1], sectionColor[2], sectionColor[3], 0.9)
                arrow:SetAlpha(1)
            else
                arrow:SetText("")
                arrow:SetAlpha(0.35)
            end
        end
        sortReset:SetActive(NS.db.talentBuildUseDefaultSort ~= true)
    end

    function state:CreateRow(index)
        local row = NS.CreateFrame("Button", nil, listChild)
        row:SetSize(tableW - 12, rowH)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0)

        local topLine = row:CreateTexture(nil, "ARTWORK")
        topLine:SetHeight(1)
        topLine:SetColorTexture(T.BORDER[1], T.BORDER[2], T.BORDER[3], 0.45)
        topLine:SetPoint("TOPLEFT", 0, 0)
        topLine:SetPoint("TOPRIGHT", 0, 0)

        local dot = row:CreateTexture(nil, "OVERLAY")
        dot:SetSize(10, 10)

        local labels = {}
        local x = 0
        for i = 1, #columns do
            local col = columns[i]
            local fs = row:CreateFontString(nil, "OVERLAY")
            fs:SetFont(NS.GetConfigFontPath(), ROW_FONT_SIZE, "OUTLINE")
            if col.justify == "CENTER" then
                fs:SetPoint("TOPLEFT", x, 0)
                fs:SetSize(col.width, rowH)
                fs:SetJustifyH("CENTER")
            else
                fs:SetPoint("TOPLEFT", x + ((i == 1) and 24 or 14), 0)
                fs:SetSize(col.width - ((i == 1) and 30 or 18), rowH)
                fs:SetJustifyH("LEFT")
            end
            fs:SetJustifyV("MIDDLE")
            labels[col.key] = fs
            x = x + col.width
        end

        dot:SetPoint("LEFT", labels.name, "LEFT", -14, 0)

        row._bg = bg
        row._dot = dot
        row._labels = labels
        row._line = topLine
        row._data = nil

        row:SetScript("OnEnter", function(self)
            if self._isSelected then return end
            self._bg:SetColorTexture(T.BG_HOVER[1], T.BG_HOVER[2], T.BG_HOVER[3], 0.32)
        end)
        row:SetScript("OnLeave", function(self)
            if self._isSelected then return end
            self._bg:SetColorTexture(0, 0, 0, 0)
        end)

        self.rowButtons[index] = row
        return row
    end

    function state:UpdateRow(row, data, index)
        local activeSpecID = NS.GetTalentBuildCurrentSpecID()
        row._data = data
        row._isSelected = (self.selectedID == data.id and self.selectedSpecID == data.specID)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -((index - 1) * rowH))

        local isOffSpec = data.specID ~= activeSpecID
        local alpha = isOffSpec and 0.45 or 1
        local dotColor = GetBuildSourceColor(data, sectionColor)
        row._dot:SetVertexColor(dotColor[1], dotColor[2], dotColor[3], alpha)

        local nameColor = row._isSelected and BrightenColor(sectionColor, 0.15, 1) or (isOffSpec and MultiplyColor(T.TEXT, 0.62, 1) or T.TEXT)
        local subColor = isOffSpec and MultiplyColor(T.TEXT_DIM, 0.72, 1) or T.TEXT_DIM
        local specColor = GetSpecTextColor(data.specID, subColor, isOffSpec, row._isSelected)

        row._labels.name:SetText(data.name or "")
        row._labels.name:SetTextColor(nameColor[1], nameColor[2], nameColor[3], alpha)
        row._labels.spec:SetText(data.specName or NS.GetTalentBuildSpecName(data.specID) or "")
        row._labels.spec:SetTextColor(specColor[1], specColor[2], specColor[3], alpha)
        row._labels.author:SetText((data.author and data.author ~= "") and data.author or "-")
        row._labels.author:SetTextColor(subColor[1], subColor[2], subColor[3], alpha)
        row._labels.rating:SetText((data.rating and data.rating ~= "") and data.rating or "-")
        row._labels.rating:SetTextColor(subColor[1], subColor[2], subColor[3], alpha)
        row._labels.source:SetText((data.source and data.source ~= "") and data.source or "-")
        row._labels.source:SetTextColor(subColor[1], subColor[2], subColor[3], alpha)
        row._labels.type:SetText((data.buildType and data.buildType ~= "") and data.buildType or "-")
        row._labels.type:SetTextColor(subColor[1], subColor[2], subColor[3], alpha)

        if row._isSelected then
            row._bg:SetColorTexture(sectionColor[1], sectionColor[2], sectionColor[3], isOffSpec and 0.16 or 0.22)
        else
            row._bg:SetColorTexture(0, 0, 0, 0)
        end

        row:SetScript("OnClick", function()
            self.selectedID = data.id
            self.selectedSpecID = data.specID
            NS.RequestTalentBuildApply(data.id, {
                specID = data.specID,
                reason = "config-row",
                loadAnyway = false,
            })
            self:Refresh()
        end)

        row:Show()
    end

    function state:UpdateRows()
        local count = #self.filteredRows
        for i = 1, count do
            local row = self.rowButtons[i] or self:CreateRow(i)
            self:UpdateRow(row, self.filteredRows[i], i)
        end
        for i = count + 1, #self.rowButtons do
            self.rowButtons[i]:Hide()
        end
        local childH = math.max(1, count * rowH)
        listChild:SetHeight(childH)
        UpdateListScrollbar()
    end

    function state:UpdateDetails()
        local row = self.selectedRow
        if not row then
            detailsName:SetText("No build selected")
            fieldValues.spec:SetText("-")
            fieldValues.spec:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3], 1)
            fieldValues.author:SetText("-")
            fieldValues.source:SetText("-")
            fieldValues.rating:SetText("-")
            fieldValues.type:SetText("-")
            fieldValues.status:SetText("-")
            behaviorText:SetText("Select a build to view details.")
            sourceBtn:SetEnabledState(false)
            sourceBtn:Hide()
            loadAnywayBtn:Hide()
            return
        end

        local status = NS.GetTalentBuildLastStatus(row.specID)
        local statusText = "-"
        local statusKind = nil
        if status and status.buildID == row.id then
            statusText = status.text or "-"
            statusKind = status.kind
        elseif row.id == NS.GetSelectedTalentBuildID(row.specID) then
            statusText = row.id == NS.TALENT_BUILD_CUSTOM_ID and "Using Custom talents" or "Selected for this specialization"
            statusKind = row.id == NS.TALENT_BUILD_CUSTOM_ID and "custom" or "selected"
        end

        detailsName:SetText(row.name or "Custom")
        fieldValues.spec:SetText(row.specName or NS.GetTalentBuildSpecName(row.specID) or "-")
        local detailSpecColor = GetSpecTextColor(row.specID, T.TEXT, false, false)
        fieldValues.spec:SetTextColor(detailSpecColor[1], detailSpecColor[2], detailSpecColor[3], 1)
        fieldValues.author:SetText((row.author and row.author ~= "") and row.author or "-")
        fieldValues.source:SetText((row.source and row.source ~= "") and row.source or "-")
        fieldValues.rating:SetText((row.rating and row.rating ~= "") and row.rating or "-")
        fieldValues.type:SetText((row.buildType and row.buildType ~= "") and row.buildType or "-")
        fieldValues.status:SetText(statusText)
        local statusColor = GetStatusColor(statusKind, sectionColor)
        fieldValues.status:SetTextColor(statusColor[1], statusColor[2], statusColor[3])

        local activeSpecID = NS.GetTalentBuildCurrentSpecID()
        if row.specID == activeSpecID then
            behaviorText:SetText("Single click applies active-spec rows.")
            loadAnywayBtn:Hide()
        else
            behaviorText:SetText("This build belongs to another specialization. LOAD ANYWAY will switch specs and apply it.")
            loadAnywayBtn:Show()
            loadAnywayBtn:SetEnabledState(true)
        end

        if row.sourceURL and row.sourceURL ~= "" then
            sourceBtn:Show()
            sourceBtn:SetEnabledState(true)
        else
            sourceBtn:Hide()
            sourceBtn:SetEnabledState(false)
        end
    end

    function state:RefreshSubtitle()
        local className = select(1, UnitClass("player")) or (NS.GetTalentBuildClassToken() or "")
        local activeSpecName = NS.GetTalentBuildSpecName(NS.GetTalentBuildCurrentSpecID()) or "Unknown"
        subtitle:SetText(("%s builds using live catalog data. Active specialization: %s."):format(className, activeSpecName))
    end

    function state:Refresh()
        self.rows = self:CollectRows()
        self:UpdateFilterButtons()
        self.filteredRows = self:FilterRows(self:GetSortedRows(CopyTable(self.rows)))
        self.selectedRow = self:EnsureSelectedRow()
        self:UpdateHeaderSort()
        self:UpdateRows()
        self:UpdateDetails()
        self:RefreshSubtitle()

        applyBtn:SetEnabledState(self.selectedRow ~= nil)
        deleteBtn:SetEnabledState(self.selectedRow and self.selectedRow.buildType == NS.TALENT_BUILD_TYPE_USER)
        editBtn:SetEnabledState(self.selectedRow and self.selectedRow.buildType == NS.TALENT_BUILD_TYPE_USER)
        createBtn:SetEnabledState(true)
        copyBtn:SetEnabledState(self.selectedRow and self.selectedRow.id ~= NS.TALENT_BUILD_CUSTOM_ID)

        if self.selectedRow and self.selectedRow.specID ~= NS.GetTalentBuildCurrentSpecID() then
            loadAnywayBtn:Show()
            loadAnywayBtn:SetEnabledState(true)
        else
            loadAnywayBtn:Hide()
        end
    end

    searchBox:SetScript("OnTextChanged", function(self, userInput)
        local text = self:GetText() or ""
        searchPlaceholder:SetShown(text == "")
        if not userInput then
            return
        end
        NS.db.talentBuildSearchText = text
        state:Refresh()
    end)

    typeButtons.all:SetCallback(function()
        NS.db.talentBuildSourceFilter = NS.TALENT_BUILD_FILTER_ALL
        state:SetTypeFilter("all")
    end)
    typeButtons.builtIn:SetCallback(function()
        state:SetTypeFilter("builtIn")
    end)
    typeButtons.user:SetCallback(function()
        state:SetTypeFilter("user")
    end)

    for i = 1, #sourceButtons do
        sourceButtons[i]:SetCallback(function(self)
            if self._source then
                state:SetSourceFilter(self._source)
            end
        end)
    end

    sortReset:SetCallback(function()
        state:UseDefaultSort()
    end)

    for i = 1, #headerButtons do
        headerButtons[i]:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" then
                state:SetSort(self._columnKey)
            end
        end)
    end

    applyBtn:SetCallback(function()
        if not state.selectedRow then
            return
        end
        NS.RequestTalentBuildApply(state.selectedRow.id, {
            specID = state.selectedRow.specID,
            reason = "config-apply",
            loadAnyway = false,
        })
        state:Refresh()
    end)

    loadAnywayBtn:SetCallback(function()
        if not state.selectedRow then
            return
        end
        NS.RequestTalentBuildApply(state.selectedRow.id, {
            specID = state.selectedRow.specID,
            reason = "config-load-anyway",
            loadAnyway = true,
        })
        state:Refresh()
    end)

    sourceBtn:SetCallback(function()
        if state.selectedRow then
            ShowURLPopup(parent, state.selectedRow)
        end
    end)

    deleteBtn:SetCallback(function()
        if not state.selectedRow or state.selectedRow.buildType ~= NS.TALENT_BUILD_TYPE_USER then
            return
        end
        ShowDeletePopup(parent, state.selectedRow, function()
            NS.DeleteUserTalentBuild(state.selectedRow.id)
            state.selectedID = NS.TALENT_BUILD_CUSTOM_ID
            state.selectedSpecID = NS.GetTalentBuildCurrentSpecID()
            state:Refresh()
        end)
    end)

    createBtn:SetCallback(function()
        ShowTalentBuildEditor(parent, state, "create", nil)
    end)
    editBtn:SetCallback(function()
        if not state.selectedRow or state.selectedRow.buildType ~= NS.TALENT_BUILD_TYPE_USER then
            return
        end
        ShowTalentBuildEditor(parent, state, "edit", state.selectedRow)
    end)
    copyBtn:SetCallback(function()
        if not state.selectedRow or state.selectedRow.id == NS.TALENT_BUILD_CUSTOM_ID then
            return
        end
        ShowTalentBuildEditor(parent, state, "copy", state.selectedRow)
    end)

    parent._refresh = function()
        state:Refresh()
    end

    state:Refresh()
    if not parent._contentH then
        parent._contentH = sectionH
        parent:SetHeight(sectionH)
    end

    return state
end
