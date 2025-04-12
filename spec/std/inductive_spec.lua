local inductive = require 'std.inductive'

describe('inductive', function()
  local Maybe = inductive('Maybe', {
    some = function(_, value)
      return { inner = value }
    end,
    nothing = function()
      return 37
    end,
  })

  it('calls the appropriate constructor from a tagged value', function()
    local some = Maybe { some = 42 }
    local none = Maybe { nothing = {} }
    assert.are.same({ Maybe:some(42), Maybe:nothing() }, { some, none })
  end)

  it('errors when given an unknown constructor', function()
    assert.has_error(function()
      Maybe { does_not_exist = 42 }
    end, 'Invalid Maybe constructor: does_not_exist')
  end)

  it('supports directly calling constructors', function()
    local some = Maybe:some(42)
    local none = Maybe:nothing()
    assert.are.same({ { inner = 42 }, 37 }, { some, none })
  end)

  it('supports passing along additional arguments', function()
    local Foo = inductive('Foo', {
      const = function()
        return 37
      end,
      id = function(_, x)
        return x
      end,
      add = function(_, x, y)
        return x + y
      end,
      combine = function(self, x, y)
        return self(x) + y
      end,
    })

    assert.are.same(Foo({ const = {} }, 73), 37)
    assert.are.same(Foo({ id = 12 }, 73), 12)
    assert.are.same(Foo({ add = 37 }, 73), 73 + 37)
    assert.are.same(Foo({ combine = { id = 37 } }, 73), 73 + 37)
  end)

  it('can have no constructors', function()
    local Empty = inductive('Empty', {})
    assert.has_error(function()
      Empty { something = 37 }
    end, 'Invalid Empty constructor: something')
  end)

  describe('with additional methods', function()
    it('are defined for each constructor', function()
      local MaybeWithMethods = inductive('Maybe', {
        some = {
          map = function(self, f)
            return self(f(self[1]))
          end,
          unwrap_or = function(self)
            return self[1]
          end,
        },
        nothing = {
          map = function(self)
            return self()
          end,
          unwrap_or = function(_, default)
            return default
          end,
        },
      })

      local x = MaybeWithMethods:some(42)
      local y = MaybeWithMethods:nothing()

      local doubled = x:map(function(n)
        return n * 2
      end)
      assert.are.equal(84, doubled:unwrap_or(0))

      local still_nothing = y:map(function(n)
        return n * 2
      end)
      assert.are.equal(0, still_nothing:unwrap_or(0))
    end)

    it('allow explicitly calling constructors', function()
      local MaybeExplicitConstructor = inductive('Maybe', {
        some = {
          map = function(self, f)
            return self:some(f(self[1]))
          end,
          unwrap_or = function(self)
            return self[1]
          end,
        },
        nothing = {
          map = function(self)
            return self
          end,
          unwrap_or = function(_, default)
            return default
          end,
        },
      })

      local x = MaybeExplicitConstructor:some(42)
      local y = MaybeExplicitConstructor:nothing()

      assert.are.equal(42, x:unwrap_or(0))
      assert.are.equal(0, y:unwrap_or(0))

      local doubled = x:map(function(n)
        return n * 2
      end)
      assert.are.equal(84, doubled:unwrap_or(0))

      local still_nothing = y:map(function(n)
        return n * 2
      end)
      assert.are.equal(0, still_nothing:unwrap_or(0))
    end)

    it('errors when a method is not defined for all constructors', function()
      local function missing_map_err()
        return inductive('Result', {
          ok = {
            map = function(self)
              return self
            end,
          },
          err = {},
        })
      end

      local _, error = pcall(missing_map_err)
      assert.is.truthy(
        error:match 'map method is missing for Result.err'
          or error:match 'map method is unexpected for Result.ok'
      )
    end)

    it('supports serializing back to a plain table', function()
      local Foo = inductive('Foo', {
        id = {
          calc = function(_, z)
            return z
          end,
        },
        const = {
          calc = function(self, z)
            return self[1] + z
          end,
        },
        pair = {
          calc = function(self, z)
            return self.x + self.y + z
          end,
        },
      })

      local id = { id = {} }
      assert.are.same(id, Foo(id):serialize())

      local const = { const = 37 }
      assert.are.same(const, Foo(const):serialize())

      local pair = { pair = { x = 37, y = 73 } }
      assert.are.same(pair, Foo(pair):serialize())
    end)
  end)
end)
