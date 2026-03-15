local ADDON_NAME, NS = ...

local animPool = {}

local BASE_GCD = 1.9
local ANIM_CONFIGS = {
    DRIFT = function(ag, g)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(0.3, 0.3); s:SetDuration(1.2*g); s:SetSmoothing("IN_OUT"); s:SetStartDelay(0)
        t:SetOffset(-80, -15); t:SetDuration(1.0*g); t:SetSmoothing("OUT"); t:SetStartDelay(0)
        a:SetFromAlpha(1.0); a:SetToAlpha(0); a:SetDuration(1.3*g); a:SetSmoothing("IN"); a:SetStartDelay(0.05*g)
        r:SetDegrees(180); r:SetDuration(1.2*g); r:SetSmoothing("OUT"); r:SetStartDelay(0)
    end,
    PULSE = function(ag, g)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(2.0, 2.0); s:SetDuration(0.45*g); s:SetSmoothing("OUT"); s:SetStartDelay(0)
        t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(0)
        a:SetFromAlpha(1.0); a:SetToAlpha(0); a:SetDuration(1.4*g); a:SetSmoothing("IN"); a:SetStartDelay(0)
        r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(0)
    end,
    VORTEX = function(ag, g)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(0.15, 0.15); s:SetDuration(0.7*g); s:SetSmoothing("OUT"); s:SetStartDelay(0)
        t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(0)
        a:SetFromAlpha(1.0); a:SetToAlpha(0); a:SetDuration(1.3*g); a:SetSmoothing("IN"); a:SetStartDelay(0)
        r:SetDegrees(360); r:SetDuration(0.7*g); r:SetSmoothing("OUT"); r:SetStartDelay(0)
    end,
    ZOOM = function(ag, g)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(3.5, 3.5); s:SetDuration(0.55*g); s:SetSmoothing("OUT"); s:SetStartDelay(0)
        t:SetOffset(0, 25); t:SetDuration(0.55*g); t:SetSmoothing("OUT"); t:SetStartDelay(0)
        a:SetFromAlpha(1.0); a:SetToAlpha(0); a:SetDuration(1.3*g); a:SetSmoothing("IN"); a:SetStartDelay(0)
        r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(0)
    end,
    SLAM = function(ag, g)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(0)
        t:SetOffset(0, -28); t:SetDuration(0.70*g); t:SetSmoothing("IN"); t:SetStartDelay(0)
        a:SetFromAlpha(1.0); a:SetToAlpha(0); a:SetDuration(1.3*g); a:SetSmoothing("IN"); a:SetStartDelay(0)
        r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(0)
    end,
    ["POP!"] = function(ag, g)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(1.25, 1.25); s:SetDuration(0.12*g); s:SetSmoothing("OUT"); s:SetStartDelay(0)
        t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(0)
        a:SetFromAlpha(1); a:SetToAlpha(0); a:SetDuration(1.4*g); a:SetSmoothing("IN"); a:SetStartDelay(0.10*g)
        r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(0)
    end,
    BURST = function(ag, g)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(1.5, 1.5); s:SetDuration(0.45*g); s:SetSmoothing("IN_OUT"); s:SetStartDelay(0)
        t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(0)
        a:SetFromAlpha(1); a:SetToAlpha(0); a:SetDuration(1.4*g); a:SetSmoothing("IN"); a:SetStartDelay(0.15*g)
        r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(0)
    end,
    FADE = function(ag, g)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(0)
        t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(0)
        a:SetFromAlpha(1); a:SetToAlpha(0); a:SetDuration(1.5*g); a:SetSmoothing("IN_OUT"); a:SetStartDelay(0)
        r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(0)
    end,
    FLIP = function(ag, g)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(0.01, 1); s:SetDuration(0.50*g); s:SetSmoothing("IN"); s:SetStartDelay(0)
        t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(0)
        a:SetFromAlpha(1); a:SetToAlpha(0); a:SetDuration(1.3*g); a:SetSmoothing("IN"); a:SetStartDelay(0.10*g)
        r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(0)
    end,
    RISE = function(ag, g)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(0)
        t:SetOffset(0, 35); t:SetDuration(0.80*g); t:SetSmoothing("OUT"); t:SetStartDelay(0)
        a:SetFromAlpha(1); a:SetToAlpha(0); a:SetDuration(1.3*g); a:SetSmoothing("IN"); a:SetStartDelay(0)
        r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(0)
    end,
    SCATTER = function(ag, g)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(0.4, 0.4); s:SetDuration(0.70*g); s:SetSmoothing("OUT"); s:SetStartDelay(0)
        t:SetOffset(65, 40); t:SetDuration(0.70*g); t:SetSmoothing("OUT"); t:SetStartDelay(0)
        a:SetFromAlpha(1); a:SetToAlpha(0); a:SetDuration(1.2*g); a:SetSmoothing("IN"); a:SetStartDelay(0)
        r:SetDegrees(270); r:SetDuration(0.80*g); r:SetSmoothing("OUT"); r:SetStartDelay(0)
    end,
}

