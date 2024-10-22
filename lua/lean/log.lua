---@type Log
local log = vim.schedule_wrap(require 'lean.config'().log)

---@class LogMessage: { message: string?, [string]: any }
---@alias Log fun(level: integer, data: LogMessage):nil

---A logger of internal `lean.nvim` events.
local Logger = {
  debug = function(self, ...)
    self(vim.log.levels.DEBUG, ...)
  end,
  error = function(self, ...)
    self(vim.log.levels.ERROR, ...)
  end,
  info = function(self, ...)
    self(vim.log.levels.INFO, ...)
  end,
  trace = function(self, ...)
    self(vim.log.levels.TRACE, ...)
  end,
  warning = function(self, ...)
    self(vim.log.levels.WARN, ...)
  end,

  ---Log a given event.
  __call = function(_, ...)
    log(...)
  end,
}

return setmetatable(Logger, Logger)
