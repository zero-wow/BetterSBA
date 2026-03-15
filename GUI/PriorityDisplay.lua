local ADDON_NAME, NS = ...

local T = NS.THEME
local MAX_PRIORITY_ICONS = 6
local priorityIcons = {}

----------------------------------------------------------------
-- Priority sorting helpers
----------------------------------------------------------------
local sortBuffer = {}  -- reusable table (no GC pressure)

-- Sanitize potentially tainted (secret) numbers into clean Lua numbers.
-- WoW's C_Spell cooldown API returns "secret number" values in combat
-- that cannot be compared with Lua operators.  Converting through
-- tostring -> tonumber produces a clean, non-tainted copy.
local function CleanNumber(val)
    if val == nil then return 0 end
    local ok, s = pcall(tostring, val)
    if not ok then return 0 end
    return tonumber(s) or 0
end

-- Get cooldown remaining (seconds). Returns 0 if ready, not seeded, or on error.
local function GetCDRemaining(spellID)
    if not NS.IsVirtualCDReady() then return 0 end  -- graceful degrade: no CD data yet
    local cdInfo = NS.GetCooldownCached(spellID)
    if not cdInfo then return 0 end
    local st = CleanNumber(cdInfo.startTime)
    local dur = CleanNumber(cdInfo.duration)
    if dur <= 1.5 then return 0 end  -- GCD or no CD
    local now = GetTime()
    local rem = (st + dur) - now
    return rem > 0 and rem or 0
end

-- Get base cooldown duration for importance sorting
local function GetBaseCooldown(spellID)
    local baseCD = NS.GetBaseCooldownCached and NS.GetBaseCooldownCached(spellID)
    if baseCD then return CleanNumber(baseCD) end
    local cdInfo = NS.GetCooldownCached(spellID)
    if not cdInfo then return 0 end
    return CleanNumber(cdInfo.duration)
end

-- Sort rotation spells by priority.
-- Pre-computes all sort keys in one O(N) pass so the comparator
-- does zero API calls, zero CleanNumber/tostring, zero closures.
local sortKeys = {}  -- reusable: sortKeys[spellID] = { rem, ready, base, isNext }

local function SortByPriority(spells, nextSpellID)
    -- Fill sort buffer (reuse table to avoid GC)
    for i = 1, #sortBuffer do sortBuffer[i] = nil end
    for i = 1, #spells do
        sortBuffer[i] = spells[i]
    end

    -- Pre-compute clean sort keys (one pass — all string garbage here, not in comparator)
    for i = 1, #sortBuffer do
        local sid = sortBuffer[i]
        local k = sortKeys[sid]
        if not k then k = {}; sortKeys[sid] = k end
        k.rem = GetCDRemaining(sid)
        k.ready = (k.rem == 0)
        k.base = k.ready and GetBaseCooldown(sid) or 0
        k.isNext = (sid == nextSpellID)
    end

    table.sort(sortBuffer, function(a, b)
        local ka, kb = sortKeys[a], sortKeys[b]
        -- Next-cast spell always first
        if ka.isNext ~= kb.isNext then return ka.isNext end
        -- Ready spells before on-CD spells
        if ka.ready ~= kb.ready then return ka.ready end
        if ka.ready and kb.ready then
            -- Both ready: higher base CD = more important = first
            if ka.base ~= kb.base then return ka.base > kb.base end
        else
            -- Both on CD: soonest available first
            if ka.rem ~= kb.rem then return ka.rem < kb.rem end
        end
        -- Tiebreaker: spell ID (prevents flickering from unstable sort)
        return a < b
    end)

    return sortBuffer
end

----------------------------------------------------------------
-- Active spell glow tracking (multi-target: next-cast + high-importance ready spells)
----------------------------------------------------------------
local function ColorOverlayGlow(icon, r, g, b)
    local overlay = icon.overlay
    if not overlay then return end
    -- Blizzard overlay has: ants (animated dashed border), innerGlow, outerGlow,
    -- outerGlowOver, spark, innerGlowOver
    if overlay.ants then overlay.ants:SetVertexColor(r, g, b) end
    if overlay.innerGlow then overlay.innerGlow:SetVertexColor(r, g, b) end
    if overlay.outerGlow then overlay.outerGlow:SetVertexColor(r, g, b) end
    if overlay.outerGlowOver then overlay.outerGlowOver:SetVertexColor(r, g, b) end
    if overlay.spark then overlay.spark:SetVertexColor(r, g, b) end
    if overlay.innerGlowOver then overlay.innerGlowOver:SetVertexColor(r, g, b) end