-- Reverse (incoming) animation configs â€” overlapping with outgoing.
--
-- Both outgoing and incoming clones are launched simultaneously.
-- The incoming clone uses SetStartDelay on each sub-animation so it
-- begins partway through the outgoing, creating a seamless cross-fade
-- where the old icon leaves and the new icon arrives as one motion.
--
--   offset    â€“ where the clone starts (opposite side from forward's travel)
--   preScale  â€“ frame's actual scale before animation (matches forward's
--               end scale).  Scale animation compensates to arrive at 1.0.
--   delay     â€“ seconds to wait before the incoming animations begin
--               (overlap point into the outgoing animation)
--   setup(ag, d) â€“ configures the AnimationGroup with start delay d
local REVERSE_ANIM_CONFIGS = {
    DRIFT = {
        offset = { 80, 15 },
        preScale = 1,
        delay = 1.10,
        setup = function(ag, d, g)
            d = d or 0; g = g or 1
            local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
            s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(d)
            t:SetOffset(-80, -15); t:SetDuration(0.55*g); t:SetSmoothing("IN"); t:SetStartDelay(d)
            a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.45*g); a:SetSmoothing("OUT"); a:SetStartDelay(d)
            r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(d)
        end,
    },
    PULSE = {
        offset = { 0, 0 },
        preScale = 1,
        delay = 1.10,
        setup = function(ag, d, g)
            d = d or 0; g = g or 1
            local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
            s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(d)
            t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(d)
            a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.40*g); a:SetSmoothing("OUT"); a:SetStartDelay(d)
            r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(d)
        end,
    },
    VORTEX = {
        offset = { 0, 0 },
        preScale = 1,
        delay = 1.10,
        setup = function(ag, d, g)
            d = d or 0; g = g or 1
            local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
            s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(d)
            t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(d)
            a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.40*g); a:SetSmoothing("OUT"); a:SetStartDelay(d)
            r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(d)
        end,
    },
    ZOOM = {
        offset = { 0, 0 },
        preScale = 1,
        delay = 1.10,
        setup = function(ag, d, g)
            d = d or 0; g = g or 1
            local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
            s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(d)
            t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(d)
            a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.40*g); a:SetSmoothing("OUT"); a:SetStartDelay(d)
            r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(d)
        end,
    },
    ["POP!"] = {
        offset = { 0, 0 },
        preScale = 1,
        delay = 1.20,
        setup = function(ag, d, g)
            d = d or 0; g = g or 1
            local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
            s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(d)
            t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(d)
            a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.35*g); a:SetSmoothing("OUT"); a:SetStartDelay(d)
            r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(d)
        end,
    },
    BURST = {
        offset = { 0, 0 },
        preScale = 1,
        delay = 1.20,
        setup = function(ag, d, g)
            d = d or 0; g = g or 1
            local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
            s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(d)
            t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(d)
            a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.35*g); a:SetSmoothing("OUT"); a:SetStartDelay(d)
            r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(d)
        end,
    },
    SLAM = {
        offset = { 0, 28 },
        preScale = 1,
        delay = 1.20,
        setup = function(ag, d, g)
            d = d or 0; g = g or 1
            local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
            s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(d)
            t:SetOffset(0, -28); t:SetDuration(0.50*g); t:SetSmoothing("OUT"); t:SetStartDelay(d)
            a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.40*g); a:SetSmoothing("OUT"); a:SetStartDelay(d)
            r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(d)
        end,
    },
    FADE = {
        offset = { 0, 0 },
        preScale = 1,
        delay = 1.20,
        setup = function(ag, d, g)
            d = d or 0; g = g or 1
            local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
            s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(d)
            t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(d)
            a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.40*g); a:SetSmoothing("OUT"); a:SetStartDelay(d)
            r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(d)
        end,
    },
    FLIP = {
        offset = { 0, 0 },
        preScale = 1,
        delay = 1.10,
        setup = function(ag, d, g)
            d = d or 0; g = g or 1
            local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
            s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(d)
            t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(d)
            a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.35*g); a:SetSmoothing("OUT"); a:SetStartDelay(d)
            r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(d)
        end,
    },
    RISE = {
        offset = { 0, 0 },
        preScale = 1,
        delay = 1.10,
        setup = function(ag, d, g)
            d = d or 0; g = g or 1
            local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
            s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(d)
            t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(d)
            a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.40*g); a:SetSmoothing("OUT"); a:SetStartDelay(d)
            r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(d)
        end,
    },
    SCATTER = {
        offset = { 0, 0 },
        preScale = 1,
        delay = 1.10,
        setup = function(ag, d, g)
            d = d or 0; g = g or 1
            local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
            s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(d)
            t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(d)
            a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.35*g); a:SetSmoothing("OUT"); a:SetStartDelay(d)
            r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(d)
        end,
    },
}

----------------------------------------------------------------
-- SLAM landing bounce â€” damped cosine wobble ("superhero landing")
-- Must be declared before AcquireAnimFrame so the OnFinished
-- closure can capture these upvalues.
----------------------------------------------------------------
local slamBounceTarget = nil
local slamBounceElapsed = 0
local SLAM_BOUNCE_DUR = 0.30
local slamBounceDurScaled = SLAM_BOUNCE_DUR
local SLAM_BOUNCE_AMP = 0.10   -- 10% scale oscillation
local SLAM_BOUNCE_FREQ = 2.5   -- ~2.5 wobble cycles

