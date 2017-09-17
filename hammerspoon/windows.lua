hs.window.animationDuration = 0
local spaces           = require('hs._asm.undocumented.spaces')

local cache = {
  mousePosition = nil
}

-- grabs screen with active window, unless it's Finder's desktop
-- then we use mouse position
local function activeScreen()
  local mousePoint = hs.geometry.point(hs.mouse.getAbsolutePosition())
  local activeWindow = hs.window.focusedWindow()

  if activeWindow and activeWindow:role() ~= 'AXScrollArea' then
    return activeWindow:screen()
  else
    return hs.fnutils.find(hs.screen.allScreens(), function(screen)
        return mousePoint:inside(screen:frame())
      end)
  end
end

local function focusScreen(screen)
  local frame = screen:frame()

  -- if mouse is already on the given screen we can safely return
  if hs.geometry(hs.mouse.getAbsolutePosition()):inside(frame) then return false end

  -- "hide" cursor in the lower right side of screen
  -- it's invisible while we are changing spaces
  local mousePosition = {
    x = frame.x + frame.w - 1,
    y = frame.y + frame.h - 1
  }

  -- hs.mouse.setAbsolutePosition doesn't work for gaining proper screen focus
  -- moving the mouse pointer with cliclick (available on homebrew) works
  os.execute(template([[ /usr/local/bin/cliclick m:={X},{Y} ]], { X = mousePosition.x, Y = mousePosition.y }))
  hs.timer.usleep(1000)

  return true
end

local function activeSpaceIndex(screenSpaces)
  return hs.fnutils.indexOf(screenSpaces, spaces.activeSpace()) or 1
end

local function screenSpaces(currentScreen)
  currentScreen = currentScreen or activeScreen()
  return spaces.layout()[currentScreen:spacesUUID()]
end

local function spaceInDirection(direction)
  local screenSpaces = screenSpaces()
  local activeIdx = activeSpaceIndex(screenSpaces)
  local targetIdx = direction == 'left' and activeIdx - 1 or activeIdx + 1

  return screenSpaces[targetIdx]
end

local function moveWindowOneSpace(win, direction)
  local clickPoint = win:zoomButtonRect()
  local sleepTime = 1000
  local targetSpace = spaceInDirection(direction)

  -- check if all conditions are ok to move the window
  local shouldMoveWindow = hs.fnutils.every({
      clickPoint ~= nil,
      targetSpace ~= nil,
      not cache.movingWindowToSpace
    }, function(test) return test end)

  if not shouldMoveWindow then return end

  cache.movingWindowToSpace = true

  cache.mousePosition = cache.mousePosition or hs.mouse.getAbsolutePosition()

  clickPoint.x = clickPoint.x + clickPoint.w + 5
  clickPoint.y = clickPoint.y + clickPoint.h / 2

  -- fix for Chrome UI
  if win:application():title() == 'Google Chrome' then
    clickPoint.y = clickPoint.y - clickPoint.h
  end

  -- focus screen before switching window
  focusScreen(win:screen())

  hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseDown, clickPoint):post()
  hs.timer.usleep(sleepTime)

  hs.eventtap.keyStroke({ 'ctrl' }, direction)

  hs.timer.waitUntil(
    function()
      return spaces.activeSpace() == targetSpace
    end,
    function()
      hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseUp, clickPoint):post()

      -- resetting mouse after small timeout is needed for focusing screen to work properly
      hs.mouse.setAbsolutePosition(cache.mousePosition)
      cache.mousePosition = nil

      -- reset cache
      cache.movingWindowToSpace = false

    end,
    0.01 -- check every 1/100 of a second
  )
end

-- +-----------------+
-- |        |        |
-- |  HERE  |        |
-- |        |        |
-- +-----------------+
function hs.window.left(win)
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()

  f.x = max.x
  f.y = max.y
  f.w = max.w / 2
  f.h = max.h
  win:setFrame(f)
end

-- +-----------------+
-- |        |        |
-- |        |  HERE  |
-- |        |        |
-- +-----------------+
function hs.window.right(win)
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()

  f.x = max.x + (max.w / 2)
  f.y = max.y
  f.w = max.w / 2
  f.h = max.h
  win:setFrame(f)
end

