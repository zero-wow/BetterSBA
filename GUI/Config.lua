local ADDON_NAME, NS = ...

local T = NS.THEME
NS.Config = {}

-- Dimensions and screen bounds share UIParent's coordinate space. Its scale
-- already includes WoW's UI scaling; do not apply an OS DPI multiplier again.
function NS.Config:ApplyScale()
    local frame = self.frame
    if not frame then return end
    local preferred = math.max(0.5, math.min(2, tonumber(NS.db.configPanelScale) or 1))
    local width, height = frame:GetWidth(), frame:GetHeight()
    local availableW = math.max(1, NS.UIParent:GetWidth() - 48)
    local availableH = math.max(1, NS.UIParent:GetHeight() - 48)
    local applied = math.min(preferred, availableW / width, availableH / height)
    frame:SetScale(applied)
    if self.zoomLabel then self.zoomLabel:SetText(string.format("%.0f%%", applied * 100)) end
    if self._refreshPixelLines then self._refreshPixelLines() end
end

local function GetContextSignature()
    local specIndex = GetSpecialization and GetSpecialization() or 0
    local signature = tostring(specIndex)
    for _, spellID in ipairs({NS.DEMON_SPIKES_SPELL_ID, NS.CONVOKE_THE_SPIRITS_ID,
        NS.SHIELD_BLOCK_SPELL_ID, NS.IGNORE_PAIN_SPELL_ID, NS.IRONFUR_SPELL_ID,
        NS.SHIELD_OF_RIGHTEOUS_ID, NS.RUNE_TAP_SPELL_ID, NS.PURIFYING_BREW_SPELL_ID}) do
        signature = signature .. ":" .. (NS.IsCombatAssistSpellKnown(spellID) and "1" or "0")
    end
    return signature
end

function NS.Config:QueueContextRefresh()
    if self._contextRefreshQueued then return end
    self._contextRefreshQueued = true
    NS.C_Timer_After(0, function()
        self._contextRefreshQueued = false
        local frame = self.frame
        if not frame or not frame:IsShown() then
            self._contextRefreshPending = true
            return
        end
        if NS.InCombatLockdown() then
            self._contextRefreshPending = true
            return
        end

        self._contextRefreshPending = false
        NS._restoreSection = NS._activeSection or 1
        NS._restoreScroll = self.scrollFrame and self.scrollFrame:GetVerticalScroll() or nil
        frame:SetAlpha(0)
        frame:Hide()
        self.frame = nil
        NS.C_Timer_After(0.02, function()
            self:Toggle()
            if self.frame then self.frame:SetAlpha(1) end
        end)
    end)
end

local contextRefreshFrame = NS.CreateFrame("Frame")
contextRefreshFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
contextRefreshFrame:RegisterEvent("SPELLS_CHANGED")
contextRefreshFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
contextRefreshFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if NS.Config._contextRefreshPending then
            NS.Config:QueueContextRefresh()
        end
        return
    end
    local signature = GetContextSignature()
    if signature == NS.Config._contextSignature then return end
    NS.Config._contextSignature = signature
    if not NS.Config.frame or not NS.Config.frame:IsShown() then
        NS.Config._contextRefreshPending = true
        return
    end
    NS.Config:QueueContextRefresh()
end)

local function ApplyFont()
    NS.ApplyButtonSettings()
    -- If config panel override is off, global font also affects the panel
    if not (NS.db and NS.db.configPanelFontOverride) then
        NS.UpdateAllConfigFonts()
    end
end

function NS.GetAnimCloneReapplyBindingText()
    local key = NS.db and NS.db.animCloneReapplyKey
    if not key or key == "" then
        return "Not Set"
    end
    local formatted = NS.FormatKeybind and NS.FormatKeybind(key)
    if formatted and formatted ~= "" then
        return formatted
    end
    return key
end

function NS.OpenAnimCloneReapplyKeyCapture(onApplied)
    local popup = NS.Config and NS.Config._animCloneReapplyKeyPopup
    local parent = (NS.Config and NS.Config.frame) or NS.UIParent
    if not popup then
        popup = NS.CreateFrame("Frame", "BetterSBA_AnimCloneReapplyKeyPopup", parent, "BackdropTemplate")
        popup:SetSize(300, 92)
        popup:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        popup:SetBackdropColor(T.BG_DARK[1], T.BG_DARK[2], T.BG_DARK[3], 0.98)
        popup:SetBackdropBorderColor(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3], 0.6)
        popup:SetFrameStrata("DIALOG")
        popup:EnableKeyboard(true)
        popup:SetPropagateKeyboardInput(false)

        local title = popup:CreateFontString(nil, "OVERLAY")
        title:SetFont(NS.GetConfigFontPath(), 10, "OUTLINE")
        title:SetPoint("TOP", 0, -10)
        title:SetTextColor(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3])
        title:SetText("Press a key combo")

        local hint = popup:CreateFontString(nil, "OVERLAY")
        hint:SetFont(NS.GetConfigFontPath(), 9, "")
        hint:SetPoint("TOP", title, "BOTTOM", 0, -10)
        hint:SetTextColor(NS.unpack(T.TEXT))
        hint:SetText("This only re-applies the animated clone hotkey text.")

        local hint2 = popup:CreateFontString(nil, "OVERLAY")
        hint2:SetFont(NS.GetConfigFontPath(), 8, "")
        hint2:SetPoint("TOP", hint, "BOTTOM", 0, -8)
        hint2:SetTextColor(NS.unpack(T.TEXT_MUTED))
        hint2:SetText("ESC cancels. Pick a spare combo.")

        popup:SetScript("OnHide", function(self)
            self._onApplied = nil
        end)
        popup:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" and not IsShiftKeyDown() and not IsControlKeyDown() and not IsAltKeyDown() then
                self:Hide()
                return
            end
            local binding = NS.BuildBindingChord and NS.BuildBindingChord(key)
            if not binding then return end
            NS.db.animCloneReapplyKey = binding
            if NS.ApplyAnimCloneDebugBinding then NS.ApplyAnimCloneDebugBinding() end
            if self._onApplied then self._onApplied(binding) end
            self:Hide()
        end)
        NS.Config._animCloneReapplyKeyPopup = popup
    end
    popup._onApplied = onApplied
    popup:SetParent(parent)
    popup:SetFrameLevel(parent:GetFrameLevel() + 20)
    popup:ClearAllPoints()
    popup:SetPoint("CENTER", parent, "CENTER")
    popup:Show()
end

function NS.CreateAnimCloneReapplyKeyControl(parent, yOffset, width)
    local W = width or ((parent._contentWidth or parent:GetWidth()) - 28)
    local row = NS.CreateFrame("Frame", nil, parent)
    row:SetSize(W, 38)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, yOffset)

    local lbl = row:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(NS.GetConfigFontPath(), 11, NS.GetConfigFontOutline())
    lbl:SetPoint("TOPLEFT", 0, 0)
    lbl:SetTextColor(NS.unpack(T.TEXT_DIM))
    lbl:SetText("Reapply Clone Hotkey")

    local bindW = W - 46
    local btn = NS.CreateFrame("Button", nil, row, "BackdropTemplate")
    btn:SetSize(bindW, 20)
    btn:SetPoint("TOPLEFT", 0, -16)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(NS.unpack(T.TOGGLE_OFF))
    btn:SetBackdropBorderColor(NS.unpack(T.BORDER))

    local btnText = btn:CreateFontString(nil, "OVERLAY")
    btnText:SetFont(NS.GetConfigFontPath(), 10, NS.GetConfigFontOutline())
    btnText:SetPoint("LEFT", 6, 0)
    btnText:SetPoint("RIGHT", -6, 0)
    btnText:SetJustifyH("LEFT")
    btnText:SetTextColor(NS.unpack(parent._sectionColor or T.ACCENT))

    local clear = NS.CreateFrame("Button", nil, row, "BackdropTemplate")
    clear:SetSize(40, 20)
    clear:SetPoint("TOPLEFT", btn, "TOPRIGHT", 6, 0)
    clear:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    clear:SetBackdropColor(NS.unpack(T.TOGGLE_OFF))
    clear:SetBackdropBorderColor(NS.unpack(T.BORDER))

    local clearText = clear:CreateFontString(nil, "OVERLAY")
    clearText:SetFont(NS.GetConfigFontPath(), 9, "OUTLINE")
    clearText:SetPoint("CENTER")
    clearText:SetText("Clear")

    row.Refresh = function()
        local hasKey = NS.db and NS.db.animCloneReapplyKey and NS.db.animCloneReapplyKey ~= ""
        btnText:SetText(NS.GetAnimCloneReapplyBindingText())
        if hasKey then
            clearText:SetTextColor(NS.unpack(T.TEXT))
        else
            clearText:SetTextColor(NS.unpack(T.TEXT_MUTED))
        end
    end

    btn:SetScript("OnClick", function()
        NS.OpenAnimCloneReapplyKeyCapture(function()
            row.Refresh()
        end)
    end)
    btn:SetScript("OnEnter", function(self)
        local sc = parent._sectionColorDim or T.ACCENT_DIM
        self:SetBackdropBorderColor(NS.unpack(sc))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(NS.unpack(T.BORDER))
    end)

    clear:SetScript("OnClick", function()
        if not NS.db or not NS.db.animCloneReapplyKey or NS.db.animCloneReapplyKey == "" then return end
        NS.db.animCloneReapplyKey = ""
        if NS.ApplyAnimCloneDebugBinding then NS.ApplyAnimCloneDebugBinding() end
        row.Refresh()
    end)
    clear:SetScript("OnEnter", function(self)
        local sc = parent._sectionColorDim or T.ACCENT_DIM
        self:SetBackdropBorderColor(NS.unpack(sc))
    end)
    clear:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(NS.unpack(T.BORDER))
    end)

    row.btn = btn
    row.clear = clear
    row.Refresh()
    return row
end

