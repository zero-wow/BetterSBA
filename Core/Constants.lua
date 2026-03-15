local ADDON_NAME, NS = ...
_G.BetterSBA = NS

-- Version: R<release>.<lines>.<git-hash>.<version>.<build>
--   release = major release (manual)
--   lines   = total code lines (auto)
--   git-hash= short commit hash (auto)
--   version = feature/milestone version (manual, bump via .scripts/version.sh bump)
--   build   = total commit count (auto)
NS.VERSION_RELEASE = 1
NS.VERSION_PATCH   = 7       -- bump this for feature milestones
NS.VERSION = "R1.13041.31de34a.0007.16"
NS.ADDON_NAME = ADDON_NAME

-- SBA Spell
NS.SBA_SPELL_ID = 1229376
NS.AUTO_ATTACK_SPELL_ID = 6603
-- Class-specific off-GCD ability spell IDs
NS.DEMON_SPIKES_SPELL_ID    = 203720   -- Vengeance DH
NS.SHIELD_BLOCK_SPELL_ID    = 2565     -- Protection Warrior
NS.IGNORE_PAIN_SPELL_ID     = 190456   -- Protection Warrior
NS.IRONFUR_SPELL_ID         = 192081   -- Guardian Druid
NS.SHIELD_OF_RIGHTEOUS_ID   = 53600    -- Protection Paladin
NS.RUNE_TAP_SPELL_ID        = 194679   -- Blood DK (talent)
NS.PURIFYING_BREW_SPELL_ID  = 119582   -- Brewmaster Monk

-- Icon TexCoord (crops baked-in Blizzard borders)
NS.ICON_TEXCOORD = { 0.08, 0.92, 0.08, 0.92 }

-- Spell importance border colors (based on base cooldown duration)
NS.SPELL_IMPORTANCE = {
    AUTO_ATTACK = { 1.00, 1.00, 1.00, 1.0 },  -- White
    FILLER      = { 0.12, 1.00, 0.00, 1.0 },  -- Green
    SHORT_CD    = { 0.00, 0.44, 0.87, 1.0 },  -- Blue
    LONG_CD     = { 0.64, 0.21, 0.93, 1.0 },  -- Purple
    MAJOR_CD    = { 1.00, 0.50, 0.00, 1.0 },  -- Orange
}

NS.SPELL_IMPORTANCE_BRIGHT = {
    AUTO_ATTACK = { 1.00, 1.00, 1.00, 1.0 },
    FILLER      = { 0.40, 1.00, 0.30, 1.0 },
    SHORT_CD    = { 0.30, 0.64, 1.00, 1.0 },
    LONG_CD     = { 0.80, 0.45, 1.00, 1.0 },
    MAJOR_CD    = { 1.00, 0.70, 0.30, 1.0 },
}

-- Icon
NS.ICON_PATH = "Interface\\AddOns\\BetterSBA\\IMG\\BetterSBA"

-- Nerd Font (for special glyphs: stars, arrows, play/stop, etc.)
NS.NERD_FONT = "Interface\\AddOns\\BetterSBA\\Fonts\\CascadiaCodeNF-SemiBold.ttf"

-- Glyph constants (UTF-8 sequences for Nerd Font characters)
NS.GLYPH_STAR_FILLED  = "\226\152\133"   -- ★ U+2605
NS.GLYPH_STAR_EMPTY   = "\226\152\134"   -- ☆ U+2606
NS.GLYPH_TRI_DOWN     = "\226\150\190"   -- ▾ U+25BE
NS.GLYPH_TRI_RIGHT    = "\226\150\184"   -- ▸ U+25B8
NS.GLYPH_PLAY         = "\226\150\182"   -- ▶ U+25B6
NS.GLYPH_STOP         = "\226\150\160"   -- ■ U+25A0
NS.GLYPH_DIAMOND      = "\226\151\134"   -- ◆ U+25C6
NS.GLYPH_CHEVRON_DOWN = "\226\150\188"   -- ▼ U+25BC
NS.GLYPH_CHEVRON_UP   = "\226\150\178"   -- ▲ U+25B2
NS.GLYPH_LOCK         = "\226\150\160"   -- ■ U+25A0 (solid = locked)
NS.GLYPH_UNLOCK       = "\226\150\161"   -- □ U+25A1 (hollow = unlocked)

