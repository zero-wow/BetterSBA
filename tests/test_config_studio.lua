-- Run from the addon root: lua tests/test_config_studio.lua
local mock = assert(loadfile("tests/wow_ui_mock.lua"))()
local ui = mock.install()
local previewFaction = arg and arg[3] == "alliance" and "Alliance" or "Horde"
_G.UnitFactionGroup = function() return previewFaction end
local db = {
    configExperience = "classic", configStudioWidth = 1120, configStudioHeight = 760,
    configPanelScale = 1, castFeedback = "Motion", enabled = true,
    showPriority = true, enableTargeting = true, motionPreset = "Pulse",
    motionReduced = false, prioritySpacing = 3, buttonSize = 48,
    sectionColorCombat = {1, .45, .15, 1},
}
local info = {
    enabled = false, warningEnabled = true, autoRespecEnabled = false,
    targetName = "Blood Death Knight - San'layn",
    specName = "Blood", status = "Waiting for an eligible talent.", nextName = "Rune Tap",
    canSpend = true, canRespec = false,
}
local classicShown = false
local activeProfile = "Default"
local NS = {
    UIParent = ui.uiParent, db = db, unpack = table.unpack,
    defaults = { enabled = true, showPriority = true, enableTargeting = true,
        castFeedback = "Motion", motionPreset = "Pulse", motionReduced = false,
        prioritySpacing = 3, buttonSize = 48,
        sectionColorCombat = {1, .45, .15, 1} },
    CreateFrame = ui.createFrame,
    GetConfigFontPath = function() return "Fonts\\FRIZQT__.TTF" end,
    CreatePanel = function(name, parent, w, h)
        local frame = ui.createFrame("Frame", name, parent)
        frame:SetSize(w, h)
        return frame
    end,
    Config = {
        Show = function() classicShown = true end,
        Hide = function() classicShown = false end,
        Toggle = function() classicShown = not classicShown end,
        SelectSection = function() end,
    },
    GetTalentLevelingInfo = function() return info end,
    GetTalentSBAUndoInfo = function() return { canUndo = false } end,
    GetTalentBuildEntriesForClass = function()
        return { { id = "one", name = "Blood Leveling", specID = 250 } }
    end,
    GetActiveProfileName = function(self)
        assert(self, "profile methods require their NS receiver")
        return activeProfile
    end,
    GetProfileList = function() return {"Default", "Raid"} end,
    HasCharProfile = function() return false end,
    SwitchProfile = function(_, name) activeProfile = name; return true end,
    ResetProfile = function() return true end,
    GetFontList = function() return {"Friz Quadrata TT", "Arial Narrow"} end,
    GetPaletteList = function() return {"Confetti", "Gold"} end,
    FONT_OUTLINE_OPTIONS = {"NONE", "OUTLINE"},
    CAST_ANIMATIONS = {"NONE", "DRIFT", "PULSE", "VORTEX", "ZOOM", "SLAM", "POP!", "BURST", "FADE", "FLIP", "RISE", "SCATTER"},
    THEME_PRESET_ORDER = {"Default", "Arcane"},
    PARTICLE_TIMINGS = {"On Cast", "On Animation End", "Both"},
    PARTICLE_STYLES = {"None", "Confetti", "Sparks"},
    KEYBIND_ANCHORS = {"TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT"},
    PRIORITY_POSITIONS = {"RIGHT", "LEFT", "TOP", "BOTTOM"},
    INTERCEPTION_TYPES = {"Keybind", "Click", "Both"},
    GetTalentBuildClassToken = function() return "DEATHKNIGHT" end,
    GetTalentBuildCurrentSpecID = function() return 250 end,
    SetTalentLevelingTarget = function(id)
        info.buildID = id
        info.targetName = "Blood Death Knight - San'layn (Leveling / Delves / Dungeons)"
        return true
    end,
    SetTalentLevelingEnabled = function(value) info.enabled = value; return true end,
    SetTalentSBAWarningEnabled = function(value) info.warningEnabled = value; return true end,
    SetTalentAutoRespecEnabled = function(value) info.autoRespecEnabled = value; return true end,
    SpendAllOrRespecTalentPoints = function() return true, "Spending talents." end,
    RequestTalentSBARespec = function() return true end,
    RequestTalentSBAUndo = function() return false end,
}
local constants = assert(io.open("Core/Constants.lua", "r")):read("*a")
local defaultsBody = assert(constants:match("NS%.defaults%s*=%s*%{(.-)\n%}\n\n%-%- Theme"))
NS.defaults = assert(load("return {" .. defaultsBody .. "}"))()
for key, value in pairs(NS.defaults) do
    if db[key] == nil then db[key] = value end
