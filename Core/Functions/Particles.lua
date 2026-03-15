local ADDON_NAME, NS = ...

local PARTICLE_POOL = {}          -- recycled frame pool

local function AcquireParticle()
    for _, p in NS.ipairs(PARTICLE_POOL) do
        if not p._inUse then
            p._inUse = true
            return p
        end
    end

    local f = NS.CreateFrame("Frame", nil, NS.UIParent)
    f:SetFrameStrata("TOOLTIP")
    f:SetFrameLevel(300)
    f:Hide()

    -- Dark outline layer (1px black border for visibility)
    f.outline = f:CreateTexture(nil, "ARTWORK")
    f.outline:SetPoint("TOPLEFT", -1, 1)
    f.outline:SetPoint("BOTTOMRIGHT", 1, -1)
    f.outline:SetColorTexture(0, 0, 0, 0.9)

    -- Colored particle layer on top
    f.tex = f:CreateTexture(nil, "OVERLAY")
    f.tex:SetAllPoints()
    f.tex:SetColorTexture(1, 1, 1, 1)

    f._inUse = true
    PARTICLE_POOL[#PARTICLE_POOL + 1] = f
    return f
end

-- Style configs: count, duration, distance, per-particle setup
local PARTICLE_STYLE_CONFIGS = {
    Confetti = {
        count = 20, duration = 1.8, distance = 100,
        setup = function(p, angle, dist, dur, clr)
            local sz = math.random(4, 10)
            p:SetSize(sz, sz * (0.4 + 0.6 * math.random()))
            local shade = 0.8 + 0.4 * math.random()
            p.tex:SetColorTexture(math.min(1, clr[1]*shade), math.min(1, clr[2]*shade), math.min(1, clr[3]*shade), 1)
            local stagger = math.random() * 0.20
            local ag = p._ag
            ag._trans:SetOffset(math.cos(angle)*dist, math.sin(angle)*dist)
            ag._trans:SetDuration(dur); ag._trans:SetSmoothing("OUT"); ag._trans:SetStartDelay(stagger)
            ag._alpha:SetFromAlpha(1); ag._alpha:SetToAlpha(0)
            ag._alpha:SetDuration(dur*0.4); ag._alpha:SetSmoothing("IN"); ag._alpha:SetStartDelay(stagger + dur*0.5)
            ag._scale:SetScale(0.3, 0.3); ag._scale:SetDuration(dur); ag._scale:SetSmoothing("IN"); ag._scale:SetStartDelay(stagger)
            ag._rot:SetDegrees(math.random(0, 360)); ag._rot:SetDuration(0.001); ag._rot:SetSmoothing("NONE"); ag._rot:SetStartDelay(0)
        end,
    },
    Lasers = {
        count = 16, duration = 1.2, distance = 140,
        setup = function(p, angle, dist, dur, clr)
            p:SetSize(2, 16)
            p.tex:SetColorTexture(math.min(1, clr[1]*1.2), math.min(1, clr[2]*1.2), math.min(1, clr[3]*1.2), 1)
            local stagger = math.random() * 0.15
            local ag = p._ag
            ag._trans:SetOffset(math.cos(angle)*dist, math.sin(angle)*dist)
            ag._trans:SetDuration(dur); ag._trans:SetSmoothing("NONE"); ag._trans:SetStartDelay(stagger)
            ag._alpha:SetFromAlpha(1); ag._alpha:SetToAlpha(0)
            ag._alpha:SetDuration(dur*0.3); ag._alpha:SetSmoothing("IN"); ag._alpha:SetStartDelay(stagger + dur*0.6)
            ag._scale:SetScale(1.5, 0.5); ag._scale:SetDuration(dur); ag._scale:SetSmoothing("OUT"); ag._scale:SetStartDelay(stagger)
            ag._rot:SetDegrees(math.deg(angle) - 90); ag._rot:SetDuration(0.001); ag._rot:SetSmoothing("NONE"); ag._rot:SetStartDelay(0)
        end,
    },
    Sparks = {
        count = 28, duration = 1.4, distance = 80,
        setup = function(p, angle, dist, dur, clr)
            local sz = math.random(3, 7)
            p:SetSize(sz, sz * (0.3 + 0.4 * math.random()))
            p.tex:SetColorTexture(clr[1], clr[2], clr[3], 1)
            local stagger = math.random() * 0.20
            local ag = p._ag
            ag._trans:SetOffset(math.cos(angle)*dist, math.sin(angle)*dist)
            ag._trans:SetDuration(dur); ag._trans:SetSmoothing("OUT"); ag._trans:SetStartDelay(stagger)
            ag._alpha:SetFromAlpha(1); ag._alpha:SetToAlpha(0)
            ag._alpha:SetDuration(dur*0.4); ag._alpha:SetSmoothing("IN"); ag._alpha:SetStartDelay(stagger + dur*0.4)
            ag._scale:SetScale(0.4, 0.4); ag._scale:SetDuration(dur); ag._scale:SetSmoothing("IN"); ag._scale:SetStartDelay(stagger)
            ag._rot:SetDegrees(math.random(0, 360)); ag._rot:SetDuration(0.001); ag._rot:SetSmoothing("NONE"); ag._rot:SetStartDelay(0)
        end,
    },
    Squares = {
        count = 16, duration = 2.0, distance = 85,
        setup = function(p, angle, dist, dur, clr)
            local sz = math.random(6, 11)
            p:SetSize(sz, sz)
            local shade = 0.9 + 0.2 * math.random()
            p.tex:SetColorTexture(math.min(1, clr[1]*shade), math.min(1, clr[2]*shade), math.min(1, clr[3]*shade), 1)
            local stagger = math.random() * 0.25
            local ag = p._ag
            ag._trans:SetOffset(math.cos(angle)*dist*0.7, math.sin(angle)*dist*0.7)
            ag._trans:SetDuration(dur); ag._trans:SetSmoothing("OUT"); ag._trans:SetStartDelay(stagger)
            ag._alpha:SetFromAlpha(1); ag._alpha:SetToAlpha(0)
            ag._alpha:SetDuration(dur*0.3); ag._alpha:SetSmoothing("IN"); ag._alpha:SetStartDelay(stagger + dur*0.6)
            ag._scale:SetScale(0.5, 0.5); ag._scale:SetDuration(dur); ag._scale:SetSmoothing("OUT"); ag._scale:SetStartDelay(stagger)
            ag._rot:SetDegrees(45); ag._rot:SetDuration(0.001); ag._rot:SetSmoothing("NONE"); ag._rot:SetStartDelay(0)
        end,
    },
}

-- Fire a burst of particles from the center of `btn`
local RANDOM_STYLE_KEYS = { "Confetti", "Lasers", "Sparks", "Squares" }

function NS.FireParticleBurst(btn, styleName, paletteName, gcdScale)
    if not btn then return end
    if styleName == "None" then return end

    if styleName == "Random" then
        styleName = RANDOM_STYLE_KEYS[math.random(#RANDOM_STYLE_KEYS)]
    end

    local styleConfig = PARTICLE_STYLE_CONFIGS[styleName or "Confetti"]
    if not styleConfig then styleConfig = PARTICLE_STYLE_CONFIGS.Confetti end

    local colors = NS:GetPalette(paletteName or "Confetti")
    if not colors or #colors == 0 then
        colors = NS.BUILTIN_PALETTES.Confetti
    end

    local g = gcdScale or ((NS.db.gcdDuration or 1.9) / 1.9)
    local count = styleConfig.count
    local dur = styleConfig.duration * g
    local maxDist = styleConfig.distance

    for i = 1, count do
        local p = AcquireParticle()

        local angle = math.random() * 2 * math.pi
        local dist = maxDist * (0.5 + 0.5 * math.random())
        local clr = colors[math.random(#colors)]

        p:ClearAllPoints()
        p:SetPoint("CENTER", btn, "CENTER")
        p:SetAlpha(1)
        p:SetScale(1)
        p:Show()

        -- Ensure animation group exists
        local ag = p._ag
        if not ag then
            ag = p:CreateAnimationGroup()
            ag._trans = ag:CreateAnimation("Translation")
            ag._alpha = ag:CreateAnimation("Alpha")
            ag._scale = ag:CreateAnimation("Scale")
            ag._rot = ag:CreateAnimation("Rotation")
            ag._rot:SetOrigin("CENTER", 0, 0)
            ag:SetScript("OnFinished", function()
                p:Hide()
                p:ClearAllPoints()
                p:SetScale(1)
                p._inUse = false
            end)
            p._ag = ag
        end

        styleConfig.setup(p, angle, dist, dur, clr)

        ag:Stop()
        ag:Play()
    end
end

-- Legacy wrapper for any remaining call sites
local function FirePopBurst(btn)
    NS.FireParticleBurst(btn, "Confetti", "Confetti")
end
