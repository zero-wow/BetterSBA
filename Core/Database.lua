local ADDON_NAME, NS = ...

function NS:InitializeDatabase()
    if not BetterSBA_DB then
        BetterSBA_DB = {}
    end

    self.db = BetterSBA_DB

    for key, value in NS.pairs(NS.defaults) do
        if self.db[key] == nil then
            if NS.type(value) == "table" then
                self.db[key] = CopyTable(value)
            else
                self.db[key] = value
            end
        end
    end

    -- Migrate old alpha-only bg settings to color tables
    if NS.type(self.db.buttonBgAlpha) == "number" then
        self.db.buttonBgColor = { 0, 0, 0, self.db.buttonBgAlpha }
        self.db.buttonBgAlpha = nil
    end
    if NS.type(self.db.queueBgAlpha) == "number" then
        self.db.queueBgColor = { 0, 0, 0, self.db.queueBgAlpha }
        self.db.queueBgAlpha = nil
    end

    -- Migrate boolean castAnimation to string
    if NS.type(self.db.castAnimation) == "boolean" then
        self.db.castAnimation = self.db.castAnimation and "DRIFT" or "NONE"
    end

    -- Clean up session-only state
    self.db._queueLocked = nil
    self.db.queueDetached = false  -- drag mode is session-only
end
