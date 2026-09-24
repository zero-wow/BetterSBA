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
    popup:SetSize(560, 300)
    popup:SetClampedToScreen(true)
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(100)
    popup:SetBackdropColor(T.BG_DARK[1], T.BG_DARK[2], T.BG_DARK[3], 0.98)
    popup:SetBackdropBorderColor(T.BORDER_ACCENT[1], T.BORDER_ACCENT[2], T.BORDER_ACCENT[3], 0.8)
    popup:Hide()

    local title = popup:CreateFontString(nil, "OVERLAY")
    title:SetFont(NS.GetConfigFontPath(), 10, "OUTLINE")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetPoint("RIGHT", popup, "RIGHT", -12, 0)
    title:SetHeight(14)
    title:SetWordWrap(false)
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

    local sourceScroll = NS.CreateFrame("ScrollFrame", nil, popup)
    sourceScroll:SetPoint("TOPLEFT", 14, -96)
    sourceScroll:SetSize(532, 164)
    sourceScroll:EnableMouseWheel(true)
    local sourceContent = NS.CreateFrame("Frame", nil, sourceScroll)
    sourceContent:SetSize(532, 164)
    sourceScroll:SetScrollChild(sourceContent)
    local provenance = sourceContent:CreateFontString(nil, "OVERLAY")
    provenance:SetFont(NS.GetConfigFontPath(), VALUE_FONT_SIZE, "")
    provenance:SetPoint("TOPLEFT", 0, 0)
    provenance:SetWidth(532)
    provenance:SetJustifyH("LEFT")
    provenance:SetJustifyV("TOP")
    provenance:SetWordWrap(true)
    provenance:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])
    sourceScroll:SetScript("OnMouseWheel", function(self, delta)
        local maximum = math.max(0, sourceContent:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(maximum, self:GetVerticalScroll() - delta * 24)))
    end)

    local close = CreateTextButton(popup, "CLOSE", 54, function()
        popup:Hide()
    end)
    close:SetPoint("BOTTOMRIGHT", -12, 10)

    popup._title = title
    popup._editBox = editBox
    popup._hint = hint
    popup._provenance = provenance
    popup._sourceScroll, popup._sourceContent = sourceScroll, sourceContent
    owner._talentBuildURLPopup = popup
    return popup
end

local function ShowURLPopup(owner, row)
    if not row then return end
    local popup = EnsureURLPopup(owner)
    local hasSourceURL = row.sourceURL and row.sourceURL ~= ""
    local evidence = row.verificationStatus == "source-sba" and "Source supplies an assist-specific build"
        or (row.verificationStatus == "source-talent" and "Source supplies this WoW talent export; SBA suitability is unverified")
        or (row.verificationStatus == "source-compatible" and "Source recommends this build for SBA")
        or (row.verificationStatus == "guide-adapted" and "Guide-adapted: source-informed targeted choice")
        or (row.verificationStatus == "guide-inferred" and "Guide discusses SBA for this spec; exact import is unverified")
        or (row.verificationStatus == "user-provided" and "User-provided import: SBA suitability is not independently verified")
        or (row.verificationStatus == "legacy-unverified" and "Legacy entry: SBA suitability unverified")
        or "SBA suitability unverified"
    local priorityNote = row.verificationStatus == "user-provided"
        and "User-provided imports are selectable but have no independent SBA verification. Legal prerequisites always apply."
        or "Guide-informed priorities only influence matched talents in this selected target. Legal prerequisites always apply; this is not an optimality claim."
    popup._provenance:SetText(evidence .. "\nPatch: " .. ((row.patch and row.patch ~= "") and row.patch or "unverified")
        .. "   Checked: " .. (row.checkedAt or "not recorded")
        .. "\nHero tree: " .. (row.heroTree or "not recorded")
        .. "\n\n" .. (row.notes or "")
        .. "\n\n" .. priorityNote)
    popup._sourceContent:SetHeight(math.max(164, popup._provenance:GetStringHeight() + 6))
    popup._sourceScroll:SetVerticalScroll(0)
    popup._title:SetText((row.name or "Build") .. (hasSourceURL and " - Source Page" or " - Build Notes"))
    popup._editBox:SetText(hasSourceURL and row.sourceURL or "No source URL supplied")
    popup._hint:SetText(hasSourceURL and "Ctrl+C copies the page URL for manual review."
        or "This build has no source URL; review its provenance and compatibility notes below.")
    popup._editBox:SetCursorPosition(0)
    popup:ClearAllPoints()
    popup:SetPoint("CENTER", owner, "CENTER", 0, 0)
    popup:Show()
    if hasSourceURL then
        popup._editBox:SetFocus()
        popup._editBox:HighlightText()
    else
        popup._editBox:ClearFocus()
    end