end

NS.ColorOverlayGlow = ColorOverlayGlow

local function HideAllGlows()
    if not priorityIcons then return end
    for i = 1, MAX_PRIORITY_ICONS do
        local icon = priorityIcons[i]
        if icon then
            icon._wantGlow = false
        end
    end
end

----------------------------------------------------------------
-- Create the priority display frame
----------------------------------------------------------------
function NS:CreatePriorityDisplay()
    local f = NS.CreateFrame("Frame", "BetterSBA_PriorityFrame", NS.UIParent)
    -- Border + background: SetColorTexture (GPU-native color) instead of
    -- BackdropTemplate + WHITE8X8, which can flash white during rendering hiccups.
    f.borderTex = f:CreateTexture(nil, "BACKGROUND")
    f.borderTex:SetAllPoints()
    local pbc = NS.db.priorityBorderColor
    f.borderTex:SetColorTexture(pbc[1], pbc[2], pbc[3], pbc[4] or 1)

    f.bg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    f.bg:SetPoint("TOPLEFT", 1, -1)
    f.bg:SetPoint("BOTTOMRIGHT", -1, 1)
    local pbg = NS.db.priorityBgColor
    f.bg:SetColorTexture(pbg[1], pbg[2], pbg[3], pbg[4] or 0.6)
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(4)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    -- Label
    f.label = f:CreateFontString(nil, "OVERLAY")
    f.label:SetFont(NS.ResolveFontPath("priorityLabelFont"), NS.db.priorityLabelFontSize, NS.ResolveFontOutline("priorityLabelFont", "priorityLabelOutline"))
    f.label:SetTextColor(NS.unpack(T.TEXT_DIM))
    f.label:SetText("PRIORITY")

    -- Shared drag handlers (called by both priority frame and overlay)
    -- Uses manual cursor tracking instead of StartMoving() because
    -- StartMoving() silently fails when called from a child frame's
    -- drag handler (WoW requires mouse focus on the frame being moved).
    local function PriorityDragStart()
        if NS.db.priorityLocked or not NS.db.priorityDetached or NS.InCombatLockdown() then return end
        -- Convert anchored position to absolute on first drag
        if not NS.db.priorityFreePosition then
            local cx, cy = f:GetCenter()
            f:ClearAllPoints()
            f:SetPoint("CENTER", NS.UIParent, "BOTTOMLEFT", cx, cy)
        end
        f._dragging = true
        -- Record cursor-to-frame offset for manual movement
        local scale = f:GetEffectiveScale()
        local mx, my = GetCursorPosition()
        local cx, cy = f:GetCenter()
        f._dragOffX = cx - mx / scale
        f._dragOffY = cy - my / scale
        -- Move frame via OnUpdate (bypasses StartMoving)
        f:SetScript("OnUpdate", function(self)
            local curX, curY = GetCursorPosition()
            local s = self:GetEffectiveScale()
            self:ClearAllPoints()
            self:SetPoint("CENTER", NS.UIParent, "BOTTOMLEFT",
                curX / s + f._dragOffX, curY / s + f._dragOffY)
        end)
        -- Make overlay invisible while dragging (keep frame active for drag events)
        if f._overlay then f._overlay:SetAlpha(0) end
    end

    local function PriorityDragStop()
        f:SetScript("OnUpdate", nil)  -- stop cursor tracking
        f._dragging = false

        -- Save free position
        local p, _, rp, x, yy = f:GetPoint()
        NS.db.priorityFreePosition = { point = p, relPoint = rp, x = x, y = yy }
        NS.UpdateDetachOverlay()
    end

    f:SetScript("OnDragStart", function() PriorityDragStart() end)
    f:SetScript("OnDragStop", function() PriorityDragStop() end)

    -- Modifier+scroll scaling (Ctrl+MouseWheel adjusts priority scale)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        if not NS.db.modifierScaling or not IsControlKeyDown() then return end
        local scale = NS.db.priorityScale or 1.0
        scale = scale + delta * 0.05
        scale = math.max(0.5, math.min(2.0, scale))
        scale = tonumber(string.format("%.2f", scale))
        NS.db.priorityScale = scale
        f:SetScale(scale)
    end)

    -- Create icon slots (Button type for Masque compatibility)
    for i = 1, MAX_PRIORITY_ICONS do
        local icon = NS.CreateFrame("Button", nil, f)

        -- Border + background: ColorTexture (no BackdropTemplate / WHITE8X8)
        icon.borderTex = icon:CreateTexture(nil, "BACKGROUND")
        icon.borderTex:SetAllPoints()
        local pbc = NS.db.priorityBorderColor
        icon.borderTex:SetColorTexture(pbc[1], pbc[2], pbc[3], pbc[4] or 1)

        icon.bg = icon:CreateTexture(nil, "BACKGROUND", nil, 1)
        icon.bg:SetPoint("TOPLEFT", 1, -1)
        icon.bg:SetPoint("BOTTOMRIGHT", -1, 1)
        icon.bg:SetColorTexture(0, 0, 0, 0.6)

        icon.tex = icon:CreateTexture(nil, "ARTWORK")
        if NS.masque then
            icon.tex:SetAllPoints()
        else
            icon.tex:SetPoint("TOPLEFT", 1, -1)
            icon.tex:SetPoint("BOTTOMRIGHT", -1, 1)
            icon.tex:SetTexCoord(NS.unpack(NS.ICON_TEXCOORD))
        end

        icon.cd = NS.CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
        icon.cd:SetAllPoints(icon.tex)
        icon.cd:SetDrawEdge(false)
        icon.cd:SetHideCountdownNumbers(false)

        icon.hotkey = icon:CreateFontString(nil, "OVERLAY")
        icon.hotkey:SetFont(NS.ResolveFontPath("priorityKeybindFont"), NS.db.priorityKeybindFontSize, NS.ResolveFontOutline("priorityKeybindFont", "priorityKeybindOutline"))
        icon.hotkey:SetPoint(NS.db.priorityKeybindAnchor or "TOPRIGHT", NS.db.priorityKeybindOffsetX or -5, NS.db.priorityKeybindOffsetY or -5)
        icon.hotkey:SetTextColor(0.9, 0.9, 0.9, 1)

        icon.spellID = nil
        icon:Hide()
        priorityIcons[i] = icon

        -- Register with Masque (create required textures for skin compatibility)
        if NS.masquePriorityGroup then
            local iconSize = NS.db.priorityIconSize
            local normalTex = icon:CreateTexture()
            normalTex:SetTexture("Interface\\Buttons\\UI-Quickslot2")
            normalTex:SetSize(iconSize * 1.7, iconSize * 1.7)
            normalTex:ClearAllPoints()
            normalTex:SetPoint("CENTER")
            icon:SetNormalTexture(normalTex)

            local pushedTex = icon:CreateTexture()
            pushedTex:SetColorTexture(0, 0, 0, 0.5)
            pushedTex:SetAllPoints(icon.tex)
            icon:SetPushedTexture(pushedTex)

            local hlTex = icon:CreateTexture()
            hlTex:SetColorTexture(1, 1, 1, 0.15)
            hlTex:SetAllPoints(icon.tex)
            icon:SetHighlightTexture(hlTex)

            local flashTex = icon:CreateTexture(nil, "OVERLAY")
            flashTex:SetColorTexture(1, 0, 0, 0.3)
            flashTex:SetAllPoints(icon.tex)
            flashTex:Hide()
            icon.Flash = flashTex

            local borderTex = icon:CreateTexture(nil, "OVERLAY")
            borderTex:SetAllPoints(icon.tex)
            borderTex:Hide()
            icon.Border = borderTex

            NS.masquePriorityGroup:AddButton(icon, {
                Icon = icon.tex,
                Cooldown = icon.cd,
                Normal = normalTex,
                Pushed = pushedTex,
                Highlight = hlTex,
                Flash = flashTex,
                Border = borderTex,
            })

            -- Masque handles appearance — hide our textures
            if icon.borderTex then icon.borderTex:Hide() end
            if icon.bg then icon.bg:Hide() end
        end
    end

    NS._priorityIcons = priorityIcons

    -- Detach overlay ("DRAG TO MOVE" indicator, right-click to commit)
    local overlay = NS.CreateFrame("Frame", nil, f, "BackdropTemplate")
    overlay:SetAllPoints()
    overlay:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    overlay:SetBackdropColor(T.BG_DARK[1], T.BG_DARK[2], T.BG_DARK[3], 0.7)
    overlay:SetBackdropBorderColor(T.NEON_NEXT[1], T.NEON_NEXT[2], T.NEON_NEXT[3], 0.8)
    overlay:SetFrameLevel(f:GetFrameLevel() + 5)
    overlay:Hide()

    local overlayText = overlay:CreateFontString(nil, "OVERLAY")
    overlayText:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    overlayText:SetPoint("CENTER")
    overlayText:SetTextColor(T.NEON_NEXT[1], T.NEON_NEXT[2], T.NEON_NEXT[3])

    -- Overlay intercepts mouse when visible (sits above icon buttons).
    -- Uses OnMouseDown/OnMouseUp instead of RegisterForDrag — WoW's drag
    -- system is unreliable on BackdropTemplate child frames.
    overlay:EnableMouse(true)
    overlay:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            PriorityDragStart()
        elseif button == "RightButton" then
            -- Right-click: snap back to main button, exit detach mode
            NS.db.priorityDetached = false
            NS.db.priorityFreePosition = nil
            NS.LayoutPriority()
            NS.UpdateDetachOverlay()
        end
    end)
    overlay:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and f._dragging then
            PriorityDragStop()
        end
    end)

    f._overlay = overlay
    f._overlayText = overlayText

    function NS.UpdateDetachOverlay()
        if not NS.db.priorityDetached or NS.db.priorityLocked then
            overlay:Hide()
            return
        end
        overlay:Show()
        overlay:SetAlpha(1)  -- restore visibility (drag sets it to 0)
        overlayText:SetText("DRAG TO MOVE")
        overlayText:SetTextColor(T.NEON_NEXT[1], T.NEON_NEXT[2], T.NEON_NEXT[3])
        overlay:SetBackdropBorderColor(T.NEON_NEXT[1], T.NEON_NEXT[2], T.NEON_NEXT[3], 0.8)
        overlay:SetBackdropColor(T.BG_DARK[1], T.BG_DARK[2], T.BG_DARK[3], 0.7)
    end

    self.priorityFrame = f
    f:SetScale(NS.db.priorityScale or 1.0)
    NS.LayoutPriority()
    NS.UpdateDetachOverlay()

    return f
