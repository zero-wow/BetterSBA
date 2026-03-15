local ADDON_NAME, NS = ...

local DEFAULT_FONTS = {
    ["Friz Quadrata TT"]  = "Fonts\\FRIZQT__.TTF",
    ["Arial Narrow"]      = "Fonts\\ARIALN.TTF",
    ["Morpheus"]          = "Fonts\\MORPHEUS.TTF",
    ["Skurri"]            = "Fonts\\SKURRI.TTF",
    ["2002"]              = "Fonts\\2002.TTF",
    ["2002 Bold"]         = "Fonts\\2002B.TTF",
}
local DEFAULT_FONT_ORDER = { "Friz Quadrata TT", "Arial Narrow", "Morpheus", "Skurri", "2002", "2002 Bold" }

function NS.GetFontPath(fontName)
    fontName = fontName or (NS.db and NS.db.fontFace) or "Friz Quadrata TT"
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local path = LSM:Fetch("font", fontName)
        if path then return path end
    end
    return DEFAULT_FONTS[fontName] or "Fonts\\FRIZQT__.TTF"
end

function NS.GetFontList()
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then return LSM:List("font") end
    return DEFAULT_FONT_ORDER
end

----------------------------------------------------------------
-- Font outline helper
----------------------------------------------------------------
-- Outline display names â†’ WoW SetFont flags
NS.FONT_OUTLINE_OPTIONS = { "NONE", "OUTLINE", "THICKOUTLINE", "MONOCHROME", "MONO OUTLINE", "MONO THICKOUTLINE" }

local OUTLINE_MAP = {
    ["NONE"]               = "",
    ["OUTLINE"]            = "OUTLINE",
    ["THICKOUTLINE"]       = "THICKOUTLINE",
    ["MONOCHROME"]         = "MONOCHROME",
    ["MONO OUTLINE"]       = "MONOCHROME, OUTLINE",
    ["MONO THICKOUTLINE"]  = "MONOCHROME, THICKOUTLINE",
}

function NS.GetOutlineFlags(outlineSetting)
    outlineSetting = outlineSetting or "OUTLINE"
    return OUTLINE_MAP[outlineSetting] or outlineSetting
end

function NS.GetFontOutline()
    return NS.GetOutlineFlags(NS.db and NS.db.fontOutline or "OUTLINE")
end

function NS.GetConfigFontPath()
    local db = NS.db
    if db and db.configPanelFontOverride and db.configPanelFont then
        return NS.GetFontPath(db.configPanelFont)
    end
    return NS.GetFontPath(db and db.fontFace)
end

function NS.GetConfigFontOutline()
    local db = NS.db
    if db and db.configPanelFontOverride then
        return NS.GetOutlineFlags(db.configPanelOutline or "")
    end
    return NS.GetOutlineFlags(db and db.fontOutline or "OUTLINE")
end

-- Update all config panel fonts in-place (no rebuild needed)
function NS.UpdateAllConfigFonts()
    local f = NS.Config and NS.Config.frame
    if not f then return end
    local path = NS.GetConfigFontPath()
    local outline = NS.GetConfigFontOutline()
    local function WalkFrame(frame)
        -- FontStrings are regions, not children
        local regions = { frame:GetRegions() }
        for _, region in NS.ipairs(regions) do
            if region.IsObjectType and region:IsObjectType("FontString") then
                local curPath, size = region:GetFont()
                if size and curPath then
                    region:SetFont(path, size, outline)
                end
            end
        end
        -- Recurse into child frames
        local children = { frame:GetChildren() }
        for _, child in NS.ipairs(children) do
            WalkFrame(child)
        end
    end
    WalkFrame(f)
end

-- Resolve font path: context-specific if override enabled, else global fallback
function NS.ResolveFontPath(contextFontKey)
    local db = NS.db
    if not db then return NS.GetFontPath() end
    if db[contextFontKey .. "Override"] then
        return NS.GetFontPath(db[contextFontKey])
    end
    return NS.GetFontPath(db.fontFace)
end

-- Resolve font outline: context-specific if override enabled, else global fallback
function NS.ResolveFontOutline(contextFontKey, contextOutlineKey)
    local db = NS.db
    if not db then return NS.GetFontOutline() end
    if db[contextFontKey .. "Override"] then
        return NS.GetOutlineFlags(db[contextOutlineKey])
    end
    return NS.GetOutlineFlags(db.fontOutline)
end
