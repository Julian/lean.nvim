---@generic S
---@alias Constructor fun(self: any, ...: any): S
---@alias InductiveMethod fun(self: S, ...: any): any

---@alias ConstructorDefs table<string, Constructor> | table<string, table<string, InductiveMethod>>

---@class Inductive<S> : { [string]: InductiveMethod }
---@operator call(table): `S`

---Create a new inductive type.
---@param name string The name of the new type, used only for errors
---@param defs ConstructorDefs A table of constructor definitions
---@return Inductive
return function(name, defs)
  local Type = {}

  local to_obj

  local _, first = next(defs)
  if type(first) ~= 'table' then
    to_obj = function(_, t)
      return t
    end
  else
    local methods = vim.tbl_keys(first)

    to_obj = function(constructor_name, impl)
      local obj = setmetatable({
        serialize = function(self)
          return { [constructor_name] = self[1] }
        end,
      }, { __index = Type })

      for _, method_name in ipairs(methods) do
        local method = impl[method_name]

        if not method then
          error(('%s method is missing for %s.%s'):format(method_name, name, constructor_name))
        end
        obj[method_name] = method
        impl[method_name] = nil -- so we can tell if there are any extras...
      end

      local extra = next(impl)
      if extra then
        error(('%s method is unexpected for %s.%s'):format(extra, name, constructor_name))
      end
      return function(_, ...)
        return setmetatable({ ... }, {
          __index = obj,
          __call = function(_, ...)
            return Type[constructor_name](Type, ...)
          end,
        })
      end
    end
  end

  local constructor_names = {}
  for constructor_name, impl in pairs(defs) do
    constructor_names[constructor_name] = true
    Type[constructor_name] = to_obj(constructor_name, impl)
  end

  ---Create a matcher which dispatches on tagged data.
  ---
  ---Arms are validated once; the returned function only dispatches.
  ---@param arms table<string, function> a handler for each constructor
  ---@return fun(data: table, ...: any): any
  function Type:match(arms)
    for arm_name in pairs(arms) do
      if not constructor_names[arm_name] then
        error(('Extraneous match arm for %s: %s'):format(name, arm_name))
      end
    end
    for ctor_name in pairs(constructor_names) do
      if not arms[ctor_name] then
        error(('Non-exhaustive match on %s: missing %s'):format(name, ctor_name))
      end
    end

    return function(data, ...)
      local constructor_name, value = next(data)
      if not constructor_names[constructor_name] then
        error(('Invalid %s constructor: %s'):format(name, constructor_name))
      end
      return arms[constructor_name](value, ...)
    end
  end

  return setmetatable(Type, {
    __call = function(self, data, ...)
      local constructor_name, value = next(data)
      if not constructor_names[constructor_name] then
        error(('Invalid %s constructor: %s'):format(name, constructor_name))
      end
      return self[constructor_name](self, value, ...)
    end,
  })
end
