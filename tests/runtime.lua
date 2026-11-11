local function Run(layout, savedScale)
local now, mana, maximum, resource = 100, 500, 1000, 0
local inCombat = false
ForeverManaTickDB = savedScale and {sparkScale = savedScale} or nil
local function RestrictedOperation() error('attempt to use restricted mana') end
local secret = setmetatable({}, {__sub = RestrictedOperation, __lt = RestrictedOperation,
    __le = RestrictedOperation, __concat = RestrictedOperation, __tostring = RestrictedOperation})
issecretvalue = layout ~= 'legacy' and function(value) return rawequal(value, secret) end or nil
local textures, texts = {}, {}
local function Region()
    return {
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        SetPoint = function(self, ...) self.point = {...} end,
        ClearAllPoints = function(self) self.point = nil end,
        SetTexture = function() end,
        SetBlendMode = function() end,
        SetSize = function(self, width, height) self.size = {width, height} end,
        SetText = function(self, value)
            assert(not rawequal(value, secret), 'restricted values must not reach numeric text')
            self.text = value
        end,
        SetTextColor = function(self, ...) self.color = {...} end,
        SetAlpha = function(self, value) self.alpha = value end,
    }
end
local manaBar = {
    GetWidth = function() return 100 end,
    GetHeight = function() return 24 end,
    GetFrameLevel = function() return 2 end,
}
local personalPowerBar = {
    GetWidth = function() return 160 end,
    GetHeight = function() return 10 end,
    GetFrameLevel = function() return 4 end,
}
local alternatePowerBar = {GetWidth = function() return 140 end, GetHeight = function() return 8 end,
    GetFrameLevel = function() return 4 end}
local alternateMana, alternateMax = 500, 1000
UnitClass = function() return 'Druid', 'DRUID' end
PersonalResourceDisplayFrame = nil
InCombatLockdown = function() return inCombat end
local playerFrame = {PlayerFrameContent = {PlayerFrameContentMain = {ManaBarArea = {ManaBar = manaBar}}}}
PlayerFrameManaBar = layout == 'legacy' and manaBar or nil
PlayerFrame = (layout == 'forever' or layout == 'secret') and playerFrame or nil
if layout == 'secret' then mana = secret end
GetTime = function() return now end
UnitPower = function(unit, power) assert(unit == 'player' and (power == 0 or power == 3)); if power == 0 and resource == 3 and PersonalResourceDisplayFrame and PersonalResourceDisplayFrame.AlternatePowerBar then return alternateMana end; return mana end
UnitPowerMax = function(unit, power) assert(unit == 'player' and (power == 0 or power == 3)); if power == 0 and resource == 3 and PersonalResourceDisplayFrame and PersonalResourceDisplayFrame.AlternatePowerBar then return alternateMax end; return maximum end
UnitPowerType = function() return resource end
Enum = {LuaCurveType = {Step = 1}}
C_CurveUtil = {CreateCurve = function()
    return {SetType = function(_, kind) assert(kind == 1) end,
        AddPoint = function(_, x, y) assert((x == 0 and y == 1) or (x == 1 and y == 0)) end}
end}
UnitPowerPercent = function(unit, power, unmodified, curve)
    assert(unit == 'player' and (power == resource or (power == 0 and resource == 3)) and unmodified == false and curve)
    local value, max = UnitPower(unit, power), UnitPowerMax(unit, power)
    if rawequal(value, secret) or rawequal(max, secret) then return secret end
    return value < max and 1 or 0
