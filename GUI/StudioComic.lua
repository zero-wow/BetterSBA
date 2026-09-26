local ADDON_NAME, NS = ...

-- Artwork is deliberately separate from controls. Text, hit targets and layout
-- remain native widgets; these layers can animate without moving a control.
local Studio = NS.ConfigStudio
local Comic = {}
Studio.Comic = Comic
local ROOT = "Interface\\AddOns\\BetterSBA\\IMG\\Comic\\"
local LETTER_ROOT = ROOT .. "Lettering\\"
Comic._fontTargets = setmetatable({}, { __mode = "k" })
local WHITE = "Interface\\Buttons\\WHITE8X8"
local unpack = NS.unpack or unpack
local faction = UnitFactionGroup and UnitFactionGroup("player") == "Horde" and "Horde" or "Alliance"
Comic.faction = faction
local path = function(name) return ROOT .. name end
local P = {
    button = path(faction .. "ButtonRounded"),
    chevron = path(faction .. "Chevron"),
    chevronHover = path(faction .. "ChevronHover"),
    ring = path(faction .. "Ring"), glint = path(faction .. "Glint"),
    paper = path(faction .. "Paper"),
    caption = path(faction .. "Caption"), cardFrame = path(faction .. "CardFrame"),
}
Comic.paths = P

-- Keep the native FontString for text measurement and variable values. Fixed
-- labels use transparent, pre-rendered lettering on top of the existing art.
function Comic.SetLettering(label, kind, value, size)
    if not label or not label.GetText then return false end
    local catalog = type(NS.StudioLettering) == "table" and NS.StudioLettering[kind]
    local entry = catalog and catalog[value or label:GetText()]
    local art = label._comicLettering
    if not entry then
        if art then art:Hide() end
        label:SetAlpha(1)
        label:Show()
        return false
    end
    if not art then
        art = label:GetParent():CreateTexture(nil, "OVERLAY", nil, 1)
        label._comicLettering = art
    end
    art:SetTexture(LETTER_ROOT .. entry.file)
    art:SetTexCoord(0, entry.u, 0, entry.v)
    art:ClearAllPoints()
    art:SetPoint(kind == "button" and "CENTER" or "LEFT", label,
        kind == "button" and "CENTER" or "LEFT", 0, 0)
    local width = label:GetWidth()
    if kind == "button" then
        local parentWidth = label:GetParent():GetWidth()
        width = math.min(width, parentWidth - (parentWidth >= 80 and 18 or 8))
    end
    local height = kind == "button" and math.max(12, label:GetParent():GetHeight() - 6)
        or (size or 16) + 3
    local scale = math.min(1, width > 0 and width / entry.width or 1,
        height / entry.height)
    art:SetSize(entry.width * scale, entry.height * scale)
    art:Show()
    -- SetAlpha(0) alone does not reliably suppress WoW FontString glyphs
    -- after later state/color updates. The art is a sibling on the parent,
    -- so hiding this measurement label leaves the illustrated text visible.
    label:SetAlpha(0)
    label:Hide()
    return true
end

function Comic.StyleHeading(label,size)
    local fallback = "Fonts\\FRIZQT__.TTF"
    if not label:SetFont(fallback,size,"") then
        label:SetFont(NS.GetConfigFontPath(),size,"OUTLINE")
    end
    label:SetShadowColor(0,0,0,.9)
    label:SetShadowOffset(size >= 18 and 2 or 1,-1)
    if size < 18 then label:SetHeight(size + 6) end
    Comic._fontTargets[label] = { kind = "heading", size = size }
    Comic.SetLettering(label, "heading", nil, size)
end

-- Navigation has a narrow, fixed row. Keep its text native so the illustrated
-- heading texture cannot collide with the page number or neighbouring rows.
function Comic.StyleNavText(label,size)
    size = size or 13
    local fallback = "Fonts\\FRIZQT__.TTF"
    if not label:SetFont(fallback,size,"") then
        label:SetFont(NS.GetConfigFontPath(),size,"")
    end
    label:SetShadowColor(0,0,0,.9)
    label:SetShadowOffset(1,-1)
    label:SetHeight(size + 6)
    if label._comicLettering then label._comicLettering:Hide() end
    label:SetAlpha(1)
    label:Show()
    Comic._fontTargets[label] = { kind = "nav", size = size }
