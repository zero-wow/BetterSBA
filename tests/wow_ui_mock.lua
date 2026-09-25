-- Minimal WoW widget model for executable Config.lua construction tests.
-- It records dimensions, anchors, and visual metadata while deliberately
-- keeping rendering inert. Font metrics are estimates, suitable for bounds
-- checks rather than pixel-perfect screenshots.
local M = {}

local function noop() end
local function visibleText(value)
    local text = tostring(value or "")
    text = text:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return text
end

-- IsShown is local state; IsVisible also follows parent visibility. Lifecycle
-- scripts run only when that effective visibility actually changes.
local function isVisible(node)
    if not node or rawget(node, "_shown") == false then return false end
    local parent = rawget(node, "_parent")
    return not parent or isVisible(parent)
end

local function runScript(node, event, ...)
    local primary = (rawget(node, "_scripts") or {})[event]
    if primary then primary(node, ...) end
    local hooks = (rawget(node, "_hooks") or {})[event]
    if hooks then for _, hook in ipairs(hooks) do hook(node, ...) end end
end

local function captureVisibility(node, state)
    state[node] = isVisible(node)
    for _, child in ipairs(rawget(node, "_children") or {}) do captureVisibility(child, state) end
end

local function dispatchVisibility(node, before)
    local visible = isVisible(node)
    if before[node] ~= visible then runScript(node, visible and "OnShow" or "OnHide") end
    for _, child in ipairs(rawget(node, "_children") or {}) do dispatchVisibility(child, before) end
end

local function setShown(node, shown)
    shown = shown and true or false
    if rawget(node, "_shown") == shown then return end
    local before = {}
    captureVisibility(node, before)
    rawset(node, "_shown", shown)
    dispatchVisibility(node, before)
end

-- Approximate WoW's text box metrics. Glyph widths vary, so this is a
-- deliberately conservative inspection aid instead of a rendering promise.
function M.textMetrics(fontString, constrainedWidth)
    local font = rawget(fontString, "_font") or {}
    local size = font.size or 10
    local charWidth, lineHeight = size * 0.55, math.ceil(size * 1.2)
    local widest, lines = 0, 0
    local text = visibleText(rawget(fontString, "_text"))
    for line in (text .. "\n"):gmatch("(.-)\n") do
        local pixels = #line * charWidth
        widest = math.max(widest, pixels)
        if rawget(fontString, "_wordWrap") and constrainedWidth and constrainedWidth > 0 then
            lines = lines + math.max(1, math.ceil(pixels / constrainedWidth))
        else
            lines = lines + 1
        end
    end
    lines = math.max(1, lines)
    local maxLines = rawget(fontString, "_maxLines")
    if maxLines and maxLines > 0 then lines = math.min(lines, maxLines) end
    return widest, lines * lineHeight
end

