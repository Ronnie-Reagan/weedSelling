local M = {}
function M.new()
  local love = {}
  love.graphics = {
    setColor = function() end,
    rectangle = function() end,
    circle = function() end,
    print = function() end,
    printf = function() end
  }
  love.window = {
    getDesktopDimensions = function() return 800, 600 end,
    getMode = function() return 800, 600 end
  }
  love.mouse = {
    getPosition = function() return 0,0 end
  }
  love.timer = { getTime = function() return 0 end }
  love.data = {
    encode = function(_,_,d) return d end,
    decode = function(_,_,d) return d end
  }
  love.filesystem = {
    getInfo = function() return nil end,
    read = function() return nil end,
    write = function() return true end,
    getDirectoryItems = function() return {} end,
    load = function() return nil end
  }
  return love
end
return M
