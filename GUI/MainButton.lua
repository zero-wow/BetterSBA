local ADDON_NAME, NS = ...

local T = NS.THEME
local ticker

----------------------------------------------------------------
-- Create the main secure action button
----------------------------------------------------------------
function NS:CreateMainButton()
    local db = self.db
    local size = db.buttonSize

    local btn = NS.CreateFrame("Button", "BetterSBA_MainButton", NS.UIParent,
        "SecureActionButtonTemplate, BackdropTemplate")
    btn:SetSize(size, size)
    btn:SetScale(db.scale)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(5)
    btn:SetClampedToScreen(true)
    btn:SetMovable(true)
    btn:RegisterForDrag("LeftButton")

    -- Secure macro action
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("macrotext", NS.BuildMacroText())

    -- Background
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(0, 0, 0, 0.85)
    btn:SetBackdropBorderColor(NS.unpack(T.BORDER))

    -- Icon
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", 1, -1)
    btn.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Cooldown
    btn.cooldown = NS.CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints(btn.icon)
    btn.cooldown:SetDrawEdge(false)
    btn.cooldown:SetHideCountdownNumbers(false)

    -- Keybind text
    btn.hotkey = btn:CreateFontString(nil, "OVERLAY")
    btn.hotkey:SetFont("Fonts\\FRIZQT__.TTF", db.keybindFontSize, "OUTLINE")
    btn.hotkey:SetPoint("TOPRIGHT", -2, -2)
    btn.hotkey:SetTextColor(0.9, 0.9, 0.9, 1)

    -- Current spell ID
    btn.spellID = nil

    -- Drag handling
    btn:SetScript("OnDragStart", function(self)
        if not NS.db.locked and not NS.InCombatLockdown() then
            self:StartMoving()
        end
    end)
    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        NS.db.position = { point = p, relPoint = rp, x = x, y = y }
    end)

    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.spellID then
            GameTooltip:SetSpellByID(self.spellID)
            GameTooltip:AddLine(" ")
        end
        GameTooltip:AddLine("BetterSBA", T.ACCENT[1], T.ACCENT[2], T.ACCENT[3])
        if not NS.db.locked then
            GameTooltip:AddLine("Drag to move | /bs lock", 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Restore position
    if db.position then
        local pos = db.position
        btn:ClearAllPoints()
        btn:SetPoint(pos.point, NS.UIParent, pos.relPoint, pos.x, pos.y)
    else
        btn:SetPoint("CENTER", NS.UIParent, "CENTER", 0, -100)
    end

    self.mainButton = btn
    return btn
end

----------------------------------------------------------------
-- Update button visuals
----------------------------------------------------------------
local function UpdateButton(btn, spellID)
    if not spellID then
        btn.spellID = nil
        btn.icon:SetTexture(nil)
        btn.hotkey:SetText("")
        btn.cooldown:Clear()
        return
    end

    btn.spellID = spellID

    -- Icon
    local tex = NS.C_Spell and NS.C_Spell.GetSpellTexture and NS.C_Spell.GetSpellTexture(spellID)
    if tex then
        btn.icon:SetTexture(tex)
    end

    -- Keybind
    if NS.db.showKeybind then
        local key = NS.GetKeybindForSpell(spellID)
        btn.hotkey:SetText(key or "")
        btn.hotkey:Show()
    else
        btn.hotkey:Hide()
    end

    -- Cooldown
    if NS.db.showCooldown and NS.C_Spell and NS.C_Spell.GetSpellCooldown then
        local cdInfo = NS.C_Spell.GetSpellCooldown(spellID)
        if cdInfo and cdInfo.startTime and cdInfo.duration and cdInfo.duration > 1.5 then
            btn.cooldown:SetCooldown(cdInfo.startTime, cdInfo.duration)
        else
            btn.cooldown:Clear()
        end
    end

    -- Range coloring
    if NS.db.rangeColoring and NS.C_Spell and NS.C_Spell.IsSpellInRange then
        local inRange = NS.C_Spell.IsSpellInRange(spellID, "target")
        if inRange == false then
            btn.icon:SetVertexColor(T.OUT_OF_RANGE[1], T.OUT_OF_RANGE[2], T.OUT_OF_RANGE[3])
            btn.icon:SetDesaturated(true)
        else
            btn.icon:SetVertexColor(1, 1, 1)
            btn.icon:SetDesaturated(false)
        end
    else
        btn.icon:SetVertexColor(1, 1, 1)
        btn.icon:SetDesaturated(false)
    end
end

----------------------------------------------------------------
-- Visibility
----------------------------------------------------------------
local function UpdateVisibility()
    local btn = NS.mainButton
    if not btn then return end
    local db = NS.db

    if not db.enabled then
        btn:Hide()
        return
    end

    if db.hideInVehicle and UnitInVehicle("player") then
        btn:Hide()
        return
    end

    local inCombat = InCombatLockdown()

    if db.onlyInCombat and not inCombat then
        btn:SetAlpha(0)
        return
    end

    btn:Show()
    btn:SetAlpha(inCombat and db.alphaCombat or db.alphaOOC)
end

----------------------------------------------------------------
-- Main update tick
----------------------------------------------------------------
function NS.UpdateNow()
    local btn = NS.mainButton
    if not btn then return end

    UpdateVisibility()

    if not btn:IsVisible() or btn:GetAlpha() == 0 then return end

    local spellID = NS.CollectNextSpell()
    UpdateButton(btn, spellID)

    -- Update queue display
    if NS.UpdateQueueDisplay then
        NS.UpdateQueueDisplay()
    end
end

----------------------------------------------------------------
-- Start / stop ticker
----------------------------------------------------------------
function NS.StartTicker()
    if ticker then return end
    local rate = NS.db.updateRate or 0.1
    if rate < 0.05 then rate = 0.05 end
    ticker = NS.C_Timer_NewTicker(rate, NS.UpdateNow)
end

function NS.StopTicker()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

----------------------------------------------------------------
-- Apply size/scale changes
----------------------------------------------------------------
function NS.ApplyButtonSettings()
    local btn = NS.mainButton
    if not btn then return end
    btn:SetSize(NS.db.buttonSize, NS.db.buttonSize)
    btn:SetScale(NS.db.scale)
    if btn.hotkey then
        btn.hotkey:SetFont("Fonts\\FRIZQT__.TTF", NS.db.keybindFontSize, "OUTLINE")
    end
end
