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
end)