end

function Comic.StyleButtonText(label,size)
    if not label then return end
    local fallback = NS.GetConfigFontPath and NS.GetConfigFontPath() or "Fonts\\FRIZQT__.TTF"
    size = size or 14
    -- Tiny state controls need a compact face and a real text box. Display
    -- fonts that work at 14px can have taller metrics than a 21px switch.
    local tiny = size < 13
    -- Live values still need a font. Use a client-provided face, since the
    -- illustrated fixed labels no longer depend on third-party font loading.
    local face = "Fonts\\FRIZQT__.TTF"
    if not label:SetFont(face,size,tiny and "OUTLINE" or "") then
        label:SetFont(fallback,size,"OUTLINE")
    end
    if tiny then label:SetHeight(18) end
    label:SetShadowColor(0,0,0,.95)
    label:SetShadowOffset(1,-1)
    Comic._fontTargets[label] = { kind = "button", size = size }
    Comic.SetLettering(label, "button", nil, size)
end

function Comic.RefreshTypography()
    for label, style in pairs(Comic._fontTargets) do
        if style.kind == "heading" then
            Comic.StyleHeading(label, style.size)
        elseif style.kind == "nav" then
            Comic.StyleNavText(label, style.size)
        else
            Comic.StyleButtonText(label, style.size)
            if label._comicActionButton then
                local button = label._comicActionButton
                local measured = label:GetStringWidth()
                if label:GetText() == "Change Build" then
                    label:SetText("Choose a Build")
                    measured = math.max(measured, label:GetStringWidth())
                    label:SetText("Change Build")
                end
                local art = type(NS.StudioLettering) == "table"
                    and NS.StudioLettering.button[label:GetText()]
                local width = math.min(label._comicActionMaxWidth,
                    math.max(88, math.ceil(measured) + 26,
                        art and math.ceil(art.width) + 18 or 0))
                button:SetWidth(width)
                label:SetWidth(width - 16)
                Comic.SetLettering(label, "button", nil, style.size)
            end
        end
    end
end

local function tint(t, color)
    t:SetVertexColor(unpack(color))
end

local function texture(parent, layer, file, alpha, sublevel)
    local t = parent:CreateTexture(nil, layer, nil, sublevel)
    t:SetTexture(file)
    t:SetAlpha(alpha or 1)
    return t
end

function Comic.DecoratePaper(frame,alpha)
    local paper=texture(frame,"BACKGROUND",P.paper,alpha or .6,1)
    paper:SetAllPoints(frame)
    local function crop()
        local w,h=frame:GetWidth(),frame:GetHeight()
        if not w or not h or w<1 or h<1 then return end
        if w>h then
            local span=h/w
            paper:SetTexCoord(0,1,(1-span)/2,(1+span)/2)
        else
            local span=w/h
            paper:SetTexCoord((1-span)/2,(1+span)/2,0,1)
        end
    end
    crop()
    frame:HookScript("OnSizeChanged",crop)
    frame._comicPaper=paper
end

local function ink(parent, point, relativePoint, x, y, w, h, color)
    local t = texture(parent, "ARTWORK", WHITE)
    t:SetPoint(point, parent, relativePoint, x, y)
    t:SetSize(w, h)
    tint(t, color)
    return t
end

function Comic.ApplyPalette(C)
    local palette
    if faction == "Horde" then
        palette = {
            shell={.035,.075,.060,1}, rail={.035,.065,.055,1},
            body={.045,.085,.068,1}, card={.060,.105,.080,1},
            border={.30,.37,.28,1}, gutter={.025,.045,.035,1},
            accent={.48,.30,.55,1}, bright={.96,.92,.86,1},
            text={.90,.91,.84,1}, dim={.66,.75,.65,1},
            muted={.49,.61,.51,1}, cyan={.64,.78,.56,1},
            gold={.73,.52,.21,1}, danger={.80,.22,.24,1},
        }
    else
        palette = {
            shell={.035,.053,.078,1}, rail={.035,.052,.080,1},
            body={.042,.062,.088,1}, card={.057,.080,.110,1},
            border={.29,.36,.52,1}, gutter={.022,.034,.053,1},
            accent={.32,.40,.64,1}, bright={.96,.95,.98,1},
            text={.88,.92,.98,1}, dim={.62,.73,.83,1},
            muted={.44,.60,.73,1}, cyan={.53,.79,.87,1},
            gold={.75,.55,.22,1}, danger={.85,.29,.35,1},
        }
    end
    for key, value in pairs(palette) do C[key] = value end
    Comic.colors = C
