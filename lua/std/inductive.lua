---Create a new inductive type.
---@param type_name string the type name, used only in error messages
---@param obj table<string, fun(...): any> an object containing each of the constructors
return function(type_name, obj)
  local mt = {
    __call = function(self, data, ...)
      local name, value = next(data)
      local constructor = self[name]
      if not constructor then
        error(('Invalid %s constructor: %s'):format(type_name, name))
      end
      return constructor(self, value, ...)
    end,
  }
  return setmetatable(obj, mt)
end