local slamBounceDriver = NS.CreateFrame("Frame")
slamBounceDriver:Hide()
slamBounceDriver:SetScript("OnUpdate", function(self, elapsed)
    if not slamBounceTarget then self:Hide() return end
    slamBounceElapsed = slamBounceElapsed + elapsed
    if slamBounceElapsed >= slamBounceDurScaled then
        -- Bounce done â€” reveal real button and clean up
        local srcBtn = slamBounceTarget._sourceBtn
        if srcBtn then
            local targetAlpha = InCombatLockdown()
                and (NS.db.alphaCombat or 1)
                or  (NS.db.alphaOOC or 1)
            srcBtn:SetAlpha(targetAlpha)
            NS._recreateFading = false
        end
        slamBounceTarget:SetScale(1)
        slamBounceTarget:Hide()
        slamBounceTarget:ClearAllPoints()
        slamBounceTarget._sourceBtn = nil
        slamBounceTarget._animType = nil
        slamBounceTarget._isIncoming = nil
        slamBounceTarget._hasIncomingPeer = nil
        slamBounceTarget._inUse = false
        slamBounceTarget = nil
        self:Hide()
        return
    end
    -- Damped cosine: wobbles Â±AMP, decaying to zero over BOUNCE_DUR
    local decay = 1 - (slamBounceElapsed / slamBounceDurScaled)
    local wobble = 1 + SLAM_BOUNCE_AMP * decay * math.cos(
        SLAM_BOUNCE_FREQ * 2 * math.pi * slamBounceElapsed / slamBounceDurScaled)
    local baseScale = slamBounceTarget._btnScale or NS.db.scale or 1
    slamBounceTarget:SetScale(wobble * baseScale)
end)

----------------------------------------------------------------
-- Hidden reference button for Masque "Animated Button" group
----------------------------------------------------------------
local animRefButton

local function EnsureAnimRefButton()
    if animRefButton or not NS.masqueAnimGroup then return end

    local ref = NS.CreateFrame("Button", nil, NS.UIParent)
    ref:SetSize(36, 36)
    ref:SetPoint("CENTER")
    ref:Hide()

    ref.icon = ref:CreateTexture(nil, "ARTWORK")
    ref.icon:SetAllPoints()

    local normalTex = ref:CreateTexture()
    normalTex:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    normalTex:SetSize(36 * 1.7, 36 * 1.7)
    normalTex:SetPoint("CENTER")
    ref:SetNormalTexture(normalTex)

    local pushedTex = ref:CreateTexture()
    pushedTex:SetColorTexture(0, 0, 0, 0.5)
    pushedTex:SetAllPoints(ref.icon)
    ref:SetPushedTexture(pushedTex)

    local hlTex = ref:CreateTexture()
    hlTex:SetColorTexture(1, 1, 1, 0.15)
    hlTex:SetAllPoints(ref.icon)
    ref:SetHighlightTexture(hlTex)

    local flashTex = ref:CreateTexture(nil, "OVERLAY")
    flashTex:SetColorTexture(1, 0, 0, 0.3)
    flashTex:SetAllPoints(ref.icon)
    flashTex:Hide()
    ref.Flash = flashTex

    local borderTex = ref:CreateTexture(nil, "OVERLAY")
    borderTex:SetAllPoints(ref.icon)
    borderTex:Hide()
    ref.Border = borderTex

    NS.masqueAnimGroup:AddButton(ref, {
        Icon = ref.icon,
        Normal = normalTex,
        Pushed = pushedTex,
        Highlight = hlTex,
        Flash = flashTex,
        Border = borderTex,
    })

    animRefButton = ref
end

local MAX_ANIM_POOL = 10  -- cap to prevent unbounded frame creation

local function UseMasqueAnimClone()
    return NS.masqueAnimGroup and NS.db.animCloneMasque ~= false
end

local function PositionKeybindHotkey(hk)
    if not hk then return end
    local parent = hk:GetParent()
    local anchor = NS.db.keybindAnchor or "TOPRIGHT"
    hk:ClearAllPoints()
    hk:SetPoint(anchor, parent, anchor, NS.db.keybindOffsetX or -5, NS.db.keybindOffsetY or -5)
end

local function PositionAnimCloneHotkey(hk)
    if not hk then return end
    local parent = hk:GetParent()
    local anchor = NS.db.keybindAnchor or "TOPRIGHT"
    hk:ClearAllPoints()
    hk:SetPoint(anchor, parent, anchor, NS.db.animCloneKeybindOffsetX or -5, NS.db.animCloneKeybindOffsetY or -5)
end

