local ADDON_NAME, NS = ...
local T = NS.THEME

local reminderFrame

local function IsKnown(spellID)
    if NS.IsCombatAssistSpellKnown then
        return NS.IsCombatAssistSpellKnown(spellID) == true
    end
    return false
end

function NS.GetActiveManualCooldownReminder()
    if not (NS.db and NS.db.enabled ~= false and NS.db.manualCooldownReminders) then return nil end
    local specID = NS.GetTalentBuildCurrentSpecID and NS.GetTalentBuildCurrentSpecID()
    if not specID then return nil end
    local state = NS.GetTalentLevelingState and NS.GetTalentLevelingState(specID)
    local buildID = state and state.buildID
    local entry = NS.GetManualCooldownReminderForTarget and NS.GetManualCooldownReminderForTarget(specID, buildID)
    if not entry or not entry.spellID or not IsKnown(entry.spellID) then return nil end

    local getName = NS.C_Spell and NS.C_Spell.GetSpellName
    if not getName then return nil end
    local ok, name = NS.pcall(getName, entry.spellID)
    if not ok or not name or (issecretvalue and issecretvalue(name)) then return nil end
    -- Leveling assessment decodes the full talent tree; the display ticker
    -- only needs the selected catalog entry's stable name.
    local target = NS.FindTalentBuildByID and NS.FindTalentBuildByID(buildID)
    local targetName = target and target.name or buildID
    return entry, specID, buildID, name, targetName
end

local function EnsureReminderFrame()
    if reminderFrame then return reminderFrame end
    local anchor = NS.mainButton
    if not anchor or NS.InCombatLockdown() then return nil end

    local frame = NS.CreateFrame("Frame", "BetterSBA_ManualCooldownReminder", anchor, "BackdropTemplate")
    frame:SetSize(184, 52)
    frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(anchor:GetFrameLevel() + 2)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    frame:SetBackdropColor(T.BG_DARK[1], T.BG_DARK[2], T.BG_DARK[3], 0.94)
    frame:SetBackdropBorderColor(T.ACCENT_DIM[1], T.ACCENT_DIM[2], T.ACCENT_DIM[3], 0.75)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("LEFT", 8, 0)
    icon:SetTexCoord(NS.unpack(NS.ICON_TEXCOORD))

    local cooldown = NS.CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon)
    cooldown:SetDrawEdge(false)
    cooldown:SetHideCountdownNumbers(false)

    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont(NS.GetConfigFontPath(), 8, "OUTLINE")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -7)
    title:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    title:SetHeight(11)
    title:SetWordWrap(false)
    title:SetJustifyH("LEFT")
    title:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
    title:SetText("MANUAL COOLDOWN")

    local name = frame:CreateFontString(nil, "OVERLAY")
    name:SetFont(NS.GetConfigFontPath(), 10, "OUTLINE")
    name:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -1)
    name:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    name:SetHeight(13)
    name:SetWordWrap(false)
    name:SetJustifyH("LEFT")
    name:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])

    local context = frame:CreateFontString(nil, "OVERLAY")
    context:SetFont(NS.GetConfigFontPath(), 8, "")
    context:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -1)
    context:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    context:SetHeight(10)
    context:SetWordWrap(false)
    context:SetJustifyH("LEFT")
    context:SetTextColor(T.TEXT_DIM[1], T.TEXT_DIM[2], T.TEXT_DIM[3])

    local status = frame:CreateFontString(nil, "OVERLAY")
    status:SetFont(NS.GetConfigFontPath(), 8, "OUTLINE")
    status:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, 5)
    status:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    status:SetHeight(10)
    status:SetWordWrap(false)
    status:SetJustifyH("LEFT")

    frame._icon, frame._cooldown = icon, cooldown
    frame._spellName, frame._context, frame._status = name, context, status
    frame:Hide()
    reminderFrame = frame
    NS.manualCooldownReminderFrame = frame
    return frame
end

function NS.UpdateManualCooldownReminder()
    local entry, specID, buildID, spellName, targetName = NS.GetActiveManualCooldownReminder()
    if not entry then
        if reminderFrame then reminderFrame:Hide() end
        return
    end

    local frame = EnsureReminderFrame()
    if not frame then return end
    local texture = NS.GetSpellTextureCached and NS.GetSpellTextureCached(entry.spellID)
        or (NS.C_Spell and NS.C_Spell.GetSpellTexture and NS.C_Spell.GetSpellTexture(entry.spellID))
    if texture then frame._icon:SetTexture(texture) end
    frame._spellName:SetText(spellName)
    local specName = NS.GetTalentBuildSpecName and NS.GetTalentBuildSpecName(specID) or ""
    frame._context:SetText((specName or "") .. "  •  " .. tostring(targetName or buildID))

    if NS.SetSpellCooldownVisual then NS.SetSpellCooldownVisual(frame._cooldown, entry.spellID) else frame._cooldown:Clear() end
    -- The general display treats a short GCD as actionable; a manual reminder
    -- must say READY only when the spell cooldown itself is actually zero.
    local ready = NS.IsCooldownShortOrReady
        and NS.IsCooldownShortOrReady(NS.GetCooldownCached and NS.GetCooldownCached(entry.spellID), 0)
    if ready == true then
        frame._status:SetText("READY — PRESS MANUALLY")
        frame._status:SetTextColor(T.TOGGLE_ON[1], T.TOGGLE_ON[2], T.TOGGLE_ON[3])
    elseif ready == false then
        frame._status:SetText("ON COOLDOWN — PRESS MANUALLY")
        frame._status:SetTextColor(T.TEXT_DIM[1], T.TEXT_DIM[2], T.TEXT_DIM[3])
    else
        frame._status:SetText("COOLDOWN UNKNOWN")
        frame._status:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
    end
    frame:Show()
end

function NS.RefreshManualCooldownReminder()
    if NS.InvalidateCooldownCache then NS.InvalidateCooldownCache() end
    NS.UpdateManualCooldownReminder()
end