end

----------------------------------------------------------------
-- Layout icons based on position setting
----------------------------------------------------------------
local PRIORITY_ANCHORS = {
    RIGHT       = { from = "LEFT",        to = "RIGHT",       ox = -3, oy = -16 },
    LEFT        = { from = "RIGHT",       to = "LEFT",        ox = -4, oy =  0 },
    TOP         = { from = "BOTTOM",      to = "TOP",         ox =  0, oy =  4 },
    BOTTOM      = { from = "TOP",         to = "BOTTOM",      ox =  0, oy = -4 },
    TOPRIGHT    = { from = "BOTTOMLEFT",  to = "TOPRIGHT",    ox =  4, oy =  4 },
    TOPLEFT     = { from = "BOTTOMRIGHT", to = "TOPLEFT",     ox = -4, oy =  4 },
    BOTTOMRIGHT = { from = "TOPLEFT",     to = "BOTTOMRIGHT", ox =  4, oy = -4 },
    BOTTOMLEFT  = { from = "TOPRIGHT",    to = "BOTTOMLEFT",  ox = -4, oy = -4 },
}

function NS.LayoutPriority()
    local f = NS.priorityFrame
    local btn = NS.mainButton
    if not f or not btn then return end

    local db = NS.db
    local iconSize = db.priorityIconSize
    local spacing = db.prioritySpacing

    for i, icon in NS.ipairs(priorityIcons) do
        icon:SetSize(iconSize, iconSize)
        icon:ClearAllPoints()
    end

    f:ClearAllPoints()
    f.label:ClearAllPoints()

    local lx = db.priorityLabelOffsetX or 0
    local ly = db.priorityLabelOffsetY or 0

    -- Priority frame offset (attached mode fine-tuning)
    local pox = db.priorityOffsetX or 0
    local poy = db.priorityOffsetY or 0

    if db.priorityFreePosition then
        local pos = db.priorityFreePosition
        f:SetPoint(pos.point, NS.UIParent, pos.relPoint, pos.x, pos.y)
        f.label:SetPoint("BOTTOM", f, "TOP", lx, 2 + ly)
    elseif db.priorityDetached then
        local bindName = db.priorityBindFrame or "BetterSBA_MainButton"
        local bindFrame = _G[bindName] or btn
        local myPt = db.priorityMyPoint or "LEFT"
        local theirPt = db.priorityTheirPoint or "RIGHT"
        f:SetPoint(myPt, bindFrame, theirPt, pox, poy)
        f.label:SetPoint("BOTTOM", f, "TOP", lx, 2 + ly)
    else
        local pos = db.priorityPosition
        local anchor = PRIORITY_ANCHORS[pos] or PRIORITY_ANCHORS.RIGHT
        f:SetPoint(anchor.from, btn, anchor.to, anchor.ox + pox, anchor.oy + poy)

        local labelAboveFrame = (pos == "TOP" or pos == "BOTTOM"
            or pos == "TOPRIGHT" or pos == "TOPLEFT"
            or pos == "BOTTOMRIGHT" or pos == "BOTTOMLEFT")
        if labelAboveFrame then
            f.label:SetPoint("BOTTOM", f, "TOP", lx, 2 + ly)
        else
            f.label:SetPoint("BOTTOM", priorityIcons[1], "TOP", lx, 2 + ly)
        end
    end

    -- Layout icons in a horizontal row
    for i, icon in NS.ipairs(priorityIcons) do
        if i == 1 then
            icon:SetPoint("LEFT", f, "LEFT", 3, 0)
        else
            icon:SetPoint("LEFT", priorityIcons[i - 1], "RIGHT", spacing, 0)
        end
    end

    local count = math.min(MAX_PRIORITY_ICONS, #priorityIcons)
    f:SetSize(count * (iconSize + spacing) - spacing + 6, iconSize + 6)

end


function NS.ApplyPriorityBinding()
    NS.db.priorityFreePosition = nil
    NS.LayoutPriority()
end

----------------------------------------------------------------
-- Apply font settings to priority label + icon keybind text
----------------------------------------------------------------
function NS.ApplyPriorityFonts()
    local f = NS.priorityFrame
    if not f then return end
    if f.label then
        f.label:SetFont(
            NS.ResolveFontPath("priorityLabelFont"),
            NS.db.priorityLabelFontSize,
            NS.ResolveFontOutline("priorityLabelFont", "priorityLabelOutline"))
    end
    for _, icon in NS.ipairs(priorityIcons) do
        if icon.hotkey then
            icon.hotkey:SetFont(
                NS.ResolveFontPath("priorityKeybindFont"),
                NS.db.priorityKeybindFontSize,
                NS.ResolveFontOutline("priorityKeybindFont", "priorityKeybindOutline"))
            icon.hotkey:ClearAllPoints()
            icon.hotkey:SetPoint(NS.db.priorityKeybindAnchor or "TOPRIGHT",
                NS.db.priorityKeybindOffsetX or -5,
                NS.db.priorityKeybindOffsetY or -5)
        end
    end
end

----------------------------------------------------------------
-- Update priority icons with rotation spells (sorted by priority)
----------------------------------------------------------------
function NS.UpdatePriorityDisplay()
    local f = NS.priorityFrame
    if not f then return end

    if not NS.db.showPriority then
        f:Hide()
        HideAllGlows()
        return
    end

    local nextSpell = NS.CollectNextSpell()
    local rotationSpells = NS.CollectRotationSpells()

    if not rotationSpells or #rotationSpells == 0 then
        f:Hide()
        HideAllGlows()
        return
    end

    f:Show()

    -- Priority alpha: match combat state
    local inCombat = InCombatLockdown()
    f:SetAlpha(inCombat and 1.0 or (NS.db.priorityAlphaOOC or 0.6))

    -- Sort spells by priority (next-cast first, ready by importance, on-CD by remaining)
    local sorted = SortByPriority(rotationSpells, nextSpell)

    local visibleCount = 0

    for i = 1, MAX_PRIORITY_ICONS do
        local icon = priorityIcons[i]
        local spellID = sorted[i]
        -- Reset per-tick glow color (avoids table allocation)
        icon._wantGlow = false

        if spellID and spellID ~= 0 then
            icon.spellID = spellID
            visibleCount = visibleCount + 1

            local tex = NS.GetSpellTextureCached(spellID)
            if tex then
                icon.tex:SetTexture(tex)
            end

            -- Border color: importance color when enabled, neon fallback for next-cast
            local isNext = (spellID == nextSpell)

            -- Mark icons for glow: store color directly on icon (zero-alloc)
            if isNext then
                icon._wantGlow = true
                icon._glowR = T.NEON_NEXT[1]
                icon._glowG = T.NEON_NEXT[2]
                icon._glowB = T.NEON_NEXT[3]
            elseif NS.db.showActiveGlow then
                local impKey = NS.GetSpellImportanceKey(spellID)
                if impKey == "LONG_CD" or impKey == "MAJOR_CD" then
                    local cdInfo = NS.GetCooldownCached(spellID)
                    local isReady = true
                    if cdInfo then
                        local ok, isLong = pcall(NS._durGT, cdInfo, 1.5)
                        if ok and isLong then isReady = false end
                    end
                    if isReady then
                        local brightColor = NS.GetSpellBorderColorBright(spellID)
                            or NS.SPELL_IMPORTANCE_BRIGHT[impKey]
                        icon._wantGlow = true
                        icon._glowR = brightColor[1]
                        icon._glowG = brightColor[2]
                        icon._glowB = brightColor[3]
                    end
                end
            end

            if NS.db.importanceBorders then
                -- Importance borders ON: use spell's importance color for ALL icons
                local borderColor = NS.GetSpellBorderColor(spellID)
                if borderColor then
                    if icon.Border then
                        icon.Border:SetVertexColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
                        icon.Border:Show()
                    elseif icon.borderTex then
                        icon.borderTex:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
                    end
                else
                    if icon.Border then
                        icon.Border:Hide()
                    elseif icon.borderTex then
                        local pbc = NS.db.priorityBorderColor
                        icon.borderTex:SetColorTexture(pbc[1], pbc[2], pbc[3], pbc[4] or 1)
                    end
                end
            elseif isNext then
                -- Importance borders OFF + next-cast: use neon highlight
                if icon.Border then
                    icon.Border:SetVertexColor(T.NEON_NEXT[1], T.NEON_NEXT[2], T.NEON_NEXT[3], 1)
                    icon.Border:Show()
                elseif icon.borderTex then
                    icon.borderTex:SetColorTexture(T.NEON_NEXT[1], T.NEON_NEXT[2], T.NEON_NEXT[3], 1)
                end
            else
                -- Importance borders OFF + not next: default border
                if icon.Border then
                    icon.Border:Hide()
                elseif icon.borderTex then
                    local pbc = NS.db.priorityBorderColor
                    icon.borderTex:SetColorTexture(pbc[1], pbc[2], pbc[3], pbc[4] or 1)
                end
            end

            -- Next-cast icon is full brightness; others are dimmed
            icon.tex:SetDesaturated(false)
            icon.tex:SetVertexColor(isNext and 1 or 0.7, isNext and 1 or 0.7, isNext and 1 or 0.7)

            -- Cooldown (uses per-tick cache to avoid API table garbage)
            -- pcall guards comparison — cdInfo fields may be tainted secret numbers
            local cdInfo = NS.GetCooldownCached(spellID)
            if cdInfo then
                local ok, isLong = pcall(NS._durGT, cdInfo, 1.5)
                if ok and isLong then
                    icon.cd:SetCooldown(cdInfo.startTime, cdInfo.duration)
                else
                    icon.cd:Clear()
                end
            end

            -- Keybind text
            if NS.db.showPriorityKeybinds then
                local key = NS.GetKeybindForSpell(spellID)
                icon.hotkey:SetText(key or "")
                icon.hotkey:Show()
            else
                icon.hotkey:Hide()
            end

            icon:Show()
        else
            icon:Hide()
        end
    end

    -- Active spell highlight: bright border color on qualifying icons (zero-alloc)
    -- Uses the existing borderTex/Border — no Blizzard overlay glow frames needed
    if NS.db.showActiveGlow then
        for gi = 1, MAX_PRIORITY_ICONS do
            local icon = priorityIcons[gi]
            if icon._wantGlow then
                if icon.Border then
                    icon.Border:SetVertexColor(icon._glowR, icon._glowG, icon._glowB, 1)
                    icon.Border:Show()
                elseif icon.borderTex then
                    icon.borderTex:SetColorTexture(icon._glowR, icon._glowG, icon._glowB, 1)
                end
            end
        end
    end

    -- Tooltip on individual icons
    for i = 1, MAX_PRIORITY_ICONS do
        local icon = priorityIcons[i]
        if not icon._tooltipHooked then
            icon:EnableMouse(true)
            icon:SetScript("OnEnter", function(self)
                if self.spellID then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetSpellByID(self.spellID)
                    GameTooltip:Show()
                end
            end)
            icon:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            icon._tooltipHooked = true
        end
    end

    -- Resize frame to fit visible icons
    if visibleCount > 0 then
        local iconSize = NS.db.priorityIconSize
        local spacing = NS.db.prioritySpacing
        f:SetSize(visibleCount * (iconSize + spacing) - spacing + 6, iconSize + 6)
    end
end
