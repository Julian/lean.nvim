---A ring buffer that supports non-destructive reads.
---
---Wraps a plain array with a write cursor that cycles, providing O(1) push
---and non-destructive access to all stored items via :items().
---
---vim.ringbuf is a FIFO queue whose iteration is destructive (it pops);
---this implementation is intended for history buffers where you need to
---read back all entries without draining them.
---@class std.Ringbuf<T>
---@field private _buf any[]
---@field private _cap integer
---@field private _next integer
local Ringbuf = {}
Ringbuf.__index = Ringbuf

---Create a new ring buffer with the given capacity.
---@generic T
---@param capacity integer
---@return std.Ringbuf<T>
function Ringbuf:new(capacity)
  return setmetatable({ _buf = {}, _cap = capacity, _next = 1 }, self)
end

---Push an item into the buffer, overwriting the oldest if full.
---@param item any
function Ringbuf:push(item)
  self._buf[self._next] = item
  self._next = self._next % self._cap + 1
end

---Return all stored items oldest-first as a plain list.
---
---Non-destructive: the buffer is not modified.
---@return any[]
function Ringbuf:items()
  if #self._buf < self._cap then
    return vim.list_slice(self._buf, 1, #self._buf)
  end
  local out = {}
  for i = 0, self._cap - 1 do
    out[i + 1] = self._buf[(self._next - 1 + i) % self._cap + 1]
  end
  return out
end

---Clear all items from the buffer.
function Ringbuf:clear()
  self._buf = {}
  self._next = 1
end

return Ringbuf
