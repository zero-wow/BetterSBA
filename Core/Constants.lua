local ADDON_NAME, NS = ...
_G.BetterSBA = NS

-- Version
NS.VERSION = "R1.2603.0100"
NS.ADDON_NAME = ADDON_NAME

-- SBA Spell
NS.SBA_SPELL_ID = 1229376

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

    -- Visibility
    onlyInCombat = false,
    alphaCombat = 1.0,
    alphaOOC = 0.6,
    hideInVehicle = true,

    -- Advanced
    updateRate = 0.1,
    checkVisibleButton = true,
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