end

local sbaWarningPopup
local sbaWarningDismissedSignature

local function SBAWarningSignature(assessment)
    if assessment and assessment.signature and assessment.signature ~= "" then
        return assessment.signature
    end
    if not assessment then return nil end
    return table.concat({
        tostring(assessment.specID or "?"),
        tostring(assessment.buildID or "?"),
        tostring(assessment.targetName or "?"),
        tostring(assessment.message or "?"),
    }, "\31")
end

local function EnsureSBAWarningPopup()
    if sbaWarningPopup then return sbaWarningPopup end

    local popup = CreateBackdropFrame(NS.UIParent)
    popup:SetSize(500, 284)
    popup:SetClampedToScreen(true)
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(120)
    popup:SetBackdropColor(T.BG_DARK[1], T.BG_DARK[2], T.BG_DARK[3], 0.98)
    popup:SetBackdropBorderColor(T.DANGER[1], T.DANGER[2], T.DANGER[3], 0.8)
    popup:Hide()

    local title = popup:CreateFontString(nil, "OVERLAY")
    title:SetFont(NS.GetConfigFontPath(), VALUE_FONT_SIZE, "OUTLINE")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetPoint("RIGHT", -14, 0)
    title:SetJustifyH("LEFT")
    title:SetTextColor(T.DANGER[1], T.DANGER[2], T.DANGER[3])
    title:SetText("SBA TALENT MISMATCH")

    local target = popup:CreateFontString(nil, "OVERLAY")
    target:SetFont(NS.GetConfigFontPath(), LABEL_FONT_SIZE, "OUTLINE")
    target:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    target:SetPoint("RIGHT", -14, 0)
    target:SetHeight(14)
    target:SetWordWrap(false)
    target:SetJustifyH("LEFT")
    target:SetTextColor(T.TEXT_DIM[1], T.TEXT_DIM[2], T.TEXT_DIM[3])

    local bodyScroll = NS.CreateFrame("ScrollFrame", nil, popup)
    bodyScroll:SetPoint("TOPLEFT", target, "BOTTOMLEFT", 0, -8)
    bodyScroll:SetSize(472, 160)
    bodyScroll:EnableMouseWheel(true)
    local bodyContent = NS.CreateFrame("Frame", nil, bodyScroll)
    bodyContent:SetSize(472, 160)
    bodyScroll:SetScrollChild(bodyContent)
    local body = bodyContent:CreateFontString(nil, "OVERLAY")
    body:SetFont(NS.GetConfigFontPath(), VALUE_FONT_SIZE, "")
    body:SetPoint("TOPLEFT", 0, 0)
    body:SetWidth(472)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetWordWrap(true)
    body:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])
    bodyScroll:SetScript("OnMouseWheel", function(self, delta)
        local maximum = math.max(0, bodyContent:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(maximum, self:GetVerticalScroll() - delta * 24)))
    end)

    local dismiss = CreateTextButton(popup, "DISMISS", 58, function() end)
    dismiss:SetPoint("BOTTOMRIGHT", -14, 12)
    local respec = CreateTextButton(popup, "RESPEC TO SBA", 104, function() end)
    respec:SetPoint("RIGHT", dismiss, "LEFT", -24, 0)

    popup._title, popup._target, popup._body = title, target, body
    popup._bodyScroll, popup._bodyContent = bodyScroll, bodyContent
    popup._dismiss, popup._respec = dismiss, respec
    dismiss:SetCallback(function()
        sbaWarningDismissedSignature = popup._signature
        popup:Hide()
    end)
    respec:SetCallback(function()
        local ok, message = NS.RequestTalentSBARespec()
        if ok then
            popup._body:SetText(message or "Respec requested. Waiting for Blizzard to apply the selected SBA target.")
            popup._respec:SetEnabledState(false)
        else
            popup._body:SetText(message or "Unable to respec to the SBA target. Recheck the current talent tree and try again.")
            popup._body:SetTextColor(T.DANGER[1], T.DANGER[2], T.DANGER[3])
        end
        popup._bodyContent:SetHeight(math.max(160, popup._body:GetStringHeight() + 6))
        popup._bodyScroll:SetVerticalScroll(0)
        if NS.RefreshTalentBuildPanels then NS.RefreshTalentBuildPanels() end
    end)

    sbaWarningPopup = popup
    return popup