end

local function strip(parent, file, alpha, compactCap)
    local pieces = {}
    for i=1,3 do
        local t = texture(parent, "BACKGROUND", file, alpha)
        local u0,u1 = 0,.09
        if i == 2 then u0,u1=.09,.91 elseif i == 3 then u0,u1=.91,1 end
        t:SetTexCoord(u0,u1,0,1)
        pieces[i]=t
    end
    local function layout()
        local width,height = parent:GetWidth(),parent:GetHeight()
        local cap = compactCap and math.min(height*.58,width*.19)
            or math.min(height*.83,width*.25)
        pieces[1]:ClearAllPoints(); pieces[1]:SetPoint("TOPLEFT",parent,"TOPLEFT",0,0)
        pieces[1]:SetSize(cap,height)
        pieces[3]:ClearAllPoints(); pieces[3]:SetPoint("TOPRIGHT",parent,"TOPRIGHT",0,0)
        pieces[3]:SetSize(cap,height)
        pieces[2]:ClearAllPoints(); pieces[2]:SetPoint("TOPLEFT",pieces[1],"TOPRIGHT",0,0)
        pieces[2]:SetPoint("BOTTOMRIGHT",pieces[3],"BOTTOMLEFT",0,0)
    end
    layout()
    parent:HookScript("OnSizeChanged",layout)
    return pieces
end

local function slicedFrame(parent,file)
    local xUV={{0,.11},{.11,.89},{.89,1}}
    local yUV={{0,.20},{.20,.80},{.80,1}}
    local pieces={}
    for row=1,3 do
        for col=1,3 do
            if row~=2 or col~=2 then
                local t=texture(parent,"BORDER",file,.78)
                t:SetTexCoord(xUV[col][1],xUV[col][2],yUV[row][1],yUV[row][2])
                pieces[#pieces+1]={texture=t,row=row,col=col}
            end
        end
    end
    local function layout()
        local w,h=parent:GetWidth(),parent:GetHeight()
        local cap=math.min(42,w*.22,h*.35)
        for _,piece in ipairs(pieces) do
            local col,row=piece.col,piece.row
            local x=col==1 and 0 or (col==2 and cap or w-cap)
            local y=row==1 and 0 or (row==2 and cap or h-cap)
            local pw=col==2 and w-cap*2 or cap
            local ph=row==2 and h-cap*2 or cap
            local t=piece.texture
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y)
            t:SetSize(pw,ph)
        end
    end
    layout()
    parent:HookScript("OnSizeChanged",layout)
    return pieces
end

local function motionEnabled()
    return not NS.db or NS.db.motionReduced ~= true
end

local function pageTransitionsEnabled()
    return motionEnabled() and (not NS.db or NS.db.cfgAnimTransitions ~= false)
end