end
assert(loadfile("GUI/ConfigStudio.lua"))("BetterSBA", NS)
assert(loadfile("GUI/StudioComicLettering.lua"))("BetterSBA", NS)
assert(loadfile("GUI/StudioComic.lua"))("BetterSBA", NS)
assert(loadfile("GUI/StudioSettings.lua"))("BetterSBA", NS)
NS.SwitchSettingsPanel("studio")
assert(db.configExperience == "studio" and NS.ConfigStudio.frame:IsShown())
local studio = NS.ConfigStudio
assert(studio.Comic.faction == previewFaction
    and studio.Comic.paths.button:find(previewFaction .. "ButtonRounded", 1, true),
    "characters must receive faction-matched rounded comic art")
assert(not studio.Comic.paths.header,
    "the top flourish must not be used by the comic header")
assert(studio.frame._comicOuterBorder,
    "the illustrated shell needs a continuous outer frame edge")
local overview = studio.pages.Overview
assert(overview._comicHero and overview._groupHeaders[1]:GetText() == "Essentials",
    "Overview must display the faction character and real section headings")
assert(overview._overviewCard and overview._overviewRoute:GetText(),
    "Overview must offer a visible route summary and quick actions")
overview._overviewTalentButton:GetScript("OnClick")(overview._overviewTalentButton)
assert(studio.page == "Talents", "Overview talent shortcut must open the Talent page")
studio:SelectPage("Overview")
overview._overviewMotionButton:GetScript("OnClick")(overview._overviewMotionButton)
assert(studio.page == "Motion", "Overview motion shortcut must open Motion")
studio:SelectPage("Overview")
assert(overview._groupHeaders[1]._comicLettering._texture:find("HeadingEssentials", 1, true)
    and overview._groupHeaders[1]:GetHeight() >= 19
    and not overview._groupHeaders[1]:IsShown()
    and overview._groupHeaders[1]._comicLettering:IsShown(),
    "small section headings must use one visible illustrated layer")
local comicFont = assert(io.open("Fonts/Comic/VTC-Letterer-Pro.ttf", "rb"),
    "the comic button font must ship with the addon")
comicFont:close()
local comicLicense = assert(io.open("Fonts/Comic/VTCinfo.txt", "r"),
    "the bundled comic font must include its license")
comicLicense:close()
local kalamFont = assert(io.open("Fonts/Comic/Kalam-Bold.ttf", "rb"),
    "the optional comic letterer must ship with the addon")
kalamFont:close()
local lilitaFont = assert(io.open("Fonts/Comic/LilitaOne-Regular.ttf", "rb"),
    "the default comic action font must ship with the addon")
lilitaFont:close()
local lilitaLicense = assert(io.open("Fonts/Comic/LilitaOne-OFL.txt", "r"),
    "the default comic action font must include its license")
lilitaLicense:close()
assert(overview._overviewTalentButton._label._comicLettering._texture:find("ButtonOpenTalents", 1, true)
    and overview._overviewTalentButton._label:GetAlpha() == 0
    and not overview._overviewTalentButton._label:IsShown()
    and overview._overviewTalentButton:GetWidth() < 136,
    "fixed action labels need visible image lettering and tighter button lengths")
local letteringFile = assert(io.open("IMG/Comic/Lettering/ButtonOpenTalents.tga", "rb"))
letteringFile:close()
local unknownAction = overview._overviewTalentButton
studio.UI.SetActionText(unknownAction, "Custom Route Name")
assert(unknownAction._label:GetAlpha() == 1
    and unknownAction._label:IsShown()
    and not unknownAction._label._comicLettering:IsShown(),
    "variable action values need a live-text fallback")
studio.UI.SetActionText(unknownAction, "Open Talents")
assert(unknownAction._label:GetAlpha() == 0
    and not unknownAction._label:IsShown()
    and unknownAction._label._comicLettering:IsShown(),
    "fixed action art must return when its label returns")