local function DebugAnimClone(phase, anim, spellID, sourceBtn)
    if not NS.IsDebugChannelEnabled("anim") or not anim then return end

    local hk = anim.hotkey
    local point, relPoint, ox, oy = "nil", "nil", "nil", "nil"
    if hk then
        local ok, a, _, c, d, e = NS.pcall(hk.GetPoint, hk, 1)
        if ok then
            point = a or "nil"
            relPoint = c or "nil"
            ox = d or 0
            oy = e or 0
        end
    end

    local hkParent = hk and hk:GetParent()
    local hkParentName = hkParent and hkParent.GetName and hkParent:GetName()
    local hkParentType = hkParent and hkParent.GetObjectType and hkParent:GetObjectType() or "nil"
    local group = NS.masqueAnimGroup
    local gdb = group and group.db

    NS.DebugPrintAlways("anim",
        "ANIM CLONE", phase,
        "| acquire:", anim._acquireKind or "unknown",
        "| spellID:", spellID or "nil",
        "| masque:", anim._usesMasque and "on" or "off",
        "| skin:", (gdb and gdb.SkinID) or "nil",
        "| groupScale:", (gdb and gdb.Scale) or "nil",
        "| groupUseScale:", (gdb and gdb.UseScale) and "true" or "false",
        "| sourceSize:", sourceBtn and math.floor(sourceBtn:GetWidth() + 0.5) or "nil",
        "x", sourceBtn and math.floor(sourceBtn:GetHeight() + 0.5) or "nil",
        "| sourceScale:", sourceBtn and sourceBtn:GetScale() or "nil",
        "| frameSize:", math.floor(anim:GetWidth() + 0.5), "x", math.floor(anim:GetHeight() + 0.5),
        "| frameScale:", anim:GetScale(),
        "| effectiveScale:", anim:GetEffectiveScale(),
        "| iconSize:", anim.icon and math.floor(anim.icon:GetWidth() + 0.5) or "nil",
        "x", anim.icon and math.floor(anim.icon:GetHeight() + 0.5) or "nil",
        "| hotkeySize:", hk and math.floor(hk:GetWidth() + 0.5) or "nil",
        "x", hk and math.floor(hk:GetHeight() + 0.5) or "nil",
        "| hotkeyJustify:", hk and hk:GetJustifyH() or "nil", "/", hk and hk:GetJustifyV() or "nil",
        "| hotkeyPoint:", point, relPoint, ox, oy,
        "| hotkeyParent:", hkParentType, hkParentName or "nil",
        "| dbAnchor:", NS.db.keybindAnchor or "TOPRIGHT",
        "| dbOffset:", NS.db.keybindOffsetX or -5, NS.db.keybindOffsetY or -5,
        "| cloneDbOffset:", NS.db.animCloneKeybindOffsetX or -5, NS.db.animCloneKeybindOffsetY or -5)
end

local function ApplyAnimHotkey(anim, spellID)
    local hk = anim and anim.hotkey
    if not hk then return end
    anim._spellID = spellID
    hk:SetFont(NS.ResolveFontPath("keybindFont"), NS.db.keybindFontSize or 12,
        NS.ResolveFontOutline("keybindFont", "keybindOutline"))
    PositionAnimCloneHotkey(hk)
    if NS.db.showKeybind then
        local keyText = spellID and NS.GetKeybindForSpell(spellID)
        if not keyText or keyText == "" then keyText = "#" end
        hk:SetText(keyText)
        hk:Show()
    else
        hk:SetText("")
        hk:Hide()
    end
end

function NS.RefreshAnimHotkeys()
    for _, f in NS.ipairs(animPool) do
        if f.hotkey then
            f.hotkey:SetFont(NS.ResolveFontPath("keybindFont"), NS.db.keybindFontSize or 12,
                NS.ResolveFontOutline("keybindFont", "keybindOutline"))
            PositionAnimCloneHotkey(f.hotkey)
            if not NS.db.showKeybind then
                f.hotkey:SetText("")
                f.hotkey:Hide()
            end
        end
    end
end

function NS.ReapplyAnimCloneHotkeysNow()
    local count = 0
    for _, f in NS.ipairs(animPool) do
        if f._inUse and f:IsShown() and f.hotkey then
            count = count + 1
            DebugAnimClone("MANUAL-BEFORE", f, f._spellID, f._sourceBtn)
            ApplyAnimHotkey(f, f._spellID)
            DebugAnimClone("MANUAL-AFTER", f, f._spellID, f._sourceBtn)
        end
    end
    if count == 0 then
        print("|cFF66B8D9BetterSBA|r: No active animation clone")
    elseif NS.IsDebugChannelEnabled("anim") then
        NS.DebugPrintAlways("anim", "ANIM CLONE", "MANUAL", "| reapplied:", count)
    end
end

function NS.ApplyAnimCloneDebugBinding()
    if NS.InCombatLockdown() then
        NS._pendingAnimCloneDebugBinding = true
        return
    end
    local btn = _G["BetterSBA_AnimCloneReapplyButton"]
    if not btn then
        btn = NS.CreateFrame("Button", "BetterSBA_AnimCloneReapplyButton", NS.UIParent)
        btn:SetSize(1, 1)
        btn:SetPoint("TOPLEFT", NS.UIParent, "BOTTOMLEFT", -100, 100)
        btn:SetAlpha(0)
        btn:RegisterForClicks("AnyDown", "AnyUp")
        btn:SetScript("OnClick", NS.ReapplyAnimCloneHotkeysNow)
    end
    ClearOverrideBindings(btn)
    local key = NS.db and NS.db.animCloneReapplyKey
    if key and key ~= "" then
        SetOverrideBindingClick(btn, true, key, btn:GetName(), "LeftButton")
    end
    NS._pendingAnimCloneDebugBinding = nil
end

function NS.ResetAnimClonePool()
    slamBounceTarget = nil
    slamBounceElapsed = 0
    slamBounceDriver:Hide()
    for _, f in NS.ipairs(animPool) do
        if f.ag then f.ag:Stop() end
        f:Hide()
        f:ClearAllPoints()
        f:SetScale(1)
        f:SetAlpha(0)
        f._sourceBtn = nil
        f._animType = nil
        f._isIncoming = nil
        f._hasIncomingPeer = nil
        f._fireParticlesOnEnd = nil
        f._particleStyle = nil
        f._particlePalette = nil
        f._particleGcdScale = nil
        f._gcdScale = nil
        f._spellID = nil
        f._inUse = false
        if f.hotkey then
            f.hotkey:SetText("")
            f.hotkey:Hide()
        end
        if NS.masqueAnimGroup and f._usesMasque and NS.masqueAnimGroup.RemoveButton then
            NS.masqueAnimGroup:RemoveButton(f)
        end
    end
    for i = 1, #animPool do
        animPool[i] = nil
    end
end

