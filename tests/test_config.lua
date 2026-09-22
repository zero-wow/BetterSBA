-- Run from the addon root: lua tests/test_config.lua
local mock = assert(loadfile("tests/wow_ui_mock.lua"))()
local ui = mock.install()

local colors = {
    BG_DARK={.02,.03,.04,1}, BG_CARD={.04,.05,.06,1}, BG_HEADER={.06,.07,.08,1}, BG={.03,.04,.05,1}, BG_HOVER={.1,.12,.14,1},
    BORDER={.2,.25,.3,1}, BORDER_ACCENT={.2,.35,.45,1}, ACCENT={.2,.7,1,1}, ACCENT_DIM={.15,.45,.65,1}, ACCENT_BRIGHT={.4,.85,1,1},
    TEXT={.9,.9,.9,1}, TEXT_DIM={.6,.6,.6,1}, TEXT_MUTED={.4,.4,.4,1}, TOGGLE_ON={.2,.8,.5,1}, TOGGLE_OFF={.1,.1,.1,1}, DANGER={1,.2,.2,1},
}
local function color() return {.3,.6,.9,1} end
local defaults = {
    configPanelBaseHeight=480, configPanelHeight=480, configPanelScale=1, cfgAnimTransitions=false,
    sectionColorCombat=color(), sectionColorAppearance=color(), sectionColorActive=color(), sectionColorPriority=color(),
    sectionColorTalentBuilds=color(), sectionColorVisibility=color(), sectionColorImportance=color(), sectionColorAdvanced=color(), sectionColorProfiles=color(),
}
setmetatable(defaults, { __index = function() return false end })
local db = {}; for k, v in pairs(defaults) do db[k] = v end
db.castFeedback, db.castAnimation, db.buttonStyle = "Motion", "Off", "Soft"
db.talentBuildShowBuiltIn, db.talentBuildShowUser, db.talentBuildUseDefaultSort = true, true, true
db.talentBuildSearchText, db.talentBuildSourceFilter = "", "All"
for _, key in ipairs({"buttonBgColor", "priorityBgColor", "priorityBorderColor", "importColorAutoAttack", "importColorFiller", "importColorLongCD", "importColorMajorCD", "importColorShortCD"}) do
    db[key] = color()
end

local NS = {
    THEME=colors, defaults=defaults, db=db, dbRoot={profiles={}}, UIParent=ui.uiParent,
    CreateFrame=ui.createFrame, pairs=pairs, ipairs=ipairs, type=type, tostring=tostring, unpack=table.unpack,
    table_concat=table.concat, math_floor=math.floor, VERSION="test", NERD_FONT="Fonts\\FRIZQT__.TTF",
    TC={KEY="",UI="",VAL="",WARN="",NUM="",R=""},
    GLYPH_TRI_DOWN="v", GLYPH_TRI_RIGHT=">", GLYPH_CHEVRON_DOWN="v", GLYPH_CHEVRON_UP="^", GLYPH_DIAMOND="*", GLYPH_LOCK="L", GLYPH_UNLOCK="U", GLYPH_PLAY=">", GLYPH_STAR_EMPTY="o", GLYPH_STAR_FILLED="*",
    INTERCEPTION_TYPES={"Action Button", "Keybind"}, CAST_ANIMATIONS={"Off", "Pulse"}, FONT_OUTLINE_OPTIONS={"", "OUTLINE"},
    KEYBIND_ANCHORS={"TOPRIGHT"}, ANCHOR_POINTS={"CENTER"}, PARTICLE_STYLES={"Confetti"}, PARTICLE_TIMINGS={"On Cast"}, PARTICLE_STYLE_DEFAULTS={}, THEME_PRESET_ORDER={},
    PRIORITY_POSITIONS={"BOTTOM"},
    TALENT_BUILD_CUSTOM_ID="CUSTOM", TALENT_BUILD_TYPE_USER="user", TALENT_BUILD_TYPE_BUILTIN="builtin",
    TALENT_BUILD_FILTER_ALL="All", TALENT_BUILD_SOURCES={"All", "Very Long Source Alpha", "Very Long Source Bravo", "Very Long Source Charlie", "Very Long Source Delta", "Very Long Source Echo", "Very Long Source Foxtrot"},
    C_Timer_After=function() end, C_Timer_NewTicker=function() return {Cancel=function() end} end,
    GetConfigFontPath=function() return "Fonts\\FRIZQT__.TTF" end, GetConfigFontOutline=function() return "" end,
    GetFontList=function() return {} end, GetFontPath=function() return "Fonts\\FRIZQT__.TTF" end,
    AddTooltip=function() end, InCombatLockdown=function() return false end,
    IsClass=function() return false end, IsSpec=function() return false end, IsPetClass=function() return false end,
    GetMacroActions=function() return {} end, GetTrinketStatus=function() return {} end, GetActiveProfileName=function() return "Default" end,
    GetCharKey=function() return "Tester-Realm" end, GetCacheDiagnostics=function() return {} end,
    AnimKeyPrefix=function(animation) return "anim" .. tostring(animation) end,
    _restoreSection=false, _restoreScroll=false, _activeSection=1, _loadTime=0, _overrideKeys=false, _overrideSlot=false,
    masque=false, priorityFrame=false, mainButton=false, secureButton=false,
}
setmetatable(NS, { __index = function() return function() end end })
local entries = {}
for i, source in ipairs({"Very Long Source Alpha", "Very Long Source Bravo", "Very Long Source Charlie", "Very Long Source Delta", "Very Long Source Echo", "Very Long Source Foxtrot"}) do
    entries[i] = {id="BUILD-" .. i, name="Build " .. i, specID=(i % 2 == 0 and 101 or 100), author="Tester", source=source, catalogSource=source, rating="A", buildType="builtin", sourceURL="https://example.test/" .. i}