-- +-----------------+
-- |      HERE       |
-- +-----------------+
-- |                 |
-- +-----------------+
function hs.window.up(win)
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()

  f.x = max.x
  f.w = max.w
  f.y = max.y
  f.h = max.h / 2
  win:setFrame(f)
end

-- +-----------------+
-- |                 |
-- +-----------------+
-- |      HERE       |
-- +-----------------+
function hs.window.down(win)
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()

  f.x = max.x
  f.w = max.w
  f.y = max.y + (max.h / 2)
  f.h = max.h / 2
  win:setFrame(f)
end

-- +-----------------+
-- |  HERE  |        |
-- +--------+        |
-- |                 |
-- +-----------------+
function hs.window.upLeft(win)
  local f = win:frame()
  local screen = win:screen()
  local max = screen:fullFrame()

  f.x = max.x
  f.y = max.y
  f.w = max.w/2
  f.h = max.h/2
  win:setFrame(f)
end

-- +-----------------+
-- |                 |
-- +--------+        |
-- |  HERE  |        |
-- +-----------------+
function hs.window.downLeft(win)
  local f = win:frame()
  local screen = win:screen()
  local max = screen:fullFrame()

  f.x = max.x
  f.y = max.y + (max.h / 2)
  f.w = max.w/2
  f.h = max.h/2
  win:setFrame(f)
end

-- +-----------------+
-- |                 |
-- |        +--------|
-- |        |  HERE  |
-- +-----------------+
function hs.window.downRight(win)
  local f = win:frame()
  local screen = win:screen()
  local max = screen:fullFrame()

  f.x = max.x + (max.w / 2)
  f.y = max.y + (max.h / 2)
  f.w = max.w/2
  f.h = max.h/2

  win:setFrame(f)
end

-- +-----------------+
-- |        |  HERE  |
-- |        +--------|
-- |                 |
-- +-----------------+
function hs.window.upRight(win)
  local f = win:frame()
  local screen = win:screen()
  local max = screen:fullFrame()

  f.x = max.x + (max.w / 2)
  f.y = max.y
  f.w = max.w/2
  f.h = max.h/2
  win:setFrame(f)
end

-- +--------------+
-- |  |        |  |
-- |  |  HERE  |  |
-- |  |        |  |
-- +---------------+
function hs.window.centerWithFullHeight(win)
  local f = win:frame()
  local screen = win:screen()
  local max = screen:fullFrame()

  f.x = max.x
  f.w = max.w
  f.y = max.y
  f.h = max.h
  win:setFrame(f)
end

-- +-----------------+
-- |      |          |
-- | HERE |          |
-- |      |          |
-- +-----------------+
function hs.window.left40(win)
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()

  f.x = max.x
  f.y = max.y
  f.w = max.w * 0.4
  f.h = max.h
  win:setFrame(f)
end

-- +-----------------+
-- |           |     |
-- | HERE      |     |
-- |           |     |
-- +-----------------+
-- add 5 to cover annoying spaces
function hs.window.left66(win)
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()

  f.x = max.x
  f.y = max.y
  f.w = max.w * (2/3) + 5
  f.h = max.h
  win:setFrame(f)
end

-- +-----------------+
-- |           |     |
-- |           | HERE|
-- |           |     |
-- +-----------------+
-- add 5 to cover annoying spaces
function hs.window.right33(win)
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()

  f.x = max.x + (max.w * 2/3) + 5
  f.y = max.y
  f.w = max.w * (1/3)
  f.h = max.h
  win:setFrame(f)
end

-- +-----------------+
-- |      |          |
-- |      |   HERE   |
-- |      |          |
-- +-----------------+
function hs.window.right60(win)
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()

  f.x = max.w * 0.4
  f.y = max.y
  f.w = max.w * 0.6
  f.h = max.h
  win:setFrame(f)
end

function hs.window.nextScreen(win)
  local currentScreen = win:screen()
  local allScreens = hs.screen.allScreens()
  currentScreenIndex = hs.fnutils.indexOf(allScreens, currentScreen)
  nextScreenIndex = currentScreenIndex + 1

  if allScreens[nextScreenIndex] then
    win:moveToScreen(allScreens[nextScreenIndex])
  else
    win:moveToScreen(allScreens[1])
  end
end

