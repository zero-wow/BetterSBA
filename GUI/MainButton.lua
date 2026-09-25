local ADDON_NAME, NS = ...

local T = NS.THEME
local ticker
local wasOnSpecialBar = false
local lastRescanTime = nil
local PRESS_DURATION = 0.09

local function Clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

-- All values use UIParent coordinates. Keep the same point of the button under
-- the cursor while clamping its visible rectangle to the screen.
function NS.CalculateCursorAnchoredButtonPosition(cursorX, cursorY, oldLeft, oldBottom,
    oldWidth, oldHeight, newWidth, newHeight, screenWidth, screenHeight)
    if not oldWidth or oldWidth <= 0 or not oldHeight or oldHeight <= 0
        or not newWidth or newWidth <= 0 or not newHeight or newHeight <= 0
        or not screenWidth or screenWidth <= 0 or not screenHeight or screenHeight <= 0 then
        return nil
    end
    local across = Clamp((cursorX - oldLeft) / oldWidth, 0, 1)
    local up = Clamp((cursorY - oldBottom) / oldHeight, 0, 1)
    local left = Clamp(cursorX - across * newWidth, 0,
        math.max(0, screenWidth - newWidth))
    local bottom = Clamp(cursorY - up * newHeight, 0,
        math.max(0, screenHeight - newHeight))
    return left, bottom
end

local function LayoutPauseVisual(button)
    local pause = button and button.pauseOverlay
    if not pause then return end
    local size = button:GetWidth()
    local barHeight = math.min(math.floor(size * 0.58),
        math.max(11, math.floor((NS.db.pauseSymbolFontSize or 14) * 1.15)))
    local barWidth = math.max(3, math.floor(barHeight * 0.23))
    local gap = math.max(3, math.floor(barWidth * 0.9))
    for i, bar in ipairs(pause.bars) do
        local x = i == 1 and -(gap / 2 + barWidth) or gap / 2
        bar.shadow:SetSize(barWidth + 2, barHeight + 2)
        bar.shadow:ClearAllPoints()
        bar.shadow:SetPoint("CENTER", pause, "CENTER", x + 1, -1)
        bar.fill:SetSize(barWidth, barHeight)
        bar.fill:ClearAllPoints()
        bar.fill:SetPoint("CENTER", pause, "CENTER", x, 0)
    end
    local emblem = NS.db.pauseSymbolStyle ~= "Text"
    pause.symbolText:SetShown(not emblem)
    for _, bar in ipairs(pause.bars) do
        bar.shadow:SetShown(emblem)
        bar.fill:SetShown(emblem)
    end
end

local function ClearButtonPressVisual(button)
    if not button then return end
    button._pressUntil = nil
    button._pressHeld = nil
    button._pressStartedAt = nil
    button._pressSpellID = nil
    button:SetButtonState("NORMAL")
    if button._pressVisualActive then
        button._pressVisualActive = nil
        button:SetScript("OnUpdate", nil)
    end
end

local function PressVisualOnUpdate(self)
    if self._pressHeld then return end
    local untilTime = self._pressUntil
    if not untilTime or GetTime() >= untilTime then
        ClearButtonPressVisual(self)
    end
end

local function StartButtonPressVisual(button, spellID, held)
    if not button then return end
    button._pressSpellID = spellID or button.spellID
    if held then
        button._pressHeld = true
        button._pressStartedAt = GetTime()
        button._pressUntil = nil
    else
        button._pressHeld = nil
        button._pressStartedAt = nil
        button._pressUntil = GetTime() + PRESS_DURATION
    end
    button:SetButtonState("PUSHED", true)
    if held then
        if button._pressVisualActive then
            button:SetScript("OnUpdate", nil)
        else
            button._pressVisualActive = true
        end
    elseif not button._pressVisualActive then
        button._pressVisualActive = true
        button:SetScript("OnUpdate", PressVisualOnUpdate)
    elseif not button._pressHeld then
        button:SetScript("OnUpdate", PressVisualOnUpdate)
    end
end

local function ReleaseButtonPressVisual(button)
    if not button then return end
    if not button._pressHeld then
        ClearButtonPressVisual(button)
        return
    end
    local startedAt = button._pressStartedAt or GetTime()
    local elapsed = GetTime() - startedAt
    local remaining = PRESS_DURATION - elapsed
    button._pressHeld = nil
    button._pressStartedAt = nil
    if remaining > 0 then
        button._pressUntil = GetTime() + remaining
        button:SetButtonState("PUSHED", true)
        button._pressVisualActive = true
        button:SetScript("OnUpdate", PressVisualOnUpdate)
    else
        ClearButtonPressVisual(button)
    end
