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
    configPanelBaseHeight=480, configPanelHeight=620, configPanelScale=1, cfgAnimTransitions=false,
    sectionColorCombat=color(), sectionColorAppearance=color(), sectionColorActive=color(), sectionColorPriority=color(),
    sectionColorTalentBuilds=color(), sectionColorVisibility=color(), sectionColorImportance=color(), sectionColorAdvanced=color(), sectionColorProfiles=color(),
}
setmetatable(defaults, { __index = function() return false end })
local db = {}; for k, v in pairs(defaults) do db[k] = v end
-- A prior user-resized 413px panel exceeds the new 400px safety floor and
-- must be honored rather than reset to the default compact height.
db.configPanelBaseHeight, db.configPanelHeight = 413, 413
db.castFeedback, db.castAnimation, db.buttonStyle = "Motion", "Off", "Soft"
db.talentBuildShowBuiltIn, db.talentBuildShowUser, db.talentBuildUseDefaultSort = true, true, true
db.talentBuildSearchText, db.talentBuildSourceFilter = "", "All"
for _, key in ipairs({"buttonBgColor", "priorityBgColor", "priorityBorderColor", "importColorAutoAttack", "importColorFiller", "importColorLongCD", "importColorMajorCD", "importColorShortCD"}) do
    db[key] = color()
end
-- Opening a page fires every slider's real OnShow initializer. Supply values
-- for the full slider surface so lifecycle coverage does not accidentally
-- depend on a mock that suppresses those handlers.
for _, key in ipairs({
    "motionDuration", "motionIntensity", "gcdDuration", "keybindFontSize",
    "priorityKeybindFontSize", "priorityLabelFontSize", "pauseSymbolFontSize",
    "pauseReasonFontSize", "buttonSize", "scale", "keybindOffsetX", "keybindOffsetY",
    "animCloneKeybindOffsetX", "animCloneKeybindOffsetY", "animCloneKeybindFontSize",
    "priorityIconSize", "priorityScale", "prioritySpacing", "priorityOffsetX",
    "priorityOffsetY", "priorityKeybindOffsetX", "priorityKeybindOffsetY",
    "priorityLabelOffsetX", "priorityLabelOffsetY", "alphaOOC", "priorityAlphaOOC",
}) do
    db[key] = 1
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
    masque=false, priorityFrame=false, mainButton=false, secureButton=false, _priorityIcons=false,
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
NS.GetInterceptBlockReason = function() return nil end
UnitClass = function() return "Mage", "MAGE", 8 end

assert(loadfile("GUI/Framework.lua"))("BetterSBA", NS)
assert(loadfile("GUI/TalentBuildsPanel.lua"))("BetterSBA", NS)
assert(loadfile("GUI/Config.lua"))("BetterSBA", NS)

