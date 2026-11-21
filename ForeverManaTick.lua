local addonName = ...
local MANA = 0
local RAGE = 1
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
local personalBar, personalFsrSpark, personalRegenSpark
local alternateBar, alternateFsrSpark, alternateRegenSpark
local leatrixBars = {}
local alternatePrevious, alternateSpend, alternateTick, alternateGainTime, alternateChannel
local trackedResource
local previousPower, lastSpend, tickStart, textStart
local channelMana, visibilityCurve
local lastManaGainTime
local sparkScale = 1
local applyingSettings

local function Readable(value)
    return not issecretvalue or not issecretvalue(value)
end

local function IsRegionShown(region)
    if not region or not region.IsShown then return false end
    -- Forbidden frames throw on method calls, so a failed check counts as hidden.
    local ok, shown = pcall(region.IsShown, region)
    if not ok or not Readable(shown) then return false end
    return shown == true
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

local function IsAlternateResource(resource)
    return resource == ENERGY or (resource == RAGE and #leatrixBars > 0)
end

local function HasAlternateBar()
    return alternateBar ~= nil or #leatrixBars > 0
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
    if personalBar then
        height = personalBar:GetHeight() * SPARK_BASE_SCALE * sparkScale
        personalFsrSpark:SetSize(height / 2, height)
        personalRegenSpark:SetSize(height / 2, height)
    end
    if alternateBar then
        height = alternateBar:GetHeight() * SPARK_BASE_SCALE * sparkScale
        alternateFsrSpark:SetSize(height / 2, height)
        alternateRegenSpark:SetSize(height / 2, height)
    end
    for _, display in ipairs(leatrixBars) do
        height = bar:GetHeight() * SPARK_BASE_SCALE * sparkScale
        display.fsrSpark:SetSize(height / 2, height)
        display.regenSpark:SetSize(height / 2, height)
    end
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
    alternatePrevious, alternateSpend, alternateTick, alternateGainTime, alternateChannel = nil, nil, nil, nil, nil
    if alternateBar then
        alternateFsrSpark:Hide()
        alternateRegenSpark:Hide()
    end
    for _, display in ipairs(leatrixBars) do
        display.fsrSpark:Hide()
        display.regenSpark:Hide()
    end
    if gainText then
        fsrSpark:Hide()
        regenSpark:Hide()
        gainText:Hide()
        if personalBar then
            personalFsrSpark:Hide()
            personalRegenSpark:Hide()
        end
    end
end

local function Reset()
    local resource = UnitPowerType("player")
    local alternateActive = Readable(resource) and IsAlternateResource(resource) and HasAlternateBar()
    local previousAlternate = trackedResource and IsAlternateResource(trackedResource)
    local manaSpend, manaTick, manaGain
    if alternateActive and previousAlternate and trackedResource ~= resource then
        manaSpend, manaTick, manaGain = alternateSpend, alternateTick, alternateGainTime
    elseif alternateActive and trackedResource == MANA then
        manaSpend, manaTick, manaGain = lastSpend, tickStart, lastManaGainTime
    elseif Readable(resource) and resource == MANA and previousAlternate then
        manaSpend, manaTick, manaGain = alternateSpend, alternateTick, alternateGainTime
    end
    ClearTracking()
    trackedResource = Readable(resource) and resource or nil
    if alternateActive then
        alternatePrevious = ReadPower(MANA)
        alternateSpend, alternateTick, alternateGainTime = manaSpend, manaTick or GetTime(), manaGain
    elseif trackedResource == MANA and manaTick then
        lastSpend, tickStart, lastManaGainTime = manaSpend, manaTick, manaGain
    end
    if trackedResource == MANA or trackedResource == ENERGY then
        previousPower = ReadPower(trackedResource)
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

local function CreatePersonalDisplay()
    if InCombatLockdown and InCombatLockdown() then return end
    local display = PersonalResourceDisplayFrame
    if not display then return end
    local function CreateSparks(powerBar)
        local overlay = CreateFrame("Frame", nil, powerBar)
        overlay:SetAllPoints(powerBar)
        overlay:SetFrameLevel(powerBar:GetFrameLevel() + 1)
        local function Spark()
            local texture = overlay:CreateTexture(nil, "OVERLAY")
            texture:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
            texture:SetBlendMode("ADD")
            texture:Hide()
            return texture
        end
        return Spark(), Spark()
    end
    if not personalBar and display.PowerBar then
        personalBar = display.PowerBar
        personalFsrSpark, personalRegenSpark = CreateSparks(personalBar)
    end
    local _, class = UnitClass("player")
    if class == "DRUID" and not alternateBar and display.AlternatePowerBar then
        alternateBar = display.AlternatePowerBar
        alternateFsrSpark, alternateRegenSpark = CreateSparks(alternateBar)
        alternatePrevious = ReadPower(MANA)
        alternateTick = GetTime()
    end
    UpdateSparkSize()
end

local function IsPlayerManaBar(candidate)
    local unit = candidate.unit
    if not Readable(unit) then return false end
    if unit == nil then return true end
    if type(unit) ~= "string" then return false end
    return unit == "player"
end

local function InspectManaBar(candidate)
    if not candidate.GetStatusBarTexture or not IsPlayerManaBar(candidate) then
        return false
    end
    local texture = candidate:GetStatusBarTexture()
    local path = texture and texture.GetTexture and texture:GetTexture()
    if Readable(path) and type(path) == "string"
        and path:lower():find("player-portraiton-bar-mana", 1, true) then
        return true
    end
    local atlas = texture and texture.GetAtlas and texture:GetAtlas()
    if Readable(atlas) and type(atlas) == "string"
        and atlas:lower():find("player-portraiton-bar-mana", 1, true) then
        return true
    end
    local mask, text, left, right = candidate.Mask, candidate.TextString, candidate.LeftText, candidate.RightText
    if not (Readable(mask) and Readable(text) and Readable(left) and Readable(right)) then return false end
    return mask and text and left and right and not candidate.unit
end

local function MatchesLeatrixManaBar(candidate)
    if candidate == bar then return false end
    -- A forbidden frame throws when inspected, so treat any failure as no match.
    local ok, matches = pcall(InspectManaBar, candidate)
    return ok and matches == true
end

local function CollectManaBars(frameToWalk, found, seen)
    for _, child in ipairs({frameToWalk:GetChildren()}) do
        if not seen[child] then
            seen[child] = true
            if MatchesLeatrixManaBar(child) then found[#found + 1] = child end
            if child.GetChildren then CollectManaBars(child, found, seen) end
        end
    end
end

local function FindPlayerManaBars(includeShownGlobal)
    local _, class = UnitClass("player")
    if class ~= "DRUID" then return {} end
    local found, seen = {}, {}
    if PlayerFrame and PlayerFrame.GetChildren then
        CollectManaBars(PlayerFrame, found, seen)
    end
    if includeShownGlobal and EnumerateFrames then
        local candidate = EnumerateFrames()
        while candidate do
            if not seen[candidate] and IsRegionShown(candidate)
                and MatchesLeatrixManaBar(candidate) then
                found[#found + 1] = candidate
                seen[candidate] = true
            end
            candidate = EnumerateFrames(candidate)
        end
    end
    return found
end

local function CreateLeatrixDisplays()
    if InCombatLockdown and InCombatLockdown() then return end
    local anyShown = false
    for _, display in ipairs(leatrixBars) do
        if IsRegionShown(display.bar) then
            anyShown = true
            break
        end
    end
    local resource = UnitPowerType("player")
    local alternateForm = Readable(resource) and (resource == ENERGY or resource == RAGE)
    for _, target in ipairs(FindPlayerManaBars(alternateForm and not anyShown)) do
        local known = false
        for _, display in ipairs(leatrixBars) do
            if display.bar == target then
                known = true
                break
            end
        end
        if not known then
            local width = target.GetWidth and target:GetWidth()
            if not Readable(width) or type(width) ~= "number" then width = bar:GetWidth() end
            local overlay = CreateFrame("Frame", nil, target)
            overlay:SetAllPoints(target)
            overlay:SetFrameLevel(bar:GetFrameLevel() + 2)
            local function Spark()
                local texture = overlay:CreateTexture(nil, "OVERLAY")
                texture:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
                texture:SetBlendMode("ADD")
                texture:Hide()
                return texture
            end
            leatrixBars[#leatrixBars + 1] = {
                bar = target,
                width = width,
                overlay = overlay,
                fsrSpark = Spark(),
                regenSpark = Spark(),
            }
        end
    end
    if not alternatePrevious then alternatePrevious = ReadPower(MANA) end
    if not alternateTick then alternateTick = GetTime() end
    UpdateSparkSize()
end

local function CreateCompatibleDisplays()
    CreatePersonalDisplay()
    CreateLeatrixDisplays()
end

local function RenderAlternateSparks(targetBar, width, fsrSparkToDraw, regenSparkToDraw, fsrProgress, regenProgress, regenAlpha)
    if not targetBar then return end
    if fsrProgress then
        fsrSparkToDraw:ClearAllPoints()
        fsrSparkToDraw:SetPoint("CENTER", targetBar, "LEFT", width * fsrProgress, 0)
        fsrSparkToDraw:Show()
    else
        fsrSparkToDraw:Hide()
    end
    if regenProgress then
        regenSparkToDraw:ClearAllPoints()
        regenSparkToDraw:SetPoint("CENTER", targetBar, "LEFT", width * regenProgress, 0)
        regenSparkToDraw:SetAlpha(regenAlpha)
        regenSparkToDraw:Show()
    else
        regenSparkToDraw:Hide()
    end
end

local function UpdateAlternateDisplay(now, resource)
    if not HasAlternateBar() then return end
    local fsrProgress, regenProgress, regenAlpha
    if IsAlternateResource(resource) then
        local current, maximum = ReadPower(MANA)
        if not current then alternatePrevious = nil end
        if current and not alternatePrevious then alternatePrevious = current end
        if alternateChannel then alternateSpend = now end
        local elapsed = alternateSpend and now - alternateSpend
        if elapsed and elapsed < FSR_SECONDS then
            fsrProgress = 1 - elapsed / FSR_SECONDS
        elseif (current and maximum > 0 and current < maximum) or (not current and visibilityCurve) then
            regenProgress = ((now - (alternateTick or now)) % TICK_SECONDS) / TICK_SECONDS
            if visibilityCurve then
                regenAlpha = UnitPowerPercent("player", MANA, false, visibilityCurve)
            else
                regenAlpha = 1
            end
        end
    end
    if alternateBar then
        RenderAlternateSparks(alternateBar, alternateBar:GetWidth(), alternateFsrSpark, alternateRegenSpark,
            fsrProgress, regenProgress, regenAlpha)
    end
    for _, display in ipairs(leatrixBars) do
        RenderAlternateSparks(display.bar, display.width, display.fsrSpark, display.regenSpark,
            fsrProgress, regenProgress, regenAlpha)
    end
end

local function UpdatePersonalDisplay(fsrProgress, regenProgress, alpha)
    if not personalBar then return end
    if fsrProgress then
        personalFsrSpark:ClearAllPoints()
        personalFsrSpark:SetPoint("CENTER", personalBar, "LEFT", personalBar:GetWidth() * fsrProgress, 0)
        personalFsrSpark:Show()
    else
        personalFsrSpark:Hide()
    end
    if regenProgress then
        personalRegenSpark:ClearAllPoints()
        personalRegenSpark:SetPoint("CENTER", personalBar, "LEFT", personalBar:GetWidth() * regenProgress, 0)
        personalRegenSpark:SetAlpha(alpha)
        personalRegenSpark:Show()
    else
        personalRegenSpark:Hide()
    end
end

local function UpdateDisplay()
    local now = GetTime()
    local resource = UnitPowerType("player")
    if not Readable(resource) then
        ClearTracking()
        return
    end
    if resource ~= MANA and resource ~= ENERGY then
        if IsAlternateResource(resource) and HasAlternateBar() then
            -- The player bar shows rage; only the addon-supplied mana bar gets indicators.
            if fsrSpark then
                fsrSpark:Hide()
                regenSpark:Hide()
                gainText:Hide()
            end
            UpdateAlternateDisplay(now, resource)
        else
            ClearTracking()
        end
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
    local fsrProgress, regenProgress, regenAlpha
    local elapsed = lastSpend and now - lastSpend
    if resource == MANA and elapsed and elapsed < FSR_SECONDS then
        fsrProgress = 1 - elapsed / FSR_SECONDS
        fsrSpark:ClearAllPoints()
        fsrSpark:SetPoint("CENTER", bar, "LEFT", bar:GetWidth() * fsrProgress, 0)
        fsrSpark:Show()
        regenSpark:Hide()
    else
        fsrSpark:Hide()
        if (current and previousPower < maximum) or (not current and visibilityCurve) then
            local progress = ((now - tickStart) % TICK_SECONDS) / TICK_SECONDS
            regenProgress = progress
            regenSpark:ClearAllPoints()
            regenSpark:SetPoint("CENTER", bar, "LEFT", bar:GetWidth() * progress, 0)
            if visibilityCurve then
                -- The native display accepts this result even when power is restricted.
                regenAlpha = UnitPowerPercent("player", resource, false, visibilityCurve)
                regenSpark:SetAlpha(regenAlpha)
            else
                regenAlpha = 1
                regenSpark:SetAlpha(regenAlpha)
            end
            regenSpark:Show()
        else
            regenSpark:Hide()
        end
    end
    UpdatePersonalDisplay(fsrProgress, regenProgress, regenAlpha)
    UpdateAlternateDisplay(now, resource)
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
        if unit ~= addonName then
            if bar then CreateCompatibleDisplays() end
            return
        end
        if type(ForeverManaTickDB) ~= "table" then ForeverManaTickDB = {} end
        sparkScale = NormalizeSparkScale(ForeverManaTickDB.sparkScale)
        ForeverManaTickDB.sparkScale = sparkScale
        CreateOptions()
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_LOGIN")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if not bar and not CreateDisplay() then return end
        CreateCompatibleDisplays()
        if #leatrixBars == 0 and C_Timer and C_Timer.After then
            C_Timer.After(1, CreateLeatrixDisplays)
        end
        Reset()
        self:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
        self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
        self:RegisterUnitEvent("UNIT_MAXPOWER", "player")
        self:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
        self:SetScript("OnUpdate", UpdateDisplay)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if bar then CreateCompatibleDisplays() end
    elseif Readable(unit) and unit == "player" then
        if event == "UNIT_DISPLAYPOWER" then
            CreateLeatrixDisplays()
            if C_Timer and C_Timer.After then C_Timer.After(0.2, CreateLeatrixDisplays) end
            Reset()
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            local resource = UnitPowerType("player")
            if Readable(resource) and ManaCost(spellID) then
                if resource == MANA then lastSpend = GetTime()
                elseif IsAlternateResource(resource) and HasAlternateBar() then alternateSpend = GetTime() end
            end
        elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
            local _, periodic = ManaCost(spellID)
            local resource = UnitPowerType("player")
            channelMana = Readable(resource) and resource == MANA and periodic or nil
            if channelMana then lastSpend = GetTime() end
            alternateChannel = Readable(resource) and IsAlternateResource(resource) and HasAlternateBar() and periodic or nil
            if alternateChannel then alternateSpend = GetTime() end
        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            if channelMana then lastSpend = GetTime() end
            if alternateChannel then alternateSpend = GetTime() end
            channelMana, alternateChannel = nil, nil
        elseif Readable(powerType) and (powerType == "MANA" or powerType == "ENERGY") then
            local resource = UnitPowerType("player")
            if not Readable(resource) then return end
            if IsAlternateResource(resource) and powerType == "MANA" and HasAlternateBar() then
                local current = ReadPower(MANA)
                if not current then
                    alternatePrevious = nil
                elseif event == "UNIT_MAXPOWER" or not alternatePrevious then
                    alternatePrevious = current
                else
                    local delta = current - alternatePrevious
                    alternatePrevious = current
                    local now = GetTime()
                    if delta < 0 then
                        alternateSpend = now
                    elseif delta > 0 then
                        if not alternateGainTime or now - alternateGainTime >= 1.4 then alternateTick = now end
                        alternateGainTime = now
                    end
                end
                return
            end
            if resource ~= MANA and resource ~= ENERGY then return end
            if (resource == MANA and powerType ~= "MANA") or (resource == ENERGY and powerType ~= "ENERGY") then return end
            local current, maximum = ReadPower(resource)
            if not current then
                previousPower, textStart = nil, nil
                gainText:Hide()
                return
            end
            if event == "UNIT_MAXPOWER" then
                previousPower, textStart = current, nil
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