end
NS.GetTalentBuildSpecsForCurrentClass = function() return {{specID=100, index=1}, {specID=101, index=2}} end
NS.GetTalentBuildCurrentSpecID = function() return 100 end
NS.GetTalentBuildSpecName = function(id) return id == 100 and "Arcane" or "Fire" end
NS.GetTalentBuildClassToken = function() return "MAGE" end
NS.GetTalentBuildEntriesForClass = function() return entries end
NS.GetTalentBuildCustomEntry = function(id, name) return {id="CUSTOM", name="Custom", specID=id, specName=name, buildType="custom", source=""} end
NS.GetSelectedTalentBuildID = function() return "CUSTOM" end
NS.GetTalentBuildLastStatus = function() return nil end
NS.RequestTalentBuildApply = function() return true end
UnitClass = function() return "Mage", "MAGE", 8 end

assert(loadfile("GUI/Framework.lua"))("BetterSBA", NS)
assert(loadfile("GUI/TalentBuildsPanel.lua"))("BetterSBA", NS)
assert(loadfile("GUI/Config.lua"))("BetterSBA", NS)

local function newestSection(index)
    for i = #ui.frames, 1, -1 do
        if ui.frames[i]._kind == "Frame" and rawget(ui.frames[i], "_sectionIndex") == index then return ui.frames[i] end
    end
end

local function findTextWidget(frame, wanted)
    if rawget(frame, "_text") == wanted then return frame end
    for _, child in ipairs(frame._children) do
        local found = findTextWidget(child, wanted)
        if found then return found end
    end
end

local sectionLabels = {
    "Combat Assist", "Appearance", "Active Display", "Priority Display", "Talent Builds",
    "Visibility", "Importance", "Advanced", "Profiles",
}

local function navRows(panel)
    local function findButtonLabel(frame, wanted)
        if rawget(frame, "_text") == wanted and rawget(rawget(frame, "_parent"), "_kind") == "Button" then
            return rawget(frame, "_parent")
        end
        for _, child in ipairs(frame._children) do
            local found = findButtonLabel(child, wanted)
            if found then return found end
        end
    end
    local rows = {}
    for i, label in ipairs(sectionLabels) do
        rows[i] = assert(findButtonLabel(panel, label), "missing sidebar button: " .. label)
    end
    return rows
end