local fontsPage = studio.pages["Colors & Fonts"]
assert(fontsPage._controls.fontFace and not fontsPage._controls.configStudioButtonFont,
    "retired live-font choices should not appear beside illustrated labels")
assert(overview._controls.enabled._control._comicMini,
    "On/Off switches must use compact styling rather than action-button art")
local enabledSwitch = overview._controls.enabled._control
assert(enabledSwitch._label:GetText() == "On"
    and enabledSwitch._label._comicLettering._texture:find("ButtonOn", 1, true)
    and not enabledSwitch._label:IsShown()
    and enabledSwitch._label._comicLettering:IsShown()
    and enabledSwitch._label:GetHeight() >= 18,
    "compact On/Off switches must have visible illustrated labels at WoW UI scale")
local onLetteringWidth = enabledSwitch._label._comicLettering:GetWidth()
local onLetteringHeight = enabledSwitch._label._comicLettering:GetHeight()
local wasEnabled = db.enabled
enabledSwitch:GetScript("OnClick")(enabledSwitch)
assert(db.enabled == not wasEnabled and enabledSwitch._comicOn == not wasEnabled,
    "compact On/Off controls must update their setting and visual state")
assert(enabledSwitch._label._comicLettering._texture:find("ButtonOff", 1, true),
    "illustrated switch lettering must follow its state")
assert(not enabledSwitch._label:IsShown() and enabledSwitch._label._comicLettering:IsShown(),
    "changing a switch must never reveal a second live-text layer")
assert(math.abs(enabledSwitch._label._comicLettering:GetHeight() - onLetteringHeight) < .1
    and enabledSwitch._label._comicLettering:GetWidth() > onLetteringWidth
    and enabledSwitch._label._comicLettering:GetWidth() < onLetteringWidth * 1.3,
    "On and Off lettering must share a height without distorting Off")
enabledSwitch:GetScript("OnClick")(enabledSwitch)
assert(not studio.navButtons.Overview._stripe,
    "navigation artwork must not have a second accent stripe on the left")
assert(studio.navButtons.Overview:GetWidth() == 190
    and studio.navButtons.Overview._comicNavPlate[1]._texture == studio.Comic.paths.button,
    "active navigation needs a compact rounded plate instead of the pointed caption")
for _, page in ipairs({"Overview", "Combat", "Button & Queue", "Motion", "Talents",
        "Visibility", "Colors & Fonts", "Advanced", "Profiles"}) do
    local row = studio.navButtons[page]
    assert(row._name:GetText() == page and row._name:GetAlpha() == 1
        and not row._name._comicLettering
        and row._number:GetAlpha() == 1,
        "navigation must show a single live label without overlapping heading art")
end
studio:SelectPage("Talents")
local talents = studio.pages.Talents
assert(talents._comicHero and studio.frame._children,
    "the talent page must keep the approved faction illustration")
assert(talents._spend._comic and talents._spend._comic.glint,
    "Spend Available Points needs a restrained hover animation")
assert(talents._spend._comicPlate,
    "Spend Available Points must use the same faction button plate as other actions")
for _, caption in ipairs({talents._routeCaption, talents._nextCaption,
    talents._safetyCaption}) do
    assert(caption._label:GetStringWidth() <= caption._label:GetWidth(),
        "talent section captions must show their full Title Case text")
end
assert(talents._change._comic and not talents._change._comic.ring,
    "compact action buttons must not grow oversized swirl rings")
assert(talents._change._label:GetText() == "Choose a Build"
    and talents._change._label:GetStringWidth() + 4 <= talents._change._label:GetWidth()
    and talents._spend._label:GetStringWidth() <= talents._spend._label:GetWidth(),
    "compact buttons must fit their longest visible labels")
talents._change:GetScript("OnMouseDown")(talents._change)
assert(talents._change._comic.pressShade:GetAlpha() == 1,
    "small action buttons need a pressed state too")
talents._change:GetScript("OnLeave")(talents._change)
assert(talents._change._comic.pressShade:GetAlpha() == 0,
    "a button must release when the pointer leaves it")
