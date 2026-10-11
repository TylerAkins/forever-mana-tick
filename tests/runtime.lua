local now, mana, maximum, resource = 100, 500, 1000, 0
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
        SetTextColor = function() end,
        SetAlpha = function(self, value) self.alpha = value end,
    }
end
PlayerFrameManaBar = {GetWidth = function() return 100 end, GetFrameLevel = function() return 2 end}
GetTime = function() return now end
UnitPower = function(unit, power) assert(unit == 'player' and power == 0); return mana end
UnitPowerMax = function(unit, power) assert(unit == 'player' and power == 0); return maximum end
UnitPowerType = function() return resource end
local frame
CreateFrame = function()
    frame = {
        scripts = {}, events = {},
        RegisterEvent = function(self, event) self.events[event] = true end,
        UnregisterEvent = function(self, event) self.events[event] = nil end,
        RegisterUnitEvent = function(self, event, unit) assert(unit == 'player'); self.events[event] = true end,
        SetScript = function(self, event, fn) self.scripts[event] = fn end,
        SetParent = function() end,
        SetAllPoints = function() end,
        SetFrameLevel = function() end,
        CreateTexture = function() local r = Region(); textures[#textures + 1] = r; return r end,
        CreateFontString = function() local r = Region(); texts[#texts + 1] = r; return r end,
    }
    return frame
end
assert(loadfile('ForeverManaTick.lua'))('ForeverManaTick')
local function Event(event, unit, power) frame.scripts.OnEvent(frame, event, unit, power) end
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
print('Runtime behavior checks passed')