-- API Cache
NS.CreateFrame = CreateFrame
NS.UIParent = UIParent
NS.pcall = pcall
NS.unpack = unpack
NS.pairs = pairs
NS.ipairs = ipairs
NS.type = type
NS.tostring = tostring
NS.math_floor = math.floor
NS.math_ceil = math.ceil
NS.table_insert = table.insert
NS.table_concat = table.concat
NS.GetBindingKey = GetBindingKey
NS.GetActionInfo = GetActionInfo
NS.InCombatLockdown = InCombatLockdown
NS.IsShiftKeyDown = IsShiftKeyDown
NS.UnitExists = UnitExists
NS.UnitIsDead = UnitIsDead
NS.UnitCanAttack = UnitCanAttack

NS.C_Timer_NewTicker = C_Timer.NewTicker
NS.C_Timer_After = C_Timer.After
NS.C_Spell = C_Spell
NS.C_AssistedCombat = C_AssistedCombat
NS.C_ActionBar = C_ActionBar
NS.C_AddOns = C_AddOns

-- Binding header (for Bindings.xml)
BINDING_HEADER_BETTERSBA = "BetterSBA"

-- Defaults
NS.defaults = {
    enabled = true,
    locked = true,
    buttonSize = 48,
    scale = 1.0,
    position = nil,

    -- Combat
    enableDismount = true,
    enableTargeting = true,
    enablePetAttack = true,
    enableChannelProtection = true,
    interceptionType = "Keybind",

    -- Class-specific combat options (off-GCD abilities appended after /cast SBA)
    enableDemonSpikes = true,       -- Vengeance DH: /cast Demon Spikes
    enableShieldBlock = true,       -- Prot Warrior: /cast Shield Block
    enableIgnorePain = false,       -- Prot Warrior: /cast Ignore Pain (off by default — drains Rage)
    enableIronfur = true,           -- Guardian Druid: /cast Ironfur
    enableShieldOfRighteous = true, -- Prot Paladin: /cast Shield of the Righteous
    enableRuneTap = false,          -- Blood DK: /cast Rune Tap (off by default — talent, short duration)
    enablePurifyingBrew = false,    -- Brewmaster: /cast Purifying Brew (off by default — situational)

    -- Display
    showKeybind = true,
    showCooldown = true,
    rangeColoring = true,
    outOfRangeSound = false,
    spellUsability = false,
    keybindFontSize = 12,
    keybindOffsetX = -5,
    keybindOffsetY = -5,
    keybindAnchor = "TOPRIGHT",
    animCloneKeybindOffsetX = -5,
    animCloneKeybindOffsetY = -5,

    -- Priority Display
    showPriority = true,
    priorityIconSize = 28,
    prioritySpacing = 3,
    priorityPosition = "RIGHT",
    showPriorityKeybinds = false,
    priorityKeybindFontSize = 7,
    priorityKeybindOffsetX = -5,
    priorityKeybindOffsetY = -5,
    priorityKeybindAnchor = "TOPRIGHT",
    priorityDetached = false,
    priorityLocked = true,
    priorityFreePosition = nil,
    priorityBindFrame = "BetterSBA_MainButton",
    priorityMyPoint = "LEFT",
    priorityTheirPoint = "RIGHT",
    priorityOffsetX = 0,
    priorityOffsetY = 0,
    showActiveGlow = true,
    configPanelHeight = 620,

    -- Visibility
    onlyInCombat = false,
    alphaCombat = 1.0,
    alphaOOC = 0.6,
    hideInVehicle = true,
    priorityAlphaOOC = 0.6,

    -- Font (per-context, with override toggles)
    fontFace = "Friz Quadrata TT",
    fontOutline = "OUTLINE",
    keybindFont = "Friz Quadrata TT",
    keybindOutline = "OUTLINE",
    keybindFontOverride = false,
    priorityKeybindFont = "Friz Quadrata TT",
    priorityKeybindOutline = "OUTLINE",
    priorityKeybindFontOverride = false,
    priorityLabelFont = "Friz Quadrata TT",
    priorityLabelOutline = "OUTLINE",
    priorityLabelFontOverride = false,
    priorityLabelFontSize = 8,
    pauseSymbolFont = "Friz Quadrata TT",
    pauseSymbolOutline = "OUTLINE",
    pauseSymbolFontOverride = false,
    pauseSymbolFontSize = 14,
    pauseReasonFont = "Friz Quadrata TT",
    pauseReasonOutline = "OUTLINE",
    pauseReasonFontOverride = false,
    pauseReasonFontSize = 9,

    -- Priority label offset
    priorityLabelOffsetX = 0,
    priorityLabelOffsetY = 0,

    -- Background / border color
    buttonBgColor = { 0, 0, 0, 0.85 },
    priorityBgColor = { 0, 0, 0, 0.7 },
    priorityBorderColor = { 0.20, 0.22, 0.26, 0.6 },
    importanceBorders = true,

    -- Importance border colors (user-configurable)
    importColorAutoAttack = { 1.00, 1.00, 1.00, 1.0 },
    importColorFiller     = { 0.12, 1.00, 0.00, 1.0 },
    importColorShortCD    = { 0.00, 0.44, 0.87, 1.0 },
    importColorLongCD     = { 0.64, 0.21, 0.93, 1.0 },
    importColorMajorCD    = { 1.00, 0.50, 0.00, 1.0 },

    -- Section theme colors (config panel groups)
    sectionColorCombat     = { 1.00, 0.45, 0.15, 1.0 },
    sectionColorAppearance = { 0.72, 0.52, 0.95, 1.0 },
    sectionColorActive     = { 0.30, 0.78, 1.00, 1.0 },
    sectionColorPriority   = { 0.20, 0.90, 0.45, 1.0 },
    sectionColorVisibility = { 0.30, 0.95, 0.80, 1.0 },
    sectionColorImportance = { 1.00, 0.82, 0.20, 1.0 },
    sectionColorAdvanced   = { 1.00, 0.30, 0.30, 1.0 },
    sectionColorProfiles   = { 0.85, 0.65, 0.30, 1.0 },
    -- (subColor* keys removed — sub-headers now use parent section color)

    -- Theme
    themePreset = "Default",

    -- Config panel font
    configPanelFont = "Friz Quadrata TT",
    configPanelOutline = "",
    configPanelFontOverride = false,

    -- Animation
    castAnimation = "DRIFT",
    animateIncoming = false,
    gcdDuration = 1.9,
    animHideButton = true,
    animCloneMasque = true,
    animCloneReapplyKey = "",

    -- Particle system (per-animation: <animKey>Particles, <animKey>ParticleTiming, etc.)
    -- POP! has particles ON by default, all others OFF
    driftParticles = false,  driftParticleTiming = "On Cast",  driftParticleStyle = "Confetti",  driftParticlePalette = "Confetti",
    pulseParticles = false,  pulseParticleTiming = "On Cast",  pulseParticleStyle = "Confetti",  pulseParticlePalette = "Confetti",
    vortexParticles = false, vortexParticleTiming = "On Cast",  vortexParticleStyle = "Confetti",  vortexParticlePalette = "Confetti",
    zoomParticles  = false,  zoomParticleTiming  = "On Cast",  zoomParticleStyle  = "Confetti",  zoomParticlePalette  = "Confetti",
    slamParticles  = false,  slamParticleTiming  = "On Cast",  slamParticleStyle  = "Confetti",  slamParticlePalette  = "Confetti",
    popParticles   = true,   popParticleTiming   = "On Cast",  popParticleStyle   = "Confetti",  popParticlePalette   = "Confetti",
    burstParticles = true,   burstParticleTiming = "On Cast",  burstParticleStyle = "Sparks",    burstParticlePalette = "Gold",
    driftParticleDelay = 0.3,  pulseParticleDelay = 0.3,  vortexParticleDelay = 0.3,
    zoomParticleDelay = 0.3,   slamParticleDelay = 0.3,   popParticleDelay = 0.3,
    burstParticleDelay = 0.3,  fadeParticleDelay = 0.3,   flipParticleDelay = 0.3,
    riseParticleDelay = 0.3,   scatterParticleDelay = 0.3,
    fadeParticles  = false,  fadeParticleTiming  = "On Cast",  fadeParticleStyle  = "Confetti",  fadeParticlePalette  = "Confetti",
    flipParticles  = false,  flipParticleTiming  = "On Cast",  flipParticleStyle  = "Confetti",  flipParticlePalette  = "Confetti",
    riseParticles  = false,  riseParticleTiming  = "On Cast",  riseParticleStyle  = "Confetti",  riseParticlePalette  = "Confetti",
    scatterParticles = false, scatterParticleTiming = "On Cast", scatterParticleStyle = "Confetti", scatterParticlePalette = "Confetti",

    -- Config panel animation toggles
    cfgAnimTransitions = true,

    -- Advanced
    updateRate = 0.1,
    checkVisibleButton = true,

    -- Minimap / LDB
    minimap = { hide = false },
    showMinimapButton = true,
    ldbShowText = true,
    minimapIconSize = 19,
    minimapIconOffsetX = 0,
    minimapIconOffsetY = 0,

    -- GC
    enableGC = false,
    gcTargetMB = 0,

    -- Debug
    debug = false,
    debugSpellUpdates = true,
    debugAnimClone = true,
    debugOther = true,

    -- Modifier scaling
    modifierScaling = true,
    configPanelScale = 1.0,
    priorityScale = 1.0,
}