assert(talents._route._backdropColor[4] < 1 and talents._left._backdropColor[4] < 1,
    "section fills must reveal the illustrated page behind them")
db.cfgAnimTransitions = false
talents._spend:GetScript("OnEnter")(talents._spend)
talents._spend:GetScript("OnUpdate")(talents._spend,.12)
assert(talents._spend._comic.ring:GetAlpha() > 0
    and talents._spend._comic.glint:GetAlpha() > 0,
    "button hover must animate the hero ring and glint")
talents._spend:GetScript("OnMouseDown")(talents._spend)
assert(talents._spend._comic.pressShade:GetAlpha() == 1
    and talents._spend._comicPlate[1]._vertexColor[1] < 1,
    "button press must visibly recess its plate")
talents._spend:GetScript("OnMouseUp")(talents._spend)
assert(talents._spend._comic.pressShade:GetAlpha() == 0
    and talents._spend._comicPlate[1]._vertexColor[1] == 1,
    "pressed artwork must return to normal on release")
talents._spend:GetScript("OnLeave")(talents._spend)
for _=1,24 do
    local tick=talents._spend:GetScript("OnUpdate")
    if not tick then break end
    tick(talents._spend,.05)
end
assert(talents._spend._comic.ring:GetAlpha() == 0,
    "button hover artwork must reset after leaving")
db.cfgAnimTransitions = true
talents._change:GetScript("OnClick")(talents._change)
assert(talents._picker:IsShown() and talents._pickerRows[1]:IsShown(),
    "changing the build must expose current-spec targets")
assert(talents._pickerCard:GetHeight() == 185,
    "the build picker must not reserve four empty rows for a single build")
talents._pickerRows[1]:GetScript("OnClick")(talents._pickerRows[1])
assert(info.buildID == "one" and not talents._picker:IsShown(),
    "choosing a build must save its leveling target")
assert(talents._routeName:GetText():gsub("\n", " ") == info.targetName
    and talents._change._label:GetText() == "Change Build",
    "the chosen build must replace the empty route label")
assert(talents._status:GetText() == info.status,
    "a successful build choice must clear the picker error")
talents._auto:GetScript("OnClick")(talents._auto)
assert(info.enabled, "Auto-Spend must enable after choosing a target")
assert(studio.notice:GetText() == "Auto-Spend is On for this route."
    and talents._auto._clicks[1] == "LeftButtonUp"
    and talents._auto._stateText:GetText() == "On",
    "the Auto-Spend row must be clickable and confirm its new state")
talents._autoRebuild:GetScript("OnClick")(talents._autoRebuild)
assert(info.autoRespecEnabled, "Auto-Rebuild switch must save its state")
NS.PreviewMotionFeedback = function() return true end
studio:SelectPage("Motion")
local motion = studio.pages.Motion
db.castFeedback = "Off"
motion._controls.motionPreset._control:GetScript("OnClick")(motion._controls.motionPreset._control)
assert(studio._choicePopup.overlay:IsShown(), "motion preset must open its choice list")
studio._choicePopup.rows[6]:GetScript("OnClick")(studio._choicePopup.rows[6])
assert(db.motionPreset == "Orbit" and db.castFeedback == "Motion",
    "choosing Orbit must enable motion feedback")
assert(motion._controls.castAnimation._control._label:GetText() == "Drift",
    "Studio must show animation choices in Title Case while preserving saved values")
motion._previewMotion:GetScript("OnClick")(motion._previewMotion)
assert(studio.notice:GetText() == "Motion preview played.", "motion preview must run")
db.motionReduced = true
motion.Refresh()
motion._previewMotion:GetScript("OnClick")(motion._previewMotion)
assert(studio.notice:GetText():find("stationary flash", 1, true),
    "Reduced Motion must explain why Orbit does not circle")
db.motionReduced = false
studio:SelectPage("Talents")
studio:SelectPage("Profiles")
local profiles = studio.pages.Profiles
profiles._profileActions[1]:GetScript("OnClick")(profiles._profileActions[1])
assert(studio._choicePopup.overlay:IsShown(), "profiles must be selectable in Studio")
studio._choicePopup.rows[2]:GetScript("OnClick")(studio._choicePopup.rows[2])
assert(activeProfile == "Raid" and studio.profileLabel:GetText() == "Profile: Raid",
    "switching profiles must refresh the visible profile name")
