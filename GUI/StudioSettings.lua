local ADDON_NAME, NS = ...
local Studio = NS.ConfigStudio
local UI = Studio.UI
local C = UI.colors
local unpack = NS.unpack or unpack or table.unpack
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function Words(keys)
    local result = {}
    for key in keys:gmatch("%S+") do result[#result + 1] = key end
    return result
end

local GROUPS = {
    Overview = {
        { "Essentials", Words("enabled locked showPriority showKeybind showCooldown") },
        { "Quick Behavior", Words("enableDismount enableTargeting enablePetAttack onlyInCombat") },
    },
    Combat = {
        { "Macro Actions", Words("enableDismount enableTargeting enablePetAttack enableChannelProtection") },
        { "Class Abilities", Words("enableDemonSpikes enableConvokeTheSpirits enableShieldBlock enableIgnorePain enableIronfur enableShieldOfRighteous enableRuneTap enablePurifyingBrew") },
        { "Trinkets & Input", Words("trinketMode interceptionType") },
        { "Equipped Trinkets", Words("trinketSlot13 trinketSlot14") },
    },
    ["Button & Queue"] = {
        { "Button", Words("enabled locked buttonStyle buttonSize scale showKeybind showCooldown manualCooldownReminders rangeColoring outOfRangeSound spellUsability") },
        { "Button Keybind", Words("keybindAnchor keybindOffsetX keybindOffsetY") },
        { "Priority Queue", Words("showPriority priorityIconSize priorityScale prioritySpacing priorityPosition priorityDetached priorityLocked showActiveGlow showPriorityKeybinds") },
        { "Priority Placement", Words("priorityBindFrame priorityMyPoint priorityTheirPoint priorityOffsetX priorityOffsetY priorityKeybindAnchor priorityKeybindOffsetX priorityKeybindOffsetY priorityLabelOffsetX priorityLabelOffsetY") },
        { "Animated Clone", Words("animCloneKeybindOffsetX animCloneKeybindOffsetY animCloneMasque") },
    },
    Motion = {
        { "Cast Feedback", Words("castFeedback motionPreset motionDuration motionIntensity motionReduced") },
        { "Classic Animation", Words("castAnimation animateIncoming animHideButton gcdDuration cfgAnimTransitions animCloneReapplyKey") },
        { "Palettes", Words("createPalette editPalette") },
    },
    Talents = {
        { "Build Automation", Words("talentBuildsEnabled talentBuildRetryAfterCombat") },
        { "Build Library", Words("talentBuildShowBuiltIn talentBuildShowUser talentBuildSourceFilter") },
    },
    Visibility = {
        { "Display Visibility", Words("onlyInCombat hideInVehicle alphaCombat alphaOOC priorityAlphaOOC") },
        { "Minimap & Data Broker", Words("showMinimapButton ldbShowText minimapIconSize minimapIconOffsetX minimapIconOffsetY") },
    },
    ["Colors & Fonts"] = {
        { "Theme", Words("themePreset importanceBorders buttonBgColor priorityBgColor priorityBorderColor") },
        { "Spell Importance", Words("importColorAutoAttack importColorFiller importColorShortCD importColorLongCD importColorMajorCD") },
        { "Global & Panel Fonts", Words("fontFace fontOutline configPanelFontOverride configPanelFont configPanelOutline") },
        { "Button Keybind Font", Words("keybindFontOverride keybindFont keybindOutline keybindFontSize") },
        { "Priority Fonts", Words("priorityKeybindFontOverride priorityKeybindFont priorityKeybindOutline priorityKeybindFontSize priorityLabelFontOverride priorityLabelFont priorityLabelOutline priorityLabelFontSize") },
        { "Pause Text", Words("pauseSymbolStyle pauseSymbolFontOverride pauseSymbolFont pauseSymbolOutline pauseSymbolFontSize pauseReasonFontOverride pauseReasonFont pauseReasonOutline pauseReasonFontSize") },
        { "Clone Font", Words("animCloneKeybindFont animCloneKeybindOutline animCloneKeybindFontSize") },
        { "Section Accents", Words("sectionColorCombat sectionColorAppearance sectionColorActive sectionColorTalentBuilds sectionColorPriority sectionColorVisibility sectionColorImportance sectionColorAdvanced sectionColorProfiles") },
    },
    Advanced = {
        { "Performance", Words("updateRate checkVisibleButton modifierScaling configPanelScale") },
        { "Diagnostics", Words("debug debugSpellUpdates debugAnimClone debugOther") },
    },
}

local LABELS = {
    enabled = "Enable BetterSBA", locked = "Lock Button Position", scale = "Button Scale",
    enableDismount = "Auto-Dismount", enableTargeting = "Auto-Target Enemies",
    enablePetAttack = "Pet Attack", enableChannelProtection = "Channel Protection",
    trinketSlot13 = "Trinket 1", trinketSlot14 = "Trinket 2",
    createPalette = "Create Color Palette", editPalette = "Edit Color Palette",
    animCloneReapplyKey = "Reapply Clone Hotkey",
    trinketMode = "Trinket Use", interceptionType = "Interception Method",
    showPriority = "Show Priority Queue", priorityScale = "Priority Scale",
    prioritySpacing = "Icon Padding", priorityDetached = "Detach Queue",
    priorityLocked = "Lock Queue Position", priorityBindFrame = "Bind Queue To Frame",
    priorityMyPoint = "Queue Anchor", priorityTheirPoint = "Target Anchor",
    alphaCombat = "Button Combat Alpha", alphaOOC = "Button Out-Of-Combat Alpha",
    priorityAlphaOOC = "Priority Out-Of-Combat Alpha", ldbShowText = "Show Data Broker Text",
    motionReduced = "Reduced Motion", castFeedback = "Cast Feedback",
    animHideButton = "Hide Button During Animation",
    gcdDuration = "GCD Duration", cfgAnimTransitions = "Panel Transitions",
    themePreset = "Color Theme", importanceBorders = "Importance Borders",
    outOfRangeSound = "Out-Of-Range Sound", updateRate = "Update Interval",
    checkVisibleButton = "Check Visible Button", configPanelScale = "Settings Panel Scale",
    debug = "Debug Mode", debugAnimClone = "Debug Animated Clone",
    talentBuildsEnabled = "Enable Talent Builds",
    talentBuildShowBuiltIn = "Show Built-In Builds",
    talentBuildShowUser = "Show User Builds",
    talentBuildSourceFilter = "Build Source Filter",
    importColorAutoAttack = "Auto Attack", importColorFiller = "Filler",
    importColorShortCD = "Short Cooldown", importColorLongCD = "Long Cooldown",
    importColorMajorCD = "Major Cooldown",
    buttonBgColor = "Button Background", priorityBgColor = "Priority Background",
    priorityBorderColor = "Priority Border",
    pauseSymbolStyle = "Pause Symbol Style",
    animCloneMasque = "Apply Masque To Clone",
}

local RANGES = {
    buttonSize = {24, 80, 1}, scale = {.5, 2, .05}, priorityIconSize = {16, 48, 1},
    priorityScale = {.5, 2, .05}, prioritySpacing = {0, 12, 1},
    alphaCombat = {0, 1, .1}, alphaOOC = {0, 1, .1}, priorityAlphaOOC = {0, 1, .1},
    motionDuration = {.2, .8, .05}, motionIntensity = {.2, 1, .05},
    gcdDuration = {.5, 3, .1}, updateRate = {.02, 1, .01},
    configPanelScale = {.5, 2, .05}, minimapIconSize = {12, 36, 1},
    keybindFontSize = {6, 24, 1}, priorityKeybindFontSize = {6, 16, 1},
    priorityLabelFontSize = {6, 18, 1}, pauseSymbolFontSize = {8, 28, 1},
    pauseReasonFontSize = {6, 14, 1}, animCloneKeybindFontSize = {6, 24, 1},
    keybindOffsetX = {-20, 20, 1}, keybindOffsetY = {-20, 20, 1},
    animCloneKeybindOffsetX = {-20, 20, 1}, animCloneKeybindOffsetY = {-20, 20, 1},
    priorityOffsetX = {-200, 200, 1}, priorityOffsetY = {-200, 200, 1},
    priorityKeybindOffsetX = {-20, 20, 1}, priorityKeybindOffsetY = {-20, 20, 1},
    priorityLabelOffsetX = {-50, 50, 1}, priorityLabelOffsetY = {-50, 50, 1},
}
local OPTIONS = {
    buttonStyle = {"Soft", "Classic"}, trinketMode = {"Off", "Approved"},
    castFeedback = {"Motion", "Classic", "Off"},
    motionPreset = {"Pulse", "Echo", "Sweep", "Sheen", "Snap", "Orbit"},
    pauseSymbolStyle = {"Emblem", "Text"},
}
local EXCLUDE = {
    position = true, priorityFreePosition = true, minimap = true,
    selectedTalentBuildIDs = true, talentBuildLastStatus = true,
    talentBuildSearchText = true, talentBuildUseDefaultSort = true,
    talentBuildSortColumn = true, talentBuildSortAscending = true,
    configPanelBaseHeight = true, configPanelHeight = true,
    configExperience = true, configStudioWidth = true, configStudioHeight = true,
    configPanelLayoutVersion = true, trinketApproved = true,
    animCloneReapplyKey = true, enableGC = true, gcTargetMB = true,
    talentBuildAutoApplyMode = true, talentBuildManagedLoadouts = true,
    talentBuildLoadoutPanelEnabled = true, talentBuildLoadoutPanelFilter = true,
}

local function Title(key)
    if LABELS[key] then return LABELS[key] end
    local value = key:gsub("(%u)(%u%l)", "%1 %2"):gsub("(%l)(%u)", "%1 %2")
    value = value:gsub("^%l", string.upper)
    value = value:gsub("(%s)(%l)", function(space, letter) return space .. letter:upper() end)
    return value:gsub("Cd", "CD"):gsub("Gcd", "GCD"):gsub("Ooc", "OOC")
end

local CHOICE_LABELS = {
    TOPRIGHT = "Top Right", TOPLEFT = "Top Left",
    BOTTOMRIGHT = "Bottom Right", BOTTOMLEFT = "Bottom Left",
    THICKOUTLINE = "Thick Outline", ["MONO OUTLINE"] = "Mono Outline",
    ["MONO THICKOUTLINE"] = "Mono Thick Outline",
}

local function ChoiceLabel(value)
    if type(value) ~= "string" then return tostring(value) end
    if CHOICE_LABELS[value] then return CHOICE_LABELS[value] end
    if value:find("%l") then return value end
    return value:lower():gsub("^%l", string.upper)
end

local function OptionsFor(key)
    if OPTIONS[key] then return OPTIONS[key] end
    if key == "talentBuildSourceFilter" then
        local result, seen = {"All"}, {All = true}
        if NS.GetTalentBuildEntriesForClass and NS.GetTalentBuildClassToken then
            for _, entry in ipairs(NS.GetTalentBuildEntriesForClass(NS.GetTalentBuildClassToken()) or {}) do
                for _, source in pairs({entry.source, entry.catalogSource}) do
                    if source and source ~= "" and not seen[source] then
                        seen[source] = true; result[#result + 1] = source
                    end
                end
            end
        end
        table.sort(result, function(a, b) return a == "All" or (b ~= "All" and a < b) end)
        return result
    end
    if key == "castAnimation" then return NS.CAST_ANIMATIONS end
    if key == "themePreset" then return NS.THEME_PRESET_ORDER end
    if key == "interceptionType" then return NS.INTERCEPTION_TYPES end
    if key == "priorityPosition" then return NS.PRIORITY_POSITIONS end
    if key:find("Anchor") or key == "priorityMyPoint" or key == "priorityTheirPoint" then
        return NS.KEYBIND_ANCHORS
    end
    if key:find("Font$") or key == "fontFace" or key == "configPanelFont" then
        return NS.GetFontList and NS.GetFontList() or nil
    end
    if key:find("Outline$") then return NS.FONT_OUTLINE_OPTIONS end
    if key:find("ParticleTiming$") then return NS.PARTICLE_TIMINGS end
    if key:find("ParticleStyle$") then return NS.PARTICLE_STYLES end
    if key:find("ParticlePalette$") then
        return NS.GetPaletteList and NS:GetPaletteList() or NS.BUILTIN_PALETTE_ORDER
    end
end

local function RangeFor(key, value)
    if RANGES[key] then return unpack(RANGES[key]) end
    if key:find("ParticleDelay$") then return 0, 2, .05 end
    if key:find("FontSize$") then return 6, 32, 1 end
    if key:find("Offset[XY]$") or key:find("IconOffset[XY]$") then
        return key:find("priorityOffset") and -200 or -50,
            key:find("priorityOffset") and 200 or 50, 1
    end
    return 0, math.max(10, value * 3), value < 1 and .05 or 1
end

local function Apply(key, value, studio)
    NS.db[key] = value
    if key == "motionPreset" then NS.db.castFeedback = "Motion" end
    if key == "themePreset" and NS.ApplyThemePreset then NS.ApplyThemePreset(value) end
    if key == "showMinimapButton" and NS.SetMinimapVisible then NS.SetMinimapVisible(value) end
    if key == "manualCooldownReminders" and NS.RefreshManualCooldownReminder then
        NS.RefreshManualCooldownReminder()
    end
    if key == "showPriority" or key:find("^priority") then
        if NS.UpdatePriorityDisplay then NS.UpdatePriorityDisplay() end
    end
    if (key:find("Font") or key == "fontFace" or key == "fontOutline")
        and NS.UpdateAllConfigFonts then NS.UpdateAllConfigFonts() end
    if NS.ApplyProfileVisuals then NS:ApplyProfileVisuals() end
    if key == "configPanelScale" then studio:ApplyScale() end
end

local function Clone(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = Clone(item) end
    return result
end

function Studio:OpenStudioChoices(title, choices, current, onChoose)
    if not choices or #choices == 0 then return end
    local popup = self._choicePopup
    if not popup then
        local overlay = NS.CreateFrame("Frame", nil, self.content)
        overlay:SetAllPoints()
        overlay:SetFrameLevel(self.content:GetFrameLevel() + 30)
        overlay:EnableMouse(true)
        UI.Paint(overlay, { .02, .025, .045, .85 })
        local card = UI.Surface(overlay, 0, 0, 420, 304, C.card)
        card:ClearAllPoints()
        card:SetPoint("CENTER", overlay, "CENTER")
        card:SetFrameLevel(overlay:GetFrameLevel() + 1)
        if self.Comic then self.Comic.DecorateDialog(card,245) end
        local heading = UI.Label(card, "", 20, C.bright, 388, "TOPLEFT", card, "TOPLEFT", 16, -11)
        if self.Comic then self.Comic.StyleHeading(heading,20) end
        local rows = {}
        for i = 1, 7 do
            local index = i
            rows[i] = UI.Action(card, "", 16, -42 - (i - 1) * 32, 388, 28, function()
                local value = rows[index]._value
                if value == nil then return end
                overlay:Hide()
                popup.choose(value)
            end, "quiet")
        end
        local back = UI.Action(card, "Previous", 16, -272, 90, 24, function()
            popup.page = math.max(1, popup.page - 1)
            popup.Refresh()
        end)
        local forward = UI.Action(card, "Next", 116, -272, 70, 24, function()
            popup.page = popup.page + 1
            popup.Refresh()
        end)
        local close = UI.Action(card, "Close", 324, -272, 80, 24, function() overlay:Hide() end, "quiet")
        local pageLabel = UI.Label(card, "", 10, C.dim, 80, "BOTTOM", card, "BOTTOM", 0, 16)
        pageLabel:SetJustifyH("CENTER")
        popup = { overlay = overlay, card = card, heading = heading, rows = rows,
            back = back, forward = forward, close = close, pageLabel = pageLabel, page = 1 }
        function popup.Refresh()
            local pages = math.max(1, math.ceil(#popup.choices / 7))
            popup.page = math.min(popup.page, pages)
            local visibleRows = math.max(1, math.min(7, #popup.choices - (popup.page - 1) * 7))
            local savedSpace = (7 - visibleRows) * 32
            card:SetHeight(304 - savedSpace)
            for _, control in ipairs({ back, forward, close }) do
                control:ClearAllPoints()
                control:SetPoint("TOPLEFT", card, "TOPLEFT",
                    control == back and 16 or (control == forward and 116 or 324), -272 + savedSpace)
            end
            for i, row in ipairs(rows) do
                local value = popup.choices[(popup.page - 1) * 7 + i]
                row._value = value
                row:SetShown(value ~= nil)
                if value then row._label:SetText((value == popup.current and "◆ " or "") .. ChoiceLabel(value)) end
            end
            back:SetShown(popup.page > 1)
            forward:SetShown(popup.page < pages)
            pageLabel:SetText(popup.page .. " / " .. pages)
        end
        self._choicePopup = popup
        overlay:Hide()
    end
    popup.choices, popup.current, popup.choose, popup.page = choices, current, onChoose, 1
    popup.heading:SetText(title)
    popup.Refresh()
    popup.overlay:Show()
end

local function MakeSetting(studio, parent, key, y, refreshers)
    local initial = (NS.defaults or {})[key]
    local custom = key == "trinketSlot13" or key == "trinketSlot14"
        or key == "createPalette" or key == "editPalette"
        or key == "animCloneReapplyKey"
    if (initial == nil and not custom) or (EXCLUDE[key] and not custom) then return false end
    local row = NS.CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
    row:SetHeight(31)
    local label = UI.Label(row, Title(key), 11, C.text, 280, "LEFT", row, "LEFT", 8, 0)
    row._key, row._label = key, label
    local function Save(value)
        Apply(key, value, studio)
        studio.notice:SetText(Title(key) .. " saved.")
        if row.Refresh then row.Refresh() end
    end
    if key == "trinketSlot13" or key == "trinketSlot14" then
        local slot = tonumber(key:sub(-2))
        local control = UI.Action(row, "Unavailable", 0, 0, 105, 21, function()
            if NS.IsTrinketApproved and NS.SetTrinketApproved then
                NS.SetTrinketApproved(slot, not NS.IsTrinketApproved(slot))
                row.Refresh()
            end
        end, "quiet")
        control:ClearAllPoints(); control:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.Refresh = function()
            local info = NS.GetTrinketStatus and NS.GetTrinketStatus(slot)
            label:SetText(info and info.name or Title(key))
            local available = info and info.canApprove
            local approved = available and NS.IsTrinketApproved and NS.IsTrinketApproved(slot)
            control._label:SetText(not available and "Unavailable" or approved and "Approved" or "Approve")
            control:SetEnabled(available == true)
            control:SetAlpha(available and 1 or .5)
        end
        row._control = control
    elseif key == "createPalette" or key == "editPalette" then
        local control = UI.Action(row, key == "createPalette" and "Create" or "Edit", 0, 0, 105, 21, function()
            if not NS.ShowPaletteEditor then return end
            local animation = NS.db.castAnimation or "POP!"
            local prefix = NS.AnimKeyPrefix and NS.AnimKeyPrefix(animation)
                or animation:gsub("[^%a]", ""):lower()
            if prefix == "" or prefix == "none" then prefix = "pop" end
            NS.ShowPaletteEditor(studio.frame, prefix .. "ParticlePalette",
                function() studio:Refresh() end, key == "createPalette")
        end)
        control:ClearAllPoints(); control:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.Refresh = function() end
        row._control = control
    elseif key == "animCloneReapplyKey" then
        local control = UI.Action(row, "Not Set", 0, 0, 150, 21, function()
            if NS.OpenAnimCloneReapplyKeyCapture then
                NS.OpenAnimCloneReapplyKeyCapture(row.Refresh, studio.frame)
            end
        end, "quiet")
        control:ClearAllPoints(); control:SetPoint("RIGHT", row, "RIGHT", -65, 0)
        local clear = UI.Action(row, "Clear", 0, 0, 50, 21, function()
            NS.db.animCloneReapplyKey = ""
            if NS.ApplyAnimCloneDebugBinding then NS.ApplyAnimCloneDebugBinding() end
            row.Refresh()
        end, "quiet")
        clear:ClearAllPoints(); clear:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.Refresh = function()
            control._label:SetText(NS.GetAnimCloneReapplyBindingText
                and NS.GetAnimCloneReapplyBindingText() or (NS.db.animCloneReapplyKey or "Not Set"))
        end
        row._control = control
    elseif type(initial) == "boolean" then
        local control = UI.Action(row, "Off", 0, 0, 50, 21, function()
            Save(not (NS.db[key] == true))
        end)
        control:ClearAllPoints()
        control:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.Refresh = function()
            local on = NS.db[key] == true
            control._label:SetText(on and "On" or "Off")
            control:SetBackdropColor(unpack(on and C.accent or C.rail))
        end
        row._control = control
    elseif type(initial) == "number" then
        local minimum, maximum, step = RangeFor(key, initial)
        local function Adjust(amount)
            local current = tonumber(NS.db[key]) or initial
            local value = math.max(minimum, math.min(maximum, current + amount))
            local decimals = step < 1 and (step < .1 and 2 or 1) or 0
            Save(tonumber(string.format("%." .. decimals .. "f", value)))
        end
        local minus = UI.Action(row, "−", 0, 0, 23, 21, function() Adjust(-step) end)
        minus:ClearAllPoints(); minus:SetPoint("RIGHT", row, "RIGHT", -128, 0)
        local value = NS.CreateFrame("EditBox", nil, row, "BackdropTemplate")
        value:SetSize(72, 21)
        value:SetPoint("RIGHT", row, "RIGHT", -47, 0)
        value:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
        value:SetBackdropColor(unpack(C.rail)); value:SetBackdropBorderColor(unpack(C.border))
        if studio.Comic then studio.Comic.StyleInput(value) end
        value:SetFont(NS.GetConfigFontPath(), 11, "")
        value:SetTextColor(unpack(C.text)); value:SetJustifyH("CENTER")
        value:SetAutoFocus(false)
        value:SetScript("OnEnterPressed", function(self)
            local parsed = tonumber(self:GetText())
            if parsed then
                parsed = math.max(minimum, math.min(maximum, parsed))
                parsed = minimum + math.floor((parsed - minimum) / step + .5) * step
                local decimals = step < 1 and (step < .1 and 2 or 1) or 0
                Save(tonumber(string.format("%." .. decimals .. "f", parsed)))
            end
            self:ClearFocus()
            row.Refresh()
        end)
        value:SetScript("OnEscapePressed", function(self) self:ClearFocus(); row.Refresh() end)
        local plus = UI.Action(row, "+", 0, 0, 23, 21, function() Adjust(step) end)
        plus:ClearAllPoints(); plus:SetPoint("RIGHT", row, "RIGHT", -15, 0)
        row.Refresh = function() value:SetText(tostring(NS.db[key] or initial)) end
        row._control = value
    elseif type(initial) == "string" then
        local choices = OptionsFor(key)
        if choices then
            local control = UI.Action(row, "", 0, 0, 198, 21, function()
                studio:OpenStudioChoices(Title(key), OptionsFor(key), NS.db[key], Save)
            end)
            control:ClearAllPoints(); control:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            row.Refresh = function()
                UI.FitText(control._label, ChoiceLabel(NS.db[key] or initial), control._label:GetWidth())
            end
            row._control = control
        else
            local value = NS.CreateFrame("EditBox", nil, row, "BackdropTemplate")
            value:SetSize(198, 21); value:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            value:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
            value:SetBackdropColor(unpack(C.rail)); value:SetBackdropBorderColor(unpack(C.border))
            if studio.Comic then studio.Comic.StyleInput(value) end
            value:SetFont(NS.GetConfigFontPath(), 11, "")
            value:SetTextColor(unpack(C.text)); value:SetTextInsets(6, 6, 0, 0)
            value:SetAutoFocus(false)
            value:SetScript("OnEnterPressed", function(self)
                Save(self:GetText()); self:ClearFocus()
            end)
            value:SetScript("OnEscapePressed", function(self) self:ClearFocus(); row.Refresh() end)
            row.Refresh = function() value:SetText(NS.db[key] or initial) end
            row._control = value
        end
    elseif type(initial) == "table" and type(initial[1]) == "number" then
        local swatch = UI.Action(row, "", 0, 0, 50, 21, function()
            if not ColorPickerFrame then return end
            local current = NS.db[key] or initial
            local previous = Clone(current)
            local function PaintColor()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local alpha = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or 1
                Save({r, g, b, alpha})
            end
            local info = { r = current[1], g = current[2], b = current[3],
                opacity = current[4] or 1, hasOpacity = true,
                swatchFunc = PaintColor, opacityFunc = PaintColor,
                cancelFunc = function() Save(previous) end }
            if ColorPickerFrame.SetupColorPickerAndShow then
                ColorPickerFrame:SetupColorPickerAndShow(info)
            else
                ColorPickerFrame:SetColorRGB(current[1], current[2], current[3])
                ColorPickerFrame.hasOpacity = true
                ColorPickerFrame.opacity = 1 - (current[4] or 1)
                ColorPickerFrame.func = PaintColor
                ColorPickerFrame.opacityFunc = PaintColor
                ColorPickerFrame.cancelFunc = info.cancelFunc
                ColorPickerFrame:Show()
            end
        end)
        swatch:ClearAllPoints(); swatch:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        local color = swatch:CreateTexture(nil, "ARTWORK")
        color:SetPoint("TOPLEFT", swatch, "TOPLEFT", 3, -3)
        color:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -3, 3)
        row.Refresh = function()
            local value = NS.db[key] or initial
            color:SetColorTexture(value[1], value[2], value[3], value[4] or 1)
        end
        row._control = swatch
    else
        return false
    end
    row.Refresh()
    refreshers[#refreshers + 1] = row.Refresh
    return row
end

local function CategoryFor(key)
    if key:find("Particle") or key:find("^motion") or key:find("^cast")
        or key:find("^anim") or key == "gcdDuration" then return "Motion" end
    if key:find("Font") or key:find("Outline") or key:find("Color")
        or key == "fontFace" or key == "themePreset" then return "Colors & Fonts" end
    if key:find("^talentBuild") then return "Talents" end
    if key:find("^priority") or key:find("^keybind") or key:find("^show")
        or key:find("^button") then return "Button & Queue" end
    if key:find("^minimap") or key:find("^ldb") or key:find("^alpha")
        or key:find("^hide") or key == "onlyInCombat" then return "Visibility" end
    if key:find("^enable") or key:find("^trinket") or key == "interceptionType" then return "Combat" end
    return "Advanced"
end

local function CompileGroups()
    local result, seen = {}, {}
    for page, groups in pairs(GROUPS) do
        result[page] = {}
        for _, group in ipairs(groups) do
            local keys = {}
            for _, key in ipairs(group[2]) do
                local custom = key == "trinketSlot13" or key == "trinketSlot14"
                    or key == "createPalette" or key == "editPalette"
                    or key == "animCloneReapplyKey"
                if custom or (NS.defaults or {})[key] ~= nil and not EXCLUDE[key] then
                    keys[#keys + 1] = key
                    if page ~= "Overview" then seen[key] = true end
                end
            end
            result[page][#result[page] + 1] = { group[1], keys }
        end
    end
    for _, animation in ipairs(NS.CAST_ANIMATIONS or {}) do
        if animation ~= "NONE" then
            local prefix = NS.AnimKeyPrefix and NS.AnimKeyPrefix(animation)
                or animation:gsub("[^%a]", ""):lower()
            local keys = {}
            for _, suffix in ipairs({"Particles", "ParticleTiming", "ParticleStyle",
                "ParticlePalette", "ParticleDelay"}) do
                local key = prefix .. suffix
                if (NS.defaults or {})[key] ~= nil then
                    keys[#keys + 1] = key
                    seen[key] = true
                end
            end
            if #keys > 0 then
                result.Motion[#result.Motion + 1] = {
                    animation:sub(1, 1) .. animation:sub(2):lower() .. " Particles", keys }
            end
        end
    end
    local extra = {}
    for key, value in pairs(NS.defaults or {}) do
        if not seen[key] and not EXCLUDE[key]
            and (type(value) == "boolean" or type(value) == "number" or type(value) == "string"
                or type(value) == "table" and type(value[1]) == "number") then
            local page = CategoryFor(key)
            extra[page] = extra[page] or {}
            extra[page][#extra[page] + 1] = key
        end
    end
    for page, keys in pairs(extra) do
        table.sort(keys)
        result[page] = result[page] or {}
        result[page][#result[page] + 1] = { page == "Motion" and "Particle & Additional Options" or "More Settings", keys }
    end
    return result, seen
end

local function BuildPage(studio, page, groups)
    if studio.pages[page] then studio.pages[page]:Hide() end
    local view = NS.CreateFrame("Frame", nil, studio.content)
    view:SetAllPoints()
    studio.pages[page] = view
    local pageTitle = UI.Label(view, page, 25, C.bright, 420, "TOPLEFT", view, "TOPLEFT", 26, -8)
    if studio.Comic then studio.Comic.StyleHeading(pageTitle, 25) end
    local count = 0
    for _, group in ipairs(groups or {}) do count = count + #group[2] end
    local countLabel = UI.Label(view, count .. " settings", 10, C.muted, 120,
        "TOPRIGHT", view, "TOPRIGHT", -28, -14)
    countLabel:SetJustifyH("RIGHT")
    view._countLabel = countLabel

    local scroll = NS.CreateFrame("ScrollFrame", nil, view)
    scroll:SetPoint("TOPLEFT", view, "TOPLEFT", 26, -49)
    scroll:SetSize(610, 520)
    scroll:EnableMouseWheel(true)
    local child = NS.CreateFrame("Frame", nil, scroll)
    child:SetSize(596, 1)
    scroll:SetScrollChild(child)
    view._studioScroll, view._studioChild = scroll, child
    local y, refreshers, controls = -2, {}, {}
    for _, group in ipairs(groups or {}) do
        if #group[2] > 0 then
            if studio.Comic then studio.Comic.DecorateGroup(child, y) end
            local groupTitle = UI.Label(child, group[1], 13, C.bright, 300, "TOPLEFT", child, "TOPLEFT", 8, y - 2)
            if studio.Comic then studio.Comic.StyleHeading(groupTitle, 13) end
            local line = UI.Paint(child, C.border)
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", child, "TOPLEFT", 8, y - 20)
            line:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, y - 20)
            line:SetHeight(1)
            y = y - 26
            for _, key in ipairs(group[2]) do
                local row = MakeSetting(studio, child, key, y, refreshers)
                if row then controls[key] = row; y = y - 31 end
            end
            y = y - 8
        end
    end
    child:SetHeight(math.max(1, -y + 12))
    view._controls = controls
    view._count = count
    local function ScrollTo(value)
        local limit = math.max(0, child:GetHeight() - scroll:GetHeight())
        scroll:SetVerticalScroll(math.max(0, math.min(limit, value)))
    end
    scroll:SetScript("OnMouseWheel", function(_, delta)
        ScrollTo(scroll:GetVerticalScroll() - delta * 72)
    end)
    local up = UI.Action(view, "↑", 0, 0, 19, 19, function()
        ScrollTo(scroll:GetVerticalScroll() - 200)
    end, "quiet")
    up:ClearAllPoints(); up:SetPoint("TOPRIGHT", view, "TOPRIGHT", -4, -49)
    local down = UI.Action(view, "↓", 0, 0, 19, 19, function()
        ScrollTo(scroll:GetVerticalScroll() + 200)
    end, "quiet")
    down:ClearAllPoints(); down:SetPoint("BOTTOMRIGHT", view, "BOTTOMRIGHT", -4, 10)
    view.Refresh = function()
        for _, fn in ipairs(refreshers) do fn() end
    end
    return view
end

local function BuildProfiles(studio)
    if studio.pages.Profiles then studio.pages.Profiles:Hide() end
    local view = NS.CreateFrame("Frame", nil, studio.content)
    view:SetAllPoints()
    studio.pages.Profiles = view
    local title = UI.Label(view, "Profiles", 25, C.bright, 420, "TOPLEFT", view, "TOPLEFT", 26, -8)
    if studio.Comic then studio.Comic.StyleHeading(title,25) end
    local name = UI.Label(view, "", 15, C.text, 380, "TOPLEFT", view, "TOPLEFT", 26, -46)
    local message = UI.Label(view, "", 11, C.dim, 540, "TOPLEFT", view, "TOPLEFT", 26, -73)
    local function Report(ok, err, success)
        if ok and NS.UpdateAllConfigFonts then NS.UpdateAllConfigFonts() end
        studio.notice:SetText(ok and success or (err or "Profile action failed."))
        studio:Refresh()
    end
    local choose = UI.Action(view, "Switch Profile", 26, -106, 150, 27, function()
        studio:OpenStudioChoices("Switch Profile", NS:GetProfileList(), NS:GetActiveProfileName(),
            function(selected)
                local ok, err = NS:SwitchProfile(selected)
                Report(ok, err, "Switched to " .. selected .. ".")
            end)
    end)
    local create = UI.Action(view, "New Profile", 185, -106, 135, 27, function()
        local n = #NS:GetProfileList() + 1
        local candidate = "Profile " .. n
        while NS.dbRoot.profiles[candidate] do n = n + 1; candidate = "Profile " .. n end
        local ok, err = NS:CreateProfile(candidate)
        Report(ok, err, "Created " .. candidate .. ".")
    end)
    local bind = UI.Action(view, "", 26, -152, 190, 27, function()
        local bound = NS:HasCharProfile()
        NS:SetCharProfile(bound and nil or NS:GetActiveProfileName())
        Report(true, nil, bound and "Character unbound." or "Character bound to this profile.")
    end)
    local copy = UI.Action(view, "Copy From Profile", 26, -204, 190, 27, function()
        local choices = {}
        for _, candidate in ipairs(NS:GetProfileList()) do
            if candidate ~= NS:GetActiveProfileName() then choices[#choices + 1] = candidate end
        end
        studio:OpenStudioChoices("Copy Settings From", choices, nil, function(selected)
            studio:ConfirmStudioAction("Replace this profile's settings with " .. selected .. "?", function()
                local ok, err = NS:CopyFromProfile(selected)
                Report(ok, err, "Copied settings from " .. selected .. ".")
            end)
        end)
    end)
    local reset = UI.Action(view, "Reset To Defaults", 26, -250, 190, 27, function()
        studio:ConfirmStudioAction("Reset this profile to default settings?", function()
            local ok, err = NS:ResetProfile()
            Report(ok, err, "Profile reset to defaults.")
        end)
    end, "quiet")
    local delete = UI.Action(view, "Delete Profile", 226, -250, 150, 27, function()
        studio:ConfirmStudioAction("Delete " .. NS:GetActiveProfileName() .. "?", function()
            local current = NS:GetActiveProfileName()
            local replacement
            for _, candidate in ipairs(NS:GetProfileList()) do
                if candidate ~= current then replacement = candidate; break end
            end
            if not replacement then Report(false, "Cannot delete the last profile."); return end
            local switched, switchError = NS:SwitchProfile(replacement)
            if not switched then Report(false, switchError); return end
            local ok, err = NS:DeleteProfile(current)
            Report(ok, err, "Deleted " .. current .. ".")
        end)
    end, "quiet")
    local font = NS.CreateFrame("EditBox", nil, view, "BackdropTemplate")
    font:SetSize(240, 25); font:SetPoint("TOPLEFT", view, "TOPLEFT", 26, -312)
    font:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    font:SetBackdropColor(unpack(C.rail)); font:SetBackdropBorderColor(unpack(C.border))
    if studio.Comic then studio.Comic.StyleInput(font) end
    font:SetFont(NS.GetConfigFontPath(), 11, ""); font:SetTextColor(unpack(C.text))
    font:SetTextInsets(7, 7, 0, 0); font:SetAutoFocus(false)
    UI.Label(view, "Rename Current Profile", 11, C.dim, 250, "TOPLEFT", view, "TOPLEFT", 26, -293)
    local rename = UI.Action(view, "Rename", 276, -312, 90, 25, function()
        local old, nextName = NS:GetActiveProfileName(), font:GetText()
        local ok, err = NS:RenameProfile(old, nextName)
        Report(ok, err, "Renamed profile to " .. nextName .. ".")
    end)
    view._profileActions = {choose, create, bind, copy, reset, delete, rename}
    view.Refresh = function()
        name:SetText("Active Profile: " .. NS:GetActiveProfileName())
        message:SetText(NS:HasCharProfile() and "This character uses the selected profile."
            or "This character follows the account default profile.")
        bind._label:SetText(NS:HasCharProfile() and "Unbind Character" or "Bind To This Profile")
        font:SetText(NS:GetActiveProfileName())
    end
    return view
end

function Studio:ConfirmStudioAction(prompt, confirm)
    local popup = self._confirmPopup
    if not popup then
        local overlay = NS.CreateFrame("Frame", nil, self.content)
        overlay:SetAllPoints(); overlay:SetFrameLevel(self.content:GetFrameLevel() + 40)
        overlay:EnableMouse(true)
        UI.Paint(overlay, { .02, .025, .045, .85 })
        local card = UI.Surface(overlay, 0, 0, 470, 145, C.card)
        card:ClearAllPoints(); card:SetPoint("CENTER", overlay, "CENTER")
        card:SetFrameLevel(overlay:GetFrameLevel() + 1)
        if self.Comic then self.Comic.DecorateDialog(card,205) end
        local title = UI.Label(card,"Confirm Action",19,C.bright,230,"TOPLEFT",card,"TOPLEFT",16,-12)
        if self.Comic then self.Comic.StyleHeading(title,19) end
        local text = UI.Label(card, "", 13, C.text, 438, "TOPLEFT", card, "TOPLEFT", 16, -47)
        text:SetWordWrap(true); text:SetMaxLines(2)
        UI.Action(card, "Cancel", 220, -100, 105, 28, function() overlay:Hide() end, "quiet")
        UI.Action(card, "Confirm", 339, -100, 115, 28, function()
            overlay:Hide()
            popup.confirm()
        end)
        popup = { overlay = overlay, card = card, text = text }
        self._confirmPopup = popup
        overlay:Hide()
    end
    popup.text:SetText(prompt)
    popup.confirm = confirm
    popup.overlay:Show()
end

function Studio:BuildSettingsPages()
    local groups = CompileGroups()
    self.settingsCoverage = {}
    for _, page in ipairs({ "Overview", "Combat", "Button & Queue", "Motion", "Visibility", "Colors & Fonts", "Advanced" }) do
        local view = BuildPage(self, page, groups[page])
        for key in pairs(view._controls) do self.settingsCoverage[key] = true end
    end
    local motion = self.pages.Motion
    if motion._countLabel then motion._countLabel:Hide() end
    motion._previewMotion = UI.Action(motion, "Preview Motion", 0, 0, 118, 24, function()
        local mode = NS.db.castFeedback
        local played
        if mode == "Classic" and NS.PlayCastAnimation then
            played = NS.PlayCastAnimation(NS.mainButton and NS.mainButton.spellID or NS.SBA_SPELL_ID)
        elseif mode == "Motion" and NS.PreviewMotionFeedback then
            played = NS.PreviewMotionFeedback()
        end
        self.notice:SetText(played and (NS.db.motionReduced and mode == "Motion"
            and "Reduced Motion uses a stationary flash." or "Motion preview played.")
            or "Show the BetterSBA button and enable Cast Feedback to preview.")
    end, "quiet")
    motion._previewMotion:ClearAllPoints()
    motion._previewMotion:SetPoint("TOPRIGHT", motion, "TOPRIGHT", -32, -8)
    BuildProfiles(self)
    local oldTalents = self.pages.Talents
    if oldTalents then
        local settingsButton = UI.Action(oldTalents, "Talent Options", 260, -474, 130, 30,
            function() self:SelectPage("Talent Options") end, "quiet")
        oldTalents._settingsButton = settingsButton
    end
    local talentSettings = BuildPage(self, "Talent Options", groups.Talents)
    if talentSettings._countLabel then talentSettings._countLabel:Hide() end
    for key in pairs(talentSettings._controls) do self.settingsCoverage[key] = true end
    local back = UI.Action(talentSettings, "← Talents", 0, 0, 100, 24,
        function() self:SelectPage("Talents") end, "quiet")
    back:ClearAllPoints(); back:SetPoint("TOPRIGHT", talentSettings, "TOPRIGHT", -32, -7)

    local library = NS.CreateFrame("Frame", nil, self.content)
    library:SetAllPoints(); self.pages["Build Library"] = library
    local libraryTitle = UI.Label(library, "Build Library", 25, C.bright, 350, "TOPLEFT", library, "TOPLEFT", 26, -8)
    if self.Comic then self.Comic.StyleHeading(libraryTitle,25) end
    local libraryBack = UI.Action(library, "← Talents", 0, 0, 100, 24,
        function() self:SelectPage("Talents") end, "quiet")
    libraryBack:ClearAllPoints(); libraryBack:SetPoint("TOPRIGHT", library, "TOPRIGHT", -32, -7)
    local scroll = NS.CreateFrame("ScrollFrame", nil, library)
    scroll:SetPoint("TOPLEFT", library, "TOPLEFT", 26, -49)
    scroll:SetSize(610, 520); scroll:EnableMouseWheel(true)
    local child = NS.CreateFrame("Frame", nil, scroll)
    child:SetSize(600, 1100); child._contentWidth = 600
    child._comicStudio = self.Comic ~= nil
    child._sectionColor = child._comicStudio and C.accent or
        (NS.THEME and NS.THEME.ACCENT or C.accent)
    scroll:SetScrollChild(child)
    library._studioScroll, library._studioChild = scroll, child
    library._fixedStudioChildWidth = 600
    if NS.BuildTalentBuildsConfigSection then
        library._catalog = NS.BuildTalentBuildsConfigSection(child)
        child:SetHeight(math.max(1100, child._contentH or 0))
    end
    local catalogTop = 150
    scroll:SetVerticalScroll(catalogTop)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        local limit = math.max(0, child:GetHeight() - scroll:GetHeight())
        scroll:SetVerticalScroll(math.max(catalogTop, math.min(limit,
            scroll:GetVerticalScroll() - delta * 96)))
    end)
    local down = UI.Action(library, "↓", 0, 0, 19, 19, function()
        scroll:SetVerticalScroll(math.min(child:GetHeight() - scroll:GetHeight(),
            scroll:GetVerticalScroll() + 250))
    end, "quiet")
    down:ClearAllPoints(); down:SetPoint("BOTTOMRIGHT", library, "BOTTOMRIGHT", -4, 10)
    library.Refresh = function()
        if library._catalog and library._catalog.Refresh then library._catalog:Refresh() end
        if scroll:GetVerticalScroll() < catalogTop then scroll:SetVerticalScroll(catalogTop) end
    end
    for key, value in pairs(NS.defaults or {}) do
        if not EXCLUDE[key] and (type(value) == "boolean" or type(value) == "number"
            or type(value) == "string" or type(value) == "table" and type(value[1]) == "number") then
            assert(self.settingsCoverage[key], "Studio setting missing: " .. key)
        end
    end
end
