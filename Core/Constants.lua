local ADDON_NAME, NS = ...
_G.BetterSBA = NS

-- Version: R<release>.<lines>.<git-hash>.<version>.<build>
--   release = major release (manual)
--   lines   = total code lines (auto)
--   git-hash= short commit hash (auto)
--   version = feature/milestone version (manual, bump via .scripts/version.sh bump)
--   build   = total commit count (auto)
NS.VERSION_RELEASE = 1
NS.VERSION_PATCH   = 6       -- bump this for feature milestones
NS.VERSION = "R1.8835.3f961cf.0006.9"
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
    keybindFontSize = 12,
    keybindOffsetX = -5,
    keybindOffsetY = -5,
    keybindAnchor = "TOPRIGHT",

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
    priorityFreePosition = nil,
    priorityOffsetX = 0,
    priorityOffsetY = 0,
    showActiveGlow = true,
    configPanelHeight = 600,

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

    -- Config panel font
    configPanelFont = "Friz Quadrata TT",
    configPanelOutline = "",
    configPanelFontOverride = false,

    -- Animation
    castAnimation = "DRIFT",
    animateIncoming = false,
    animHideButton = true,

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

    -- Debug
    debug = false,
    debugSpellSubs = false,

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
NS.CAST_ANIMATIONS = { "NONE", "DRIFT", "PULSE", "SPIN", "ZOOM", "SLAM", "POP!" }

-- Priority display position options
NS.PRIORITY_POSITIONS = { "RIGHT", "LEFT", "TOP", "BOTTOM", "TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT" }

-- Keybind anchor point options
NS.KEYBIND_ANCHORS = { "TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT", "TOP", "BOTTOM", "LEFT", "RIGHT", "CENTER" }

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