----------------------------------------------------------------
-- Create the config panel.
----------------------------------------------------------------
function NS.Config:Create()
    self._contextSignature = GetContextSignature()
    self._contextRefreshPending = false
    local panelW = 640
    local talentPanelW = 980
    local leftW = 0
    local rightW = panelW - leftW
    local defaultBasePanelH = (NS.defaults and NS.defaults.configPanelBaseHeight) or 480
    local defaultTalentPanelH = (NS.defaults and NS.defaults.configPanelHeight) or 620
    if NS.db.configPanelBaseHeight == nil then
        NS.db.configPanelBaseHeight = defaultBasePanelH
    end
    if NS.db.configPanelHeight == nil then
        NS.db.configPanelHeight = defaultTalentPanelH
    end
    if NS.db.configPanelBaseHeight == NS.db.configPanelHeight and NS.db.configPanelBaseHeight > defaultBasePanelH then
        NS.db.configPanelBaseHeight = defaultBasePanelH
    end
    local function GetBasePanelHeight()
        return math.max(400, math.min(900, NS.db.configPanelBaseHeight or defaultBasePanelH))
    end
    local function GetTalentPanelHeight()
        return math.max(400, math.min(900, NS.db.configPanelHeight or defaultTalentPanelH))
    end
    local titleH = 40
    local navH = 34
    local statusH = 24
    local sectionHeaderH = 42
    local scrollBarW = 6
    local scrollContentW = rightW - scrollBarW - 2
    local talentScrollContentW = (talentPanelW - leftW) - scrollBarW - 2
    local contentW = scrollContentW

    local f = NS.CreatePanel("BetterSBA_ConfigPanel", NS.UIParent, panelW, GetBasePanelHeight())
    f:SetBackdropColor(T.BG[1], T.BG[2], T.BG[3], 0.99)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:EnableMouse(true)
    f:Hide()

    ----------------------------------------------------------------
    -- Title bar
    ----------------------------------------------------------------
    local titleBar = NS.CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetHeight(titleH)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    titleBar:SetBackdropColor(NS.unpack(T.BG_HEADER))
    titleBar:SetBackdropBorderColor(0, 0, 0, 0)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetFont(NS.GetConfigFontPath(), 15, "")
    titleText:SetPoint("LEFT", 14, 0)
    titleText:SetTextColor(NS.unpack(T.ACCENT))
    titleText:SetText("BetterSBA")

    local ver = titleBar:CreateFontString(nil, "OVERLAY")
    ver:SetFont(NS.GetConfigFontPath(), 9, "")
    ver:SetPoint("LEFT", titleText, "RIGHT", 10, 0)
    ver:SetTextColor(NS.unpack(T.TEXT_MUTED))
    ver:SetText("Settings")

    local profileSummary = titleBar:CreateFontString(nil, "OVERLAY")
    profileSummary:SetFont(NS.GetConfigFontPath(), 10, "")
    profileSummary:SetPoint("RIGHT", -42, 0)
    profileSummary:SetWidth(152)
    profileSummary:SetWordWrap(false)
    profileSummary:SetMaxLines(1)
    profileSummary:SetJustifyH("RIGHT")
    profileSummary:SetTextColor(NS.unpack(T.TEXT_DIM))
    profileSummary:SetText("Profile: " .. NS:GetActiveProfileName())

    NS.CreateCloseButton(f)

    ----------------------------------------------------------------
    -- Title click → GitHub URL popup
    ----------------------------------------------------------------
    local titleHitbox = NS.CreateFrame("Button", nil, titleBar)
    titleHitbox:SetPoint("TOPLEFT", 14, -6)
    titleHitbox:SetSize(154, titleH - 12)
    NS.AddTooltip(titleHitbox, "BetterSBA " .. NS.VERSION, { "Settings save automatically.", "Click to view the project URL." })

    local urlPopup = nil
    local urlAutoCloseTicker = nil

    local function CloseURLPopup()
        if urlPopup then urlPopup:Hide() end
        if urlAutoCloseTicker then
            urlAutoCloseTicker:Cancel()
            urlAutoCloseTicker = nil
        end
    end

    local function ShowURLPopup()
        if urlPopup and urlPopup:IsShown() then
            CloseURLPopup()
            return
        end

        local GITHUB_URL = "https://github.com/zero-wow/BetterSBA/"

        if not urlPopup then
            local p = NS.CreateFrame("Frame", "BetterSBA_URLPopup", f, "BackdropTemplate")
            p:SetSize(320, 90)
            p:SetPoint("TOP", titleBar, "BOTTOM", 0, -4)
            p:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            p:SetBackdropColor(T.BG_DARK[1], T.BG_DARK[2], T.BG_DARK[3], 0.98)
            p:SetBackdropBorderColor(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3], 0.6)
            p:SetFrameStrata("DIALOG")
            p:SetFrameLevel(f:GetFrameLevel() + 20)
            p:EnableKeyboard(true)
            p:SetPropagateKeyboardInput(false)

            p:SetScript("OnKeyDown", function(self, key)
                if key == "SPACE" or key == "ESCAPE" then
                    self:SetPropagateKeyboardInput(false)
                    CloseURLPopup()
                else
                    self:SetPropagateKeyboardInput(true)
                end
            end)

            -- "URL copied" message
            local msg = p:CreateFontString(nil, "OVERLAY")
            msg:SetFont(NS.GetConfigFontPath(), 10, "")
            msg:SetPoint("TOP", 0, -10)
            msg:SetTextColor(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3])
            msg:SetText("GitHub URL — press Ctrl+C to copy")

            -- Selectable URL field
            local urlBox = NS.CreateFrame("EditBox", nil, p, "BackdropTemplate")
            urlBox:SetSize(290, 22)
            urlBox:SetPoint("TOP", msg, "BOTTOM", 0, -8)
            urlBox:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            urlBox:SetBackdropColor(T.BG[1], T.BG[2], T.BG[3], 1)
            urlBox:SetBackdropBorderColor(T.BORDER[1], T.BORDER[2], T.BORDER[3], 0.6)
            urlBox:SetFont(NS.GetConfigFontPath(), 10, "")
            urlBox:SetTextColor(NS.unpack(T.TEXT))
            urlBox:SetTextInsets(6, 6, 0, 0)
            urlBox:SetAutoFocus(false)
            urlBox:SetMaxLetters(200)
            urlBox:SetText(GITHUB_URL)
            urlBox:SetCursorPosition(0)

            -- When the EditBox gets focus, select all text for easy Ctrl+C
            urlBox:SetScript("OnEditFocusGained", function(self)
                self:HighlightText()
            end)
            -- Prevent editing — restore URL on any character input
            urlBox:SetScript("OnChar", function(self)
                self:SetText(GITHUB_URL)
                self:HighlightText()
            end)
            -- Escape in the EditBox closes the popup
            urlBox:SetScript("OnEscapePressed", function(self)
                self:ClearFocus()
                CloseURLPopup()
            end)

            -- "[SPACE] Close" hint
            local hint = p:CreateFontString(nil, "OVERLAY")
            hint:SetFont(NS.GetConfigFontPath(), 9, "")
            hint:SetPoint("BOTTOM", 0, 8)
            hint:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
            hint:SetText("[SPACE] or [ESC] to close")

            p._urlBox = urlBox
            urlPopup = p
        end

        -- Reset state and show
        urlPopup._urlBox:SetText(GITHUB_URL)
        urlPopup._urlBox:SetCursorPosition(0)
        urlPopup:Show()
        urlPopup._urlBox:SetFocus()
        urlPopup._urlBox:HighlightText()

        -- Auto-close after 5 seconds (NewTicker with 1 iteration = cancelable After)
        if urlAutoCloseTicker then urlAutoCloseTicker:Cancel() end
        urlAutoCloseTicker = NS.C_Timer_NewTicker(5, function()
            CloseURLPopup()
        end, 1)
    end

    titleHitbox:SetScript("OnClick", ShowURLPopup)
    titleHitbox:SetScript("OnEnter", function()
        titleText:SetTextColor(NS.unpack(T.TEXT))
    end)
    titleHitbox:SetScript("OnLeave", function()
        titleText:SetTextColor(NS.unpack(T.ACCENT))
    end)

    -- Close URL popup when config panel hides
    f:HookScript("OnHide", CloseURLPopup)

    ----------------------------------------------------------------
    -- Status bar (keybind intercept indicator)
    ----------------------------------------------------------------
    local statusBar = NS.CreateFrame("Frame", nil, f, "BackdropTemplate")
    statusBar:SetHeight(statusH)
    statusBar:SetPoint("BOTTOMLEFT", 0, 0)
    statusBar:SetPoint("BOTTOMRIGHT", 0, 0)
    statusBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    statusBar:SetBackdropColor(T.BG_DARK[1], T.BG_DARK[2], T.BG_DARK[3], 0.95)
    statusBar:SetBackdropBorderColor(T.BORDER[1], T.BORDER[2], T.BORDER[3], 0.4)
    statusBar:SetFrameLevel(f:GetFrameLevel() + 5)

    local statusIcon = statusBar:CreateTexture(nil, "ARTWORK")
    statusIcon:SetSize(8, 8)
    statusIcon:SetPoint("LEFT", 8, 0)
    statusIcon:SetTexture("Interface\\Buttons\\WHITE8X8")

    local statusText = statusBar:CreateFontString(nil, "OVERLAY")
    statusText:SetFont(NS.GetConfigFontPath(), 10, "")
    statusText:SetPoint("LEFT", statusIcon, "RIGHT", 5, 0)
    statusText:SetPoint("RIGHT", -82, 0)
    statusText:SetJustifyH("LEFT")

    local zoomButton = NS.CreateFrame("Button", nil, statusBar)
    zoomButton:SetSize(60, statusH - 4)
    zoomButton:SetPoint("RIGHT", -12, 0)
    local zoomLabel = zoomButton:CreateFontString(nil, "OVERLAY")
    zoomLabel:SetFont(NS.GetConfigFontPath(), 10, "")
    zoomLabel:SetPoint("RIGHT")
    zoomLabel:SetTextColor(NS.unpack(T.TEXT_DIM))
    self.zoomLabel = zoomLabel
    zoomButton:SetScript("OnClick", function()
        NS.db.configPanelScale = 1
        self:ApplyScale()
    end)
    NS.AddTooltip(zoomButton, "Panel zoom", { "Click to reset to 100%.", "Ctrl + mouse wheel adjusts zoom when Modifier Scaling is enabled." })

    local statusOverrideToken = 0
    local statusOverrideActive = false

    local function ApplyTemporaryStatus(kind, text)
        if kind == "error" then
            statusIcon:SetColorTexture(T.DANGER[1], T.DANGER[2], T.DANGER[3], 0.9)
            statusText:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])
        elseif kind == "success" then
            statusIcon:SetColorTexture(T.TOGGLE_ON[1], T.TOGGLE_ON[2], T.TOGGLE_ON[3], 1)
            statusText:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])
        elseif kind == "queued" or kind == "waiting" or kind == "prompt" or kind == "creating" or kind == "applying" then
            statusIcon:SetColorTexture(1.0, 0.53, 0.0, 0.9)
            statusText:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])
        elseif kind == "custom" or kind == "selected" then
            statusIcon:SetColorTexture(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3], 0.8)
            statusText:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])
        else
            statusIcon:SetColorTexture(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3], 0.8)
            statusText:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])
        end
        statusText:SetText(text or "")
    end

    local function RefreshStatus()
        if statusOverrideActive then
            if NS.UpdateLDBText then NS.UpdateLDBText() end
            return
        end
        local keys = NS._overrideKeys
        local clickSlot = NS.GetClickInterceptSlot and NS.GetClickInterceptSlot()
        local slot = NS._overrideSlot or clickSlot or (NS.GetCachedSBASlot and NS.GetCachedSBASlot())
        local bar = slot and (NS.math_floor((slot - 1) / 12) + 1) or nil
        local btn = slot and (((slot - 1) % 12) + 1) or nil
        if not NS.db.enabled then
            statusIcon:SetColorTexture(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3], 1)
            statusText:SetTextColor(NS.unpack(T.TEXT_DIM))
            statusText:SetText(NS.InCombatLockdown() and NS._pendingKeybindOverride
                and "Disabled - input changes apply after combat" or "BetterSBA is disabled")
        elseif NS._pendingMacroRebuild or NS._pendingClickIntercept or NS._pendingKeybindOverride then
            statusIcon:SetColorTexture(1, 0.65, 0.2, 1)
            statusText:SetTextColor(NS.unpack(T.TEXT_DIM))
            statusText:SetText("Settings saved - input changes apply after combat")
        elseif keys and #keys > 0 and slot then
            statusIcon:SetColorTexture(T.TOGGLE_ON[1], T.TOGGLE_ON[2], T.TOGGLE_ON[3], 1)
            local keyStr = NS.table_concat(keys, ", ")
            statusText:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])
            statusText:SetText("Hotkey " .. keyStr .. (clickSlot and " + mouse click" or "") .. " connected   /   Bar " .. bar .. ", slot " .. btn)
        elseif clickSlot then
            statusIcon:SetColorTexture(T.TOGGLE_ON[1], T.TOGGLE_ON[2], T.TOGGLE_ON[3], 1)
            statusText:SetTextColor(NS.unpack(T.TEXT))
            statusText:SetText("Mouse click connected   /   Bar " .. bar .. ", slot " .. btn)
        elseif slot then
            local reason = NS.GetInterceptBlockReason and NS.GetInterceptBlockReason()
            if reason then
                statusIcon:SetColorTexture(1.0, 0.53, 0.0, 0.9)
                statusText:SetTextColor(T.TEXT_DIM[1], T.TEXT_DIM[2], T.TEXT_DIM[3])
                statusText:SetText("Paused - " .. reason .. "   /   Bar " .. bar .. ", slot " .. btn)
            else
                statusIcon:SetColorTexture(T.DANGER[1], T.DANGER[2], T.DANGER[3], 0.8)
                statusText:SetTextColor(T.TEXT_DIM[1], T.TEXT_DIM[2], T.TEXT_DIM[3])
                statusText:SetText("SBA found on bar " .. bar .. ", slot " .. btn .. " - no active interception")
            end
        else
            local reason = NS.GetInterceptBlockReason and NS.GetInterceptBlockReason()
            if reason then
                statusIcon:SetColorTexture(1.0, 0.53, 0.0, 0.7)
                statusText:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
                statusText:SetText("Paused — " .. reason)
            else
                statusIcon:SetColorTexture(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3], 0.6)
                statusText:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
                statusText:SetText("SBA not found on action bar")
            end
        end
        if NS.UpdateLDBText then NS.UpdateLDBText() end
    end

    function NS.ShowConfigStatusMessage(text, kind, duration)
        if not statusBar or not statusText or not statusIcon then
            return
        end
        statusOverrideToken = statusOverrideToken + 1
        local token = statusOverrideToken
        statusOverrideActive = true
        ApplyTemporaryStatus(kind, text)
        NS.C_Timer_After(duration or 4, function()
            if statusOverrideToken ~= token then
                return
            end
            statusOverrideActive = false
            RefreshStatus()
        end)
    end

    NS.UpdateKeybindStatus = RefreshStatus
    f:HookScript("OnShow", RefreshStatus)
    f:HookScript("OnShow", function()
        if NS.Config._contextRefreshPending then
            NS.Config:QueueContextRefresh()
        end
    end)
    f:HookScript("OnHide", function()
        statusOverrideToken = statusOverrideToken + 1
        statusOverrideActive = false
    end)

    ----------------------------------------------------------------
    -- A horizontal navigation strip leaves the page's full width for settings.
    ----------------------------------------------------------------
    local tabBar = NS.CreateFrame("Frame", nil, f)
    tabBar:SetHeight(navH)
    tabBar:SetPoint("TOPLEFT", 0, -titleH)
    tabBar:SetPoint("TOPRIGHT", 0, -titleH)
    local tabBackground = tabBar:CreateTexture(nil, "BACKGROUND")
    tabBackground:SetAllPoints()
    tabBackground:SetColorTexture(T.BG_HEADER[1], T.BG_HEADER[2], T.BG_HEADER[3], 0.65)
    self.tabBar = tabBar

    local divider = tabBar:CreateTexture(nil, "OVERLAY")
    divider:SetHeight(1)
    divider:SetPoint("BOTTOMLEFT", tabBar, "BOTTOMLEFT", 12, 0)
    divider:SetPoint("BOTTOMRIGHT", tabBar, "BOTTOMRIGHT", -12, 0)
    divider:SetColorTexture(T.BORDER[1], T.BORDER[2], T.BORDER[3], 0.4)

    ----------------------------------------------------------------
    -- Right panel: section title + underline
    ----------------------------------------------------------------
    local sectionTitle = f:CreateFontString(nil, "OVERLAY")
    sectionTitle:SetFont(NS.GetConfigFontPath(), 16, "")
    sectionTitle:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -titleH - navH - 10)
    sectionTitle:SetPoint("RIGHT", f, "RIGHT", -138, 0)
    sectionTitle:SetJustifyH("LEFT")
    sectionTitle:SetTextColor(NS.unpack(T.TEXT))

    local sectionJump = NS.CreateFrame("Button", nil, f, "BackdropTemplate")
    sectionJump:SetSize(112, 24)
    sectionJump:SetPoint("TOPRIGHT", -14, -titleH - navH - 9)
    sectionJump:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
    sectionJump:SetBackdropColor(NS.unpack(T.BG_HEADER))
    sectionJump:SetBackdropBorderColor(NS.unpack(T.BORDER))
    local jumpLabel = sectionJump:CreateFontString(nil, "OVERLAY")
    jumpLabel:SetFont(NS.GetConfigFontPath(), 10, "")
    jumpLabel:SetPoint("CENTER")
    jumpLabel:SetText("Jump to section")
    jumpLabel:SetTextColor(NS.unpack(T.TEXT_DIM))

    local sectionMenu = NS.CreateFrame("Frame", nil, f, "BackdropTemplate")
    sectionMenu:SetPoint("TOPRIGHT", sectionJump, "BOTTOMRIGHT", 0, -6)
    sectionMenu:SetSize(260, 200)
    sectionMenu:SetFrameStrata("DIALOG")
    sectionMenu:SetFrameLevel(f:GetFrameLevel() + 30)
    sectionMenu:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
    sectionMenu:SetBackdropColor(T.BG_HEADER[1], T.BG_HEADER[2], T.BG_HEADER[3], 1)
    sectionMenu:SetBackdropBorderColor(NS.unpack(T.BORDER_ACCENT))
    sectionMenu:EnableMouse(true)
    sectionMenu:Hide()
    local sectionMenuScroll = NS.CreateFrame("ScrollFrame", nil, sectionMenu)
    sectionMenuScroll:SetPoint("TOPLEFT", 6, -6)
    sectionMenuScroll:SetPoint("BOTTOMRIGHT", -6, 6)
    local sectionMenuContent = NS.CreateFrame("Frame", nil, sectionMenuScroll)
    sectionMenuContent:SetSize(248, 100)
    sectionMenuScroll:SetScrollChild(sectionMenuContent)
    sectionMenu:EnableMouseWheel(true)
    sectionMenu:SetScript("OnMouseWheel", function(_, delta)
        local maxScroll = math.max(0, sectionMenuContent:GetHeight() - sectionMenuScroll:GetHeight())
        sectionMenuScroll:SetVerticalScroll(math.max(0, math.min(maxScroll, sectionMenuScroll:GetVerticalScroll() - delta * 52)))
    end)
    sectionJump:SetScript("OnClick", function()
        sectionMenu:SetHeight(math.min(sectionMenuContent:GetHeight() + 12, f:GetHeight() - titleH - navH - statusH - 63))
        sectionMenuScroll:SetVerticalScroll(0)
        sectionMenu:SetShown(not sectionMenu:IsShown())
    end)
    f:HookScript("OnHide", function() sectionMenu:Hide() end)
    self.sectionJump, self.sectionMenu = sectionJump, sectionMenu

    local titleUnderline = f:CreateTexture(nil, "ARTWORK")
    titleUnderline:SetHeight(1)
    titleUnderline:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -titleH - navH - sectionHeaderH + 9)
    titleUnderline:SetPoint("RIGHT", f, "RIGHT", -14, 0)
    titleUnderline:SetColorTexture(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3], 0.6)

    ----------------------------------------------------------------
    -- Right panel: scroll frame
    ----------------------------------------------------------------
    local scrollFrame = NS.CreateFrame("ScrollFrame", nil, f)
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -titleH - navH - sectionHeaderH)
    scrollFrame:SetPoint("BOTTOMRIGHT", -scrollBarW - 2, statusH)

    local scrollChild = NS.CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollContentW)
    scrollChild:SetHeight(100)
    scrollFrame:SetScrollChild(scrollChild)

    -- Scrollbar track
    local scrollTrack = NS.CreateFrame("Frame", nil, f, "BackdropTemplate")
    scrollTrack:SetWidth(scrollBarW)
    scrollTrack:SetPoint("TOPRIGHT", -4, -titleH - navH - sectionHeaderH)
    scrollTrack:SetPoint("BOTTOMRIGHT", 0, statusH)
    scrollTrack:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    scrollTrack:SetBackdropColor(T.BG_DARK[1], T.BG_DARK[2], T.BG_DARK[3], 0.5)
    scrollTrack:Hide()

    -- Scrollbar thumb
    local scrollThumb = NS.CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
    scrollThumb:SetWidth(scrollBarW)
    scrollThumb:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    scrollThumb:SetBackdropColor(T.ACCENT_DIM[1], T.ACCENT_DIM[2], T.ACCENT_DIM[3], 0.8)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
    scrollThumb:EnableMouse(true)
    scrollThumb:SetMovable(true)

    -- Thumb dragging
    local thumbDragging = false
    local thumbDragStart = 0
    local thumbScrollStart = 0

    scrollThumb:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            thumbDragging = true
            self:SetScript("OnUpdate", function(frame)
                if not thumbDragging then return end
                local _, cursorY = GetCursorPosition()
                local scale = frame:GetEffectiveScale()
                cursorY = cursorY / scale
                local delta = thumbDragStart - cursorY
                local trackH = scrollTrack:GetHeight()
                local thumbH = frame:GetHeight()
                local scrollRange = scrollChild:GetHeight() - scrollFrame:GetHeight()
                if scrollRange <= 0 or trackH <= thumbH then return end
                local scrollPerPixel = scrollRange / (trackH - thumbH)
                local newScroll = thumbScrollStart + delta * scrollPerPixel
                scrollFrame:SetVerticalScroll(math.max(0, math.min(scrollRange, newScroll)))
            end)
            local _, cursorY = GetCursorPosition()
            local scale = self:GetEffectiveScale()
            thumbDragStart = cursorY / scale
            thumbScrollStart = scrollFrame:GetVerticalScroll()
        end
    end)
    scrollThumb:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            thumbDragging = false
            self:SetScript("OnUpdate", nil)
        end
    end)
    scrollThumb:SetScript("OnHide", function(self)
        thumbDragging = false
        self:SetScript("OnUpdate", nil)
    end)

    local function UpdateScrollbar()
        local ch = scrollChild:GetHeight()
        local viewH = scrollFrame:GetHeight()
        if ch <= viewH then
            scrollTrack:Hide()
            return
        end
        scrollTrack:Show()
        local trackH = scrollTrack:GetHeight()
        local ratio = viewH / ch
        local thumbH = math.max(20, trackH * ratio)
        scrollThumb:SetHeight(thumbH)
        local scrollRange = ch - viewH
        local scroll = scrollFrame:GetVerticalScroll()
        local pct = scroll / scrollRange
        local travel = trackH - thumbH
        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -pct * travel)
    end

    scrollFrame:SetScript("OnScrollRangeChanged", UpdateScrollbar)
    scrollFrame:SetScript("OnVerticalScroll", UpdateScrollbar)

    local function OnMouseWheel(_, delta)
        if IsControlKeyDown() and NS.db.modifierScaling then
            local scale = NS.db.configPanelScale or 1.0
            scale = scale + delta * 0.05
            scale = math.max(0.5, math.min(2.0, scale))
            scale = tonumber(string.format("%.2f", scale))
            NS.db.configPanelScale = scale
            NS.Config:ApplyScale()
            return
        end
        local scroll = scrollFrame:GetVerticalScroll()
        local step = 30
        local maxScroll = math.max(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
        scroll = math.max(0, math.min(maxScroll, scroll - delta * step))
        scrollFrame:SetVerticalScroll(scroll)
    end
    f:SetScript("OnMouseWheel", OnMouseWheel)
    scrollFrame:SetScript("OnMouseWheel", OnMouseWheel)
    f:EnableMouseWheel(true)
    scrollFrame:EnableMouseWheel(true)

    ----------------------------------------------------------------
    -- Resize grip
    ----------------------------------------------------------------
    f:SetResizable(true)
    f:SetResizeBounds(panelW, 400, panelW, 900)

    local grip = NS.CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    grip:SetScript("OnMouseDown", function()
        sectionMenu:Hide()
        f:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        if math.abs(f:GetWidth() - talentPanelW) < 0.5 then
            NS.db.configPanelHeight = f:GetHeight()
        else
            NS.db.configPanelBaseHeight = f:GetHeight()
        end
        UpdateScrollbar()
        NS.Config:ApplyScale()
    end)

    ----------------------------------------------------------------
    -- Section definitions (reordered with importance classification)
    ----------------------------------------------------------------
    local db = NS.db
    local SECTIONS = {
        { id = "COMBAT_ASSIST",  label = "Combat Assist",  dotColor = db.sectionColorCombat,     dbKey = "sectionColorCombat" },
        { id = "APPEARANCE",     label = "Appearance",      dotColor = db.sectionColorAppearance, dbKey = "sectionColorAppearance" },
        { id = "ACTIVE_DISPLAY", label = "Active Display",  dotColor = db.sectionColorActive,     dbKey = "sectionColorActive" },
        { id = "PRIORITY",       label = "Priority Display", dotColor = db.sectionColorPriority,   dbKey = "sectionColorPriority" },
        { id = "TALENT_BUILDS",  label = "Talent Builds",   dotColor = db.sectionColorTalentBuilds, dbKey = "sectionColorTalentBuilds" },
        { id = "VISIBILITY",     label = "Visibility",      dotColor = db.sectionColorVisibility, dbKey = "sectionColorVisibility" },
        { id = "IMPORTANCE",     label = "Importance",      dotColor = db.sectionColorImportance, dbKey = "sectionColorImportance" },
        { id = "ADVANCED",       label = "Advanced",        dotColor = db.sectionColorAdvanced,   dbKey = "sectionColorAdvanced" },
        { id = "PROFILES",       label = "Profiles",        dotColor = db.sectionColorProfiles,   dbKey = "sectionColorProfiles" },
    }
    local function IsTalentBuildSectionIndex(idx)
        return idx and SECTIONS[idx] and SECTIONS[idx].id == "TALENT_BUILDS"
    end

    local function ApplySectionWindowSize(idx)
        local isTalent = IsTalentBuildSectionIndex(idx)
        local targetW = isTalent and talentPanelW or panelW
        local targetH = isTalent and GetTalentPanelHeight() or GetBasePanelHeight()
        local targetContentW = isTalent and talentScrollContentW or scrollContentW

        f:SetWidth(targetW)
        f:SetHeight(targetH)
        f:SetResizeBounds(targetW, 400, targetW, 900)
        scrollChild:SetWidth(targetContentW)
        NS.Config:ApplyScale()
    end

    -- Content frames (one per section, parented to scrollChild)
    local contentFrames = {}
    local subHeaderLines = {}
    local activeSection = 1

    local function ClampColorValue(value)
        return math.max(0, math.min(1, value))
    end

    local function BrightenColor(color, amount, alpha)
        amount = amount or 0.3
        return {
            ClampColorValue(color[1] + (1 - color[1]) * amount),
            ClampColorValue(color[2] + (1 - color[2]) * amount),
            ClampColorValue(color[3] + (1 - color[3]) * amount),
            alpha or 1,
        }
    end

    local function DarkenColor(color, factor, alpha)
        factor = factor or 0.7
        return {
            ClampColorValue(color[1] * factor),
            ClampColorValue(color[2] * factor),
            ClampColorValue(color[3] * factor),
            alpha or 1,
        }
    end

    local function PositionSectionEndDivider(line, parent, yPos)
        if line then
            line:Hide()
        end
    end

    local function CreateSectionEndDivider(parent, yPos)
        local line = parent:CreateTexture(nil, "ARTWORK")
        line:SetHeight(2)
        PositionSectionEndDivider(line, parent, yPos)
        return line
    end

    for i = 1, #SECTIONS do
        local cf = NS.CreateFrame("Frame", nil, scrollChild)
        if SECTIONS[i].id == "TALENT_BUILDS" then
            cf:SetWidth(talentScrollContentW)
            cf._contentWidth = talentScrollContentW
        else
            cf:SetWidth(contentW)
            cf._contentWidth = contentW
        end
        cf:SetPoint("TOPLEFT", 0, 0)
        cf:Hide()
        cf._sectionIndex = i
        cf._subsections = {}
        local dc = SECTIONS[i].dotColor
        cf._sectionColor = dc
        cf._sectionColorBright = BrightenColor(dc, 0.3, 1)
        cf._sectionColorDim = DarkenColor(dc, 0.82, 0.7)
        cf:SetScript("OnSizeChanged", function(self)
            if self:IsVisible() and activeSection == self._sectionIndex then
                scrollChild:SetHeight(self._contentH or self:GetHeight())
                local maxScroll = math.max(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
                if scrollFrame:GetVerticalScroll() > maxScroll then
                    scrollFrame:SetVerticalScroll(maxScroll)
                end
                UpdateScrollbar()
            end
        end)
        contentFrames[i] = cf
    end

    ----------------------------------------------------------------
    -- Panel rebuild (destroy + recreate, preserving section/scroll)
    ----------------------------------------------------------------
    local function rebuildPanel()
        NS._restoreSection = NS._activeSection or activeSection
        NS._restoreScroll = scrollFrame:GetVerticalScroll()
        NS.Config.frame:SetAlpha(0)
        NS.Config.frame:Hide()
        NS.Config.frame = nil
        NS.C_Timer_After(0.02, function()
            NS.Config:Toggle()
            if NS.Config.frame then
                NS.Config.frame:SetAlpha(1)
            end
        end)
    end

    ----------------------------------------------------------------
    -- Default button helper (resets DB keys + rebuilds panel)
    ----------------------------------------------------------------
    local function CreateDefaultBtn(parent, hdr, keys)
        local btn = NS.CreateFrame("Button", nil, parent)
        btn:SetSize(40, 12)
        btn:SetPoint("RIGHT", parent, "RIGHT", -14, 0)
        if hdr then
            btn:SetPoint("TOP", hdr, "TOP", 0, 1)
        else
            btn:SetPoint("TOP", parent, "TOP", 0, -2)
        end
        local lbl = btn:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(NS.GetConfigFontPath(), 9, "")
        lbl:SetPoint("CENTER")
        lbl:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
        lbl:SetText("Reset")
        btn:SetScript("OnClick", function()
            for i = 1, #keys do
                local def = NS.defaults[keys[i]]
                if NS.type(def) == "table" then
                    NS.db[keys[i]] = CopyTable(def)
                else
                    NS.db[keys[i]] = def
                end
            end
            NS:ApplyProfileVisuals()
            rebuildPanel()
        end)
        btn:SetScript("OnEnter", function()
            local sc = parent._sectionColorBright or T.ACCENT_BRIGHT
            lbl:SetTextColor(sc[1], sc[2], sc[3])
        end)
        btn:SetScript("OnLeave", function()
            lbl:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
        end)
        return btn
    end

    ----------------------------------------------------------------
    -- Sub-header helper: creates label + ruler + returns the header
    ----------------------------------------------------------------
    local function CreateSubHeader(parent, text, yPos)
        local col = parent._sectionColor or T.TEXT_DIM
        local hdr = parent:CreateFontString(nil, "OVERLAY")
        hdr:SetFont(NS.GetConfigFontPath(), 11, "")
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
        line._header = hdr
        subHeaderLines[#subHeaderLines + 1] = line
        if parent._subsections then
            parent._subsections[#parent._subsections + 1] = {
                label = text,
                y = yPos,
                header = hdr,
            }
        end
        return hdr
    end

    ----------------------------------------------------------------
    -- Build section content (all 39 options)
    ----------------------------------------------------------------
    local c, y

    -- Tooltip color shortcuts
    local K, U, V, W, N, R = NS.TC.KEY, NS.TC.UI, NS.TC.VAL, NS.TC.WARN, NS.TC.NUM, NS.TC.R

    -- 1. COMBAT ASSIST (4 options)
    c = contentFrames[1]
    y = -6
    do
    local c, y = c, y -- Keep callbacks bound to this section.
    local macroHdr = CreateSubHeader(c, "MACRO ACTIONS", y)
    CreateDefaultBtn(c, macroHdr, {"enableDismount", "enableTargeting", "enablePetAttack", "enableChannelProtection"})
    y = y - 18
    local r1 = NS.CreateToggle(c, "Auto-Dismount", "enableDismount", y, function()
        NS.RebuildMacroText()
        NS.RefreshSBAInterception()
    end)
    NS.AddTooltip(r1, "Auto-Dismount", {
        "Adds " .. K .. "/dismount" .. R .. " to the macro before casting.",
        " ",
        "When " .. V .. "enabled" .. R .. ", automatically dismounts before",
        "the " .. U .. "Single-Button Assistant" .. R .. " fires.",
        "Ground mounts stay interceptable while this is enabled.",
        "Vehicle and skyriding bars remain protected from interception.",
    }, c)
    y = y - 28
    local r2 = NS.CreateToggle(c, "Auto-Target Enemies", "enableTargeting", y, function() NS.RebuildMacroText() end)
    NS.AddTooltip(r2, "Auto-Target Enemies", {
        "Adds " .. K .. "/targetenemy [noharm][dead]" .. R .. " to the macro.",
        " ",
        "Uses Blizzard's enemy targeting if your",
        "current target is " .. W .. "dead" .. R .. ", " .. W .. "friendly" .. R .. ", or " .. W .. "missing" .. R .. ".",
        "Attempts before the cast on each press; it does not select by threat or priority.",
    }, c)
    y = y - 28
    local r3  -- Pet Attack toggle (nil for non-pet classes)
    if NS.IsPetClass and NS.IsPetClass() then
        r3 = NS.CreateToggle(c, "Pet Attack", "enablePetAttack", y, function() NS.RebuildMacroText() end)
        NS.AddTooltip(r3, "Pet Attack", {
            "Adds " .. K .. "/petattack [pet,harm,nodead]" .. R .. " to the macro.",
            " ",
            "Sends your pet to attack your current target",
            "on each press, even if SBA cannot cast yet.",
            "Requires an active pet and a living hostile target.",
        }, c)
        y = y - 28
    end
    local r4 = NS.CreateToggle(c, "Channel Protection", "enableChannelProtection", y, function() NS.RebuildMacroText() end)
    NS.AddTooltip(r4, "Channel Protection", {
        "Adds " .. K .. "/stopmacro [channeling]" .. R .. " to the macro.",
        " ",
        "Prevents " .. U .. "SBA" .. R .. " from interrupting channeled spells",
        "like " .. V .. "Rapid Fire" .. R .. " or " .. V .. "Eye Beam" .. R .. ".",
        "The macro " .. W .. "stops executing" .. R .. " if you are channeling.",
        "Turning this off removes channel guards; repeated presses may interrupt channels.",
    }, c)
    y = y - 28

    -- Class-specific off-GCD abilities (only shown for the relevant tank spec)
    -- Each entry: { dbKey, label, spellID, specCheck, tooltip, comment }
    local CLASS_ABILITIES = {
        { "enableDemonSpikes",      "Demon Spikes",           NS.DEMON_SPIKES_SPELL_ID,   "Vengeance",
            "Vengeance Demon Hunter only.",
            "Attempts off-GCD mitigation on each combat press.",
            "Does not time charges around incoming damage.", nil, true },
        { "enableConvokeTheSpirits","Convoke the Spirits",    NS.CONVOKE_THE_SPIRITS_ID,  "DRUID",
            "Druid only.",
            "Attempts the channel before SBA on each combat press.",
            "May take that press instead of SBA; does not choose burst windows.",
            "before", true },
        { "enableShieldBlock",      "Shield Block",           NS.SHIELD_BLOCK_SPELL_ID,   "Protection:W",
            "Protection Warrior only.",
            "Attempts off-GCD blocking on each combat press.",
            "Consumes Rage and charges when the client allows it.", nil, true },
        { "enableIgnorePain",       "Ignore Pain",            NS.IGNORE_PAIN_SPELL_ID,    "Protection:W",
            "Protection Warrior only.",
            "Off-GCD Rage dump that applies an absorb shield.",
            W .. "Off by default" .. R .. " \226\128\148 drains Rage quickly.", nil, true },
        { "enableIronfur",          "Ironfur",                NS.IRONFUR_SPELL_ID,        "Guardian",
            "Guardian Druid only.",
            "Attempts off-GCD stacking armor before SBA.",
            "Spends available Rage without choosing an armor target.",
            "before", true },
        { "enableShieldOfRighteous","Shield of the Righteous",NS.SHIELD_OF_RIGHTEOUS_ID,  "Protection:Pa",
            "Protection Paladin only.",
            "Attempts off-GCD mitigation; spends Holy Power.",
            W .. "Competes with Word of Glory for HP." .. R, nil, true },
        { "enableRuneTap",          "Rune Tap",               NS.RUNE_TAP_SPELL_ID,       "Blood",
            "Blood Death Knight only.",
            "Attempts off-GCD damage reduction on each combat press.",
            W .. "Off by default" .. R .. " - spends runes without timing incoming damage.", nil, true },
        { "enablePurifyingBrew",    "Purifying Brew",         NS.PURIFYING_BREW_SPELL_ID, "Brewmaster",
            "Brewmaster Monk only.",
            "Attempts off-GCD purification on each combat press.",
            W .. "Off by default" .. R .. " - does not wait for high Stagger.", nil, true },
    }

    local function IsCombatAssistAbilityVisible(info)
        local gate = info[4]
        if gate == "DRUID" then
            return NS.IsClass("DRUID")
        end
        return NS.IsSpec(gate)
    end

    local function IsCombatAssistAbilityAvailable(info)
        return NS.IsCombatAssistSpellKnown(info[3])
    end

    -- Collect which abilities apply to this character's current spec
    local activeAbilities = {}
    for _, info in NS.ipairs(CLASS_ABILITIES) do
        if IsCombatAssistAbilityVisible(info) then
            activeAbilities[#activeAbilities + 1] = info
        end
    end

    local classToggles = {}
    local RefreshMacroPreview
    if #activeAbilities > 0 then
        -- Sub-header: CLASS OPTIONS
        do
            local col = c._sectionColor or T.TEXT_DIM
            local hdr = c:CreateFontString(nil, "OVERLAY")
            hdr:SetFont(NS.GetConfigFontPath(), 11, "")
            hdr:SetPoint("TOPLEFT", c, "TOPLEFT", 14, y)
            hdr:SetTextColor(col[1], col[2], col[3])
            hdr:SetText("CLASS OPTIONS")
            local line = c:CreateTexture(nil, "ARTWORK")
            line:SetHeight(1)
            line:SetColorTexture(col[1], col[2], col[3], 0.4)
            line:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -3)
            line:SetPoint("RIGHT", c, "RIGHT", -14, 0)
            subHeaderLines[#subHeaderLines + 1] = line
            c._subHdr = hdr
        end
        y = y - 18

        local classKeys = {}
        for _, info in NS.ipairs(activeAbilities) do
            local dbKey, label, _, _, specNote, desc1, desc2, castOrder = NS.unpack(info)
            classKeys[#classKeys + 1] = dbKey
            local toggle = NS.CreateToggle(c, label, dbKey, y, function() NS.RebuildMacroText() end)
            local available = IsCombatAssistAbilityAvailable(info)
            toggle:SetEnabledState(available)
            local castNote
            if castOrder == "before" then
                castNote = "Adds " .. K .. "/cast " .. label .. R .. " before the"
            else
                castNote = "Adds " .. K .. "/cast " .. label .. R .. " after the"
            end
            local tooltipLines = {
                castNote,
                U .. "Single-Button Assistant" .. R .. " cast.",
                " ",
                desc1,
                desc2,
                " ",
                W .. specNote .. R,
            }
            if dbKey == "enableIronfur" then
                tooltipLines[#tooltipLines + 1] = " "
                tooltipLines[#tooltipLines + 1] = W .. "Ironfur is injected before " .. U .. "Single-Button Assistant" .. R .. W .. "." .. R
                tooltipLines[#tooltipLines + 1] = "Spending Rage first can leave less for SBA's next attack."
                tooltipLines[#tooltipLines + 1] = "Requires Bear Form; this option does not change your form."
            end
            if not available then
                tooltipLines[#tooltipLines + 1] = " "
                tooltipLines[#tooltipLines + 1] = W .. "This spell is not learned or is unavailable in your spellbook." .. R
                tooltipLines[#tooltipLines + 1] = "The option is disabled and its cast line is omitted."
            end
            NS.AddTooltip(toggle, label, tooltipLines, c)
            classToggles[#classToggles + 1] = toggle
            y = y - 28
        end
        CreateDefaultBtn(c, c._subHdr, classKeys)
        y = y - 4
    end

    local trinketHdr = CreateSubHeader(c, "TRINKETS", y)
    CreateDefaultBtn(c, trinketHdr, {"trinketMode"})
    y = y - 18
    local trinketModeRow = NS.CreateOptionsDropdown(c, "Trinket Use", "trinketMode", {"Off", "Approved"}, y, function()
        if NS.RefreshTrinkets then NS.RefreshTrinkets() end
        if NS.RebuildMacroText then NS.RebuildMacroText() end
        if RefreshMacroPreview then RefreshMacroPreview() end
        if NS.RefreshTrinketConfig then NS.RefreshTrinketConfig() end
    end)
    NS.AddTooltip(trinketModeRow, "Trinket Use", {
        V .. "Approved" .. R .. " uses only item and spell pairs you have individually approved.",
        "Approve only instant, off-GCD, non-channeling trinket uses.",
        W .. "Off" .. R .. " leaves trinkets out of the SBA macro.",
    }, c)
    y = y - 46

    local trinketRows = {}
    local trinketRowW = (contentW - 42) / 2
    for slot = 1, 2 do
        local row = NS.CreateFrame("Frame", nil, c)
        row:SetSize(trinketRowW, 66)
        row:SetPoint("TOPLEFT", c, "TOPLEFT", 14 + (slot - 1) * (trinketRowW + 14), y)
        row._trinketSlot = slot
        local name = row:CreateFontString(nil, "OVERLAY")
        name:SetFont(NS.GetConfigFontPath(), 10, NS.GetConfigFontOutline())
        name:SetPoint("TOPLEFT", 0, 0)
        name:SetPoint("RIGHT", row, "RIGHT", -78, 0)
        name:SetJustifyH("LEFT")
        name:SetWordWrap(false)
        name:SetMaxLines(1)
        local state = row:CreateFontString(nil, "OVERLAY")
        state:SetFont(NS.GetConfigFontPath(), 9, "OUTLINE")
        state:SetPoint("TOPRIGHT", 0, 0)
        state:SetJustifyH("RIGHT")
        local reason = row:CreateFontString(nil, "OVERLAY")
        reason:SetFont(NS.GetConfigFontPath(), 9, NS.GetConfigFontOutline())
        reason:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -1)
        reason:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        reason:SetJustifyH("LEFT")
        reason:SetWordWrap(true)
        reason:SetMaxLines(2)

        local allow = NS.CreateFrame("Button", nil, row, "BackdropTemplate")
        allow:SetSize(16, 16)
        allow:SetPoint("TOPLEFT", reason, "BOTTOMLEFT", 0, -4)
        allow:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        local allowFill = allow:CreateTexture(nil, "ARTWORK")
        allowFill:SetPoint("TOPLEFT", 2, -2)
        allowFill:SetPoint("BOTTOMRIGHT", -2, 2)
        local allowLabel = row:CreateFontString(nil, "OVERLAY")
        allowLabel:SetFont(NS.GetConfigFontPath(), 9, NS.GetConfigFontOutline())
        allowLabel:SetPoint("LEFT", allow, "RIGHT", 6, 0)
        allowLabel:SetText("Allow this trinket")
        NS.AddTooltip(allow, "Allow This Trinket", {
            "Confirm that this exact item and use spell are instant, off-GCD, and non-channeling.",
            "Cast-time items are not eligible.",
            "Approval follows the item and spell, not this equipment slot.",
        }, c)
        trinketRows[slot] = {
            name = name, state = state, reason = reason,
            allow = allow, allowFill = allowFill, allowLabel = allowLabel,
        }
    end
    y = y - 70

    function NS.RefreshTrinketConfig()
        for slot = 1, 2 do
            local row = trinketRows[slot]
            local inventorySlot = slot + 12
            local info = NS.GetTrinketStatus and NS.GetTrinketStatus(inventorySlot) or nil
            local label = (info and info.name) or ("Trinket " .. slot)
            local status = (info and info.status) or "Unavailable"
            local reason = (info and info.reason) or "No trinket information available."
            row.name:SetText(label)
            row.state:SetText(status)
            row.reason:SetText(reason)
            local canApprove = info and info.canApprove
            if canApprove then
                local approved = NS.IsTrinketApproved and NS.IsTrinketApproved(inventorySlot)
                row.allow:Show()
                row.allowLabel:Show()
                row.allow:SetBackdropColor(NS.unpack(approved and T.TOGGLE_ON or T.TOGGLE_OFF))
                row.allow:SetBackdropBorderColor(NS.unpack(approved and T.ACCENT_DIM or T.BORDER))
                row.allowFill:SetColorTexture(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3], 0.9)
                if approved then row.allowFill:Show() else row.allowFill:Hide() end
                row.allowLabel:SetTextColor(NS.unpack(approved and T.TEXT or T.TEXT_DIM))
            else
                row.allow:Hide()
                row.allowLabel:Hide()
            end
            if info and info.eligible then
                row.state:SetTextColor(NS.unpack(T.TOGGLE_ON))
                row.name:SetTextColor(NS.unpack(T.TEXT))
            else
                row.state:SetTextColor(NS.unpack(T.TEXT_MUTED))
                row.name:SetTextColor(NS.unpack(T.TEXT_DIM))
            end
            row.reason:SetTextColor(NS.unpack(T.TEXT_MUTED))
        end
    end
    for slot, row in NS.ipairs(trinketRows) do
        row.allow:SetScript("OnClick", function()
            if not (NS.SetTrinketApproved and NS.IsTrinketApproved) then return end
            local inventorySlot = slot + 12
            NS.SetTrinketApproved(inventorySlot, not NS.IsTrinketApproved(inventorySlot))
            if NS.RefreshTrinkets then NS.RefreshTrinkets() end
            if NS.RebuildMacroText then NS.RebuildMacroText() end
            NS.RefreshTrinketConfig()
            if RefreshMacroPreview then RefreshMacroPreview() end
        end)
    end
    NS.RefreshTrinketConfig()

    -- Sub-header: INTERCEPTION TYPE
    do
        local intHdr = CreateSubHeader(c, "INTERCEPTION TYPE", y)
        CreateDefaultBtn(c, intHdr, {"interceptionType"})
    end
    y = y - 18

    local intRow = NS.CreateDropdown(c, "Method", "interceptionType", NS.INTERCEPTION_TYPES, y, function(val)
        NS.OverrideSBAKeybind()
        NS.UpdateClickIntercept()
    end)
    NS.AddTooltip(intRow, "Interception Method", {
        "Choose how BetterSBA intercepts the " .. U .. "SBA" .. R .. " action:",
        " ",
        V .. "Keybind" .. R .. " — redirects your action bar keybind",
        "to fire BetterSBA's macro instead of the raw spell.",
        " ",
        V .. "Click" .. R .. " — places an invisible overlay on the",
        "SBA bar button so mouse clicks fire BetterSBA's macro.",
        "Works with " .. K .. "Blizzard" .. R .. ", " .. K .. "Bartender4" .. R .. ", " .. K .. "ElvUI" .. R .. ".",
        " ",
        V .. "Both" .. R .. " — activates both methods.",
    }, c)
    y = y - 44

    -- Sub-header: MACRO PREVIEW
    local annotBtn
    do
        local col = c._sectionColor or T.TEXT_DIM
        local hdr = c:CreateFontString(nil, "OVERLAY")
        hdr:SetFont(NS.GetConfigFontPath(), 11, "")
        hdr:SetPoint("TOPLEFT", c, "TOPLEFT", 14, y)
        hdr:SetTextColor(col[1], col[2], col[3])
        hdr:SetText("MACRO PREVIEW")
        local line = c:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetColorTexture(col[1], col[2], col[3], 0.4)
        line:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -3)
        line:SetPoint("RIGHT", c, "RIGHT", -14, 0)
        subHeaderLines[#subHeaderLines + 1] = line

        -- Annotation toggle button (far right of header line)
        annotBtn = NS.CreateFrame("Button", nil, c)
        annotBtn:SetSize(52, 12)
        annotBtn:SetPoint("RIGHT", c, "RIGHT", -14, 0)
        annotBtn:SetPoint("TOP", hdr, "TOP", 0, 1)
        annotBtn._lbl = annotBtn:CreateFontString(nil, "OVERLAY")
        annotBtn._lbl:SetFont(NS.GetConfigFontPath(), 7, "OUTLINE")
        annotBtn._lbl:SetPoint("CENTER")
        annotBtn._lbl:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
        annotBtn._lbl:SetText("SHOW HINTS")
    end
    y = y - 18

    -- Annotation description label (below ruler, hidden by default)
    local annotDesc = c:CreateFontString(nil, "OVERLAY")
    annotDesc:SetFont(NS.GetConfigFontPath(), 9, NS.GetConfigFontOutline())
    annotDesc:SetPoint("TOPLEFT", c, "TOPLEFT", 14, y)
    annotDesc:SetPoint("RIGHT", c, "RIGHT", -14, 0)
    annotDesc:SetJustifyH("LEFT")
    annotDesc:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
    annotDesc:SetText("Annotations shown in the Macro Preview are display-only and do not get injected into the actual SBA Button Presses.")
    annotDesc:Hide()
    local ANNOT_DESC_H = 24
    local showAnnotations = false

    -- Macro preview panel (dark code-style display with syntax highlighting)
    local previewPanel = NS.CreateFrame("Frame", nil, c, "BackdropTemplate")
    local previewW = contentW - 28
    local GUTTER_W = 22
    local previewBaseY = y
    previewPanel:SetPoint("TOPLEFT", c, "TOPLEFT", 14, previewBaseY)
    previewPanel:SetWidth(previewW)
    previewPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    local sc = c._sectionColor or T.ACCENT
    previewPanel:SetBackdropColor(0.02, 0.02, 0.03, 0.85)
    previewPanel:SetBackdropBorderColor(sc[1], sc[2], sc[3], 0.35)
    local sectionEndDivider = CreateSectionEndDivider(c, y)

    -- Gutter background (slightly lighter than code area)
    local gutterBG = previewPanel:CreateTexture(nil, "BACKGROUND", nil, 1)
    gutterBG:SetPoint("TOPLEFT", 1, -1)
    gutterBG:SetPoint("BOTTOMLEFT", 1, 1)
    gutterBG:SetWidth(GUTTER_W)
    gutterBG:SetColorTexture(0.06, 0.06, 0.08, 0.9)

    -- Gutter separator line
    local gutterLine = previewPanel:CreateTexture(nil, "ARTWORK")
    gutterLine:SetWidth(1)
    gutterLine:SetPoint("TOPLEFT", gutterBG, "TOPRIGHT", 0, 0)
    gutterLine:SetPoint("BOTTOMLEFT", gutterBG, "BOTTOMRIGHT", 0, 0)
    gutterLine:SetColorTexture(sc[1], sc[2], sc[3], 0.15)

    -- Syntax color codes
    local CMD  = "|cFFFFD100"   -- gold — slash commands
    local CMT  = "|cFF9AAABA"   -- readable secondary hints
    local RST  = "|r"
    local LINENUM_COLOR = "|cFF7A8896"

    -- The macro builder owns this list. Keep enough pooled rows for optional
    -- class actions and verified trinkets without allocating during refreshes.
    local MAX_PREVIEW = 12
    local PREVIEW_FONT_SIZE = 11
    local PREVIEW_LINE_H = 15
    local PREVIEW_TOP_PAD = 5
    local previewLineNums = {}
    local previewLines = {}
    for i = 1, MAX_PREVIEW do
        local num = previewPanel:CreateFontString(nil, "OVERLAY")
        num:SetFont(NS.GetConfigFontPath(), PREVIEW_FONT_SIZE, NS.GetConfigFontOutline())
        num:SetPoint("TOPRIGHT", previewPanel, "TOPLEFT", GUTTER_W - 4, -PREVIEW_TOP_PAD - (i - 1) * PREVIEW_LINE_H)
        num:SetJustifyH("RIGHT")
        num:SetText(LINENUM_COLOR .. i .. RST)
        num:Hide()
        previewLineNums[i] = num

        local fs = previewPanel:CreateFontString(nil, "OVERLAY")
        fs:SetFont(NS.GetConfigFontPath(), PREVIEW_FONT_SIZE, NS.GetConfigFontOutline())
        fs:SetPoint("TOPLEFT", previewPanel, "TOPLEFT", GUTTER_W + 6, -PREVIEW_TOP_PAD - (i - 1) * PREVIEW_LINE_H)
        fs:SetPoint("RIGHT", previewPanel, "RIGHT", -8, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:Hide()
        previewLines[i] = fs
    end

    local RefreshAnnotLayout
    RefreshMacroPreview = function()
        local idx = 0
        local actions = NS.GetMacroActions and NS.GetMacroActions() or {}

        for _, action in NS.ipairs(actions) do
            if idx >= MAX_PREVIEW then break end
            idx = idx + 1
            local text = CMD .. (action.text or "") .. RST
            if showAnnotations and action.hint and action.hint ~= "" then
                text = text .. "  " .. CMT .. "-- " .. action.hint .. RST
            end
            previewLines[idx]:SetText(text)
            previewLines[idx]:Show()
        end

        if idx == 0 then
            idx = 1
            previewLines[idx]:SetText(CMT .. "No macro actions are available." .. RST)
            previewLines[idx]:Show()
        end

        -- Hide unused lines
        for i = idx + 1, MAX_PREVIEW do
            previewLineNums[i]:Hide()
            previewLines[i]:Hide()
        end
        -- Show line numbers for visible lines
        local rowY = PREVIEW_TOP_PAD
        for i = 1, idx do
            previewLineNums[i]:SetText(LINENUM_COLOR .. i .. RST)
            previewLineNums[i]:Show()
            previewLineNums[i]:ClearAllPoints()
            previewLineNums[i]:SetPoint("TOPRIGHT", previewPanel, "TOPLEFT", GUTTER_W - 4, -rowY)
            local line = previewLines[i]
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", previewPanel, "TOPLEFT", GUTTER_W + 6, -rowY)
            line:SetPoint("RIGHT", previewPanel, "RIGHT", -8, 0)
            rowY = rowY + math.max(PREVIEW_LINE_H, (line:GetStringHeight() or PREVIEW_LINE_H) + 4)
        end

        -- Resize panel to fit
        previewPanel:SetHeight(rowY + 6)
        if RefreshAnnotLayout then RefreshAnnotLayout() end
    end

    RefreshAnnotLayout = function()
        local sc = c._sectionColor or T.ACCENT
        if showAnnotations then
            annotDesc:Show()
            previewPanel:ClearAllPoints()
            previewPanel:SetPoint("TOPLEFT", c, "TOPLEFT", 14, previewBaseY - ANNOT_DESC_H)
            annotBtn._lbl:SetTextColor(sc[1], sc[2], sc[3])
        else
            annotDesc:Hide()
            previewPanel:ClearAllPoints()
            previewPanel:SetPoint("TOPLEFT", c, "TOPLEFT", 14, previewBaseY)
            annotBtn._lbl:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
        end
        local extra = showAnnotations and ANNOT_DESC_H or 0
        local totalY = math.abs(previewBaseY) + extra + previewPanel:GetHeight() + 8
        PositionSectionEndDivider(sectionEndDivider, c, -totalY)
        totalY = totalY + 12
        c._contentH = totalY
        c:SetHeight(totalY)
    end

    annotBtn:SetScript("OnClick", function()
        showAnnotations = not showAnnotations
        annotBtn._lbl:SetText(showAnnotations and "HIDE HINTS" or "SHOW HINTS")
        RefreshMacroPreview()
        RefreshAnnotLayout()
    end)
    annotBtn:SetScript("OnEnter", function()
        local sc = c._sectionColorBright or T.ACCENT_BRIGHT
        annotBtn._lbl:SetTextColor(sc[1], sc[2], sc[3])
    end)
    annotBtn:SetScript("OnLeave", function()
        if showAnnotations then
            local sc = c._sectionColor or T.ACCENT
            annotBtn._lbl:SetTextColor(sc[1], sc[2], sc[3])
        else
            annotBtn._lbl:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
        end
    end)

    -- Hook toggles to refresh preview when clicked
    r1:HookScript("OnClick", RefreshMacroPreview)
    r2:HookScript("OnClick", RefreshMacroPreview)
    if r3 then r3:HookScript("OnClick", RefreshMacroPreview) end
    r4:HookScript("OnClick", RefreshMacroPreview)
    for _, toggle in NS.ipairs(classToggles) do
        toggle:HookScript("OnClick", RefreshMacroPreview)
    end

    RefreshMacroPreview()
    RefreshAnnotLayout()
    end -- do (Section 1)

    -- 2. APPEARANCE (Animation + Fonts)
    c = contentFrames[2]
    y = -6
    do
    local c, y = c, y -- Keep callbacks bound to this section.
    local motionHdr = CreateSubHeader(c, "MOTION FEEDBACK", y)
    CreateDefaultBtn(c, motionHdr, {
        "castFeedback", "motionPreset", "motionDuration", "motionIntensity", "motionReduced",
    })
    y = y - 18

    local motionDropW = contentW - 28 - 80 - 6
    local feedbackRow = NS.CreateOptionsDropdown(c, "Cast Feedback", "castFeedback",
        {"Motion", "Classic", "Off"}, y, function()
            if NS.RefreshCastFeedbackSettings then NS.RefreshCastFeedbackSettings() end
            rebuildPanel()
        end, motionDropW)
    NS.AddTooltip(feedbackRow, "Cast Feedback", {
        V .. "Motion" .. R .. " uses the new native effect layers.",
        V .. "Classic" .. R .. " keeps the existing animated clone system.",
        V .. "Off" .. R .. " disables cast feedback.",
    }, c)

    local motionPreview = NS.CreateFrame("Button", nil, c, "BackdropTemplate")
    motionPreview:SetSize(74, 20)
    motionPreview:SetPoint("TOPLEFT", feedbackRow, "TOPRIGHT", 6, -16)
    motionPreview:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    motionPreview:SetBackdropColor(NS.unpack(T.TOGGLE_OFF))
    motionPreview:SetBackdropBorderColor(NS.unpack(T.BORDER))
    local motionPreviewText = motionPreview:CreateFontString(nil, "OVERLAY")
    motionPreviewText:SetFont(NS.GetConfigFontPath(), 9, "OUTLINE")
    motionPreviewText:SetPoint("CENTER")
    motionPreviewText:SetTextColor(NS.unpack(T.TEXT))
    motionPreviewText:SetText(NS.GLYPH_PLAY .. " Preview")
    motionPreview:SetEnabled(NS.db.castFeedback ~= "Off")
    motionPreview:SetAlpha(NS.db.castFeedback == "Off" and 0.4 or 1)
    motionPreview:SetScript("OnClick", function()
        if NS.db.castFeedback == "Classic" then
            NS.PlayCastAnimation(NS.mainButton and NS.mainButton.spellID or NS.SBA_SPELL_ID)
        elseif NS.db.castFeedback == "Motion" and NS.PreviewMotionFeedback then
            NS.PreviewMotionFeedback()
        end
    end)
    motionPreview:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(NS.unpack(T.ACCENT_DIM)) end)
    motionPreview:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(NS.unpack(T.BORDER)) end)
    y = y - 46

    if NS.db.castFeedback == "Motion" then
        local presetRow = NS.CreateOptionsDropdown(c, "Motion Preset", "motionPreset",
            {"Pulse", "Echo", "Sweep"}, y, function()
                if NS.RefreshCastFeedbackSettings then NS.RefreshCastFeedbackSettings() end
            end)
        NS.AddTooltip(presetRow, "Motion Preset", {
            "Select the effect layer shown when SBA casts.",
        }, c)
        y = y - 46

        local durationRow = NS.CreateSlider(c, "Motion Duration", "motionDuration", 0.2, 0.8, 0.05, y, function()
            if NS.RefreshCastFeedbackSettings then NS.RefreshCastFeedbackSettings() end
        end)
        NS.AddTooltip(durationRow, "Motion Duration", {
            "Controls how long the motion feedback lasts.",
        }, c)
        y = y - 38

        local intensityRow = NS.CreateSlider(c, "Motion Intensity", "motionIntensity", 0.2, 1.0, 0.05, y, function()
            if NS.RefreshCastFeedbackSettings then NS.RefreshCastFeedbackSettings() end
        end)
        NS.AddTooltip(intensityRow, "Motion Intensity", {
            "Controls the reach and opacity of the motion layers.",
        }, c)
        y = y - 38

        local reducedRow = NS.CreateToggle(c, "Reduced Motion", "motionReduced", y, function()
            if NS.RefreshCastFeedbackSettings then NS.RefreshCastFeedbackSettings() end
        end)
        NS.AddTooltip(reducedRow, "Reduced Motion", {
            "Uses the smallest possible cast feedback movement.",
        }, c)
        y = y - 32
    end

    if NS.db.castFeedback == "Classic" then
    local classicHdr = CreateSubHeader(c, "CLASSIC ANIMATION", y)
    CreateDefaultBtn(c, classicHdr, {"castAnimation", "animateIncoming", "animHideButton", "cfgAnimTransitions", "gcdDuration"})
    y = y - 18

    local ScheduleParticleRebuild
    local animDropW = contentW - 28 - 80 - 6
    local animRow = NS.CreateOptionsDropdown(c, "Cast Animation", "castAnimation", NS.CAST_ANIMATIONS, y, function()
        if ScheduleParticleRebuild then ScheduleParticleRebuild() end
    end, animDropW)
    NS.AddTooltip(animRow, "Cast Animation", {
        "Visual effect that plays on the " .. U .. "Active Display" .. R,
        "each time " .. U .. "SBA" .. R .. " casts an ability.",
        " ",
        "Choose from different animation styles or",
        "set to " .. V .. "None" .. R .. " to disable.",
    }, c)

    -- Preview button (inline with dropdown)
    local testBtn = NS.CreateFrame("Button", nil, c, "BackdropTemplate")
    testBtn:SetSize(56, 20)
    testBtn:SetPoint("TOPLEFT", animRow, "TOPRIGHT", 6, -16)
    testBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    testBtn:SetBackdropColor(NS.unpack(T.TOGGLE_OFF))
    testBtn:SetBackdropBorderColor(NS.unpack(T.BORDER))

    local testLbl = c:CreateFontString(nil, "OVERLAY")
    testLbl:SetFont(NS.GetConfigFontPath(), 9, "OUTLINE")
    testLbl:SetPoint("BOTTOMLEFT", testBtn, "TOPLEFT", 0, 2)
    testLbl:SetTextColor(NS.unpack(T.TEXT_DIM))
    testLbl:SetText("Preview")

    local testBtnText = testBtn:CreateFontString(nil, "OVERLAY")
    testBtnText:SetFont(NS.NERD_FONT, 10, "OUTLINE")
    testBtnText:SetPoint("CENTER")
    testBtnText:SetTextColor(NS.unpack(T.TEXT))
    testBtnText:SetText(NS.GLYPH_PLAY .. " Preview")
    testBtn:SetScript("OnClick", function()
        NS.PlayCastAnimation(NS.mainButton and NS.mainButton.spellID or NS.SBA_SPELL_ID)
    end)
    testBtn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(NS.unpack(T.ACCENT_DIM)) end)
    testBtn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(NS.unpack(T.BORDER)) end)

    y = y - 46

    local animIncoming = NS.CreateToggle(c, "Incoming Animation", "animateIncoming", y)
    NS.AddTooltip(animIncoming, "Incoming Animation", {
        "When " .. V .. "enabled" .. R .. ", the " .. U .. "new spell" .. R .. " animates",
        "into position from the " .. V .. "opposite direction" .. R .. " of",
        "the outgoing cast animation.",
        " ",
        "When " .. W .. "disabled" .. R .. ", the new spell simply",
        "fades back in after the outgoing animation.",
    }, c)
    y = y - 28

    local animHide = NS.CreateToggle(c, "Hide Button During Animation", "animHideButton", y)
    NS.AddTooltip(animHide, "Hide Button During Animation", {
        "When " .. V .. "enabled" .. R .. ", the real button is " .. W .. "hidden" .. R,
        "while the animation clone plays.",
        " ",
        "When " .. W .. "disabled" .. R .. ", the button stays " .. V .. "visible" .. R,
        "underneath the animation.",
    }, c)
    y = y - 28

    y = y - 32

    local gcdSlider = NS.CreateSlider(c, "GCD Duration", "gcdDuration", 0.5, 3.0, 0.1, y)
    NS.AddTooltip(gcdSlider, "GCD Duration", {
        "The " .. V .. "effective GCD" .. R .. " length in seconds that",
        "all animation and particle timings scale to.",
        " ",
        U .. "SBA" .. R .. " has a " .. W .. "25% GCD penalty" .. R .. ", so the",
        "default " .. V .. "1.9s" .. R .. " \226\137\136 1.5s base + 25% penalty.",
        " ",
        "Lower values = " .. V .. "faster" .. R .. " animations.",
        "Higher values = " .. W .. "slower" .. R .. " animations.",
    }, c)
    y = y - 28

    local animDesc = c:CreateFontString(nil, "OVERLAY")
    animDesc:SetFont(NS.GetConfigFontPath(), 9, NS.GetConfigFontOutline())
    animDesc:SetPoint("TOPLEFT", c, "TOPLEFT", 14, y)
    animDesc:SetPoint("RIGHT", c, "RIGHT", -14, 0)
    animDesc:SetJustifyH("LEFT")
    animDesc:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
    animDesc:SetText("Toggle individual config panel animations on or off.")
    y = y - 16
    local cosmeticNote = N .. "Purely cosmetic" .. R .. ". " .. V .. "Safe" .. R .. " to " .. W .. "disable" .. R .. " \226\128\148 just " .. U .. "visual noise" .. R .. "."
    local aSlide = NS.CreateToggle(c, "Slide Transitions", "cfgAnimTransitions", y)
    NS.AddTooltip(aSlide, "Slide Transitions", {
        "Slide the active tab indicator when switching sections.",
        "Settings appear immediately.",
        " ",
        cosmeticNote,
    }, c)
    y = y - 28

    -- Sub-header: PARTICLES
    do
        local col = c._sectionColor or T.TEXT_DIM
        local hdr = c:CreateFontString(nil, "OVERLAY")
        hdr:SetFont(NS.GetConfigFontPath(), 11, "")
        hdr:SetPoint("TOPLEFT", c, "TOPLEFT", 14, y)
        hdr:SetTextColor(col[1], col[2], col[3])
        hdr:SetText("PARTICLES")
        local line = c:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetColorTexture(col[1], col[2], col[3], 0.4)
        line:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -3)
        line:SetPoint("RIGHT", c, "RIGHT", -14, 0)
        subHeaderLines[#subHeaderLines + 1] = line
        local pKeys = {}
        for _, a in NS.ipairs(NS.CAST_ANIMATIONS) do
            if a ~= "NONE" then
                local k = NS.AnimKeyPrefix(a)
                pKeys[#pKeys + 1] = k .. "Particles"
                pKeys[#pKeys + 1] = k .. "ParticleTiming"
                pKeys[#pKeys + 1] = k .. "ParticleStyle"
                pKeys[#pKeys + 1] = k .. "ParticlePalette"
            end
        end
        CreateDefaultBtn(c, hdr, pKeys)
    end
    y = y - 18

    -- Particle settings for the currently selected cast animation
    local particleNote = c:CreateFontString(nil, "OVERLAY")
    particleNote:SetFont(NS.GetConfigFontPath(), 9, NS.GetConfigFontOutline())
    particleNote:SetPoint("TOPLEFT", c, "TOPLEFT", 14, y)
    particleNote:SetPoint("RIGHT", c, "RIGHT", -14, 0)
    particleNote:SetJustifyH("LEFT")
    particleNote:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
    particleNote:SetText("Settings for the selected Cast Animation above.")
    y = y - 16

    -- Dynamic particle controls container (rebuilt when animation dropdown changes)
    local particleContainer = NS.CreateFrame("Frame", nil, c)
    particleContainer:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
    particleContainer:SetPoint("RIGHT", c, "RIGHT", 0, 0)
    particleContainer._contentWidth = contentW
    particleContainer._sectionColor = c._sectionColor
    particleContainer._sectionColorBright = c._sectionColorBright
    particleContainer._sectionColorDim = c._sectionColorDim

    local particleWidgets = {}
    local particleContainerH = 0

    local function BuildParticleControls()
        -- Clear existing widgets
        for _, w in NS.ipairs(particleWidgets) do
            if w.Hide then w:Hide() end
        end
        wipe(particleWidgets)

        local anim = NS.db.castAnimation or "NONE"
        if anim == "NONE" then
            particleContainer:SetHeight(20)
            particleContainerH = 20
            local noAnimText = particleContainer:CreateFontString(nil, "OVERLAY")
            noAnimText:SetFont(NS.GetConfigFontPath(), 10, NS.GetConfigFontOutline())
            noAnimText:SetPoint("TOPLEFT", 14, -4)
            noAnimText:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
            noAnimText:SetText("No animation selected.")
            particleWidgets[#particleWidgets + 1] = noAnimText
            return
        end

        local animKey = NS.AnimKeyPrefix(anim)
        local py = -4
        local previewW = 56
        local defaultW = 56
        local gap = 6
        local pStyle  -- forward declare for default button OnClick

        -- Row 1: [Enable Particles] [▶ Play] [DEFAULT]
        local pToggle = NS.CreateToggle(particleContainer, "Enable Particles", animKey .. "Particles", py)
        NS.AddTooltip(pToggle, "Enable Particles", {
            "Show particle effects when " .. U .. anim .. R .. " animation plays.",
        }, particleContainer)
        particleWidgets[#particleWidgets + 1] = pToggle

        -- Preview button (inline with toggle, same row)
        local ptestBtn = NS.CreateFrame("Button", nil, particleContainer, "BackdropTemplate")
        ptestBtn:SetSize(previewW, 20)
        ptestBtn:SetPoint("TOPRIGHT", particleContainer, "TOPRIGHT", -(defaultW + gap + 10), py - 1)
        ptestBtn:SetFrameLevel(pToggle:GetFrameLevel() + 10)
        ptestBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        ptestBtn:SetBackdropColor(NS.unpack(T.TOGGLE_OFF))
        ptestBtn:SetBackdropBorderColor(NS.unpack(T.BORDER))

        local ptestBtnText = ptestBtn:CreateFontString(nil, "OVERLAY")
        ptestBtnText:SetFont(NS.NERD_FONT, 10, "OUTLINE")
        ptestBtnText:SetPoint("CENTER")
        ptestBtnText:SetTextColor(NS.unpack(T.TEXT))
        ptestBtnText:SetText(NS.GLYPH_PLAY .. " Preview")

        ptestBtn:SetScript("OnClick", function()
            local style = NS.db[animKey .. "ParticleStyle"] or "Confetti"
            local palette = NS.db[animKey .. "ParticlePalette"] or "Confetti"
            if NS.mainButton and style ~= "None" then
                NS.FireParticleBurst(NS.mainButton, style, palette)
            end
        end)
        ptestBtn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(NS.unpack(T.ACCENT_DIM)) end)
        ptestBtn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(NS.unpack(T.BORDER)) end)
        particleWidgets[#particleWidgets + 1] = ptestBtn

        py = py - 26

        -- Row 2: [Style] [Timing] [Palette] — three dropdowns in a row
        local thirdW = math.floor((contentW - 28 - 12) / 3)

        local pTiming  -- forward declare for style onChange
        local pPalette -- forward declare for style onChange

        pStyle = NS.CreateOptionsDropdown(particleContainer, "Style", animKey .. "ParticleStyle",
            NS.PARTICLE_STYLES, py, function(val)
                local styleDefs = NS.PARTICLE_STYLE_DEFAULTS[val]
                if styleDefs then
                    NS.db[animKey .. "ParticleTiming"] = styleDefs.timing
                    NS.db[animKey .. "ParticlePalette"] = styleDefs.palette
                    if pTiming and pTiming.Refresh then pTiming:Refresh() end
                    if pPalette and pPalette.Refresh then pPalette:Refresh() end
                end
            end, thirdW)
        NS.AddTooltip(pStyle, "Particle Style", {
            "Visual style of the particles.",
            " ",
            "Selecting a style auto-sets " .. V .. "Timing" .. R .. " and",
            V .. "Palette" .. R .. " to that style's defaults.",
            " ",
            V .. "None" .. R .. " — no particles",
            V .. "Confetti" .. R .. " — colored rectangular shards",
            V .. "Lasers" .. R .. " — thin radial streaks",
            V .. "Sparks" .. R .. " — tiny fast dots",
            V .. "Squares" .. R .. " — diamond shapes, gentle drift",
        }, particleContainer)
        particleWidgets[#particleWidgets + 1] = pStyle

        pTiming = NS.CreateTimingDropdown(particleContainer, "Timing", animKey .. "ParticleTiming",
            animKey .. "ParticleDelay", py, nil, thirdW)
        pTiming:ClearAllPoints()
        pTiming:SetPoint("TOPLEFT", pStyle, "TOPRIGHT", 6, 0)
        NS.AddTooltip(pTiming, "Particle Timing", {
            "When particles fire relative to the cast animation.",
            " ",
            V .. "On Cast" .. R .. " — at animation start",
            V .. "On Animation End" .. R .. " — when outgoing animation finishes",
            V .. "Both" .. R .. " — fires at both moments",
            V .. "Specific" .. R .. " — fires after the delay you type (seconds)",
        }, particleContainer)
        particleWidgets[#particleWidgets + 1] = pTiming

        pPalette = NS.CreatePaletteDropdown(particleContainer, "Color Palette", animKey .. "ParticlePalette",
            py, nil, thirdW)
        pPalette:ClearAllPoints()
        pPalette:SetPoint("TOPLEFT", pTiming, "TOPRIGHT", 6, 0)
        NS.AddTooltip(pPalette, "Color Palette", {
            "Color palette used for the particles.",
            "Choose from built-in presets or create custom palettes.",
        }, particleContainer)
        particleWidgets[#particleWidgets + 1] = pPalette
        py = py - 46

        -- Row 3: Palette management — PALETTES  CREATE  EDIT (left-aligned)
        local palMgmtLabel = particleContainer:CreateFontString(nil, "OVERLAY")
        palMgmtLabel:SetFont(NS.GetConfigFontPath(), 8, "OUTLINE")
        palMgmtLabel:SetPoint("TOPLEFT", particleContainer, "TOPLEFT", 14, py)
        palMgmtLabel:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
        palMgmtLabel:SetText("PALETTES")
        particleWidgets[#particleWidgets + 1] = palMgmtLabel

        local function MakePaletteTextBtn(text, anchorFrame, anchorPoint, xOff)
            local btn = NS.CreateFrame("Button", nil, particleContainer)
            btn:SetHeight(14)
            btn:SetFrameLevel(pToggle:GetFrameLevel() + 5)

            local txt = btn:CreateFontString(nil, "OVERLAY")
            txt:SetFont(NS.GetConfigFontPath(), 8, "OUTLINE")
            txt:SetPoint("LEFT")
            txt:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
            txt:SetText(text)
            -- Size button to fit the text
            txt:SetJustifyH("LEFT")
            btn:SetWidth(txt:GetStringWidth() + 4)
            btn:SetPoint("LEFT", anchorFrame, anchorPoint, xOff, 0)

            btn:SetScript("OnEnter", function()
                txt:SetTextColor(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3])
            end)
            btn:SetScript("OnLeave", function()
                txt:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
            end)
            btn._txt = txt
            return btn
        end

        local createBtn = MakePaletteTextBtn("CREATE", palMgmtLabel, "RIGHT", 6)
        createBtn:SetScript("OnClick", function()
            createBtn._txt:SetTextColor(1, 1, 1)
            NS.C_Timer_After(0.15, function()
                createBtn._txt:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
            end)
            NS.ShowPaletteEditor(f, animKey .. "ParticlePalette", function()
                if pPalette.Refresh then pPalette:Refresh() end
            end, true)  -- createMode = true
        end)
        NS.AddTooltip(createBtn, "Create Palette", {
            "Open the palette editor with a " .. V .. "blank palette" .. R .. ".",
            "Name it, pick colors, and save.",
        }, particleContainer)
        particleWidgets[#particleWidgets + 1] = createBtn

        local editBtn = MakePaletteTextBtn("EDIT", createBtn, "RIGHT", 6)
        editBtn:SetScript("OnClick", function()
            editBtn._txt:SetTextColor(1, 1, 1)
            NS.C_Timer_After(0.15, function()
                editBtn._txt:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
            end)
            NS.ShowPaletteEditor(f, animKey .. "ParticlePalette", function()
                if pPalette.Refresh then pPalette:Refresh() end
            end)
        end)
        NS.AddTooltip(editBtn, "Edit Palette", {
            "Open the palette editor with the " .. V .. "currently selected" .. R,
            "palette loaded for editing.",
        }, particleContainer)
        particleWidgets[#particleWidgets + 1] = editBtn
        py = py - 18

        particleContainerH = math.abs(py)
        particleContainer:SetHeight(particleContainerH)
    end

    BuildParticleControls()
    -- Track total height for particle section
    y = y - particleContainerH - 4

    -- Rebuild particle controls when animation dropdown changes
    -- Particle controls have different heights. Rebuild the layout once so
    -- every following font section moves too, preserving the visible gutter.
    local particleRebuildTimer = nil
    ScheduleParticleRebuild = function()
        if particleRebuildTimer then return end
        particleRebuildTimer = true
        NS.C_Timer_After(0.1, function()
            particleRebuildTimer = nil
            rebuildPanel()
        end)
    end
    end -- Classic feedback controls

    -- Sub-header: FONTS
    do
        local col = c._sectionColor or T.TEXT_DIM
        local hdr = c:CreateFontString(nil, "OVERLAY")
        hdr:SetFont(NS.GetConfigFontPath(), 11, "")
        hdr:SetPoint("TOPLEFT", c, "TOPLEFT", 14, y)
        hdr:SetTextColor(col[1], col[2], col[3])
        hdr:SetText("FONTS")
        local line = c:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetColorTexture(col[1], col[2], col[3], 0.4)
        line:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -3)
        line:SetPoint("RIGHT", c, "RIGHT", -14, 0)
        subHeaderLines[#subHeaderLines + 1] = line
        CreateDefaultBtn(c, hdr, {
            "fontFace", "fontOutline",
            "configPanelFont", "configPanelOutline", "configPanelFontOverride",
            "keybindFont", "keybindOutline", "keybindFontOverride", "keybindFontSize",
            "priorityKeybindFont", "priorityKeybindOutline", "priorityKeybindFontOverride", "priorityKeybindFontSize",
            "priorityLabelFont", "priorityLabelOutline", "priorityLabelFontOverride", "priorityLabelFontSize",
            "pauseSymbolFont", "pauseSymbolOutline", "pauseSymbolFontOverride", "pauseSymbolFontSize",
            "pauseReasonFont", "pauseReasonOutline", "pauseReasonFontOverride", "pauseReasonFontSize",
        })
    end
    y = y - 18

    local fontContentW = contentW - 28
    -- 2-column layout (font + outline, no size) — with checkbox indent
    local cbIndent = 16
    local fontW2 = math.floor((fontContentW - cbIndent) * 0.6)
    local outlineW2 = (fontContentW - cbIndent) - fontW2 - 6
    -- Full-width 2-column for Global (no checkbox)
    local fontW2g = math.floor(fontContentW * 0.6)
    local outlineW2g = fontContentW - fontW2g - 6
    -- 3-column layout (font + outline + size) — with checkbox indent
    local fontW3 = math.floor((fontContentW - cbIndent) * 0.40)
    local outlineW3 = math.floor((fontContentW - cbIndent) * 0.28)
    local sizeW3 = (fontContentW - cbIndent) - fontW3 - outlineW3 - 12

    -- Override checkbox: small themed toggle before the font row label
    local OVR_BACKDROP = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    }
    local function CreateOverrideCheckbox(fontRow, outlineRow, sizeRow, overrideKey, onChange)
        local cbSize = 10
        -- Shift font row label right
        fontRow.lbl:ClearAllPoints()
        fontRow.lbl:SetPoint("TOPLEFT", cbIndent, 0)
        -- Also shift the dropdown button right
        fontRow.btn:ClearAllPoints()
        fontRow.btn:SetPoint("TOPLEFT", cbIndent, -16)
        fontRow.btn:SetWidth(fontRow:GetWidth() - cbIndent)
        -- Checkbox
        local cb = NS.CreateFrame("Button", nil, fontRow, "BackdropTemplate")
        cb:SetSize(cbSize, cbSize)
        cb:SetPoint("RIGHT", fontRow.lbl, "LEFT", -4, 0)
        cb:SetBackdrop(OVR_BACKDROP)
        local fill = cb:CreateTexture(nil, "ARTWORK")
        fill:SetPoint("TOPLEFT", 2, -2)
        fill:SetPoint("BOTTOMRIGHT", -2, 2)
        local function RefreshOverride()
            local on = NS.db[overrideKey]
            if on then
                local sc = c._sectionColor or T.TOGGLE_ON
                cb:SetBackdropColor(sc[1], sc[2], sc[3], sc[4] or 1)
                cb:SetBackdropBorderColor(sc[1], sc[2], sc[3], 0.6)
                fill:SetColorTexture(sc[1], sc[2], sc[3], 0.9)
                fill:Show()
                fontRow.btn:SetAlpha(1)
                outlineRow:SetAlpha(1)
            else
                cb:SetBackdropColor(NS.unpack(T.TOGGLE_OFF))
                cb:SetBackdropBorderColor(NS.unpack(T.BORDER))
                fill:Hide()
                fontRow.btn:SetAlpha(0.3)
                outlineRow:SetAlpha(0.3)
            end
        end
        cb:SetScript("OnClick", function()
            NS.db[overrideKey] = not NS.db[overrideKey]
            RefreshOverride()
            if onChange then onChange() end
        end)
        -- Tooltip
        NS.AddTooltip(cb, "Override Global", {
            "When " .. V .. "enabled" .. R .. ", this context uses its own",
            "font and outline settings below.",
            " ",
            "When " .. W .. "disabled" .. R .. ", it inherits from the",
            K .. "Global" .. R .. " font and outline above.",
        }, c)
        RefreshOverride()
        return cb
    end

    -- Row 1: Global (Font + Outline) — master, no checkbox
    local gFontRow = NS.CreateFontDropdown(c, "Global", "fontFace", y, ApplyFont, fontW2g)
    NS.AddTooltip(gFontRow, "Global Font", {
        "Master font used across all BetterSBA elements.",
        " ",
        "Applies everywhere unless a context below has its",
        "override checkbox " .. V .. "enabled" .. R .. ".",
    }, c)
    local gOutRow = NS.CreateDropdown(c, "Outline", "fontOutline",
        NS.FONT_OUTLINE_OPTIONS, y, ApplyFont, outlineW2g)
    gOutRow:ClearAllPoints()
    gOutRow:SetPoint("TOPLEFT", gFontRow, "TOPRIGHT", 6, 0)
    y = y - 46

    -- Row 2: Config Panel (Font + Outline + override checkbox)
    local cpFontRow = NS.CreateFontDropdown(c, "Config Panel", "configPanelFont", y, NS.UpdateAllConfigFonts, fontW2)
    NS.AddTooltip(cpFontRow, "Config Panel Font", {
        "Font used for all text in the " .. U .. "Config Panel" .. R .. " (" .. K .. "/bs" .. R .. ").",
        " ",
        "Updates " .. V .. "instantly" .. R .. " across all panel labels,",
        "values, dropdowns, and headers.",
    }, c)
    local cpOutRow = NS.CreateDropdown(c, "Config Outline", "configPanelOutline",
        NS.FONT_OUTLINE_OPTIONS, y, NS.UpdateAllConfigFonts, outlineW2)
    cpOutRow:ClearAllPoints()
    cpOutRow:SetPoint("TOPLEFT", cpFontRow, "TOPRIGHT", 6, 0)
    CreateOverrideCheckbox(cpFontRow, cpOutRow, nil, "configPanelFontOverride", NS.UpdateAllConfigFonts)
    y = y - 46

    -- Row 3: Keybind (Font + Outline + Size + override checkbox)
    local kbFontRow = NS.CreateFontDropdown(c, "Keybind", "keybindFont", y, ApplyFont, fontW3)
    NS.AddTooltip(kbFontRow, "Keybind Font", {
        "Font for the keybind text on the " .. U .. "Active Display" .. R .. ".",
        " ",
        "Shown in the top-right corner of the main button.",
        "Size: " .. N .. "6" .. R .. " to " .. N .. "24" .. R .. " px.",
    }, c)
    local kbOutRow = NS.CreateDropdown(c, "Outline", "keybindOutline",
        NS.FONT_OUTLINE_OPTIONS, y, ApplyFont, outlineW3)
    kbOutRow:ClearAllPoints()
    kbOutRow:SetPoint("TOPLEFT", kbFontRow, "TOPRIGHT", 6, 0)
    local kbSizeRow = NS.CreateSlider(c, "Size", "keybindFontSize", 6, 24, 1, y, function()
        NS.ApplyButtonSettings()
    end)
    kbSizeRow:SetSize(sizeW3, 32)
    kbSizeRow:ClearAllPoints()
    kbSizeRow:SetPoint("TOPLEFT", kbOutRow, "TOPRIGHT", 6, 0)
    CreateOverrideCheckbox(kbFontRow, kbOutRow, nil, "keybindFontOverride", ApplyFont)
    y = y - 46

    -- Row 4: Priority Keybind (Font + Outline + Size + override checkbox)
    local qkFontRow = NS.CreateFontDropdown(c, "Priority Keybind", "priorityKeybindFont", y, function()
        if NS.ApplyPriorityFonts then NS.ApplyPriorityFonts() end
    end, fontW3)
    NS.AddTooltip(qkFontRow, "Priority Keybind Font", {
        "Font for keybind text on " .. U .. "Priority Display" .. R .. " spell icons.",
        " ",
        "Each icon in the priority display shows its keybind.",
        "Size: " .. N .. "6" .. R .. " to " .. N .. "16" .. R .. " px.",
    }, c)
    local qkOutRow = NS.CreateDropdown(c, "Outline", "priorityKeybindOutline",
        NS.FONT_OUTLINE_OPTIONS, y, function()
        if NS.ApplyPriorityFonts then NS.ApplyPriorityFonts() end
    end, outlineW3)
    qkOutRow:ClearAllPoints()
    qkOutRow:SetPoint("TOPLEFT", qkFontRow, "TOPRIGHT", 6, 0)
    local qkSizeRow = NS.CreateSlider(c, "Size", "priorityKeybindFontSize", 6, 16, 1, y, function()
        if NS.ApplyPriorityFonts then NS.ApplyPriorityFonts() end
    end)
    qkSizeRow:SetSize(sizeW3, 32)
    qkSizeRow:ClearAllPoints()
    qkSizeRow:SetPoint("TOPLEFT", qkOutRow, "TOPRIGHT", 6, 0)
    CreateOverrideCheckbox(qkFontRow, qkOutRow, nil, "priorityKeybindFontOverride", function()
        if NS.ApplyPriorityFonts then NS.ApplyPriorityFonts() end
    end)
    y = y - 46

    -- Row 5: Priority Label (Font + Outline + Size + override checkbox)
    local qlFontRow = NS.CreateFontDropdown(c, "Priority Label", "priorityLabelFont", y, function()
        if NS.ApplyPriorityFonts then NS.ApplyPriorityFonts() end
    end, fontW3)
    NS.AddTooltip(qlFontRow, "Priority Label Font", {
        "Font for the " .. V .. "Priority" .. R .. " label text above",
        "the " .. U .. "Priority Display" .. R .. ".",
        " ",
        "Size: " .. N .. "6" .. R .. " to " .. N .. "18" .. R .. " px.",
    }, c)
    local qlOutRow = NS.CreateDropdown(c, "Outline", "priorityLabelOutline",
        NS.FONT_OUTLINE_OPTIONS, y, function()
        if NS.ApplyPriorityFonts then NS.ApplyPriorityFonts() end
    end, outlineW3)
    qlOutRow:ClearAllPoints()
    qlOutRow:SetPoint("TOPLEFT", qlFontRow, "TOPRIGHT", 6, 0)
    local qlSizeRow = NS.CreateSlider(c, "Size", "priorityLabelFontSize", 6, 18, 1, y, function()
        if NS.ApplyPriorityFonts then NS.ApplyPriorityFonts() end
    end)
    qlSizeRow:SetSize(sizeW3, 32)
    qlSizeRow:ClearAllPoints()
    qlSizeRow:SetPoint("TOPLEFT", qlOutRow, "TOPRIGHT", 6, 0)
    CreateOverrideCheckbox(qlFontRow, qlOutRow, nil, "priorityLabelFontOverride", function()
        if NS.ApplyPriorityFonts then NS.ApplyPriorityFonts() end
    end)
    y = y - 46

    -- Row 6: Pause Symbol (Font + Outline + Size + override checkbox)
    local psFontRow = NS.CreateFontDropdown(c, "Pause Symbol", "pauseSymbolFont", y, function()
        NS.ApplyButtonSettings()
    end, fontW3)
    NS.AddTooltip(psFontRow, "Pause Symbol Font", {
        "Font for the " .. V .. "II" .. R .. " pause symbol shown on",
        "the " .. U .. "Active Display" .. R .. " when paused.",
        " ",
        "Size: " .. N .. "8" .. R .. " to " .. N .. "28" .. R .. " px.",
    }, c)
    local psOutRow = NS.CreateDropdown(c, "Outline", "pauseSymbolOutline",
        NS.FONT_OUTLINE_OPTIONS, y, function()
        NS.ApplyButtonSettings()
    end, outlineW3)
    psOutRow:ClearAllPoints()
    psOutRow:SetPoint("TOPLEFT", psFontRow, "TOPRIGHT", 6, 0)
    local psSizeRow = NS.CreateSlider(c, "Size", "pauseSymbolFontSize", 8, 28, 1, y, function()
        NS.ApplyButtonSettings()
    end)
    psSizeRow:SetSize(sizeW3, 32)
    psSizeRow:ClearAllPoints()
    psSizeRow:SetPoint("TOPLEFT", psOutRow, "TOPRIGHT", 6, 0)
    CreateOverrideCheckbox(psFontRow, psOutRow, nil, "pauseSymbolFontOverride", function()
        NS.ApplyButtonSettings()
    end)
    y = y - 46

    -- Row 7: Pause Reason (Font + Outline + Size + override checkbox)
    local prFontRow = NS.CreateFontDropdown(c, "Pause Reason", "pauseReasonFont", y, function()
        NS.ApplyButtonSettings()
    end, fontW3)
    NS.AddTooltip(prFontRow, "Pause Reason Font", {
        "Font for the pause " .. V .. "reason text" .. R .. " shown below",
        "the button (e.g. " .. U .. "SKYRIDING" .. R .. ", " .. U .. "MOUNTED" .. R .. ").",
        " ",
        "Size: " .. N .. "6" .. R .. " to " .. N .. "14" .. R .. " px.",
    }, c)
    local prOutRow = NS.CreateDropdown(c, "Outline", "pauseReasonOutline",
        NS.FONT_OUTLINE_OPTIONS, y, function()
        NS.ApplyButtonSettings()
    end, outlineW3)
    prOutRow:ClearAllPoints()
    prOutRow:SetPoint("TOPLEFT", prFontRow, "TOPRIGHT", 6, 0)
    local prSizeRow = NS.CreateSlider(c, "Size", "pauseReasonFontSize", 6, 14, 1, y, function()
        NS.ApplyButtonSettings()
    end)
    prSizeRow:SetSize(sizeW3, 32)
    prSizeRow:ClearAllPoints()
    prSizeRow:SetPoint("TOPLEFT", prOutRow, "TOPRIGHT", 6, 0)
    CreateOverrideCheckbox(prFontRow, prOutRow, nil, "pauseReasonFontOverride", function()
        NS.ApplyButtonSettings()
    end)
    y = y - 38
    CreateSectionEndDivider(c, y)
    y = y - 12
    c._contentH = math.abs(y)
    c:SetHeight(c._contentH)
    end -- do (Section 2)

    -- 3. ACTIVE ABILITY (5 options)
    c = contentFrames[3]
    y = -6
    do
    local c, y = c, y -- Keep callbacks bound to this section.
    local styleHdr = CreateSubHeader(c, "BUTTON STYLE", y)
    CreateDefaultBtn(c, styleHdr, {"buttonStyle"})
    y = y - 18
    local styleRow = NS.CreateOptionsDropdown(c, "Button Style", "buttonStyle", {"Soft", "Classic"}, y, function()
        NS.ApplyButtonSettings()
    end)
    NS.AddTooltip(styleRow, "Button Style", {
        V .. "Soft" .. R .. " uses BetterSBA's native rounded treatment.",
        V .. "Classic" .. R .. "keeps the prior button and Masque appearance.",
    }, c)
    y = y - 46

    local btnHdr = CreateSubHeader(c, "BUTTON LAYOUT", y)
    CreateDefaultBtn(c, btnHdr, {
        "buttonSize", "scale", "showKeybind", "showCooldown", "manualCooldownReminders", "rangeColoring",
        "outOfRangeSound", "spellUsability", "keybindFontSize",
        "keybindOffsetX", "keybindOffsetY", "keybindAnchor",
    })
    y = y - 18
    local halfW3 = math.floor((contentW - 28 - 6) / 2)
    local btnSzRow = NS.CreateSlider(c, "Button Size", "buttonSize", 24, 80, 1, y, function()
        NS.ApplyButtonSettings()
        NS.LayoutPriority()
    end)
    btnSzRow:SetSize(halfW3, 32)
    NS.AddTooltip(btnSzRow, "Button Size", {
        "Pixel size of the " .. U .. "Active Display" .. R .. " button.",
        " ",
        "Range: " .. N .. "24" .. R .. " to " .. N .. "80" .. R .. " pixels.",
        "The " .. U .. "Priority Display" .. R .. " repositions to match.",
    }, c)
    local scaleRow = NS.CreateSlider(c, "Scale", "scale", 0.5, 2.0, 0.05, y, function()
        NS.ApplyButtonSettings()
    end)
    scaleRow:SetSize(halfW3, 32)
    scaleRow:ClearAllPoints()
    scaleRow:SetPoint("TOPLEFT", btnSzRow, "TOPRIGHT", 6, 0)
    NS.AddTooltip(scaleRow, "Button Scale", {
        "Overall scale of the " .. U .. "Active Display" .. R .. " button.",
        " ",
        "Range: " .. N .. "0.5x" .. R .. " to " .. N .. "2.0x" .. R .. ".",
        "Also adjustable via " .. K .. "Ctrl+MouseWheel" .. R .. ".",
    }, c)
    y = y - 38
    local skRow = NS.CreateToggle(c, "Show Keybind", "showKeybind", y, function() NS.UpdateNow() end)
    NS.AddTooltip(skRow, "Show Keybind", {
        "Display the intercepted " .. K .. "keybind" .. R .. " text on",
        "the " .. U .. "Active Display" .. R .. " button.",
        " ",
        "Shows in the " .. V .. "top-right" .. R .. " corner of the icon.",
    }, c)
    y = y - 24
    -- Keybind Anchor + X/Y Offset
    do
    local halfW = math.floor((contentW - 28 - 6) / 2)
    local function ApplyKeybindOffset()
        local btn = NS.mainButton
        if btn and btn.hotkey then
            btn.hotkey:ClearAllPoints()
            btn.hotkey:SetPoint(NS.db.keybindAnchor or "TOPRIGHT",
                NS.db.keybindOffsetX or -5, NS.db.keybindOffsetY or -5)
        end
    end
    local kbAnchor = NS.CreateDropdown(c, "Keybind Anchor", "keybindAnchor", NS.KEYBIND_ANCHORS, y, ApplyKeybindOffset)
    NS.AddTooltip(kbAnchor, "Keybind Anchor", {
        "Anchor point for the " .. K .. "keybind" .. R .. " text",
        "on the " .. U .. "Active Display" .. R .. " button.",
    }, c)
    y = y - 46
    local kbOfsX = NS.CreateSlider(c, "Keybind X", "keybindOffsetX", -20, 20, 1, y, ApplyKeybindOffset)
    kbOfsX:SetSize(halfW, 32)
    NS.AddTooltip(kbOfsX, "Keybind X Offset", {
        "Horizontal offset of the " .. K .. "keybind" .. R .. " text",
        "on the " .. U .. "Active Display" .. R .. " button.",
    }, c)
    local kbOfsY = NS.CreateSlider(c, "Keybind Y", "keybindOffsetY", -20, 20, 1, y, ApplyKeybindOffset)
    kbOfsY:SetSize(halfW, 32)
    kbOfsY:ClearAllPoints()
    kbOfsY:SetPoint("TOPLEFT", kbOfsX, "TOPRIGHT", 6, 0)
    NS.AddTooltip(kbOfsY, "Keybind Y Offset", {
        "Vertical offset of the " .. K .. "keybind" .. R .. " text",
        "on the " .. U .. "Active Display" .. R .. " button.",
    }, c)
    y = y - 38
    end
    local scRow = NS.CreateToggle(c, "Show Cooldown", "showCooldown", y, function() NS.UpdateNow() end)
    NS.AddTooltip(scRow, "Show Cooldown", {
        "Display a " .. V .. "cooldown sweep" .. R .. " animation on the",
        U .. "Active Display" .. R .. " when the recommended spell",
        "is on cooldown (over " .. N .. "1.5s" .. R .. " duration).",
    }, c)
    y = y - 24
    local manualCooldownRow = NS.CreateToggle(c, "Manual Cooldown Reminders", "manualCooldownReminders", y, function()
        if NS.RefreshManualCooldownReminder then NS.RefreshManualCooldownReminder() end
    end)
    NS.AddTooltip(manualCooldownRow, "Manual Cooldown Reminders", {
        "Shows a separate reminder only when your active specialization has a",
        "selected catalog SBA target with a reviewed manual cooldown.",
        " ",
        "The reminder never casts the spell. It uses Blizzard's native cooldown",
        "sweep and says cooldown unknown when the client cannot verify readiness.",
    }, c)
    y = y - 24
    local rcRow = NS.CreateToggle(c, "Range Coloring", "rangeColoring", y, function() NS.UpdateNow() end)
    NS.AddTooltip(rcRow, "Range Coloring", {
        "Tints the " .. U .. "Active Display" .. R .. " icon " .. W .. "red" .. R,
        "when your target is " .. W .. "out of range" .. R .. ".",
        " ",
        "Also " .. V .. "desaturates" .. R .. " the icon to make it obvious.",
    }, c)
    y = y - 24
    local orsRow = NS.CreateToggle(c, "Out-of-Range Sound", "outOfRangeSound", y, function() NS.UpdateNow() end)
    NS.AddTooltip(orsRow, "Out-of-Range Sound", {
        "Plays a subtle " .. W .. "error beep" .. R .. " when the recommended",
        "spell is " .. W .. "out of range" .. R .. ".",
        " ",
        "Throttled to once per second to avoid spam.",
        "Requires " .. V .. "Range Coloring" .. R .. " to be active.",
    }, c)
    y = y - 24
    local suRow = NS.CreateToggle(c, "Spell Usability", "spellUsability", y, function() NS.UpdateNow() end)
    NS.AddTooltip(suRow, "Spell Usability", {
        "Dims and " .. V .. "desaturates" .. R .. " the " .. U .. "Active Display" .. R,
        "icon when the spell is " .. W .. "not usable" .. R .. ".",
        " ",
        "Catches " .. W .. "out of mana" .. R .. ", " .. W .. "out of rage" .. R .. ",",
        "and other resource-gated spells.",
    }, c)
    y = y - 28
    NS.CreateColorSwatch(c, "Button Background", "buttonBgColor", y, function(col)
        if NS.mainButton and not NS.masque and NS.mainButton.bg then
            NS.mainButton.bg:SetColorTexture(col[1], col[2], col[3], col[4] or 0.6)
        end
    end)
    y = y - 30

    local function RefreshAnimCloneHotkeyStyle()
        if NS.RefreshAnimHotkeys then NS.RefreshAnimHotkeys() end
    end

    local cloneHdr = CreateSubHeader(c, "ACTIVE ANIMATION CLONE", y)
    CreateDefaultBtn(c, cloneHdr, {
        "animCloneMasque", "animCloneReapplyKey", "animCloneKeybindOffsetX",
        "animCloneKeybindOffsetY", "animCloneKeybindFont",
        "animCloneKeybindOutline", "animCloneKeybindFontSize",
    })
    y = y - 18

    local animMasque = NS.CreateToggle(c, "Masque Skin Animated Clone", "animCloneMasque", y, function()
        if NS.ResetAnimClonePool then NS.ResetAnimClonePool() end
    end)
    NS.AddTooltip(animMasque, "Masque Skin Animated Clone", {
        "When " .. V .. "enabled" .. R .. ", the " .. U .. "animation clone" .. R .. " uses",
        "the " .. V .. "Animated Button" .. R .. " Masque group skin.",
        " ",
        "When " .. W .. "disabled" .. R .. ", only the " .. U .. "clone" .. R .. " falls back",
        "to BetterSBA's own border/icon layout.",
        " ",
        "The " .. U .. "Active Display" .. R .. " still uses Masque normally.",
    }, c)
    y = y - 32

    local animBindRow = NS.CreateAnimCloneReapplyKeyControl(c, y, contentW - 28)
    NS.AddTooltip(animBindRow.btn, "Reapply Clone Hotkey", {
        "Sets a debug key that re-applies the " .. U .. "animated clone" .. R .. " keybind text",
        "font, text, and X/Y anchor while the clone is visible.",
        " ",
        "Uses the cached spell keybind table only.",
        "Does " .. W .. "not" .. R .. " change the secure " .. U .. "SBA" .. R .. " binding.",
        " ",
        "This uses an override binding while set, so pick a spare combo.",
    }, c)
    y = y - 46

    local cloneHalfW = math.floor((contentW - 28 - 6) / 2)
    local cloneKbX = NS.CreateSlider(c, "Clone Keybind X", "animCloneKeybindOffsetX", -20, 20, 1, y, function()
        RefreshAnimCloneHotkeyStyle()
    end)
    cloneKbX:SetSize(cloneHalfW, 32)
    NS.AddTooltip(cloneKbX, "Animated Clone Keybind X Offset", {
        "Horizontal adjustment applied to the " .. K .. "keybind" .. R .. " text",
        "on the " .. U .. "animated clone" .. R .. " only.",
        " ",
        "This is added on top of the " .. U .. "Active Display" .. R .. " keybind X offset.",
    }, c)
    local cloneKbY = NS.CreateSlider(c, "Clone Keybind Y", "animCloneKeybindOffsetY", -20, 20, 1, y, function()
        RefreshAnimCloneHotkeyStyle()
    end)
    cloneKbY:SetSize(cloneHalfW, 32)
    cloneKbY:ClearAllPoints()
    cloneKbY:SetPoint("TOPLEFT", cloneKbX, "TOPRIGHT", 6, 0)
    NS.AddTooltip(cloneKbY, "Animated Clone Keybind Y Offset", {
        "Vertical adjustment applied to the " .. K .. "keybind" .. R .. " text",
        "on the " .. U .. "animated clone" .. R .. " only.",
        " ",
        "This is added on top of the " .. U .. "Active Display" .. R .. " keybind Y offset.",
    }, c)
    y = y - 38

    local cloneFontRowW = contentW - 28
    local cloneFontW = math.floor(cloneFontRowW * 0.46)
    local cloneOutlineW = math.floor(cloneFontRowW * 0.26)
    local cloneSizeW = cloneFontRowW - cloneFontW - cloneOutlineW - 12

    local cloneFontRow = NS.CreateFontDropdown(c, "Clone Font", "animCloneKeybindFont", y, RefreshAnimCloneHotkeyStyle, cloneFontW)
    NS.AddTooltip(cloneFontRow, "Animated Clone Keybind Font", {
        "Font used by the " .. U .. "animated clone" .. R .. " keybind text.",
        " ",
        "This only changes the virtual clone, not the main display.",
    }, c)

    local cloneOutRow = NS.CreateDropdown(c, "Clone Outline", "animCloneKeybindOutline",
        NS.FONT_OUTLINE_OPTIONS, y, RefreshAnimCloneHotkeyStyle, cloneOutlineW)
    cloneOutRow:ClearAllPoints()
    cloneOutRow:SetPoint("TOPLEFT", cloneFontRow, "TOPRIGHT", 6, 0)
    NS.AddTooltip(cloneOutRow, "Animated Clone Keybind Outline", {
        "Outline style for the " .. U .. "animated clone" .. R .. " keybind text.",
    }, c)

    local cloneSizeRow = NS.CreateSlider(c, "Clone Size", "animCloneKeybindFontSize", 6, 24, 1, y, RefreshAnimCloneHotkeyStyle)
    cloneSizeRow:SetSize(cloneSizeW, 32)
    cloneSizeRow:ClearAllPoints()
    cloneSizeRow:SetPoint("TOPLEFT", cloneOutRow, "TOPRIGHT", 6, 0)
    NS.AddTooltip(cloneSizeRow, "Animated Clone Keybind Size", {
        "Font size for the " .. U .. "animated clone" .. R .. " keybind text.",
    }, c)
    y = y - 46

    CreateSectionEndDivider(c, y)
    y = y - 12
    c._contentH = math.abs(y)
    c:SetHeight(c._contentH)
    end -- do (Section 3)

    -- 4. PRIORITY DISPLAY (12 options)
    c = contentFrames[4]
    y = -6
    do
    local c, y = c, y -- Keep callbacks bound to this section.
    local pdHdr = CreateSubHeader(c, "DISPLAY OPTIONS", y)
    CreateDefaultBtn(c, pdHdr, {
        "showPriority", "priorityIconSize", "prioritySpacing", "priorityPosition",
        "showPriorityKeybinds", "priorityKeybindFontSize", "priorityKeybindOffsetX",
        "priorityKeybindOffsetY", "priorityKeybindAnchor", "showActiveGlow",
        "priorityAlphaOOC", "priorityScale", "priorityDetached", "priorityLocked",
        "priorityBindFrame", "priorityMyPoint", "priorityTheirPoint",
    })
    y = y - 18
    local halfW = math.floor((contentW - 28 - 6) / 2)

    local sqRow = NS.CreateToggle(c, "Show Priority Display", "showPriority", y, function(on)
        if NS.priorityFrame then
            if on then NS.priorityFrame:Show() else NS.priorityFrame:Hide() end
        end
    end)
    NS.AddTooltip(sqRow, "Show Priority Display", {
        "Show or hide the " .. U .. "Priority Display" .. R .. " panel.",
        " ",
        "Displays the rotation " .. V .. "spell pool" .. R .. " from",
        U .. "SBA" .. R .. " as small icons beside the main button,",
        "sorted by " .. V .. "priority" .. R .. " (next-cast first).",
    }, c)
    y = y - 28

    local glowRow = NS.CreateToggle(c, "Active Spell Glow", "showActiveGlow", y, function()
        NS.UpdatePriorityDisplay()
    end)
    NS.AddTooltip(glowRow, "Active Spell Glow", {
        "Show Blizzard's " .. V .. "overlay glow" .. R .. " effect on",
        "the " .. U .. "next-cast" .. R .. " spell icon in the",
        U .. "Priority Display" .. R .. ".",
        " ",
        "Uses the standard proc highlight (dashed golden border).",
    }, c)
    y = y - 28
    -- Side-by-side: Icon Size + Scale
    local iconSz = NS.CreateSlider(c, "Icon Size", "priorityIconSize", 16, 48, 1, y, function()
        NS.LayoutPriority()
        NS.UpdatePriorityDisplay()
    end)
    iconSz:SetSize(halfW, 32)
    NS.AddTooltip(iconSz, "Priority Icon Size", {
        "Pixel size of each spell icon in the " .. U .. "Priority Display" .. R .. ".",
        "Range: " .. N .. "16" .. R .. " to " .. N .. "48" .. R .. " px.",
    }, c)
    local pScale = NS.CreateSlider(c, "Scale", "priorityScale", 0.5, 2.0, 0.05, y, function(val)
        if NS.priorityFrame then NS.priorityFrame:SetScale(val) end
    end)
    pScale:SetSize(halfW, 32)
    pScale:ClearAllPoints()
    pScale:SetPoint("TOPLEFT", iconSz, "TOPRIGHT", 6, 0)
    NS.AddTooltip(pScale, "Priority Scale", {
        "Overall scale of the " .. U .. "Priority Display" .. R .. " frame.",
        "Range: " .. N .. "0.5x" .. R .. " to " .. N .. "2.0x" .. R .. ".",
    }, c)
    y = y - 38
    local padSlider = NS.CreateSlider(c, "Icon Padding", "prioritySpacing", 0, 12, 1, y, function()
        NS.LayoutPriority()
        NS.UpdatePriorityDisplay()
    end)
    NS.AddTooltip(padSlider, "Icon Padding", {
        "Spacing between each icon in the " .. U .. "Priority Display" .. R .. ".",
        "Range: " .. N .. "0" .. R .. " to " .. N .. "12" .. R .. " px.",
    }, c)
    y = y - 38
    local pPosRow = NS.CreateDropdown(c, "Position", "priorityPosition", NS.PRIORITY_POSITIONS, y, function()
        NS.LayoutPriority()
    end)
    NS.AddTooltip(pPosRow, "Priority Position", {
        "Where the " .. U .. "Priority Display" .. R .. " anchors relative",
        "to the " .. U .. "Active Display" .. R .. ".",
        " ",
        "Options: " .. V .. "RIGHT" .. R .. ", " .. V .. "LEFT" .. R .. ", " .. V .. "TOP" .. R .. ", " .. V .. "BOTTOM" .. R .. ".",
    }, c)
    y = y - 46
    local detRow = NS.CreateToggle(c, "Detach Priority", "priorityDetached", y, function(on)
        if on then
            local f = NS.priorityFrame
            if f then
                local cx, cy = f:GetCenter()
                if cx and cy then
                    f:ClearAllPoints()
                    f:SetPoint("CENTER", NS.UIParent, "BOTTOMLEFT", cx, cy)
                    NS.db.priorityFreePosition = { point = "CENTER", relPoint = "BOTTOMLEFT", x = cx, y = cy }
                end
            end
            NS.db.priorityLocked = false
        else
            NS.db.priorityFreePosition = nil
            NS.db.priorityLocked = true
            NS.LayoutPriority()
        end
        if NS.UpdateDetachOverlay then NS.UpdateDetachOverlay() end
        rebuildPanel()
    end)
    NS.AddTooltip(detRow, "Detach Priority", {
        "Allows the " .. U .. "Priority Display" .. R .. " to be freely",
        "positioned anywhere on screen via " .. K .. "drag" .. R .. ".",
        " ",
        "When disabled, it re-attaches to the " .. V .. "Position" .. R .. " setting.",
    }, c)
    y = y - 28

    if db.priorityDetached then
        local lockBtn = NS.CreateFrame("Button", nil, c, "BackdropTemplate")
        lockBtn:SetSize(contentW - 28, 22)
        lockBtn:SetPoint("TOPLEFT", c, "TOPLEFT", 14, y)
        lockBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        local isLocked = db.priorityLocked
        lockBtn:SetBackdropColor(isLocked and T.TOGGLE_OFF[1] or T.TOGGLE_ON[1],
            isLocked and T.TOGGLE_OFF[2] or T.TOGGLE_ON[2],
            isLocked and T.TOGGLE_OFF[3] or T.TOGGLE_ON[3],
            isLocked and 1 or 0.6)
        lockBtn:SetBackdropBorderColor(NS.unpack(T.BORDER))
        local lockLbl = lockBtn:CreateFontString(nil, "OVERLAY")
        lockLbl:SetFont(NS.GetConfigFontPath(), 10, "OUTLINE")
        lockLbl:SetPoint("CENTER")
        lockLbl:SetTextColor(NS.unpack(T.TEXT))
        lockLbl:SetText(isLocked and (NS.GLYPH_LOCK .. "  Unlock Priority Position") or (NS.GLYPH_UNLOCK .. "  Lock Priority Position"))
        lockBtn:SetScript("OnClick", function()
            NS.db.priorityLocked = not NS.db.priorityLocked
            if NS.UpdateDetachOverlay then NS.UpdateDetachOverlay() end
            rebuildPanel()
        end)
        lockBtn:SetScript("OnEnter", function(self)
            local sc = c._sectionColorDim or T.ACCENT_DIM
            self:SetBackdropBorderColor(sc[1], sc[2], sc[3])
        end)
        lockBtn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(NS.unpack(T.BORDER)) end)
        NS.AddTooltip(lockBtn, "Lock / Unlock", {
            "Toggle whether the " .. U .. "Priority Display" .. R .. " can be",
            V .. "dragged" .. R .. " to a new position.",
            " ",
            "When " .. K .. "unlocked" .. R .. ", a " .. V .. "DRAG TO MOVE" .. R .. " overlay appears.",
        }, c)
        y = y - 28

        local bindRow = NS.CreateTextBoxDropdown(c, "Bind Frame", "priorityBindFrame",
            NS.PRIORITY_BIND_FRAMES, y, function(val)
                NS.db.priorityFreePosition = nil
                NS.ApplyPriorityBinding()
            end)
        NS.AddTooltip(bindRow, "Bind Frame", {
            "The " .. U .. "frame" .. R .. " that the " .. U .. "Priority Display" .. R,
            "anchors to when detached.",
            " ",
            V .. "Ctrl+Click" .. R .. " the text box for a list of presets.",
            "You can also type any valid frame name.",
        }, c)
        y = y - 44

        local myPt = NS.CreateTextBoxDropdown(c, "My Point", "priorityMyPoint",
            NS.ANCHOR_POINTS, y, function()
                NS.db.priorityFreePosition = nil
                NS.ApplyPriorityBinding()
            end, halfW)
        NS.AddTooltip(myPt, "My Point", {
            "The anchor point on the " .. U .. "Priority Display" .. R .. " frame.",
        }, c)
        local theirPt = NS.CreateTextBoxDropdown(c, "Their Point", "priorityTheirPoint",
            NS.ANCHOR_POINTS, y, function()
                NS.db.priorityFreePosition = nil
                NS.ApplyPriorityBinding()
            end, halfW)
        theirPt:ClearAllPoints()
        theirPt:SetPoint("TOPLEFT", myPt, "TOPRIGHT", 6, 0)
        NS.AddTooltip(theirPt, "Their Point", {
            "The anchor point on the " .. V .. "Bind Frame" .. R .. ".",
        }, c)
        y = y - 44
    end

    -- Side-by-side: Priority X/Y Offset
    local ofsX = NS.CreateSlider(c, "X Offset", "priorityOffsetX", -200, 200, 1, y, function()
        if NS.db.priorityDetached then
            NS.db.priorityFreePosition = nil
            if NS.ApplyPriorityBinding then NS.ApplyPriorityBinding() end
        end
        NS.LayoutPriority()
    end)
    ofsX:SetSize(halfW, 32)
    NS.AddTooltip(ofsX, "Priority X Offset", {
        "Horizontal offset of the " .. U .. "Priority Display" .. R .. ".",
        "Range: " .. N .. "-200" .. R .. " to " .. N .. "200" .. R .. " px.",
    }, c)
    local ofsY = NS.CreateSlider(c, "Y Offset", "priorityOffsetY", -200, 200, 1, y, function()
        if NS.db.priorityDetached then
            NS.db.priorityFreePosition = nil
            if NS.ApplyPriorityBinding then NS.ApplyPriorityBinding() end
        end
        NS.LayoutPriority()
    end)
    ofsY:SetSize(halfW, 32)
    ofsY:ClearAllPoints()
    ofsY:SetPoint("TOPLEFT", ofsX, "TOPRIGHT", 6, 0)
    NS.AddTooltip(ofsY, "Priority Y Offset", {
        "Vertical offset of the " .. U .. "Priority Display" .. R .. ".",
        "Range: " .. N .. "-200" .. R .. " to " .. N .. "200" .. R .. " px.",
    }, c)
    y = y - 38

    local sqkRow = NS.CreateToggle(c, "Show Priority Keybinds", "showPriorityKeybinds", y, function()
        NS.UpdatePriorityDisplay()
    end)
    NS.AddTooltip(sqkRow, "Show Priority Keybinds", {
        "Display " .. K .. "keybind" .. R .. " text on each spell icon",
        "in the " .. U .. "Priority Display" .. R .. ".",
        " ",
        "Shows the action bar keybind for each rotation spell.",
    }, c)
    y = y - 24

    -- Priority Keybind Anchor + X/Y Offset
    local pkbAnchor = NS.CreateDropdown(c, "Keybind Anchor", "priorityKeybindAnchor", NS.KEYBIND_ANCHORS, y, function()
        NS.ApplyPriorityFonts()
    end)
    NS.AddTooltip(pkbAnchor, "Priority Keybind Anchor", {
        "Anchor point for " .. K .. "keybind" .. R .. " text on",
        U .. "Priority Display" .. R .. " icons.",
    }, c)
    y = y - 46
    local pkbX = NS.CreateSlider(c, "Keybind X", "priorityKeybindOffsetX", -20, 20, 1, y, function()
        NS.ApplyPriorityFonts()
    end)
    pkbX:SetSize(halfW, 32)
    NS.AddTooltip(pkbX, "Priority Keybind X Offset", {
        "Horizontal offset of " .. K .. "keybind" .. R .. " text on",
        U .. "Priority Display" .. R .. " icons.",
    }, c)
    local pkbY = NS.CreateSlider(c, "Keybind Y", "priorityKeybindOffsetY", -20, 20, 1, y, function()
        NS.ApplyPriorityFonts()
    end)
    pkbY:SetSize(halfW, 32)
    pkbY:ClearAllPoints()
    pkbY:SetPoint("TOPLEFT", pkbX, "TOPRIGHT", 6, 0)
    NS.AddTooltip(pkbY, "Priority Keybind Y Offset", {
        "Vertical offset of " .. K .. "keybind" .. R .. " text on",
        U .. "Priority Display" .. R .. " icons.",
    }, c)
    y = y - 38

    -- Side-by-side: Label X/Y Offset
    local lblX = NS.CreateSlider(c, "Label X Offset", "priorityLabelOffsetX", -50, 50, 1, y, function()
        NS.LayoutPriority()
    end)
    lblX:SetSize(halfW, 32)
    NS.AddTooltip(lblX, "Label X Offset", {
        "Horizontal offset of the " .. V .. "Priority" .. R .. " label.",
        "Range: " .. N .. "-50" .. R .. " to " .. N .. "50" .. R .. " px.",
    }, c)
    local lblY = NS.CreateSlider(c, "Label Y Offset", "priorityLabelOffsetY", -50, 50, 1, y, function()
        NS.LayoutPriority()
    end)
    lblY:SetSize(halfW, 32)
    lblY:ClearAllPoints()
    lblY:SetPoint("TOPLEFT", lblX, "TOPRIGHT", 6, 0)
    NS.AddTooltip(lblY, "Label Y Offset", {
        "Vertical offset of the " .. V .. "Priority" .. R .. " label.",
        "Range: " .. N .. "-50" .. R .. " to " .. N .. "50" .. R .. " px.",
    }, c)
    y = y - 38

    -- Side-by-side: Priority Background + Border colors
    local bgSwatch = NS.CreateColorSwatch(c, "Background", "priorityBgColor", y, function(col)
        if NS.priorityFrame and NS.priorityFrame.bg then NS.priorityFrame.bg:SetColorTexture(col[1], col[2], col[3], col[4] or 0.6) end
    end)
    bgSwatch:SetSize(halfW, 20)
    local borderSwatch = NS.CreateColorSwatch(c, "Border", "priorityBorderColor", y, function(col)
        if NS.priorityFrame and NS.priorityFrame.borderTex then NS.priorityFrame.borderTex:SetColorTexture(col[1], col[2], col[3], col[4] or 1) end
    end)
    borderSwatch:SetSize(halfW, 20)
    borderSwatch:ClearAllPoints()
    borderSwatch:SetPoint("TOPLEFT", bgSwatch, "TOPRIGHT", 6, 0)
    y = y - 24

    CreateSectionEndDivider(c, y)
    y = y - 12
    c._contentH = math.abs(y)
    c:SetHeight(c._contentH)
    end -- do (Section 4)

    -- 5. TALENT BUILDS
    c = contentFrames[5]
    y = -6
    do
    local c, y = c, y -- Keep callbacks bound to this section.
    NS.BuildTalentBuildsConfigSection(c)
    end -- do (Section 5)

    -- 6. VISIBILITY (4 options)
    c = contentFrames[6]
    y = -6
    do
    local c, y = c, y -- Keep callbacks bound to this section.
    local visHdr = CreateSubHeader(c, "COMBAT STATE", y)
    CreateDefaultBtn(c, visHdr, {"onlyInCombat", "alphaCombat", "alphaOOC", "hideInVehicle"})
    y = y - 18
    local coRow = NS.CreateToggle(c, "Combat Only", "onlyInCombat", y, function() NS.UpdateNow() end)
    NS.AddTooltip(coRow, "Combat Only", {
        "Only show the " .. U .. "Active Display" .. R .. " during " .. V .. "combat" .. R .. ".",
        " ",
        "When out of combat the button becomes " .. W .. "invisible" .. R .. ".",
        "The keybind intercept still works regardless.",
    }, c)
    y = y - 24
    local hivRow = NS.CreateToggle(c, "Hide In Vehicle", "hideInVehicle", y, function() NS.UpdateNow() end)
    NS.AddTooltip(hivRow, "Hide In Vehicle", {
        "Hide the " .. U .. "Active Display" .. R .. " when inside",
        "a " .. V .. "vehicle" .. R .. " or using a vehicle UI.",
    }, c)
    y = y - 28
    local oocRow = NS.CreateSlider(c, "Button Out-of-Combat Alpha", "alphaOOC", 0, 1, 0.1, y, function()
        NS.UpdateNow()
    end)
    NS.AddTooltip(oocRow, "Button Out-of-Combat Alpha", {
        "Opacity of the " .. U .. "Active Display" .. R .. " when",
        W .. "out of combat" .. R .. ".",
        " ",
        "Range: " .. N .. "0" .. R .. " (invisible) to " .. N .. "1" .. R .. " (fully opaque).",
        "Set to " .. N .. "0" .. R .. " to hide outside combat.",
    }, c)
    y = y - 38
    local qoocRow2 = NS.CreateSlider(c, "Priority Out-of-Combat Alpha", "priorityAlphaOOC", 0, 1, 0.1, y, function()
        NS.UpdateNow()
    end)
    NS.AddTooltip(qoocRow2, "Priority Out-of-Combat Alpha", {
        "Opacity of the " .. U .. "Priority Display" .. R .. " when",
        W .. "out of combat" .. R .. ".",
        " ",
        "Range: " .. N .. "0" .. R .. " (invisible) to " .. N .. "1" .. R .. " (fully opaque).",
    }, c)
    y = y - 38
    CreateSectionEndDivider(c, y)
    y = y - 12
    c._contentH = math.abs(y)
    c:SetHeight(c._contentH)
    end -- do (Section 6)

    -- 7. IMPORTANCE BORDERS (6 options)
    c = contentFrames[7]
    y = -6
    do
    local c, y = c, y -- Keep callbacks bound to this section.
    local impHdr = CreateSubHeader(c, "PRIORITY IMPORTANCE COLORS", y)
    CreateDefaultBtn(c, impHdr, {
        "importanceBorders", "importColorAutoAttack", "importColorFiller",
        "importColorShortCD", "importColorLongCD", "importColorMajorCD",
    })
    y = y - 18
    local ibRow = NS.CreateToggle(c, "Importance Borders", "importanceBorders", y, function() NS.UpdateNow() end)
    NS.AddTooltip(ibRow, "Importance Borders", {
        "Color the " .. U .. "Active Display" .. R .. " border based on",
        "the recommended spell's " .. V .. "cooldown tier" .. R .. ".",
        " ",
        "Helps prioritize abilities at a glance.",
        "Customize colors for each tier below.",
    }, c)
    y = y - 28
    NS.CreateColorSwatchWithTooltip(c, "Auto Attack", "importColorAutoAttack", y, function() NS.UpdateNow() end,
        "Auto Attack (White)",
        { "Basic auto-attack and melee swing abilities.",
          "These have no cooldown (0 seconds).",
          "Shown when no other ability is recommended." })
    y = y - 24
    NS.CreateColorSwatchWithTooltip(c, "Filler", "importColorFiller", y, function() NS.UpdateNow() end,
        "Filler (Green)",
        { "Low or no-cooldown rotational abilities.",
          "Cooldown: 10 seconds or less.",
          "Examples: Cobra Shot, Steady Shot, Shadow Bolt." })
    y = y - 24
    NS.CreateColorSwatchWithTooltip(c, "Short Cooldown", "importColorShortCD", y, function() NS.UpdateNow() end,
        "Short Cooldown (Blue)",
        { "Regular rotation abilities with moderate cooldowns.",
          "Cooldown: 10 to 30 seconds.",
          "Examples: Barbed Shot, Kill Command, Dire Beast." })
    y = y - 24
    NS.CreateColorSwatchWithTooltip(c, "Long Cooldown", "importColorLongCD", y, function() NS.UpdateNow() end,
        "Long Cooldown (Purple)",
        { "Significant cooldown abilities.",
          "Cooldown: 30 seconds to 2 minutes.",
          "Examples: Bestial Wrath, Aspect of the Wild." })
    y = y - 24
    NS.CreateColorSwatchWithTooltip(c, "Major Cooldown", "importColorMajorCD", y, function() NS.UpdateNow() end,
        "Major Cooldown (Orange)",
        { "Major offensive or defensive cooldowns.",
          "Cooldown: over 2 minutes.",
          "Examples: Bloodlust, major defensive abilities." })
    y = y - 32

    -- Sub-header: Section Theme Colors
    do
        local col = c._sectionColor or T.TEXT_DIM
        local secHeader = c:CreateFontString(nil, "OVERLAY")
        secHeader:SetFont(NS.GetConfigFontPath(), 11, "")
        secHeader:SetPoint("TOPLEFT", c, "TOPLEFT", 14, y)
        secHeader:SetTextColor(col[1], col[2], col[3])
        secHeader:SetText("SECTION THEME COLORS")
        local line = c:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetColorTexture(col[1], col[2], col[3], 0.4)
        line:SetPoint("TOPLEFT", secHeader, "BOTTOMLEFT", 0, -3)
        line:SetPoint("RIGHT", c, "RIGHT", -14, 0)
        subHeaderLines[#subHeaderLines + 1] = line
        CreateDefaultBtn(c, secHeader, {
            "sectionColorCombat", "sectionColorAppearance", "sectionColorActive", "sectionColorPriority",
            "sectionColorTalentBuilds", "sectionColorVisibility", "sectionColorImportance",
            "sectionColorAdvanced", "sectionColorProfiles",
        })
    end
    y = y - 18

    -- Side-by-side section color swatches (4 rows: 2+2+2+1)
    local secHalfW = math.floor((contentW - 28 - 6) / 2)
    local reloadNote = "Changes apply after /reload."

    local s1 = NS.CreateColorSwatchWithTooltip(c, "Combat Assist", "sectionColorCombat", y, nil,
        "Combat Assist", { reloadNote })
    s1:SetSize(secHalfW, 20)
    local s2 = NS.CreateColorSwatchWithTooltip(c, "Appearance", "sectionColorAppearance", y, nil,
        "Appearance", { reloadNote })
    s2:SetSize(secHalfW, 20)
    s2:ClearAllPoints()
    s2:SetPoint("TOPLEFT", s1, "TOPRIGHT", 6, 0)
    y = y - 24

    local s3 = NS.CreateColorSwatchWithTooltip(c, "Active Display", "sectionColorActive", y, nil,
        "Active Display", { reloadNote })
    s3:SetSize(secHalfW, 20)
    local s4 = NS.CreateColorSwatchWithTooltip(c, "Talent Builds", "sectionColorTalentBuilds", y, nil,
        "Talent Builds", { reloadNote })
    s4:SetSize(secHalfW, 20)
    s4:ClearAllPoints()
    s4:SetPoint("TOPLEFT", s3, "TOPRIGHT", 6, 0)
    y = y - 24

    local s5 = NS.CreateColorSwatchWithTooltip(c, "Priority Display", "sectionColorPriority", y, nil,
        "Priority Display", { reloadNote })
    s5:SetSize(secHalfW, 20)
    local s6 = NS.CreateColorSwatchWithTooltip(c, "Visibility", "sectionColorVisibility", y, nil,
        "Visibility", { reloadNote })
    s6:SetSize(secHalfW, 20)
    s6:ClearAllPoints()
    s6:SetPoint("TOPLEFT", s5, "TOPRIGHT", 6, 0)
    y = y - 24

    local s7 = NS.CreateColorSwatchWithTooltip(c, "Importance", "sectionColorImportance", y, nil,
        "Importance", { reloadNote })
    s7:SetSize(secHalfW, 20)
    local s8 = NS.CreateColorSwatchWithTooltip(c, "Advanced", "sectionColorAdvanced", y, nil,
        "Advanced", { reloadNote })
    s8:SetSize(secHalfW, 20)
    s8:ClearAllPoints()
    s8:SetPoint("TOPLEFT", s7, "TOPRIGHT", 6, 0)
    y = y - 24

    local s9 = NS.CreateColorSwatchWithTooltip(c, "Profiles", "sectionColorProfiles", y, nil,
        "Profiles", { reloadNote })
    s9:SetSize(secHalfW, 20)
    y = y - 20

    CreateSectionEndDivider(c, y)
    y = y - 12
    c._contentH = math.abs(y)
    c:SetHeight(c._contentH)
    end -- do (Section 7)

    -- 8. ADVANCED
    c = contentFrames[8]
    y = -6
    do
    local c, y = c, y -- Keep callbacks bound to this section.
    local genHdr = CreateSubHeader(c, "GENERAL", y)
    CreateDefaultBtn(c, genHdr, {"modifierScaling", "locked"})
    y = y - 18
    local modScaleRow = NS.CreateToggle(c, "Modifier Scaling", "modifierScaling", y)
    NS.AddTooltip(modScaleRow, "Modifier Scaling", {
        "Use " .. K .. "CTRL+MOUSEWHEEL" .. R .. " to scroll and resize",
        "UI elements " .. V .. "independently" .. R .. ":",
        " ",
        U .. "Active Display" .. R .. " \226\128\148 " .. V .. "scales" .. R .. " the main ability button",
        U .. "Priority Display" .. R .. " \226\128\148 " .. V .. "scales" .. R .. " the priority display panel",
        U .. "Config Panel" .. R .. " \226\128\148 " .. V .. "scales" .. R .. " the " .. K .. "/bs" .. R .. " settings window",
        " ",
        "Each element scales " .. V .. "independently" .. R .. " and " .. V .. "persists" .. R,
        "across " .. V .. "reloads" .. R .. ". Range: " .. N .. "0.5x" .. R .. " to " .. N .. "2.0x" .. R .. ".",
    }, c)
    y = y - 24
    local lockRow = NS.CreateToggle(c, "Lock Position", "locked", y)
    NS.AddTooltip(lockRow, "Lock Position", {
        "Prevents " .. K .. "dragging" .. R .. " the " .. U .. "Active Display" .. R .. ".",
        " ",
        "When " .. V .. "locked" .. R .. ", the button cannot be moved.",
        "Use " .. K .. "/bs unlock" .. R .. " to toggle from chat.",
    }, c)
    y = y - 32

    do
        local col = c._sectionColor or T.TEXT_DIM
        local dbgHdr = c:CreateFontString(nil, "OVERLAY")
        dbgHdr:SetFont(NS.GetConfigFontPath(), 11, "")
        dbgHdr:SetPoint("TOPLEFT", c, "TOPLEFT", 14, y)
        dbgHdr:SetTextColor(col[1], col[2], col[3])
        dbgHdr:SetText("DEBUG")
        local dbgLine = c:CreateTexture(nil, "ARTWORK")
        dbgLine:SetHeight(1)
        dbgLine:SetColorTexture(col[1], col[2], col[3], 0.4)
        dbgLine:SetPoint("TOPLEFT", dbgHdr, "BOTTOMLEFT", 0, -3)
        dbgLine:SetPoint("RIGHT", c, "RIGHT", -14, 0)
        subHeaderLines[#subHeaderLines + 1] = dbgLine
        CreateDefaultBtn(c, dbgHdr, {"debug", "debugSpellUpdates", "debugAnimClone", "debugOther"})
    end
    y = y - 18

    local dbgRow = NS.CreateToggle(c, "Debug Mode", "debug", y, function()
        if NS.ApplyDebugSettings then NS.ApplyDebugSettings() end
    end)
    NS.AddTooltip(dbgRow, "Debug Mode", {
        "Master switch for BetterSBA chat diagnostics.",
        " ",
        "Turn this on first, then choose which debug",
        "output buckets should print below.",
    }, c)
    y = y - 24

    local spellDbgRow = NS.CreateToggle(c, "Spell Updates", "debugSpellUpdates", y, function()
        if NS.ApplyDebugSettings then NS.ApplyDebugSettings() end
    end)
    spellDbgRow:ClearAllPoints()
    spellDbgRow:SetPoint("TOPLEFT", c, "TOPLEFT", 30, y)
    spellDbgRow:SetSize(contentW - 44, 20)
    NS.AddTooltip(spellDbgRow, "Spell Updates", {
        "Prints display-update diagnostics to chat.",
        " ",
        "Includes recommendation resolution, action-bar fallback,",
        "display spell changes, and spell substitution logging.",
    }, c)
    y = y - 28

    local animDbgRow = NS.CreateToggle(c, "Animate Clone", "debugAnimClone", y, function()
        if NS.ApplyDebugSettings then NS.ApplyDebugSettings() end
    end)
    animDbgRow:ClearAllPoints()
    animDbgRow:SetPoint("TOPLEFT", c, "TOPLEFT", 30, y)
    animDbgRow:SetSize(contentW - 44, 20)
    NS.AddTooltip(animDbgRow, "Animate Clone", {
        "Prints animated clone diagnostics to chat.",
        " ",
        "Includes clone size, scale, anchor, Masque state,",
        "and manual reapply output.",
    }, c)
    y = y - 28

    local otherDbgRow = NS.CreateToggle(c, "Other", "debugOther", y, function()
        if NS.ApplyDebugSettings then NS.ApplyDebugSettings() end
    end)
    otherDbgRow:ClearAllPoints()
    otherDbgRow:SetPoint("TOPLEFT", c, "TOPLEFT", 30, y)
    otherDbgRow:SetSize(contentW - 44, 20)
    NS.AddTooltip(otherDbgRow, "Other", {
        "Prints the remaining debug output to chat.",
        " ",
        "Includes API availability, keybind interception status,",
        "and click/macro execution diagnostics.",
    }, c)
    y = y - 32

    -- Sub-header: GARBAGE COLLECTION
    do
        local col = c._sectionColor or T.TEXT_DIM
        local gcHdr = c:CreateFontString(nil, "OVERLAY")
        gcHdr:SetFont(NS.GetConfigFontPath(), 11, "")
        gcHdr:SetPoint("TOPLEFT", c, "TOPLEFT", 14, y)
        gcHdr:SetTextColor(col[1], col[2], col[3])
        gcHdr:SetText("GARBAGE COLLECTION")
        local gcLine = c:CreateTexture(nil, "ARTWORK")
        gcLine:SetHeight(1)
        gcLine:SetColorTexture(col[1], col[2], col[3], 0.4)
        gcLine:SetPoint("TOPLEFT", gcHdr, "BOTTOMLEFT", 0, -3)
        gcLine:SetPoint("RIGHT", c, "RIGHT", -14, 0)
        subHeaderLines[#subHeaderLines + 1] = gcLine
    end
    y = y - 18

    local gcNote = c:CreateFontString(nil, "OVERLAY")
    gcNote:SetFont(NS.GetConfigFontPath(), 9, NS.GetConfigFontOutline())
    gcNote:SetPoint("TOPLEFT", c, "TOPLEFT", 14, y)
    gcNote:SetPoint("RIGHT", c, "RIGHT", -14, 0)
    gcNote:SetJustifyH("LEFT")
    gcNote:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
    gcNote:SetText("Memory is managed by World of Warcraft automatically. BetterSBA does not change the shared Lua garbage collector.")
    y = y - 30

    -- Sub-header: THEME
    do
        local col = c._sectionColor or T.TEXT_DIM
        local themeHdr = c:CreateFontString(nil, "OVERLAY")
        themeHdr:SetFont(NS.GetConfigFontPath(), 11, "")
        themeHdr:SetPoint("TOPLEFT", c, "TOPLEFT", 14, y)
        themeHdr:SetTextColor(col[1], col[2], col[3])
        themeHdr:SetText("THEME")
        local themeLine = c:CreateTexture(nil, "ARTWORK")
        themeLine:SetHeight(1)
        themeLine:SetColorTexture(col[1], col[2], col[3], 0.4)
        themeLine:SetPoint("TOPLEFT", themeHdr, "BOTTOMLEFT", 0, -3)
        themeLine:SetPoint("RIGHT", c, "RIGHT", -14, 0)
        subHeaderLines[#subHeaderLines + 1] = themeLine
        CreateDefaultBtn(c, themeHdr, {"themePreset"})
    end
    y = y - 18

    local themeRow = NS.CreateDropdown(c, "Color Theme", "themePreset",
        NS.THEME_PRESET_ORDER, y, function(val)
            NS.ApplyThemePreset(val)
            rebuildPanel()
        end)
    NS.AddTooltip(themeRow, "Color Theme", {
        "Choose a color theme for the BetterSBA UI.",
        " ",
        V .. "Default" .. R .. " — cyan/blue accent (original)",
        V .. "Obsidian" .. R .. " — neutral grey tones",
        V .. "Arcane" .. R .. " — purple/violet",
        V .. "Fel" .. R .. " — green",
        V .. "Blood" .. R .. " — red",
        V .. "Gold" .. R .. " — warm amber/gold",
        V .. "Frost" .. R .. " — ice blue",
        " ",
        "Affects accent colors throughout the UI.",
        "Section colors are " .. V .. "independent" .. R .. " (editable in Importance).",
    }, c)
    y = y - 50

    -- Sub-header: LDB / Minimap Options
    do
        local col = c._sectionColor or T.TEXT_DIM
        local ldbHeader = c:CreateFontString(nil, "OVERLAY")
        ldbHeader:SetFont(NS.GetConfigFontPath(), 11, "")
        ldbHeader:SetPoint("TOPLEFT", c, "TOPLEFT", 14, y)
        ldbHeader:SetTextColor(col[1], col[2], col[3])
        ldbHeader:SetText("LDB / MINIMAP OPTIONS")
        local ldbLine = c:CreateTexture(nil, "ARTWORK")
        ldbLine:SetHeight(1)
        ldbLine:SetColorTexture(col[1], col[2], col[3], 0.4)
        ldbLine:SetPoint("TOPLEFT", ldbHeader, "BOTTOMLEFT", 0, -3)
        ldbLine:SetPoint("RIGHT", c, "RIGHT", -14, 0)
        subHeaderLines[#subHeaderLines + 1] = ldbLine
        CreateDefaultBtn(c, ldbHeader, {"showMinimapButton", "ldbShowText", "minimapIconSize", "minimapIconOffsetX", "minimapIconOffsetY"})
    end
    y = y - 18

    local mmRow = NS.CreateToggle(c, "Show Minimap Button", "showMinimapButton", y, function(on)
        NS.SetMinimapVisible(on)
    end)
    NS.AddTooltip(mmRow, "Show Minimap Button", {
        "Show or hide the BetterSBA icon on the " .. U .. "minimap" .. R .. ".",
        " ",
        "The minimap button provides quick access to",
        "the " .. U .. "Config Panel" .. R .. " and intercept status.",
    }, c)
    y = y - 24

    local ldbRow = NS.CreateToggle(c, "LDB Status Text", "ldbShowText", y, function()
        NS.UpdateLDBText()
    end)
    NS.AddTooltip(ldbRow, "LDB Status Text", {
        "Show intercept status on the " .. U .. "LDB" .. R .. " data object.",
        " ",
        "Displays current " .. V .. "keybind" .. R .. ", " .. V .. "slot" .. R .. ", and " .. V .. "bar" .. R .. " info",
        "in compatible data broker displays.",
    }, c)
    y = y - 32

    -- Sub-header: Performance Statistics
    do
        local col = c._sectionColor or T.TEXT_DIM
        local perfHeader = c:CreateFontString(nil, "OVERLAY")
        perfHeader:SetFont(NS.GetConfigFontPath(), 11, "")
        perfHeader:SetPoint("TOPLEFT", c, "TOPLEFT", 14, y)
        perfHeader:SetTextColor(col[1], col[2], col[3])
        perfHeader:SetText("PERFORMANCE")
        local perfLine = c:CreateTexture(nil, "ARTWORK")
        perfLine:SetHeight(1)
        perfLine:SetColorTexture(col[1], col[2], col[3], 0.4)
        perfLine:SetPoint("TOPLEFT", perfHeader, "BOTTOMLEFT", 0, -3)
        perfLine:SetPoint("RIGHT", c, "RIGHT", -14, 0)
        subHeaderLines[#subHeaderLines + 1] = perfLine
    end
    y = y - 18

    -- Stat rows (FontStrings updated by a ticker while visible)
    local statFontSize = 10
    local statOutline = NS.GetConfigFontOutline()
    local statFont = NS.GetConfigFontPath()
    local sc7 = c._sectionColor or T.ACCENT

    local function MakeStatRow(label, yOff)
        local row = NS.CreateFrame("Frame", nil, c)
        row:SetPoint("TOPLEFT", c, "TOPLEFT", 10, yOff)
        row:SetPoint("RIGHT", c, "RIGHT", -10, 0)
        row:SetHeight(16)

        local lbl = row:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(statFont, statFontSize, statOutline)
        lbl:SetPoint("LEFT", 4, 0)
        lbl:SetTextColor(T.TEXT_DIM[1], T.TEXT_DIM[2], T.TEXT_DIM[3])
        lbl:SetText(label)

        local val = row:CreateFontString(nil, "OVERLAY")
        val:SetFont(statFont, statFontSize, statOutline)
        val:SetPoint("RIGHT", -4, 0)
        val:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])
        val:SetJustifyH("RIGHT")
        val:SetText("--")

        row.val = val
        row.lbl = lbl
        return row
    end

    local rowMem = MakeStatRow("Memory Usage", y)
    NS.AddTooltip(rowMem, "Memory Usage", {
        "Lua memory allocated by BetterSBA.",
        " ",
        V .. "< 1 MB" .. R .. "  \226\128\148  Excellent (green)",
        N .. "1 \226\128\147 3 MB" .. R .. "  \226\128\148  Normal (yellow)",
        W .. "3 \226\128\147 5 MB" .. R .. "  \226\128\148  Elevated (orange)",
        W .. "> 5 MB" .. R .. "  \226\128\148  High \226\128\148 report to dev",
        W .. "> 10 MB" .. R .. " \226\128\148  Critical \226\128\148 possible leak, report immediately",
        " ",
        "Memory grows slightly over time. A " .. K .. "/reload" .. R,
        "clears it. Sustained growth may indicate a bug.",
    }, c)
    y = y - 16

    local rowRate = MakeStatRow("Update Rate", y)
    NS.AddTooltip(rowRate, "Update Rate", {
        "How often BetterSBA refreshes the display.",
        " ",
        V .. "100 ms (10 Hz)" .. R .. "  \226\128\148  Default, minimal CPU",
        N .. "50 ms (20 Hz)" .. R .. "   \226\128\148  Smooth, slight CPU increase",
        W .. "< 50 ms (20+ Hz)" .. R .. " \226\128\148  Aggressive \226\128\148 unnecessary CPU usage",
        " ",
        "Lower values = smoother updates but more CPU.",
        "Most users should keep the " .. V .. "default 100 ms" .. R .. ".",
    }, c)
    y = y - 16

    local rowFrames = MakeStatRow("Managed Frames", y)
    NS.AddTooltip(rowFrames, "Managed Frames", {
        "Total UI frames created by BetterSBA.",
        " ",
        "Includes the main button, secure button,",
        "priority icons, and config panel.",
        " ",
        V .. "< 20" .. R .. "  \226\128\148  Normal",
        W .. "> 30" .. R .. "  \226\128\148  Unusual \226\128\148 report to dev if growing",
    }, c)
    y = y - 16

    local rowOverride = MakeStatRow("Keybind Override", y)
    NS.AddTooltip(rowOverride, "Keybind Override", {
        "Status of the keybind interception system.",
        " ",
        V .. "Intercepting [KEYBIND: key]" .. R .. "  \226\128\148  Working correctly",
        W .. "Paused: reason" .. R .. "  \226\128\148  Temporarily blocked (mount, vehicle)",
        W .. "Inactive" .. R .. "  \226\128\148  SBA not found on action bar",
        " ",
        "If " .. W .. "Inactive" .. R .. " persists, make sure the SBA spell",
        "is on your action bar and Assisted Combat is enabled.",
    }, c)
    y = y - 16

    local rowProfile = MakeStatRow("Active Profile", y)
    NS.AddTooltip(rowProfile, "Active Profile", {
        "The currently loaded settings profile.",
        " ",
        "Switch profiles in the " .. U .. "Profiles" .. R .. " section.",
        "Each character can use a different profile.",
    }, c)
    y = y - 16

    local rowUptime = MakeStatRow("Session Uptime", y)
    NS.AddTooltip(rowUptime, "Session Uptime", {
        "Time since the addon loaded this session.",
        " ",
        "Resets on " .. K .. "/reload" .. R .. " or login.",
        "Useful for correlating memory growth over time.",
    }, c)
    y = y - 16

    local rowHealth = MakeStatRow("Health", y)
    NS.AddTooltip(rowHealth, "Health Assessment", {
        "Overall addon health based on all metrics.",
        " ",
        V .. "Healthy" .. R .. "  \226\128\148  Everything is working normally",
        N .. "Warning" .. R .. "  \226\128\148  Minor issue detected (yellow text)",
        W .. "Critical" .. R .. "  \226\128\148  Serious problem (red text)",
        " ",
        "Possible issues flagged:",
        "  " .. W .. "High memory" .. R .. "  \226\128\148  > 5 MB, consider " .. K .. "/reload" .. R,
        "  " .. W .. "Memory leak" .. R .. " \226\128\148  > 10 MB, report to dev",
        "  " .. W .. "Fast tick" .. R .. "   \226\128\148  Update rate < 50ms, wasting CPU",
        "  " .. W .. "No keybind" .. R .. "  \226\128\148  SBA not on action bar",
        " ",
        "If " .. W .. "Critical" .. R .. " appears, screenshot this panel",
        "and report to the addon developer.",
    }, c)
    y = y - 24

    -- Hint that stats are clickable
    local diagHint = c:CreateFontString(nil, "OVERLAY")
    diagHint:SetFont(statFont, 8, "")
    diagHint:SetPoint("TOPLEFT", c, "TOPLEFT", 14, y)
    diagHint:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3], 0.6)
    diagHint:SetText("Click any stat to copy diagnostic report")
    y = y - 14

    -- Diagnostic report popup (reused, created on first click)
    local diagPopup = nil

    local function BuildDiagReport()
        UpdateAddOnMemoryUsage(ADDON_NAME)
        local memKB = GetAddOnMemoryUsage(ADDON_NAME)
        local memStr = memKB >= 1024
            and string.format("%.2f MB", memKB / 1024)
            or string.format("%.0f KB", memKB)

        local rate = NS.db.updateRate or 0.1
        local elapsed = GetTime() - (NS._loadTime or GetTime())
        local mins = math.floor(elapsed / 60)
        local secs = math.floor(elapsed % 60)
        local uptimeStr = mins >= 60
            and string.format("%dh %dm %ds", math.floor(mins / 60), mins % 60, secs)
            or string.format("%dm %ds", mins, secs)

        local frameCount = 0
        if NS.mainButton then frameCount = frameCount + 1 end
        if NS.secureButton then frameCount = frameCount + 1 end
        if NS._priorityIcons then frameCount = frameCount + #NS._priorityIcons end
        if NS.Config and NS.Config.frame then frameCount = frameCount + 1 end

        local keys = NS._overrideKeys
        local keybindStr = "Inactive"
        if keys and #keys > 0 then
            keybindStr = "Intercepting [KEYBIND: " .. table.concat(keys, ", ") .. "]"
            if NS._overrideSlot then
                local bar = math.floor((NS._overrideSlot - 1) / 12) + 1
                local btn = ((NS._overrideSlot - 1) % 12) + 1
                keybindStr = keybindStr .. " [ACTION BAR: " .. bar .. "] [ACTION BAR SLOT: " .. btn .. "]"
            end
        else
            local reason = NS.GetInterceptBlockReason and NS.GetInterceptBlockReason()
            if reason then keybindStr = "Paused: " .. reason end
        end

        local profName = NS.GetActiveProfileName and NS:GetActiveProfileName() or "Default"

        local name, realm = UnitFullName("player")
        local charKey = (name or "?") .. " - " .. (realm or GetRealmName() or "?")
        local _, class = UnitClass("player")
        local spec = GetSpecialization and GetSpecialization() or 0
        local specName = spec > 0 and (select(2, GetSpecializationInfo(spec)) or "?") or "?"
        local level = UnitLevel("player") or "?"

        local sbaAvail = "No"
        if NS.C_AssistedCombat and NS.C_AssistedCombat.IsAvailable then
            local ok, avail = pcall(NS.C_AssistedCombat.IsAvailable)
            if ok then sbaAvail = avail and "Yes" or "No" end
        end

        local gcCount = collectgarbage("count")
        local gcStr = string.format("%.2f MB", gcCount / 1024)

        -- Cache diagnostics
        local cacheDiag = NS.GetCacheDiagnostics and NS.GetCacheDiagnostics() or {}
        local cdEntries = cacheDiag.cooldownEntries or 0
        local texEntries = cacheDiag.textureEntries or 0
        local resEntries = cacheDiag.resolveEntries or 0
        local cdDirty = cacheDiag.cooldownDirty and "Yes" or "No"

        local lines = {
            "=== BetterSBA Diagnostic Report ===",
            "Version: " .. (NS.VERSION or "?"),
            "Date: " .. date("%Y-%m-%d %H:%M:%S"),
            "",
            "--- Character ---",
            "Character: " .. charKey,
            "Class: " .. (class or "?") .. " (" .. specName .. ")",
            "Level: " .. level,
            "Profile: " .. profName,
            "",
            "--- Performance ---",
            "Addon Memory: " .. memStr,
            "Lua GC Total: " .. gcStr,
            "Update Rate: " .. string.format("%.0f ms (%.0f Hz)", rate * 1000, 1 / rate),
            "Managed Frames: " .. frameCount,
            "Session Uptime: " .. uptimeStr,
            "",
            "--- Cache ---",
            "GC Policy: Native (no forced collection)",
            "Cooldown Cache: " .. cdEntries .. " entries (dirty: " .. cdDirty .. ")",
            "Texture Cache: " .. texEntries .. " entries",
            "Resolve Cache: " .. resEntries .. " entries",
            "",
            "--- Keybind ---",
            "Override Status: " .. keybindStr,
            "SBA Available: " .. sbaAvail,
            "",
            "--- Settings ---",
            "Enabled: " .. tostring(NS.db.enabled),
            "Locked: " .. tostring(NS.db.locked),
            "Show Priority: " .. tostring(NS.db.showPriority),
            "Button Size: " .. tostring(NS.db.buttonSize),
            "Scale: " .. tostring(NS.db.scale),
            "Combat Only: " .. tostring(NS.db.onlyInCombat),
            "Targeting: " .. tostring(NS.db.enableTargeting),
            "Pet Attack: " .. tostring(NS.db.enablePetAttack),
            "Channel Protect: " .. tostring(NS.db.enableChannelProtection),
            "",
            "--- Client ---",
            "Interface: " .. (select(4, GetBuildInfo()) or "?"),
            "Build: " .. (select(1, GetBuildInfo()) or "?"),
            "Locale: " .. (GetLocale() or "?"),
            "================================",
        }
        return table.concat(lines, "\n")
    end

    local function ShowDiagPopup()
        local report = BuildDiagReport()

        if not diagPopup then
            local p = NS.CreateFrame("Frame", "BetterSBA_DiagPopup", f, "BackdropTemplate")
            p:SetSize(400, 340)
            p:SetPoint("CENTER", f, "CENTER", 0, 0)
            p:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            p:SetBackdropColor(T.BG_DARK[1], T.BG_DARK[2], T.BG_DARK[3], 0.98)
            p:SetBackdropBorderColor(sc7[1], sc7[2], sc7[3], 0.8)
            p:SetFrameStrata("DIALOG")
            p:SetFrameLevel(f:GetFrameLevel() + 30)
            p:EnableKeyboard(true)
            p:SetPropagateKeyboardInput(false)
            p:SetScript("OnKeyDown", function(self, key)
                if key == "ESCAPE" then
                    self:SetPropagateKeyboardInput(false)
                    self:Hide()
                else
                    self:SetPropagateKeyboardInput(true)
                end
            end)

            -- Title
            local title = p:CreateFontString(nil, "OVERLAY")
            title:SetFont(NS.GetConfigFontPath(), 11, "OUTLINE")
            title:SetPoint("TOP", 0, -10)
            title:SetTextColor(sc7[1], sc7[2], sc7[3])
            title:SetText("Diagnostic Report")

            -- Subtitle
            local sub = p:CreateFontString(nil, "OVERLAY")
            sub:SetFont(NS.GetConfigFontPath(), 9, "")
            sub:SetPoint("TOP", title, "BOTTOM", 0, -4)
            sub:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
            sub:SetText("Ctrl+A to select all, then Ctrl+C to copy")

            -- Scrollable EditBox
            local scroll = NS.CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
            scroll:SetPoint("TOPLEFT", 12, -46)
            scroll:SetPoint("BOTTOMRIGHT", -30, 36)

            local editBox = NS.CreateFrame("EditBox", nil, scroll)
            editBox:SetMultiLine(true)
            editBox:SetAutoFocus(false)
            editBox:SetFont(NS.GetConfigFontPath(), 10, "")
            editBox:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])
            editBox:SetWidth(scroll:GetWidth() or 340)
            editBox:SetTextInsets(4, 4, 4, 4)
            -- Prevent editing — restore report on any character input
            editBox:SetScript("OnChar", function(self)
                self:SetText(self._report or "")
                self:HighlightText()
            end)
            editBox:SetScript("OnEditFocusGained", function(self)
                self:HighlightText()
            end)
            editBox:SetScript("OnEscapePressed", function(self)
                self:ClearFocus()
                p:Hide()
            end)

            scroll:SetScrollChild(editBox)
            p._editBox = editBox
            p._scroll = scroll

            -- Close button
            local closeBtn = NS.CreateFrame("Button", nil, p, "BackdropTemplate")
            closeBtn:SetSize(70, 22)
            closeBtn:SetPoint("BOTTOM", 0, 8)
            closeBtn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            closeBtn:SetBackdropColor(T.BG_HOVER[1], T.BG_HOVER[2], T.BG_HOVER[3], 0.4)
            closeBtn:SetBackdropBorderColor(T.BORDER[1], T.BORDER[2], T.BORDER[3], 0.6)
            local closeLbl = closeBtn:CreateFontString(nil, "OVERLAY")
            closeLbl:SetFont(NS.GetConfigFontPath(), 9, "OUTLINE")
            closeLbl:SetPoint("CENTER", 0, 0)
            closeLbl:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])
            closeLbl:SetText("Close")
            closeBtn:SetScript("OnClick", function() p:Hide() end)
            closeBtn:SetScript("OnEnter", function(self)
                self:SetBackdropColor(T.BG_HOVER[1], T.BG_HOVER[2], T.BG_HOVER[3], 0.7)
                closeLbl:SetTextColor(1, 1, 1)
            end)
            closeBtn:SetScript("OnLeave", function(self)
                self:SetBackdropColor(T.BG_HOVER[1], T.BG_HOVER[2], T.BG_HOVER[3], 0.4)
                closeLbl:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])
            end)

            diagPopup = p
        end

        -- Set content and show
        diagPopup._editBox._report = report
        diagPopup._editBox:SetText(report)
        diagPopup._editBox:SetCursorPosition(0)
        diagPopup:Show()
        diagPopup._editBox:SetFocus()
        diagPopup._editBox:HighlightText()
    end

    -- Make all stat rows clickable to open diagnostic report
    local statRows = { rowMem, rowRate, rowFrames, rowOverride, rowProfile, rowUptime, rowHealth }
    for ri = 1, #statRows do
        local row = statRows[ri]
        row:EnableMouse(true)
        row:SetScript("OnMouseUp", ShowDiagPopup)
    end

    -- Live update ticker (runs while section 7 content is visible)
    local perfTicker = nil

    local function UpdatePerfStats()
        -- Memory
        UpdateAddOnMemoryUsage(ADDON_NAME)
        local memKB = GetAddOnMemoryUsage(ADDON_NAME)
        local memStr
        if memKB >= 1024 then
            memStr = string.format("%.1f MB", memKB / 1024)
        else
            memStr = string.format("%.0f KB", memKB)
        end
        local memVal = rowMem.val
        memVal:SetText(memStr)

        if memKB < 1024 then
            memVal:SetTextColor(0.3, 1.0, 0.4)
        elseif memKB < 3072 then
            memVal:SetTextColor(1.0, 0.85, 0.2)
        elseif memKB < 5120 then
            memVal:SetTextColor(1.0, 0.5, 0.1)
        elseif memKB < 10240 then
            memVal:SetText(memStr .. "  [HIGH]")
            memVal:SetTextColor(1.0, 0.3, 0.3)
        else
            memVal:SetText(memStr .. "  [CRITICAL - Report to dev]")
            memVal:SetTextColor(1.0, 0.1, 0.1)
        end

        -- Update rate
        local rate = NS.db.updateRate or 0.1
        local rateVal = rowRate.val
        rateVal:SetText(string.format("%.0f ms (%.0f Hz)", rate * 1000, 1 / rate))
        if rate >= 0.1 then
            rateVal:SetTextColor(0.3, 1.0, 0.4)
        elseif rate >= 0.05 then
            rateVal:SetTextColor(1.0, 0.85, 0.2)
        else
            rateVal:SetText(string.format("%.0f ms (%.0f Hz)  [EXCESSIVE]", rate * 1000, 1 / rate))
            rateVal:SetTextColor(1.0, 0.3, 0.3)
        end

        -- Managed frames count
        local frameCount = 0
        if NS.mainButton then frameCount = frameCount + 1 end
        if NS.secureButton then frameCount = frameCount + 1 end
        if NS._priorityIcons then frameCount = frameCount + #NS._priorityIcons end
        if NS.Config and NS.Config.frame then frameCount = frameCount + 1 end
        local fVal = rowFrames.val
        fVal:SetText(tostring(frameCount))
        if frameCount <= 20 then
            fVal:SetTextColor(0.3, 1.0, 0.4)
        elseif frameCount <= 30 then
            fVal:SetTextColor(1.0, 0.85, 0.2)
        else
            fVal:SetText(frameCount .. "  [HIGH - Report to dev]")
            fVal:SetTextColor(1.0, 0.3, 0.3)
        end

        -- Keybind override status
        local oVal = rowOverride.val
        local keys = NS._overrideKeys
        if keys and #keys > 0 then
            oVal:SetText(NS.table_concat(keys, ", "))
            oVal:SetTextColor(0.3, 1.0, 0.4)
        else
            local reason = NS.GetInterceptBlockReason and NS.GetInterceptBlockReason()
            if reason then
                oVal:SetText("Paused: " .. reason)
                oVal:SetTextColor(1.0, 0.53, 0.0)
            else
                oVal:SetText("Inactive")
                oVal:SetTextColor(1.0, 0.3, 0.3)
            end
        end

        -- Active profile
        local pVal = rowProfile.val
        local profName = NS:GetActiveProfileName()
        pVal:SetText(profName)
        pVal:SetTextColor(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3])

        -- Session uptime (from addon load, not panel open)
        local uVal = rowUptime.val
        local elapsed = GetTime() - (NS._loadTime or GetTime())
        local mins = math.floor(elapsed / 60)
        local secs = math.floor(elapsed % 60)
        if mins >= 60 then
            local hrs = math.floor(mins / 60)
            mins = mins % 60
            uVal:SetText(string.format("%dh %dm %ds", hrs, mins, secs))
        else
            uVal:SetText(string.format("%dm %ds", mins, secs))
        end
        uVal:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])

        -- Overall health assessment
        local hVal = rowHealth.val
        local issues = {}
        local severity = 0  -- 0=healthy, 1=warning, 2=critical

        if memKB > 10240 then
            issues[#issues + 1] = "Memory leak (" .. string.format("%.1f MB", memKB / 1024) .. ") - report to dev"
            severity = 2
        elseif memKB > 5120 then
            issues[#issues + 1] = "High memory"
            severity = math.max(severity, 1)
        end

        if rate < 0.05 then
            issues[#issues + 1] = "Excessive tick rate"
            severity = math.max(severity, 1)
        end

        if not keys or #keys == 0 then
            local reason = NS.GetInterceptBlockReason and NS.GetInterceptBlockReason()
            if not reason then
                issues[#issues + 1] = "No keybind active"
                severity = math.max(severity, 1)
            end
        end

        if frameCount > 30 then
            issues[#issues + 1] = "Frame count high - report to dev"
            severity = 2
        end

        if severity == 0 then
            hVal:SetText("Healthy")
            hVal:SetTextColor(0.3, 1.0, 0.4)
        elseif severity == 1 then
            hVal:SetText(table.concat(issues, " | "))
            hVal:SetTextColor(1.0, 0.85, 0.2)
        else
            hVal:SetText(table.concat(issues, " | "))
            hVal:SetTextColor(1.0, 0.1, 0.1)
        end
    end

    -- Start/stop ticker when section content shows/hides
    -- 5s interval — UpdateAddOnMemoryUsage() forces a full GC accounting
    -- pass which causes visible stutters at 1s intervals
    c:HookScript("OnShow", function()
        UpdatePerfStats()
        perfTicker = NS.C_Timer_NewTicker(5.0, UpdatePerfStats)
    end)
    c:HookScript("OnHide", function()
        if perfTicker then perfTicker:Cancel() perfTicker = nil end
    end)

    CreateSectionEndDivider(c, y)
    y = y - 12
    c._contentH = math.abs(y)
    c:SetHeight(c._contentH)
    end -- do (Section 8)

    ----------------------------------------------------------------
    -- Section 9: Profiles (wrapped in do...end to limit locals)
    ----------------------------------------------------------------
    c = contentFrames[9]
    y = -6
    do
    local c, y = c, y -- Keep callbacks bound to this section.
    local profHdr = CreateSubHeader(c, "PROFILE MANAGEMENT", y)
    y = y - 18

    local PROFILE_BTN_BACKDROP = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    }

    -- Active Profile dropdown
    local profLbl = c:CreateFontString(nil, "OVERLAY")
    profLbl:SetFont(NS.GetConfigFontPath(), 11, NS.GetConfigFontOutline())
    profLbl:SetPoint("TOPLEFT", 14, y)
    profLbl:SetTextColor(NS.unpack(T.TEXT_DIM))
    profLbl:SetText("Active Profile")

    local profBtn = NS.CreateFrame("Button", nil, c, "BackdropTemplate")
    local profBtnW = contentW - 28 - 90
    profBtn:SetSize(profBtnW, 22)
    profBtn:SetPoint("TOPLEFT", 14, y - 16)
    profBtn:SetBackdrop(PROFILE_BTN_BACKDROP)
    profBtn:SetBackdropColor(NS.unpack(T.TOGGLE_OFF))
    profBtn:SetBackdropBorderColor(NS.unpack(T.BORDER))

    local profBtnText = profBtn:CreateFontString(nil, "OVERLAY")
    profBtnText:SetFont(NS.GetConfigFontPath(), 10, NS.GetConfigFontOutline())
    profBtnText:SetPoint("LEFT", 8, 0)
    profBtnText:SetPoint("RIGHT", -20, 0)
    profBtnText:SetJustifyH("LEFT")
    profBtnText:SetTextColor(NS.unpack(c._sectionColor or T.ACCENT))
    profBtnText:SetText(NS:GetActiveProfileName())

    local profArrow = profBtn:CreateFontString(nil, "OVERLAY")
    profArrow:SetFont(NS.GetConfigFontPath(), 10, NS.GetConfigFontOutline())
    profArrow:SetPoint("RIGHT", -6, 0)
    profArrow:SetTextColor(NS.unpack(T.TEXT_DIM))
    profArrow:SetText("v")

    -- Profile dropdown popup
    local profDropdown = NS.CreateFrame("Frame", nil, NS.UIParent, "BackdropTemplate")
    profDropdown:SetWidth(profBtnW)
    profDropdown:SetBackdrop(PROFILE_BTN_BACKDROP)
    profDropdown:SetBackdropColor(NS.unpack(T.BG_DARK))
    profDropdown:SetBackdropBorderColor(NS.unpack(T.BORDER))
    profDropdown:SetFrameStrata("TOOLTIP")
    profDropdown:SetFrameLevel(100)
    profDropdown:SetPoint("TOPLEFT", profBtn, "BOTTOMLEFT", 0, -2)
    profDropdown:Hide()
    profDropdown:EnableMouse(true)

    local profEntries = {}
    local ROW_H_PROF = 20

    local function RefreshProfileDropdown()
        -- Clear old entries
        for _, e in NS.ipairs(profEntries) do
            e:Hide()
            e:SetParent(nil)
        end
        profEntries = {}

        local profiles = NS:GetProfileList()
        profDropdown:SetHeight(#profiles * ROW_H_PROF + 4)

        local maxTextW = profBtnW
        for i, name in NS.ipairs(profiles) do
            local entry = NS.CreateFrame("Button", nil, profDropdown)
            entry:SetHeight(ROW_H_PROF)
            entry:SetPoint("TOPLEFT", 2, -(i - 1) * ROW_H_PROF - 2)
            entry:SetPoint("RIGHT", profDropdown, "RIGHT", -2, 0)

            local hl = entry:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(T.BG_HOVER[1], T.BG_HOVER[2], T.BG_HOVER[3], 0.5)

            entry.text = entry:CreateFontString(nil, "OVERLAY")
            entry.text:SetFont(NS.NERD_FONT, 10, NS.GetConfigFontOutline())
            entry.text:SetPoint("LEFT", 8, 0)
            entry.text:SetJustifyH("LEFT")

            if name == NS:GetActiveProfileName() then
                entry.text:SetText("|cFFFFCC00" .. NS.GLYPH_DIAMOND .. "|r " .. name)
            else
                entry.text:SetText("  " .. name)
            end

            local tw = entry.text:GetStringWidth()
            if tw and tw + 24 > maxTextW then maxTextW = tw + 24 end

            entry:SetScript("OnClick", function()
                profDropdown:Hide()
                if name == NS:GetActiveProfileName() then return end
                local ok, err = NS:SwitchProfile(name)
                if ok then
                    profBtnText:SetText(name)
                    print("|cFF66B8D9BetterSBA|r: Switched to profile |cFFFFCC00" .. name .. "|r")
                    -- Rebuild config panel to reflect new profile settings
                    NS._restoreSection = NS._activeSection or activeSection
                    NS.Config.frame:SetAlpha(0)
                    NS.Config.frame:Hide()
                    NS.Config.frame = nil
                    NS.C_Timer_After(0.02, function()
                        NS.Config:Toggle()
                        if NS.Config.frame then NS.Config.frame:SetAlpha(1) end
                    end)
                else
                    print("|cFF66B8D9BetterSBA|r: |cFFFF4444" .. (err or "Error") .. "|r")
                end
            end)

            profEntries[i] = entry
        end
        profDropdown:SetWidth(math.max(profBtnW, maxTextW))
    end

    profBtn:SetScript("OnClick", function()
        if profDropdown:IsShown() then
            profDropdown:Hide()
        else
            RefreshProfileDropdown()
            profDropdown:Show()
        end
    end)
    profBtn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(NS.unpack(T.ACCENT_DIM)) end)
    profBtn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(NS.unpack(T.BORDER)) end)

    -- Action buttons row: New / Delete
    local function MakeProfileButton(parent, label, x, yOff, w, onClick)
        local b = NS.CreateFrame("Button", nil, parent, "BackdropTemplate")
        b:SetSize(w, 22)
        b:SetPoint("TOPLEFT", x, yOff)
        b:SetBackdrop(PROFILE_BTN_BACKDROP)
        b:SetBackdropColor(NS.unpack(T.TOGGLE_OFF))
        b:SetBackdropBorderColor(NS.unpack(T.BORDER))
        local bl = b:CreateFontString(nil, "OVERLAY")
        bl:SetFont(NS.GetConfigFontPath(), 10, "")
        bl:SetPoint("CENTER")
        bl:SetTextColor(NS.unpack(T.TEXT))
        bl:SetText(label)
        b:SetScript("OnClick", onClick)
        b:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(NS.unpack(T.ACCENT_DIM))
            bl:SetTextColor(NS.unpack(c._sectionColorBright or T.ACCENT_BRIGHT))
        end)
        b:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(NS.unpack(T.BORDER))
            bl:SetTextColor(NS.unpack(T.TEXT))
        end)
        return b
    end

    -- New Profile button
    local newProfBtn = MakeProfileButton(c, "+ New", 14 + profBtnW + 6, y - 16, 40, function()
        -- Simple prompt: create profile named "Profile N"
        local profiles = NS:GetProfileList()
        local n = #profiles + 1
        local name = "Profile " .. n
        while NS.dbRoot.profiles[name] do
            n = n + 1
            name = "Profile " .. n
        end
        local ok, err = NS:CreateProfile(name)
        if ok then
            print("|cFF66B8D9BetterSBA|r: Created profile |cFFFFCC00" .. name .. "|r")
        else
            print("|cFF66B8D9BetterSBA|r: |cFFFF4444" .. (err or "Error") .. "|r")
        end
    end)
    NS.AddTooltip(newProfBtn, "New Profile", {
        "Creates a new profile by " .. V .. "copying" .. R .. " all current settings.",
        " ",
        "The new profile can be customized independently.",
    }, c)

    -- Delete Profile button
    local delProfBtn = MakeProfileButton(c, "Delete", 14 + profBtnW + 50, y - 16, 42, function()
        local current = NS:GetActiveProfileName()
        local replacement
        for _, name in NS.ipairs(NS:GetProfileList()) do
            if name ~= current then
                replacement = name
                break
            end
        end
        if not replacement then
            print("|cFF66B8D9BetterSBA|r: |cFFFF4444Cannot delete last profile|r")
            return
        end

        local switched, switchErr = NS:SwitchProfile(replacement)
        if not switched then
            print("|cFF66B8D9BetterSBA|r: |cFFFF4444" .. (switchErr or "Could not switch profile") .. "|r")
            return
        end

        local ok, err = NS:DeleteProfile(current)
        if ok then
            print("|cFF66B8D9BetterSBA|r: Deleted profile |cFFFFCC00" .. current .. "|r")
            -- Rebuild panel
            NS._restoreSection = 9
            NS.Config.frame:SetAlpha(0)
            NS.Config.frame:Hide()
            NS.Config.frame = nil
            NS.C_Timer_After(0.02, function()
                NS.Config:Toggle()
                if NS.Config.frame then NS.Config.frame:SetAlpha(1) end
            end)
        else
            print("|cFF66B8D9BetterSBA|r: |cFFFF4444" .. (err or "Error") .. "|r")
        end
    end)
    NS.AddTooltip(delProfBtn, "Delete Profile", {
        W .. "Deletes" .. R .. " the currently active profile.",
        " ",
        "Cannot delete the " .. V .. "last remaining" .. R .. " profile.",
        "Switches to another available profile first.",
    }, c)

    y = y - 52

    -- Character Binding section
    do
        local col = c._sectionColor or T.TEXT_DIM
        local charHeader = c:CreateFontString(nil, "OVERLAY")
        charHeader:SetFont(NS.GetConfigFontPath(), 11, "")
        charHeader:SetPoint("TOPLEFT", c, "TOPLEFT", 14, y)
        charHeader:SetTextColor(col[1], col[2], col[3])
        charHeader:SetText("CHARACTER BINDING")
        local charLine = c:CreateTexture(nil, "ARTWORK")
        charLine:SetHeight(1)
        charLine:SetColorTexture(col[1], col[2], col[3], 0.4)
        charLine:SetPoint("TOPLEFT", charHeader, "BOTTOMLEFT", 0, -3)
        charLine:SetPoint("RIGHT", c, "RIGHT", -14, 0)
    end
    y = y - 28

    local charKey = NS.GetCharKey()
    local charInfoLbl = c:CreateFontString(nil, "OVERLAY")
    charInfoLbl:SetFont(NS.GetConfigFontPath(), 9, "")
    charInfoLbl:SetPoint("TOPLEFT", 14, y)
    charInfoLbl:SetTextColor(NS.unpack(T.TEXT_MUTED))
    charInfoLbl:SetText("Character: |cFFCCCCCC" .. charKey .. "|r")
    y = y - 18

    -- Character binding info label
    local hasCharProf = NS:HasCharProfile()
    local charStatusLbl = c:CreateFontString(nil, "OVERLAY")
    charStatusLbl:SetFont(NS.GetConfigFontPath(), 10, "")
    charStatusLbl:SetPoint("TOPLEFT", 14, y)
    if hasCharProf then
        charStatusLbl:SetTextColor(0.30, 0.85, 0.45)
        charStatusLbl:SetText("This character has a specific profile binding.")
    else
        charStatusLbl:SetTextColor(NS.unpack(T.TEXT_DIM))
        charStatusLbl:SetText("Using global default profile.")
    end
    y = y - 20

    -- Bind / Unbind character button
    local charBindBtn = MakeProfileButton(c, hasCharProf and "Unbind Character" or "Bind to This Profile",
        14, y, hasCharProf and 120 or 130, function()
        if NS:HasCharProfile() then
            NS:SetCharProfile(nil)
            print("|cFF66B8D9BetterSBA|r: Character unbound — using global default profile")
        else
            NS:SetCharProfile(NS:GetActiveProfileName())
            print("|cFF66B8D9BetterSBA|r: Character bound to |cFFFFCC00" .. NS:GetActiveProfileName() .. "|r")
        end
        -- Rebuild to update button text / status
        NS._restoreSection = 9
        NS.Config.frame:SetAlpha(0)
        NS.Config.frame:Hide()
        NS.Config.frame = nil
        NS.C_Timer_After(0.02, function()
            NS.Config:Toggle()
            if NS.Config.frame then NS.Config.frame:SetAlpha(1) end
        end)
    end)
    NS.AddTooltip(charBindBtn, hasCharProf and "Unbind Character" or "Bind Character", {
        hasCharProf
            and "Removes the character-specific profile binding.\nThis character will use the " .. V .. "global default" .. R .. " profile."
            or "Assigns this character to the " .. V .. "current profile" .. R .. ".\nOther characters will continue using the global default.",
    }, c)
    y = y - 34

    -- Management section
    do
        local col = c._sectionColor or T.TEXT_DIM
        local mgmtHeader = c:CreateFontString(nil, "OVERLAY")
        mgmtHeader:SetFont(NS.GetConfigFontPath(), 11, "")
        mgmtHeader:SetPoint("TOPLEFT", c, "TOPLEFT", 14, y)
        mgmtHeader:SetTextColor(col[1], col[2], col[3])
        mgmtHeader:SetText("MANAGEMENT")
        local mgmtLine = c:CreateTexture(nil, "ARTWORK")
        mgmtLine:SetHeight(1)
        mgmtLine:SetColorTexture(col[1], col[2], col[3], 0.4)
        mgmtLine:SetPoint("TOPLEFT", mgmtHeader, "BOTTOMLEFT", 0, -3)
        mgmtLine:SetPoint("RIGHT", c, "RIGHT", -14, 0)
    end
    y = y - 28

    -- Copy From dropdown
    local copyFromLbl = c:CreateFontString(nil, "OVERLAY")
    copyFromLbl:SetFont(NS.GetConfigFontPath(), 11, NS.GetConfigFontOutline())
    copyFromLbl:SetPoint("TOPLEFT", 14, y)
    copyFromLbl:SetTextColor(NS.unpack(T.TEXT_DIM))
    copyFromLbl:SetText("Copy Settings From")
    y = y - 16

    local copyFromBtn = NS.CreateFrame("Button", nil, c, "BackdropTemplate")
    local copyW = contentW - 28 - 60
    copyFromBtn:SetSize(copyW, 22)
    copyFromBtn:SetPoint("TOPLEFT", 14, y)
    copyFromBtn:SetBackdrop(PROFILE_BTN_BACKDROP)
    copyFromBtn:SetBackdropColor(NS.unpack(T.TOGGLE_OFF))
    copyFromBtn:SetBackdropBorderColor(NS.unpack(T.BORDER))

    local copyFromText = copyFromBtn:CreateFontString(nil, "OVERLAY")
    copyFromText:SetFont(NS.GetConfigFontPath(), 10, NS.GetConfigFontOutline())
    copyFromText:SetPoint("LEFT", 8, 0)
    copyFromText:SetPoint("RIGHT", -20, 0)
    copyFromText:SetJustifyH("LEFT")
    copyFromText:SetTextColor(NS.unpack(T.TEXT_MUTED))
    copyFromText:SetText("Select profile...")

    local copyFromArrow = copyFromBtn:CreateFontString(nil, "OVERLAY")
    copyFromArrow:SetFont(NS.GetConfigFontPath(), 10, NS.GetConfigFontOutline())
    copyFromArrow:SetPoint("RIGHT", -6, 0)
    copyFromArrow:SetTextColor(NS.unpack(T.TEXT_DIM))
    copyFromArrow:SetText("v")

    -- Copy From dropdown popup
    local copyDropdown = NS.CreateFrame("Frame", nil, NS.UIParent, "BackdropTemplate")
    copyDropdown:SetWidth(copyW)
    copyDropdown:SetBackdrop(PROFILE_BTN_BACKDROP)
    copyDropdown:SetBackdropColor(NS.unpack(T.BG_DARK))
    copyDropdown:SetBackdropBorderColor(NS.unpack(T.BORDER))
    copyDropdown:SetFrameStrata("TOOLTIP")
    copyDropdown:SetFrameLevel(100)
    copyDropdown:SetPoint("TOPLEFT", copyFromBtn, "BOTTOMLEFT", 0, -2)
    copyDropdown:Hide()
    copyDropdown:EnableMouse(true)

    local copyEntries = {}
    local selectedCopySource = nil

    local function RefreshCopyDropdown()
        for _, e in NS.ipairs(copyEntries) do
            e:Hide()
            e:SetParent(nil)
        end
        copyEntries = {}

        local profiles = NS:GetProfileList()
        -- Filter out current profile
        local filtered = {}
        for _, name in NS.ipairs(profiles) do
            if name ~= NS:GetActiveProfileName() then
                filtered[#filtered + 1] = name
            end
        end

        if #filtered == 0 then
            copyDropdown:SetHeight(ROW_H_PROF + 4)
            local entry = NS.CreateFrame("Button", nil, copyDropdown)
            entry:SetHeight(ROW_H_PROF)
            entry:SetPoint("TOPLEFT", 2, -2)
            entry:SetPoint("RIGHT", copyDropdown, "RIGHT", -2, 0)
            entry.text = entry:CreateFontString(nil, "OVERLAY")
            entry.text:SetFont(NS.GetConfigFontPath(), 10, NS.GetConfigFontOutline())
            entry.text:SetPoint("LEFT", 8, 0)
            entry.text:SetTextColor(NS.unpack(T.TEXT_MUTED))
            entry.text:SetText("No other profiles")
            copyEntries[1] = entry
            return
        end

        copyDropdown:SetHeight(#filtered * ROW_H_PROF + 4)
        for i, name in NS.ipairs(filtered) do
            local entry = NS.CreateFrame("Button", nil, copyDropdown)
            entry:SetHeight(ROW_H_PROF)
            entry:SetPoint("TOPLEFT", 2, -(i - 1) * ROW_H_PROF - 2)
            entry:SetPoint("RIGHT", copyDropdown, "RIGHT", -2, 0)

            local hl = entry:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(T.BG_HOVER[1], T.BG_HOVER[2], T.BG_HOVER[3], 0.5)

            entry.text = entry:CreateFontString(nil, "OVERLAY")
            entry.text:SetFont(NS.GetConfigFontPath(), 10, NS.GetConfigFontOutline())
            entry.text:SetPoint("LEFT", 8, 0)
            entry.text:SetJustifyH("LEFT")
            entry.text:SetText(name)

            entry:SetScript("OnClick", function()
                selectedCopySource = name
                copyFromText:SetText(name)
                copyFromText:SetTextColor(NS.unpack(c._sectionColor or T.ACCENT))
                copyDropdown:Hide()
            end)

            copyEntries[i] = entry
        end
    end

    copyFromBtn:SetScript("OnClick", function()
        if copyDropdown:IsShown() then
            copyDropdown:Hide()
        else
            RefreshCopyDropdown()
            copyDropdown:Show()
        end
    end)
    copyFromBtn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(NS.unpack(T.ACCENT_DIM)) end)
    copyFromBtn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(NS.unpack(T.BORDER)) end)

    -- Apply Copy button
    local applyCopyBtn = MakeProfileButton(c, "Apply", 14 + copyW + 6, y, 50, function()
        if not selectedCopySource then
            print("|cFF66B8D9BetterSBA|r: Select a source profile first")
            return
        end
        local ok, err = NS:CopyFromProfile(selectedCopySource)
        if ok then
            print("|cFF66B8D9BetterSBA|r: Copied settings from |cFFFFCC00" .. selectedCopySource .. "|r")
            -- Rebuild panel
            NS._restoreSection = 9
            NS.Config.frame:SetAlpha(0)
            NS.Config.frame:Hide()
            NS.Config.frame = nil
            NS.C_Timer_After(0.02, function()
                NS.Config:Toggle()
                if NS.Config.frame then NS.Config.frame:SetAlpha(1) end
            end)
        else
            print("|cFF66B8D9BetterSBA|r: |cFFFF4444" .. (err or "Error") .. "|r")
        end
    end)
    NS.AddTooltip(applyCopyBtn, "Apply Copy", {
        "Copies all settings from the selected profile",
        "into the " .. V .. "current" .. R .. " profile.",
        " ",
        W .. "Overwrites" .. R .. " current settings. Cannot undo.",
    }, c)
    y = y - 36

    -- Reset to Defaults button
    local resetBtn = MakeProfileButton(c, "Reset to Defaults", 14, y, 130, function()
        local ok, err = NS:ResetProfile()
        if ok then
            print("|cFF66B8D9BetterSBA|r: Profile reset to defaults")
            NS._restoreSection = 9
            NS.Config.frame:SetAlpha(0)
            NS.Config.frame:Hide()
            NS.Config.frame = nil
            NS.C_Timer_After(0.02, function()
                NS.Config:Toggle()
                if NS.Config.frame then NS.Config.frame:SetAlpha(1) end
            end)
        else
            print("|cFF66B8D9BetterSBA|r: |cFFFF4444" .. (err or "Error") .. "|r")
        end
    end)
    NS.AddTooltip(resetBtn, "Reset to Defaults", {
        "Resets " .. W .. "all settings" .. R .. " in the current profile",
        "back to their " .. V .. "default" .. R .. " values.",
        " ",
        W .. "Cannot undo" .. R .. " this action.",
    }, c)
    y = y - 30

    CreateSectionEndDivider(c, y)
    y = y - 12
    c._contentH = math.abs(y)
    c:SetHeight(c._contentH)

    end -- do (Profiles section local scope)

    ----------------------------------------------------------------
    -- Search: settings index + results display
    ----------------------------------------------------------------
    local searchMode = false

    -- Searchable index: maps display labels → section indices
    -- Section titles are included so users can search by group name
    local settingsIndex = {
        { label = "Combat Assist", section = 1, isSection = true },
        { label = "Auto-Dismount", section = 1 },
        { label = "Auto-Target Enemies", section = 1 },
        { label = "Pet Attack", section = 1 },
        { label = "Channel Protection", section = 1 },
        { label = "Interception Type", section = 1 },
        { label = "Interception Method", section = 1 },
        { label = "Click Interception", section = 1 },
        { label = "Keybind Interception", section = 1 },
        { label = "Macro Preview", section = 1 },
        { label = "Trinkets", section = 1 },
        { label = "Trinket Use", section = 1 },
        { label = "Appearance", section = 2, isSection = true },
        { label = "Motion Feedback", section = 2 },
        { label = "Cast Feedback", section = 2 },
        { label = "Motion Preset", section = 2 },
        { label = "Motion Duration", section = 2 },
        { label = "Motion Intensity", section = 2 },
        { label = "Reduced Motion", section = 2 },
        { label = "Motion Preview", section = 2 },
        { label = "Classic Animation", section = 2 },
        { label = "Cast Animation", section = 2 },
        { label = "Animation Style", section = 2 },
        { label = "Pop Animation", section = 2 },
        { label = "Animation Preview", section = 2 },
        { label = "Incoming Animation", section = 2 },
        { label = "Hide Button During Animation", section = 2 },
        { label = "GCD Duration", section = 2 },
        { label = "Scan Line", section = 2 },
        { label = "Orbiting Dots", section = 2 },
        { label = "Pulse Effects", section = 2 },
        { label = "Slide Transitions", section = 2 },
        { label = "Particles", section = 2 },
        { label = "Particle Style", section = 2 },
        { label = "Particle Timing", section = 2 },
        { label = "Color Palette", section = 2 },
        { label = "Edit Palettes", section = 2 },
        { label = "Global Font", section = 2 },
        { label = "Global Outline", section = 2 },
        { label = "Config Panel Font", section = 2 },
        { label = "Config Panel Outline", section = 2 },
        { label = "Config Panel Override", section = 2 },
        { label = "Keybind Font", section = 2 },
        { label = "Keybind Outline", section = 2 },
        { label = "Keybind Font Size", section = 2 },
        { label = "Keybind Override", section = 2 },
        { label = "Priority Keybind Font", section = 2 },
        { label = "Priority Keybind Outline", section = 2 },
        { label = "Priority Keybind Font Size", section = 2 },
        { label = "Priority Keybind Override", section = 2 },
        { label = "Priority Label Font", section = 2 },
        { label = "Priority Label Outline", section = 2 },
        { label = "Priority Label Font Size", section = 2 },
        { label = "Priority Label Override", section = 2 },
        { label = "Active Display", section = 3, isSection = true },
        { label = "Button Style", section = 3 },
        { label = "Button Size", section = 3 },
        { label = "Show Keybind", section = 3 },
        { label = "Keybind Anchor", section = 3 },
        { label = "Keybind X Offset", section = 3 },
        { label = "Keybind Y Offset", section = 3 },
        { label = "Button Scale", section = 3 },
        { label = "Show Cooldown", section = 3 },
        { label = "Range Coloring", section = 3 },
        { label = "Out-of-Range Sound", section = 3 },
        { label = "Spell Usability", section = 3 },
        { label = "Button Background", section = 3 },
        { label = "Active Animation Clone", section = 3 },
        { label = "Masque Skin Animated Clone", section = 3 },
        { label = "Reapply Clone Hotkey", section = 3 },
        { label = "Clone Keybind X", section = 3 },
        { label = "Clone Keybind Y", section = 3 },
        { label = "Clone Font", section = 3 },
        { label = "Clone Outline", section = 3 },
        { label = "Clone Size", section = 3 },
        { label = "Priority Display", section = 4, isSection = true },
        { label = "Show Priority Display", section = 4 },
        { label = "Active Spell Glow", section = 4 },
        { label = "Priority Icon Size", section = 4 },
        { label = "Priority Scale", section = 4 },
        { label = "Icon Padding", section = 4 },
        { label = "Show Priority Keybinds", section = 4 },
        { label = "Priority Keybind Anchor", section = 4 },
        { label = "Priority Keybind X Offset", section = 4 },
        { label = "Priority Keybind Y Offset", section = 4 },
        { label = "Position", section = 4 },
        { label = "Detach Priority", section = 4 },
        { label = "Lock Priority", section = 4 },
        { label = "Bind Frame", section = 4 },
        { label = "My Point", section = 4 },
        { label = "Their Point", section = 4 },
        { label = "Priority X Offset", section = 4 },
        { label = "Priority Y Offset", section = 4 },
        { label = "Priority Background", section = 4 },
        { label = "Priority Border", section = 4 },
        { label = "Label X Offset", section = 4 },
        { label = "Label Y Offset", section = 4 },
        { label = "Talent Builds", section = 5, isSection = true },
        { label = "Search Builds", section = 5 },
        { label = "ALL", section = 5 },
        { label = "BUILT-IN", section = 5 },
        { label = "USER", section = 5 },
        { label = "APPLY", section = 5 },
        { label = "LOAD ANYWAY", section = 5 },
        { label = "CREATE", section = 5 },
        { label = "EDIT", section = 5 },
        { label = "DELETE", section = 5 },
        { label = "COPY", section = 5 },
        { label = "VIEW SOURCE", section = 5 },
        { label = "Visibility", section = 6, isSection = true },
        { label = "Combat Only", section = 6 },
        { label = "Hide In Vehicle", section = 6 },
        { label = "Button Out-of-Combat Alpha", section = 6 },
        { label = "Priority Out-of-Combat Alpha", section = 6 },
        { label = "Importance", section = 7, isSection = true },
        { label = "Importance Borders", section = 7 },
        { label = "Auto Attack Color", section = 7 },
        { label = "Filler Color", section = 7 },
        { label = "Short Cooldown Color", section = 7 },
        { label = "Long Cooldown Color", section = 7 },
        { label = "Major Cooldown Color", section = 7 },
        { label = "Section Theme Colors", section = 7 },
        { label = "Combat Assist Color", section = 7 },
        { label = "Appearance Color", section = 7 },
        { label = "Active Display Color", section = 7 },
        { label = "Talent Builds Color", section = 7 },
        { label = "Priority Display Color", section = 7 },
        { label = "Visibility Color", section = 7 },
        { label = "Importance Color", section = 7 },
        { label = "Advanced Color", section = 7 },
        { label = "Profiles Color", section = 7 },
        { label = "Advanced", section = 8, isSection = true },
        { label = "Garbage Collection", section = 8 },
        { label = "Modifier Scaling", section = 8 },
        { label = "Lock Position", section = 8 },
        { label = "Debug", section = 8 },
        { label = "Debug Mode", section = 8 },
        { label = "Spell Updates", section = 8 },
        { label = "Animate Clone", section = 8 },
        { label = "Other", section = 8 },
        { label = "Color Theme", section = 8 },
        { label = "Theme", section = 8 },
        { label = "LDB / Minimap Options", section = 8 },
        { label = "Show Minimap Button", section = 8 },
        { label = "LDB Status Text", section = 8 },
        { label = "Performance", section = 8 },
        { label = "Memory Usage", section = 8 },
        { label = "Health", section = 8 },
        { label = "Profiles", section = 9, isSection = true },
        { label = "Active Profile", section = 9 },
        { label = "New Profile", section = 9 },
        { label = "Delete Profile", section = 9 },
        { label = "Character Binding", section = 9 },
        { label = "Copy Settings From", section = 9 },
        { label = "Reset to Defaults", section = 9 },
    }

    -- Search results frame (shown in right panel during search)
    local searchResultsFrame = NS.CreateFrame("Frame", nil, scrollChild)
    searchResultsFrame:SetSize(contentW, 100)
    searchResultsFrame:SetPoint("TOPLEFT", 0, 0)
    searchResultsFrame:EnableMouse(true)
    searchResultsFrame:Hide()

    -- Result entry pool (section headers + individual results)
    local MAX_RESULTS = 30
    local resultEntries = {}
    for i = 1, MAX_RESULTS do
        local entry = NS.CreateFrame("Button", nil, searchResultsFrame)
        entry:SetSize(contentW - 28, 22)
        -- Position set dynamically during DoSearch

        -- Highlight on hover (recolored per-section in DoSearch)
        local hl = entry:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(T.BG_HOVER[1], T.BG_HOVER[2], T.BG_HOVER[3], 0.3)

        -- Left accent bar (colored per-section, visible on headers + results)
        local bar = entry:CreateTexture(nil, "ARTWORK")
        bar:SetWidth(2)
        bar:SetPoint("TOPLEFT", 0, 0)
        bar:SetPoint("BOTTOMLEFT", 0, 0)
        bar:SetColorTexture(1, 1, 1, 0.6)
        bar:Hide()

        -- Section dot (small colored dot for child results)
        local dot = entry:CreateTexture(nil, "OVERLAY")
        dot:SetSize(4, 4)
        dot:SetPoint("LEFT", 8, 0)
        dot:Hide()

        -- Label (positioned after dot when shown)
        local lbl = entry:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(NS.GetConfigFontPath(), 10, "")
        lbl:SetPoint("LEFT", 0, 0)
        lbl:SetTextColor(NS.unpack(T.TEXT))

        -- Match highlight text (shows the matched portion in accent color)
        local matchLbl = entry:CreateFontString(nil, "OVERLAY")
        matchLbl:SetFont(NS.GetConfigFontPath(), 10, "")
        matchLbl:SetPoint("LEFT", lbl, "LEFT", 0, 0)
        matchLbl:Hide()

        -- Separator line between section groups
        local sep = entry:CreateTexture(nil, "BACKGROUND")
        sep:SetHeight(1)
        sep:SetPoint("TOPLEFT", entry, "TOPLEFT", 0, 4)
        sep:SetPoint("TOPRIGHT", entry, "TOPRIGHT", 0, 4)
        sep:SetColorTexture(T.BORDER[1], T.BORDER[2], T.BORDER[3], 0.3)
        sep:Hide()

        entry._lbl = lbl
        entry._matchLbl = matchLbl
        entry._hl = hl
        entry._bar = bar
        entry._dot = dot
        entry._sep = sep
        entry:Hide()
        resultEntries[i] = entry
    end

    -- Search highlight overlay (persists until user interacts)
    local searchHighlight = scrollChild:CreateTexture(nil, "OVERLAY")
    searchHighlight:SetHeight(26)
    searchHighlight:SetColorTexture(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3], 0.25)
    searchHighlight:Hide()

    local highlightPulseTime = 0
    local highlightedHeader = nil
    local headerHighlightStart = 0
    local highlightFrame = NS.CreateFrame("Frame", nil, f)
    highlightFrame:SetScript("OnUpdate", function(self, elapsed)
        local running = false
        if searchHighlight:IsShown() then
            highlightPulseTime = highlightPulseTime + elapsed
            if highlightPulseTime >= 0.85 then
                searchHighlight:Hide()
            else
                searchHighlight:SetAlpha(1 - highlightPulseTime / 0.85)
                running = true
            end
        end

        if highlightedHeader then
            local base = highlightedHeader._baseColor
            local line = highlightedHeader._line
            local elapsedTime = GetTime() - headerHighlightStart
            local pct = math.min(1, elapsedTime / 0.85)
            local brightR = math.min(1, base[1] * 0.55 + 0.45)
            local brightG = math.min(1, base[2] * 0.55 + 0.45)
            local brightB = math.min(1, base[3] * 0.55 + 0.45)
            local mix = 1 - pct
            highlightedHeader:SetTextColor(
                base[1] + (brightR - base[1]) * mix,
                base[2] + (brightG - base[2]) * mix,
                base[3] + (brightB - base[3]) * mix
            )
            if line then
                local alpha = 0.4 + 0.45 * mix
                line:SetColorTexture(
                    base[1] + (brightR - base[1]) * mix,
                    base[2] + (brightG - base[2]) * mix,
                    base[3] + (brightB - base[3]) * mix,
                    alpha
                )
            end
            if pct >= 1 then
                highlightedHeader:SetTextColor(base[1], base[2], base[3])
                if line then
                    line:SetColorTexture(base[1], base[2], base[3], 0.4)
                end
                highlightedHeader = nil
            else
                running = true
            end
        end

        if not running then
            self:Hide()
        end
    end)
    highlightFrame:Hide()

    local function DismissSearchHighlight()
        searchHighlight:Hide()
        highlightPulseTime = 0
        if highlightedHeader then
            local base = highlightedHeader._baseColor
            local line = highlightedHeader._line
            highlightedHeader:SetTextColor(base[1], base[2], base[3])
            if line then
                line:SetColorTexture(base[1], base[2], base[3], 0.4)
            end
            highlightedHeader = nil
        end
        highlightFrame:Hide()
    end

    local function FindWidgetYByLabel(cf, label)
        local children = { cf:GetChildren() }
        for _, child in NS.ipairs(children) do
            local regions = { child:GetRegions() }
            for _, region in NS.ipairs(regions) do
                if region.GetText and region:GetText() == label then
                    local _, _, _, _, wy = child:GetPoint(1)
                    return wy, child
                end
            end
        end
        return nil, nil
    end

    local function ShowSearchHighlight(cf, targetY, widget)
        searchHighlight:ClearAllPoints()
        searchHighlight:SetPoint("TOPLEFT", cf, "TOPLEFT", 4, targetY + 4)
        searchHighlight:SetPoint("TOPRIGHT", cf, "TOPRIGHT", -4, targetY + 4)
        searchHighlight:SetAlpha(1)
        searchHighlight:Show()
        highlightPulseTime = 0
        highlightFrame:Show()

        -- Dismiss when user mouses over the highlighted widget
        if widget and not widget._searchHighlightHooked then
            widget:HookScript("OnEnter", function()
                if searchHighlight:IsShown() then
                    DismissSearchHighlight()
                end
            end)
            widget._searchHighlightHooked = true
        end
    end

    local function ShowSubHeaderHighlight(hdr)
        if not hdr or not hdr._baseColor then return end
        if highlightedHeader and highlightedHeader ~= hdr then
            local prevBase = highlightedHeader._baseColor
            local prevLine = highlightedHeader._line
            highlightedHeader:SetTextColor(prevBase[1], prevBase[2], prevBase[3])
            if prevLine then
                prevLine:SetColorTexture(prevBase[1], prevBase[2], prevBase[3], 0.4)
            end
        end
        highlightedHeader = hdr
        headerHighlightStart = GetTime()
        highlightFrame:Show()
    end

    -- Dismiss highlight when user manually scrolls (mouse wheel)
    local suppressScrollDismiss = false
    f:HookScript("OnMouseWheel", function()
        if searchHighlight:IsShown() and not suppressScrollDismiss then
            DismissSearchHighlight()
        end
    end)

    ----------------------------------------------------------------
    -- Top navigation and its active-page underline
    ----------------------------------------------------------------
    local BTN_H = navH
    local CHILD_H = 28
    local sectionButtons = {}
    self.sectionButtons = sectionButtons
    local subsectionButtons = {}
    local activeSubsection = nil

    local indicator = tabBar:CreateTexture(nil, "OVERLAY")
    indicator:SetWidth(50)
    indicator:SetHeight(2)
    indicator:SetColorTexture(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3], 0.9)

    local indicatorTargetX = 18
    local indicatorCurrentX = indicatorTargetX
    local animFrame
    local RefreshNavigationLayout
    local SelectSection

    local function EnsureSubsectionButton(sectionIndex, childIndex)
        subsectionButtons[sectionIndex] = subsectionButtons[sectionIndex] or {}
        if subsectionButtons[sectionIndex][childIndex] then
            return subsectionButtons[sectionIndex][childIndex]
        end

        local btn = NS.CreateFrame("Button", nil, sectionMenuContent)
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0)

        local branch = btn:CreateTexture(nil, "ARTWORK")
        branch:SetSize(3, 3)
        branch:SetPoint("LEFT", 9, 0)
        branch:SetColorTexture(NS.unpack(T.ACCENT))

        local lbl = btn:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(NS.GetConfigFontPath(), 11, "")
        lbl:SetPoint("LEFT", branch, "RIGHT", 9, 0)
        lbl:SetPoint("RIGHT", -8, 0)
        lbl:SetJustifyH("LEFT")

        btn._bg = bg
        btn._branch = branch
        btn._lbl = lbl
        btn._sectionIndex = sectionIndex
        btn._childIndex = childIndex

        btn:SetScript("OnClick", function(self)
            sectionMenu:Hide()
            local cf = contentFrames[self._sectionIndex]
            local subs = cf and cf._subsections
            local sub = subs and subs[self._childIndex]
            if not sub then return end
            activeSubsection = sub.label
            SelectSection(self._sectionIndex, true)
            if sub.kind == "page" or sub.onSelect or (cf and cf._onSubsectionSelected) then
                if sub.onSelect then
                    sub.onSelect(sub, cf)
                elseif cf and cf._onSubsectionSelected then
                    cf._onSubsectionSelected(sub.label, sub)
                end
                scrollChild:SetHeight(cf._contentH or 100)
                scrollFrame:SetVerticalScroll(0)
                UpdateScrollbar()
                RefreshNavigationLayout(true)
                return
            end
            local cf = contentFrames[self._sectionIndex]
            local viewH = scrollFrame:GetHeight()
            local maxScroll = math.max(0, (cf._contentH or 100) - viewH)
            local desiredScroll = math.max(0, math.min(maxScroll, (-sub.y) - 18))
            suppressScrollDismiss = true
            scrollFrame:SetVerticalScroll(desiredScroll)
            suppressScrollDismiss = false
            ShowSubHeaderHighlight(sub.header)
            UpdateScrollbar()
            RefreshNavigationLayout(true)
        end)
        btn:SetScript("OnEnter", function(self)
            local secColor = SECTIONS[self._sectionIndex].dotColor
            local subs = contentFrames[self._sectionIndex] and contentFrames[self._sectionIndex]._subsections
            local sub = subs and subs[self._childIndex]
            if sub and activeSubsection ~= sub.label then
                self._lbl:SetTextColor(secColor[1], secColor[2], secColor[3])
                self._bg:SetColorTexture(secColor[1], secColor[2], secColor[3], 0.12)
                self._branch:SetVertexColor(secColor[1], secColor[2], secColor[3], 0.95)
            end
        end)
        btn:SetScript("OnLeave", function(self)
            local secColor = SECTIONS[self._sectionIndex].dotColor
            local subs = contentFrames[self._sectionIndex] and contentFrames[self._sectionIndex]._subsections
            local sub = subs and subs[self._childIndex]
            if sub and activeSubsection ~= sub.label then
                self._lbl:SetTextColor(secColor[1] * 0.62, secColor[2] * 0.62, secColor[3] * 0.62)
                self._bg:SetColorTexture(0, 0, 0, 0)
                self._branch:SetVertexColor(secColor[1], secColor[2], secColor[3], 0.58)
            end
        end)

        subsectionButtons[sectionIndex][childIndex] = btn
        return btn
    end

    local function ApplyNavigationVisuals()
        for i, btn in NS.ipairs(sectionButtons) do
            local active = i == activeSection
            btn._lbl:SetTextColor(NS.unpack(active and T.TEXT or T.TEXT_DIM))
            btn._bg:SetColorTexture(1, 1, 1, active and 0.045 or 0)
        end
        for sectionIndex, btnList in NS.pairs(subsectionButtons) do
            local subs = contentFrames[sectionIndex]._subsections or {}
            for childIndex, btn in NS.ipairs(btnList) do
                local sub = subs[childIndex]
                btn:SetShown(sectionIndex == activeSection and sub ~= nil)
                local active = sub and activeSubsection == sub.label
                btn._lbl:SetTextColor(NS.unpack(active and T.TEXT or T.TEXT_DIM))
                btn._bg:SetColorTexture(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3], active and 0.12 or 0)
            end
        end
        local activeRow = sectionButtons[activeSection]
        if activeRow then
            indicator:SetWidth(activeRow:GetWidth() - 12)
            indicatorTargetX = activeRow._xOff + 6
            if animFrame and NS.db.cfgAnimTransitions and math.abs(indicatorCurrentX - indicatorTargetX) > 0.3 then
                animFrame:Show()
            else
                indicatorCurrentX = indicatorTargetX
                indicator:ClearAllPoints()
                indicator:SetPoint("BOTTOMLEFT", tabBar, "BOTTOMLEFT", indicatorCurrentX, 0)
            end
        end
    end

    RefreshNavigationLayout = function(animateIndicator)
        local tabW = (f:GetWidth() - 24) / #SECTIONS
        for i, btn in NS.ipairs(sectionButtons) do
            local xOff = 12 + (i - 1) * tabW
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", xOff, 0)
            btn:SetSize(tabW, BTN_H)
            btn._xOff, btn._height = xOff, BTN_H
        end
        local subs = contentFrames[activeSection]._subsections or {}
        for childIndex, sub in NS.ipairs(subs) do
            local childBtn = EnsureSubsectionButton(activeSection, childIndex)
            childBtn:ClearAllPoints()
            childBtn:SetPoint("TOPLEFT", 0, -(childIndex - 1) * CHILD_H)
            childBtn:SetSize(248, CHILD_H)
            childBtn._lbl:SetText(sub.label)
        end
        sectionMenuContent:SetHeight(math.max(CHILD_H, #subs * CHILD_H))
        sectionMenu:SetHeight(math.min(#subs * CHILD_H + 12, f:GetHeight() - titleH - navH - statusH - 63))
        sectionMenuScroll:SetVerticalScroll(0)
        sectionJump:SetShown(#subs > 0)
        if not animateIndicator then indicatorCurrentX = indicatorTargetX end
        ApplyNavigationVisuals()
    end
    SelectSection = function(idx, keepSubsection)
        sectionMenu:Hide()
        if searchMode then
            searchMode = false
            searchResultsFrame:Hide()
        end

        if contentFrames[activeSection] then
            contentFrames[activeSection]:Hide()
        end

        activeSection = idx
        if not keepSubsection then
            activeSubsection = nil
        end
        NS._activeSection = idx

        local cf = contentFrames[idx]
        if cf and cf._subsections and #cf._subsections > 0 then
            local targetSub
            if activeSubsection then
                for i = 1, #cf._subsections do
                    if cf._subsections[i].label == activeSubsection then
                        targetSub = cf._subsections[i]
                        break
                    end
                end
            end
            if not targetSub then
                local firstSub = cf._subsections[1]
                if firstSub and (firstSub.kind == "page" or firstSub.onSelect or cf._onSubsectionSelected) then
                    targetSub = firstSub
                    activeSubsection = firstSub.label
                end
            end
            if targetSub and (targetSub.kind == "page" or targetSub.onSelect or cf._onSubsectionSelected) then
                if targetSub.onSelect then
                    targetSub.onSelect(targetSub, cf)
                elseif cf._onSubsectionSelected then
                    cf._onSubsectionSelected(targetSub.label, targetSub)
                end
            end
        end
        ApplySectionWindowSize(idx)
        scrollChild:SetHeight(cf._contentH or 100)
        if NS._restoreScroll then
            scrollFrame:SetVerticalScroll(NS._restoreScroll)
            NS._restoreScroll = nil
        else
            scrollFrame:SetVerticalScroll(0)
        end
        -- Settings must be readable immediately, including selections made
        -- while the window is hidden. Animate only the navigation indicator.
        cf:SetAlpha(1)
        cf:Show()

        if cf._refresh then
            cf._refresh()
        end

        local dc = SECTIONS[idx].dotColor
        sectionTitle:SetText(SECTIONS[idx].label)
        sectionTitle:SetTextColor(NS.unpack(T.TEXT))
        titleUnderline:SetColorTexture(T.BORDER[1], T.BORDER[2], T.BORDER[3], 0.35)
        indicator:SetColorTexture(dc[1], dc[2], dc[3], 0.9)

        RefreshNavigationLayout(true)
        UpdateScrollbar()
    end

    local TAB_LABELS = { "Combat", "Style", "Button", "Priority", "Talents", "Visibility", "Colors", "Advanced", "Profiles" }
    for i, sec in NS.ipairs(SECTIONS) do
        local btn = NS.CreateFrame("Button", nil, tabBar)

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0)

        local dc = sec.dotColor

        local lbl = btn:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(NS.GetConfigFontPath(), 10, "")
        lbl:SetPoint("LEFT", 4, 0)
        lbl:SetPoint("RIGHT", -4, 0)
        lbl:SetJustifyH("CENTER")
        lbl:SetWordWrap(false)
        lbl:SetMaxLines(1)
        lbl:SetTextColor(dc[1] * 0.7, dc[2] * 0.7, dc[3] * 0.7)
        lbl:SetText(TAB_LABELS[i])

        btn._bg = bg
        btn._lbl = lbl
        btn._dotColor = dc
        NS.AddTooltip(btn, sec.label, {})

        btn:SetScript("OnClick", function()
            SelectSection(i)
        end)
        btn:SetScript("OnEnter", function()
            if i ~= activeSection then
                lbl:SetTextColor(NS.unpack(T.TEXT))
                bg:SetColorTexture(T.BG_HOVER[1], T.BG_HOVER[2], T.BG_HOVER[3], 0.25)
            end
        end)
        btn:SetScript("OnLeave", function()
            if i ~= activeSection then
                lbl:SetTextColor(NS.unpack(T.TEXT_DIM))
                bg:SetColorTexture(0, 0, 0, 0)
            end
        end)

        sectionButtons[i] = btn
    end

    ----------------------------------------------------------------
    -- Search lives in the toolbar, independent of the selected page.
    ----------------------------------------------------------------
    local searchBox = NS.CreateFrame("EditBox", nil, titleBar, "BackdropTemplate")
    searchBox:SetSize(180, 24)
    searchBox:SetPoint("LEFT", 182, 0)
    searchBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    searchBox:SetBackdropColor(NS.unpack(T.BG))
    searchBox:SetBackdropBorderColor(NS.unpack(T.BORDER_ACCENT))
    searchBox:SetFont(NS.GetConfigFontPath(), 11, "")
    searchBox:SetTextColor(NS.unpack(T.TEXT))
    searchBox:SetTextInsets(6, 6, 0, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(30)

    local searchPlaceholder = searchBox:CreateFontString(nil, "OVERLAY")
    searchPlaceholder:SetFont(NS.GetConfigFontPath(), 11, "")
    searchPlaceholder:SetPoint("LEFT", 6, 0)
    searchPlaceholder:SetTextColor(NS.unpack(T.TEXT_MUTED))
    searchPlaceholder:SetText("Find a setting...")

    local function DoSearch(query)
        query = query:lower()
        if query == "" then
            -- Exit search mode → restore active section
            if searchMode then
                searchMode = false
                searchResultsFrame:Hide()
                ApplySectionWindowSize(activeSection)
                RefreshNavigationLayout(false)
                contentFrames[activeSection]:Show()
                local sec = SECTIONS[activeSection]
                sectionTitle:SetText(sec.label)
                sectionTitle:SetTextColor(NS.unpack(T.TEXT))
                sectionJump:SetShown(#(contentFrames[activeSection]._subsections or {}) > 0)
                scrollChild:SetHeight(contentFrames[activeSection]._contentH or 100)
                scrollFrame:SetVerticalScroll(0)
                UpdateScrollbar()
            end
            return
        end

        -- Enter search mode
        if not searchMode then
            contentFrames[activeSection]:Hide()
            searchMode = true
        end

        ApplySectionWindowSize(nil)
        RefreshNavigationLayout(false)

        sectionTitle:SetText("Search settings")
        sectionTitle:SetTextColor(NS.unpack(T.TEXT))
        sectionMenu:Hide()
        sectionJump:Hide()

        -- Hide all entries first
        for i = 1, MAX_RESULTS do
            resultEntries[i]:Hide()
        end

        -- Show the results container BEFORE populating entries
        -- (WoW requires parent visible for child rendering in ScrollFrames)
        searchResultsFrame:Show()

        -- Collect matches grouped by section number
        local grouped = {}  -- section index → list of settingsIndex entries
        local sectionOrder = {}  -- ordered list of section indices with matches
        local sectionSeen = {}

        for _, si in NS.ipairs(settingsIndex) do
            if si.label:lower():find(query, 1, true) then
                local sec = si.section
                if not sectionSeen[sec] then
                    sectionSeen[sec] = true
                    sectionOrder[#sectionOrder + 1] = sec
                    grouped[sec] = {}
                end
                if not si.isSection then
                    grouped[sec][#grouped[sec] + 1] = si
                end
            end
        end

        -- Helper: reset all visual extras on a result entry
        local function ResetEntry(re)
            re._bar:Hide()
            re._dot:Hide()
            re._matchLbl:Hide()
            re._sep:Hide()
            re._hl:SetAllPoints()
            re._hl:SetColorTexture(T.BG_HOVER[1], T.BG_HOVER[2], T.BG_HOVER[3], 0.3)
            re._hl:Show()
            re:EnableMouse(true)
            re:SetScript("OnEnter", nil)
            re:SetScript("OnLeave", nil)
            re:SetScript("OnClick", nil)
        end

        -- Render grouped results: section header → indented child results
        local rowIdx = 0
        local rowY = -8
        local ROW_H = 24
        local isFirstSection = true

        for _, secIdx in NS.ipairs(sectionOrder) do
            local secDC = SECTIONS[secIdx].dotColor
            local secLabel = SECTIONS[secIdx].label
            local entries = grouped[secIdx]

            -- Section header row (non-clickable, colored, with accent bar)
            rowIdx = rowIdx + 1
            if rowIdx > MAX_RESULTS then break end

            -- Add separator between section groups (not before first)
            if not isFirstSection then
                rowY = rowY - 6  -- extra spacing between groups
            end
            isFirstSection = false

            local hdr = resultEntries[rowIdx]
            ResetEntry(hdr)
            hdr:ClearAllPoints()
            hdr:SetPoint("TOPLEFT", 14, rowY)
            hdr._lbl:ClearAllPoints()
            hdr._lbl:SetPoint("LEFT", 8, 0)
            hdr._lbl:SetFont(NS.GetConfigFontPath(), 10, "OUTLINE")
            hdr._lbl:SetText(secLabel)
            hdr._lbl:SetTextColor(secDC[1], secDC[2], secDC[3])
            -- Left accent bar in section color
            hdr._bar:SetColorTexture(secDC[1], secDC[2], secDC[3], 0.8)
            hdr._bar:Show()
            -- Separator above (except first)
            if rowIdx > 1 then
                hdr._sep:SetColorTexture(secDC[1], secDC[2], secDC[3], 0.15)
                hdr._sep:Show()
            end
            hdr._hl:Hide()
            hdr:SetScript("OnClick", nil)
            hdr:EnableMouse(false)
            hdr:Show()
            rowY = rowY - ROW_H

            -- Child result rows (indented, clickable, with dot + hover color)
            for _, si in NS.ipairs(entries) do
                rowIdx = rowIdx + 1
                if rowIdx > MAX_RESULTS then break end
                local re = resultEntries[rowIdx]
                ResetEntry(re)
                re:ClearAllPoints()
                re:SetPoint("TOPLEFT", 14, rowY)

                -- Section-colored dot
                re._dot:SetColorTexture(secDC[1], secDC[2], secDC[3], 0.7)
                re._dot:Show()

                -- Left accent bar (subtle, dimmer than header)
                re._bar:SetColorTexture(secDC[1], secDC[2], secDC[3], 0.25)
                re._bar:Show()

                -- Label positioned after dot
                re._lbl:ClearAllPoints()
                re._lbl:SetPoint("LEFT", 16, 0)
                re._lbl:SetFont(NS.GetConfigFontPath(), 10, "")
                re._lbl:SetTextColor(NS.unpack(T.TEXT))

                -- Highlight matched text portion in accent color
                local labelLower = si.label:lower()
                local matchStart, matchEnd = labelLower:find(query, 1, true)
                if matchStart then
                    -- Build colored label: prefix + |cFF colored match + |r suffix
                    local prefix = si.label:sub(1, matchStart - 1)
                    local matched = si.label:sub(matchStart, matchEnd)
                    local suffix = si.label:sub(matchEnd + 1)
                    local cr = math.floor(secDC[1] * 255)
                    local cg = math.floor(secDC[2] * 255)
                    local cb = math.floor(secDC[3] * 255)
                    local hexColor = string.format("%02x%02x%02x", cr, cg, cb)
                    re._lbl:SetText(prefix .. "|cFF" .. hexColor .. matched .. "|r" .. suffix)
                else
                    re._lbl:SetText(si.label)
                end

                -- Section-colored highlight on hover
                re._hl:SetColorTexture(secDC[1], secDC[2], secDC[3], 0.12)
                re:SetScript("OnEnter", function()
                    re._lbl:SetTextColor(secDC[1], secDC[2], secDC[3])
                    re._bar:SetColorTexture(secDC[1], secDC[2], secDC[3], 0.7)
                    re._dot:SetColorTexture(secDC[1], secDC[2], secDC[3], 1.0)
                end)
                re:SetScript("OnLeave", function()
                    re._lbl:SetTextColor(NS.unpack(T.TEXT))
                    re._bar:SetColorTexture(secDC[1], secDC[2], secDC[3], 0.25)
                    re._dot:SetColorTexture(secDC[1], secDC[2], secDC[3], 0.7)
                end)
                re:SetScript("OnClick", function()
                    searchBox:SetText("")
                    searchBox:ClearFocus()
                    SelectSection(si.section)
                    -- Find and scroll to make the widget visible, then highlight
                    local cf = contentFrames[si.section]
                    local targetY, widget = FindWidgetYByLabel(cf, si.label)
                    if targetY then
                        -- Scroll just enough to place the widget in view
                        local widgetTop = -targetY
                        local viewH = scrollFrame:GetHeight()
                        local maxScroll = math.max(0, (cf._contentH or 100) - viewH)
                        local desiredScroll = math.max(0, math.min(maxScroll, widgetTop - viewH * 0.3))
                        suppressScrollDismiss = true
                        scrollFrame:SetVerticalScroll(desiredScroll)
                        suppressScrollDismiss = false
                        ShowSearchHighlight(cf, targetY, widget)
                        UpdateScrollbar()
                    end
                end)
                re:Show()
                rowY = rowY - ROW_H
            end
            if rowIdx > MAX_RESULTS then break end
        end

        -- "No results" message
        if rowIdx == 0 then
            rowIdx = 1
            local re = resultEntries[1]
            ResetEntry(re)
            re:ClearAllPoints()
            re:SetPoint("TOPLEFT", 14, -8)
            re._lbl:ClearAllPoints()
            re._lbl:SetPoint("LEFT", 0, 0)
            re._lbl:SetFont(NS.GetConfigFontPath(), 10, "")
            re._lbl:SetText("No matching settings")
            re._lbl:SetTextColor(NS.unpack(T.TEXT_MUTED))
            re._hl:Hide()
            re:EnableMouse(false)
            rowY = -8 - ROW_H
        end

        local resultsH = math.abs(rowY) + 8
        searchResultsFrame:SetHeight(resultsH)
        scrollChild:SetHeight(math.max(50, resultsH))
        scrollFrame:SetVerticalScroll(0)
        UpdateScrollbar()
    end

    searchBox:SetScript("OnTextChanged", function(self)
        searchPlaceholder:SetShown(self:GetText() == "")
        DoSearch(self:GetText())
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)

    -- Clear search when panel hides
    f:HookScript("OnHide", function()
        searchBox:SetText("")
        searchBox:ClearFocus()
        DismissSearchHighlight()
        animFrame:Hide()
        indicatorCurrentX = indicatorTargetX
    end)

    ----------------------------------------------------------------
    -- Animations (indicator slide)
    -- Only runs while the indicator is actively sliding, then stops.
    ----------------------------------------------------------------
    animFrame = NS.CreateFrame("Frame", nil, f)
    animFrame:SetScript("OnUpdate", function(self, elapsed)
        local diff = indicatorTargetX - indicatorCurrentX
        if math.abs(diff) > 0.3 then
            indicatorCurrentX = indicatorCurrentX + diff * math.min(1, elapsed * 14)
        else
            indicatorCurrentX = indicatorTargetX
            self:Hide()  -- done sliding, stop running
        end
        indicator:ClearAllPoints()
        indicator:SetPoint("BOTTOMLEFT", tabBar, "BOTTOMLEFT", indicatorCurrentX, 0)
    end)
    animFrame:Hide()  -- start hidden, only shown when indicator needs to move

    ----------------------------------------------------------------
    -- Initialize
    ----------------------------------------------------------------
    SelectSection(NS._restoreSection or 1)
    NS._restoreSection = nil
    -- Expose SelectSection and scrollFrame for external use (screenshots, etc.)
    self.SelectSection = SelectSection
    self.scrollFrame = scrollFrame

    self.frame = f
    self._refreshPixelLines = function()
        if not PixelUtil then return end
        PixelUtil.SetHeight(divider, 1, 1)
        PixelUtil.SetPoint(divider, "BOTTOMLEFT", tabBar, "BOTTOMLEFT", 12, 0)
        PixelUtil.SetPoint(divider, "BOTTOMRIGHT", tabBar, "BOTTOMRIGHT", -12, 0)
        PixelUtil.SetHeight(indicator, 2, 1)
        PixelUtil.SetHeight(titleUnderline, 1, 1)
        PixelUtil.SetPoint(titleUnderline, "TOPLEFT", f, "TOPLEFT", 14, -titleH - navH - sectionHeaderH + 9)
        PixelUtil.SetPoint(titleUnderline, "RIGHT", f, "RIGHT", -14, 0)
        for _, line in ipairs(subHeaderLines) do
            PixelUtil.SetHeight(line, 1, 1)
            -- Keep each divider's original header anchor. Several sections
            -- build headers directly and do not populate line._header.
        end
    end
    f:HookScript("OnShow", function()
        f:RegisterEvent("DISPLAY_SIZE_CHANGED")
        f:RegisterEvent("UI_SCALE_CHANGED")
        self:ApplyScale()
    end)
    f:HookScript("OnHide", function()
        f:UnregisterEvent("DISPLAY_SIZE_CHANGED")
        f:UnregisterEvent("UI_SCALE_CHANGED")
    end)
    f:SetScript("OnEvent", function()
        if f:IsShown() then self:ApplyScale() end
    end)
    self:ApplyScale()
    return f
end

----------------------------------------------------------------
-- Toggle config panel
----------------------------------------------------------------
function NS.Config:Toggle()
    if not self.frame then
        self:Create()
    end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
    end
end

function NS.Config:Show()
    if not self.frame then self:Create() end
    self.frame:Show()
end

function NS.Config:Hide()
    if self.frame then self.frame:Hide() end
end