local function styleMini(button)
    local c=Comic.colors
    button._comicMini=true
    button:SetBackdropColor(unpack(c.rail))
    button:SetBackdropBorderColor(unpack(c.border))
    local glow=texture(button,"ARTWORK",WHITE,0)
    glow:SetAllPoints(button)
    glow:SetColorTexture(c.cyan[1],c.cyan[2],c.cyan[3],.12)
    local pip=texture(button,"ARTWORK",WHITE,0)
    pip:SetSize(10,2)
    pip:SetColorTexture(unpack(c.cyan))
    pip:SetAlpha(0)
    local value,target=0,0
    local position,positionTarget=0,0
    local function placePip()
        pip:ClearAllPoints()
        pip:SetPoint("TOPLEFT",button,"TOPLEFT",
            4+(button:GetWidth()-18)*position,-2)
    end
    placePip()
    local function tick(self,dt)
        local step=math.min(1,(dt or 0)*(motionEnabled() and 14 or 100))
        value=value+(target-value)*step
        position=position+(positionTarget-position)*step
        if math.abs(value-target)<.006 then value=target end
        if math.abs(position-positionTarget)<.006 then position=positionTarget end
        glow:SetAlpha(value)
        placePip()
        if value==target and position==positionTarget then self:SetScript("OnUpdate",nil) end
    end
    button:HookScript("OnEnter",function(self)
        target=1
        self:SetBackdropBorderColor(unpack(c.gold))
        self:SetScript("OnUpdate",tick)
        if not motionEnabled() then tick(self,1) end
    end)
    button:HookScript("OnLeave",function(self)
        target=0
        local border=self._comicOn and c.cyan or c.border
        self:SetBackdropBorderColor(unpack(border))
        self:SetScript("OnUpdate",tick)
        if not motionEnabled() then tick(self,1) end
    end)
    button:HookScript("OnHide",function(self)
        value=0;target=0;position=positionTarget
        glow:SetAlpha(0);placePip();self:SetScript("OnUpdate",nil)
    end)
    local function releaseMini(self)
        if self._comicOn and faction=="Alliance" then
            self:SetBackdropColor(.08,.15,.30,1)
        else
            self:SetBackdropColor(unpack(c.rail))
        end
        if self._label then
            self._label:ClearAllPoints()
            self._label:SetPoint("CENTER",self,"CENTER",0,0)
        end
    end
    button:HookScript("OnMouseDown",function(self)
        self:SetBackdropColor(.015,.025,.035,1)
        if self._label then
            self._label:ClearAllPoints()
            self._label:SetPoint("CENTER",self,"CENTER",0,-1)
        end
    end)
    button:HookScript("OnMouseUp",releaseMini)
    button:HookScript("OnLeave",releaseMini)
    button:HookScript("OnHide",releaseMini)
    button._comicMiniPip=pip
    button._comicMiniSlide=function(on)
        local destination=on and 1 or 0
        if not button._comicMiniInitialized then
            position=destination;positionTarget=destination
            button._comicMiniInitialized=true
            placePip()
        elseif positionTarget~=destination then
            positionTarget=destination
            button:SetScript("OnUpdate",tick)
            if not motionEnabled() then tick(button,1) end
        end
    end
end

function Comic.SetMiniState(button,on)
    if not button._comicMini then return end
    local c=Comic.colors
    button._comicOn=on and true or false
    if faction == "Alliance" and on then
        button:SetBackdropColor(.08,.15,.30,1)
    else
        button:SetBackdropColor(unpack(c.rail))
    end
    button:SetBackdropBorderColor(unpack(on and c.cyan or c.border))
    if button._label then button._label:SetTextColor(unpack(on and c.bright or c.dim)) end
    button._comicMiniPip:SetColorTexture(unpack(on and c.cyan or c.muted))
    button._comicMiniPip:SetAlpha(1)
    button._comicMiniSlide(on)
end