-- Theme
NS.THEME = {
    BG            = { 0.06, 0.06, 0.08, 0.95 },
    BG_DARK       = { 0.03, 0.03, 0.04, 0.97 },
    BG_CARD       = { 0.08, 0.08, 0.11, 0.95 },
    BG_HEADER     = { 0.08, 0.08, 0.10, 0.98 },
    BG_HOVER      = { 0.12, 0.12, 0.16, 1.0 },

    ACCENT        = { 0.40, 0.72, 0.85, 1.0 },
    ACCENT_DIM    = { 0.28, 0.52, 0.62, 0.7 },
    ACCENT_BRIGHT = { 0.55, 0.85, 0.95, 1.0 },

    TEXT          = { 0.90, 0.92, 0.94, 1.0 },
    TEXT_DIM      = { 0.58, 0.60, 0.65, 1.0 },
    TEXT_MUTED    = { 0.40, 0.42, 0.46, 1.0 },

    BORDER        = { 0.20, 0.22, 0.26, 0.6 },
    BORDER_ACCENT = { 0.40, 0.72, 0.85, 0.4 },

    TOGGLE_ON     = { 0.30, 0.72, 0.50, 1.0 },
    TOGGLE_OFF    = { 0.22, 0.22, 0.26, 1.0 },

    DANGER        = { 0.85, 0.30, 0.30, 1.0 },
    OUT_OF_RANGE  = { 0.85, 0.20, 0.20, 1.0 },

    NEON_NEXT     = { 0.00, 1.00, 0.85, 1.0 },  -- Neon cyan for next-cast highlight
}

