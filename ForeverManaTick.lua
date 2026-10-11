local addonName = ...
local MANA = 0
local TICK_SECONDS = 2
local FSR_SECONDS = 5
local frame = CreateFrame("Frame")
local bar, fsrSpark, regenSpark, gainText
local previousMana, lastSpend, tickStart, textStart

local function Reset()
    previousMana = UnitPower("player", MANA)
    lastSpend, tickStart, textStart = nil, GetTime(), nil
    if gainText then gainText:Hide() end
end

local function CreateDisplay()
    bar = PlayerFrameManaBar
    if not bar then return false end
    frame:SetParent(bar)
    frame:SetAllPoints(bar)
    frame:SetFrameLevel(bar:GetFrameLevel() + 1)
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
    if UnitPowerType("player") ~= MANA or UnitPowerMax("player", MANA) <= 0 then
        fsrSpark:Hide()
        regenSpark:Hide()
        gainText:Hide()
        return
    end
    local elapsed = lastSpend and now - lastSpend
    if elapsed and elapsed < FSR_SECONDS then
        fsrSpark:ClearAllPoints()
        fsrSpark:SetPoint("CENTER", bar, "LEFT", bar:GetWidth() * (1 - elapsed / FSR_SECONDS), 0)
        fsrSpark:Show()
        regenSpark:Hide()
    else
        fsrSpark:Hide()
        if previousMana < UnitPowerMax("player", MANA) then
            local progress = ((now - tickStart) % TICK_SECONDS) / TICK_SECONDS
            regenSpark:ClearAllPoints()
            regenSpark:SetPoint("CENTER", bar, "LEFT", bar:GetWidth() * progress, 0)
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
frame:SetScript("OnEvent", function(self, event, unit, powerType)
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
        self:SetScript("OnUpdate", UpdateDisplay)
    elseif unit == "player" then
        if event == "UNIT_DISPLAYPOWER" or event == "UNIT_MAXPOWER" then
            Reset()
        elseif powerType == "MANA" then
            local mana = UnitPower("player", MANA)
            local delta = mana - previousMana
            previousMana = mana
            if delta ~= 0 and UnitPowerType("player") == MANA then
                local now = GetTime()
                if delta < 0 then
                    lastSpend = now
                else
                    -- Power events do not identify potions, heals, or natural regeneration.
                    tickStart = now
                end
                gainText:SetText((delta > 0 and "+" or "") .. delta)
                if delta > 0 then
                    gainText:SetTextColor(0.4, 0.8, 1)
                else
                    gainText:SetTextColor(0.6, 0.2, 1)
                end
                textStart = now
            end
        end
    end
end)
