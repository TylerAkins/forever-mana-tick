local addonName = ...
local MANA = 0
local ENERGY = 3
local TICK_SECONDS = 2
local FSR_SECONDS = 5
local frame = CreateFrame("Frame")
local bar, fsrSpark, regenSpark, gainText
local previousPower, lastSpend, tickStart, textStart
local channelMana, visibilityCurve
local lastGainTime

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

local function ClearTracking()
    previousPower, lastSpend, textStart = nil, nil, nil
    channelMana = nil
    lastGainTime = nil
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
        texture:SetSize(16, 32)
        texture:Hide()
        return texture
    end
    fsrSpark, regenSpark = Spark(), Spark()
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
            local current = ReadPower(resource)
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
                    -- Power events do not identify potions, heals, or natural regeneration.
                    -- Continuous power updates must not restart the sweep every frame.
                    if not lastGainTime or now - lastGainTime >= 1.4 then tickStart = now end
                    lastGainTime = now
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
