local ADDON_NAME, NS = ...

-- Keys that live at root level (NOT inside profiles)
local GLOBAL_KEYS = {
    _version = true,
    activeProfile = true,
    profiles = true,
    charProfiles = true,
    minimap = true,
}

----------------------------------------------------------------
-- Character key for per-character profile binding
----------------------------------------------------------------
function NS.GetCharKey()
    local name, realm = UnitFullName("player")
    realm = realm or GetRealmName() or ""
    return (name or "Unknown") .. " - " .. realm
end

----------------------------------------------------------------
-- Migrate legacy per-profile settings (run on the profile table)
----------------------------------------------------------------
local function MigrateProfileSettings(profile)
    -- Migrate old alpha-only bg settings to color tables
    if NS.type(profile.buttonBgAlpha) == "number" then
        profile.buttonBgColor = { 0, 0, 0, profile.buttonBgAlpha }
        profile.buttonBgAlpha = nil
    end
    if NS.type(profile.queueBgAlpha) == "number" then
        profile.queueBgColor = { 0, 0, 0, profile.queueBgAlpha }
        profile.queueBgAlpha = nil
    end

    -- Migrate boolean castAnimation to string
    if NS.type(profile.castAnimation) == "boolean" then
        profile.castAnimation = profile.castAnimation and "DRIFT" or "NONE"
    end

    -- Sync minimap visibility inside profile
    if profile.minimap and profile.minimap.hide then
        profile.showMinimapButton = false
    end

    -- Clean up removed keys
    profile.sectionColorAnimation = nil
    profile.sectionColorFonts = nil

    -- Clean up removed sub-color keys (sub-headers now use parent section color)
    profile.subColorAnimation = nil
    profile.subColorFonts = nil
    profile.subColorLDB = nil
    profile.subColorImportance = nil

    -- Clean up session-only state
    profile._queueLocked = nil
    profile.queueDetached = false  -- drag mode is session-only
end

----------------------------------------------------------------
-- Fill missing keys from defaults (non-destructive)
----------------------------------------------------------------
local function ApplyDefaults(profile)
    for key, value in NS.pairs(NS.defaults) do
        if profile[key] == nil then
            if NS.type(value) == "table" then
                profile[key] = CopyTable(value)
            else
                profile[key] = value
            end
        end
    end
end

----------------------------------------------------------------
-- Initialize database with profile support
----------------------------------------------------------------
function NS:InitializeDatabase()
    if not BetterSBA_DB then
        BetterSBA_DB = {}
    end

    local root = BetterSBA_DB

    -- Detect and migrate legacy flat format (no _version field)
    if not root._version then
        local oldMinimap = root.minimap
        local profile = {}
        for k, v in NS.pairs(root) do
            if not GLOBAL_KEYS[k] then
                if NS.type(v) == "table" then
                    profile[k] = CopyTable(v)
                else
                    profile[k] = v
                end
            end
        end
        -- Wipe root and rebuild with profile structure
        for k in NS.pairs(root) do
            root[k] = nil
        end
        root._version = 1
        root.activeProfile = "Default"
        root.profiles = { ["Default"] = profile }
        root.charProfiles = {}
        root.minimap = oldMinimap or { hide = false }
    end

    -- Ensure structural integrity
    root._version = root._version or 1
    root.activeProfile = root.activeProfile or "Default"
    root.profiles = root.profiles or {}
    root.charProfiles = root.charProfiles or {}
    root.minimap = root.minimap or { hide = false }

    -- Ensure at least one profile exists
    if not next(root.profiles) then
        root.profiles["Default"] = {}
    end

    -- Store root reference
    self.dbRoot = root

    -- Resolve active profile for this character
    local charKey = NS.GetCharKey()
    local profileName = root.charProfiles[charKey] or root.activeProfile or "Default"

    -- Verify profile exists, fall back to first available
    if not root.profiles[profileName] then
        profileName = root.activeProfile or "Default"
        if not root.profiles[profileName] then
            profileName = next(root.profiles)
        end
    end

    local profile = root.profiles[profileName]

    -- Apply defaults and run migrations
    ApplyDefaults(profile)
    MigrateProfileSettings(profile)

    -- Alias root minimap into profile so NS.db.minimap works for LibDBIcon
    profile.minimap = root.minimap
    if root.minimap and root.minimap.hide then
        profile.showMinimapButton = false
    end

    -- Set the active reference (all NS.db.X reads now hit the profile)
    self.db = profile
    self._activeProfileName = profileName
end

----------------------------------------------------------------
-- Get sorted list of profile names
----------------------------------------------------------------
function NS:GetProfileList()
    local list = {}
    for name in NS.pairs(self.dbRoot.profiles) do
        NS.table_insert(list, name)
    end
    table.sort(list)
    return list
end

----------------------------------------------------------------
-- Get active profile name
----------------------------------------------------------------
function NS:GetActiveProfileName()
    return self._activeProfileName or self.dbRoot.activeProfile or "Default"
end

----------------------------------------------------------------
-- Create a new profile (deep-copy from current)
----------------------------------------------------------------
function NS:CreateProfile(name)
    if not name or name == "" then return false, "Name required" end
    if self.dbRoot.profiles[name] then return false, "Profile already exists" end

    local copy = {}
    for k, v in NS.pairs(self.db) do
        if NS.type(v) == "table" then
            copy[k] = CopyTable(v)
        else
            copy[k] = v
        end
    end
    self.dbRoot.profiles[name] = copy
    return true
end