local function AcquireAnimFrame()
    local useMasque = UseMasqueAnimClone()
    for _, f in NS.ipairs(animPool) do
        if not f._inUse and f._usesMasque == useMasque then
            f._inUse = true
            f._acquireKind = "reuse"
            if f.ag then f.ag:Stop() end
            f:SetScale(1)
            f:SetAlpha(0)
            f._spellID = nil
            return f
        end
    end

    -- Pool full â€” recycle the oldest frame
    if #animPool >= MAX_ANIM_POOL then
        for _, oldest in NS.ipairs(animPool) do
            if oldest._usesMasque == useMasque then
                if oldest.ag then oldest.ag:Stop() end
                oldest:Hide()
                oldest:ClearAllPoints()
                oldest:SetScale(1)
                oldest:SetAlpha(0)
                oldest._spellID = nil
                oldest._inUse = true
                oldest._acquireKind = "recycle"
                return oldest
            end
        end
    end

    -- NO BackdropTemplate â€” WHITE8X8 can flash white during WoW rendering
    -- hiccups.  Use SetColorTexture instead (creates color in GPU memory
    -- with no white base texture that can leak through).
    local f = NS.CreateFrame("Button", nil, NS.UIParent)
    f:SetFrameStrata("HIGH")
    f:Hide()
    f:EnableMouse(false)  -- don't intercept clicks during animation
    f._usesMasque = useMasque

    -- Register with Masque animated button group
    if useMasque then
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetAllPoints()

        local size = NS.db.buttonSize or 48

        local normalTex = f:CreateTexture()
        normalTex:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        normalTex:SetSize(size * 1.7, size * 1.7)
        normalTex:SetPoint("CENTER")
        f:SetNormalTexture(normalTex)

        local pushedTex = f:CreateTexture()
        pushedTex:SetColorTexture(0, 0, 0, 0.5)
        pushedTex:SetAllPoints(f.icon)
        f:SetPushedTexture(pushedTex)

        local hlTex = f:CreateTexture()
        hlTex:SetColorTexture(1, 1, 1, 0.15)
        hlTex:SetAllPoints(f.icon)
        f:SetHighlightTexture(hlTex)

        local flashTex = f:CreateTexture(nil, "OVERLAY")
        flashTex:SetColorTexture(1, 0, 0, 0.3)
        flashTex:SetAllPoints(f.icon)
        flashTex:Hide()
        f.Flash = flashTex

        local borderTex = f:CreateTexture(nil, "OVERLAY")
        borderTex:SetAllPoints(f.icon)
        borderTex:Hide()
        f.Border = borderTex

        NS.masqueAnimGroup:AddButton(f, {
            Icon = f.icon,
            Normal = normalTex,
            Pushed = pushedTex,
            Highlight = hlTex,
            Flash = flashTex,
            Border = borderTex,
        })
    else
        -- Border layer (fills entire frame, shows as 1px edge around the icon)
        f.borderTex = f:CreateTexture(nil, "BACKGROUND")
        f.borderTex:SetAllPoints()
        f.borderTex:SetColorTexture(NS.THEME.BORDER[1], NS.THEME.BORDER[2], NS.THEME.BORDER[3], 1)

        -- Background layer (1px inset, sits on top of border)
        f.bg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
        f.bg:SetPoint("TOPLEFT", 1, -1)
        f.bg:SetPoint("BOTTOMRIGHT", -1, 1)
        f.bg:SetColorTexture(0, 0, 0, 0.6)

        -- Icon (1px inset, matches main button's border gap)
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetPoint("TOPLEFT", 1, -1)
        f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        f.icon:SetTexCoord(NS.unpack(NS.ICON_TEXCOORD))
    end

    -- Keybind â€” on a child frame so Masque can't hook the FontString
    local hkFrame = NS.CreateFrame("Frame", nil, f)
    hkFrame:SetAllPoints()
    hkFrame:SetFrameLevel(f:GetFrameLevel() + 5)
    f.hotkey = hkFrame:CreateFontString(nil, "OVERLAY")
    f.hotkey:SetFont(NS.ResolveFontPath("keybindFont"), NS.db.keybindFontSize or 12,
        NS.ResolveFontOutline("keybindFont", "keybindOutline"))
    f.hotkey:SetTextColor(0.9, 0.9, 0.9, 1)
    PositionAnimCloneHotkey(f.hotkey)
    f.hotkey:SetText("")
    f.hotkey:Hide()
    f._hkFrame = hkFrame

    local ag = f:CreateAnimationGroup()
    ag._scale = ag:CreateAnimation("Scale")
    ag._scale:SetOrigin("CENTER", 0, 0)
    ag._trans = ag:CreateAnimation("Translation")
    ag._alpha = ag:CreateAnimation("Alpha")
    ag._rot = ag:CreateAnimation("Rotation")
    ag._rot:SetOrigin("CENTER", 0, 0)

    ag:SetScript("OnFinished", function()
        -- SLAM incoming: chain into landing bounce instead of cleanup
        if f._isIncoming and f._animType == "SLAM" and f._sourceBtn then
            f:SetScale(f._btnScale or NS.db.scale or 1)
            f:ClearAllPoints()
            f:SetPoint("CENTER", f._sourceBtn, "CENTER")
            slamBounceTarget = f
            slamBounceElapsed = 0
            slamBounceDurScaled = SLAM_BOUNCE_DUR * (f._gcdScale or 1)
            slamBounceDriver:Show()
            return  -- bounce driver handles cleanup + reveal
        end

        -- Fire particles on animation end (if configured)
        if f._fireParticlesOnEnd and f._sourceBtn and not f._isIncoming then
            NS.FireParticleBurst(f._sourceBtn, f._particleStyle, f._particlePalette, f._particleGcdScale)
        end

        f:Hide()
        f:ClearAllPoints()
        f:SetScale(1)  -- reset preScale from reverse animations

        local srcBtn = f._sourceBtn
        local isIncoming = f._isIncoming
        local hasPeer = f._hasIncomingPeer
        f._sourceBtn = nil
        f._animType = nil
        f._isIncoming = nil
        f._hasIncomingPeer = nil
        f._fireParticlesOnEnd = nil
        f._particleStyle = nil
        f._particlePalette = nil
        f._particleGcdScale = nil
        f._gcdScale = nil
        f._spellID = nil
        f._inUse = false

        if srcBtn then
            if isIncoming then
                local targetAlpha = InCombatLockdown()
                    and (NS.db.alphaCombat or 1)
                    or  (NS.db.alphaOOC or 1)
                srcBtn:SetAlpha(targetAlpha)
                NS._recreateFading = false
                elseif not hasPeer then
                local targetAlpha = InCombatLockdown()
                    and (NS.db.alphaCombat or 1)
                    or  (NS.db.alphaOOC or 1)
                srcBtn:SetAlpha(targetAlpha)
                NS._recreateFading = false
                end
        end
    end)

    f.ag = ag
    f._inUse = true
    f._acquireKind = "new"
    animPool[#animPool + 1] = f
    return f
end

-- Tracks active animation cycle (prevents ticker from overriding alpha)
NS._recreateFading = false

----------------------------------------------------------------
-- Play a cast animation â€” simultaneous outgoing + incoming clones
--
-- 1. Clone the button (icon, border, keybind text, size)
-- 2. Place the outgoing clone on top of the real button
-- 3. If incoming enabled, place incoming clone at offset position
-- 4. Hide the real button instantly (alpha 0)
-- 5. Start both animations simultaneously â€” incoming uses start
--    delays so it begins partway through the outgoing, creating
--    a seamless cross-fade where old and new spells overlap
-- 6. Outgoing OnFinished just cleans up (incoming handles reveal)
-- 7. Incoming OnFinished reveals the real button
----------------------------------------------------------------
function NS.PlayCastAnimation(spellID)
    local btn = NS.mainButton
    if not btn or not btn:IsShown() then return end

    local animType = NS.db and NS.db.castAnimation or "NONE"
    if animType == "NONE" then return end

    local config = ANIM_CONFIGS[animType]
    if not config then return end

    -- Cancel any in-progress landing bounce
    if slamBounceTarget then
        slamBounceTarget:SetScale(1)
        slamBounceTarget:Hide()
        slamBounceTarget:ClearAllPoints()
        slamBounceTarget._sourceBtn = nil
        slamBounceTarget._animType = nil
        slamBounceTarget._isIncoming = nil
        slamBounceTarget._spellID = nil
        slamBounceTarget._inUse = false
        slamBounceTarget = nil
        slamBounceDriver:Hide()
    end

    -- If a previous animation is still running, revoke its source reference
    -- so only the newest clone triggers the incoming animation
    if NS._recreateFading and NS.db.animHideButton ~= false then
        btn:SetAlpha(0)
    end
    -- Clear source reference on any in-flight animation frames
    for _, af in NS.ipairs(animPool) do
        if af._inUse and af._sourceBtn then
            af._sourceBtn = nil
        end
    end

    -- Always use the CAST spell's own texture.  Earlier events
    -- (SPELL_UPDATE_COOLDOWN, ASSISTED_COMBAT_ACTION_SPELL_CAST) fire
    -- before UNIT_SPELLCAST_SUCCEEDED, so by the time we get here
    -- btn.icon has already been updated to the NEXT recommendation.
    local tex
    if spellID then
        tex = NS.GetSpellTextureCached(spellID)
    end
    if not tex and btn.icon then
        tex = btn.icon:GetTexture()
    end
    if not tex then return end

    local anim = AcquireAnimFrame()
    -- Read actual button dimensions (not DB) so clone matches exactly,
    -- even if ApplyButtonSettings hasn't run yet or was deferred by combat.
    local size = btn:GetWidth()
    local btnScale = btn:GetScale()

    anim:SetSize(size, size)
    anim:SetScale(btnScale * 1.2)
    anim:ClearAllPoints()
    anim:SetPoint("CENTER", btn, "CENTER")

    -- 2. Icon texture
    anim.icon:SetTexture(tex)

    -- 3. Importance border color + backdrop (ColorTexture API â€” no BackdropTemplate)
    if not NS.masque and anim.bg then
        local bgColor = NS.db.buttonBgColor
        anim.bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 0.6)
    end
    if NS.db.importanceBorders and spellID then
        local borderColor = NS.GetSpellBorderColor(spellID)
        if borderColor then
            if anim.Border then
                anim.Border:SetVertexColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
                anim.Border:Show()
            elseif anim.borderTex then
                anim.borderTex:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
            end
        else
            if not NS.masque and anim.borderTex then
                anim.borderTex:SetColorTexture(NS.THEME.BORDER[1], NS.THEME.BORDER[2], NS.THEME.BORDER[3], 1)
            end
        end
    else
        if not NS.masque and anim.borderTex then
            anim.borderTex:SetColorTexture(NS.THEME.BORDER[1], NS.THEME.BORDER[2], NS.THEME.BORDER[3], 1)
        end
    end

    -- 5. ReSkin Masque at current size
    if anim._usesMasque then
        NS.masqueAnimGroup:ReSkin()
    end

    -- 6. Keybind text
    ApplyAnimHotkey(anim, spellID)
    DebugAnimClone("OUT", anim, spellID, btn)

    -- 7. Store references for OnFinished
    anim._sourceBtn = btn
    anim._animType = animType
    anim._isIncoming = false

    -- 7. Hide the real button instantly (unless user disabled hiding)
    if NS.db.animHideButton ~= false then
        btn:SetAlpha(0)
    end
    NS._recreateFading = true

    -- 8. Start outgoing animation immediately
    --    Show at alpha 0 first, then play â€” the animation's SetFromAlpha(1)
    --    sets opacity on the first rendered frame, preventing a flash where
    --    both the clone and button are visible at full size.
    local g = (NS.db.gcdDuration or 1.9) / BASE_GCD
    anim:SetAlpha(0)
    anim:Show()
    anim.ag:Stop()
    config(anim.ag, g)
    anim.ag:Play()

    -- 8b. Particle burst â€” fires based on per-animation particle config
    local animKey = NS.AnimKeyPrefix(animType)
    local particlesOn = NS.db[animKey .. "Particles"]
    local particleStyle = NS.db[animKey .. "ParticleStyle"] or "Confetti"
    local particlePalette = NS.db[animKey .. "ParticlePalette"] or "Confetti"
    local particleTiming = NS.db[animKey .. "ParticleTiming"] or "On Cast"

    if particlesOn and particleStyle ~= "None" then
        if particleTiming == "Specific" then
            local delay = NS.db[animKey .. "ParticleDelay"] or 0.3
            NS.C_Timer_After(delay, function()
                NS.FireParticleBurst(btn, particleStyle, particlePalette, g)
            end)
        else
            if particleTiming == "On Cast" or particleTiming == "Both" then
                NS.FireParticleBurst(btn, particleStyle, particlePalette, g)
            end
            if particleTiming == "On Animation End" or particleTiming == "Both" then
                anim._fireParticlesOnEnd = true
                anim._particleStyle = particleStyle
                anim._particlePalette = particlePalette
                anim._particleGcdScale = g
            end
        end
    end

    -- 9. Defer incoming clone creation â€” the SBA API needs a frame to
    --    update its recommendation after UNIT_SPELLCAST_SUCCEEDED.
    --    The incoming animation has built-in start delays (0.30â€“0.40s)
    --    anyway, so a 0.05s API delay is invisible.
    local reverseConfig = REVERSE_ANIM_CONFIGS[animType]
    if NS.db.animateIncoming and reverseConfig then
        -- Mark that we expect an incoming peer (prevents outgoing's
        -- OnFinished from revealing the button if it finishes first)
        anim._hasIncomingPeer = true

        NS.C_Timer_After(0.05, function()
            -- Bail if the outgoing was cancelled (new animation started)
            if not anim._sourceBtn then
                -- Outgoing was orphaned â€” no peer expected anymore
                return
            end

            -- Re-query: btn.spellID should now reflect the NEXT recommendation
            NS.UpdateNow()
            local nextSpellID = btn.spellID
            local nextTex
            if nextSpellID then nextTex = NS.GetSpellTextureCached(nextSpellID) end
            if not nextTex and btn.icon then nextTex = btn.icon:GetTexture() end

            if not nextTex then
                -- Can't get next spell â€” reveal button now
                anim._hasIncomingPeer = false
                local targetAlpha = InCombatLockdown()
                    and (NS.db.alphaCombat or 1)
                    or  (NS.db.alphaOOC or 1)
                btn:SetAlpha(targetAlpha)
                NS._recreateFading = false
                return
            end

            local incoming = AcquireAnimFrame()
            local ox, oy = reverseConfig.offset[1], reverseConfig.offset[2]

            incoming:SetSize(size, size)
            incoming:SetScale((reverseConfig.preScale or 1) * btnScale)
            incoming._btnScale = btnScale
            incoming:ClearAllPoints()
            incoming:SetPoint("CENTER", btn, "CENTER", ox, oy)
            incoming.icon:SetTexture(nextTex)

            -- Background + importance border
            if not NS.masque and incoming.bg then
                local bgColor = NS.db.buttonBgColor
                incoming.bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 0.6)
            end
            if NS.db.importanceBorders and nextSpellID then
                local borderColor = NS.GetSpellBorderColor(nextSpellID)
                if borderColor then
                    if incoming.Border then
                        incoming.Border:SetVertexColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
                        incoming.Border:Show()
                    elseif incoming.borderTex then
                        incoming.borderTex:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
                    end
                else
                    if not NS.masque and incoming.borderTex then
                        incoming.borderTex:SetColorTexture(NS.THEME.BORDER[1], NS.THEME.BORDER[2], NS.THEME.BORDER[3], 1)
                    end
                end
            else
                if not NS.masque and incoming.borderTex then
                    incoming.borderTex:SetColorTexture(NS.THEME.BORDER[1], NS.THEME.BORDER[2], NS.THEME.BORDER[3], 1)
                end
            end

            if incoming._usesMasque then NS.masqueAnimGroup:ReSkin() end

            ApplyAnimHotkey(incoming, nextSpellID)
            DebugAnimClone("IN", incoming, nextSpellID, btn)

            incoming._sourceBtn = btn
            incoming._animType = animType
            incoming._isIncoming = true
            incoming._gcdScale = g

            -- Ensure incoming renders ON TOP of outgoing during overlap
            incoming:SetFrameLevel(anim:GetFrameLevel() + 5)
            incoming:Show()
            incoming:SetAlpha(0)  -- invisible during start delay period
            incoming.ag:Stop()
            local adjustedDelay = math.max(0, reverseConfig.delay * g - 0.05)
            reverseConfig.setup(incoming.ag, adjustedDelay, g)
            incoming.ag:Play()
        end)
    end
