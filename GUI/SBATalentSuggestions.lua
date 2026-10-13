local ADDON_NAME, NS = ...

-- Optional previews only: the ranking API owns evidence, this dialog owns consent.
local UI = NS.ConfigStudio.UI
local C = UI.colors
local popup
local names = { ready = "Tested Choices", tie = "Too Close To Call", stale = "Needs Retest",
    unavailable = "Not Available", ["single-candidate"] = "Only One Build Tested" }

local function Label(parent, text, x, y, width, size)
    local label = UI.Label(parent, text, size or 12, C.text, width,
        "TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetWordWrap(true)
    label:SetNonSpaceWrap(true)
    label:SetMaxLines(0)
    label:SetJustifyV("TOP")
    return label
end

local function Selectable(result)
    return result and (result.state == "ready" or result.state == "tie")
end

local function Contains(result, selected)
    if not selected or not Selectable(result) then return false end
    for _, choice in ipairs(result.choices or {}) do
        if choice.buildID == selected.buildID and choice.importString == selected.importString then return true end
    end
    return false
end

local function AutoEnabled()
    return NS.GetTalentLevelingInfo and NS.GetTalentLevelingInfo().enabled == true
end

local function ReadResult()
    return NS.GetBestTestedSBABuild and NS.GetBestTestedSBABuild(popup.specID, popup.targets)
        or { state = "unavailable", reason = "No matching tests are available yet.", choices = {} }
end

local function SetEnabled(button, enabled)
    button:SetEnabled(enabled == true)
    button:SetAlpha(enabled and 1 or .45)
end

local Render
local function Review(resetSelection)
    popup.result = ReadResult()
    if resetSelection then popup.selected, popup.message = nil, nil end
    if not Contains(popup.result, popup.selected) then popup.selected = nil end
    if not popup.selected and popup.result.state == "ready" and #(popup.result.choices or {}) == 1 then
        local choice = popup.result.choices[1]
        popup.selected = { buildID = choice.buildID, importString = choice.importString, name = choice.name }
    end
    popup.reviewedAuto = AutoEnabled()
    popup.scroll:SetVerticalScroll(0)
    Render()
end

local function Reject(message, result)
    popup.message = message
    if result then popup.result, popup.selected = result, nil end
    popup.scroll:SetVerticalScroll(0)
    Render()
end

local function Choose()
    local selected = popup.selected
    if not selected then return end
    if NS.GetTalentBuildCurrentSpecID() ~= popup.specID
        or NS.GetTalentBuildClassToken() ~= popup.classToken then
        Reject("Your specialization changed. Close this preview and open it again.",
            { state = "unavailable", choices = {} })
        return
    end
    local fresh = ReadResult()
    if not Contains(fresh, selected) then
        Reject("These test results changed. Review the updated choices before choosing.", fresh)
        return
    end
    local entry = NS.FindTalentBuildByID(selected.buildID)
    if not entry or entry.specID ~= popup.specID or entry.classToken ~= popup.classToken
        or entry.importString ~= selected.importString then
        Reject("This build changed since it was tested. Choose another build from the normal list.",
            { state = "stale", choices = {} })
        return
    end
    local enabled = AutoEnabled()
    if enabled ~= popup.reviewedAuto then
        popup.reviewedAuto = enabled
        Reject("Automatic Points changed. Read its status below, then choose again when you are ready.")
        return
    end
    if NS.ValidateTalentBuildImportString then
        local valid, message = NS.ValidateTalentBuildImportString(selected.importString, popup.specID)
        if not valid then Reject(message or "This build cannot be used by your current talent tree."); return end
    end
    local ok, message = NS.SetTalentLevelingTarget(selected.buildID)
    if not ok then Reject(message or "Unable to choose this build. Please try again."); return end
    popup.frame:Hide()
    if popup.onSelected then popup.onSelected(entry, enabled) end
end

Render = function()
    local result = popup.result
    UI.SetTextIfChanged(popup.status, names[result.state] or names.unavailable)
    for targets, button in pairs(popup.scenarios) do
        button:SetAlpha(popup.targets == targets and 1 or .55)
    end
    local reason = popup.message or result.reason or "No matching tests are available yet."
    if popup.details then
        reason = (popup.selected and ("Selected: " .. popup.selected.name .. "\n\n") or "")
            .. reason .. "\n\n" .. (result.details or "No further test details are available.")
    elseif result.state == "tie" then
        reason = reason .. "\nChoose one of the tied builds below."
    end
    popup.body:SetText(reason)
    local height = math.max(18, popup.body:GetStringHeight())
    popup.body:SetHeight(height)
    for _, row in ipairs(popup.rows) do row:Hide() end
    if not popup.details and Selectable(result) then
        for index, choice in ipairs(result.choices or {}) do
            local row = popup.rows[index]
            if not row then
                row = UI.Action(popup.content, "", 0, 0, 512, 38, function()
                    local current = popup.rows[index].choice
                    popup.selected = { buildID = current.buildID, importString = current.importString, name = current.name }
                    popup.message = nil
                    Render()
                end, "quiet")
                row._label:SetWordWrap(true)
                row._label:SetNonSpaceWrap(true)
                row._label:SetMaxLines(0)
                row._label:SetJustifyH("LEFT")
                popup.rows[index] = row
            end
            row.choice = choice
            local selected = popup.selected and popup.selected.buildID == choice.buildID
                and popup.selected.importString == choice.importString
            -- These names are live catalog text, not baked lettering assets.
            row._label:SetText((selected and "Selected: " or "") .. choice.name)
            row._label:SetWidth(484)
            row._label:SetHeight(row._label:GetStringHeight())
            row:SetHeight(math.max(38, row._label:GetHeight() + 16))
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", popup.content, "TOPLEFT", 0, -height - 8)
            row:SetAlpha(selected and 1 or .7)
            row:Show()
            height = height + 8 + row:GetHeight()
        end
    end
    popup.content:SetHeight(height + 4)
    local maximum = math.max(0, popup.content:GetHeight() - popup.scroll:GetHeight())
    popup.scroll:SetVerticalScroll(math.min(popup.scroll:GetVerticalScroll(), maximum))
    popup.scrollHint:SetShown(maximum > 0)
    popup.consent:SetText(popup.reviewedAuto
        and "Automatic Points is On. Choosing this build can spend points or rebuild your talents immediately."
        or "Automatic Points is Off. Choosing a build keeps it off. Turn it on later when you are ready.")
    SetEnabled(popup.choose, Contains(result, popup.selected))
    UI.SetActionText(popup.detailsButton, popup.details and "Back" or "Details")
end

local function Create()
    local frame = NS.CreateFrame("Frame", "BetterSBA_SBATalentSuggestions", NS.UIParent, "BackdropTemplate")
    frame:SetSize(560, 400)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    frame:SetBackdropColor(NS.unpack(C.card))
    frame:SetBackdropBorderColor(NS.unpack(C.border))
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()
    if type(UISpecialFrames) == "table" then UISpecialFrames[#UISpecialFrames + 1] = "BetterSBA_SBATalentSuggestions" end
    popup = { frame = frame, rows = {}, scenarios = {} }
    NS.SBATalentSuggestions = popup
    local title = Label(frame, "Best Tested for SBA", 16, -14, 440, 20)
    title:SetHeight(26)
    popup.close = UI.Action(frame, "Close", 476, -12, 68, 28, function() frame:Hide() end, "quiet")
    for _, targets in ipairs({ 1, 5 }) do
        popup.scenarios[targets] = UI.Action(frame, targets == 1 and "One Target" or "Five Targets",
            targets == 1 and 16 or 144, -52, 118, 28, function()
                popup.targets, popup.details = targets, false
                Review(true)
            end)
    end
    popup.status = Label(frame, "", 278, -57, 266, 12)
    popup.status:SetHeight(18)
    local intro = Label(frame, "Compared at max level using example gear. Your results may differ.", 16, -94, 528, 12)
    intro:SetHeight(30)
    local scroll = NS.CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -132)
    scroll:SetSize(528, 128)
    scroll:EnableMouseWheel(true)
    local content = NS.CreateFrame("Frame", nil, scroll)
    content:SetSize(512, 1)
    scroll:SetScrollChild(content)
    popup.scroll, popup.content = scroll, content
    popup.body = Label(content, "", 0, 0, 512, 12)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        local maximum = math.max(0, content:GetHeight() - scroll:GetHeight())
        scroll:SetVerticalScroll(math.max(0, math.min(maximum, scroll:GetVerticalScroll() - delta * 42)))
    end)
    popup.scrollHint = Label(frame, "Scroll for more.", 16, -266, 528, 10)
    popup.scrollHint:SetHeight(14)
    popup.consent = Label(frame, "", 16, -292, 528, 12)
    popup.consent:SetHeight(44)
    popup.detailsButton = UI.Action(frame, "Details", 16, -350, 90, 32, function()
        popup.details = not popup.details
        popup.scroll:SetVerticalScroll(0)
        Render()
    end, "quiet")
    popup.classInfo = UI.Action(frame, "Class Info", 118, -350, 98, 32, function()
        if NS.ShowTalentClassInfo then NS.ShowTalentClassInfo(popup.owner, popup.specID) end
        frame:Hide()
    end, "quiet")
    popup.choose = UI.Action(frame, "Choose This Build", 354, -350, 190, 32, Choose)
end

function NS.ShowSBATalentSuggestions(owner, specID, onSelected)
    if not popup then Create() end
    owner = owner or NS.UIParent
    popup.owner, popup.specID, popup.onSelected = owner, specID or NS.GetTalentBuildCurrentSpecID(), onSelected
    popup.classToken = NS.GetTalentBuildClassToken()
    popup.targets, popup.details = 1, false
    if not owner._sbaSuggestionsHideHook then
        owner._sbaSuggestionsHideHook = true
        owner:HookScript("OnHide", function() if popup.owner == owner then popup.frame:Hide() end end)
    end
    popup.frame:SetScale(math.min(1, (NS.UIParent:GetWidth() - 32) / 560, (NS.UIParent:GetHeight() - 32) / 400))
    popup.frame:SetFrameLevel(math.max(100, owner:GetFrameLevel() + 20))
    popup.frame:ClearAllPoints()
    popup.frame:SetPoint("CENTER", owner, "CENTER")
    SetEnabled(popup.classInfo, NS.ShowTalentClassInfo ~= nil)
    Review(true)
    popup.frame:Show()
end
