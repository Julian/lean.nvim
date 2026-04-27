local Instrumentation = require 'lean.infoview.instrumentation'

local MS = 1e6

---Build a clock fixture that returns whatever `now` was last set to.
local function fake_clock()
  local now = 0
  return function()
    return now
  end, function(t)
    now = t
  end
end

describe('Instrumentation', function()
  it('starts empty', function()
    local i = Instrumentation:new()
    assert.are.same({}, i.history:items())
    assert.are.equal(0, i.flashes)
  end)

  it('appends records to history with timestamps', function()
    local clock, set_now = fake_clock()
    set_now(42)
    local i = Instrumentation:new(clock)
    i:record({ total = 1000 }, 'file:///foo', false)
    local items = i.history:items()
    assert.are.equal(1, #items)
    assert.are.equal('file:///foo', items[1].uri)
    assert.are.equal(false, items[1].stale)
    assert.are.equal(42, items[1].timestamp)
  end)

  it('counts a flash when consecutive records arrive within 100ms', function()
    local clock, set_now = fake_clock()
    set_now(0)
    local i = Instrumentation:new(clock)
    i:record({ total = 1 }, 'file:///foo', false)
    set_now(50 * MS) -- 50ms later
    i:record({ total = 1 }, 'file:///foo', false)
    assert.are.equal(1, i.flashes)
  end)

  it('does not count a flash when records are 100ms+ apart', function()
    local clock, set_now = fake_clock()
    set_now(0)
    local i = Instrumentation:new(clock)
    i:record({ total = 1 }, 'file:///foo', false)
    set_now(150 * MS) -- 150ms later
    i:record({ total = 1 }, 'file:///foo', false)
    assert.are.equal(0, i.flashes)
  end)

  it('accumulates flashes across many fast records', function()
    local clock, set_now = fake_clock()
    set_now(0)
    local i = Instrumentation:new(clock)
    for k = 0, 5 do
      set_now(k * 10 * MS) -- one record every 10ms
      i:record({ total = 1 }, 'file:///foo', false)
    end
    -- 6 records, 5 visibility intervals, all under 100ms ⇒ 5 flashes.
    assert.are.equal(5, i.flashes)
  end)

  it('records render time into the render_times histogram via stopwatch', function()
    local clock, set_now = fake_clock()
    set_now(0)
    local i = Instrumentation:new(clock)
    local sw = i:stopwatch()
    set_now(7 * MS)
    sw:finish()
    assert.are.equal(1, i.render_times:count())
  end)

  it('renders a debug Element containing the position, flashes, and tabs', function()
    local clock, set_now = fake_clock()
    set_now(0)
    local i = Instrumentation:new(clock)
    -- Populate both the render_times histogram (via stopwatch) and the
    -- ring buffer (via record), since the render-times tab needs at least
    -- one sample to compute percentiles.
    local sw = i:stopwatch()
    set_now(5 * MS)
    i:record(sw:finish(), 'file:///foo', false)

    local el = i:debug_element {
      expanded = {},
      active_tab = 1,
      on_tab_change = function() end,
      position = 'foo at 1:1',
      text_columns = 40,
    }
    local text = el:to_string()
    assert.is_truthy(text:find('Last refresh at foo at 1:1', 1, true))
    assert.is_truthy(text:find('render times', 1, true))
    assert.is_truthy(text:find('refresh rate', 1, true))
  end)
end)
