local ADDON_NAME, NS = ...

----------------------------------------------------------------
-- Masque integration
----------------------------------------------------------------
-- Reapply our hotkey offsets after Masque repositions elements
local function PostMasqueSkinFix()
    local btn = NS.mainButton
    if btn and btn.hotkey then
        btn.hotkey:ClearAllPoints()
        btn.hotkey:SetPoint(NS.db.keybindAnchor or "TOPRIGHT", NS.db.keybindOffsetX or -5, NS.db.keybindOffsetY or -5)
    end
end

function NS.InitMasque()
    local MSQ = LibStub and LibStub("Masque", true)
    if not MSQ then return end
    NS.masque = MSQ

    -- Masque callback fires when user changes skin â€” reapply our offsets after
    local function onSkinChanged() NS.C_Timer_After(0, PostMasqueSkinFix) end

    NS.masqueMainGroup = MSQ:Group("BetterSBA", "Main Button")
    NS.masqueMainGroup.SkinChanged = onSkinChanged
    NS.masquePriorityGroup = MSQ:Group("BetterSBA", "Rotation")
    NS.masqueAnimGroup = MSQ:Group("BetterSBA", "Animated Button")
end

-- No-op: Masque handles its own reskinning via callbacks.
-- Kept for any remaining call sites during transition.
function NS.MasqueReSkin() end
