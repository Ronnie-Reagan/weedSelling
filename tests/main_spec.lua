local fake = require('tests.fake_love')
_G.love = fake.new()
local ui = require('ui')
dofile('main.lua')

describe('HUD Labels', function()
  it('builds labels after loading', function()
    love.load()
    -- run loading coroutine
    love.update(0)
    love.update(0)
    local function setGameState(value)
      for i=1, debug.getinfo(love.update).nups do
        local name = debug.getupvalue(love.update, i)
        if name == 'gameState' then
          debug.setupvalue(love.update, i, value)
          return
        end
      end
    end
    setGameState('game')
    love.update(0)
    assert.truthy(hudLabels['stash'])
    local idx = hudLabels['stash'].wallet
    assert.is_truthy(ui.states['stash'].labels[idx])
    assert.are.equal('Wallet: $50', ui.states['stash'].labels[idx].text)
  end)
end)
