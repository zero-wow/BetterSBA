local ADDON_NAME, NS = ...

local T = NS.THEME
local MAX_QUEUE_ICONS = 6
local queueIcons = {}

----------------------------------------------------------------
-- Snap-back constants
----------------------------------------------------------------
local SNAP_DISTANCE = 80
local GLOW_DISTANCE = 200
local NUM_BUBBLES = 6

----------------------------------------------------------------
-- Create the queue display frame
----------------------------------------------------------------
function NS:CreateQueueDisplay()
    local f = NS.CreateFrame("Frame", "BetterSBA_QueueFrame", NS.UIParent, "BackdropTemplate")
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    f:SetBackdropColor(NS.unpack(NS.db.queueBgColor))
    f:SetBackdropBorderColor(NS.unpack(NS.db.queueBorderColor))
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(4)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    -- Label
    f.label = f:CreateFontString(nil, "OVERLAY")
    f.label:SetFont(NS.ResolveFontPath("queueLabelFont"), NS.db.queueLabelFontSize, NS.ResolveFontOutline("queueLabelFont", "queueLabelOutline"))
    f.label:SetTextColor(NS.unpack(T.TEXT_DIM))
    f.label:SetText("ROTATION")

    -- Shared drag handlers (called by both queue frame and overlay)
    local function QueueDragStart()
        if NS.db.locked or not NS.db.queueDetached or NS.InCombatLockdown() then return end
        -- Convert anchored position to absolute on first drag
        if not NS.db.queueFreePosition then
            f._firstDrag = true  -- skip snap on initial placement
            local cx, cy = f:GetCenter()
            f:ClearAllPoints()
            f:SetPoint("CENTER", NS.UIParent, "BOTTOMLEFT", cx, cy)
        end
        f:StartMoving()
        f._dragging = true
        -- Hide overlay text while dragging
        if f._overlay then f._overlay:Hide() end
        NS.StartSnapDetection()
    end

    local function QueueDragStop()
        f:StopMovingOrSizing()
        f._dragging = false

        -- Skip snap check on the very first drag (queue starts on top of button)
        local skipSnap = f._firstDrag
        f._firstDrag = nil

        if not skipSnap and NS.ShouldSnap() then
            -- Snap back to main button
            NS.db.queueDetached = false
            NS.db.queueFreePosition = nil
            NS.LayoutQueue()
            NS.PlaySnapEffect()
            NS.HideMainButtonOverlay()
        else
            -- Save free position
            local p, _, rp, x, y = f:GetPoint()
            NS.db.queueFreePosition = { point = p, relPoint = rp, x = x, y = y }
        end
        NS.StopSnapDetection()
        NS.UpdateDetachOverlay()
    end

    f:SetScript("OnDragStart", function() QueueDragStart() end)
    f:SetScript("OnDragStop", function() QueueDragStop() end)

    -- Modifier+scroll scaling (Ctrl+MouseWheel adjusts queue scale)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        if not NS.db.modifierScaling or not IsControlKeyDown() then return end
        local scale = NS.db.queueScale or 1.0
        scale = scale + delta * 0.05
        scale = math.max(0.5, math.min(2.0, scale))
        scale = tonumber(string.format("%.2f", scale))
        NS.db.queueScale = scale
        f:SetScale(scale)
    end)

    -- Create icon slots (Button type for Masque compatibility)
    for i = 1, MAX_QUEUE_ICONS do
        local icon = NS.CreateFrame("Button", nil, f, "BackdropTemplate")
        icon:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        icon:SetBackdropColor(0, 0, 0, 0.6)
        icon:SetBackdropBorderColor(NS.unpack(NS.db.queueBorderColor))

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
        icon.hotkey:SetFont(NS.ResolveFontPath("queueKeybindFont"), NS.db.queueKeybindFontSize, NS.ResolveFontOutline("queueKeybindFont", "queueKeybindOutline"))
        icon.hotkey:SetPoint("TOPRIGHT", -1, -1)
        icon.hotkey:SetTextColor(0.9, 0.9, 0.9, 1)

        icon.spellID = nil
        icon:Hide()
        queueIcons[i] = icon

        -- Register with Masque (create required textures for skin compatibility)
        if NS.masqueQueueGroup then
            local iconSize = NS.db.queueIconSize
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

            NS.masqueQueueGroup:AddButton(icon, {
                Icon = icon.tex,
                Cooldown = icon.cd,
                Normal = normalTex,
                Pushed = pushedTex,
                Highlight = hlTex,
                Flash = flashTex,
                Border = borderTex,
            })

            -- Masque handles appearance — hide our backdrop
            icon:SetBackdrop(nil)
        end
    end

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

    overlay:EnableMouse(true)
    overlay:RegisterForDrag("LeftButton")
    overlay:SetScript("OnDragStart", function() QueueDragStart() end)
    overlay:SetScript("OnDragStop", function() QueueDragStop() end)
    overlay:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" then
            -- Right-click: commit position, exit drag mode
            NS.db.queueDetached = false
            NS.db.queueFreePosition = nil
            NS.LayoutQueue()
            NS.UpdateDetachOverlay()
        end
    end)

    f._overlay = overlay
    f._overlayText = overlayText

    function NS.UpdateDetachOverlay()
        if not NS.db.queueDetached then
            overlay:Hide()
            return
        end
        overlay:Show()
        overlayText:SetText("DRAG TO MOVE")
        overlayText:SetTextColor(T.NEON_NEXT[1], T.NEON_NEXT[2], T.NEON_NEXT[3])
        overlay:SetBackdropBorderColor(T.NEON_NEXT[1], T.NEON_NEXT[2], T.NEON_NEXT[3], 0.8)
        overlay:SetBackdropColor(T.BG_DARK[1], T.BG_DARK[2], T.BG_DARK[3], 0.7)
    end

    self.queueFrame = f
    f:SetScale(NS.db.queueScale or 1.0)
    NS.LayoutQueue()
    NS.UpdateDetachOverlay()

    -- Create snap feedback elements (lazy, hidden by default)
    NS.CreateSnapEffects()

    return f