function hs.window.moveWindowOneSpaceRight(win)
  moveWindowOneSpace(win, 'right')
end

function hs.window.moveWindowOneSpaceLeft(win)
  moveWindowOneSpace(win, 'left')
end

--------------------------------------------------------------------------------
-- Define WindowLayout Mode
--
-- WindowLayout Mode allows you to manage window layout using keyboard shortcuts
-- that are on the home row, or very close to it. Use Control+s to turn
-- on WindowLayout mode. Then, use any shortcut below to perform a window layout
-- action. For example, to send the window left, press and release
-- Control+s, and then press h.
--
--   h/j/k/l => send window to the left/bottom/top/right half of the screen
--   i => send window to the upper left quarter of the screen
--   o => send window to the upper right quarter of the screen
--   , => send window to the lower left quarter of the screen
--   . => send window to the lower right quarter of the screen
--   return => make window full screen
--   n => send window to the next monitor
--   left => send window to the monitor on the left (if there is one)
--   right => send window to the monitor on the right (if there is one)
--------------------------------------------------------------------------------

windowLayoutMode = hs.hotkey.modal.new({}, 'F16')

local message = require('keyboard.status-message')
windowLayoutMode.statusMessage = message.new('Window Layout Mode (control-s)')
windowLayoutMode.entered = function()
  windowLayoutMode.statusMessage:show()
end
windowLayoutMode.exited = function()
  windowLayoutMode.statusMessage:hide()
end

-- Bind the given key to call the given function and exit WindowLayout mode
function windowLayoutMode.bindWithAutomaticExit(mode, modifiers, key, fn)
  mode:bind(modifiers, key, function()
    mode:exit()
    fn()
  end)
end

windowLayoutMode:bindWithAutomaticExit({}, 'return', function()
  hs.window.focusedWindow():maximize()
end)

windowLayoutMode:bindWithAutomaticExit({}, 'space', function()
  hs.window.focusedWindow():centerWithFullHeight()
end)

windowLayoutMode:bindWithAutomaticExit({}, 'h', function()
  hs.window.focusedWindow():left66()
end)

windowLayoutMode:bindWithAutomaticExit({}, 'j', function()
  hs.window.focusedWindow():down()
end)

windowLayoutMode:bindWithAutomaticExit({}, 'k', function()
  hs.window.focusedWindow():up()
end)

windowLayoutMode:bindWithAutomaticExit({}, 'l', function()
  hs.window.focusedWindow():right33()
end)

windowLayoutMode:bindWithAutomaticExit({'shift'}, 'h', function()
  hs.window.focusedWindow():left40()
end)

windowLayoutMode:bindWithAutomaticExit({'shift'}, 'l', function()
  hs.window.focusedWindow():right60()
end)

windowLayoutMode:bindWithAutomaticExit({}, 'i', function()
  hs.window.focusedWindow():upLeft()
end)

windowLayoutMode:bindWithAutomaticExit({}, 'o', function()
  hs.window.focusedWindow():upRight()
end)

windowLayoutMode:bindWithAutomaticExit({}, ',', function()
  hs.window.focusedWindow():downLeft()
end)

windowLayoutMode:bindWithAutomaticExit({}, '.', function()
  hs.window.focusedWindow():downRight()
end)

windowLayoutMode:bindWithAutomaticExit({}, 'n', function()
  hs.window.focusedWindow():nextScreen()
end)

windowLayoutMode:bindWithAutomaticExit({}, 'right', function()
  hs.window.focusedWindow():moveWindowOneSpaceRight()
end)

windowLayoutMode:bindWithAutomaticExit({}, 'left', function()
  hs.window.focusedWindow():moveWindowOneSpaceLeft()
end)

windowLayoutMode:bindWithAutomaticExit({'shift'}, 'right', function()
  hs.window.focusedWindow():moveOneScreenEast()
end)

windowLayoutMode:bindWithAutomaticExit({'shift'}, 'left', function()
  hs.window.focusedWindow():moveOneScreenWest()
end)
-- Use Control+s to toggle WindowLayout Mode
hs.hotkey.bind({'ctrl'}, 's', function()
  windowLayoutMode:enter()
end)
windowLayoutMode:bind({'ctrl'}, 's', function()
  windowLayoutMode:exit()
end)