end

-- The backend calls this after a settled assessment.  It may run before the
-- config panel exists, so the alert owns no panel state and is created lazily.
function NS.CheckTalentSBAWarning(assessment)
    if not assessment or assessment.warningEnabled ~= true then
        if sbaWarningPopup then sbaWarningPopup:Hide() end
        sbaWarningDismissedSignature = nil
        return
    end
    if assessment.settled == false and not assessment.failure then
        if sbaWarningPopup then sbaWarningPopup:Hide() end
        return
    end
    if assessment.hasMismatch ~= true and not assessment.failure then
        if sbaWarningPopup then sbaWarningPopup:Hide() end
        sbaWarningDismissedSignature = nil
        return
    end
    local signature = SBAWarningSignature(assessment)
    if assessment.failure then signature = signature .. ":failure:" .. assessment.failure end
    if signature and signature == sbaWarningDismissedSignature then return end

    local popup = EnsureSBAWarningPopup()
    popup._signature = signature
    popup._title:SetText(assessment.failure and "SBA TALENT CHANGE FAILED" or "SBA TALENT MISMATCH")
    popup._target:SetText("Target: " .. (assessment.targetName or "Selected SBA build"))
    popup._body:SetText((assessment.failure or assessment.message or "Your learned talents do not match the selected SBA target.")
        .. (assessment.mismatchDetails and ("\n\nDifferences from this target:\n" .. assessment.mismatchDetails) or "")
        .. "\n\n" .. (assessment.detail or "")
        .. "\n\nRESPEC TO SBA resets your class, specialization, and hero talent points, then applies the selected target at your current level. This only happens after you press the button.")
    popup._bodyContent:SetHeight(math.max(160, popup._body:GetStringHeight() + 6))
    popup._bodyScroll:SetVerticalScroll(0)
    popup._body:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])
    popup._respec:SetEnabledState(assessment.settled ~= false and assessment.canRespec == true)
    popup:ClearAllPoints()
    popup:SetPoint("CENTER", NS.UIParent, "CENTER", 0, 0)
    popup:Show()
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
    if source == "LazyGrip" then
        return { 0.50, 0.78, 0.72, 1 }
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

