---@type Log
local log = vim.schedule_wrap(require 'lean.config'().log)

---@class LogMessage: { message: string?, [string]: any }
---@alias Log fun(level: integer, data: LogMessage):nil

---A logger of internal `lean.nvim` events.
local Logger = {
  ---@param data LogMessage
  debug = function(self, data)
    self(vim.log.levels.DEBUG, data)
  end,
  error = function(self, data)
    self(vim.log.levels.ERROR, data)
  end,
  ---@param data LogMessage
  info = function(self, data)
    self(vim.log.levels.INFO, data)
  end,
  ---@param data LogMessage
  trace = function(self, data)
    self(vim.log.levels.TRACE, data)
  end,
  ---@param data LogMessage
  warning = function(self, data)
    self(vim.log.levels.WARN, data)
  end,

  ---Log a given event.
  ---@param level integer
  ---@param data LogMessage
  __call = function(_, level, data)
    log(level, data)
  end,
}

return setmetatable(Logger, Logger)