local function styleButton(button, plate, hero)
    if button._comicStyled then return end
    button._comicStyled = true
    local w,h = button:GetWidth(),button:GetHeight()
    if plate and (w<88 or h<24) then
        styleMini(button)
        return
    end
    local big = w >= 120 and h >= 25
    local pieces
    if plate then
        pieces=strip(button,P.button,plate == "quiet" and .74 or .88,true)
        button._comicPlate=pieces
        button:SetBackdropColor(0,0,0,0)
        button:SetBackdropBorderColor(0,0,0,0)
    end
    local pressShade=texture(button,"BORDER",WHITE,0)
    pressShade:SetPoint("TOPLEFT",button,"TOPLEFT",5,-4)
    pressShade:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-5,4)
    pressShade:SetColorTexture(0,0,0,.3)
    local pressed=false
    local function setPressed(on)
        pressed=on and true or false
        pressShade:SetAlpha(pressed and 1 or 0)
        if pieces then
            for _,piece in ipairs(pieces) do
                piece:SetVertexColor(pressed and .57 or 1,pressed and .66 or 1,
                    pressed and .78 or 1)
            end
        end
        if button._label then
            button._label:ClearAllPoints()
            button._label:SetPoint("CENTER",button,"CENTER",0,pressed and -1 or 0)
        end
    end
    button:HookScript("OnMouseDown",function() setPressed(true) end)
    button:HookScript("OnMouseUp",function() setPressed(false) end)
    button:HookScript("OnLeave",function() setPressed(false) end)
    button:HookScript("OnHide",function() setPressed(false) end)
    if not big then
        button._comic={pressShade=pressShade}
        if pieces then
            local value,target=plate == "quiet" and .74 or .88,plate == "quiet" and .74 or .88
            local function tick(self,dt)
                value=value+(target-value)*math.min(1,(dt or 0)*(motionEnabled() and 12 or 100))
                if math.abs(value-target)<.006 then value=target end
                for _,piece in ipairs(pieces) do piece:SetAlpha(value) end
                if value==target then self:SetScript("OnUpdate",nil) end
            end
            button:HookScript("OnEnter",function(self)
                target=1;self:SetScript("OnUpdate",tick)
                if not motionEnabled() then tick(self,1) end
            end)
            button:HookScript("OnLeave",function(self)
                target=plate == "quiet" and .74 or .88;self:SetScript("OnUpdate",tick)
                if not motionEnabled() then tick(self,1) end
            end)
            button:HookScript("OnHide",function(self) self:SetScript("OnUpdate",nil) end)
        end
        return
    end
    local ring
    if hero then
        ring = texture(button,"ARTWORK",P.ring,0)
        ring:SetSize(math.min(h*1.6,65),math.min(h*1.6,65))
        ring:SetPoint("CENTER",button,"LEFT",math.min(h*.6,25),0)
    end
    local glint = texture(button,"ARTWORK",P.glint,0)
    glint:SetSize(math.min(h*.58,23),h*.9)
    glint:SetPoint("CENTER",button,"LEFT",h,0)
    local state = {target=0,hover=0,phase=0}
    local function tick(_,dt)
        dt=math.min(dt or 0,.05)
        local speed=motionEnabled() and 10 or 100
        state.hover=state.hover+(state.target-state.hover)*math.min(1,dt*speed)
        if math.abs(state.hover-state.target)<.006 then state.hover=state.target end
        if pieces and not pressed then
            local alpha=(plate == "quiet" and .74 or .88)+state.hover*.12
            for _,piece in ipairs(pieces) do piece:SetAlpha(alpha) end
        end
        if ring then ring:SetAlpha(state.hover*.7) end
        if state.hover>0 then
            state.phase=state.phase+dt
            if motionEnabled() then
                if ring then ring:SetRotation(state.phase*.9) end
                glint:SetAlpha(state.hover*math.max(0,1-math.abs((state.phase%1.55)-.6)*1.7)*.72)
                glint:ClearAllPoints()
                glint:SetPoint("CENTER",button,"LEFT",h+((button:GetWidth()-h*2)*(state.phase%1.55)/1.55),0)
            else
                glint:SetAlpha(0)
            end
        else
            glint:SetAlpha(0)
            button:SetScript("OnUpdate",nil)
        end
    end
    button:HookScript("OnEnter",function()
        state.target=1
        if not motionEnabled() then tick(button,1) else button:SetScript("OnUpdate",tick) end
    end)
    button:HookScript("OnLeave",function()
        state.target=0
        if not motionEnabled() then tick(button,1) else button:SetScript("OnUpdate",tick) end
    end)
    button:HookScript("OnHide",function()
        state.target=0;state.hover=0
        setPressed(false)
        if ring then ring:SetAlpha(0) end;glint:SetAlpha(0)
        button:SetScript("OnUpdate",nil)
    end)
    button._comic={pressShade=pressShade,ring=ring,glint=glint,state=state}
end

function Comic.StyleAction(button,tone)
    styleButton(button,tone or "normal",false)
end
function Comic.StyleHeroAction(button)
    styleButton(button,"hero",true)
end

function Comic.StyleCaption(tab)
    strip(tab,P.caption,1)
    tab:SetBackdropColor(0,0,0,0)
    tab:SetBackdropBorderColor(0,0,0,0)
end

function Comic.StyleToggle(track)
    styleMini(track)
    track._comicToggle=true
end

