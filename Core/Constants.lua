local ADDON_NAME, NS = ...
_G.BetterSBA = NS

-- Version: R<release>.<lines>.<git-hash>.<version>.<build>
--   release = major release (manual)
--   lines   = total code lines (auto)
--   git-hash= short commit hash (auto)
--   version = feature/milestone version (manual, bump via .scripts/version.sh bump)
--   build   = total commit count (auto)
NS.VERSION_RELEASE = 1
NS.VERSION_PATCH   = 4       -- bump this for feature milestones
NS.VERSION = "R1.3949.551bc59.0004.6"
NS.ADDON_NAME = ADDON_NAME

-- SBA Spell
NS.SBA_SPELL_ID = 1229376
NS.AUTO_ATTACK_SPELL_ID = 6603

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
    locked = false,
    buttonSize = 48,
    scale = 1.0,
    position = nil,

    -- Combat
    enableTargeting = true,
    enablePetAttack = true,
    enableChannelProtection = true,

    -- Display
    showKeybind = true,
    showCooldown = true,
    rangeColoring = true,
    keybindFontSize = 12,

    -- Queue
    showQueue = true,
    queueIconSize = 28,
    queueSpacing = 3,
    queuePosition = "RIGHT",
    queueDetached = false,
    queueFreePosition = nil,
    queueOffsetX = 0,
    queueOffsetY = 0,
    configPanelHeight = 600,

    -- Visibility
    onlyInCombat = false,
    alphaCombat = 1.0,
    alphaOOC = 0.6,
    hideInVehicle = true,
    queueAlphaOOC = 0.6,

    -- Font
    fontFace = "Friz Quadrata TT",
    fontOutline = "OUTLINE",
    queueLabelFontSize = 8,

    -- Queue label offset
    queueLabelOffsetX = 0,
    queueLabelOffsetY = 0,

    -- Background / border color
    buttonBgColor = { 0, 0, 0, 0.85 },
    queueBgColor = { 0, 0, 0, 0.7 },
    queueBorderColor = { 0.20, 0.22, 0.26, 0.6 },
    importanceBorders = true,

    -- Importance border colors (user-configurable)
    importColorAutoAttack = { 1.00, 1.00, 1.00, 1.0 },
    importColorFiller     = { 0.12, 1.00, 0.00, 1.0 },
    importColorShortCD    = { 0.00, 0.44, 0.87, 1.0 },
    importColorLongCD     = { 0.64, 0.21, 0.93, 1.0 },
    importColorMajorCD    = { 1.00, 0.50, 0.00, 1.0 },

    -- Animation
    castAnimation = "DRIFT",
    castAnimStyle = "RECREATE",

    -- Advanced
    updateRate = 0.1,
    checkVisibleButton = true,

    -- Minimap
    minimap = { hide = false },

    -- Debug
    debug = false,
}

-- Theme
NS.THEME = {
    BG            = { 0.06, 0.06, 0.08, 0.95 },
    BG_DARK       = { 0.03, 0.03, 0.04, 0.97 },
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

-- Cast animation types
NS.CAST_ANIMATIONS = { "NONE", "DRIFT", "PULSE", "SPIN", "ZOOM", "SLAM" }

-- Cast animation style (what happens to the main button)
NS.CAST_ANIM_STYLES = { "KEEP", "RECREATE" }

-- Queue position options
NS.QUEUE_POSITIONS = { "RIGHT", "LEFT", "TOP", "BOTTOM", "TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT" }

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