----------------------------------------------------------------
-- Theme presets
NS.THEME_PRESETS = {
    Default = {
        ACCENT = { 0.40, 0.72, 0.85 },
        ACCENT_DIM = { 0.28, 0.52, 0.62 },
        ACCENT_BRIGHT = { 0.55, 0.85, 0.95 },
        TOGGLE_ON = { 0.30, 0.72, 0.50 },
        NEON_NEXT = { 0.00, 1.00, 0.85 },
    },
    Obsidian = {
        ACCENT = { 0.55, 0.55, 0.60 },
        ACCENT_DIM = { 0.35, 0.35, 0.40 },
        ACCENT_BRIGHT = { 0.70, 0.70, 0.75 },
        TOGGLE_ON = { 0.50, 0.55, 0.60 },
        NEON_NEXT = { 0.80, 0.85, 0.90 },
    },
    Arcane = {
        ACCENT = { 0.65, 0.40, 0.95 },
        ACCENT_DIM = { 0.45, 0.28, 0.68 },
        ACCENT_BRIGHT = { 0.80, 0.55, 1.00 },
        TOGGLE_ON = { 0.55, 0.35, 0.85 },
        NEON_NEXT = { 0.70, 0.30, 1.00 },
    },
    Fel = {
        ACCENT = { 0.40, 0.85, 0.30 },
        ACCENT_DIM = { 0.28, 0.60, 0.22 },
        ACCENT_BRIGHT = { 0.55, 1.00, 0.40 },
        TOGGLE_ON = { 0.35, 0.80, 0.25 },
        NEON_NEXT = { 0.30, 1.00, 0.20 },
    },
    Blood = {
        ACCENT = { 0.85, 0.25, 0.25 },
        ACCENT_DIM = { 0.60, 0.18, 0.18 },
        ACCENT_BRIGHT = { 1.00, 0.40, 0.40 },
        TOGGLE_ON = { 0.80, 0.30, 0.30 },
        NEON_NEXT = { 1.00, 0.20, 0.20 },
    },
    Gold = {
        ACCENT = { 0.90, 0.75, 0.30 },
        ACCENT_DIM = { 0.65, 0.52, 0.20 },
        ACCENT_BRIGHT = { 1.00, 0.88, 0.45 },
        TOGGLE_ON = { 0.85, 0.70, 0.25 },
        NEON_NEXT = { 1.00, 0.85, 0.00 },
    },
    Frost = {
        ACCENT = { 0.50, 0.80, 1.00 },
        ACCENT_DIM = { 0.35, 0.55, 0.72 },
        ACCENT_BRIGHT = { 0.65, 0.90, 1.00 },
        TOGGLE_ON = { 0.40, 0.75, 0.90 },
        NEON_NEXT = { 0.30, 0.70, 1.00 },
    },
}
NS.THEME_PRESET_ORDER = { "Default", "Obsidian", "Arcane", "Fel", "Blood", "Gold", "Frost" }

