local ADDON_NAME, NS = ...

-- Lightweight cast feedback.  This deliberately owns only visual, unprotected
-- siblings of the display button: it never alters the button, secure overlay,
-- bindings, or action attributes.

local ASSET_ROOT = "Interface\\AddOns\\BetterSBA\\IMG\\Button\\"
local ROUNDED_RING = ASSET_ROOT .. "RoundedRing"
local SQUARE_RING = ASSET_ROOT .. "SquareRing"
local GLOW = ASSET_ROOT .. "Glow"
local SOLID = "Interface\\Buttons\\WHITE8X8"

local MAX_LAYERS = 3
local FALLBACK_ACCENT = { 0.30, 0.78, 1.00 }
local ECHO_OFFSETS = { { -10, 5, 0.00 }, { -18, 9, 0.04 }, { -26, 13, 0.08 } }
local motion = {
    layers = {},
    ready = false,
}

local function Clamp(value, low, high, fallback)
    value = tonumber(value)
    if not value then return fallback end
    if value < low then return low end
    if value > high then return high end
    return value
end

local function GetSettings()
    local db = NS.db or {}
    return db.motionPreset or "Pulse",
        Clamp(db.motionDuration, 0.16, 0.90, 0.40),
        Clamp(db.motionIntensity, 0.15, 1.00, 0.65),
        db.motionReduced == true
end

local function GetAccent()
    local accent = NS.THEME and NS.THEME.ACCENT or FALLBACK_ACCENT
    -- A little white keeps low-saturation themes visible without making the
    -- feedback compete with the recommendation icon.
    return accent[1] * 0.84 + 0.16,
        accent[2] * 0.84 + 0.16,
        accent[3] * 0.84 + 0.16
end

local function GetRingTexture()
    local style = NS.db and NS.db.buttonStyle
    return style == "Classic" and SQUARE_RING or ROUNDED_RING
end

local function StopLayer(layer)
    if not layer then return end
    if rawget(layer, "orbitAG") then layer.orbitAG:Stop() end
    if layer.ag then layer.ag:Stop() end
    layer:SetAlpha(1)
    layer:SetScale(1)
    layer:Hide()
end

