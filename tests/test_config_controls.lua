-- Run from the addon root: lua tests/test_config_controls.lua
-- Focused regression coverage for Framework.lua's generic dropdown popup.
local mock = assert(loadfile("tests/wow_ui_mock.lua"))()
local ui = mock.install()

local T = {
    BG_DARK={.02,.03,.04,1}, BG_HOVER={.1,.12,.14,1},
    BORDER={.2,.25,.3,1}, ACCENT={.2,.7,1,1},
    TEXT={.9,.9,.9,1}, TEXT_DIM={.6,.6,.6,1},
}
local selected
local NS = {
    THEME=T, UIParent=ui.uiParent, CreateFrame=ui.createFrame,
    db={choice="First", optionChoice="Off"}, ipairs=ipairs, pairs=pairs, type=type, tostring=tostring, unpack=table.unpack,
    NERD_FONT="Fonts\\FRIZQT__.TTF", GLYPH_CHEVRON_DOWN="v", GLYPH_CHEVRON_UP="^",
    GetConfigFontPath=function() return "Fonts\\FRIZQT__.TTF" end,
    GetConfigFontOutline=function() return "" end,
    C_Timer_After=function() end,
}

assert(loadfile("GUI/Framework.lua"))("BetterSBA", NS)

local parent = ui.createFrame("Frame", nil, ui.uiParent)
parent:SetSize(600, 200)
parent._contentWidth = 572
parent._sectionColor = T.ACCENT
parent:SetScale(1.5)

local row = NS.CreateDropdown(parent, "Choice", "choice", {"First", "Second"}, -10,
    function(value) selected = value end)
local dropdown = assert(row.dropdown, "dropdown row should expose its popup for refresh consumers")
assert(dropdown:GetParent() == ui.uiParent, "popup must stay outside scroll content")
assert(rawget(dropdown, "_clamped") == true, "popup must use native screen clamping")

local click = assert(row.btn:GetScript("OnClick"), "dropdown trigger click handler missing")
click(row.btn)
assert(dropdown:IsShown(), "trigger should show the popup")
assert(dropdown:GetWidth() == row.btn:GetWidth() and dropdown:GetWidth() == 272,
    ("popup should start from its 272px field width, not the 544px full row (got %s)"):format(dropdown:GetWidth()))
assert(math.abs(dropdown:GetScale() - 1.5) < 0.001,
    "UIParent popup must mirror the scaled config trigger")

local entry = assert(rawget(dropdown, "_children")[2], "second option entry missing")
local choose = assert(entry:GetScript("OnClick"), "option callback missing")
choose(entry)
assert(NS.db.choice == "Second", "option click must update the saved value")
assert(selected == "Second", "option click must preserve the caller callback")
assert(not dropdown:IsShown(), "option click must close the popup")

-- A narrow UI must cap only an otherwise oversize popup's applied scale; it
-- does not mutate the configuration frame's requested scale.
ui.uiParent:SetSize(400, 300)
click(row.btn)
local maxScale = (400 - 32) / row.btn:GetWidth()
assert(dropdown:GetScale() <= maxScale + 0.001,
    "oversized popup should fit inside the UIParent horizontal gutter")
assert(math.abs(parent:GetScale() - 1.5) < 0.001,
    "screen fitting must not change the config frame's preferred scale")

-- CreateOptionsDropdown uses the nested popup implementation but opts into the
-- same inline field layout and UIParent popup behavior as the simple dropdown.
ui.uiParent:SetSize(1920, 1080)
local optionSelected
local optionsRow = NS.CreateOptionsDropdown(parent, "Trinket Use", "optionChoice", {"Off", "Approved"}, -50,
    function(value) optionSelected = value end)
local optionsPopup = assert(optionsRow.dropdown, "options row should expose its popup")
assert(optionsRow:GetHeight() == 30 and optionsRow.btn:GetWidth() == 272,
    "wide OptionsDropdown should use the inline half-width field layout")
assert(rawget(optionsPopup, "_clamped") == true, "options popup must use native screen clamping")
local optionsClick = assert(optionsRow.btn:GetScript("OnClick"), "options trigger click handler missing")
optionsClick(optionsRow.btn)
assert(optionsPopup:IsShown() and optionsPopup:GetWidth() == optionsRow.btn:GetWidth(),
    "options popup must start at the field width rather than its full row width")
assert(math.abs(optionsPopup:GetScale() - 1.5) < 0.001,
    "options popup must mirror the scaled config trigger")
local optionScroll = assert(rawget(optionsPopup, "_children")[1], "options popup scroll frame missing")
local optionChild = assert(rawget(optionScroll, "_scrollChild"), "options popup scroll child missing")
local approvedEntry = assert(rawget(optionChild, "_children")[2], "Approved option entry missing")
assert(approvedEntry:GetScript("OnClick"), "options selection handler missing")(approvedEntry)
assert(NS.db.optionChoice == "Approved" and optionSelected == "Approved",
    "options selection must preserve saved-value and callback behavior")
assert(not optionsPopup:IsShown(), "options selection must close the popup")

ui.uiParent:SetSize(400, 300)
optionsClick(optionsRow.btn)
local optionMaxScale = (400 - 32) / optionsRow.btn:GetWidth()
assert(optionsPopup:GetScale() <= optionMaxScale + 0.001,
    "oversized options popup should fit inside the UIParent horizontal gutter")
assert(math.abs(parent:GetScale() - 1.5) < 0.001,
    "options popup fitting must not change the config frame's preferred scale")
optionsClick(optionsRow.btn)
ui.uiParent:SetSize(1920, 1080)

local narrowOptions = NS.CreateOptionsDropdown(parent, "Narrow", "optionChoice", {"Off", "Approved"}, -90, nil, 240)
assert(narrowOptions:GetHeight() == 38 and narrowOptions.btn:GetWidth() == 240,
    "narrow paired OptionsDropdown controls must retain their stacked layout")

print("config control regressions passed")