profiles._profileActions[5]:GetScript("OnClick")(profiles._profileActions[5])
assert(studio._confirmPopup.overlay:IsShown(), "profile reset must require a confirming click")
studio:SelectPage("Talents")
assert(not studio._confirmPopup.overlay:IsShown(), "leaving a page must close its confirmation")

local function rect(frame)
    local left, top, right, bottom = mock.rect(frame)
    return { left = left, top = top, right = right, bottom = bottom }
end
local function inside(child, parent, name)
    local a, b = rect(child), rect(parent)
    assert(a.left >= b.left - .1 and a.right <= b.right + .1
        and a.top <= b.top + .1 and a.bottom >= b.bottom - .1,
        name .. " escapes its parent")
end
for page, view in pairs(studio.pages) do
    for index, heading in ipairs(view._groupHeaders or {}) do
        local art, bar, divider = heading._comicLettering,
            view._groupBars[index], view._groupDividers[index]
        assert(art and bar and divider and not heading:IsShown() and art:IsShown(),
            page .. " group heading must show only its illustrated lettering")
        inside(art, bar, page .. " group lettering")
        assert(rect(art).left - rect(bar).left >= 25,
            page .. " group lettering must clear the slanted ribbon edge")
        assert(rect(art).bottom - rect(divider).top >= 4,
            page .. " group lettering needs a visible gutter above its divider")
    end
end
for _, size in ipairs({ {900, 600}, {1120, 620}, {1300, 900} }) do
    local frame = studio.frame
    frame:SetSize(size[1], size[2])
    frame:GetScript("OnSizeChanged")(frame, size[1], size[2])
    inside(studio.fitButton, studio.footer, "Fit Window button")
    assert(rect(studio.resizeGrip).left - rect(studio.fitButton).right >= 8,
        "Fit Window needs a gutter before the resize grip")
    local talents = studio.pages.Talents
    inside(talents._route, studio.content, "route")
    inside(talents._left, studio.content, "left column")
    inside(talents._right, studio.content, "right column")
    inside(talents._browse, studio.content, "build library")
    inside(talents._spend, talents._route, "spend button")
    inside(talents._pickerCard, studio.content, "build picker dialog")
    studio:OpenStudioChoices("Cast Animation", {"Drift", "Pulse"}, "Pulse", function() end)
    inside(studio._choicePopup.card, studio.content, "choice dialog")
    studio._choicePopup.overlay:Hide()
    studio:ConfirmStudioAction("Reset this profile to default settings?", function() end)
    inside(studio._confirmPopup.card, studio.content, "confirmation dialog")
    studio._confirmPopup.overlay:Hide()
    assert(talents._routeName:GetStringWidth() <= talents._routeName:GetWidth(),
        "the selected build name must fit the route column at every size")
    local a, b = rect(talents._left), rect(talents._right)
    assert(b.left - a.right >= 11, "columns lack a gutter")
    for page, view in pairs(studio.pages) do
        if view._studioScroll then inside(view._studioScroll, studio.content, page .. " controls") end
        if view._quickBox then inside(view._quickBox, studio.content, page .. " quick controls") end
        if view._comicHero then inside(view._comicHero, view, page .. " character art") end
    end
    inside(overview._overviewCard, overview._studioChild, "Overview adventure card")
    if overview._studioChild:GetWidth() >= 790 then
        inside(overview._overviewCard, overview._studioScroll, "wide Overview adventure card")
        local form, card = rect(overview._studioForm), rect(overview._overviewCard)
        assert(card.left - form.right >= 15,
            "wide Overview summary must sit beside the settings with a gutter")
        assert(card.top <= rect(overview._comicHero).bottom - 8,
            "Overview summary must clear the faction character art")
    else
        assert(overview._studioChild:GetHeight() > overview._studioScroll:GetHeight(),
            "compact Overview must keep the adventure card scrollable")
        inside(overview._overviewCard, overview._studioScroll,
            "compact Overview adventure card must be visible before scrolling")
        assert(rect(overview._studioForm).top <= rect(overview._overviewCard).bottom - 12,
            "compact Overview settings need a gutter below the adventure card")
    end
    assert(studio.pages.Combat._studioForm:GetWidth() <= 680,
        "setting controls must not stretch across the full expanded window")
    local advanced = studio.pages.Advanced
    advanced.Refresh()
    local overflow = advanced._studioChild:GetHeight() - advanced._studioScroll:GetHeight()
    assert(not advanced._scrollUp:IsShown()
        and advanced._scrollDown:IsShown() == (overflow > 1),
        "scroll arrows should appear only when content can scroll")
