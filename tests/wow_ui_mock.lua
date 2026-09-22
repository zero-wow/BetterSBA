-- Minimal WoW widget model for executable Config.lua construction tests.
-- It records dimensions and anchors while deliberately keeping rendering inert.
local M = {}

local function noop() end
local function widget(kind, parent)
    local o = {
        _kind = kind, _parent = parent, _children = {}, _shown = true,
        _width = 0, _height = 0, _scripts = {}, _points = {}, _alpha = 1,
    }
    if parent and parent._children then parent._children[#parent._children + 1] = o end
    local mt = {}
    function mt.__index(self, key)
        local methods = {
            SetSize = function(s, w, h) s._width, s._height = w or 0, h or 0 end,
            SetWidth = function(s, w) s._width = w or 0 end,
            SetHeight = function(s, h) s._height = h or 0 end,
            GetWidth = function(s) return s._width end,
            GetHeight = function(s) return s._height end,
            SetPoint = function(s, ...) s._points[#s._points + 1] = {...} end,
            ClearAllPoints = function(s) s._points = {} end,
            SetAllPoints = function(s, target) s._allPoints = target or s._parent end,
            SetParent = function(s, p) s._parent = p end,
            Show = function(s) s._shown = true end,
            Hide = function(s) s._shown = false end,
            IsShown = function(s) return s._shown end,
            SetShown = function(s, shown) s._shown = shown and true or false end,
            SetAlpha = function(s, alpha) s._alpha = alpha end,
            GetAlpha = function(s) return s._alpha end,
            SetScript = function(s, event, fn) s._scripts[event] = fn end,
            HookScript = function(s, event, fn) s._scripts[event] = fn end,
            GetScript = function(s, event) return s._scripts[event] end,
            CreateTexture = function(s) return widget("Texture", s) end,
            CreateFontString = function(s) return widget("FontString", s) end,
            SetText = function(s, text) s._text = text or "" end,
            GetText = function(s) return rawget(s, "_text") or "" end,
            GetStringWidth = function(s) return #(rawget(s, "_text") or "") * 6 end,
            SetVerticalScroll = function(s, value) s._scroll = value or 0 end,
            GetVerticalScroll = function(s) return rawget(s, "_scroll") or 0 end,
            SetScrollChild = function(s, child) s._scrollChild = child end,
            SetValue = function(s, value) s._value = value end,
            GetValue = function(s) return rawget(s, "_value") end,
            SetMinMaxValues = function(s, lo, hi) s._min, s._max = lo, hi end,
            GetMinMaxValues = function(s) return s._min, s._max end,
            SetBackdrop = noop, SetBackdropColor = noop, SetBackdropBorderColor = noop,
            SetColorTexture = noop, SetTexture = noop, SetVertexColor = noop,
            SetFont = noop, SetTextColor = noop, SetJustifyH = noop, SetJustifyV = noop,
            SetTextInsets = noop, SetAutoFocus = noop, SetMaxLetters = noop,
            SetCursorPosition = noop, HighlightText = noop, SetFocus = noop, ClearFocus = noop,
            EnableMouse = noop, EnableKeyboard = noop, SetPropagateKeyboardInput = noop,
            RegisterEvent = noop, RegisterForDrag = noop, SetMovable = noop,
            SetClampedToScreen = noop, SetFrameStrata = noop, SetFrameLevel = noop,
            GetFrameLevel = function() return 1 end, SetResizeBounds = noop,
            StartMoving = noop, StopMovingOrSizing = noop, SetScale = noop,
            SetNormalTexture = noop, SetHighlightTexture = noop, SetPushedTexture = noop,
            Enable = noop, Disable = noop,
        }
        return methods[key] or noop
    end
    return setmetatable(o, mt)
end

function M.install()
    local frames = {}
    local uiParent = widget("Frame")
    uiParent:SetSize(1920, 1080)
    local function createFrame(kind, name, parent)
        local f = widget(kind, parent or uiParent)
        f._name = name
        frames[#frames + 1] = f
        return f
    end
    _G.CreateFrame = createFrame
    _G.UIParent = uiParent
    _G.GetTime = function() return 1 end
    _G.C_Timer = { After = function() end }
    _G.GetCursorPosition = function() return 0, 0 end
    _G.InCombatLockdown = function() return false end
    _G.IsShiftKeyDown = function() return false end
    _G.IsControlKeyDown = function() return false end
    _G.IsAltKeyDown = function() return false end
    _G.CopyTable = function(t)
        local out = {}; for k, v in pairs(t) do out[k] = v end; return out
    end
    _G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    _G.GameTooltip = { SetOwner = noop, SetText = noop, AddLine = noop, Show = noop, Hide = noop }
    return { createFrame = createFrame, uiParent = uiParent, frames = frames }
end

-- Resolve the common fixed-size anchors used by BetterSBA's configuration UI.
-- This is intentionally a bounds checker, not a renderer or a full WoW layout engine.
function M.rect(frame, seen)
    seen = seen or {}
    if seen[frame] then return 0, 0, 0, 0 end
    seen[frame] = true
    local parent = rawget(frame, "_parent")
    local pl, pt, pr, pb
    if parent then pl, pt, pr, pb = M.rect(parent, seen) else pl, pt, pr, pb = 0, frame._height or 0, frame._width or 0, 0 end
    local w, h = frame._width or 0, frame._height or 0
    local point = frame._points[#frame._points]
    if not point then return pl, pt, pl + w, pt - h end
    local own, target, relative, x, y = point[1], point[2], point[3], point[4], point[5]
    if type(target) ~= "table" then
        x, y, target, relative = target or 0, relative or 0, parent, own
    else
        relative, x, y = relative or own, x or 0, y or 0
    end
    target = target or parent
    local tl, tt, tr, tb = M.rect(target, seen)
    local function pointXY(kind, l, t, r, b)
        local midX, midY = (l + r) / 2, (t + b) / 2
        local px = kind:find("LEFT") and l or (kind:find("RIGHT") and r or midX)
        local py = kind:find("TOP") and t or (kind:find("BOTTOM") and b or midY)
        return px, py
    end
    local rx, ry = pointXY(relative, tl, tt, tr, tb)
    rx, ry = rx + x, ry + y
    local ox, oy = pointXY(own, 0, 0, w, -h)
    local l, t = rx - ox, ry - oy
    return l, t, l + w, t - h
end

return M