----------------------------------------------------------------
-- Delete a profile (cannot delete last one)
----------------------------------------------------------------
function NS:DeleteProfile(name)
    if not name or not self.dbRoot.profiles[name] then return false, "Not found" end

    -- Count profiles
    local count = 0
    for _ in NS.pairs(self.dbRoot.profiles) do count = count + 1 end
    if count <= 1 then return false, "Cannot delete last profile" end

    -- Cannot delete the active profile
    if name == self._activeProfileName then return false, "Cannot delete active profile" end

    -- Remove profile
    self.dbRoot.profiles[name] = nil

    -- Clean up character bindings pointing to deleted profile
    for charKey, pName in NS.pairs(self.dbRoot.charProfiles) do
        if pName == name then
            self.dbRoot.charProfiles[charKey] = nil
        end
    end

    -- Fix activeProfile if it pointed to deleted
    if self.dbRoot.activeProfile == name then
        self.dbRoot.activeProfile = next(self.dbRoot.profiles)
    end

    return true
end

----------------------------------------------------------------
-- Rename a profile
----------------------------------------------------------------
function NS:RenameProfile(oldName, newName)
    if not oldName or not newName or newName == "" then return false, "Name required" end
    if oldName == newName then return false, "Same name" end
    if not self.dbRoot.profiles[oldName] then return false, "Not found" end
    if self.dbRoot.profiles[newName] then return false, "Name taken" end

    -- Move data
    self.dbRoot.profiles[newName] = self.dbRoot.profiles[oldName]
    self.dbRoot.profiles[oldName] = nil

    -- Update activeProfile
    if self.dbRoot.activeProfile == oldName then
        self.dbRoot.activeProfile = newName
    end

    -- Update charProfiles
    for charKey, pName in NS.pairs(self.dbRoot.charProfiles) do
        if pName == oldName then
            self.dbRoot.charProfiles[charKey] = newName
        end
    end

    -- Update internal name if active
    if self._activeProfileName == oldName then
        self._activeProfileName = newName
    end

    return true
end

----------------------------------------------------------------
-- Switch to a different profile (reassigns NS.db, triggers refresh)
----------------------------------------------------------------
function NS:SwitchProfile(name)
    if not name or not self.dbRoot.profiles[name] then return false, "Not found" end
    if name == self._activeProfileName then return false, "Already active" end

    local profile = self.dbRoot.profiles[name]
    ApplyDefaults(profile)
    MigrateProfileSettings(profile)

    self.db = profile
    self._activeProfileName = name

    -- Update the character binding
    local charKey = NS.GetCharKey()
    self.dbRoot.charProfiles[charKey] = name

    -- Also update global default
    self.dbRoot.activeProfile = name

    -- Refresh all visual state
    self:ApplyProfileVisuals()

    return true
end

----------------------------------------------------------------
-- Copy settings from another profile into the current one
----------------------------------------------------------------
function NS:CopyFromProfile(srcName)
    if not srcName or not self.dbRoot.profiles[srcName] then return false, "Not found" end
    if srcName == self._activeProfileName then return false, "Cannot copy from self" end

    local src = self.dbRoot.profiles[srcName]
    -- Overwrite current profile's settings
    for k in NS.pairs(self.db) do
        self.db[k] = nil
    end
    for k, v in NS.pairs(src) do
        if NS.type(v) == "table" then
            self.db[k] = CopyTable(v)
        else
            self.db[k] = v
        end
    end
    ApplyDefaults(self.db)

    -- Refresh visuals
    self:ApplyProfileVisuals()
    return true
end

----------------------------------------------------------------
-- Reset a profile to defaults
----------------------------------------------------------------
function NS:ResetProfile(name)
    name = name or self._activeProfileName
    local profile = self.dbRoot.profiles[name]
    if not profile then return false, "Not found" end

    -- Wipe and re-apply defaults
    for k in NS.pairs(profile) do
        profile[k] = nil
    end
    ApplyDefaults(profile)

    -- Refresh visuals if active
    if name == self._activeProfileName then
        self:ApplyProfileVisuals()
    end
    return true
end

----------------------------------------------------------------
-- Set character-specific profile (nil = use global default)
----------------------------------------------------------------
function NS:SetCharProfile(profileName)
    local charKey = NS.GetCharKey()
    if profileName then
        self.dbRoot.charProfiles[charKey] = profileName
    else
        self.dbRoot.charProfiles[charKey] = nil
    end
end

----------------------------------------------------------------
-- Check if current character has a specific profile binding
----------------------------------------------------------------
function NS:HasCharProfile()
    local charKey = NS.GetCharKey()
    return self.dbRoot.charProfiles[charKey] ~= nil
end

----------------------------------------------------------------
-- Apply all visual changes after a profile switch
----------------------------------------------------------------
function NS:ApplyProfileVisuals()
    -- Rebuild macro (may change targeting/petattack/channel options)
    if NS.RebuildMacroText then
        if NS.InCombatLockdown() then
            NS._pendingMacroRebuild = true
        else
            NS.RebuildMacroText()
        end
    end
    -- Update main button size, fonts, position
    if NS.ApplyButtonSettings then NS.ApplyButtonSettings() end
    -- Update queue display
    if NS.ApplyQueueFonts then NS.ApplyQueueFonts() end
    if NS.LayoutQueue then NS.LayoutQueue() end
    -- Refresh all display state
    if NS.UpdateNow then NS.UpdateNow() end
    -- Update LDB text
    if NS.UpdateLDBText then NS.UpdateLDBText() end
end
