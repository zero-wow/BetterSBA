local ADDON_NAME, NS = ...

-- These are deliberately limited to catalog builds whose reviewed source notes
-- say that SBA leaves this specific cooldown to the player.  They are display
-- hints only: this table is never used to build a macro or cast a spell.
NS.MANUAL_COOLDOWN_REMINDERS = {
    [63] = { -- Fire Mage: the catalog guide adaptation calls out Combustion.
        ["BSBA-WH-SBA-COMPATIBLE-63-TARGETED-20260924"] = {
            spellID = 190319,
            sourceURL = "https://www.wowhead.com/guide/classes/mage/fire/basics",
        },
    },
    [258] = { -- Shadow Priest: the catalog source explicitly excludes PI.
        ["WH-SBA-COMPATIBLE-258-20260812"] = {
            spellID = 10060,
            sourceURL = "https://www.wowhead.com/guide/classes/priest/shadow/basics",
        },
    },
    [577] = { -- Havoc: both Fel-Scarred SBA alternatives require Meta manually.
        ["ICY-577-sba-fel-scarred-raid"] = {
            spellID = 191427,
            sourceURL = "https://www.icy-veins.com/wow/havoc-demon-hunter-pve-dps-easy-mode",
        },
        ["ICY-577-sba-fel-scarred-dungeon"] = {
            spellID = 191427,
            sourceURL = "https://www.icy-veins.com/wow/havoc-demon-hunter-pve-dps-easy-mode",
        },
    },
}

-- Devourer's catalog notes mention manual Void Metamorphosis, but the reviewed
-- talent definition (471306) is passive and its live activation has no native
-- cooldown duration.  Do not synthesize a READY state or a fake cooldown swipe.

function NS.GetManualCooldownReminderForTarget(specID, buildID)
    if not specID or not buildID or buildID == NS.TALENT_BUILD_CUSTOM_ID then return nil end
    local bySpec = NS.MANUAL_COOLDOWN_REMINDERS[specID]
    return bySpec and bySpec[buildID] or nil
end