-- Spell substitution table: maps bad/obsolete spell IDs from the
-- SBA API to the correct spell IDs.  Checked BEFORE auto-resolution
-- (FindSpellOverrideByID), so manual entries always win.
--
-- Usage:  [badSpellID] = correctSpellID
-- Example: [203782] = 263642   -- Shear → Fracture (VDH)
----------------------------------------------------------------
NS.SPELL_SUBSTITUTIONS = {
    -- Add manual overrides here when auto-resolution can't fix them.
    -- The auto-resolver handles most talent-replaced spells automatically
    -- via FindSpellOverrideByID / C_Spell.GetOverrideSpell.
}

-- Cast animation types
NS.CAST_ANIMATIONS = { "NONE", "DRIFT", "PULSE", "VORTEX", "ZOOM", "SLAM", "POP!", "BURST", "FADE", "FLIP", "RISE", "SCATTER" }

-- Apply theme preset to the active THEME table
function NS.ApplyThemePreset(presetName)
    local preset = NS.THEME_PRESETS[presetName]
    if not preset then return end
    local T = NS.THEME
    for key, color in NS.pairs(preset) do
        if T[key] then
            T[key][1] = color[1]
            T[key][2] = color[2]
            T[key][3] = color[3]
            -- Preserve existing alpha
        end
    end
end

-- Animation key normalization: "POP!" → "pop", "DRIFT" → "drift"
function NS.AnimKeyPrefix(animType)
    return (animType or ""):gsub("[^%a]", ""):lower()
end

-- Particle system options
NS.PARTICLE_STYLES = { "None", "Random", "Confetti", "Lasers", "Sparks", "Squares" }
NS.PARTICLE_TIMINGS = { "On Cast", "On Animation End", "Both" }
-- "Specific" is added dynamically by CreateTimingDropdown as an input entry

-- Per-style particle defaults: when user picks a style, timing + palette auto-switch
NS.PARTICLE_STYLE_DEFAULTS = {
    None     = { timing = "On Cast",           palette = "Confetti" },
    Confetti = { timing = "On Cast",           palette = "Confetti" },
    Lasers   = { timing = "On Cast",           palette = "Neon" },
    Random   = { timing = "On Cast",           palette = "Confetti" },
    Sparks   = { timing = "On Animation End",  palette = "Gold" },
    Squares  = { timing = "Both",              palette = "Magic" },
}

-- Palette definitions moved to Core/Palettes.lua

----------------------------------------------------------------
-- AddonCompartment (minimap menu in 12.x+)
----------------------------------------------------------------
function BetterSBA_OnAddonCompartmentClick(addonName, buttonName)
    if buttonName == "RightButton" then
        NS.Config:Toggle()
    else
        NS.Config:Toggle()
    end
end

function BetterSBA_OnAddonCompartmentEnter(addonName, menuButtonFrame)
    GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
    GameTooltip:SetText("|cFF66B8D9Better|r|cFFFFFFFFSBA|r")
    GameTooltip:AddLine("Click to open settings", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

function BetterSBA_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

-- Interception type options
NS.INTERCEPTION_TYPES = { "Keybind", "Click", "Both" }

-- Priority display position options
NS.PRIORITY_POSITIONS = { "RIGHT", "LEFT", "TOP", "BOTTOM", "TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT" }

-- Anchor point options (shared by keybind anchors and priority binding)
NS.ANCHOR_POINTS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
NS.KEYBIND_ANCHORS = { "TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT", "TOP", "BOTTOM", "LEFT", "RIGHT", "CENTER" }

-- Frame presets for Priority Display binding
NS.PRIORITY_BIND_FRAMES = {
    "BetterSBA_MainButton",
    "UIParent",
    "BetterSBA_PriorityFrame",
}

-- Keybind abbreviations
NS.KEYBIND_SUBS = {
    ["ALT%-"]          = "A-",
    ["CTRL%-"]         = "C-",
    ["SHIFT%-"]        = "S-",
    ["NUMPAD"]         = "N",
    ["MOUSEWHEELUP"]   = "MwU",
    ["MOUSEWHEELDOWN"] = "MwD",
    ["BUTTON"]         = "M",
    ["BACKSPACE"]      = "Bk",
    ["DELETE"]         = "Del",
    ["INSERT"]         = "Ins",
    ["SPACE"]          = "Sp",
    ["ESCAPE"]         = "Esc",
    ["PAGEUP"]         = "PU",
    ["PAGEDOWN"]       = "PD",
}