end
local talents = studio.pages.Talents
talents._change:GetScript("OnClick")(talents._change)
assert(talents._picker:IsShown(), "build picker must open as a dialog")
studio:SelectPage("Overview")
assert(not talents._picker:IsShown(), "leaving Talents must close the build dialog")
assert(studio.frame:GetWidth() == 1120 and studio.frame:GetHeight() == 600,
    "content fit must remove the oversized empty area on Overview")
studio:SelectPage("Combat")
assert(studio.frame:GetHeight() > 600 and studio.frame:GetHeight() < 900,
    "content fit must leave enough height for Combat settings")
studio.resizeGrip:GetScript("OnMouseDown")(studio.resizeGrip)
studio.frame:SetSize(1300, 900)
studio.resizeGrip:GetScript("OnMouseUp")(studio.resizeGrip)
studio:SelectPage("Overview")
assert(db.configStudioAutoFit == false and studio.frame:GetWidth() == 1300
    and studio.frame:GetHeight() == 900,
    "manual resizing must keep the user's chosen window size")
studio.fitButton:GetScript("OnClick")(studio.fitButton)
assert(db.configStudioAutoFit == true and studio.frame:GetWidth() == 1120
    and studio.frame:GetHeight() == 600,
    "Fit must bring an oversized page back to its useful dimensions")
if arg and arg[1] then
    local fitted = arg[2] and arg[2]:find("%-fit$")
    db.configStudioAutoFit = fitted and true or false
    local large = arg[2] and arg[2]:find("%-large$")
    local medium = arg[2] and (arg[2] == "default" or arg[2]:find("%-default$"))
    local previewWidth, previewHeight = large and 1300 or (medium and 1120 or 900),
        large and 900 or (medium and 620 or 600)
    if not fitted then
        studio.frame:SetSize(previewWidth, previewHeight)
        studio.frame:GetScript("OnSizeChanged")(studio.frame, previewWidth, previewHeight)
    end
    local previewKind = arg[2] and arg[2]:gsub("%-large$", "")
        :gsub("%-default$", ""):gsub("%-fit$", "") or ""
    local previewPage = ({ overview = "Overview", motion = "Motion", combat = "Combat",
        button = "Button & Queue", visibility = "Visibility", colors = "Colors & Fonts",
        advanced = "Advanced", profiles = "Profiles", library = "Build Library",
        ["talent-options"] = "Talent Options" })[previewKind] or "Talents"
    studio:SelectPage(previewPage)
    local navPage = (previewPage == "Build Library" or previewPage == "Talent Options")
        and "Talents" or previewPage
    local nav = studio.navButtons[navPage]
    if nav and nav:GetScript("OnUpdate") then nav:GetScript("OnUpdate")(nav, .5) end
    if arg[2] == "picker" then talents._change:GetScript("OnClick")(talents._change) end
    if arg[2] == "hover" then
        talents._spend:GetScript("OnEnter")(talents._spend)
        local elapsed = 0
        local duration = tonumber(arg[4]) or .3
        while elapsed < duration do
            talents._spend:GetScript("OnUpdate")(talents._spend,.05)
            elapsed = elapsed + .05
        end
    elseif arg[2] == "pressed" then
        talents._spend:GetScript("OnMouseDown")(talents._spend)
    end
    if arg[2] == "choice" then
        studio:OpenStudioChoices("Cast Animation", {"Drift", "Pulse", "Vortex"}, "Pulse", function() end)
    elseif arg[2] == "confirm" then
        studio:ConfirmStudioAction("Reset this profile to default settings?", function() end)
    end
    mock.writeSVG(studio.frame, arg[1])
end
NS.SwitchSettingsPanel("classic")
assert(db.configExperience == "classic" and classicShown and not studio.frame:IsShown())
print("Config Studio: load, switching, and minimum/expanded bounds OK")