end
local spellCosts = {
    [123] = {{type = 0, cost = 50}},
    [124] = {{type = 0, cost = 0}},
    [125] = {{type = 3, cost = 50}},
    [126] = {{type = 0, cost = 50, requiredAuraID = 9, hasRequiredAura = false}},
    [127] = {{type = 0, cost = 50, requiredAuraID = 9, hasRequiredAura = true}},
    [128] = {{type = 0, cost = 0, costPerSec = 10}},
    [130] = {{type = 0, cost = secret}},
    [131] = {{type = 0, cost = 50, requiredAuraID = secret}},
    [132] = {{type = secret, cost = 50}},
    [133] = secret,
}
C_Spell = {GetSpellPowerCost = function(id)
    assert(not rawequal(id, secret), 'secret spell ID must never be queried')
    return spellCosts[id]
end}
local frame, slider, optionsPanel, settingsCategory
local function BaseFrame()
    return {
        scripts = {}, events = {},
        RegisterEvent = function(self, event) self.events[event] = true end,
        UnregisterEvent = function(self, event) self.events[event] = nil end,
        RegisterUnitEvent = function(self, event, unit) assert(unit == 'player'); self.events[event] = true end,
        SetScript = function(self, event, fn) self.scripts[event] = fn end,
        SetParent = function(self, parent)
            assert(not inCombat, 'power events must not reparent frames during combat')
            self.parent = parent
        end,
        SetAllPoints = function() assert(not inCombat, 'power events must not reanchor frames during combat') end,
        SetFrameLevel = function() assert(not inCombat, 'power events must not change frame levels during combat') end,
        CreateTexture = function() local r = Region(); textures[#textures + 1] = r; return r end,
        CreateFontString = function() local r = Region(); texts[#texts + 1] = r; return r end,
    }
end
CreateFrame = function(frameType, name, parent)
    if frameType == 'Slider' then
        slider = {
            scripts = {},
            SetWidth = function(self, value) self.width = value end,
            SetMinMaxValues = function(self, low, high) self.range = {low, high} end,
            SetValueStep = function(self, value) self.step = value end,
            SetObeyStepOnDrag = function(self, value) self.obeyStep = value end,
            SetPoint = function(self, ...) self.point = {...} end,
            SetScript = function(self, event, fn) self.scripts[event] = fn end,
            SetValue = function(self, value) self.value = value end,
            CreateFontString = function() return Region() end,
        }
        return slider
    end
    local newFrame = BaseFrame()
    if parent == personalPowerBar or parent == alternatePowerBar then
        newFrame.parent = parent
    elseif frameType == 'Frame' and frame then
        optionsPanel = newFrame
        optionsPanel.CreateFontString = function() return Region() end
    else
        frame = newFrame
    end
    return newFrame
end
Settings = {
    RegisterCanvasLayoutCategory = function(panel, name)
        assert(name == 'Forever Mana Tick')
        settingsCategory = {panel = panel, GetID = function() return 17 end}
        return settingsCategory
    end,
    RegisterAddOnCategory = function(category) assert(category == settingsCategory) end,
}
assert(loadfile('ForeverManaTick.lua'))('ForeverManaTick')
local function Event(event, unit, power, spell) frame.scripts.OnEvent(frame, event, unit, power, spell) end
local function Draw() frame.scripts.OnUpdate(frame, 0.1) end
local function Change(value, event, unit, power)
    mana = value
    Event(event or 'UNIT_POWER_UPDATE', unit or 'player', power or 'MANA')
    Draw()
end
Event('ADDON_LOADED', 'OtherAddon')
assert(not frame.scripts.OnUpdate)
Event('ADDON_LOADED', 'ForeverManaTick')
Event('PLAYER_LOGIN')
if layout == 'delayed' then
    assert(not frame.scripts.OnUpdate, 'missing player frame must wait for world entry')
    PlayerFrame = playerFrame
    Event('PLAYER_ENTERING_WORLD')
end
if layout == 'forever' and not savedScale then
    Draw()
    assert(#textures == 2, 'an absent personal display must not create indicators')
    PersonalResourceDisplayFrame = {}
    Event('ADDON_LOADED', 'Blizzard_PersonalResourceDisplay')
    assert(#textures == 2, 'a missing personal power bar must be ignored')
    PersonalResourceDisplayFrame.PowerBar = personalPowerBar
    inCombat = true
    Event('ADDON_LOADED', 'Blizzard_PersonalResourceDisplay')
    assert(#textures == 2, 'personal display creation must wait until combat ends')
    inCombat = false
    Event('PLAYER_REGEN_ENABLED')
    assert(#textures == 4, 'personal sparks must initialize when the bar becomes available')
    Draw()
    assert(textures[4].shown and textures[4].point[2] == personalPowerBar,
        'personal sweep must attach to the primary power bar')
    Change(400)
    now = 102.5; Draw()
    assert(textures[3].shown and not textures[4].shown and textures[3].point[4] == 80,
        'personal countdown must match the player bar using its own width')
    now = 105; Draw()
    assert(not textures[3].shown and textures[4].shown, 'personal sweep follows the countdown')
    resource = 1; Event('UNIT_DISPLAYPOWER', 'player'); Draw()
    assert(not textures[3].shown and not textures[4].shown, 'unsupported resources hide personal sparks')
    PersonalResourceDisplayFrame.AlternatePowerBar = alternatePowerBar
    Event('ADDON_LOADED', 'Blizzard_PersonalResourceDisplay')
    assert(#textures == 6, 'a late alternate power bar must acquire its own sparks')
    resource = 3; mana = 60; maximum = 100; now = 200
    Event('UNIT_DISPLAYPOWER', 'player'); Draw()
    assert(textures[4].shown and textures[6].shown and textures[6].point[2] == alternatePowerBar,
        'cat form displays independent energy and mana sweeps')
    alternateMana = 450; Event('UNIT_POWER_UPDATE', 'player', 'MANA'); Draw()
    now = 202.5; Draw()
    assert(textures[4].shown and textures[5].shown and textures[5].point[4] == 70,
        'mana loss starts a countdown without interrupting energy')
    alternateMana = secret; Event('UNIT_POWER_UPDATE', 'player', 'MANA'); Draw()
    alternateMana = 400; Event('UNIT_POWER_UPDATE', 'player', 'MANA'); Draw()
    now = 205; Draw()
    assert(not textures[5].shown and textures[6].shown, 'mana recovery must not fabricate another loss')
    Event('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast-guid', 123); Draw()
    assert(textures[5].shown and textures[4].shown, 'mana-cost casts start only the alternate countdown')
    now = 210; Draw()
    alternateMana = 1000; Event('UNIT_POWER_UPDATE', 'player', 'MANA'); Draw()
    assert(not textures[6].shown and textures[4].shown, 'full mana hides only the mana sweep')
    resource = 1; Event('UNIT_DISPLAYPOWER', 'player'); Draw()
    assert(not textures[5].shown and not textures[6].shown, 'other forms hide the alternate indicator')
    resource = 0; mana = 500; maximum = 1000; now = 100; Event('PLAYER_ENTERING_WORLD')
end
assert(frame.scripts.OnUpdate, 'mana display must initialize on ' .. layout .. ' frame layout')
assert(frame.parent == manaBar, 'display must attach to the visible mana bar')
assert(optionsPanel.name == 'Forever Mana Tick' and settingsCategory.panel == optionsPanel,
    'the spark control is registered in the addon settings category')
if layout == 'secret' then
    Draw()
    assert(not textures[1].shown and textures[2].shown and not texts[1].shown)
    assert(rawequal(textures[2].alpha, secret), 'native opacity result must pass directly to texture')
    Event('UNIT_POWER_FREQUENT', 'player', 'MANA')
    mana = 500
    Event('UNIT_POWER_UPDATE', 'player', 'MANA')
    Draw()
    assert(not texts[1].shown, 'first accessible mana must establish a baseline')
end
Draw()
assert(not textures[1].shown and textures[2].shown, 'login must not start a countdown')
assert(not texts[1].shown)
Change(400)
assert(textures[1].shown and not textures[2].shown)
assert(texts[1].text == '-100')
now = 102.5; Draw()
assert(textures[1].point[4] == 50, 'countdown midpoint')
now = 105; Draw()
assert(not textures[1].shown and textures[2].shown, 'five-second boundary')
Change(420)
assert(texts[1].text == '+20')
now = 106; Draw()
assert(textures[2].point[4] == 50, 'two-second tick midpoint')
assert(texts[1].alpha == 0.5)
Change(440)
assert(texts[1].alpha == 1, 'new gain restarts fade')
now = 106.4
Event('UNIT_POWER_FREQUENT', 'player', 'MANA'); Draw()
now = 107.5; Draw()
assert(not texts[1].shown, 'duplicate event must not extend fade')
Change(1000)
assert(not textures[2].shown, 'full mana hides tick')
resource = 1
Event('UNIT_DISPLAYPOWER', 'player'); Draw()
assert(not textures[1].shown and not textures[2].shown and not texts[1].shown)
mana = 800; resource = 0
Event('UNIT_DISPLAYPOWER', 'player'); Draw()
assert(not textures[1].shown and not texts[1].shown, 'form return resets baseline')
Event('PLAYER_ENTERING_WORLD'); Draw()
Change(750, 'UNIT_POWER_UPDATE', 'target')
assert(not texts[1].shown, 'other units ignored')
Event('UNIT_POWER_UPDATE', 'player', 'RAGE'); Draw()
assert(not texts[1].shown, 'other resources ignored')
Event('UNIT_MAXPOWER', 'player', 'MANA'); Draw()
assert(not texts[1].shown)
now = 110; Change(700)
now = 111.5; Draw()
assert(not texts[1].shown, 'text expires exactly at 1.5 seconds')
if layout ~= 'legacy' then
    Event('PLAYER_ENTERING_WORLD'); Draw()
    Change(secret, 'UNIT_POWER_FREQUENT')
    assert(not textures[1].shown and textures[2].shown and not texts[1].shown)
    assert(rawequal(textures[2].alpha, secret))
    Change(650)
    assert(not textures[1].shown and not texts[1].shown, 'restriction recovery must not fabricate a loss')
    maximum = secret
    Draw()
    assert(not textures[1].shown and textures[2].shown and not texts[1].shown)
    Event('UNIT_MAXPOWER', 'player', 'MANA')
    Event('UNIT_POWER_UPDATE', 'player', 'MANA')
    maximum = 1000
    Draw()
    Change(670)
    assert(texts[1].text == '+20', 'tracking resumes from the new accessible baseline')

    now = 200; mana = secret
    Event('PLAYER_ENTERING_WORLD'); Draw()
    Event('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast-guid', 123); Draw()
    assert(textures[1].shown and not textures[2].shown, 'mana-cost casts start countdown with secret mana')
    now = 202.5; Draw()
    assert(textures[1].point[4] == 50)
    for _, spell in ipairs({124, 125, 126, 129, 130, 131, 132, 133, secret}) do
        Event('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast-guid', spell); Draw()
        assert(textures[1].point[4] == 50, 'free, non-mana, inapplicable or restricted costs must not restart countdown')
    end
    Event('UNIT_POWER_FREQUENT', 'player', 'MANA'); Draw()
    assert(textures[1].point[4] == 50, 'secret power event must preserve cast countdown')
    now = 205; Draw()
    assert(not textures[1].shown and textures[2].shown)
    Event('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast-guid', 127); Draw()
    assert(textures[1].shown, 'applicable conditional cost starts countdown')
    Event('UNIT_SPELLCAST_CHANNEL_START', 'player', 'cast-guid', 128)
    now = 220; Draw()
    assert(textures[1].shown and textures[1].point[4] == 100, 'periodic mana channel holds countdown')
    Event('UNIT_SPELLCAST_CHANNEL_STOP', 'player', 'cast-guid', 128)
    now = 225; Draw()
    assert(not textures[1].shown and textures[2].shown, 'countdown ends five seconds after channel stop')
end

now = 300; resource = 3; mana = 60; maximum = 100
Event('UNIT_DISPLAYPOWER', 'player'); Draw()
assert(not textures[1].shown and textures[2].shown, 'energy has a sweep but no five-second rule')
Change(30, 'UNIT_POWER_UPDATE', 'player', 'ENERGY')
assert(texts[1].text == '-30' and not textures[1].shown)
Change(50, 'UNIT_POWER_FREQUENT', 'player', 'ENERGY')
assert(texts[1].text == '+20' and texts[1].color[1] == 1)
now = 300.2
Change(51, 'UNIT_POWER_FREQUENT', 'player', 'ENERGY')
assert(math.abs(textures[2].point[4] - 10) < 0.001, 'continuous gains must not pin the spark to the left edge')
Event('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast-guid', 123); Draw()
assert(not textures[1].shown, 'mana-cost spells must not start a countdown on an energy bar')
now = 301; Draw()
assert(textures[2].point[4] == 50, 'energy tick midpoint')
Change(100, 'UNIT_POWER_FREQUENT', 'player', 'ENERGY')
assert(not textures[2].shown, 'full energy hides sweep')
Event('UNIT_DISPLAYPOWER', 'player'); Draw()
Event('UNIT_POWER_UPDATE', 'player', 'MANA'); Draw()
assert(not texts[1].shown, 'inactive mana events must not alter energy baseline')
if layout ~= 'legacy' then
    mana = secret
    Event('UNIT_DISPLAYPOWER', 'player'); Draw()
    assert(textures[2].shown and rawequal(textures[2].alpha, secret) and not textures[1].shown)
end
resource = 0; mana = 500; maximum = 1000
Event('UNIT_DISPLAYPOWER', 'player'); Draw()
assert(not texts[1].shown and not textures[1].shown, 'return to mana resets energy baseline')
resource = 3; mana = 30; maximum = 100; now = 400
Event('UNIT_DISPLAYPOWER', 'player'); Draw()
now = 400.2; Change(31, 'UNIT_POWER_UPDATE', 'player', 'ENERGY')
now = 401; Change(51, 'UNIT_POWER_UPDATE', 'player', 'ENERGY')
assert(textures[2].point[4] == 0, 'a recognizable 20-energy gain synchronizes inside the gain throttle')
mana = 30; now = 410; Event('UNIT_DISPLAYPOWER', 'player'); Draw()
now = 410.2; Change(31, 'UNIT_POWER_UPDATE', 'player', 'ENERGY')
now = 411; Change(71, 'UNIT_POWER_UPDATE', 'player', 'ENERGY')
assert(textures[2].point[4] == 0, 'a recognizable 40-energy gain synchronizes the sweep')
mana = 90; now = 420; Event('UNIT_DISPLAYPOWER', 'player'); Draw()
now = 420.4; Change(100, 'UNIT_POWER_UPDATE', 'player', 'ENERGY')
assert(not textures[2].shown, 'the sweep remains hidden at maximum energy')
now = 421; Change(99, 'UNIT_POWER_UPDATE', 'player', 'ENERGY')
assert(math.abs(textures[2].point[4] - 30) < 0.001, 'a gain that reached maximum synchronizes the next sweep')
mana = 30; now = 430; Event('UNIT_DISPLAYPOWER', 'player'); Draw()
now = 430.2; Change(31, 'UNIT_POWER_UPDATE', 'player', 'ENERGY')
now = 431; Change(34, 'UNIT_POWER_UPDATE', 'player', 'ENERGY')
assert(textures[2].point[4] == 50, 'unrecognized energy gains leave the two-second estimate running')
now = 432; Draw()
assert(textures[2].point[4] == 0, 'the two-second estimate wraps when no tick is observed')
assert(slider and slider.range[1] == 0.5 and slider.range[2] == 1.5, 'settings expose the spark scale slider')
assert(slider.step == 0.05 and slider.value == (savedScale or 1), 'slider loads its default or saved scale')
assert(textures[1].size[2] == 24 * 1.5 * (savedScale or 1), '100% uses the previous 150% spark size')
assert(textures[1].size[1] == 12 * 1.5 * (savedScale or 1), 'spark width preserves the original texture ratio')
slider.scripts.OnValueChanged(slider, 1.25)
assert(ForeverManaTickDB.sparkScale == 1.25, 'slider changes persist in the addon saved variable')
assert(textures[1].size[2] == 45 and textures[2].size[2] == 45, 'slider updates both sparks immediately')
if personalPowerBar == (PersonalResourceDisplayFrame and PersonalResourceDisplayFrame.PowerBar) then
    assert(textures[3].size[2] == 18.75 and textures[4].size[2] == 18.75,
        'slider updates personal sparks relative to the personal bar')
    assert(textures[5].size[2] == 15 and textures[6].size[2] == 15,
        'slider updates alternate sparks relative to the alternate bar')
end
slider.value = 0.5
optionsPanel.scripts.OnShow(optionsPanel)
assert(slider.value == 1.25 and ForeverManaTickDB.sparkScale == 1.25, 'opening settings refreshes the saved slider value')
now = 500; resource = 0; mana = 500; maximum = 1000
Event('PLAYER_ENTERING_WORLD'); Draw()
inCombat = true
Change(450)
now = 501; mana = 600; maximum = 1200
Event('UNIT_MAXPOWER', 'player', 'MANA'); Draw()
assert(textures[1].shown and textures[1].point[4] == 80,
    'capacity changes must preserve the active five-second countdown')
assert(not texts[1].shown, 'capacity changes reset numeric tracking without fabricating a gain')
Event('UNIT_POWER_UPDATE', 'player', 'MANA'); Draw()
assert(not texts[1].shown, 'the new capacity establishes the numeric baseline')
now = 505; Draw()
assert(not textures[1].shown and textures[2].shown, 'capacity changes must not extend the countdown')
Event('UNIT_SPELLCAST_CHANNEL_START', 'player', 'cast-guid', 128)
now = 506; maximum = 1300
Event('UNIT_MAXPOWER', 'player', 'MANA')
now = 512; Draw()
assert(textures[1].shown and textures[1].point[4] == 100,
    'capacity changes must not forget an ongoing periodic mana channel')
Event('UNIT_SPELLCAST_CHANNEL_STOP', 'player', 'cast-guid', 128)
now = 517; Draw()
assert(not textures[1].shown and textures[2].shown)
Change(550)
assert(texts[1].text == '-50', 'mana deltas resume from the new capacity baseline')
now = 518
Event('UNIT_MAXPOWER', 'player', 'ENERGY'); Draw()
assert(textures[1].shown and textures[1].point[4] == 80 and texts[1].shown,
    'inactive resource capacity changes must not reset mana tracking')
Event('UNIT_DISPLAYPOWER', 'player'); Draw()
assert(not textures[1].shown and not texts[1].shown, 'resource switches still clear all tracking')
if layout ~= 'legacy' then
    now = 520
    Event('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast-guid', 123)
    now = 521
    for _, values in ipairs({{secret, 1300}, {500, secret}, {secret, secret}}) do
        mana, maximum = values[1], values[2]
        Event('UNIT_MAXPOWER', 'player', 'MANA'); Draw()
        assert(textures[1].shown and textures[1].point[4] == 80 and not texts[1].shown,
            'restricted current or maximum mana preserves the countdown without numeric tracking')
    end
    maximum = 1300; mana = 500
    Event('UNIT_MAXPOWER', 'player', 'MANA'); Draw()
    assert(textures[1].shown and textures[1].point[4] == 80 and not texts[1].shown,
        'readable capacity recovery preserves the countdown and resets the numeric baseline')
end
now = 530; resource = 3; mana = 30; maximum = 100
Event('UNIT_DISPLAYPOWER', 'player'); Draw()
now = 530.5; Change(50, 'UNIT_POWER_UPDATE', 'player', 'ENERGY')
now = 531; mana = 60; maximum = 120
Event('UNIT_MAXPOWER', 'player', 'ENERGY'); Draw()
assert(textures[2].shown and textures[2].point[4] == 25 and not textures[1].shown and not texts[1].shown,
    'energy capacity changes reset numeric tracking without restarting the two-second estimate')
now = 532; Change(80, 'UNIT_POWER_UPDATE', 'player', 'ENERGY')
assert(texts[1].text == '+20' and textures[2].point[4] == 0,
    'energy ticks resume from the new capacity baseline')
if layout ~= 'legacy' then
    Event('UNIT_MAXPOWER', secret, 'ENERGY')
    Event('UNIT_MAXPOWER', 'player', secret)
    Draw()
    assert(texts[1].shown and texts[1].text == '+20', 'restricted event payloads must leave tracking untouched')
    for _, values in ipairs({{secret, 120}, {80, secret}, {secret, secret}}) do
        mana, maximum = values[1], values[2]
        Event('UNIT_MAXPOWER', 'player', 'ENERGY'); Draw()
        assert(not textures[1].shown and textures[2].shown and not texts[1].shown,
            'restricted current or maximum energy must suppress numeric tracking')
        assert(rawequal(textures[2].alpha, secret), 'restricted opacity must pass directly to the native display')
    end
    mana = 70; maximum = 120
    Event('UNIT_MAXPOWER', 'player', 'ENERGY'); Draw()
    assert(not texts[1].shown, 'energy restriction recovery must establish a fresh baseline')
    Change(90, 'UNIT_POWER_UPDATE', 'player', 'ENERGY')
    assert(texts[1].text == '+20', 'energy gains resume from the readable baseline')
    resource = secret
    Event('UNIT_MAXPOWER', 'player', 'ENERGY'); Draw()
    assert(not textures[1].shown and not textures[2].shown and not texts[1].shown,
        'a restricted resource type must hide the display without querying restricted power types')
end
inCombat = false
print('Runtime behavior checks passed: ' .. layout)
end
Run('forever')
Run('legacy')
Run('delayed')
Run('secret')
Run('forever', 1.25)
