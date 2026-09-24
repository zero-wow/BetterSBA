local ADDON_NAME, NS = ...

-- Snapshot of the WoW talent-build fields on LazyGrip 12.1 sequence pages.
-- GRIP/EMS rotation exports are deliberately excluded; these are Blizzard
-- talent imports and are not assumed to be SBA-optimized.
local builds = {
    { id = "LAZYGRIP-121-250-msqkways", classToken = "DEATHKNIGHT", specID = 250, name = "Slowdog Blood Deathbringer M+ (12.1)",
      author = "Slowdog", heroTree = "Deathbringer", contentType = "Mythic+",
      importString = "CoPAkXBWxkyfx9CbGaHonEAhLxMzyMzwMmZmhZZmZmmZxYmxMGAAAAwMmZmZmZYGDAYmZmZGAAgxsNwAWC2GmADLAmxMAAMzAYYA", sourceURL = "https://lazygrip.net/sequences/slowdogs-bdk-v6-midnight-121-deathbringer-m-plus-tank-macro-msqkways" },
    { id = "LAZYGRIP-121-1480-mql7isti", classToken = "DEMONHUNTER", specID = 1480, name = "12.1.0 MFDOOM - Devourer Demon Hunter",
      author = "MFDOOM", heroTree = "Annihilator", contentType = "Mythic+",
      importString = "CgcBAAAAAAAAAAAAAAAAAAAAAAA2mxMzMzMzMGmBAAAAAAYxY2GMDAAAAAAAAzYwMzMzMzMzMMziZMW0yCzMzMbtNzMDgZMAEwYwYGA", sourceURL = "https://lazygrip.net/sequences/1207-mfdoom-devourer-demon-hunter-mql7isti" },
    { id = "LAZYGRIP-121-1480-mteg5ydz", classToken = "DEMONHUNTER", specID = 1480, name = "Devo-Hybrid for current *WoWHead Build* Void",
      author = "daddymt", heroTree = "Void-Scarred", contentType = "Raid",
      importString = "CgcBAAAAAAAAAAAAAAAAAAAAAAA2MmZmZmZmxwMAAAAAAAegxsNYGAAAAAAAAmxMMmZmZMzMzYmtZGjNttAgAGgZMzMbzMTz2MLzMjZMA", sourceURL = "https://lazygrip.net/sequences/devo-hybrid-for-current-wowhead-build-void-mteg5ydz" },
    { id = "LAZYGRIP-121-577-mql7d6xw", classToken = "DEMONHUNTER", specID = 577, name = "12.1.0 MFDOOM - Havoc Demon Hunter",
      author = "MFDOOM", heroTree = "Fel-Scarred", contentType = "Mythic+",
      importString = "CEkAAAAAAAAAAAAAAAAAAAAAAYmZGzMz2MmZmxYmMmZAAAAAAAzixsNDzMwMWmZmZYmBzyALzmZMMLaaMzMmxGAAAwAAAAYmBDAAAAD", sourceURL = "https://lazygrip.net/sequences/1207-mfdoom-havoc-demon-hunter-mql7d6xw" },
    { id = "LAZYGRIP-121-581-mql76kas", classToken = "DEMONHUNTER", specID = 581, name = "12.1.0 MFDOOM - Vengeance Demon Hunter",
      author = "MFDOOM", heroTree = "Annihilator", contentType = "Mythic+",
      importString = "CUkAAAAAAAAAAAAAAAAAAAAAAAAYMzMjhZkZmBWMjZwMjZGz8AzMzYYmZmx2YGjxMAAAAAAACYmZsBAAAgBmZmZml2mZmBAzAAAAYA", sourceURL = "https://lazygrip.net/sequences/1207-mfdoom-vengeance-demon-hunter-mql76kas" },
    { id = "LAZYGRIP-121-581-mt47411l", classToken = "DEMONHUNTER", specID = 581, name = "Annihilator Vengeance Demon Hunter",
      author = "alienx22", heroTree = "Annihilator", contentType = "Mythic+",
      importString = "CUkAp/epaxe7D0A403L+Tvk0iCAYMzMjhZkZmBWMjZwMjZGz8AzMzYYmZmx2YGjxMAAAAAAACYmZsBAAAgBmZmZml2mZmBAzAAAAYA", sourceURL = "https://lazygrip.net/sequences/annihilator-vengeance-demon-hunter-mt47411l" },
    { id = "LAZYGRIP-121-103-mpui8hza", classToken = "DRUID", specID = 103, name = "Pershizzle's Druid of the Claw",
      author = "Pershizzle", heroTree = "", contentType = "Mythic+",
      importString = "CcGADBD3hSPCL9Y9gz68WcKvMAAAAAAgxMzGzMzMGzmx2MLzMzMmZAAAAYLY2MGmZUzYWMzMzsMmxMAAAAAAGYAAAA0MLzyMzMgALgZGgFGMAAAmZDD", sourceURL = "https://lazygrip.net/sequences/pershizzles-druid-of-the-claw-mpui8hza" },
    { id = "LAZYGRIP-121-104-mqd1jhg9", classToken = "DRUID", specID = 104, name = "12.1.0 MFDOOM - Guardian Druid",
      author = "MFDOOM", heroTree = "Elune's Chosen", contentType = "Mythic+",
      importString = "CgGADBD3hSPCL9Y9gz68WcKvMAAAAAAAAAAAAgZmxs4BmZMziZxMPwMWGY2MMaimZmlZmZmZZMDAAAAAAzYxMwy2MDGzyAYKAAAwGmZAWMDGwiFAmZAMA", sourceURL = "https://lazygrip.net/sequences/1205-mfdoom-guardian-druid-mqd1jhg9" },
    { id = "LAZYGRIP-121-104-msxiz161", classToken = "DRUID", specID = 104, name = "Slowdog's Elune's Chosen M+ V2 | 12.1 Guardian Tank Macro",
      author = "Slowdog", heroTree = "Elune's Chosen", contentType = "Mythic+",
      importString = "CgGADBD3hSPCL9Y9gz68WcKvMAAAAAAAAAAAAgZmxsYmZMziZxMmZZZgZzwoJamZWmZmZmlxMMAAAAAgZsZALbzMYMLDgpAAAAbYmHAYxMYALWAYmBwA", sourceURL = "https://lazygrip.net/sequences/slowdogs-elunes-chosen-m-plus-v2-121-guardian-tank-macro-msxiz161" },
    { id = "LAZYGRIP-121-1473-msup2p2y", classToken = "EVOKER", specID = 1473, name = "12.1.0 MFDOOM - Augmentation Evoker",
      author = "MFDOOM", heroTree = "Scalecommander", contentType = "Mythic+",
      importString = "CEcBAAAAAAAAAAAAAAAAAAAAAMMzMbjZGMDzMLzYmZMzGAAAAAAAAmhZGYM1YmZGAAAAMzMjxMz2YmBmZzYwCsMGGbDgZiYDjZwMDgB", sourceURL = "https://lazygrip.net/sequences/1210-mfdoom-augmentation-evoker-msup2p2y" },
    { id = "LAZYGRIP-121-1467-msumt9ef", classToken = "EVOKER", specID = 1467, name = "12.1.0 MFDOOM - Devastation Evoker",
      author = "MFDOOM", heroTree = "Scalecommander", contentType = "Mythic+",
      importString = "CsbBPJc41CfcseY0baneJ1IHrBAAAAAAAAAAAjZAPgZGmBGGjZaMzMNjx2MmZmZmZmZGwMzMGzMbzMDMwYwGsMGN2GQmJAbYGMzghB", sourceURL = "https://lazygrip.net/sequences/1210-mfdoom-devastation-evoker-msumt9ef" },
    { id = "LAZYGRIP-121-255-mst6txgv", classToken = "HUNTER", specID = 255, name = "12.1.0 MFDOOM - Survival Hunter",
      author = "MFDOOM", heroTree = "Pack Leader", contentType = "Mythic+",
      importString = "C8PAAAAAAAAAAAAAAAAAAAAAAMWgBmxoxyAYmgtZmZmxMz2MAAAAAAmxMzMMjxMmBjpZAAAAGAgltZGLzYmxYMzAwM2wixwMLGAA", sourceURL = "https://lazygrip.net/sequences/1210-mfdoom-survival-hunter-mst6txgv" },
    { id = "LAZYGRIP-121-62-mti3zusj", classToken = "MAGE", specID = 62, name = "Arcane M+ & Raid",
      author = "daddymt", heroTree = "Sunfury", contentType = "Mythic+",
      importString = "C4DAAAAAAAAAAAAAAAAAAAAAAMzwYZmZmFMzQzMGAAAGAwMz0sssMDAEbAAsBzMDbWmxMLzYMzMzMswMzMzMAADAAwAMzAMAYYmZA", sourceURL = "https://lazygrip.net/sequences/arcane-m-plus-mti3zusj" },
    { id = "LAZYGRIP-121-63-mt157u5r", classToken = "MAGE", specID = 63, name = "Fire fire My a.. on fire",
      author = "pandorapandabears", heroTree = "Sunfury", contentType = "Mythic+",
      importString = "C8DAAAAAAAAAAAAAAAAAAAAAAMzwMLzMzsgZGZmxAAAwAAmZmmlllZAA2MzM2GzMzYBAAAAALmZmZGAAMmhxMzMzsNAMzAMGDmhBA", sourceURL = "https://lazygrip.net/sequences/fire-fire-my-a-on-fire-mt157u5r" },
    { id = "LAZYGRIP-121-64-mqczowkp", classToken = "MAGE", specID = 64, name = "12.1.0 MFDOOM - Frost Mage",
      author = "MFDOOM", heroTree = "Spellslinger", contentType = "Mythic+",
      importString = "CAEAche08tHz49KSVf7iKFnyuZGGLzMzsMmZmYmZGzMzMziZmZMjZgAAAzMzssMz0GAAAAAAsBw2yYmZGMbDjZYDAAgZ2AmBGwMYYA", sourceURL = "https://lazygrip.net/sequences/1205-mfdoom-frost-mage-mqczowkp" },
    { id = "LAZYGRIP-121-268-mqcy5yt7", classToken = "MONK", specID = 268, name = "12.1.0 MFDOOM - Brewmaster Monk",
      author = "MFDOOM", heroTree = "Shado-Pan", contentType = "Mythic+",
      importString = "CwQAAAAAAAAAAAAAAAAAAAAAAAAAAwMLbGDzwyM2MmZMAAAAAAALLgYmBmhBzgZmZGzsNMjZWGW2stNbzYWAAgNEAAgZbWamZmNG2AYmhpxAGAwA", sourceURL = "https://lazygrip.net/sequences/1205-mfdoom-brewmaster-monk-mqcy5yt7" },
    { id = "LAZYGRIP-121-269-mqd2avol", classToken = "MONK", specID = 269, name = "12.1.0 MFDOOM - Windwalker Monk",
      author = "MFDOOM", heroTree = "Shado-Pan", contentType = "Mythic+",
      importString = "C0QAAAAAAAAAAAAAAAAAAAAAAMzYAMGbzMz2MAAAAAAAAAAAALDzEmxywAmxwMzMDz2wMMLzEAwiZ2mZGzMzMAA2AgZZWamZmFAMwMDAswQMgB", sourceURL = "https://lazygrip.net/sequences/1205-mfdoom-windwalker-monk-mqd2avol" },
    { id = "LAZYGRIP-121-66-msuq8ly8", classToken = "PALADIN", specID = 66, name = "12.1.0 MFDOOM - Protection Paladin",
      author = "MFDOOM", heroTree = "Lightsmith", contentType = "Mythic+",
      importString = "CIEAAAAAAAAAAAAAAAAAAAAAAsZeAzyYGzYmZWWGjZZWmlZMAADAAAAAAaamhZMzwY2aDADMgZw2AAAIAzMbbLtMzYxyCGAwMMGAMzAwMzgMWA", sourceURL = "https://lazygrip.net/sequences/1210-mfdoom-protection-paladin-msuq8ly8" },
    { id = "LAZYGRIP-121-256-mst9y8ld", classToken = "PRIEST", specID = 256, name = "12.1.0 MFDOOM - Discipline Priest",
      author = "MFDOOM", heroTree = "Oracle", contentType = "Raid",
      importString = "CAQAR03Gt7xPmcDNOjs2Zlb3yCDsADmZGmZGz2MbzMzMDzAAAAAAAAAAYGWmBzMzwMMDMTz0MDwMLYIMmlBYMYBAAGjZGDmBYmZ0MMA", sourceURL = "https://lazygrip.net/sequences/1210-mfdoom-discipline-priest-mst9y8ld" },
    { id = "LAZYGRIP-121-257-mt5r35dj", classToken = "PRIEST", specID = 257, name = "Lucifer Holy Oracle M+ / Raid (12.1)",
      author = "lucifer", heroTree = "Oracle", contentType = "Mythic+",
      importString = "CEQAR03Gt7xPmcDNOjs2Zlb3yCDAAAAAAgZmxsMmZMzYYGYZmZmBAAAwYmlZwMzM2mxMDgZKAmZBDhxsMAjBWMzMLAaGzMGDmBYmZAD", sourceURL = "https://lazygrip.net/sequences/lucifers-holy-m-plus-oracle-121-season-2-august-23-mt5r35dj" },
    { id = "LAZYGRIP-121-258-mqzxri1u", classToken = "PRIEST", specID = 258, name = "12.1.0 MFDOOM - Shadow Priest",
      author = "MFDOOM", heroTree = "Archon", contentType = "Raid",
      importString = "CIQAR03Gt7xPmcDNOjs2Zlb3yOMDDAAAAAAAAAAAAmZxMmZbmxMzyMGzM2mxYmZGbIzYxMNAzAMzmZ0sZAIjxCAmZAjZmZMbMz2yAMDGA", sourceURL = "https://lazygrip.net/sequences/1207-mfdoom-shadow-priest-mqzxri1u" },
    { id = "LAZYGRIP-121-260-mthzkkzm", classToken = "ROGUE", specID = 260, name = "SK OL TR P2 SPEND",
      author = "SatisfiedKiller", heroTree = "Trickster", contentType = "Mythic+",
      importString = "CQQA5HmDzx68KWyrW/8Y781L7Dgx2MMzMjZmtZmZMzMzsAmZbaZw2MAAAAAAbLzMzwMzMziZmZbAAAAMzMAYMLGGyAzCL0CbAYmBDMA", sourceURL = "https://lazygrip.net/sequences/sk-ol-tr-p2-spend-mthzkkzm" },
    { id = "LAZYGRIP-121-261-mthhnax2", classToken = "ROGUE", specID = 261, name = "SK DS AOE M+",
      author = "SatisfiedKiller", heroTree = "Deathstalker", contentType = "Mythic+",
      importString = "CUQA5HmDzx68KWyrW/8Y781L7Dgx2MAAAAAwsMGLTMbbjxMDjZmZmZGGbzYGbbzMzMzMjBjZ2GAAAAGMmFzyADYBsMMhMLYGmZAmxA", sourceURL = "https://lazygrip.net/sequences/sk-ds-aoe-m-plus-mthhnax2" },
    { id = "LAZYGRIP-121-261-mt7m5226", classToken = "ROGUE", specID = 261, name = "SK ST SUB Trickster",
      author = "SatisfiedKiller", heroTree = "Trickster", contentType = "Mythic+",
      importString = "CUQA5HmDzx68KWyrW/8Y781L7Dgx2MAAAAAwsMGLTMbbjxMjZMegZmZGjZbYmx2MzMegZGwMzsMAAAAMDjBMmlZYgBzsoFaxGmBmZGMjB", sourceURL = "https://lazygrip.net/sequences/sk-st-sub-trickster-mt7m5226" },
    { id = "LAZYGRIP-121-263-mqd60kcp", classToken = "SHAMAN", specID = 263, name = "12.1.0 MFDOOM - Enhancement Shaman",
      author = "MFDOOM", heroTree = "Totemic", contentType = "Mythic+",
      importString = "CcQALMl7AwW51MWzGneuHE3tPOzMjZmZmZmZmZmZGzAAAAAAAAAgFYDmxiGbDgZC2AYWmxMGLLGYmZbsMzMzMYZMDAAwYMjYmBYwYA", sourceURL = "https://lazygrip.net/sequences/1205-mfdoom-enhancement-shaman-mqd60kcp" },
    { id = "LAZYGRIP-121-266-mql7vm9c", classToken = "WARLOCK", specID = 266, name = "12.1.0 MFDOOM - Demonology Warlock",
      author = "MFDOOM", heroTree = "Diabolist", contentType = "Mythic+",
      importString = "CoQAAAAAAAAAAAAAAAAAAAAAAYmhZGNbmx2MzYWGAAAAAAAwYGDLwAbj2ohFjZGLz2MzMmBAmZMmZmZAmZGmZDAAMmZmxwwyMGwA", sourceURL = "https://lazygrip.net/sequences/1207-mfdoom-demonology-warlock-mql7vm9c" },
    { id = "LAZYGRIP-121-267-msjnqumq", classToken = "WARLOCK", specID = 267, name = "Anubikk's Destruction Warlock Diabolist M+ 12.1 Ready",
      author = "Anubikk", heroTree = "Diabolist", contentType = "Mythic+",
      importString = "CsQAMrNP5kak+EBqLfUa3dMm+yMjZGNbmx2MzYWmNzMzsYmZZZMAAYGjZmZDMmxwCZgthFaswAAAjBDAwMDwYGzMbAAAmZmBAAzwA", sourceURL = "https://lazygrip.net/sequences/anubikks-destruction-warlock-diabolist-m-plus-121-ready-msjnqumq" },
    { id = "LAZYGRIP-121-73-mqbi7gzi", classToken = "WARRIOR", specID = 73, name = "12.1.0 MFDOOM - Protection Warrior",
      author = "MFDOOM", heroTree = "Mountain Thane", contentType = "Mythic+",
      importString = "CkEAAAAAAAAAAAAAAAAAAAAAA0yAAAjZGzMzYGzmZmlZMGjGzYGLzMzMDzYmBAAAALDAzYAGYD2WMaMDgZJmZDmZMDmFAYmBAgBMG", sourceURL = "https://lazygrip.net/sequences/1205-mfdoom-protection-warrior-mqbi7gzi" },
}

for _, build in ipairs(builds) do
    build.rating = ""
    build.source = "LazyGrip"
    build.catalogSource = "LazyGrip"
    build.patch = "12.1"
    build.checkedAt = "2026-09-24"
    build.verificationStatus = "source-talent"
    build.notes = "Talent export published alongside a GRIP-EMS sequence on LazyGrip. It is not a GRIP/EMS import and is not independently verified for Blizzard SBA. Check the page and current in-game tree before selecting it."
    build.category = "LazyGrip 12.1 talent"
    build.buildType = NS.TALENT_BUILD_TYPE_BUILTIN
    NS.TALENT_BUILD_CATALOG.entries[#NS.TALENT_BUILD_CATALOG.entries + 1] = build
end
