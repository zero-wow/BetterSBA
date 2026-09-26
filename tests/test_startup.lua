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
    NS.db.enabled = true
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
    assert(NS.secureButton:GetAttribute("type1") == "macro"
        and NS.secureButton:GetAttribute("type") == nil,
        "only left click and its keybind may cast the SBA macro")
    local button = NS.mainButton
    local wheel = assert(NS.secureButton:GetScript("OnMouseWheel"),
        "the live button needs a Ctrl+wheel resize handler")
    local oldCursor, oldControl = GetCursorPosition, IsControlKeyDown
    local oldSetPoint = button.SetPoint
    button._testScreenX, button._testScreenY = 100, 100
    function button:GetLeft() return self._testScreenX / self:GetScale() end
    function button:GetBottom() return self._testScreenY / self:GetScale() end
    function button:SetPoint(point, relative, relativePoint, x, y)
        oldSetPoint(self, point, relative, relativePoint, x, y)
        if point == "BOTTOMLEFT" and relativePoint == "BOTTOMLEFT" then
            self._testScreenX, self._testScreenY = x * self:GetScale(), y * self:GetScale()
        end
    end
    _G.IsControlKeyDown = function() return true end
    _G.GetCursorPosition = function() return 124, 135 end
    NS.db.modifierScaling = true
    wheel(NS.secureButton, 1)
    assert(NS.db.scale == 1.05 and math.abs(button._testScreenX - 98.8) < .01
        and math.abs(button._testScreenY - 98.25) < .01,
        "growing the button must preserve the hovered point")
    assert(NS.db.position.point == "BOTTOMLEFT"
        and math.abs(NS.db.position.x * NS.db.scale - button._testScreenX) < .01,
        "wheel resize must persist its new on-screen anchor")
    wheel(NS.secureButton, -1)
    assert(NS.db.scale == 1 and math.abs(button._testScreenX - 100) < .01
        and math.abs(button._testScreenY - 100) < .01,
        "shrinking must return the button to its original position")
    for _ = 1, 6 do
        wheel(NS.secureButton, 1)
        assert(math.abs((124 - button._testScreenX)
            / (button:GetWidth() * button:GetScale()) - .5) < .001,
            "successive wheel steps must retain the same hovered button point")
    end
    for _ = 1, 6 do wheel(NS.secureButton, -1) end
    assert(NS.db.scale == 1 and math.abs(button._testScreenX - 100) < .01,
        "reversing several wheel steps must preserve the button's position")
    button._testScreenX, button._testScreenY = 1872, 1032
    _G.GetCursorPosition = function() return 1918, 1078 end
    wheel(NS.secureButton, 1)
    assert(button._testScreenX >= 0 and button._testScreenY >= 0
        and button._testScreenX + button:GetWidth() * button:GetScale() <= 1920.01
        and button._testScreenY + button:GetHeight() * button:GetScale() <= 1080.01
        and 1918 >= button._testScreenX and 1078 >= button._testScreenY,
        "resizing beside a screen edge must keep the button visible and under the cursor")
    local beforeCombatScale = NS.db.scale
    local oldCombat = NS.InCombatLockdown
    NS.InCombatLockdown = function() return true end
    wheel(NS.secureButton, -1)
    assert(NS.db.scale == beforeCombatScale,
        "protected combat state must not defer an unanchored resize")
    NS.InCombatLockdown = oldCombat
    _G.GetCursorPosition, _G.IsControlKeyDown = oldCursor, oldControl
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
    local postClick = assert(NS.secureButton:GetScript("PostClick"))
    postClick(NS.secureButton, "MiddleButton", true)
    assert(not NS.ConfigStudio.frame or not NS.ConfigStudio.frame:IsShown(),
        "middle-button down must not toggle settings")
    postClick(NS.secureButton, "MiddleButton", false)
    assert(NS.ConfigStudio.frame and NS.ConfigStudio.frame:IsShown(),
        "middle clicking the live button must open the saved settings panel")
    postClick(NS.secureButton, "MiddleButton", false)
    assert(not NS.ConfigStudio.frame:IsShown(),
        "middle clicking the live button again must close settings")
    SlashCmdList.BETTERSBA("")
    assert(NS.ConfigStudio.frame and NS.ConfigStudio.frame:IsShown(),
        "/bs must open Studio when it is the saved panel")
end

run(false)
run(true)
print("startup smoke: ADDON_LOADED reaches strict ButtonStyle, slash registration, and actual /bs Config opening")
