local _, NS = ...
local Simple = NS.ConfigSimple
local UI = Simple.UI

local function ParticleKey()
    local animation = NS.db.castAnimation or "POP!"
    local prefix = NS.AnimKeyPrefix and NS.AnimKeyPrefix(animation)
        or animation:gsub("[^%a]", ""):lower()
    if prefix == "" or prefix == "none" then prefix = "pop" end
    return prefix, animation
end

local function CanPreview()
    return NS.db.enabled and NS.mainButton and NS.mainButton:IsShown()
end

local function ExplainMacro()
    local lines = { "Each press follows these steps when the game allows them.",
        "The button still needs your key press; this is a preview of its instructions.", "" }
    for index, action in ipairs(NS.GetMacroActions and NS.GetMacroActions() or {}) do
        lines[#lines + 1] = index .. ". " .. (action.hint or "Button action")
        lines[#lines + 1] = action.text or ""
        lines[#lines + 1] = ""
    end
    if #lines == 3 then lines[#lines + 1] = "No button actions are available yet." end
    return table.concat(lines, "\n")
end

function Simple:ChooseResetGroup()
    local groups = NS.GetConfigResetGroups and NS.GetConfigResetGroups() or {}
    if #groups == 0 then self:Report(false, "Reset options are unavailable."); return end
    self:OpenChoices("Reset a Settings Group", groups, nil, function(name)
        local keys = table.concat(NS.GetConfigResetKeys(name) or {}, "\n")
        self:Confirm("Reset " .. name .. " to its defaults? Only this group's settings will change.", function()
            if keys ~= table.concat(NS.GetConfigResetKeys(name) or {}, "\n") then
                self:Report(false, "Your specialization changed. Choose the reset group again."); return
            end
            local ok, message = NS.ResetConfigGroup(name)
            self:Report(ok, message)
        end)
    end)
end

function Simple:OpenTools(topic)
    if not self.frame then self:Create() end
    topic = topic == "Motion" and "Motion" or "Advanced"
    local name = topic == "Motion" and "tools-motion" or "tools-advanced"
    local previous = self.view
    if not self.views[name] then
        local view = self:CreateView(name)
        view._actions = {}
        UI.Label(view, topic == "Motion" and "Try Your Effects" or "Help & Tools", 0, 0, 600, 20)
        local hint = UI.Label(view, "", 0, -36, 600, 13, "muted", 2)
        local function Action(id, label, y, callback)
            local button = UI.Button(view, label, 0, y, 280, callback)
            view._actions[id] = button
            return button
        end
        local function Refresh() end
        if topic == "Motion" then
            local preview = Action("preview", "Preview Feedback", -88, function()
                if not CanPreview() or NS.db.castFeedback == "Off" then
                    self:Report(false, "Show the button and turn on feedback first."); return
                end
                if NS.db.castFeedback == "Motion" and NS.PreviewMotionFeedback then
                    NS.PreviewMotionFeedback()
                elseif NS.db.castFeedback == "Classic" and NS.db.castAnimation ~= "NONE" and NS.PlayCastAnimation then
                    NS.PlayCastAnimation(NS.mainButton.spellID or NS.SBA_SPELL_ID)
                else
                    self:Report(false, "Choose an animation before previewing."); return
                end
                self:Report(true, "Feedback preview requested on your live button.")
            end)
            local particles = Action("particles", "Preview Particles", -132, function()
                local prefix = ParticleKey()
                local style = NS.db[prefix .. "ParticleStyle"] or "Confetti"
                if not CanPreview() or not NS.FireParticleBurst or style == "None" then
                    self:Report(false, "Show the button and choose a particle style first."); return
                end
                NS.FireParticleBurst(NS.mainButton, style, NS.db[prefix .. "ParticlePalette"] or "Confetti")
                self:Report(true, "Particle preview requested on your live button.")
            end)
            local function Palette(create)
                local prefix = ParticleKey()
                if NS.ShowPaletteEditor then
                    NS.ShowPaletteEditor(view, prefix .. "ParticlePalette", function() self:Refresh() end, create)
                end
            end
            local create = Action("createPalette", "Create a Color Palette", -176, function() Palette(true) end)
            local edit = Action("editPalette", "Edit This Color Palette", -220, function() Palette(false) end)
            Action("reset", "Reset a Settings Group", -264, function() self:ChooseResetGroup() end)
            Refresh = function()
                local prefix, animation = ParticleKey()
                hint:SetText("Feedback: " .. (NS.db.castFeedback or "Off") .. ". Animation: " .. animation
                    .. ". Previews use your saved settings; choose them in the effect settings.")
                UI.SetEnabled(preview, CanPreview() and ((NS.db.castFeedback == "Motion" and NS.PreviewMotionFeedback ~= nil)
                    or (NS.db.castFeedback == "Classic" and animation ~= "NONE" and NS.PlayCastAnimation ~= nil)) or false)
                UI.SetEnabled(particles, CanPreview() and NS.FireParticleBurst ~= nil
                    and NS.db[prefix .. "ParticleStyle"] ~= "None" or false)
                UI.SetEnabled(create, NS.ShowPaletteEditor ~= nil)
                UI.SetEnabled(edit, NS.ShowPaletteEditor ~= nil)
            end
        else
            hint:SetText("Open one tool at a time. Reports stay here unless you choose to copy them.")
            Action("macro", "How the Button Works", -88, function()
                self:ShowText("How the Button Works", ExplainMacro())
            end)
            local diagnostic = Action("diagnostic", "Performance & Diagnostic Report", -132, function()
                if NS.BuildConfigDiagnosticReport then
                    self:ShowText("Performance & Diagnostics", "Snapshot taken when opened. Character and profile names are omitted.\n\n"
                        .. NS.BuildConfigDiagnosticReport(false))
                end
            end)
            Action("reset", "Reset a Settings Group", -176, function() self:ChooseResetGroup() end)
            Refresh = function() UI.SetEnabled(diagnostic, NS.BuildConfigDiagnosticReport ~= nil) end
        end
        view._back = UI.Button(view, "Back", 0, -350, 100, function()
            self:SelectView(view._toolsReturn or "main")
        end)
        self:RegisterView(name, view, Refresh)
    end
    if previous ~= name then self.views[name]._toolsReturn = previous or "main" end
    self:SelectView(name)
end
