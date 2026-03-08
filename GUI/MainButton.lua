local ADDON_NAME, NS = ...

local T = NS.THEME
local ticker

----------------------------------------------------------------
-- Create the main button (display + secure overlay)
----------------------------------------------------------------
function NS:CreateMainButton()
    local db = self.db
    local size = db.buttonSize

    -- Display button (regular Button — clean for Masque skinning)
    local btn = NS.CreateFrame("Button", "BetterSBA_Display", NS.UIParent, "BackdropTemplate")
    btn:SetSize(size, size)
    btn:SetScale(db.scale)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(5)
    btn:SetClampedToScreen(true)
    btn:SetMovable(true)

    -- Background
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(NS.unpack(db.buttonBgColor))
    btn:SetBackdropBorderColor(NS.unpack(T.BORDER))

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

    -- Cooldown
    btn.cooldown = NS.CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints(btn.icon)
    btn.cooldown:SetDrawEdge(false)
    btn.cooldown:SetHideCountdownNumbers(false)

    -- Keybind text
    btn.hotkey = btn:CreateFontString(nil, "OVERLAY")
    btn.hotkey:SetFont(NS.GetFontPath(), db.keybindFontSize, NS.GetFontOutline())
    btn.hotkey:SetPoint("TOPRIGHT", -2, -2)
    btn.hotkey:SetTextColor(0.9, 0.9, 0.9, 1)

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
        GameTooltip:Hide()
    end)

    -- Debug: PreClick fires BEFORE the macro executes
    secure:SetScript("PreClick", function(self, button, down)
        if not NS.db.debug then return end
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
        if not NS.db.debug then return end
        local hasTarget = NS.UnitExists("target")
        NS.DebugPrintAlways("Macro done | Target:", hasTarget and "yes" or "no")
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
        local pushedTex = btn:CreateTexture()
        pushedTex:SetColorTexture(0, 0, 0, 0.5)
        pushedTex:SetAllPoints(btn.icon)
        btn:SetPushedTexture(pushedTex)

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

        NS.masqueMainGroup:AddButton(btn, {
            Icon = btn.icon,
            Cooldown = btn.cooldown,
            Normal = normalTex,
            Pushed = pushedTex,
            Highlight = hlTex,
            Flash = flashTex,
            Border = borderTex,
            HotKey = btn.hotkey,
        })

        -- Masque handles appearance — hide our backdrop so it doesn't darken
        btn:SetBackdrop(nil)
    end

    return btn
end

----------------------------------------------------------------
-- Update button visuals
----------------------------------------------------------------
local function UpdateButton(btn, spellID)
    if not spellID then
        -- Check for action bar fallback texture
        if NS._fallbackTexture then
            btn.spellID = nil
            btn.icon:SetTexture(NS._fallbackTexture)
            btn.hotkey:SetText("")
            btn.cooldown:Clear()
            btn.icon:SetVertexColor(1, 1, 1)
            btn.icon:SetDesaturated(false)
            return
        end
        btn.spellID = nil
        btn.icon:SetTexture(nil)
        btn.hotkey:SetText("")
        btn.cooldown:Clear()
        return
    end

    btn.spellID = spellID

    -- Icon
    local tex = NS.C_Spell and NS.C_Spell.GetSpellTexture and NS.C_Spell.GetSpellTexture(spellID)
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

    -- Cooldown (pcall + tonumber(tostring()) to handle taint during combat)
    if NS.db.showCooldown and NS.C_Spell and NS.C_Spell.GetSpellCooldown then
        local ok, cdInfo = NS.pcall(NS.C_Spell.GetSpellCooldown, spellID)
        if ok and cdInfo then
            local dur = cdInfo.duration and tonumber(tostring(cdInfo.duration)) or 0
            local start = cdInfo.startTime and tonumber(tostring(cdInfo.startTime)) or 0
            if dur > 1.5 then
                btn.cooldown:SetCooldown(start, dur)
            else
                btn.cooldown:Clear()
            end
        end
        -- If pcall failed or cdInfo nil, leave cooldown display as-is
    end

    -- Importance border color
    if NS.db.importanceBorders then
        local borderColor = NS.GetSpellBorderColor(spellID)
        if borderColor then
            if btn.Border then
                -- Masque: show and color the registered Border texture
                btn.Border:SetVertexColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
                btn.Border:Show()
            else
                -- No Masque: color the backdrop border
                btn:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
            end
        else
            if btn.Border then
                btn.Border:Hide()
            else
                btn:SetBackdropBorderColor(NS.unpack(NS.THEME.BORDER))
            end
        end
    else
        if btn.Border then
            btn.Border:Hide()
        else
            btn:SetBackdropBorderColor(NS.unpack(NS.THEME.BORDER))
        end
    end

    -- Range coloring
    if NS.db.rangeColoring and NS.C_Spell and NS.C_Spell.IsSpellInRange then
        local inRange = NS.C_Spell.IsSpellInRange(spellID, "target")
        if inRange == false then
            btn.icon:SetVertexColor(T.OUT_OF_RANGE[1], T.OUT_OF_RANGE[2], T.OUT_OF_RANGE[3])
            btn.icon:SetDesaturated(true)
        else
            btn.icon:SetVertexColor(1, 1, 1)
            btn.icon:SetDesaturated(false)
        end
    else
        btn.icon:SetVertexColor(1, 1, 1)
        btn.icon:SetDesaturated(false)
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
    if secure and not inCombat then secure:Show() end

    -- Display button inherits protection from the secure button's anchor.
    -- During combat: NEVER call Show()/Hide() — use alpha only.
    -- Out of combat: Show() so the frame is visible, then use alpha.

    if not db.enabled then
        if inCombat then
            btn:SetAlpha(0)
        else
            btn:Hide()
        end
        return
    end

    if db.hideInVehicle and UnitInVehicle("player") then
        if inCombat then
            btn:SetAlpha(0)
        else
            btn:Hide()
        end
        return
    end

    if db.onlyInCombat and not inCombat then
        -- Ensure frame is shown (so alpha works when combat starts)
        btn:Show()
        btn:SetAlpha(0)
        return
    end

    if not inCombat then
        btn:Show()
    end
    btn:SetAlpha(inCombat and db.alphaCombat or db.alphaOOC)
end

----------------------------------------------------------------
-- Main update tick
----------------------------------------------------------------
function NS.UpdateNow()
    local btn = NS.mainButton
    if not btn then return end

    UpdateVisibility()

    if not btn:IsVisible() or btn:GetAlpha() == 0 then return end

    local spellID = NS.GetDisplaySpell()
    UpdateButton(btn, spellID)

    -- Update queue display
    if NS.UpdateQueueDisplay then
        NS.UpdateQueueDisplay()
    end
end

----------------------------------------------------------------
-- Start / stop ticker
----------------------------------------------------------------
function NS.StartTicker()
    if ticker then return end
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
    btn:SetSize(NS.db.buttonSize, NS.db.buttonSize)
    btn:SetScale(NS.db.scale)
    if btn.hotkey then
        btn.hotkey:SetFont(NS.GetFontPath(), NS.db.keybindFontSize, NS.GetFontOutline())
    end
    if not NS.masque then
        btn:SetBackdropColor(NS.unpack(NS.db.buttonBgColor))
    end
    NS.MasqueReSkin()
end