end

----------------------------------------------------------------
-- Layout icons based on position setting
----------------------------------------------------------------
local QUEUE_ANCHORS = {
    RIGHT       = { from = "LEFT",        to = "RIGHT",       ox =  4, oy =  0 },
    LEFT        = { from = "RIGHT",       to = "LEFT",        ox = -4, oy =  0 },
    TOP         = { from = "BOTTOM",      to = "TOP",         ox =  0, oy =  4 },
    BOTTOM      = { from = "TOP",         to = "BOTTOM",      ox =  0, oy = -4 },
    TOPRIGHT    = { from = "BOTTOMLEFT",  to = "TOPRIGHT",    ox =  4, oy =  4 },
    TOPLEFT     = { from = "BOTTOMRIGHT", to = "TOPLEFT",     ox = -4, oy =  4 },
    BOTTOMRIGHT = { from = "TOPLEFT",     to = "BOTTOMRIGHT", ox =  4, oy = -4 },
    BOTTOMLEFT  = { from = "TOPRIGHT",    to = "BOTTOMLEFT",  ox = -4, oy = -4 },
}

function NS.LayoutQueue()
    local f = NS.queueFrame
    local btn = NS.mainButton
    if not f or not btn then return end

    local db = NS.db
    local iconSize = db.queueIconSize
    local spacing = db.queueSpacing

    for i, icon in NS.ipairs(queueIcons) do
        icon:SetSize(iconSize, iconSize)
        icon:ClearAllPoints()
    end

    f:ClearAllPoints()
    f.label:ClearAllPoints()

    local lx = db.queueLabelOffsetX or 0
    local ly = db.queueLabelOffsetY or 0

    -- Queue frame offset (attached mode fine-tuning)
    local qox = db.queueOffsetX or 0
    local qoy = db.queueOffsetY or 0

    -- Free position: use saved absolute position (persists even after drag mode off)
    if db.queueFreePosition then
        local pos = db.queueFreePosition
        f:SetPoint(pos.point, NS.UIParent, pos.relPoint, pos.x, pos.y)
        f.label:SetPoint("BOTTOM", f, "TOP", lx, 2 + ly)
    else
        -- Attached: anchor to main button with optional offset
        local pos = db.queuePosition
        local anchor = QUEUE_ANCHORS[pos] or QUEUE_ANCHORS.RIGHT
        f:SetPoint(anchor.from, btn, anchor.to, anchor.ox + qox, anchor.oy + qoy)

        local labelAboveFrame = (pos == "TOP" or pos == "BOTTOM"
            or pos == "TOPRIGHT" or pos == "TOPLEFT"
            or pos == "BOTTOMRIGHT" or pos == "BOTTOMLEFT")
        if labelAboveFrame then
            f.label:SetPoint("BOTTOM", f, "TOP", lx, 2 + ly)
        else
            f.label:SetPoint("BOTTOM", queueIcons[1], "TOP", lx, 2 + ly)
        end
    end

    -- Layout icons in a horizontal row
    for i, icon in NS.ipairs(queueIcons) do
        if i == 1 then
            icon:SetPoint("LEFT", f, "LEFT", 3, 0)
        else
            icon:SetPoint("LEFT", queueIcons[i - 1], "RIGHT", spacing, 0)
        end
    end

    local count = math.min(MAX_QUEUE_ICONS, #queueIcons)
    f:SetSize(count * (iconSize + spacing) - spacing + 6, iconSize + 6)

    NS.MasqueReSkin()
end

----------------------------------------------------------------
-- Snap proximity detection
----------------------------------------------------------------
function NS.GetSnapDistance()
    local f = NS.queueFrame
    local btn = NS.mainButton
    if not f or not btn then return 9999 end
    local fx, fy = f:GetCenter()
    local bx, by = btn:GetCenter()
    if not fx or not bx then return 9999 end
    local dx, dy = fx - bx, fy - by
    return math.sqrt(dx * dx + dy * dy)
end

function NS.ShouldSnap()
    return NS.GetSnapDistance() < SNAP_DISTANCE
end

----------------------------------------------------------------
-- Snap visual feedback
----------------------------------------------------------------
local snapFrame = NS.CreateFrame("Frame")
local glowFrame, bubbles

local mainBtnOverlay

function NS.CreateSnapEffects()
    local btn = NS.mainButton
    if not btn or glowFrame then return end

    -- Snap overlay on main button ("SNAP HERE" indicator)
    mainBtnOverlay = NS.CreateFrame("Frame", nil, btn, "BackdropTemplate")
    mainBtnOverlay:SetAllPoints()
    mainBtnOverlay:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
    })
    mainBtnOverlay:SetBackdropColor(T.NEON_NEXT[1], T.NEON_NEXT[2], T.NEON_NEXT[3], 0.15)
    mainBtnOverlay:SetBackdropBorderColor(T.NEON_NEXT[1], T.NEON_NEXT[2], T.NEON_NEXT[3], 0)
    mainBtnOverlay:SetFrameLevel(btn:GetFrameLevel() + 3)
    mainBtnOverlay:Hide()

    local snapText = mainBtnOverlay:CreateFontString(nil, "OVERLAY")
    snapText:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    snapText:SetPoint("CENTER")
    snapText:SetTextColor(T.NEON_NEXT[1], T.NEON_NEXT[2], T.NEON_NEXT[3])
    snapText:SetText("SNAP")
    mainBtnOverlay._text = snapText

    -- Neon glow border around main button
    glowFrame = NS.CreateFrame("Frame", nil, NS.UIParent, "BackdropTemplate")
    glowFrame:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
    })
    glowFrame:SetBackdropBorderColor(T.NEON_NEXT[1], T.NEON_NEXT[2], T.NEON_NEXT[3], 0)
    glowFrame:SetFrameStrata("MEDIUM")
    glowFrame:SetFrameLevel(3)
    glowFrame:Hide()

    -- Particle bubbles (main button)
    bubbles = {}
    local colors = { T.NEON_NEXT, T.ACCENT_BRIGHT, T.ACCENT, T.TOGGLE_ON }
    for i = 1, NUM_BUBBLES do
        local b = NS.CreateFrame("Frame", nil, NS.UIParent)
        b:SetSize(6, 6)
        b:SetFrameStrata("HIGH")
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        b.tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        local c = colors[((i - 1) % #colors) + 1]
        b.tex:SetColorTexture(c[1], c[2], c[3], 0.8)
        b._angle = (i - 1) * (6.2832 / NUM_BUBBLES)
        b._speed = 1.5 + (i % 3) * 0.5
        b._radius = 0
        b:Hide()
        bubbles[i] = b
    end

    -- Particle bubbles (queue frame)
    bubbles._queue = {}
    for i = 1, NUM_BUBBLES do
        local b = NS.CreateFrame("Frame", nil, NS.UIParent)
        b:SetSize(6, 6)
        b:SetFrameStrata("HIGH")
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        b.tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        local c = colors[((i - 1) % #colors) + 1]
        b.tex:SetColorTexture(c[1], c[2], c[3], 0.8)
        b._angle = (i - 1) * (6.2832 / NUM_BUBBLES) + 0.5  -- offset phase
        b._speed = 1.2 + (i % 3) * 0.6
        b._radius = 0
        b:Hide()
        bubbles._queue[i] = b
    end

    -- Dotted connection line (small square "dots" between frames)
    local NUM_DOTS = 8
    bubbles._dots = {}
    for i = 1, NUM_DOTS do
        local d = NS.CreateFrame("Frame", nil, NS.UIParent)
        d:SetSize(3, 3)
        d:SetFrameStrata("HIGH")
        d.tex = d:CreateTexture(nil, "ARTWORK")
        d.tex:SetAllPoints()
        d.tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        d.tex:SetColorTexture(0.85, 0.2, 0.2, 1) -- start red
        d:Hide()
        bubbles._dots[i] = d
    end
end

function NS.UpdateSnapGlow(intensity)
    if not glowFrame or not NS.mainButton then return end
    local btn = NS.mainButton
    local pad = 4 + intensity * 4
    glowFrame:ClearAllPoints()
    glowFrame:SetPoint("TOPLEFT", btn, "TOPLEFT", -pad, pad)
    glowFrame:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", pad, -pad)
    glowFrame:SetBackdropBorderColor(T.NEON_NEXT[1], T.NEON_NEXT[2], T.NEON_NEXT[3], intensity * 0.9)
    glowFrame:Show()
end

local function UpdateBubbleSet(set, cx, cy, intensity, elapsed, radiusBase)
    if not set then return end
    local base = radiusBase or (30 + (1 - intensity) * 20)
    for i, b in NS.ipairs(set) do
        b._angle = b._angle + elapsed * b._speed * (0.5 + intensity * 1.5)
        b._radius = base + math.sin(b._angle * 2) * 8
        local bSize = 4 + intensity * 4
        b:SetSize(bSize, bSize)
        b:SetAlpha(intensity * 0.8)
        local x = cx + math.cos(b._angle) * b._radius
        local y = cy + math.sin(b._angle) * b._radius
        b:ClearAllPoints()
        b:SetPoint("CENTER", NS.UIParent, "BOTTOMLEFT", x, y)
        b:Show()
    end
end

function NS.UpdateSnapBubbles(intensity, elapsed)
    if not bubbles or not NS.mainButton then return end

    -- Main button bubbles
    local btn = NS.mainButton
    local bx, by = btn:GetCenter()
    if bx then
        UpdateBubbleSet(bubbles, bx, by, intensity, elapsed, 30 + (1 - intensity) * 20)
    end

    -- Queue frame bubbles
    local qf = NS.queueFrame
    if qf and bubbles._queue then
        local qx, qy = qf:GetCenter()
        if qx then
            UpdateBubbleSet(bubbles._queue, qx, qy, intensity, elapsed, 20 + (1 - intensity) * 15)
        end
    end
end

function NS.UpdateSnapDots(intensity)
    if not bubbles or not bubbles._dots then return end
    local btn = NS.mainButton
    local qf = NS.queueFrame
    if not btn or not qf then return end

    local bx, by = btn:GetCenter()
    local qx, qy = qf:GetCenter()
    if not bx or not qx then return end

    -- Color: red (far) -> orange/yellow (mid) -> green (close/snap)
    local r, g, b
    if intensity < 0.5 then
        -- Red to orange/yellow
        local t = intensity / 0.5
        r = 0.85 + t * 0.15
        g = 0.20 + t * 0.60
        b = 0.05
    else
        -- Yellow to green
        local t = (intensity - 0.5) / 0.5
        r = 1.0 - t * 0.7
        g = 0.80 + t * 0.20
        b = 0.05 + t * 0.35
    end

    local NUM_DOTS = #bubbles._dots
    for i, d in NS.ipairs(bubbles._dots) do
        local pct = (i - 1) / (NUM_DOTS - 1)
        local dx = bx + (qx - bx) * pct
        local dy = by + (qy - by) * pct
        d:ClearAllPoints()
        d:SetPoint("CENTER", NS.UIParent, "BOTTOMLEFT", dx, dy)
        d.tex:SetColorTexture(r, g, b, intensity * 0.9)
        local dotSize = 2 + intensity * 2
        d:SetSize(dotSize, dotSize)
        d:Show()
    end
end

function NS.UpdateMainButtonOverlay(intensity)
    if not mainBtnOverlay then return end
    if intensity > 0 then
        mainBtnOverlay:Show()
        mainBtnOverlay:SetBackdropColor(T.NEON_NEXT[1], T.NEON_NEXT[2], T.NEON_NEXT[3], intensity * 0.2)
        mainBtnOverlay:SetBackdropBorderColor(T.NEON_NEXT[1], T.NEON_NEXT[2], T.NEON_NEXT[3], intensity * 0.9)
        mainBtnOverlay._text:SetAlpha(intensity)
    else
        mainBtnOverlay:Hide()
    end
end

function NS.HideMainButtonOverlay()
    if mainBtnOverlay then mainBtnOverlay:Hide() end
end

function NS.HideSnapEffects()
    if glowFrame then glowFrame:Hide() end
    if bubbles then
        for _, b in NS.ipairs(bubbles) do b:Hide() end
        if bubbles._queue then
            for _, b in NS.ipairs(bubbles._queue) do b:Hide() end
        end
        if bubbles._dots then
            for _, d in NS.ipairs(bubbles._dots) do d:Hide() end
        end
    end
    NS.HideMainButtonOverlay()
end

function NS.StartSnapDetection()
    snapFrame:SetScript("OnUpdate", function(self, elapsed)
        local dist = NS.GetSnapDistance()

        -- Snap intensity: 0 at GLOW_DISTANCE, 1 at SNAP_DISTANCE
        local snapIntensity = 1 - ((dist - SNAP_DISTANCE) / (GLOW_DISTANCE - SNAP_DISTANCE))
        snapIntensity = math.max(0, math.min(1, snapIntensity))

        -- Bubbles + dots always visible while dragging, minimum 0.15 intensity
        local dragIntensity = math.max(0.15, snapIntensity)

        NS.UpdateSnapBubbles(dragIntensity, elapsed)
        NS.UpdateSnapDots(dragIntensity)

        -- Glow + main overlay only when within glow distance
        if snapIntensity > 0 then
            NS.UpdateSnapGlow(snapIntensity)
            NS.UpdateMainButtonOverlay(snapIntensity)
        else
            if glowFrame then glowFrame:Hide() end
            NS.HideMainButtonOverlay()
        end
    end)
end

function NS.StopSnapDetection()
    snapFrame:SetScript("OnUpdate", nil)
    NS.HideSnapEffects()
end

----------------------------------------------------------------
-- Snap completion burst effect
----------------------------------------------------------------
function NS.PlaySnapEffect()
    if not bubbles or not NS.mainButton then return end
    local btn = NS.mainButton
    local bx, by = btn:GetCenter()
    if not bx then return end

    -- Flash the glow bright then fade
    if glowFrame then
        glowFrame:Show()
        glowFrame:SetBackdropBorderColor(T.NEON_NEXT[1], T.NEON_NEXT[2], T.NEON_NEXT[3], 1)
        local pad = 8
        glowFrame:ClearAllPoints()
        glowFrame:SetPoint("TOPLEFT", btn, "TOPLEFT", -pad, pad)
        glowFrame:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", pad, -pad)
    end

    -- Burst all bubbles outward
    local allBubbles = {}
    for _, b in NS.ipairs(bubbles) do
        b:SetAlpha(1); b:SetSize(8, 8); b:Show()
        allBubbles[#allBubbles + 1] = b
    end
    if bubbles._queue then
        for _, b in NS.ipairs(bubbles._queue) do
            b:SetAlpha(1); b:SetSize(8, 8); b:Show()
            allBubbles[#allBubbles + 1] = b
        end
    end

    -- Flash dots green then fade
    if bubbles._dots then
        for _, d in NS.ipairs(bubbles._dots) do
            d.tex:SetColorTexture(0.3, 1.0, 0.4, 1)
            d:SetSize(4, 4)
            d:Show()
        end
    end

    -- Fade out over 0.5s
    local elapsed = 0
    snapFrame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local pct = elapsed / 0.5
        if pct >= 1 then
            NS.HideSnapEffects()
            self:SetScript("OnUpdate", nil)
            return
        end

        local fade = 1 - pct
        if glowFrame then
            glowFrame:SetBackdropBorderColor(T.NEON_NEXT[1], T.NEON_NEXT[2], T.NEON_NEXT[3], fade)
        end

        for _, b in NS.ipairs(allBubbles) do
            local burstR = 30 + pct * 80
            local x = bx + math.cos(b._angle) * burstR
            local y = by + math.sin(b._angle) * burstR
            b:ClearAllPoints()
            b:SetPoint("CENTER", NS.UIParent, "BOTTOMLEFT", x, y)
            b:SetAlpha(fade * 0.8)
            b:SetSize(8 * fade, 8 * fade)
        end

        if bubbles._dots then
            for _, d in NS.ipairs(bubbles._dots) do
                d.tex:SetColorTexture(0.3, 1.0, 0.4, fade)
                d:SetSize(4 * fade, 4 * fade)
            end
        end

        if mainBtnOverlay then
            mainBtnOverlay:SetBackdropBorderColor(0.3, 1.0, 0.4, fade)
            mainBtnOverlay._text:SetAlpha(fade)
        end
    end)
end

----------------------------------------------------------------
-- Apply font settings to queue label + icon keybind text
----------------------------------------------------------------
function NS.ApplyQueueFonts()
    local f = NS.queueFrame
    if not f then return end
    if f.label then
        f.label:SetFont(
            NS.ResolveFontPath("queueLabelFont"),
            NS.db.queueLabelFontSize,
            NS.ResolveFontOutline("queueLabelFont", "queueLabelOutline"))
    end
    for _, icon in NS.ipairs(queueIcons) do
        if icon.hotkey then
            icon.hotkey:SetFont(
                NS.ResolveFontPath("queueKeybindFont"),
                NS.db.queueKeybindFontSize,
                NS.ResolveFontOutline("queueKeybindFont", "queueKeybindOutline"))
        end
    end
end

----------------------------------------------------------------
-- Update queue icons with rotation spells
----------------------------------------------------------------
function NS.UpdateQueueDisplay()
    local f = NS.queueFrame
    if not f then return end

    if not NS.db.showQueue then
        f:Hide()
        return
    end

    local nextSpell = NS.CollectNextSpell()
    local rotationSpells = NS.CollectRotationSpells()

    if not rotationSpells or #rotationSpells == 0 then
        f:Hide()
        return
    end

    f:Show()

    -- Queue alpha: match combat state
    local inCombat = InCombatLockdown()
    f:SetAlpha(inCombat and 1.0 or (NS.db.queueAlphaOOC or 0.6))

    local visibleCount = 0
    for i = 1, MAX_QUEUE_ICONS do
        local icon = queueIcons[i]
        local spellID = rotationSpells[i]

        if spellID and spellID ~= 0 then
            icon.spellID = spellID
            visibleCount = visibleCount + 1

            local tex = NS.C_Spell and NS.C_Spell.GetSpellTexture and NS.C_Spell.GetSpellTexture(spellID)
            if tex then
                icon.tex:SetTexture(tex)
            end

            -- Border color: importance color when enabled, neon fallback for next-cast
            local isNext = (spellID == nextSpell)

            if NS.db.importanceBorders then
                -- Importance borders ON: use spell's importance color for ALL icons
                local borderColor = NS.GetSpellBorderColor(spellID)
                if borderColor then
                    if icon.Border then
                        icon.Border:SetVertexColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
                        icon.Border:Show()
                    else
                        icon:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
                    end
                else
                    if icon.Border then
                        icon.Border:Hide()
                    else
                        icon:SetBackdropBorderColor(NS.unpack(NS.db.queueBorderColor))
                    end
                end
            elseif isNext then
                -- Importance borders OFF + next-cast: use neon highlight
                if icon.Border then
                    icon.Border:SetVertexColor(T.NEON_NEXT[1], T.NEON_NEXT[2], T.NEON_NEXT[3], 1)
                    icon.Border:Show()
                else
                    icon:SetBackdropBorderColor(NS.unpack(T.NEON_NEXT))
                end
            else
                -- Importance borders OFF + not next: default border
                if icon.Border then
                    icon.Border:Hide()
                else
                    icon:SetBackdropBorderColor(NS.unpack(NS.db.queueBorderColor))
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
            if NS.db.showQueueKeybinds then
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

    -- Tooltip on individual icons
    for i = 1, MAX_QUEUE_ICONS do
        local icon = queueIcons[i]
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
        local iconSize = NS.db.queueIconSize
        local spacing = NS.db.queueSpacing
        f:SetSize(visibleCount * (iconSize + spacing) - spacing + 6, iconSize + 6)
    end
end