end

function NS.ClearButtonPressVisual(button)
    ClearButtonPressVisual(button)
end

function NS.StartButtonPressVisual(button, spellID, held)
    StartButtonPressVisual(button, spellID, held)
end

function NS.PlayRecommendationPressVisual(spellID, held)
    local btn = NS.mainButton
    if btn then
        StartButtonPressVisual(btn, spellID, held)
    end
    if not spellID then return end
    local icons = NS._priorityIcons
    if not icons then return end
    for i = 1, #icons do
        local icon = icons[i]
        if icon and icon:IsShown() then
            if icon.spellID == spellID then
                StartButtonPressVisual(icon, spellID, held)
                break
            end
        end
    end
end

function NS.ClearRecommendationPressVisual()
    if NS.mainButton then
        ClearButtonPressVisual(NS.mainButton)
    end
    local icons = NS._priorityIcons
    if not icons then return end
    for i = 1, #icons do
        local icon = icons[i]
        if icon and icon._pressVisualActive then
            ClearButtonPressVisual(icon)
        end
    end
end

function NS.ReleaseRecommendationPressVisual()
    if NS.mainButton then
        ReleaseButtonPressVisual(NS.mainButton)
    end
    local icons = NS._priorityIcons
    if not icons then return end
    for i = 1, #icons do
        local icon = icons[i]
        if icon and icon._pressVisualActive then
            ReleaseButtonPressVisual(icon)
        end
    end
end