local function assertFixedSidebarRows(panel)
    local rows = navRows(panel)
    local sidebar = rawget(rows[1], "_parent")
    local sl, st, sr, sb = mock.rect(sidebar)
    assert(sr - sl == 200, "sidebar must retain its 200px width")
    for i, row in ipairs(rows) do
        assert(rawget(row, "_parent") == sidebar, "all section rows share the sidebar parent")
        local l, t, r, b = mock.rect(row)
        assert(row:GetHeight() == 32, "section row height must remain fixed")
        assert(l >= sl + 8 and r <= sr - 8, "section row must keep the sidebar gutter")
        assert(t <= st - 52 and b >= sb, "section row must remain in the sidebar")
        local expectedTop = st - 52 - (i - 1) * 36
        assert(math.abs(t - expectedTop) < 0.1,
            ("section row %d moved by an expanded disclosure (got %.1f, expected %.1f)"):format(i, t, expectedTop))
    end
end

local function assertActiveSectionInScrollRegion(index)
    local cf = assert(newestSection(index), "active content frame missing")
    local scrollChild = rawget(cf, "_parent")
    local scrollFrame = scrollChild and rawget(scrollChild, "_parent")
    assert(scrollFrame and rawget(scrollFrame, "_scrollChild") == scrollChild,
        "each disclosure section must remain parented to the scroll child")
    assert(scrollChild:GetHeight() == cf._contentH,
        "active disclosure height must be reserved by the scroll child")
    local expectedWidth = index == 5 and 872 or 612
    assert(cf:GetWidth() == expectedWidth and scrollChild:GetWidth() == expectedWidth,
        "section must use the active scroll-content width")
    local cl, ct, cr, cb = mock.rect(cf)
    for _, child in ipairs(cf._children) do
        local l, t, r, b = mock.rect(child)
        assert(l >= cl - .1 and r <= cr + .1, "direct disclosure control exceeds content width")
        assert(t <= ct + .1 and b >= cb - .1, "direct disclosure control escapes scroll content height")
    end
end

local function assertJumpMenuBounds(panel)
    local jump, menu = assert(NS.Config.sectionJump), assert(NS.Config.sectionMenu)
    if not jump:IsShown() then
        assert(not menu:IsShown(), "hidden Jump-to control must not leave its menu open")
        return
    end
    local pl, pt, pr, pb = mock.rect(panel)
    local jl, jt, jr, jb = mock.rect(jump)
    assert(jl >= pl and jr <= pr and jt <= pt and jb >= pb, "Jump-to button must fit the panel")
    local click = assert(jump:GetScript("OnClick"), "Jump-to button needs a click handler")
    click(jump)
    assert(menu:IsShown(), "Jump-to menu must open")
    local ml, mt, mr, mb = mock.rect(menu)
    assert(ml >= pl and mr <= pr and mt <= pt and mb >= pb, "Jump-to popover must fit the panel")
    local menuScroll = menu._children[1]
    local menuContent = menuScroll and rawget(menuScroll, "_scrollChild")
    assert(menuContent, "Jump-to popover requires a scroll-content frame")
    local cl, ct, cr, cb = mock.rect(menuContent)
    for _, child in ipairs(menuContent._children) do
        if child:IsShown() then
            local l, t, r, b = mock.rect(child)
            assert(child:GetHeight() == 28 and l >= cl and r <= cr and t <= ct and b >= cb,
                "Jump-to row must fit its scroll content")
        end
    end
    click(jump)
    assert(not menu:IsShown(), "Jump-to menu must close")
end

local panel = assert(NS.Config:Create())
assert(panel:GetWidth() == 820 and panel:GetHeight() == 480, "normal panel must begin at 820x480")
assertJumpMenuBounds(panel)
for i = 1, 9 do
    NS.Config.SelectSection(i)
    if i == 5 then
        assert(panel:GetWidth() == 1080 and panel:GetHeight() == 480, "Talent Builds must use 1080x480")
    else
        assert(panel:GetWidth() == 820 and panel:GetHeight() == 480, "non-talent sections must use 820x480")
    end
    assertFixedSidebarRows(panel)
    assertActiveSectionInScrollRegion(i)
    assertJumpMenuBounds(panel)
end

local function walk(frame)
    assert(frame._width >= 0 and frame._height >= 0, "widget has negative size")
    for _, child in ipairs(frame._children) do walk(child) end
end
walk(panel)
local motionAppearance = assert(newestSection(2))
local motionAppearanceH = motionAppearance:GetHeight()