end

----------------------------------------------------------------
-- Preview mode (/bs preview â€” showcases all visual effects)
----------------------------------------------------------------
do
    local previewTicker = nil
    local previewGlowTicker = nil
    local previewStep = 0

    -- Importance tiers to cycle through on priority icons
    local IMPORTANCE_KEYS = { "AUTO_ATTACK", "FILLER", "SHORT_CD", "LONG_CD", "MAJOR_CD" }

    -- Demo spell textures (generic class-neutral icons)
    local DEMO_TEXTURES = {
        136048,   -- Spell_Nature_StarFall
        135753,   -- Spell_Fire_FlameBolt
        136197,   -- Spell_Nature_Lightning
        132369,   -- Spell_Shadow_DemonBreath
        134400,   -- Spell_Frost_FrostBolt02
        135963,   -- Spell_Shadow_ShadowBolt
    }

    function NS.StartPreviewMode()
        if previewTicker then
            print("|cFF66B8D9BetterSBA|r: Preview already running â€” |cFFFFCC00/bs stop|r to end")
            return
        end

        local btn = NS.mainButton
        if not btn then
            print("|cFF66B8D9BetterSBA|r: Main button not ready")
            return
        end

        -- Show button + priority display unconditionally
        btn:Show()
        btn:SetAlpha(1)
        if NS.priorityFrame then
            NS.priorityFrame:Show()
            NS.priorityFrame:SetAlpha(1)
        end

        -- Set up demo textures on priority icons
        local icons = NS._priorityIcons
        if icons then
            for i = 1, math.min(#icons, #DEMO_TEXTURES) do
                icons[i].tex:SetTexture(DEMO_TEXTURES[i])
                icons[i].tex:SetDesaturated(false)
                icons[i].tex:SetVertexColor(1, 1, 1)
                icons[i]:Show()
            end
            NS.LayoutPriority()
        end

        print("|cFF66B8D9BetterSBA|r: |cFF44FF44Preview mode ON|r â€” type |cFFFFCC00/bs stop|r to end")

        previewStep = 0

        local previewG = (NS.db.gcdDuration or 1.9) / BASE_GCD
        previewTicker = NS.C_Timer_NewTicker(2.5 * previewG, function()
            previewStep = previewStep + 1

            -- Play cast animation
            NS.PlayCastAnimation(NS.SBA_SPELL_ID)

            -- Cycle importance border colors on priority icons
            if icons and NS.db.importanceBorders then
                for i = 1, math.min(#icons, #DEMO_TEXTURES) do
                    local icon = icons[i]
                    if icon:IsShown() then
                        local impIdx = ((previewStep + i - 1) % #IMPORTANCE_KEYS) + 1
                        local impKey = IMPORTANCE_KEYS[impIdx]
                        local color = NS.SPELL_IMPORTANCE[impKey]
                        if icon.Border then
                            icon.Border:SetVertexColor(color[1], color[2], color[3], 1)
                            icon.Border:Show()
                        elseif icon.borderTex then
                            icon.borderTex:SetColorTexture(color[1], color[2], color[3], 1)
                        end
                    end
                end
            end
        end)

        -- Border color cycling ticker (cycles importance colors on borders at 1.5s)
        previewGlowTicker = NS.C_Timer_NewTicker(1.5, function()
            if not icons then return end
            previewStep = previewStep + 1

            for i = 1, math.min(#icons, #DEMO_TEXTURES) do
                local icon = icons[i]
                if icon:IsShown() then
                    local impIdx = ((previewStep + i) % #IMPORTANCE_KEYS) + 1
                    local impKey = IMPORTANCE_KEYS[impIdx]
                    local brightColor = NS.SPELL_IMPORTANCE_BRIGHT[impKey]

                    if icon.Border then
                        icon.Border:SetVertexColor(brightColor[1], brightColor[2], brightColor[3], 1)
                        icon.Border:Show()
                    elseif icon.borderTex then
                        icon.borderTex:SetColorTexture(brightColor[1], brightColor[2], brightColor[3], 1)
                    end
                end
            end
        end)

        -- Fire initial burst immediately
        NS.PlayCastAnimation(NS.SBA_SPELL_ID)
    end

    function NS.StopPreviewMode()
        if not previewTicker and not previewGlowTicker then
            print("|cFF66B8D9BetterSBA|r: No preview running")
            return
        end

        if previewTicker then
            previewTicker:Cancel()
            previewTicker = nil
        end
        if previewGlowTicker then
            previewGlowTicker:Cancel()
            previewGlowTicker = nil
        end

        -- Reset priority icon borders
        local icons = NS._priorityIcons
        if icons then
            for i = 1, #icons do
                icons[i]._wantGlow = false
            end
        end

        -- Restore normal display state
        NS.UpdateNow()
        print("|cFF66B8D9BetterSBA|r: |cFFFF4444Preview mode OFF|r")
    end
end
