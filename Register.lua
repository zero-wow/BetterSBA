local ADDON_NAME, NS = ...

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
if not LSM then return end

local FONT_PATH = "Interface\\AddOns\\BetterSBA\\Fonts\\"

LSM:Register("font", "Cascadia Code",           FONT_PATH .. "CascadiaCode-Bold.ttf")
LSM:Register("font", "Cascadia Code SemiBold",   FONT_PATH .. "CascadiaCode-SemiBold.ttf")
LSM:Register("font", "Cascadia Code NF",         FONT_PATH .. "CascadiaCodeNF-Bold.ttf")
LSM:Register("font", "Cascadia Code NF SemiBold", FONT_PATH .. "CascadiaCodeNF-SemiBold.ttf")
LSM:Register("font", "Cascadia Code PL",         FONT_PATH .. "CascadiaCodePL-Bold.ttf")
LSM:Register("font", "Cascadia Code PL SemiBold", FONT_PATH .. "CascadiaCodePL-SemiBold.ttf")
LSM:Register("font", "Cascadia Mono",            FONT_PATH .. "CascadiaMono-Bold.ttf")
LSM:Register("font", "Cascadia Mono SemiBold",   FONT_PATH .. "CascadiaMono-SemiBold.ttf")
LSM:Register("font", "Cascadia Mono NF",         FONT_PATH .. "CascadiaMonoNF-Bold.ttf")
LSM:Register("font", "Cascadia Mono PL",         FONT_PATH .. "CascadiaMonoPL-Bold.ttf")
