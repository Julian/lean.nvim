local Stopwatch = require 'std.stopwatch'
local async = require 'std.async'

---Create a fake clock that returns successive values from a list.
---@param ticks integer[]
---@return fun(): integer
local function fake_clock(ticks)
  local i = 0
  return function()
    i = i + 1
    return ticks[i]
  end
end

describe('std.stopwatch', function()
  it('records sequential phase durations', function()
    -- birth=0, open a=10, close a=30, open b=40, close b=100, finish=110
    local sw = Stopwatch:new(fake_clock { 0, 10, 30, 40, 100, 110 })
    sw:open 'a'
    sw:close()
    sw:open 'b'
    sw:close()
    local times = sw:finish()
    assert.are.same({ a = 20, b = 60, total = 110 }, times)
  end)

  it('records nested phases with dotted keys', function()
    -- birth=0, open outer=10, open inner=20, close inner=50, close outer=70, finish=80
    local sw = Stopwatch:new(fake_clock { 0, 10, 20, 50, 70, 80 })
    sw:open 'outer'
    sw:open 'inner'
    sw:close()
    sw:close()
    local times = sw:finish()
    assert.are.same({ outer = 60, ['outer.inner'] = 30, total = 80 }, times)
  end)

  it('records deeply nested phases', function()
    -- birth=0, open a=1, open b=2, open c=3, close c=6, close b=8, close a=10, finish=12
    local sw = Stopwatch:new(fake_clock { 0, 1, 2, 3, 6, 8, 10, 12 })
    sw:open 'a'
    sw:open 'b'
    sw:open 'c'
    sw:close()
    sw:close()
    sw:close()
    local times = sw:finish()
    assert.are.same({ a = 9, ['a.b'] = 6, ['a.b.c'] = 3, total = 12 }, times)
  end)

  it('records multiple children within a parent', function()
    -- birth=0, open p=1, open x=2, close x=5, open y=6, close y=10, close p=11, finish=12
    local sw = Stopwatch:new(fake_clock { 0, 1, 2, 5, 6, 10, 11, 12 })
    sw:open 'p'
    sw:open 'x'
    sw:close()
    sw:open 'y'
    sw:close()
    sw:close()
    local times = sw:finish()
    assert.are.same({ p = 10, ['p.x'] = 3, ['p.y'] = 4, total = 12 }, times)
  end)

  it('times a function call as a phase', function()
    local sw = Stopwatch:new(fake_clock { 0, 10, 30, 40 })
    local result = sw:time('add', function(a, b)
      return a + b
    end, 3, 4)
    assert.is.equal(7, result)
    assert.are.same({ add = 20, total = 40 }, sw:finish())
  end)

  it('times a function returning multiple values', function()
    local sw = Stopwatch:new(fake_clock { 0, 10, 30, 40 })
    local a, b = sw:time('multi', function()
      return 'x', 'y'
    end)
    assert.is.equal('x', a)
    assert.is.equal('y', b)
    assert.are.same({ multi = 20, total = 40 }, sw:finish())
  end)

  it('defaults to vim.uv.hrtime', function()
    local sw = Stopwatch:new()
    sw:open 'phase'
    sw:close()
    local times = sw:finish()
    assert.is_truthy(times.phase >= 0)
    assert.is_truthy(times.total >= 0)
  end)

  describe('concurrent', function()
    it('records each child plus a wall-time at the top level', function()
      -- birth=0; outer_start=10; a_start=20, a_end=30; b_start=40, b_end=80;
      -- wall_end=90; finish=100
      local sw = Stopwatch:new(fake_clock { 0, 10, 20, 30, 40, 80, 90, 100 })
      local results
      async.run(function()
        results = sw:concurrent('parallel', {
          {
            'a',
            function()
              return 1
            end,
          },
          {
            'b',
            function()
              return 'x', 'y'
            end,
          },
        })
      end)
      assert.are.same({ { 1 }, { 'x', 'y' } }, results)
      local times = sw:finish()
      assert.are.same({
        a = 10,
        b = 40,
        parallel = 80,
        total = 100,
      }, times)
    end)

    it('records under the currently-open phase as a prefix', function()
      -- birth=0; open content=10; outer_start=20; a_start=30, a_end=40;
      -- wall_end=50; close content=60; finish=70
      local sw = Stopwatch:new(fake_clock { 0, 10, 20, 30, 40, 50, 60, 70 })
      async.run(function()
        sw:open 'content'
        sw:concurrent('parallel', {
          { 'a', function() end },
        })
        sw:close()
      end)
      local times = sw:finish()
      assert.are.same({
        content = 50,
        ['content.a'] = 10,
        ['content.parallel'] = 30,
        total = 70,
      }, times)
    end)

    it('runs phases concurrently — all start before any completes', function()
      local started = 0
      local complete_a = async.event()
      local complete_b = async.event()

      async.run(function()
        local sw = Stopwatch:new()
        sw:concurrent('parallel', {
          {
            'a',
            function()
              started = started + 1
              complete_a.wait()
            end,
          },
          {
            'b',
            function()
              started = started + 1
              complete_b.wait()
            end,
          },
        })
      end)

      assert.are.equal(2, started)
      complete_a.set()
      complete_b.set()
    end)
  end)
end)
