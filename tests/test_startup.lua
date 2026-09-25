-- Startup regression: the ButtonStyle path must not abort ADDON_LOADED before
-- slash registration, even when Masque gives it native button-state regions.
local function trim(text) return (text:match("^%s*(.-)%s*$")) end
string.trim = string.trim or trim
unpack = unpack or table.unpack

local function run(hasMasque)
    local harness = assert(dofile("tests/test_config.lua"))
    local NS, ui = harness.NS, harness.ui
    NS.db.buttonSize, NS.db.scale = 48, 1
    NS.db.buttonStyle = "Soft"
    NS.ICON_TEXCOORD = {.07, .93, .07, .93}
    NS.ResolveFontPath = function() return "Fonts\\FRIZQT__.TTF" end
    NS.ResolveFontOutline = function() return "" end
    NS.BuildMacroText = function() return "/cast [@target] Test" end
    NS.CreatePriorityDisplay = function() end
    NS.ScanKeybinds = function() end
    NS.ApplyDebugSettings = function() end
    NS.ApplyAnimCloneDebugBinding = function() end
    NS.UpdateNow = function() end
    NS.StartTicker = function() end
    NS.StartGCTicker = function() end
    NS.InitLDB = function() end

    local group = { adds = 0, removes = 0 }
    function group:AddButton() self.adds = self.adds + 1 end
    function group:RemoveButton() self.removes = self.removes + 1 end
    function group:ReSkin() end
    NS.InitMasque = function()
        if hasMasque then
            NS.masque, NS.masqueMainGroup, NS.masquePriorityGroup = {}, group, group
        else
            -- The config test's convenience metatable returns a no-op function
            -- for absent symbols, so use explicit false for optional libraries.
            NS.masque, NS.masqueMainGroup, NS.masquePriorityGroup = false, false, false
        end
    end

    assert(loadfile("Core/Functions/ButtonStyle.lua"))("BetterSBA", NS)
    assert(loadfile("GUI/MainButton.lua"))("BetterSBA", NS)
    assert(loadfile("GUI/ConfigStudio.lua"))("BetterSBA", NS)
    assert(loadfile("GUI/StudioComic.lua"))("BetterSBA", NS)
    assert(loadfile("GUI/StudioSettings.lua"))("BetterSBA", NS)
    SlashCmdList = {}
    local before = #ui.frames
    assert(loadfile("BetterSBA.lua"))("BetterSBA", NS)
    local eventFrame = ui.frames[before + 1]
    local onEvent = assert(eventFrame:GetScript("OnEvent"), "startup event handler was not registered")

    -- The mock rejects nil in the two native setters. Old Soft+Masque code
    -- called both setters with nil here, which stopped this handler before
    -- RegisterSlashCommands ran.
    local strictButton = ui.createFrame("Button", nil, ui.uiParent)
    assert(not pcall(strictButton.SetNormalTexture, strictButton, nil), "strict normal setter is active")
    assert(not pcall(strictButton.SetHighlightTexture, strictButton, nil), "strict highlight setter is active")
    onEvent(eventFrame, "ADDON_LOADED", "BetterSBA")

    assert(NS.mainButton and NS.secureButton, "main and secure buttons must finish creation")
    local pause = assert(NS.mainButton.pauseOverlay, "pause treatment must exist")
    assert(not pause:IsShown(), "pause treatment must stay hidden until a pause reason applies")
    pause:Show()
    assert(pause.background and pause.bars[1].fill:IsShown()
        and not pause.symbolText:IsShown() and not rawget(pause, "reasonBadge"),
        "the translucent icon and bare reason are the default pause treatment")
    NS.db.pauseSymbolStyle = "Text"
    NS.ApplyButtonSettings()
    assert(pause.symbolText:IsShown() and not pause.bars[1].fill:IsShown(),
        "Text style keeps the original configurable pause font available")
    NS.db.pauseSymbolStyle = "Emblem"
    NS.ApplyButtonSettings()
    pause:Hide()
    assert(type(SlashCmdList.BETTERSBA) == "function", "/bs must be registered after startup")
    if hasMasque then
        local regions = assert(NS.mainButton._masqueRegions, "Masque supplies native regions")
        assert(regions.Normal and regions.Highlight and not NS.mainButton:GetNormalTexture()
            and not NS.mainButton:GetHighlightTexture(),
            "Soft Masque mode clears native regions through the documented clear APIs")
    end

    NS.ConfigStudio:Hide()
    NS.Config:Hide()
    NS.db.configExperience = "classic"
    SlashCmdList.BETTERSBA("")
    assert(NS.Config.frame and NS.Config.frame:IsShown(), "/bs must open the actual Config frame")
    NS.Config:Hide()
    NS.db.configExperience = "studio"
    SlashCmdList.BETTERSBA("")
    assert(NS.ConfigStudio.frame and NS.ConfigStudio.frame:IsShown(),
        "/bs must open Studio when it is the saved panel")
end

run(false)
run(true)
print("startup smoke: ADDON_LOADED reaches strict ButtonStyle, slash registration, and actual /bs Config opening")
