-- Minimal push-like screen scaling stub.
-- Replace this with the official push library for full behavior.
local push = {}

function push:setupScreen(virtualWidth, virtualHeight, windowWidth, windowHeight, options)
    self.virtualWidth = virtualWidth
    self.virtualHeight = virtualHeight
    self.windowWidth = windowWidth
    self.windowHeight = windowHeight

    self._scaleX = windowWidth / virtualWidth
    self._scaleY = windowHeight / virtualHeight
    self._options = options or {}
end

function push:resize(w, h)
    self.windowWidth = w
    self.windowHeight = h
    self._scaleX = w / self.virtualWidth
    self._scaleY = h / self.virtualHeight
end

function push:start()
    love.graphics.push()
    love.graphics.scale(self._scaleX, self._scaleY)
end

function push:finish()
    love.graphics.pop()
end

return push
