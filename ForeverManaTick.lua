local addonName = ...
local MANA = 0
local ENERGY = 3
local TICK_SECONDS = 2
local FSR_SECONDS = 5
local SPARK_SCALE_MIN = 0.5
local SPARK_SCALE_MAX = 1.5
local SPARK_SCALE_STEP = 0.05
local SPARK_BASE_SCALE = 1.5
local ADDON_TITLE = "Forever Mana Tick"
local frame = CreateFrame("Frame")
local bar, fsrSpark, regenSpark, gainText
local previousPower, lastSpend, tickStart, textStart
local channelMana, visibilityCurve
local lastManaGainTime
local sparkScale = 1
local applyingSettings

local function Readable(value)
    return not issecretvalue or not issecretvalue(value)
end

local function ManaCost(spellID)
    if not Readable(spellID) or type(spellID) ~= "number" then return false, false end
    if not C_Spell or not C_Spell.GetSpellPowerCost then return false, false end
    local costs = C_Spell.GetSpellPowerCost(spellID)
    if not Readable(costs) or type(costs) ~= "table" then return false, false end
    local fixed, periodic = false, false
    for _, cost in ipairs(costs) do
        if Readable(cost) and type(cost) == "table" and Readable(cost.type) and cost.type == MANA then
            local applicable = Readable(cost.requiredAuraID)
            if applicable and type(cost.requiredAuraID) == "number" and cost.requiredAuraID > 0 then
                applicable = Readable(cost.hasRequiredAura) and cost.hasRequiredAura == true
            end
            if applicable then
                if Readable(cost.cost) and type(cost.cost) == "number" and cost.cost > 0 then fixed = true end
                if Readable(cost.costPerSec) and type(cost.costPerSec) == "number" and cost.costPerSec > 0 then periodic = true end
            end
        end
    end
    return fixed, periodic
end

local function ReadPower(powerType)
    local current = UnitPower("player", powerType)
    local maximum = UnitPowerMax("player", powerType)
    if issecretvalue and (issecretvalue(current) or issecretvalue(maximum)) then return end
    if type(current) ~= "number" or type(maximum) ~= "number" then return end
    return current, maximum
end

local function IsEnergyTick(delta, current, maximum)
    if (delta > 18 and delta < 22) or (delta > 38 and delta < 42) then return true end
    return current == maximum and delta > 0 and delta < 42
end

local function NormalizeSparkScale(value)
    if type(value) ~= "number" or value ~= value then return 1 end
    value = math.max(SPARK_SCALE_MIN, math.min(SPARK_SCALE_MAX, value))
    value = math.floor(value / SPARK_SCALE_STEP + 0.5) * SPARK_SCALE_STEP
    return value
end

local function UpdateSparkSize()
    if not fsrSpark or not regenSpark then return end
    local height = bar:GetHeight() * SPARK_BASE_SCALE * sparkScale
    local width = height / 2
    fsrSpark:SetSize(width, height)
    regenSpark:SetSize(width, height)
end

local function SetSparkScale(value)
    sparkScale = NormalizeSparkScale(value)
    ForeverManaTickDB.sparkScale = sparkScale
    UpdateSparkSize()
end

local function CreateOptions()
    local panel = CreateFrame("Frame")
    panel.name = ADDON_TITLE

    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", 16, -16)
    label:SetText("Spark size")

    local slider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -12)
    slider:SetWidth(240)
    slider:SetMinMaxValues(SPARK_SCALE_MIN, SPARK_SCALE_MAX)
    slider:SetValueStep(SPARK_SCALE_STEP)
    slider:SetObeyStepOnDrag(true)
    if not slider.Text then
        slider.Text = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        slider.Text:SetPoint("TOP", slider, "BOTTOM", 0, -2)
    end
    if slider.Low then slider.Low:SetText("50%") end
    if slider.High then slider.High:SetText("150%") end

    local function Refresh()
        applyingSettings = true
        slider:SetValue(sparkScale)
        slider.Text:SetText(string.format("%d%%", math.floor(sparkScale * 100 + 0.5)))
        applyingSettings = false
    end

    slider:SetScript("OnValueChanged", function(_, value)
        local normalized = NormalizeSparkScale(value)
        slider.Text:SetText(string.format("%d%%", math.floor(normalized * 100 + 0.5)))
        if applyingSettings then return end
        SetSparkScale(normalized)
    end)
    panel:SetScript("OnShow", Refresh)
    Refresh()

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

local function ClearTracking()
    previousPower, lastSpend, textStart = nil, nil, nil
    channelMana = nil
    lastManaGainTime = nil
    tickStart = GetTime()
    if gainText then
        fsrSpark:Hide()
        regenSpark:Hide()
        gainText:Hide()
    end
end

local function Reset()
    ClearTracking()
    local resource = UnitPowerType("player")
    if Readable(resource) and (resource == MANA or resource == ENERGY) then
        previousPower = ReadPower(resource)
    end
end