-- The config root has several OnShow/OnHide hooks. Verify the widget harness
-- preserves primary scripts plus every hook and honours ancestor visibility.
local lifecycleParent = ui.createFrame("Frame", nil, ui.uiParent)
lifecycleParent:Hide()
local lifecycleChild = ui.createFrame("Frame", nil, lifecycleParent)
local lifecycleOrder = {}
lifecycleChild:SetScript("OnShow", function() lifecycleOrder[#lifecycleOrder + 1] = "script" end)
lifecycleChild:HookScript("OnShow", function() lifecycleOrder[#lifecycleOrder + 1] = "hook-one" end)
lifecycleChild:HookScript("OnShow", function() lifecycleOrder[#lifecycleOrder + 1] = "hook-two" end)
assert(lifecycleChild:IsShown() and not lifecycleChild:IsVisible(),
    "a shown child of a hidden frame must not be treated as visible")
lifecycleParent:Show()
assert(table.concat(lifecycleOrder, ",") == "script,hook-one,hook-two",
    "Show must preserve the primary script and every HookScript callback")
lifecycleParent:Hide()
assert(lifecycleChild:IsShown() and not lifecycleChild:IsVisible(),
    "hiding an ancestor must make descendants non-visible without clearing local state")

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

local function findHeaderWidget(frame, wanted)
    if rawget(frame, "_text") == wanted and rawget(frame, "_line") then return frame end
    for _, child in ipairs(frame._children) do
        local found = findHeaderWidget(child, wanted)
        if found then return found end
    end
end

local tabLabels = {
    "Combat", "Style", "Button", "Priority", "Talents",
    "Visibility", "Colors", "Advanced", "Profiles",
}

local function assertTopTabs(panel)
    local tabBar = assert(NS.Config.tabBar, "top tab bar must be exposed")
    local buttons = assert(NS.Config.sectionButtons, "section tabs must be exposed")
    assert(#buttons == 9, "exactly nine top-level section tabs are required")
    assert(tabBar:GetHeight() == 34, "top navigation strip must retain a 34px hit target")

    local pl, pt, pr = mock.rect(panel)
    local bl, bt, br, bb = mock.rect(tabBar)
    assert(math.abs(bl - pl) < .1 and math.abs(br - pr) < .1,
        "tab bar must span the panel width")
    assert(math.abs(bt - (pt - 40)) < .1 and math.abs(bb - (bt - 34)) < .1,
        "tab bar must sit directly below the 40px toolbar")

    local tabW = (panel:GetWidth() - 24) / 9
    local previousRight
    for i, button in ipairs(buttons) do
        assert(rawget(button, "_parent") == tabBar, "all tabs must share the horizontal tab bar")
        local l, t, r, b = mock.rect(button)
        local expectedLeft = pl + 12 + (i - 1) * tabW
        assert(math.abs(l - expectedLeft) < .1 and math.abs((r - l) - tabW) < .1,
            ("tab %d must use an equal horizontal slot"):format(i))
        assert(math.abs(t - bt) < .1 and math.abs(b - bb) < .1,
            "tab must remain within the 34px navigation strip")
        if previousRight then
            assert(l >= previousRight - .1, "adjacent tabs must not overlap")
        end
        previousRight = r
        local label = assert(rawget(button, "_lbl"), "tab requires a visible label")
        local ll, _, lr = mock.rect(label)
        assert(rawget(label, "_text") == tabLabels[i], "tab label changed unexpectedly")
        assert(ll >= l + 4 and lr <= r - 4, "tab label must retain horizontal gutters")
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
    local expectedWidth = index == 5 and 972 or 632
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
assert(panel:GetWidth() == 640 and panel:GetHeight() == 413, "saved 413px normal height must be honored above the 400px minimum")
-- Config construction happens while its root is hidden. Show it for real so
-- lifecycle hooks, effective child visibility, and the first selected page
-- are exercised instead of treating local IsShown state as rendered content.
local firstSection = assert(newestSection(1), "initial Combat Assist content missing")
assert(not panel:IsVisible() and firstSection:IsShown() and not firstSection:IsVisible(),
    "hidden config must retain its selected section without rendering it")
NS.Config:Show()
assert(panel:IsVisible() and firstSection:IsVisible() and firstSection:GetAlpha() == 1,
    "opening config must make the selected content immediately visible and opaque")

-- Multiple HookScript registrations must all survive, and pixels refreshes
-- must preserve each manually anchored section-header ruler.
local title = assert(findTextWidget(panel, "Combat Assist"), "page title missing")
assert(rawget(title, "_points")[1][2] == panel,
    "page title must anchor directly to the sized config frame")
assert(rawget(NS.Config.scrollFrame, "_points")[1][2] == panel,
    "scroll region must anchor directly to the sized config frame")
local macroHeader = assert(findHeaderWidget(panel, "TRINKETS"), "trinket header missing")
local macroLine = assert(rawget(macroHeader, "_line"), "trinket header ruler missing")
local headerAnchorCount = #rawget(macroLine, "_points")
local headerAnchorTarget = rawget(macroLine, "_points")[1][2]
NS.Config:ApplyScale()
assert(#rawget(macroLine, "_points") == headerAnchorCount and rawget(macroLine, "_points")[1][2] == headerAnchorTarget,
    "pixel refresh must preserve section-header ruler anchors")

NS.Config:Hide()
assert(not panel:IsVisible() and firstSection:IsShown() and not firstSection:IsVisible(),
    "hiding config must not discard the selected page's local shown state")
NS.Config:Show()
assert(panel:IsVisible() and firstSection:IsVisible() and firstSection:GetAlpha() == 1,
    "reopening config must restore visible opaque page content")
-- A roomy parent preserves a user's deliberate 150% panel preference; a
-- smaller parent applies only a transient fit cap and leaves that preference.
db.configPanelScale = 1.5
NS.Config:ApplyScale()
assert(math.abs(panel:GetScale() - 1.5) < .001, "roomy UI must retain 150% panel scale")
ui.uiParent:SetSize(800, 500)
NS.Config:ApplyScale()
local cappedScale = math.min(1.5, (800 - 48) / 640, (500 - 48) / 413)
assert(math.abs(panel:GetScale() - cappedScale) < .001, "small UI must apply a transient screen-fit cap")
assert(db.configPanelScale == 1.5, "screen-fit cap must not overwrite the saved panel preference")
ui.uiParent:SetSize(1920, 1080)
NS.Config:ApplyScale()
assertJumpMenuBounds(panel)
for i = 1, 9 do
    NS.Config.SelectSection(i)
    if i == 5 then
        assert(panel:GetWidth() == 980 and panel:GetHeight() == 413, "Talent Builds must retain the saved 413px height")
    else
        assert(panel:GetWidth() == 640 and panel:GetHeight() == 413, "non-talent sections must retain the saved 413px height")
    end
    assertTopTabs(panel)
    assertActiveSectionInScrollRegion(i)
    assertJumpMenuBounds(panel)
end

local function walk(frame)
    assert(frame._width >= 0 and frame._height >= 0, "widget has negative size")
    for _, child in ipairs(frame._children) do walk(child) end
end
walk(panel)

-- Searching from the wider Talent page must reflow the navigation as well as
-- the content. The old tab positions would otherwise escape the 640px panel.
NS.Config.SelectSection(5)
local searchPlaceholder = assert(findTextWidget(panel, "Find a setting..."))
local searchBox = rawget(searchPlaceholder, "_parent")
local searchChanged = assert(searchBox:GetScript("OnTextChanged"))
searchBox:SetText("Font"); searchChanged(searchBox)
assert(panel:GetWidth() == 640, "search uses the normal window width")
assertTopTabs(panel)
searchBox:SetText(""); searchChanged(searchBox)
assert(panel:GetWidth() == 980, "clearing search restores the active Talent page")
assertTopTabs(panel)
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
    assert(rebuilt:GetWidth() == 640 and rebuilt:GetHeight() == 413, feedback .. " appearance layout must retain 413px height")
    appearanceHeights[feedback] = assert(newestSection(2)):GetHeight()
end
assert(appearanceHeights.Classic > appearanceHeights.Off, ("Classic disclosure must reserve its particle/font controls (Classic %.0f, Off %.0f)"):format(appearanceHeights.Classic, appearanceHeights.Off))

-- Direct real Talent panel pass exposes its state for measured source-chip bounds.
local talentParent = ui.createFrame("Frame", nil, ui.uiParent)
talentParent:SetSize(972, 560)
talentParent._contentWidth, talentParent._sectionColor, talentParent._subsections = 972, color(), {}
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
    if rawget(frame, "_trinketSlot") then
        assert(frame._width == 295 and frame._height == 66, "equipment slots share the full-width page")
        local l, _, r = mock.rect(frame)
        local pl, _, pr = mock.rect(frame._parent)
        assert(l >= pl and r <= pr, "trinket row must fit its content width")
        trinketRows = trinketRows + 1
    end
end
assert(trinketRows >= 2, "expected both trinket rows")

-- Heights below the compact safety floor are raised only to that floor; the
-- earlier 413px assertion proves higher saved values remain untouched.
db.configPanelBaseHeight, db.configPanelHeight = 399, 399
NS.Config.frame = nil
NS._restoreSection = false
local minHeightPanel = assert(NS.Config:Create())
assert(minHeightPanel:GetWidth() == 640 and minHeightPanel:GetHeight() == 400,
    "compact config must enforce its 400px minimum height")

-- A page must never be left transparent when the user closes/reopens while
-- transition settings are enabled. The shell no longer fades whole content.
db.cfgAnimTransitions = true
NS.Config.frame = nil
NS._restoreSection = false
local transitionPanel = assert(NS.Config:Create())
local transitionSection = assert(newestSection(1), "transition test section missing")
NS.Config:Show()
assert(transitionSection:IsVisible() and transitionSection:GetAlpha() == 1,
    "animated settings must open with opaque content")
NS.Config:Hide()
NS.Config:Show()
assert(transitionSection:IsVisible() and transitionSection:GetAlpha() == 1,
    "hide/reopen during transitions must not strand page content at alpha zero")
db.cfgAnimTransitions = false

print("config mock: actual Framework/Config/TalentBuildsPanel passed all sections, feedback states, and wrapped-source bounds")
if arg and arg[1] and arg[1] ~= "" then
    -- The artifact is a readable inspection view, independent of the
    -- preceding DPI-fit assertions. Populate representative approved trinket
    -- and macro data only for this one-process export.
    db.configPanelScale = 1
    db.trinketMode = "Approved"
    NS.GetTrinketStatus = function(slot)
        return {
            name = slot == 13 and "Astral Talisman" or "Stormbound Compass",
            status = "Approved",
            reason = "Instant use is available for BetterSBA.",
            canApprove = true,
            eligible = true,
        }
    end
    NS.GetMacroActions = function()
        return {
            { text = "/cast [nochanneling] Sequence Break", hint = "Primary spell" },
            { text = "/use [combat] 13", hint = "Approved trinket" },
        }
    end
    -- Rebuild only for the export so local preview rows consume the
    -- representative data above; ordinary assertions retain their own state.
    NS.Config.frame = nil
    NS._restoreSection = false
    local exportFrame = assert(NS.Config:Create())
    exportFrame:Show()
    NS.Config.SelectSection(tonumber(arg[2]) or 1)
    if NS.RefreshTrinketConfig then NS.RefreshTrinketConfig() end
    NS.Config:ApplyScale()
    mock.writeSVG(NS.Config.frame, arg[1])
    print("config mock: wrote estimated-bounds SVG to " .. arg[1])
end
return { NS = NS, ui = ui, panel = panel }