----------------------------------------------------------------
-- Create the main button (display + secure overlay)
----------------------------------------------------------------
function NS:CreateMainButton()
    local db = self.db
    local size = db.buttonSize

    -- Display button (regular Button — clean for Masque skinning)
    local btn = NS.CreateFrame("Button", "BetterSBA_Display", NS.UIParent)
    btn:SetSize(size, size)
    btn:SetScale(db.scale)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(5)
    btn:SetClampedToScreen(true)
    btn:SetMovable(true)

    -- Border + background: SetColorTexture (GPU-native color) instead of
    -- BackdropTemplate + WHITE8X8, which can flash white during rendering hiccups.
    btn.borderTex = btn:CreateTexture(nil, "BACKGROUND")
    btn.borderTex:SetAllPoints()
    btn.borderTex:SetColorTexture(T.BORDER[1], T.BORDER[2], T.BORDER[3], 1)

    btn.bg = btn:CreateTexture(nil, "BACKGROUND", nil, 1)
    btn.bg:SetPoint("TOPLEFT", 1, -1)
    btn.bg:SetPoint("BOTTOMRIGHT", -1, 1)
    btn.bg:SetColorTexture(db.buttonBgColor[1], db.buttonBgColor[2], db.buttonBgColor[3], db.buttonBgColor[4] or 0.6)

    -- Icon
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    if NS.masque then
        -- Let Masque handle icon positioning and TexCoord
        btn.icon:SetAllPoints()
    else
        -- Our 1px inset for the backdrop border
        btn.icon:SetPoint("TOPLEFT", 1, -1)
        btn.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        btn.icon:SetTexCoord(NS.unpack(NS.ICON_TEXCOORD))
    end

    btn.pushedTex = btn:CreateTexture(nil, "ARTWORK", nil, 1)
    btn.pushedTex:SetColorTexture(0, 0, 0, 0.35)
    btn.pushedTex:SetAllPoints(btn.icon)
    btn:SetPushedTexture(btn.pushedTex)

    -- Cooldown
    btn.cooldown = NS.CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints(btn.icon)
    btn.cooldown:SetDrawEdge(false)
    btn.cooldown:SetHideCountdownNumbers(false)

    -- Keybind text (per-context font)
    btn.hotkey = btn:CreateFontString(nil, "OVERLAY")
    btn.hotkey:SetFont(
        NS.ResolveFontPath("keybindFont"),
        db.keybindFontSize,
        NS.ResolveFontOutline("keybindFont", "keybindOutline"))
    btn.hotkey:SetPoint(db.keybindAnchor or "TOPRIGHT", db.keybindOffsetX or -5, db.keybindOffsetY or -5)
    btn.hotkey:SetTextColor(0.9, 0.9, 0.9, 1)

    -- A quiet translucent scrim keeps the spell recognizable. The simple
    -- pause mark reads cleanly without another badge over the icon.
    local pauseGroup = NS.CreateFrame("Frame", nil, btn)
    pauseGroup:SetAllPoints()
    pauseGroup:SetFrameLevel(btn:GetFrameLevel() + 3)
    pauseGroup:Hide()

    local pauseBg = pauseGroup:CreateTexture(nil, "ARTWORK", nil, 1)
    pauseGroup.background = pauseBg
    pauseBg:SetColorTexture(0.025, 0.03, 0.065, 0.32)
    pauseBg:SetAllPoints(btn.icon)
    pauseGroup.bars = {}
    for i = 1, 2 do
        local shadow = pauseGroup:CreateTexture(nil, "ARTWORK", nil, 2)
        shadow:SetColorTexture(0.01, 0.01, 0.025, 0.9)
        local fill = pauseGroup:CreateTexture(nil, "OVERLAY")
        fill:SetColorTexture(0.94, 0.95, 1, 0.98)
        pauseGroup.bars[i] = { shadow = shadow, fill = fill }
    end

    local pauseText = pauseGroup:CreateFontString(nil, "OVERLAY")
    pauseText:SetFont(
        NS.ResolveFontPath("pauseSymbolFont"),
        db.pauseSymbolFontSize or 14,
        NS.ResolveFontOutline("pauseSymbolFont", "pauseSymbolOutline"))
    pauseText:SetText("II")
    pauseText:SetTextColor(0.94, 0.95, 1, 1)
    pauseText:SetPoint("CENTER")
    local pauseReason = pauseGroup:CreateFontString(nil, "OVERLAY")
    pauseReason:SetFont(
        NS.ResolveFontPath("pauseReasonFont"),
        db.pauseReasonFontSize or 9,
        NS.ResolveFontOutline("pauseReasonFont", "pauseReasonOutline"))
    pauseReason:SetTextColor(0.94, 0.95, 1, 1)
    pauseReason:SetShadowColor(0, 0, 0, 0.95)
    pauseReason:SetShadowOffset(1, -1)
    pauseReason:SetPoint("TOP", btn, "BOTTOM", 0, -3)
    pauseReason:SetWordWrap(false)
    pauseReason:SetMaxLines(1)
    pauseGroup.symbolText = pauseText
    pauseGroup.reasonText = pauseReason

    btn.pauseOverlay = pauseGroup
    LayoutPauseVisual(btn)

    -- Current spell ID
    btn.spellID = nil

    ----------------------------------------------------------------
    -- Secure overlay (sibling, not child — avoids protected frame taint)
    ----------------------------------------------------------------
    local secure = NS.CreateFrame("Button", "BetterSBA_MainButton", NS.UIParent,
        "SecureActionButtonTemplate")
    secure:SetAllPoints(btn)
    secure:SetFrameStrata("MEDIUM")
    secure:SetFrameLevel(btn:GetFrameLevel() + 10)
    secure:RegisterForDrag("LeftButton")

    -- Register for BOTH down and up clicks — critical for SetOverrideBindingClick
    -- In Midnight (12.x), override bindings fire based on ActionButtonUseKeyDown CVar.
    -- If we only register for "Up" (template default), key-down clicks are silently consumed.
    secure:RegisterForClicks("AnyDown", "AnyUp")

    -- Secure macro action
    secure:SetAttribute("type", "macro")
    secure:SetAttribute("macrotext", NS.BuildMacroText())

    -- Hide ALL template-created visual elements so they don't render
    local secureName = secure:GetName()
    for _, suffix in NS.ipairs({"Icon", "Flash", "Count", "Border", "Name", "NewActionTexture", "HotKey"}) do
        local region = _G[secureName .. suffix]
        if region then
            if region.SetTexture then region:SetTexture(nil) end
            if region.SetText then region:SetText("") end
            region:Hide()
        end
    end
    local pushed = secure:GetPushedTexture()
    if pushed then pushed:SetAlpha(0) end
    local highlight = secure:GetHighlightTexture()
    if highlight then highlight:SetAlpha(0) end
    local normal = secure:GetNormalTexture()
    if normal then normal:SetAlpha(0) end

    -- Drag handling (moves the display button)
    secure:SetScript("OnDragStart", function()
        if not NS.db.locked and not NS.InCombatLockdown() then
            btn:StartMoving()
        end
    end)
    secure:SetScript("OnDragStop", function()
        btn:StopMovingOrSizing()
        local p, _, rp, x, y = btn:GetPoint()
        NS.db.position = { point = p, relPoint = rp, x = x, y = y }
    end)

    -- Tooltip
    secure:SetScript("OnEnter", function()
        if NS.SetButtonHover then NS.SetButtonHover(btn, true) end
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        if btn.spellID then
            GameTooltip:SetSpellByID(btn.spellID)
            GameTooltip:AddLine(" ")
        end
        GameTooltip:AddLine("BetterSBA", T.ACCENT[1], T.ACCENT[2], T.ACCENT[3])
        if not NS.db.locked then
            GameTooltip:AddLine("Drag to move | /bs lock", 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    secure:SetScript("OnLeave", function()
        if NS.SetButtonHover then NS.SetButtonHover(btn, false) end
        GameTooltip:Hide()
    end)

    secure:SetScript("OnMouseDown", function()
        if NS.PlayRecommendationPressVisual then
            NS.PlayRecommendationPressVisual(btn.spellID, true)
        end
        if NS.StartInterceptBarPressVisual then
            NS.StartInterceptBarPressVisual(true)
        end
    end)

    secure:SetScript("OnMouseUp", function()
        if NS.ReleaseRecommendationPressVisual then
            NS.ReleaseRecommendationPressVisual()
        end
        if NS.ReleaseInterceptBarPressVisual then
            NS.ReleaseInterceptBarPressVisual()
        end
    end)

    -- Debug: PreClick fires BEFORE the macro executes
    secure:SetScript("PreClick", function(self, button, down)
        if not NS.IsDebugChannelEnabled or not NS.IsDebugChannelEnabled("other") then return end
        local macro = self:GetAttribute("macrotext") or ""
        local spellName = btn.spellID and NS.C_Spell and NS.C_Spell.GetSpellName
            and NS.C_Spell.GetSpellName(btn.spellID)
        NS.DebugPrintAlways("--- |cFF44FF44INTERCEPTED CLICK|r (keybind → BetterSBA_MainButton) ---")
        NS.DebugPrintAlways("Executing macro:")
        for line in macro:gmatch("[^\n]+") do
            NS.DebugPrintAlways("  |cFFFFCC00>|r", line)
        end
        if spellName then
            NS.DebugPrintAlways("  Display spell:", spellName, "(ID:", btn.spellID, ")")
        else
            NS.DebugPrintAlways("  Display spell: |cFFFF4444none|r")
        end
        -- Target state
        local hasTarget = NS.UnitExists("target")
        local targetHarmful = hasTarget and NS.UnitCanAttack("player", "target")
        local targetDead = hasTarget and NS.UnitIsDead("target")
        NS.DebugPrintAlways("  Target:", hasTarget and "yes" or "|cFFFF4444no|r",
            "| Hostile:", targetHarmful and "yes" or "no",
            "| Dead:", targetDead and "yes" or "no")
        -- /targetenemy analysis
        if macro:find("/targetenemy") then
            if not hasTarget or not targetHarmful or targetDead then
                NS.DebugPrintAlways("  |cFF44FF44/targetenemy WILL fire|r (condition met: [noharm] or [dead])")
            else
                NS.DebugPrintAlways("  /targetenemy skipped (have valid hostile target)")
            end
        else
            NS.DebugPrintAlways("  |cFFFF4444/targetenemy DISABLED|r in settings")
        end
        -- /petattack analysis
        if macro:find("/petattack") then
            local hasPet = NS.UnitExists("pet")
            if hasPet then
                NS.DebugPrintAlways("  |cFF44FF44/petattack WILL fire|r (pet exists)")
            else
                NS.DebugPrintAlways("  /petattack: |cFFFF4444no pet active|r")
            end
        else
            NS.DebugPrintAlways("  |cFFFF4444/petattack DISABLED|r in settings")
        end
        -- /stopmacro [channeling] analysis
        if macro:find("/stopmacro") then
            local channeling = UnitChannelInfo("player")
            if channeling then
                NS.DebugPrintAlways("  |cFFFF8800/stopmacro [channeling] WILL BLOCK|r cast (channeling:", channeling, ")")
            else
                NS.DebugPrintAlways("  /stopmacro [channeling]: not channeling, macro continues")
            end
        else
            NS.DebugPrintAlways("  |cFFFF4444/stopmacro DISABLED|r in settings")
        end
    end)

    -- Debug: PostClick fires AFTER the macro executes
    secure:SetScript("PostClick", function(self, button, down)
        if not NS.IsDebugChannelEnabled or not NS.IsDebugChannelEnabled("other") then return end
        local hasTarget = NS.UnitExists("target")
        NS.DebugPrintAlways("Macro done | Target:", hasTarget and "yes" or "no")
    end)

    -- Modifier+scroll scaling keeps the icon under the mouse. SetPoint offsets
    -- use the button's scale, while cursor and screen bounds use UIParent's.
    secure:EnableMouseWheel(true)
    secure:SetScript("OnMouseWheel", function(_, delta)
        if not NS.db.modifierScaling or not IsControlKeyDown()
            or NS.InCombatLockdown() then return end
        local oldScale = NS.db.scale or 1.0
        local scale = Clamp(oldScale + delta * 0.05, 0.5, 2.0)
        scale = tonumber(string.format("%.2f", scale))
        if scale == oldScale then return end

        local parent = NS.UIParent
        local parentScale = parent:GetEffectiveScale()
        local oldEffectiveScale = btn:GetEffectiveScale()
        local oldLeft, oldBottom = btn:GetLeft(), btn:GetBottom()
        local cursorX, cursorY = GetCursorPosition()
        if not parentScale or parentScale <= 0 or not oldEffectiveScale
            or oldEffectiveScale <= 0 or not oldLeft or not oldBottom
            or not cursorX or not cursorY then return end
        local oldRatio = oldEffectiveScale / parentScale
        local oldWidth = btn:GetWidth() * oldRatio
        local oldHeight = btn:GetHeight() * oldRatio
        local oldScreenLeft = oldLeft * oldRatio
        local oldScreenBottom = oldBottom * oldRatio

        NS.db.scale = scale
        NS.ApplyButtonSettings()
        local newRatio = btn:GetEffectiveScale() / parentScale
        local left, bottom = NS.CalculateCursorAnchoredButtonPosition(
            cursorX / parentScale, cursorY / parentScale,
            oldScreenLeft, oldScreenBottom, oldWidth, oldHeight,
            btn:GetWidth() * newRatio, btn:GetHeight() * newRatio,
            parent:GetWidth(), parent:GetHeight())
        if not left then return end
        local x, y = left / newRatio, bottom / newRatio
        btn:ClearAllPoints()
        btn:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, y)
        NS.db.position = { point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = x, y = y }
    end)

    -- Restore position
    if db.position then
        local pos = db.position
        btn:ClearAllPoints()
        btn:SetPoint(pos.point, NS.UIParent, pos.relPoint, pos.x, pos.y)
    else
        btn:SetPoint("CENTER", NS.UIParent, "CENTER", 0, -100)
    end

    self.mainButton = btn
    self.secureButton = secure

    -- Register display button with Masque (clean Button, no template conflicts)
    if NS.masqueMainGroup then
        -- Normal texture (border frame Masque expects)
        local normalTex = btn:CreateTexture()
        normalTex:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        normalTex:SetSize(size * 1.7, size * 1.7)
        normalTex:SetPoint("CENTER")
        btn:SetNormalTexture(normalTex)

        -- Pushed texture (pressed state)
        -- Highlight texture (mouseover state)
        local hlTex = btn:CreateTexture()
        hlTex:SetColorTexture(1, 1, 1, 0.15)
        hlTex:SetAllPoints(btn.icon)
        btn:SetHighlightTexture(hlTex)

        -- Flash texture (spell alert)
        local flashTex = btn:CreateTexture(nil, "OVERLAY")
        flashTex:SetColorTexture(1, 0, 0, 0.3)
        flashTex:SetAllPoints(btn.icon)
        flashTex:Hide()
        btn.Flash = flashTex

        -- Border texture (item quality / spell highlight)
        local borderTex = btn:CreateTexture(nil, "OVERLAY")
        borderTex:SetAllPoints(btn.icon)
        borderTex:Hide()
        btn.Border = borderTex

        btn._masqueRegions = {
            Icon = btn.icon,
            Cooldown = btn.cooldown,
            Normal = normalTex,
            Pushed = btn.pushedTex,
            Highlight = hlTex,
            Flash = flashTex,
            Border = borderTex,
            HotKey = btn.hotkey,
        }
        if not NS.UsesSoftButtonStyle() then
            NS.masqueMainGroup:AddButton(btn, btn._masqueRegions)
            btn._masqueRegistered = true
        end

        -- Masque handles appearance — hide our textures so they don't darken
        if btn.borderTex then btn.borderTex:Hide() end
        if btn.bg then btn.bg:Hide() end
    end

    NS.ApplyButtonStyle(btn)
    if NS.InitializeMotionFeedback then NS.InitializeMotionFeedback() end
    return btn
end

----------------------------------------------------------------
-- Update button visuals
----------------------------------------------------------------
local function UpdateButton(btn, spellID)
    if not spellID then
        ClearButtonPressVisual(btn)
        -- Check for action bar fallback texture
        if NS._fallbackTexture then
            btn.spellID = nil
            btn.icon:SetTexture(NS._fallbackTexture)
            btn.hotkey:SetText("")
            NS.UpdateButtonChrome(btn)
            btn.cooldown:Clear()
            btn.icon:SetVertexColor(1, 1, 1)
            btn.icon:SetDesaturated(false)
            return
        end
        btn.spellID = nil
        btn.icon:SetTexture(nil)
        btn.hotkey:SetText("")
        btn.cooldown:Clear()
        NS.UpdateButtonChrome(btn)
        return
    end

    btn.spellID = spellID

    -- Icon (cached — textures never change during gameplay)
    local tex = NS.GetSpellTextureCached(spellID)
    if tex then
        btn.icon:SetTexture(tex)
    end

    -- Keybind
    if NS.db.showKeybind then
        local key = NS.GetKeybindForSpell(spellID)
        btn.hotkey:SetText(key or "")
        btn.hotkey:Show()
    else
        btn.hotkey:Hide()
    end
    if NS.UpdateButtonChrome then NS.UpdateButtonChrome(btn) end

    if NS.db.showCooldown and NS.SetSpellCooldownVisual then
        NS.SetSpellCooldownVisual(btn.cooldown, spellID)
    else
        btn.cooldown:Clear()
    end

    -- Importance border color
    if NS.db.importanceBorders then
        local borderColor = NS.GetSpellBorderColor(spellID)
        if borderColor then
            if btn.Border then
                -- Masque: show and color the registered Border texture
                btn.Border:SetVertexColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
                btn.Border:Show()
            elseif btn.borderTex then
                btn.borderTex:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
            end
        else
            if btn.Border then
                btn.Border:Hide()
            elseif btn.borderTex then
                btn.borderTex:SetColorTexture(NS.THEME.BORDER[1], NS.THEME.BORDER[2], NS.THEME.BORDER[3], 1)
            end
        end
    else
        if btn.Border then
            btn.Border:Hide()
        elseif btn.borderTex then
            btn.borderTex:SetColorTexture(NS.THEME.BORDER[1], NS.THEME.BORDER[2], NS.THEME.BORDER[3], 1)
        end
    end

    -- Spell usability check (grey out when not usable — OOM, etc.)
    local usabilityDimmed = false
    if NS.db.spellUsability and C_Spell and C_Spell.IsSpellUsable then
        local isUsable = C_Spell.IsSpellUsable(spellID)
        if not (issecretvalue and issecretvalue(isUsable)) and isUsable == false then
            btn.icon:SetVertexColor(0.4, 0.4, 0.4)
            btn.icon:SetDesaturated(true)
            usabilityDimmed = true
        end
    end

    -- Range coloring (overrides usability dim if out of range)
    if not usabilityDimmed then
        if NS.db.rangeColoring and NS.C_Spell and NS.C_Spell.IsSpellInRange then
            local inRange = NS.C_Spell.IsSpellInRange(spellID, "target")
            if not (issecretvalue and issecretvalue(inRange)) and inRange == false then
                btn.icon:SetVertexColor(T.OUT_OF_RANGE[1], T.OUT_OF_RANGE[2], T.OUT_OF_RANGE[3])
                btn.icon:SetDesaturated(true)
                -- Out-of-range sound cue (throttled to avoid spam)
                if NS.db.outOfRangeSound then
                    local now = GetTime()
                    if not btn._lastRangeSound or (now - btn._lastRangeSound) > 1.0 then
                        btn._lastRangeSound = now
                        PlaySound(8959, "SFX") -- SOUNDKIT.IG_PLAYER_INVITE_DECLINE (subtle error beep)
                    end
                end
            else
                btn.icon:SetVertexColor(1, 1, 1)
                btn.icon:SetDesaturated(false)
                btn._lastRangeSound = nil
            end
        else
            btn.icon:SetVertexColor(1, 1, 1)
            btn.icon:SetDesaturated(false)
        end
    end
end

----------------------------------------------------------------
-- Visibility
----------------------------------------------------------------
local function UpdateVisibility()
    local btn = NS.mainButton
    if not btn then return end
    local db = NS.db
    local secure = NS.secureButton
    local inCombat = InCombatLockdown()

    -- Secure button must ALWAYS be shown for override keybind clicks to work
    -- (it's visually invisible — all template textures are stripped)
    if secure and not inCombat then
        secure:Show()
        local enabled = db.enabled == true
        if secure._inputEnabled ~= enabled then
            secure._inputEnabled = enabled
            secure:SetAttribute("type", enabled and "macro" or nil)
            secure:EnableMouse(enabled)
        end
    end

    -- Display button inherits protection from the secure button's anchor.
    -- During combat: NEVER call Show()/Hide() — use alpha only.
    -- Out of combat: Show() so the frame is visible, then use alpha.

    if not db.enabled then
        if NS.ResetMotionFeedback then NS.ResetMotionFeedback() end
        if inCombat then
            btn:SetAlpha(0)
        else
            btn:Hide()
        end
        return
    end

    if db.hideInVehicle and UnitInVehicle("player") then
        if NS.ResetMotionFeedback then NS.ResetMotionFeedback() end
        if inCombat then
            btn:SetAlpha(0)
        else
            btn:Hide()
        end
        return
    end

    if db.onlyInCombat and not inCombat then
        if NS.ResetMotionFeedback then NS.ResetMotionFeedback() end
        -- Ensure frame is shown (so alpha works when combat starts)
        btn:Show()
        btn:SetAlpha(0)
        return
    end

    if not inCombat then
        btn:Show()
    end
    -- Don't override alpha while a cast animation is hiding/fading the button
    if not NS._recreateFading then
        btn:SetAlpha(inCombat and db.alphaCombat or db.alphaOOC)
    end
end

----------------------------------------------------------------
-- Main update tick
----------------------------------------------------------------
local displayUpdateQueued = false
local function FlushDisplayUpdate()
    displayUpdateQueued = false
    NS.UpdateNow()
end

function NS.QueueDisplayUpdate()
    if displayUpdateQueued or not NS.db or not NS.db.enabled then return end
    displayUpdateQueued = true
    NS.C_Timer_After(0, FlushDisplayUpdate)
end

function NS.UpdateNow()
    local btn = NS.mainButton
    if not btn then return end
    if not NS.db.enabled then
        UpdateVisibility()
        if NS.UpdateLDBText then NS.UpdateLDBText() end
        if NS.UpdateManualCooldownReminder then NS.UpdateManualCooldownReminder() end
        return
    end

    -- Advance the per-frame cache generation so CollectNextSpell/CollectRotationSpells
    -- return cached results within this tick but refresh on the next one
    NS.BeginUpdate()

    -- Detect special bar / mounted → normal transition and re-establish keybind override
    local onSpecialBar = NS.IsInterceptBlocked and NS.IsInterceptBlocked()
    if wasOnSpecialBar and not onSpecialBar then
        wasOnSpecialBar = false
        if not NS.InCombatLockdown() then
            NS.ClearSBASlotCache()
            NS.ScanKeybinds()
            -- API may lag behind the event — schedule retries
            NS.C_Timer_After(0.5, function()
                if not NS._overrideKeys or #NS._overrideKeys == 0 then
                    NS.ClearSBASlotCache()
                    NS.ScanKeybinds()
                end
            end)
            NS.C_Timer_After(1.5, function()
                if not NS._overrideKeys or #NS._overrideKeys == 0 then
                    NS.ClearSBASlotCache()
                    NS.ScanKeybinds()
                end
            end)
        else
            NS._pendingKeybindOverride = true
        end
    elseif onSpecialBar then
        if not wasOnSpecialBar then
            -- Just entered special bar / mounted state — clear overrides NOW
            -- so the intercept is removed the same tick (no 0.5s delay).
            if not NS.InCombatLockdown() then
                NS.ScanKeybinds()
            end
        end
        wasOnSpecialBar = true
    end

    -- Self-healing: periodically verify keybind override is actually working.
    -- Catches stale state from skyriding/mount transitions where WoW clears
    -- our overrides but _overrideKeys still has the old keys.
    if NS.db.enabled and (NS.db.interceptionType or "Keybind") ~= "Click"
        and not onSpecialBar and not NS.InCombatLockdown() then
        local needsRescan = false
        if not NS._overrideKeys or #NS._overrideKeys == 0 then
            needsRescan = true
        elseif GetBindingAction then
            -- Verify WoW actually still has our override registered
            local action = GetBindingAction(NS._overrideKeys[1])
            if not action or not action:find("BetterSBA") then
                needsRescan = true
            end
        end
        if needsRescan then
            local now = GetTime()
            if not lastRescanTime or (now - lastRescanTime) > 1 then
                lastRescanTime = now
                NS.ClearSBASlotCache()
                NS.ScanKeybinds()
            end
        end
    end

    -- Pause overlay + LDB status sync (runs even when button is hidden/alpha 0
    -- so the LDB text and pause reason stay current during skyriding, etc.)
    if btn.pauseOverlay then
        local reason = NS.GetInterceptBlockReason and NS.GetInterceptBlockReason()
        if reason then
            btn.pauseOverlay:Show()
            if btn.pauseOverlay.currentReason ~= reason and btn.pauseOverlay.reasonText then
                btn.pauseOverlay.currentReason = reason
                btn.pauseOverlay.reasonText:SetText(reason)
                LayoutPauseVisual(btn)
            end
        else
            btn.pauseOverlay:Hide()
            btn.pauseOverlay.currentReason = nil
            if btn.pauseOverlay.reasonText then
                btn.pauseOverlay.reasonText:SetText("")
            end
        end
        -- Keep LDB text in sync with pause state
        if NS.UpdateLDBText then NS.UpdateLDBText() end
    end

    UpdateVisibility()

    if not btn:IsVisible() or btn:GetAlpha() == 0 then return end

    local spellID = NS.GetDisplaySpell()
    UpdateButton(btn, spellID)

    -- Live-update LDB tooltip "Next Up" line (only if tooltip is open + spell changed)
    if NS._ldbTooltip then NS.RefreshLDBTooltipNextSpell() end

    -- Update priority display
    if NS.UpdatePriorityDisplay then
        NS.UpdatePriorityDisplay()
    end

    -- Read the manual spell while cooldown caches are still marked dirty for
    -- this tick, so its reminder cannot reuse a pre-event cached cooldown.
    if NS.UpdateManualCooldownReminder then NS.UpdateManualCooldownReminder() end

    -- Clear cooldown dirty flag — all queries this tick have refreshed
    NS.EndUpdate()
end

----------------------------------------------------------------
-- Start / stop ticker
----------------------------------------------------------------
function NS.StartTicker()
    if ticker or not NS.db or not NS.db.enabled then return end
    local rate = NS.db.updateRate or 0.1
    if rate < 0.05 then rate = 0.05 end
    ticker = NS.C_Timer_NewTicker(rate, NS.UpdateNow)
end

function NS.StopTicker()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

----------------------------------------------------------------
-- Apply size/scale changes
----------------------------------------------------------------
function NS.ApplyButtonSettings()
    local btn = NS.mainButton
    if not btn then return end
    if NS.InCombatLockdown() then
        NS._pendingButtonSettings = true
        return
    end
    btn:SetSize(NS.db.buttonSize, NS.db.buttonSize)
    btn:SetScale(NS.db.scale)
    if btn.hotkey then
        btn.hotkey:SetFont(
            NS.ResolveFontPath("keybindFont"),
            NS.db.keybindFontSize,
            NS.ResolveFontOutline("keybindFont", "keybindOutline"))
        btn.hotkey:ClearAllPoints()
        btn.hotkey:SetPoint(NS.db.keybindAnchor or "TOPRIGHT", NS.db.keybindOffsetX or -5, NS.db.keybindOffsetY or -5)
    end
    if NS.RefreshAnimHotkeys then NS.RefreshAnimHotkeys() end
    if btn.pauseOverlay then
        local po = btn.pauseOverlay
        if po.symbolText then
            po.symbolText:SetFont(
                NS.ResolveFontPath("pauseSymbolFont"),
                NS.db.pauseSymbolFontSize or 14,
                NS.ResolveFontOutline("pauseSymbolFont", "pauseSymbolOutline"))
        end
        if po.reasonText then
            po.reasonText:SetFont(
                NS.ResolveFontPath("pauseReasonFont"),
                NS.db.pauseReasonFontSize or 9,
                NS.ResolveFontOutline("pauseReasonFont", "pauseReasonOutline"))
        end
        LayoutPauseVisual(btn)
    end
    if not NS.masque and btn.bg then
        local bgColor = NS.db.buttonBgColor
        btn.bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 0.6)
    end
    if NS.ApplyPriorityFonts then NS.ApplyPriorityFonts() end
    if NS.ApplyAllButtonStyles then NS.ApplyAllButtonStyles() end
    if NS.InitializeMotionFeedback then NS.InitializeMotionFeedback() end
end