function Comic.StyleChip(chip,forcePlate)
    if chip:GetWidth()<80 and not forcePlate then
        styleMini(chip)
        return function(active) Comic.SetMiniState(chip,active) end
    end
    local pieces=strip(chip,P.button,.6,true)
    local state={value=.48,target=.48,hover=false}
    local function tick(self,dt)
        local speed=motionEnabled() and 13 or 100
        state.value=state.value+(state.target-state.value)*math.min(1,(dt or 0)*speed)
        if math.abs(state.value-state.target)<.006 then state.value=state.target end
        for _,piece in ipairs(pieces) do piece:SetAlpha(state.value) end
        if state.value==state.target then self:SetScript("OnUpdate",nil) end
    end
    local function paint(self,active,hover)
        state.hover=hover
        state.target=active and .95 or (hover and .78 or .48)
        if motionEnabled() then self:SetScript("OnUpdate",tick) else tick(self,1) end
    end
    chip:HookScript("OnEnter",function(self) paint(self,self._active,true) end)
    chip:HookScript("OnLeave",function(self) paint(self,self._active,false) end)
    chip:HookScript("OnHide",function(self) self:SetScript("OnUpdate",nil) end)
    for _,piece in ipairs(pieces) do piece:SetAlpha(state.value) end
    return function(active) paint(chip,active,state.hover) end
end

function Comic.SetToggleState(track,on)
    if not track._comicToggle then return end
    Comic.SetMiniState(track,on)
end

function Comic.StyleSurface(frame)
    if frame:GetWidth()<100 or frame:GetHeight()<60 then return end
    -- Let the illustrated page remain visible through the section fill.
    local c=Comic.colors
    frame:SetBackdropColor(c.card[1],c.card[2],c.card[3],.58)
    Comic.DecoratePaper(frame,.24)
    frame._comicFrame=slicedFrame(frame,P.cardFrame)
    frame:SetBackdropBorderColor(0,0,0,0)
end

function Comic.DecorateHeader(header)
    Comic.DecoratePaper(header,.4)
    if faction=="Alliance" then
        local city=texture(header,"ARTWORK",path("AllianceCity"),.58)
        city:SetSize(490,72)
        city:SetPoint("CENTER",header,"CENTER",45,0)
        header._comicCity=city
    end
end

function Comic.DecorateShell(shell)
    local c=Comic.colors
    ink(shell,"TOPLEFT","TOPLEFT",0,0,70,3,c.gold)
    ink(shell,"TOPRIGHT","TOPRIGHT",0,0,70,3,c.gold)
    ink(shell,"BOTTOMLEFT","BOTTOMLEFT",0,0,36,3,c.gold)
    ink(shell,"BOTTOMRIGHT","BOTTOMRIGHT",0,0,36,3,c.gold)
    ink(shell,"TOPLEFT","TOPLEFT",0,0,3,38,c.gold)
    ink(shell,"TOPRIGHT","TOPRIGHT",0,0,3,38,c.gold)
    ink(shell,"BOTTOMLEFT","BOTTOMLEFT",0,0,3,29,c.gold)
    ink(shell,"BOTTOMRIGHT","BOTTOMRIGHT",0,0,3,29,c.gold)
end

function Comic.FinishShell(shell)
    local c=Comic.colors
    local border=NS.CreateFrame("Frame",nil,shell)
    border:SetAllPoints(shell)
    border:SetFrameLevel(shell:GetFrameLevel()+50)
    border:EnableMouse(false)
    local function line(pointA,pointB,xA,yA,xB,yB,width,height)
        local edge=texture(border,"ARTWORK",WHITE,.85)
        edge:SetVertexColor(unpack(c.gold))
        edge:SetPoint(pointA,border,pointA,xA,yA)
        edge:SetPoint(pointB,border,pointB,xB,yB)
        if width then edge:SetWidth(width) else edge:SetHeight(height) end
    end
    line("TOPLEFT","TOPRIGHT",0,0,0,0,nil,2)
    line("BOTTOMLEFT","BOTTOMRIGHT",0,0,0,0,nil,2)
    line("TOPLEFT","BOTTOMLEFT",0,0,0,0,2,nil)
    line("TOPRIGHT","BOTTOMRIGHT",0,0,0,0,2,nil)
    shell._comicOuterBorder=border
end

