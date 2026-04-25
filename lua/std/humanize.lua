local humanize = {}

---Format a nanosecond duration as a human-readable string.
---@param ns number
---@return string
function humanize.duration(ns)
  if ns >= 1e9 then
    return ('%.2fs'):format(ns / 1e9)
  elseif ns >= 1e6 then
    return ('%.1fms'):format(ns / 1e6)
  elseif ns >= 1e3 then
    return ('%.0fµs'):format(ns / 1e3)
  end
  return ('%dns'):format(ns)
end

return humanize