local function ShortenText(value, limit)
    value = TrimText(value):gsub("[\r\n]+", " ")
    if #value <= limit then
        return value
    end
    return value:sub(1, math.max(1, limit - 3)) .. "..."
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
    -- At the minimum configuration width, a side detail card leaves the build
    -- table too narrow to read.  Stack it below the table there; wide panels
    -- retain the side-by-side catalog.
    local compactCatalog = innerW < 760
    local detailsW = compactCatalog and innerW or 200
    local gutter = 12
    local tableW = compactCatalog and innerW or (innerW - detailsW - gutter)
    local tableH = compactCatalog and 260 or 330
    local detailsH = 330
    -- Keep the assist concise.  Catalog controls use their own rows and the
    -- table start is moved only by actual wrapped source-chip rows.
    local headerY = -162
    local tableBaseY = -370
    local sourceTopY = -332
    local sectionH = compactCatalog and 1080 or 800
    local rowH = 24
    local searchW = innerW
    local chipStartX = 14

    parent._sectionColor = sectionColor
    parent._sectionColorBright = sectionBright
    parent._sectionColorDim = sectionDim

    CreateSubHeader(parent, "LEVELING ASSIST", -8)
    CreateSubHeader(parent, "BUILD CATALOG", headerY)
    local selectedHdr = nil

    local levelingPanel = CreateBackdropFrame(parent)
    levelingPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -30)
    levelingPanel:SetSize(innerW, 116)
    levelingPanel:SetBackdropColor(T.BG[1], T.BG[2], T.BG[3], 0.92)
    levelingPanel:SetBackdropBorderColor(sectionColor[1], sectionColor[2], sectionColor[3], 0.55)

    local levelingTitle = levelingPanel:CreateFontString(nil, "OVERLAY")
    levelingTitle:SetFont(NS.GetConfigFontPath(), VALUE_FONT_SIZE, "OUTLINE")
    levelingTitle:SetPoint("TOPLEFT", 12, -8)
    levelingTitle:SetTextColor(sectionBright[1], sectionBright[2], sectionBright[3])
    levelingTitle:SetText("LEVELING TARGET")

    local levelingSpec = levelingPanel:CreateFontString(nil, "OVERLAY")
    levelingSpec:SetFont(NS.GetConfigFontPath(), LABEL_FONT_SIZE, "")
    levelingSpec:SetPoint("TOPLEFT", levelingTitle, "BOTTOMLEFT", 0, -4)
    levelingSpec:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])

    local levelingTarget = levelingPanel:CreateFontString(nil, "OVERLAY")
    levelingTarget:SetFont(NS.GetConfigFontPath(), VALUE_FONT_SIZE, "OUTLINE")
    levelingTarget:SetPoint("TOPLEFT", levelingSpec, "BOTTOMLEFT", 0, -3)
    levelingTarget:SetPoint("RIGHT", levelingPanel, "TOPRIGHT", -262, 0)
    levelingTarget:SetHeight(14)
    levelingTarget:SetWordWrap(false)
    levelingTarget:SetJustifyH("LEFT")
    levelingTarget:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])

    local levelingNext = levelingPanel:CreateFontString(nil, "OVERLAY")
    levelingNext:SetFont(NS.GetConfigFontPath(), VALUE_FONT_SIZE, "")
    levelingNext:SetPoint("TOPLEFT", levelingTarget, "BOTTOMLEFT", 0, -2)
    levelingNext:SetPoint("RIGHT", levelingPanel, "TOPRIGHT", -262, 0)
    levelingNext:SetHeight(14)
    levelingNext:SetWordWrap(false)
    levelingNext:SetJustifyH("LEFT")
    levelingNext:SetTextColor(T.TEXT_DIM[1], T.TEXT_DIM[2], T.TEXT_DIM[3])

    local levelingStatus = levelingPanel:CreateFontString(nil, "OVERLAY")
    levelingStatus:SetFont(NS.GetConfigFontPath(), LABEL_FONT_SIZE, "")
    levelingStatus:SetPoint("TOPLEFT", levelingNext, "BOTTOMLEFT", 0, -4)
    levelingStatus:SetPoint("RIGHT", levelingPanel, "TOPRIGHT", -262, 0)
    levelingStatus:SetHeight(32)
    levelingStatus:SetJustifyH("LEFT")
    levelingStatus:SetJustifyV("TOP")
    levelingStatus:SetWordWrap(true)
    levelingStatus:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
    local levelingTooltip = {}
    NS.AddTooltip(levelingPanel, "Leveling assistant details", levelingTooltip, parent)

    local useForLevelingBtn = CreateTextButton(levelingPanel, "USE FOR LEVELING", 112, function() end)
    useForLevelingBtn:SetPoint("TOPRIGHT", levelingPanel, "TOPRIGHT", -138, -10)
    local autoSpendBtn = CreateTextButton(levelingPanel, "AUTO-SPEND: OFF", 112, function() end)
    autoSpendBtn:SetPoint("TOPRIGHT", levelingPanel, "TOPRIGHT", -14, -10)
    local spendNextBtn = CreateTextButton(levelingPanel, "SPEND NEXT", 84, function() end)
    spendNextBtn:SetPoint("TOPRIGHT", levelingPanel, "TOPRIGHT", -138, -34)
    local sbaWarningBtn = CreateTextButton(levelingPanel, "SBA ALERT: OFF", 112, function() end)
    sbaWarningBtn:SetPoint("TOPRIGHT", levelingPanel, "TOPRIGHT", -14, -34)
    local respecSBABtn = CreateTextButton(levelingPanel, "RESPEC TO SBA", 104, function() end)
    respecSBABtn:SetPoint("TOPRIGHT", levelingPanel, "TOPRIGHT", -138, -58)
    local undoRespecBtn = CreateTextButton(levelingPanel, "UNDO RESPEC", 104, function() end)
    undoRespecBtn:SetPoint("TOPRIGHT", levelingPanel, "TOPRIGHT", -14, -58)

    local levelingHint = levelingPanel:CreateFontString(nil, "OVERLAY")
    levelingHint:SetFont(NS.GetConfigFontPath(), LABEL_FONT_SIZE, "")
    levelingHint:SetPoint("TOPRIGHT", undoRespecBtn, "BOTTOMRIGHT", 0, -3)
    levelingHint:SetSize(236, 12)
    levelingHint:SetJustifyH("RIGHT")
    levelingHint:SetJustifyV("TOP")
    levelingHint:SetWordWrap(true)
    levelingHint:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
    levelingHint:SetText("When enabled, points spend without a per-point approval.")

    local title = parent:CreateFontString(nil, "OVERLAY")
    title:SetFont(NS.GetConfigFontPath(), TITLE_FONT_SIZE, "OUTLINE")
    title:SetPoint("TOPLEFT", 14, -184)
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
    searchLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -248)
    local searchLabelText = searchLabel:CreateFontString(nil, "OVERLAY")
    searchLabelText:SetFont(NS.GetConfigFontPath(), LABEL_FONT_SIZE, "OUTLINE")
    searchLabelText:SetPoint("BOTTOMLEFT", searchLabel, "TOPLEFT", 0, 2)
    searchLabelText:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
    searchLabelText:SetText("Search Builds")

    local searchBox = NS.CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    searchBox:SetSize(searchW, 24)
    searchBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -264)
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

    local allChip = CreateChipButton(parent, "ALL", 44, function() end)
    allChip:SetPoint("TOPLEFT", parent, "TOPLEFT", chipStartX, -298)
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
    tablePanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, tableBaseY)
    tablePanel:SetSize(tableW, tableH)
    tablePanel:SetBackdropColor(T.BG[1], T.BG[2], T.BG[3], 0.92)
    tablePanel:SetBackdropBorderColor(T.BORDER[1], T.BORDER[2], T.BORDER[3], 0.85)

    local detailsPanel = CreateBackdropFrame(parent)
    if compactCatalog then
        detailsPanel:SetPoint("TOPLEFT", tablePanel, "BOTTOMLEFT", 0, -12)
    else
        detailsPanel:SetPoint("TOPLEFT", tablePanel, "TOPRIGHT", gutter, 0)
    end
    detailsPanel:SetSize(detailsW, detailsH)
    detailsPanel:SetBackdropColor(T.BG[1], T.BG[2], T.BG[3], 0.92)
    detailsPanel:SetBackdropBorderColor(T.BORDER[1], T.BORDER[2], T.BORDER[3], 0.85)
    detailsPanel:EnableMouse(true)
    local detailTooltip = {}
    NS.AddTooltip(detailsPanel, "Build details", detailTooltip, parent)

    local detailsTitle = detailsPanel:CreateFontString(nil, "OVERLAY")
    detailsTitle:SetFont(NS.GetConfigFontPath(), 8, "OUTLINE")
    detailsTitle:SetPoint("TOPLEFT", 14, -12)
    detailsTitle:SetTextColor(sectionColor[1], sectionColor[2], sectionColor[3])
    detailsTitle:SetText("SELECTED BUILD")

    local detailsName = detailsPanel:CreateFontString(nil, "OVERLAY")
    detailsName:SetFont(NS.GetConfigFontPath(), 10, "OUTLINE")
    detailsName:SetPoint("TOPLEFT", detailsTitle, "BOTTOMLEFT", 0, -12)
    detailsName:SetPoint("RIGHT", -14, 0)
    detailsName:SetHeight(32)
    detailsName:SetWordWrap(true)
    detailsName:SetMaxLines(2)
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
        value:SetHeight(14)
        value:SetWordWrap(false)
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
    behaviorText:SetHeight(70)
    behaviorText:SetWordWrap(true)
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
    state.sourceButtons = sourceButtons
    state.typeButtons = typeButtons
    state.tablePanel = tablePanel
    state.detailsPanel = detailsPanel
    state.searchBox = searchBox
    state.compactCatalog = compactCatalog
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
    state.levelingSpec = levelingSpec
    state.levelingTarget = levelingTarget
    state.levelingNext = levelingNext
    state.levelingStatus = levelingStatus
    state.levelingTooltip = levelingTooltip
    state.levelingHint = levelingHint
    state.useForLevelingBtn = useForLevelingBtn
    state.autoSpendBtn = autoSpendBtn
    state.spendNextBtn = spendNextBtn
    state.sbaWarningBtn = sbaWarningBtn
    state.respecSBABtn = respecSBABtn
    state.undoRespecBtn = undoRespecBtn

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
    if compactCatalog then
        actionsRule:SetPoint("TOPLEFT", sourceBtn, "BOTTOMLEFT", -4, -10)
        actionsRule:SetPoint("RIGHT", parent, "RIGHT", -14, 0)
    else
        actionsRule:SetPoint("TOPLEFT", tablePanel, "BOTTOMLEFT", 0, -8)
        actionsRule:SetPoint("RIGHT", detailsPanel, "LEFT", -12, 0)
    end
    state.actionsRule = actionsRule

    local applyBtn = CreateTextButton(parent, "APPLY BUILD", 82, function() end)
    applyBtn:SetPoint("TOPLEFT", actionsRule, "BOTTOMLEFT", 0, -10)
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
    footerNote:SetPoint("TOPLEFT", applyBtn, "BOTTOMLEFT", 0, -8)
    footerNote:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3], 0.85)
    footerNote:SetText("Click a row to inspect it. APPLY BUILD imports the selected full build. LOAD ANYWAY remains for an off-spec selection.")

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
            btn:SetPoint("TOPLEFT", parent, "TOPLEFT", cursorX, sourceTopY - (rowIndex - 1) * 30)
            btn:SetActive((NS.db.talentBuildSourceFilter or NS.TALENT_BUILD_FILTER_ALL) == source)
            btn:Show()
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
        defaultSortLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", cursorX, sourceTopY - (rowIndex - 1) * 30)
        sortReset:ClearAllPoints()
        sortReset:SetPoint("LEFT", defaultSortLabel, "RIGHT", 8, 0)
        local delta = (rowIndex - 1) * 30
        tablePanel:ClearAllPoints()
        tablePanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, tableBaseY - delta)
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
        for i = #detailTooltip, 1, -1 do detailTooltip[i] = nil end
        if not row then
            detailsName:SetText("No build selected")
            fieldValues.spec:SetText("-")
            fieldValues.spec:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3], 1)
            fieldValues.author:SetText("-")
            fieldValues.source:SetText("-")
            fieldValues.rating:SetText("-")
            fieldValues.type:SetText("-")
            fieldValues.status:SetText("-")
            behaviorText:SetText("Select a build to inspect it.")
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
        detailTooltip[1] = row.name or "Custom"
        detailTooltip[2] = "Patch: " .. ((row.patch and row.patch ~= "") and row.patch or "unverified")
        detailTooltip[3] = "Hero tree: " .. (row.heroTree or "not recorded")
        detailTooltip[4] = "Status: " .. statusText
        detailTooltip[5] = row.notes or ""

        local activeSpecID = NS.GetTalentBuildCurrentSpecID()
        if row.specID == activeSpecID then
            local patchNote = ""
            if row.id ~= NS.TALENT_BUILD_CUSTOM_ID and (not row.patch or row.patch == "") then
                patchNote = " Patch: unverified (catalog entry has no patch value)."
            end
            local provenanceNote = row.verificationStatus == "user-provided"
                and " Provenance: user-provided import; SBA suitability is not independently verified."
                or ""
            behaviorText:SetText("Click to inspect. APPLY BUILD imports this full active-spec build." .. patchNote .. provenanceNote)
            loadAnywayBtn:Hide()
        else
            behaviorText:SetText("OFF-SPEC BUILD. Click to inspect. LOAD ANYWAY switches to this specialization and imports it; it cannot be used for current-spec leveling.")
            loadAnywayBtn:Show()
            loadAnywayBtn:SetEnabledState(true)
        end

        if row.id ~= NS.TALENT_BUILD_CUSTOM_ID and (row.sourceURL and row.sourceURL ~= "" or row.notes and row.notes ~= "") then
            sourceBtn:Show()
            sourceBtn:SetEnabledState(true)
            sourceBtn._text:SetText(row.sourceURL and row.sourceURL ~= "" and "VIEW SOURCE" or "BUILD NOTES")
        else
            sourceBtn:Hide()
            sourceBtn:SetEnabledState(false)
        end
    end

    function state:RefreshSubtitle()
        local className = select(1, UnitClass("player")) or (NS.GetTalentBuildClassToken() or "")
        local activeSpecName = NS.GetTalentBuildSpecName(NS.GetTalentBuildCurrentSpecID()) or "Unknown"
        subtitle:SetText(("%s builds from the bundled catalog. Active specialization: %s."):format(className, activeSpecName))
    end

    function state:UpdateLevelingAssist()
        local activeSpecID = NS.GetTalentBuildCurrentSpecID()
        local info = NS.GetTalentLevelingInfo and NS.GetTalentLevelingInfo() or nil
        local targetState = NS.GetTalentLevelingState and NS.GetTalentLevelingState(activeSpecID) or nil
        local assessment = NS.GetTalentSBAAssessment and NS.GetTalentSBAAssessment() or nil
        info = info or targetState or {}

        local targetID = info.buildID or (targetState and targetState.buildID) or NS.TALENT_BUILD_CUSTOM_ID
        local enabled = info.enabled == true or (targetState and targetState.enabled == true)
        local specName = info.specName or NS.GetTalentBuildSpecName(activeSpecID) or "Unknown"
        local targetName = info.targetName
        if not targetName or targetName == "" then
            targetName = targetID == NS.TALENT_BUILD_CUSTOM_ID and "No leveling target selected" or tostring(targetID)
        end
        local nextName = info.nextName
        local status = info.status or (targetID == NS.TALENT_BUILD_CUSTOM_ID and "Choose a current-spec catalog build, then use it for leveling." or "Waiting for the next available talent point.")
        local qualification = info.detail or "Source freshness is unverified. Max-level imports follow prerequisite order unless this catalog build supplies a curated leveling order."
        local hasCurrentSpecBuild = false
        for i = 1, #self.rows do
            local row = self.rows[i]
            if row.specID == activeSpecID and row.id ~= NS.TALENT_BUILD_CUSTOM_ID then
                hasCurrentSpecBuild = true
                break
            end
        end
        local selectedRow = self.selectedRow
        if not hasCurrentSpecBuild and targetID == NS.TALENT_BUILD_CUSTOM_ID then
            targetName = "No current-spec catalog build"
            status = "No catalog leveling target exists for this specialization. Off-spec builds can be inspected or loaded manually."
        elseif selectedRow and selectedRow.specID ~= activeSpecID then
            status = "Selected build is off-spec. Select a " .. specName .. " catalog build for leveling."
        elseif selectedRow and selectedRow.id == NS.TALENT_BUILD_CUSTOM_ID then
            status = "Select a current-spec catalog build for leveling. Custom clears the leveling target."
        end

        levelingSpec:SetText("Active spec: " .. specName)
        levelingTarget:SetText("Target: " .. targetName)
        levelingNext:SetText(nextName and nextName ~= "" and ("Next recommended talent: " .. nextName) or "Next recommended talent: unavailable")
        local fullStatus = assessment and assessment.mismatchSummary or status
        for i = #levelingTooltip, 1, -1 do levelingTooltip[i] = nil end
        levelingTooltip[1] = "Leveling assistant"
        levelingTooltip[2] = fullStatus or ""
        levelingTooltip[3] = qualification or ""
        local qualificationLower = tostring(qualification or ""):lower()
        local sourceSummary = qualificationLower:find("unverified", 1, true) and "source unverified" or "source noted"
        local orderSummary = qualificationLower:find("curated", 1, true) and "curated/prerequisite order" or "prerequisite order"
        levelingStatus:SetText(ShortenText(fullStatus, 38) .. " | " .. sourceSummary .. "; " .. orderSummary)
        autoSpendBtn._text:SetText(enabled and "AUTO-SPEND: ON" or "AUTO-SPEND: OFF")
        sbaWarningBtn._text:SetText(assessment and assessment.warningEnabled == true and "SBA ALERT: ON" or "SBA ALERT: OFF")

        local selectedUsableBuild = selectedRow
            and selectedRow.specID == activeSpecID
            and selectedRow.id ~= NS.TALENT_BUILD_CUSTOM_ID
        useForLevelingBtn:SetEnabledState(selectedUsableBuild and true or false)
        autoSpendBtn:SetEnabledState(targetID ~= NS.TALENT_BUILD_CUSTOM_ID)
        spendNextBtn:SetEnabledState(not enabled and info.canSpend == true)
        sbaWarningBtn:SetEnabledState(activeSpecID ~= nil)
        respecSBABtn:SetEnabledState(assessment and assessment.hasMismatch == true and assessment.canRespec == true)
        local undoInfo = NS.GetTalentSBAUndoInfo and NS.GetTalentSBAUndoInfo()
        undoRespecBtn:SetEnabledState(undoInfo and undoInfo.canUndo == true)
        levelingHint:SetText(undoInfo and undoInfo.canUndo
            and "Undo restores the allocation saved before your last SBA respec."
            or (targetState and targetState.respecUndo and undoInfo and undoInfo.status)
            or "When enabled, points spend without a per-point approval.")
    end

    function state:Refresh()
        self.rows = self:CollectRows()
        self:UpdateFilterButtons()
        self.filteredRows = self:FilterRows(self:GetSortedRows(CopyTable(self.rows)))
        self.selectedRow = self:EnsureSelectedRow()
        self:UpdateHeaderSort()
        self:UpdateRows()
        self:UpdateDetails()
        self:UpdateLevelingAssist()
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

    useForLevelingBtn:SetCallback(function()
        local row = state.selectedRow
        local activeSpecID = NS.GetTalentBuildCurrentSpecID()
        if not row or row.specID ~= activeSpecID or row.id == NS.TALENT_BUILD_CUSTOM_ID then
            return
        end
        local ok, message = NS.SetTalentLevelingTarget(row.id)
        state:Refresh()
        if not ok and message and message ~= "" then
            levelingStatus:SetText(message)
        end
    end)

    autoSpendBtn:SetCallback(function()
        local info = NS.GetTalentLevelingInfo and NS.GetTalentLevelingInfo() or nil
        local targetState = NS.GetTalentLevelingState and NS.GetTalentLevelingState(NS.GetTalentBuildCurrentSpecID()) or nil
        local enabled = (info and info.enabled == true) or (targetState and targetState.enabled == true)
        local ok, message = NS.SetTalentLevelingEnabled(not enabled)
        state:Refresh()
        if not ok and message and message ~= "" then
            levelingStatus:SetText(message)
        end
    end)

    spendNextBtn:SetCallback(function()
        local ok, message = NS.SpendNextTalentPoint()
        state:Refresh()
        if not ok then
            levelingStatus:SetText(message or "No talent point was spent. Check the leveling status above.")
        end
    end)

    sbaWarningBtn:SetCallback(function()
        local assessment = NS.GetTalentSBAAssessment and NS.GetTalentSBAAssessment() or nil
        local enabled = assessment and assessment.warningEnabled == true
        local ok, message = NS.SetTalentSBAWarningEnabled(not enabled)
        state:Refresh()
        if not ok and message and message ~= "" then
            levelingStatus:SetText(message)
        end
    end)

    respecSBABtn:SetCallback(function()
        local ok, message = NS.RequestTalentSBARespec()
        state:Refresh()
        if not ok then
            levelingStatus:SetText(message or "Unable to respec to the selected SBA target. Recheck the current talent tree and try again.")
        end
    end)

    undoRespecBtn:SetCallback(function()
        local ok, message = NS.RequestTalentSBAUndo()
        state:Refresh()
        if not ok then levelingStatus:SetText(message or "Unable to restore the previous talents.") end
    end)

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