-- The macro-preview hint disclosure is created before later sections. Its
-- callback must retain the Combat Assist frame rather than changing Profiles.
local profilesH = assert(newestSection(9)):GetHeight()
local hintsLabel = assert(findTextWidget(panel, "SHOW HINTS"), "macro hint control was not constructed")
local hintsButton = rawget(hintsLabel, "_parent")
local hintsClick = hintsButton:GetScript("OnClick")
assert(type(hintsClick) == "function", "macro hint control needs an OnClick handler")
hintsClick(hintsButton)
assert(newestSection(9):GetHeight() == profilesH, "macro hint disclosure must not alter Profiles height")

-- The mock gives un-sized FontStrings an estimated line box, so this guards
-- actual vertical/horizontal relationships in the trinket status row instead
-- of treating every label as a zero-height point.
local trinketName = assert(findTextWidget(panel, "Trinket 1"), "Trinket name text was not built")
local trinketRow = rawget(trinketName, "_parent")
local trinketReason = assert(findTextWidget(trinketRow, "No trinket information available."), "Trinket reason text was not built")
local trinketState = assert(findTextWidget(trinketRow, "Unavailable"), "Trinket state text was not built")
local nl, nt, nr, nb = mock.rect(trinketName)
local rl, rt = mock.rect(trinketReason)
local sl, st, sr, sb = mock.rect(trinketState)
assert(rt <= nb - .5, "trinket reason must start beneath the name line")
assert(sl >= nr + 4 or sb <= nb or st >= nt, "trinket state must not overlap the name")

-- Exercise all cast-feedback disclosure states through real Config construction.
local appearanceHeights = { Motion = motionAppearanceH }
for _, feedback in ipairs({"Classic", "Off"}) do
    db.castFeedback = feedback
    db.castAnimation = feedback == "Classic" and "Pulse" or "Off"
    NS.Config.frame = nil
    NS._restoreSection = false
    local rebuilt = assert(NS.Config:Create())
    NS.Config.SelectSection(2)
    assert(rebuilt:GetWidth() == 820 and rebuilt:GetHeight() == 480, feedback .. " appearance layout must remain 820x480")
    appearanceHeights[feedback] = assert(newestSection(2)):GetHeight()
end
assert(appearanceHeights.Classic > appearanceHeights.Off, ("Classic disclosure must reserve its particle/font controls (Classic %.0f, Off %.0f)"):format(appearanceHeights.Classic, appearanceHeights.Off))

-- Direct real Talent panel pass exposes its state for measured source-chip bounds.
local talentParent = ui.createFrame("Frame", nil, ui.uiParent)
talentParent:SetSize(872, 560)
talentParent._contentWidth, talentParent._sectionColor, talentParent._subsections = 872, color(), {}
talentParent._sectionColorDim, talentParent._sectionColorBright = color(), color()
local talentState = assert(NS.BuildTalentBuildsConfigSection(talentParent))
local sourceChips = {}
for _, child in ipairs(talentParent._children) do
    if rawget(child, "_source") then sourceChips[#sourceChips + 1] = child end
end
assert(#sourceChips == 6, "all dynamic source chips must be created")
local rows = {}
for _, chip in ipairs(sourceChips) do
    local l, t, r = mock.rect(chip)
    local pl, _, pr = mock.rect(talentParent)
    assert(l >= pl + 14 and r <= pr - 14, "source chip must stay within talent content bounds")
    rows[math.floor(t)] = true
end
local rowCount = 0; for _ in pairs(rows) do rowCount = rowCount + 1 end
assert(rowCount >= 2, "long source chips must wrap across rows")

-- Fixed-size rows and direct disclosure controls must remain inside their
-- scroll-content parent. This includes the two 66px trinket rows.
local trinketRows = 0
for _, frame in ipairs(ui.frames) do
    if frame._width == 584 and frame._height == 66 then
        local l, _, r = mock.rect(frame)
        local pl, _, pr = mock.rect(frame._parent)
        assert(l >= pl and r <= pr, "trinket row must fit its content width")
        trinketRows = trinketRows + 1
    end
end
assert(trinketRows >= 2, "expected both trinket rows")

print("config mock: actual Framework/Config/TalentBuildsPanel passed all sections, feedback states, and wrapped-source bounds")
if arg and arg[1] and arg[1] ~= "" then
    NS.Config:Show()
    NS.Config.SelectSection(tonumber(arg[2]) or 1)
    mock.writeSVG(NS.Config.frame, arg[1])
    print("config mock: wrote estimated-bounds SVG to " .. arg[1])
end
