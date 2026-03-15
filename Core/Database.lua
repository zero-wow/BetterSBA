local ADDON_NAME, NS = ...

-- Keys that live at root level (NOT inside profiles)
local GLOBAL_KEYS = {
    _version = true,
    activeProfile = true,
    profiles = true,
    charProfiles = true,
    minimap = true,
    palettes = true,
    palettePaths = true,
    paletteFavorites = true,
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

    -- Migrate enableClickIntercept boolean to interceptionType string
    if profile.enableClickIntercept == true then
        profile.interceptionType = "Both"
        profile.enableClickIntercept = nil
    elseif profile.enableClickIntercept == false then
        profile.enableClickIntercept = nil
    end

    -- Clean up session-only state
    profile._queueLocked = nil
    profile.queueDetached = false     -- legacy key cleanup
    profile.priorityDetached = false  -- drag mode is session-only

    if profile.debugSpellSubs ~= nil and profile.debugSpellUpdates == nil then
        profile.debugSpellUpdates = profile.debugSpellSubs
    end
    profile.debugSpellSubs = nil

    -- Migrate queue* → priority* DB keys (v0006 rename)
    local QUEUE_TO_PRIORITY = {
        showQueue              = "showPriority",
        queueIconSize          = "priorityIconSize",
        queueSpacing           = "prioritySpacing",
        queuePosition          = "priorityPosition",
        showQueueKeybinds      = "showPriorityKeybinds",
        queueKeybindFontSize   = "priorityKeybindFontSize",
        queueDetached          = "priorityDetached",
        queueFreePosition      = "priorityFreePosition",
        queueOffsetX           = "priorityOffsetX",
        queueOffsetY           = "priorityOffsetY",
        queueAlphaOOC          = "priorityAlphaOOC",
        queueKeybindFont       = "priorityKeybindFont",
        queueKeybindOutline    = "priorityKeybindOutline",
        queueKeybindFontOverride = "priorityKeybindFontOverride",
        queueLabelFont         = "priorityLabelFont",
        queueLabelOutline      = "priorityLabelOutline",
        queueLabelFontOverride = "priorityLabelFontOverride",
        queueLabelFontSize     = "priorityLabelFontSize",
        queueLabelOffsetX      = "priorityLabelOffsetX",
        queueLabelOffsetY      = "priorityLabelOffsetY",
        queueBgColor           = "priorityBgColor",
        queueBorderColor       = "priorityBorderColor",
        queueScale             = "priorityScale",
        sectionColorQueue      = "sectionColorPriority",
    }
    for old, new in pairs(QUEUE_TO_PRIORITY) do
        if profile[old] ~= nil and profile[new] == nil then
            profile[new] = profile[old]
            profile[old] = nil
        elseif profile[old] ~= nil then
            profile[old] = nil  -- new key already set, just clean up old
        end
    end

    -- Rename particle style "Stars" → "Squares"
    for key, val in pairs(profile) do
        if NS.type(key) == "string" and key:find("ParticleStyle$") and val == "Stars" then
            profile[key] = "Squares"
        end
    end

    -- Rename animation "SPIN" → "VORTEX"
    if profile.castAnimation == "SPIN" then
        profile.castAnimation = "VORTEX"
    end
    local SPIN_TO_VORTEX = {
        spinParticles = "vortexParticles",
        spinParticleTiming = "vortexParticleTiming",
        spinParticleStyle = "vortexParticleStyle",
        spinParticlePalette = "vortexParticlePalette",
    }
    for old, new in pairs(SPIN_TO_VORTEX) do
        if profile[old] ~= nil then
            if profile[new] == nil then profile[new] = profile[old] end
            profile[old] = nil
        end
    end
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
    root.palettes = root.palettes or {}
    root.palettePaths = root.palettePaths or {}
    root.paletteFavorites = root.paletteFavorites or {}

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
-- Palette access helpers (palettes live at root level, shared)
----------------------------------------------------------------
function NS:GetPalette(name)
    if not name then return nil end
    if name == "Random" then
        local list = NS.BUILTIN_PALETTE_ORDER
        local pick = list[math.random(#list)]
        if pick == "Class" then pick = list[1] end
        return self:GetPalette(pick)
    end
    if name == "Class" then
        local _, classToken = UnitClass("player")
        local cc = RAID_CLASS_COLORS and classToken and RAID_CLASS_COLORS[classToken]
        if cc then
            return {
                { cc.r, cc.g, cc.b },
                { math.min(1, cc.r * 1.3), math.min(1, cc.g * 1.3), math.min(1, cc.b * 1.3) },
                { cc.r * 0.7, cc.g * 0.7, cc.b * 0.7 },
                { math.min(1, cc.r * 0.5 + 0.5), math.min(1, cc.g * 0.5 + 0.5), math.min(1, cc.b * 0.5 + 0.5) },
            }
        end
    end
    -- User palettes first, then built-in
    if self.dbRoot and self.dbRoot.palettes and self.dbRoot.palettes[name] then
        return self.dbRoot.palettes[name]
    end
    return NS.BUILTIN_PALETTES[name]
end

function NS:GetPaletteList()
    local list = {}
    local seen = {}
    -- Built-in palettes in defined order
    for _, name in NS.ipairs(NS.BUILTIN_PALETTE_ORDER) do
        list[#list + 1] = name
        seen[name] = true
    end
    -- User palettes alphabetically
    if self.dbRoot and self.dbRoot.palettes then
        local userNames = {}
        for name in NS.pairs(self.dbRoot.palettes) do
            if not seen[name] then
                userNames[#userNames + 1] = name
            end
        end
        table.sort(userNames)
        for _, name in NS.ipairs(userNames) do
            list[#list + 1] = name
        end
    end
    return list
end

function NS:SavePalette(name, colors, path)
    if not name or name == "" or not colors then return false end
    if not self.dbRoot then return false end
    self.dbRoot.palettes[name] = colors
    if path then
        self.dbRoot.palettePaths[name] = path
    end
    return true
end

function NS:DeletePalette(name)
    if not name or NS.BUILTIN_PALETTES[name] then return false end
    if not self.dbRoot or not self.dbRoot.palettes then return false end
    self.dbRoot.palettes[name] = nil
    if self.dbRoot.paletteFavorites then
        self.dbRoot.paletteFavorites[name] = nil
    end
    -- Clean up palette path
    if self.dbRoot.palettePaths then
        self.dbRoot.palettePaths[name] = nil
    end
    -- Revert any animation using this palette to "Confetti"
    if self.db then
        for _, animType in NS.ipairs(NS.CAST_ANIMATIONS) do
            if animType ~= "NONE" then
                local key = NS.AnimKeyPrefix(animType) .. "ParticlePalette"
                if self.db[key] == name then
                    self.db[key] = "Confetti"
                end
            end
        end
    end
    return true
end

----------------------------------------------------------------
-- Palette path helpers
----------------------------------------------------------------
function NS:GetPalettePath(name)
    if not name then return nil end
    if NS.BUILTIN_PALETTE_PATHS[name] then
        return NS.BUILTIN_PALETTE_PATHS[name]
    end
    if self.dbRoot and self.dbRoot.palettePaths then
        return self.dbRoot.palettePaths[name]
    end
    return nil
end

function NS:SetPalettePath(name, path)
    if not name or not self.dbRoot then return end
    self.dbRoot.palettePaths = self.dbRoot.palettePaths or {}
    if path and path ~= "" then
        self.dbRoot.palettePaths[name] = path
    else
        self.dbRoot.palettePaths[name] = nil
    end
end

----------------------------------------------------------------
-- Palette favorites
----------------------------------------------------------------
local BUILTIN_FAVORITES = {
    Confetti = true, Magic = true, Neon = true, Fire = true,
    Ice = true, Shadow = true, Rainbow = true, Gold = true, Class = true,
}

function NS:IsPaletteFavorite(name)
    if not name then return false end
    if self.dbRoot and self.dbRoot.paletteFavorites and self.dbRoot.paletteFavorites[name] ~= nil then
        return self.dbRoot.paletteFavorites[name]
    end
    return BUILTIN_FAVORITES[name] or false
end

function NS:SetPaletteFavorite(name, isFav)
    if not name or not self.dbRoot then return end
    self.dbRoot.paletteFavorites = self.dbRoot.paletteFavorites or {}
    if BUILTIN_FAVORITES[name] then
        if isFav then
            self.dbRoot.paletteFavorites[name] = nil
        else
            self.dbRoot.paletteFavorites[name] = false
        end
    else
        if isFav then
            self.dbRoot.paletteFavorites[name] = true
        else
            self.dbRoot.paletteFavorites[name] = nil
        end
    end
end

function NS:IsBuiltinPalette(name)
    return NS.BUILTIN_PALETTES[name] ~= nil or name == "Class"
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
    if NS.ApplyAnimCloneDebugBinding then NS.ApplyAnimCloneDebugBinding() end
    if NS.ApplyDebugSettings then NS.ApplyDebugSettings() end
    -- Update priority display
    if NS.ApplyPriorityFonts then NS.ApplyPriorityFonts() end
    if NS.LayoutPriority then NS.LayoutPriority() end
    -- Refresh all display state
    if NS.UpdateNow then NS.UpdateNow() end
    -- Update LDB text
    if NS.UpdateLDBText then NS.UpdateLDBText() end
end
