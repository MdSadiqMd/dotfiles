-- In Ghostty, a quick tap of Control alone sends F12 (tmux prefix2). Combos and holds over 0.5s don't.
local ctrlHeld = false
local otherKey = false
local pressTime = 0

local function ghosttyFront()
  local app = hs.application.frontmostApplication()
  return app ~= nil and app:name() == 'Ghostty'
end

local modTap = hs.eventtap.new({ hs.eventtap.event.types.flagsChanged }, function(e)
  local f = e:getFlags()
  if f.ctrl and not f.cmd and not f.shift and not f.alt and not ctrlHeld then
    ctrlHeld = true
    otherKey = false
    pressTime = hs.timer.secondsSinceEpoch()
  elseif not f.ctrl and ctrlHeld then
    ctrlHeld = false
    if not otherKey and ghosttyFront() and hs.timer.secondsSinceEpoch() - pressTime < 0.5 then
      hs.eventtap.keyStroke({}, 'f12')
    end
  end
  return false
end)

local keyTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(_)
  otherKey = true
  return false
end)

modTap:start()
keyTap:start()