local function CreateDisplay()
    local content = PlayerFrame and PlayerFrame.PlayerFrameContent
    local main = content and content.PlayerFrameContentMain
    local manaArea = main and main.ManaBarArea
    bar = (manaArea and manaArea.ManaBar) or PlayerFrameManaBar
    if not bar then return false end
    frame:SetParent(bar)
    frame:SetAllPoints(bar)
    frame:SetFrameLevel(bar:GetFrameLevel() + 1)
    if C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType and UnitPowerPercent then
        visibilityCurve = C_CurveUtil.CreateCurve()
        visibilityCurve:SetType(Enum.LuaCurveType.Step)
        visibilityCurve:AddPoint(0, 1)
        visibilityCurve:AddPoint(1, 0)
    end
    local function Spark()
        local texture = frame:CreateTexture(nil, "OVERLAY")
        texture:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
        texture:SetBlendMode("ADD")
        texture:Hide()
        return texture
    end
    fsrSpark, regenSpark = Spark(), Spark()
    UpdateSparkSize()
    gainText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gainText:SetPoint("LEFT", bar, "RIGHT", 5, -2)
    gainText:Hide()
    return true
end

local function UpdateDisplay()
    local now = GetTime()
    local resource = UnitPowerType("player")
    if not Readable(resource) or (resource ~= MANA and resource ~= ENERGY) then
        ClearTracking()
        return
    end
    local current, maximum = ReadPower(resource)
    if current and maximum <= 0 then
        ClearTracking()
        return
    end
    if not current then
        previousPower, textStart = nil, nil
        gainText:Hide()
    elseif not previousPower then
        previousPower = current
    end
    if resource == MANA and channelMana then lastSpend = now end
    local elapsed = lastSpend and now - lastSpend
    if resource == MANA and elapsed and elapsed < FSR_SECONDS then
        fsrSpark:ClearAllPoints()
        fsrSpark:SetPoint("CENTER", bar, "LEFT", bar:GetWidth() * (1 - elapsed / FSR_SECONDS), 0)
        fsrSpark:Show()
        regenSpark:Hide()
    else
        fsrSpark:Hide()
        if (current and previousPower < maximum) or (not current and visibilityCurve) then
            local progress = ((now - tickStart) % TICK_SECONDS) / TICK_SECONDS
            regenSpark:ClearAllPoints()
            regenSpark:SetPoint("CENTER", bar, "LEFT", bar:GetWidth() * progress, 0)
            if visibilityCurve then
                -- The native display accepts this result even when power is restricted.
                regenSpark:SetAlpha(UnitPowerPercent("player", resource, false, visibilityCurve))
            else
                regenSpark:SetAlpha(1)
            end
            regenSpark:Show()
        else
            regenSpark:Hide()
        end
    end
    if textStart then
        local age = now - textStart
        if age >= 1.5 then
            gainText:Hide()
            textStart = nil
        else
            gainText:SetAlpha(math.min(1, 1.5 - age))
            gainText:Show()
        end
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, unit, powerType, spellID)
    if event == "ADDON_LOADED" then
        if unit ~= addonName then return end
        self:UnregisterEvent("ADDON_LOADED")
        if type(ForeverManaTickDB) ~= "table" then ForeverManaTickDB = {} end
        sparkScale = NormalizeSparkScale(ForeverManaTickDB.sparkScale)
        ForeverManaTickDB.sparkScale = sparkScale
        CreateOptions()
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_LOGIN")
        return
    end
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if not bar and not CreateDisplay() then return end
        Reset()
        self:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
        self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
        self:RegisterUnitEvent("UNIT_MAXPOWER", "player")
        self:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
        self:SetScript("OnUpdate", UpdateDisplay)
    elseif Readable(unit) and unit == "player" then
        if event == "UNIT_DISPLAYPOWER" or event == "UNIT_MAXPOWER" then
            Reset()
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            local resource = UnitPowerType("player")
            if Readable(resource) and resource == MANA and ManaCost(spellID) then lastSpend = GetTime() end
        elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
            local _, periodic = ManaCost(spellID)
            local resource = UnitPowerType("player")
            channelMana = Readable(resource) and resource == MANA and periodic or nil
            if channelMana then lastSpend = GetTime() end
        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            if channelMana then lastSpend = GetTime() end
            channelMana = nil
        elseif Readable(powerType) and (powerType == "MANA" or powerType == "ENERGY") then
            local resource = UnitPowerType("player")
            if not Readable(resource) or (resource ~= MANA and resource ~= ENERGY) then return end
            if (resource == MANA and powerType ~= "MANA") or (resource == ENERGY and powerType ~= "ENERGY") then return end
            local current, maximum = ReadPower(resource)
            if not current then
                previousPower, textStart = nil, nil
                gainText:Hide()
                return
            end
            if not previousPower then
                previousPower, tickStart = current, GetTime()
                return
            end
            local delta = current - previousPower
            previousPower = current
            if delta ~= 0 then
                local now = GetTime()
                if delta < 0 then
                    if resource == MANA then lastSpend = now end
                else
                    if resource == ENERGY then
                        if IsEnergyTick(delta, current, maximum) then tickStart = now end
                    else
                        -- Mana events do not identify potions, heals, or natural regeneration.
                        -- Continuous power updates must not restart the sweep every frame.
                        if not lastManaGainTime or now - lastManaGainTime >= 1.4 then tickStart = now end
                        lastManaGainTime = now
                    end
                end
                gainText:SetText((delta > 0 and "+" or "") .. delta)
                if delta > 0 then
                    if resource == ENERGY then
                        gainText:SetTextColor(1, 0.85, 0.1)
                    else
                        gainText:SetTextColor(0.4, 0.8, 1)
                    end
                else
                    gainText:SetTextColor(0.6, 0.2, 1)
                end
                textStart = now
            end
        end
    end
end)