local function widget(kind, parent)
    local o = {
        _kind = kind, _parent = parent, _children = {}, _shown = true,
        _width = 0, _height = 0, _scripts = {}, _hooks = {}, _points = {}, _alpha = 1,
        _widthExplicit = false, _heightExplicit = false,
    }
    if parent and parent._children then parent._children[#parent._children + 1] = o end
    local mt = {}
    function mt.__index(self, key)
        if type(key) == "string" and key:sub(1, 1) == "_" then return nil end
        local methods = {
            SetSize = function(s, w, h)
                s._width, s._height = w or 0, h or 0
                s._widthExplicit, s._heightExplicit = true, true
                runScript(s,"OnSizeChanged",s._width,s._height)
            end,
            SetWidth = function(s, w)
                s._width, s._widthExplicit = w or 0, true
                runScript(s,"OnSizeChanged",s._width,s._height)
            end,
            SetHeight = function(s, h)
                s._height, s._heightExplicit = h or 0, true
                runScript(s,"OnSizeChanged",s._width,s._height)
            end,
            GetWidth = function(s) return s._width end,
            GetHeight = function(s) return s._height end,
            GetParent = function(s) return rawget(s, "_parent") end,
            SetPoint = function(s, ...) s._points[#s._points + 1] = {...} end,
            ClearAllPoints = function(s) s._points, s._allPoints = {}, nil end,
            SetAllPoints = function(s, target) s._allPoints = target or s._parent end,
            SetParent = function(s, p)
                local oldParent = rawget(s, "_parent")
                if oldParent and oldParent._children then
                    for i, child in ipairs(oldParent._children) do
                        if child == s then table.remove(oldParent._children, i); break end
                    end
                end
                s._parent = p
                if p and p._children then p._children[#p._children + 1] = s end
            end,
            Show = function(s) setShown(s, true) end,
            Hide = function(s) setShown(s, false) end,
            IsShown = function(s) return rawget(s, "_shown") == true end,
            IsVisible = function(s) return isVisible(s) end,
            SetShown = function(s, shown) setShown(s, shown) end,
            SetAlpha = function(s, alpha) s._alpha = alpha end,
            GetAlpha = function(s) return s._alpha end,
            SetScript = function(s, event, fn) s._scripts[event] = fn end,
            HookScript = function(s, event, fn)
                if not fn then return end
                s._hooks[event] = s._hooks[event] or {}
                s._hooks[event][#s._hooks[event] + 1] = fn
            end,
            GetScript = function(s, event)
                local primary, hooks = s._scripts[event], s._hooks[event]
                if not primary and (not hooks or #hooks == 0) then return nil end
                if not hooks or #hooks == 0 then return primary end
                return function(_, ...) runScript(s, event, ...) end
            end,
            GetName = function(s) return rawget(s, "_name") end,
            SetAttribute = function(s, key, value)
                local attributes = rawget(s, "_attributes") or {}
                rawset(s, "_attributes", attributes)
                attributes[key] = value
            end,
            GetAttribute = function(s, key)
                local attributes = rawget(s, "_attributes")
                return attributes and attributes[key]
            end,
            RegisterForClicks = function(s, ...) s._clicks = {...} end,
            CreateTexture = function(s, name, layer, template, sublevel)
                local child = widget("Texture", s); child._name, child._layer, child._sublevel = name, layer, sublevel or 0; return child
            end,
            CreateMaskTexture = function(s) return widget("MaskTexture", s) end,
            CreateFontString = function(s, name, layer)
                local child = widget("FontString", s); child._name, child._layer = name, layer; return child
            end,
            GetChildren = function(s) return table.unpack(s._children) end,
            CreateAnimationGroup = function(s)
                local group = { _owner = s, _scripts = {}, _animations = {}, _playing = false }
                function group:CreateAnimation(kind)
                    local animation = { _kind = kind }
                    function animation:SetFromAlpha(value) self._fromAlpha = value end
                    function animation:SetToAlpha(value) self._toAlpha = value end
                    function animation:SetDuration(value) self._duration = value end
                    function animation:SetOrder(value) self._order = value end
                    group._animations[#group._animations + 1] = animation
                    return animation
                end
                function group:SetLooping(value) self._looping = value end
                function group:SetScript(event, fn) self._scripts[event] = fn end
                function group:Play() self._playing = true end
                function group:Stop() self._playing = false end
                function group:IsPlaying() return self._playing end
                return group
            end,
            SetText = function(s, text) s._text = text or "" end,
            GetText = function(s) return rawget(s, "_text") or "" end,
            GetStringWidth = function(s)
                return M.textMetrics(s)
            end,
            GetStringHeight = function(s)
                local width = rawget(s, "_resolvedTextWidth") or rawget(s, "_width")
                local _, height = M.textMetrics(s, width > 0 and width or nil)
                return height
            end,
            SetVerticalScroll = function(s, value) s._scroll = value or 0 end,
            GetVerticalScroll = function(s) return rawget(s, "_scroll") or 0 end,
            SetScrollChild = function(s, child) s._scrollChild = child end,
            SetValue = function(s, value) s._value = value end,
            GetValue = function(s) return rawget(s, "_value") end,
            SetMinMaxValues = function(s, lo, hi) s._min, s._max = lo, hi end,
            GetMinMaxValues = function(s) return s._min, s._max end,
            SetBackdrop = function(s, value) s._backdrop = value end,
            SetBackdropColor = function(s, ...) s._backdropColor = {...} end,
            SetBackdropBorderColor = function(s, ...) s._borderColor = {...} end,
            SetColorTexture = function(s, ...) s._color = {...} end,
            SetTexture = function(s, value) s._texture = value end,
            SetTexCoord = function(s, ...) s._texCoord = {...} end,
            SetRotation = function(s, value) s._rotation = value end,
            SetVertexColor = function(s, ...) s._vertexColor = {...} end,
            SetFont = function(s, path, size, flags)
                s._font = {path=path, size=size or 10, flags=flags or ""}
                return true
            end,
            SetTextColor = function(s, ...) s._textColor = {...} end,
            SetJustifyH = function(s, value) s._justifyH = value end,
            SetJustifyV = function(s, value) s._justifyV = value end,
            SetWordWrap = function(s, value) s._wordWrap = value and true or false end,
            SetMaxLines = function(s, value) s._maxLines = value end,
            SetTextInsets = function(s, ...) s._textInsets = {...} end,
            SetAutoFocus = function(s, value) s._autoFocus = value end,
            SetMaxLetters = function(s, value) s._maxLetters = value end,
            SetCursorPosition = noop, HighlightText = noop, SetFocus = noop, ClearFocus = noop,
            EnableMouse = noop, EnableKeyboard = noop, SetPropagateKeyboardInput = noop,
            RegisterEvent = noop, RegisterForDrag = noop, SetMovable = noop,
            SetClampedToScreen = function(s, value) s._clamped = value end,
            SetFrameStrata = function(s, value) s._strata = value end,
            SetFrameLevel = function(s, value) s._level = value end,
            GetFrameLevel = function(s) return rawget(s, "_level") or 1 end,
            SetResizeBounds = function(s, ...) s._resizeBounds = {...} end,
            StartMoving = noop, StopMovingOrSizing = noop,
            SetScale = function(s, value) s._scale = value or 1 end,
            GetScale = function(s) return rawget(s, "_scale") or 1 end,
            GetEffectiveScale = function(s)
                local parent = rawget(s, "_parent")
                return (rawget(s, "_scale") or 1) * (parent and parent:GetEffectiveScale() or 1)
            end,
            SetNormalTexture = function(s, value)
                assert(value ~= nil, "SetNormalTexture requires a non-nil texture; use ClearNormalTexture")
                s._normalTexture = value
            end,
            ClearNormalTexture = function(s) s._normalTexture = nil end,
            GetNormalTexture = function(s) return rawget(s, "_normalTexture") end,
            SetHighlightTexture = function(s, value)
                assert(value ~= nil, "SetHighlightTexture requires a non-nil texture; use ClearHighlightTexture")
                s._highlightTexture = value
            end,
            ClearHighlightTexture = function(s) s._highlightTexture = nil end,
            GetHighlightTexture = function(s) return rawget(s, "_highlightTexture") end,
            SetPushedTexture = function(s, value) s._pushedTexture = value end,
            GetPushedTexture = function(s) return rawget(s, "_pushedTexture") end,
            Enable = function(s) s._enabled = true end,
            Disable = function(s) s._enabled = false end,
        }
        return methods[key] or noop
    end
    return setmetatable(o, mt)
end

function M.install()
    local frames = {}
    local now = 1
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
    _G.GetTime = function() return now end
    _G.C_Timer = { After = function() end }
    _G.GetCursorPosition = function() return 0, 0 end
    _G.GetPhysicalScreenSize = function() return 1920, 1080 end
    _G.UpdateAddOnMemoryUsage = noop
    _G.GetAddOnMemoryUsage = function() return 256 end
    _G.InCombatLockdown = function() return false end
    _G.IsShiftKeyDown = function() return false end
    _G.IsControlKeyDown = function() return false end
    _G.IsAltKeyDown = function() return false end
    _G.CopyTable = function(t)
        local out = {}; for k, v in pairs(t) do out[k] = v end; return out
    end
    _G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    _G.GameTooltip = { SetOwner = noop, SetText = noop, AddLine = noop, Show = noop, Hide = noop }
    _G.PixelUtil = {
        GetPixelToUIUnitFactor = function() return 768 / select(2, GetPhysicalScreenSize()) end,
        GetNearestPixelSize = function(uiUnits, layoutScale, minPixels)
            if uiUnits == 0 and (not minPixels or minPixels == 0) then return 0 end
            local unit = PixelUtil.GetPixelToUIUnitFactor()
            local pixels = math.floor((uiUnits * layoutScale) / unit + (uiUnits < 0 and -0.5 or 0.5))
            if minPixels then
                pixels = uiUnits < 0 and math.min(pixels, -minPixels) or math.max(pixels, minPixels)
            end
            return pixels * unit / layoutScale
        end,
        SetWidth = function(region, value, minPixels)
            region:SetWidth(PixelUtil.GetNearestPixelSize(value, region:GetEffectiveScale(), minPixels))
        end,
        SetHeight = function(region, value, minPixels)
            region:SetHeight(PixelUtil.GetNearestPixelSize(value, region:GetEffectiveScale(), minPixels))
        end,
        SetSize = function(region, width, height, minWidthPixels, minHeightPixels)
            PixelUtil.SetWidth(region, width, minWidthPixels)
            PixelUtil.SetHeight(region, height, minHeightPixels)
        end,
        SetPoint = function(region, point, relativeTo, relativePoint, x, y, minX, minY)
            -- Frame:SetPoint accepts a nil relative target (UIParent/default
            -- parent). Normalize it here so a hidden decorative line with no
            -- explicit header remains harmless to bounds tests.
            if relativeTo == nil then
                relativeTo, relativePoint = rawget(region, "_parent") or UIParent, point
            end
            region:SetPoint(point, relativeTo, relativePoint,
                PixelUtil.GetNearestPixelSize(x or 0, region:GetEffectiveScale(), minX),
                PixelUtil.GetNearestPixelSize(y or 0, region:GetEffectiveScale(), minY))
        end,
    }
    local function advance(seconds)
        now = now + (seconds or 0)
        for _, frame in ipairs(frames) do
            if frame:IsVisible() then runScript(frame, "OnUpdate", seconds or 0) end
        end
    end
    return { createFrame = createFrame, uiParent = uiParent, frames = frames, advance = advance }
end

-- Resolve the common fixed-size and stretch anchors used by BetterSBA's
-- configuration UI. This deliberately is not a full WoW layout engine.
function M.rect(frame, stack)
    stack = stack or {}
    if stack[frame] then return 0, 0, 0, 0 end
    stack[frame] = true
    local parent = rawget(frame, "_parent")
    local pl, pt, pr, pb
    if parent then
        pl, pt, pr, pb = M.rect(parent, stack)
    else
        pl, pt, pr, pb = 0, frame._height or 0, frame._width or 0, 0
    end
    stack[frame] = nil

    local allPoints = rawget(frame, "_allPoints")
    if allPoints then return M.rect(allPoints, stack) end

    local function targetPoint(kind, l, t, r, b)
        kind = kind or "CENTER"
        local x = kind:find("LEFT") and l or (kind:find("RIGHT") and r or (l + r) / 2)
        local y = kind:find("TOP") and t or (kind:find("BOTTOM") and b or (t + b) / 2)
        return x, y
    end
    local anchors = {left=nil, right=nil, centerX=nil, top=nil, bottom=nil, centerY=nil}
    for _, point in ipairs(rawget(frame, "_points") or {}) do
        local own, target, relative, x, y = point[1], point[2], point[3], point[4], point[5]
        if type(target) ~= "table" then
            x, y, target, relative = target or 0, relative or 0, parent, own
        else
            relative, x, y = relative or own, x or 0, y or 0
        end
        target = target or parent
        local tl, tt, tr, tb
        if target then tl, tt, tr, tb = M.rect(target, stack) else tl, tt, tr, tb = pl, pt, pr, pb end
        local rx, ry = targetPoint(relative, tl, tt, tr, tb)
        local ox = own and (own:find("LEFT") and "left" or (own:find("RIGHT") and "right" or "centerX")) or "centerX"
        local oy = own and (own:find("TOP") and "top" or (own:find("BOTTOM") and "bottom" or "centerY")) or "centerY"
        anchors[ox], anchors[oy] = rx + x, ry + y
    end
    local isText = rawget(frame, "_kind") == "FontString"
    local w, h = frame._width or 0, frame._height or 0
    if isText and not rawget(frame, "_widthExplicit") then
        local intrinsicWidth = M.textMetrics(frame)
        w = intrinsicWidth
    end
    local l, r
    if anchors.left and anchors.right then l, r = anchors.left, anchors.right; w = r - l
    elseif anchors.left then l, r = anchors.left, anchors.left + w
    elseif anchors.right then r, l = anchors.right, anchors.right - w
    elseif anchors.centerX then l, r = anchors.centerX - w / 2, anchors.centerX + w / 2
    else l, r = pl, pl + w end
    if isText then
        rawset(frame, "_resolvedTextWidth", r - l)
        if not rawget(frame, "_heightExplicit") and not (anchors.top and anchors.bottom) then
            local _, intrinsicHeight = M.textMetrics(frame, r - l)
            h = intrinsicHeight
        end
    end
    local t, b
    if anchors.top and anchors.bottom then t, b = anchors.top, anchors.bottom; h = t - b
    elseif anchors.top then t, b = anchors.top, anchors.top - h
    elseif anchors.bottom then b, t = anchors.bottom, anchors.bottom + h
    elseif anchors.centerY then t, b = anchors.centerY + h / 2, anchors.centerY - h / 2
    else t, b = pt, pt - h end
    if parent and rawget(parent, "_kind") == "ScrollFrame"
        and rawget(parent, "_scrollChild") == frame then
        local offset = rawget(parent, "_scroll") or 0
        t, b = t + offset, b + offset
    end
    return l, t, r, b
end

-- Write a lightweight layout inspection artifact. It uses the recorded frame
-- bounds and colors; text positioning and metrics are intentionally estimated.
function M.writeSVG(root, path)
    local rl, rt, rr, rb = M.rect(root)
    local width, height = rr - rl, rt - rb
    local function escape(value)
        return tostring(value):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
    end
    local function cssColor(color, fallback)
        color = color or fallback
        if not color then return "none", 0 end
        local r, g, b, a = color[1] or 0, color[2] or 0, color[3] or 0, color[4]
        return ("rgb(%.0f,%.0f,%.0f)"):format(r * 255, g * 255, b * 255), a == nil and 1 or a
    end
    local lines = {
        ('<svg xmlns="http://www.w3.org/2000/svg" width="%g" height="%g" viewBox="0 0 %g %g">'):format(width, height, width, height),
        '<style>@font-face{font-family:Bangers;src:url("Fonts/Comic/Bangers-Regular.ttf")}</style>',
        '<rect width="100%" height="100%" fill="#101419"/>',
    }
    local defs, clipID = {}, 0
    local function visit(node, force)
        if rawget(node, "_shown") == false and not force then return end
        local l, t, r, b = M.rect(node)
        local x, y, w, h = l - rl, rt - t, r - l, t - b
        local kind = rawget(node, "_kind")
        if kind == "ScrollFrame" then
            clipID = clipID + 1
            local id = "scrollclip" .. clipID
            defs[#defs + 1] = ('<clipPath id="%s"><rect x="%.2f" y="%.2f" width="%.2f" height="%.2f"/></clipPath>'):format(id, x, y, w, h)
            lines[#lines + 1] = ('<g clip-path="url(#%s)">'):format(id)
            for _, child in ipairs(rawget(node, "_children") or {}) do visit(child) end
            lines[#lines + 1] = "</g>"
            return
        end
        if kind == "Texture" and rawget(node, "_layer") == "HIGHLIGHT" and not rawget(node, "_hovered") then return end
        local fill, opacity = cssColor(rawget(node, "_backdropColor") or rawget(node, "_color") or rawget(node, "_vertexColor"))
        local border, borderOpacity = cssColor(rawget(node, "_borderColor"), {0.35, 0.42, 0.5, 0.35})
        opacity = opacity * (rawget(node, "_alpha") or 1)
        borderOpacity = borderOpacity * (rawget(node, "_alpha") or 1)
        if (kind == "Frame" or kind == "Button" or kind == "EditBox") and (fill ~= "none" or rawget(node, "_backdrop")) and w > 0 and h > 0 then
            lines[#lines + 1] = ('<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="%s" fill-opacity="%.3f" stroke="%s" stroke-opacity="%.3f"/>'):format(x, y, w, h, fill, opacity, border, borderOpacity)
        elseif kind == "Texture" and
            (tostring(rawget(node,"_texture") or ""):find("IMG\\Comic\\",1,true)
            or tostring(rawget(node,"_texture") or ""):find("IMG\\Button\\TalentSpendAll",1,true))
            and w > 0 and h > 0 then
            local rel = rawget(node,"_texture"):gsub("\\","/"):match(".*BetterSBA/(IMG/[^/]+/[^/]+)") .. ".png"
            local uv = rawget(node,"_texCoord")
            local name = rel:match("([^/]+)%.png$") or ""
            local iw,ih = 256,256
            if name:find("Paper") then iw,ih=1024,1024
            elseif name:find("CardFrame") then iw,ih=1024,512
            elseif name == "TalentSpendAll" then iw,ih=512,128
            elseif name:find("Button") or name:find("Caption") then iw,ih=1024,128
            elseif name:find("Header") or name:find("TalentHero") or name:find("City") then iw,ih=1024,256
            elseif name:find("Ring") or name:find("SidebarMark") then iw,ih=512,512
            elseif name:find("Glint") then iw,ih=128,256 end
            local file=io.open(rel,"rb")
            if file then
                local header=file:read(24)
                file:close()
                if header and #header>=24 and header:sub(1,8)=="\137PNG\r\n\26\n" then
                    iw,ih=string.unpack(">I4I4",header,17)
                end
            end
            local u0,u1,v0,v1=0,1,0,1
            if uv then u0,u1,v0,v1=uv[1],uv[2],uv[3],uv[4] end
            local angle=(rawget(node,"_rotation") or 0)*180/math.pi
            lines[#lines+1]=('<svg x="%.2f" y="%.2f" width="%.2f" height="%.2f" viewBox="%.2f %.2f %.2f %.2f" preserveAspectRatio="none" opacity="%.3f" transform="rotate(%.2f %.2f %.2f)"><image x="0" y="0" width="%d" height="%d" href="%s"/></svg>'):format(
                x,y,w,h,u0*iw,v0*ih,(u1-u0)*iw,(v1-v0)*ih,(rawget(node,"_alpha") or 1),angle,x+w/2,y+h/2,iw,ih,rel)
        elseif kind == "Texture" and fill ~= "none" and w > 0 and h > 0 then
            local radius = tostring(rawget(node, "_texture") or ""):lower():find("keycap") and 4 or 0
            lines[#lines + 1] = ('<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" rx="%d" fill="%s" fill-opacity="%.3f"/>'):format(x, y, w, h, radius, fill, opacity)
        elseif kind == "FontString" then
            local text = rawget(node, "_text")
            if text and text ~= "" then
                local font = rawget(node, "_font") or {}
                local family = tostring(font.path or ""):find("Bangers",1,true) and "Bangers" or "Arial, sans-serif"
                local color, alpha = cssColor(rawget(node, "_textColor"), {0.9, 0.9, 0.9, 1})
                local tx = rawget(node, "_justifyH") == "RIGHT" and x + w
                    or (rawget(node, "_justifyH") == "CENTER" and x + w / 2 or x)
                local anchor = rawget(node, "_justifyH") == "RIGHT" and "end" or (rawget(node, "_justifyH") == "CENTER" and "middle" or "start")
                local lineNumber = 0
                for line in (visibleText(text) .. "\n"):gmatch("(.-)\n") do
                    lines[#lines + 1] = ('<text x="%.2f" y="%.2f" font-family="%s" font-size="%g" fill="%s" fill-opacity="%.3f" text-anchor="%s">%s</text>'):format(
                        tx, y + (font.size or 10) + lineNumber * math.ceil((font.size or 10) * 1.2),
                        family, font.size or 10, color, alpha, anchor, escape(line))
                    lineNumber = lineNumber + 1
                end
            end
        end
        if kind == "EditBox" then
            local value = rawget(node, "_text")
            if value and value ~= "" then
                local font = rawget(node, "_font") or {}
                local color, alpha = cssColor(rawget(node, "_textColor"), {0.9, 0.9, 0.9, 1})
                local insets = rawget(node, "_textInsets") or {}
                local justify = rawget(node, "_justifyH")
                local tx = justify == "RIGHT" and x + w - (insets[2] or 0)
                    or justify == "CENTER" and x + w / 2 or x + (insets[1] or 0)
                local anchor = justify == "RIGHT" and "end" or justify == "CENTER" and "middle" or "start"
                lines[#lines + 1] = ('<text x="%.2f" y="%.2f" font-family="Arial, sans-serif" font-size="%g" fill="%s" fill-opacity="%.3f" text-anchor="%s">%s</text>'):format(
                    tx, y + h / 2 + (font.size or 10) * .35, font.size or 10,
                    color, alpha, anchor, escape(visibleText(value)))
            end
        end
        local children = {}
        for i,child in ipairs(rawget(node, "_children") or {}) do children[#children+1]={node=child,index=i} end
        local layerOrder={BACKGROUND=1,BORDER=1.5,ARTWORK=4,OVERLAY=5,HIGHLIGHT=6}
        table.sort(children,function(a,b)
            local la=rawget(a.node,"_layer") and layerOrder[rawget(a.node,"_layer")] or 2
            local lb=rawget(b.node,"_layer") and layerOrder[rawget(b.node,"_layer")] or 2
            if la~=lb then return la<lb end
            local sa,sb=rawget(a.node,"_sublevel") or 0,rawget(b.node,"_sublevel") or 0
            return sa~=sb and sa<sb or sa==sb and a.index<b.index
        end)
        for _, child in ipairs(children) do visit(child.node) end
    end
    visit(root, true)
    if #defs > 0 then table.insert(lines, 3, "<defs>" .. table.concat(defs) .. "</defs>") end
    lines[#lines + 1] = "</svg>"
    local file = assert(io.open(path, "w"))
    file:write(table.concat(lines, "\n"))
    file:close()
end

return M
