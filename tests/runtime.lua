local function Run(layout)
local now, mana, maximum, resource = 100, 500, 1000, 0
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
        SetSize = function() end,
        SetText = function(self, value) self.text = value end,
        SetTextColor = function(self, ...) self.color = {...} end,
        SetAlpha = function(self, value) self.alpha = value end,
    }
end
local manaBar = {GetWidth = function() return 100 end, GetFrameLevel = function() return 2 end}
local playerFrame = {PlayerFrameContent = {PlayerFrameContentMain = {ManaBarArea = {ManaBar = manaBar}}}}
PlayerFrameManaBar = layout == 'legacy' and manaBar or nil
PlayerFrame = (layout == 'forever' or layout == 'secret') and playerFrame or nil
if layout == 'secret' then mana = secret end
GetTime = function() return now end
UnitPower = function(unit, power) assert(unit == 'player' and (power == 0 or power == 3)); return mana end
UnitPowerMax = function(unit, power) assert(unit == 'player' and (power == 0 or power == 3)); return maximum end
UnitPowerType = function() return resource end
Enum = {LuaCurveType = {Step = 1}}
C_CurveUtil = {CreateCurve = function()
    return {SetType = function(_, kind) assert(kind == 1) end,
        AddPoint = function(_, x, y) assert((x == 0 and y == 1) or (x == 1 and y == 0)) end}
end}
UnitPowerPercent = function(unit, power, unmodified, curve)
    assert(unit == 'player' and power == resource and unmodified == false and curve)
    if rawequal(mana, secret) or rawequal(maximum, secret) then return secret end
    return mana < maximum and 1 or 0
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
local frame
CreateFrame = function()
    frame = {
        scripts = {}, events = {},
        RegisterEvent = function(self, event) self.events[event] = true end,
        UnregisterEvent = function(self, event) self.events[event] = nil end,
        RegisterUnitEvent = function(self, event, unit) assert(unit == 'player'); self.events[event] = true end,
        SetScript = function(self, event, fn) self.scripts[event] = fn end,
        SetParent = function(self, parent) self.parent = parent end,
        SetAllPoints = function() end,
        SetFrameLevel = function() end,
        CreateTexture = function() local r = Region(); textures[#textures + 1] = r; return r end,
        CreateFontString = function() local r = Region(); texts[#texts + 1] = r; return r end,
    }
    return frame
end
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
assert(frame.scripts.OnUpdate, 'mana display must initialize on ' .. layout .. ' frame layout')
assert(frame.parent == manaBar, 'display must attach to the visible mana bar')
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
print('Runtime behavior checks passed: ' .. layout)
end
Run('forever')
Run('legacy')
Run('delayed')
Run('secret')
