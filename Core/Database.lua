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
end