local function CreateLayer(parent)
    local layer = NS.CreateFrame("Frame", nil, parent)
    layer:SetAllPoints(parent)
    layer:EnableMouse(false)
    layer:Hide()

    layer.tex = layer:CreateTexture(nil, "OVERLAY")
    layer.tex:SetAllPoints()
    layer.tex:SetBlendMode("ADD")
    layer.mask = layer:CreateMaskTexture()
    layer.mask:SetTexture(ASSET_ROOT .. "RoundedMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    layer.mask:SetAllPoints(layer.tex)
    layer.edge = layer:CreateTexture(nil, "OVERLAY")
    -- A solid streak remains visible when compressed to a few pixels high.
    -- The hollow Glow asset becomes almost transparent at that aspect ratio.
    layer.edge:SetTexture(SOLID)
    layer.edge:SetBlendMode("ADD")
    layer.edge:Hide()

    local ag = layer:CreateAnimationGroup()
    ag._alpha = ag:CreateAnimation("Alpha")
    ag._scale = ag:CreateAnimation("Scale")
    ag._translate = ag:CreateAnimation("Translation")
    ag:SetScript("OnFinished", function()
        -- Do not call AnimationGroup:Stop() here: completion is already final,
        -- while ResetMotionFeedback is the explicit cancellation path.
        layer:SetAlpha(1)
        layer:SetScale(1)
        layer:Hide()
    end)
    layer.ag = ag
    return layer
end

local function SetLayerTexture(layer, texture, r, g, b, alpha, texCoord)
    layer.tex:Show()
    layer.edge:Hide()
    local masked = texCoord and NS.UsesSoftButtonStyle and NS.UsesSoftButtonStyle()
    if masked and not layer._masked then
        layer.tex:AddMaskTexture(layer.mask)
        layer._masked = true
    elseif not masked and layer._masked then
        layer.tex:RemoveMaskTexture(layer.mask)
        layer._masked = false
    end
    layer.tex:SetTexture(texture)
    layer.tex:SetVertexColor(r, g, b, alpha)
    if texCoord then
        layer.tex:SetTexCoord(NS.unpack(texCoord))
    else
        layer.tex:SetTexCoord(0, 1, 0, 1)
    end
end

local function ConfigureLayer(layer, duration, startDelay, startAlpha, endAlpha,
    scale, offsetX, offsetY, smoothing)
    layer._initialAlpha = startAlpha
    local alpha = layer.ag._alpha
    alpha:SetFromAlpha(startAlpha)
    alpha:SetToAlpha(endAlpha)
    alpha:SetDuration(duration)
    alpha:SetStartDelay(startDelay or 0)
    alpha:SetSmoothing(smoothing or "OUT")

    local scaleAnim = layer.ag._scale
    scaleAnim:SetScale(scale or 1, scale or 1)
    scaleAnim:SetDuration(duration)
    scaleAnim:SetStartDelay(startDelay or 0)
    scaleAnim:SetSmoothing(smoothing or "OUT")
    scaleAnim:SetOrigin("CENTER", 0, 0)

    local translate = layer.ag._translate
    translate:SetOffset(offsetX or 0, offsetY or 0)
    translate:SetDuration(duration)
    translate:SetStartDelay(startDelay or 0)
    translate:SetSmoothing(smoothing or "OUT")
end

local function PlayLayer(layer)
    layer.ag:Stop()
    layer:SetAlpha(layer._initialAlpha or 1)
    layer:SetScale(1)
    layer:Show()
    layer.ag:Play()
end

local function IsEligible()
    local db = NS.db
    local button = NS.mainButton
    return db and db.enabled and button and button:IsVisible() and button:GetAlpha() > 0
end

local function CopyIconTexCoord(icon)
    if not icon or not icon.GetTexCoord then return nil end
    local coords = { icon:GetTexCoord() }
    return #coords > 0 and coords or nil
end

local function RunReducedFlash(duration, intensity)
    local layer = motion.layers[1]
    local r, g, b = GetAccent()
    SetLayerTexture(layer, GetRingTexture(), r, g, b, 0.40 + intensity * 0.30)
    ConfigureLayer(layer, duration, 0, 0.65 * intensity, 0, 1, 0, 0, "IN_OUT")
    PlayLayer(layer)
end

local function RunPulse(duration, intensity)
    local r, g, b = GetAccent()
    local first = motion.layers[1]
    local second = motion.layers[2]
    local glow = motion.layers[3]
    local ring = GetRingTexture()

    SetLayerTexture(first, ring, r, g, b, 0.50 + intensity * 0.32)
    ConfigureLayer(first, duration * 0.80, 0, 0.70 * intensity, 0, 1.10 + intensity * 0.10, 0, 0, "OUT")
    PlayLayer(first)

    SetLayerTexture(second, ring, r, g, b, 0.36 + intensity * 0.28)
    ConfigureLayer(second, duration * 0.72, duration * 0.12, 0.58 * intensity, 0,
        1.22 + intensity * 0.12, 0, 0, "OUT")
    PlayLayer(second)

    SetLayerTexture(glow, GLOW, r, g, b, 0.18 + intensity * 0.20)
    ConfigureLayer(glow, duration * 0.52, 0, 0.40 * intensity, 0, 1.02, 0, 0, "OUT")
    PlayLayer(glow)
end

local function RunEcho(spellID, duration, intensity)
    local button = NS.mainButton
    local icon = button and button.icon
    local texture = spellID and NS.GetSpellTextureCached and NS.GetSpellTextureCached(spellID)
    texture = texture or (icon and icon:GetTexture())
    if not texture then
        RunPulse(duration, intensity)
        return
    end

    local r, g, b = GetAccent()
    local texCoord = CopyIconTexCoord(icon)
    for index = 1, MAX_LAYERS do
        local layer = motion.layers[index]
        local offset = ECHO_OFFSETS[index]
        SetLayerTexture(layer, texture, r, g, b, 0.38 + intensity * 0.24, texCoord)
        ConfigureLayer(layer, duration * 0.70, duration * offset[3], 0.55 * intensity, 0,
            0.92, offset[1] * intensity, offset[2] * intensity, "OUT")
        PlayLayer(layer)
    end
end

local function RunSweep(duration, intensity)
    local r, g, b = GetAccent()
    local sweep = motion.layers[1]
    local rim = motion.layers[2]
    local glow = motion.layers[3]

    -- A short light moves along the lower edge, then dissolves. Reuse the
    -- pooled streak after Sheen or Orbit may have repositioned it.
    sweep.tex:Hide()
    sweep.edge:ClearAllPoints()
    sweep.edge:SetSize(motion.width * 0.28, 4)
    sweep.edge:SetPoint("CENTER", sweep, "BOTTOM", -motion.width * 0.36, 2)
    sweep.edge:SetRotation(0)
    sweep.edge:SetVertexColor(r, g, b, 1)
    sweep.edge:Show()
    ConfigureLayer(sweep, duration, 0, 0.95 * intensity, 0, 1,
        motion.width * 0.72, 0, "IN_OUT")
    PlayLayer(sweep)

    SetLayerTexture(rim, GetRingTexture(), r, g, b, 0.30 + intensity * 0.20)
    ConfigureLayer(rim, duration, 0, 0.48 * intensity, 0, 1.06, 0, 0, "IN_OUT")
    PlayLayer(rim)

    SetLayerTexture(glow, GLOW, r, g, b, 0.14 + intensity * 0.18)
    ConfigureLayer(glow, duration * 0.48, duration * 0.08, 0.32 * intensity, 0, 1, 4 * intensity, -3 * intensity, "OUT")
    PlayLayer(glow)
end

local function RunSheen(duration, intensity)
    local r, g, b = GetAccent()
    local sheen = motion.layers[1]
    local rim = motion.layers[2]
    local glow = motion.layers[3]

    sheen.tex:Hide()
    sheen.edge:ClearAllPoints()
    sheen.edge:SetSize(math.max(3, motion.width * 0.10), motion.width * 1.30)
    sheen.edge:SetPoint("CENTER", sheen, "CENTER", -motion.width * 0.58, 0)
    sheen.edge:SetRotation(math.pi / 9)
    sheen.edge:SetVertexColor(r, g, b, 0.70)
    sheen.edge:Show()
    ConfigureLayer(sheen, duration * 0.85, 0, 0.55 * intensity, 0, 1,
        motion.width * 1.16, 0, "IN_OUT")
    PlayLayer(sheen)

    SetLayerTexture(rim, GetRingTexture(), r, g, b, 0.30 + intensity * 0.18)
    ConfigureLayer(rim, duration * 0.85, 0, 0.32 * intensity, 0, 1.03, 0, 0, "IN_OUT")
    PlayLayer(rim)

    SetLayerTexture(glow, GLOW, r, g, b, 0.12 + intensity * 0.12)
    ConfigureLayer(glow, duration * 0.50, duration * 0.12, 0.25 * intensity, 0,
        1, 0, 0, "OUT")
    PlayLayer(glow)
end

local function RunSnap(duration, intensity)
    local r, g, b = GetAccent()
    local hit = motion.layers[1]
    local release = motion.layers[2]
    local glow = motion.layers[3]
    local ring = GetRingTexture()
    local hitTime = math.min(duration * 0.30, 0.12)

    SetLayerTexture(hit, ring, r, g, b, 0.65 + intensity * 0.25)
    ConfigureLayer(hit, hitTime, 0, 0.85 * intensity, 0, 0.88, 0, 0, "IN")
    PlayLayer(hit)

    SetLayerTexture(release, ring, r, g, b, 0.48 + intensity * 0.22)
    ConfigureLayer(release, duration * 0.48, hitTime * 0.65, 0.62 * intensity, 0,
        1.12, 0, 0, "OUT")
    PlayLayer(release)

    SetLayerTexture(glow, GLOW, r, g, b, 0.28 + intensity * 0.18)
    ConfigureLayer(glow, duration * 0.30, 0, 0.52 * intensity, 0, 1.02, 0, 0, "OUT")
    PlayLayer(glow)
end

local function RunOrbit(duration, intensity)
    local r, g, b = GetAccent()
    local spark = motion.layers[1]
    local rim = motion.layers[2]
    local glow = motion.layers[3]

    spark.tex:Hide()
    spark.edge:ClearAllPoints()
    spark.edge:SetSize(motion.width * 0.22, 4)
    spark.edge:SetPoint("CENTER", spark, "BOTTOM", 0, 2)
    spark.edge:SetRotation(0)
    spark.edge:SetVertexColor(r, g, b, 0.85)
    spark.edge:Show()
    ConfigureLayer(spark, duration, 0, 0.72 * intensity, 0, 1, 0, 0, "IN_OUT")
    PlayLayer(spark)
    spark.orbitRotation:SetDuration(duration)
    spark.orbitRotation:SetDegrees(320)
    spark.orbitAG:Play()

    SetLayerTexture(rim, GetRingTexture(), r, g, b, 0.30 + intensity * 0.20)
    ConfigureLayer(rim, duration, 0, 0.46 * intensity, 0, 1.02, 0, 0, "IN_OUT")
    PlayLayer(rim)

    SetLayerTexture(glow, GLOW, r, g, b, 0.12 + intensity * 0.12)
    ConfigureLayer(glow, duration * 0.60, duration * 0.12, 0.22 * intensity, 0,
        1, 0, 0, "OUT")
    PlayLayer(glow)
end

-- Creates the pooled frames and refreshes their base size out of combat.
-- Presets can reposition only the unprotected streak texture during combat.
function NS.InitializeMotionFeedback()
    local button = NS.mainButton
    if not button then return false end
    if InCombatLockdown and InCombatLockdown() then
        return motion.ready
    end

    if not motion.host then
        local host = NS.CreateFrame("Frame", nil, NS.UIParent)
        host:EnableMouse(false)
        for index = 1, MAX_LAYERS do
            motion.layers[index] = CreateLayer(host)
        end
        local spark = motion.layers[1]
        spark.orbitAG = spark.edge:CreateAnimationGroup()
        spark.orbitRotation = spark.orbitAG:CreateAnimation("Rotation")
        spark.orbitRotation:SetSmoothing("NONE")
        motion.host = host
    end

    NS.ResetMotionFeedback()
    local host = motion.host
    host:ClearAllPoints()
    host:SetScale(button:GetScale())
    host:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
    host:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
    host:SetFrameStrata(button:GetFrameStrata())
    -- Pulse and Echo pass behind the recommendation, keeping the icon and key readable.
    host:SetFrameLevel(math.max(0, button:GetFrameLevel() - 2))
    motion.width = button:GetWidth()
    motion.layers[1].orbitRotation:SetOrigin("CENTER", 0, motion.width / 2 - 2)
    for _, layer in ipairs(motion.layers) do
        layer.edge:ClearAllPoints()
        layer.edge:SetSize(motion.width * 0.28, 4)
        layer.edge:SetPoint("CENTER", layer, "BOTTOM", -motion.width * 0.36, 2)
    end
    host:Show()
    motion.ready = true
    return true
end

function NS.ResetMotionFeedback()
    for index = 1, #motion.layers do
        StopLayer(motion.layers[index])
    end
end

-- Called after a confirmed cast.  It is intentionally one-shot: AnimationGroup
-- owns completion and ResetMotionFeedback interrupts a previous run cleanly.
function NS.PlayMotionFeedback(spellID)
    if not IsEligible() then
        NS.ResetMotionFeedback()
        return false
    end
    if not motion.ready and not NS.InitializeMotionFeedback() then
        return false
    end

    NS.ResetMotionFeedback()
    motion.host:SetAlpha(NS.mainButton:GetAlpha())
    local preset, duration, intensity, reduced = GetSettings()
    -- Traveling glints cross above the icon; soft rings remain behind it.
    local buttonLevel = NS.mainButton:GetFrameLevel()
    local behind = math.max(0, buttonLevel - 1)
    motion.host:SetFrameLevel(math.max(0, behind - 1))
    for index, layer in ipairs(motion.layers) do
        layer:SetFrameLevel((not reduced and (preset == "Sweep" or preset == "Sheen" or preset == "Orbit") and index == 1)
            and buttonLevel + 2 or behind)
    end
    if reduced then
        RunReducedFlash(duration, intensity)
    elseif preset == "Echo" then
        RunEcho(spellID, duration, intensity)
    elseif preset == "Sweep" then
        RunSweep(duration, intensity)
    elseif preset == "Sheen" then
        RunSheen(duration, intensity)
    elseif preset == "Snap" then
        RunSnap(duration, intensity)
    elseif preset == "Orbit" then
        RunOrbit(duration, intensity)
    else
        RunPulse(duration, intensity)
    end
    return true
end

-- Settings-preview entry point: it deliberately only starts the visual.
function NS.PreviewMotionFeedback()
    local button = NS.mainButton
    return NS.PlayMotionFeedback(button and button.spellID)
end