function Comic.DecorateRail(rail)
    Comic.DecoratePaper(rail,.7)
    local mark=texture(rail,"BACKGROUND",path(faction .. "SidebarMark"),faction=="Horde" and .52 or .63,2)
    mark:SetSize(188,188)
    mark:SetPoint("BOTTOM",rail,"BOTTOM",0,42)
    rail._comicMark=mark
end

function Comic.DecorateTalentPage(view)
    local hero=texture(view,"ARTWORK",path(faction .. "TalentHero"),.96)
    hero:SetSize(305,78)
    hero:SetPoint("TOPRIGHT",view,"TOPRIGHT",-14,-3)
    view._comicHero=hero
end

function Comic.StyleNav(button)
    local plate=strip(button,P.button,0,true)
    button._bg:SetAlpha(0)
    button._comicNavPlate=plate
    local state={value=0,target=0,phase=0,pressed=false}
    local function tick(self,dt)
        local speed=motionEnabled() and 11 or 100
        state.value=state.value+(state.target-state.value)*math.min(1,(dt or 0)*speed)
        if math.abs(state.value-state.target)<.006 then state.value=state.target end
        if button._comicActive and motionEnabled() then
            state.phase=state.phase+(dt or 0)
            for _,piece in ipairs(plate) do piece:SetAlpha(state.value*(.84+.05*math.sin(state.phase*3.2))) end
        else
            for _,piece in ipairs(plate) do piece:SetAlpha(state.value*.87) end
        end
        if state.value==state.target and not button._comicActive then self:SetScript("OnUpdate",nil) end
    end
    button._comicNavState=state
    button:HookScript("OnEnter",function()
        if not button._comicActive then state.target=.62 end
        button:SetScript("OnUpdate",tick)
    end)
    button:HookScript("OnLeave",function()
        if not button._comicActive then state.target=0 end
        state.pressed=false
        for _,piece in ipairs(plate) do piece:SetVertexColor(1,1,1) end
        button:SetScript("OnUpdate",tick)
    end)
    button:HookScript("OnMouseDown",function()
        state.pressed=true
        for _,piece in ipairs(plate) do piece:SetVertexColor(.55,.67,.82) end
    end)
    button:HookScript("OnMouseUp",function()
        state.pressed=false
        for _,piece in ipairs(plate) do piece:SetVertexColor(1,1,1) end
    end)
    button:HookScript("OnHide",function()
        button:SetScript("OnUpdate",nil)
        state.pressed=false
        for _,piece in ipairs(plate) do piece:SetVertexColor(1,1,1) end
    end)
    button._comicNavTick=tick
end

function Comic.SetNavActive(button,active)
    button._comicActive=active
    local state=button._comicNavState
    if state then
        state.target=active and 1 or 0
        button:SetScript("OnUpdate",button._comicNavTick)
        if not motionEnabled() then button._comicNavTick(button,1) end
    end
end

function Comic.FadePage(view)
    if not pageTransitionsEnabled() then view:SetAlpha(1);return end
    view:SetAlpha(.35)
    local alpha=.35
    view:SetScript("OnUpdate",function(self,dt)
        alpha=math.min(1,alpha+(dt or 0)*4.8)
        self:SetAlpha(alpha)
        if alpha>=1 then self:SetScript("OnUpdate",nil) end
    end)
end

function Comic.ResetPage(view)
    view:SetScript("OnUpdate",nil)
    view:SetAlpha(1)
end

function Comic.StyleInput(input)
    local c=Comic.colors
    input:SetBackdropColor(unpack(c.rail))
    input:SetBackdropBorderColor(unpack(c.gold))
end

function Comic.DecorateGroup(parent,y)
    local bar=texture(parent,"BACKGROUND",P.caption,.52)
    bar:SetSize(230,22)
    bar:SetPoint("TOPLEFT",parent,"TOPLEFT",0,y+1)
    return bar
end

function Comic.DecorateDialog(card,width)
    local c=Comic.colors
    card:SetBackdropColor(c.card[1],c.card[2],c.card[3],.94)
    local banner=texture(card,"BACKGROUND",P.caption,.94,2)
    banner:SetSize(math.min(width or 240,card:GetWidth()-20),29)
    banner:SetPoint("TOPLEFT",card,"TOPLEFT",8,-6)
    card._comicBanner=banner
end
