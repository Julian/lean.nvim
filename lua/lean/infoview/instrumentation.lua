---@brief [[
--- Per-pin instrumentation: refresh timing history, render-time histogram,
--- visibility flash counter, plus the debug-pin Element that visualises them.
---@brief ]]

---@tag lean.infoview.instrumentation

local Histogram = require 'std.histogram'
local Ringbuf = require 'std.ringbuf'
local humanize = require 'std.humanize'

local Element = require('lean.tui').Element
local Graphic = require 'tui.graphic'
local Table = require 'tui.table'
local Tabs = require 'tui.tabs'
local plot = require 'tui.plot'
local percentile_distribution = plot.percentile_distribution

vim.api.nvim_set_hl(0, 'leanDebugTimingTrivial', { default = true, link = 'Comment' })
vim.api.nvim_set_hl(0, 'leanDebugTimingDominant', { default = true, link = 'DiagnosticWarn' })
vim.api.nvim_set_hl(0, 'leanDebugVisibilityFlash', { default = true, link = 'DiagnosticWarn' })

---A single refresh timing record stored in the pin's history ring buffer.
---@class PinRefreshRecord
---@field timing table<string, integer> phase durations from the stopwatch (dotted paths)
---@field uri string the document URI this refresh was for
---@field stale boolean whether this update was discarded as stale
---@field timestamp integer hrtime when this refresh completed; the next
---  record's timestamp minus this one is how long this content was visible

local REFRESH_HISTORY_SIZE = 128

local MS = 1e6
local SECOND = 1e9

---A "flash" is content that was on screen for less than this — too brief
---to read. Counting these is the cheap signal that catches refresh thrash.
local FLASH_THRESHOLD_NS = 100 * MS

---Sparkline glyphs from idle (1 event/s) up to thrash (8+ events/s).
---Empty buckets render as a space so quiet stretches stay obvious.
local RATE_BARS = { '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█' }

---Pick the sparkline glyph for a given event count in a 1-second bucket.
---@param count integer
---@return string
local function rate_bar(count)
  if count <= 0 then
    return ' '
  end
  return RATE_BARS[math.min(count, #RATE_BARS)]
end

---Build the flash-count line: "flashes: N", coloured if any have happened.
---@param flashes integer
---@return Element
local function flashes_element(flashes)
  local text = ('flashes: %d'):format(flashes)
  if flashes > 0 then
    return Element:new { text = text, hlgroups = { 'leanDebugVisibilityFlash' } }
  end
  return Element.text(text)
end

---Kernel-density estimate of the recent refresh rate, evaluated at `n`
---equally-spaced points covering the last `window_ns` of wall clock time.
---Each refresh contributes a Gaussian bump of width `sigma_ns`; the
---resulting curve slides smoothly as `now` advances because each output
---value depends continuously on it (no bucket-boundary discretisation).
---@param records PinRefreshRecord[]
---@param n integer evaluation points (left = oldest, right = now)
---@param window_ns integer time span the chart represents
---@param sigma_ns integer per-refresh kernel width (≈ visible bump duration)
---@return number[]
local function refresh_density(records, n, window_ns, sigma_ns)
  local now = vim.uv.hrtime()
  local cutoff = 4 * sigma_ns -- Gaussian tail is negligible past 4σ.
  local out = {}
  for i = 1, n do
    -- Pixel i ↔ wall-clock time linearly between now-window_ns (left) and now (right).
    local pixel_time = now - window_ns * (n - i) / (n - 1)
    local sum = 0
    for _, record in ipairs(records) do
      local dt = pixel_time - record.timestamp
      if math.abs(dt) < cutoff then
        local x = dt / sigma_ns
        sum = sum + math.exp(-0.5 * x * x)
      end
    end
    out[i] = sum
  end
  return out
end

---Text fallback sparkline: one Unicode block glyph per kernel-density
---sample. Heights round to the nearest integer event-count level.
---@param values number[]
---@return Element
local function refresh_rate_sparkline_element(values)
  local glyphs = {}
  for i, v in ipairs(values) do
    glyphs[i] = rate_bar(math.floor(v + 0.5))
  end
  return Element.text(table.concat(glyphs))
end

---Format a duration as an Element, dimmed if trivial relative to a total.
---@param ns number the phase duration
---@param total? number the reference total (omit to skip relative coloring)
---@return Element
local function duration_element(ns, total)
  local formatted = humanize.duration(ns)
  if total and total > 0 then
    local fraction = ns / total
    if fraction < 0.05 then
      return Element:new { text = formatted, hlgroups = { 'leanDebugTimingTrivial' } }
    elseif fraction > 0.7 then
      return Element:new { text = formatted, hlgroups = { 'leanDebugTimingDominant' } }
    end
  end
  return Element.text(formatted)
end

---Split a list of {name, ns} entries into significant and trivial
---based on a 1% threshold relative to the reference value.
---@param phases { name: string, ns: number }[]
---@param reference number
---@return { name: string, ns: number }[] significant
---@return { name: string, ns: number }[] trivial
local function partition_phases(phases, reference)
  local threshold = reference * 0.01
  local significant, trivial = {}, {}
  for _, entry in ipairs(phases) do
    if entry.ns >= threshold then
      table.insert(significant, entry)
    else
      table.insert(trivial, entry)
    end
  end
  return significant, trivial
end

---All instrumentation collected for a single pin's refreshes.
---@class PinInstrumentation
---@field history std.Ringbuf<PinRefreshRecord>
---@field render_times std.Histogram
---@field flashes integer count of refreshes whose content was on screen
---  for less than `FLASH_THRESHOLD_NS` (i.e. effectively never seen)
---@field private _last_timestamp? integer
---@field private _clock fun(): integer
local Instrumentation = {}
Instrumentation.__index = Instrumentation

---@param clock? fun(): integer hrtime-style clock; defaults to `vim.uv.hrtime`
function Instrumentation:new(clock)
  return setmetatable({
    history = Ringbuf:new(REFRESH_HISTORY_SIZE),
    render_times = Histogram:new(),
    flashes = 0,
    _clock = clock or vim.uv.hrtime,
  }, self)
end

---Start a stopwatch whose total time is recorded into render_times on finish.
function Instrumentation:stopwatch()
  return self.render_times:stopwatch(self._clock)
end

---Record a completed refresh: now that we know how long the previous
---record's content was on screen, count it as a flash if it was too
---brief to read; then append the new record stamped with `now`.
---@param timing table<string, integer>
---@param uri string
---@param stale boolean
function Instrumentation:record(timing, uri, stale)
  local now = self._clock()
  if self._last_timestamp and now - self._last_timestamp < FLASH_THRESHOLD_NS then
    self.flashes = self.flashes + 1
  end
  self.history:push { timing = timing, uri = uri, stale = stale, timestamp = now }
  self._last_timestamp = now
end

---@class InstrumentationDebugOpts
---@field expanded table<string, boolean> tracks which phases are expanded across rebuilds
---@field active_tab integer current tab index
---@field on_tab_change fun(i: integer) called when the user clicks a different tab
---@field position string formatted "Last refresh at ..." location
---@field text_columns? integer text-area width for sizing charts

---Build the debug Element summarizing recent refresh activity for a pin.
---
---Layout: an always-visible header showing the most recent refresh's
---per-phase timings, then a tab strip switching between aggregate render
---times (percentile curve) and refresh rate (live wave).
---@param opts InstrumentationDebugOpts
---@return Element
function Instrumentation:debug_element(opts)
  local histogram = self.render_times
  local records = self.history:items()
  local latest = records[#records]
  local children = {}

  -- Last refresh table: top-level phases are rows, phases with
  -- children (like content) become foldable rows.
  local total_ns = latest.timing.total
  local top_phases = {}
  local sub_phase_data = {}
  for phase, ns in vim.spairs(latest.timing) do
    local dot = phase:find('.', 1, true)
    if dot then
      local parent = phase:sub(1, dot - 1)
      sub_phase_data[parent] = sub_phase_data[parent] or {}
      table.insert(sub_phase_data[parent], { name = phase:sub(dot + 1), ns = ns })
    else
      table.insert(top_phases, { name = phase, ns = ns })
    end
  end

  local detail_rows = {}
  local significant_top, trivial_top = partition_phases(top_phases, total_ns)
  for _, entry in ipairs(significant_top) do
    local subs = sub_phase_data[entry.name]
    -- Color phases relative to total, but not total itself.
    local reference = entry.name ~= 'total' and total_ns or nil
    if subs then
      local sig_subs, triv_subs = partition_phases(subs, entry.ns)
      local child_rows = {}
      for _, sub in ipairs(sig_subs) do
        table.insert(
          child_rows,
          Table.row { Element.text(sub.name), duration_element(sub.ns, entry.ns) }
        )
      end
      if #triv_subs > 0 then
        local triv_rows = {}
        for _, sub in ipairs(triv_subs) do
          table.insert(
            triv_rows,
            Table.row { Element.text(sub.name), duration_element(sub.ns, entry.ns) }
          )
        end
        table.insert(
          child_rows,
          Table.foldable {
            cells = {
              Element:new {
                text = ('%d trivial'):format(#triv_subs),
                hlgroups = { 'leanDebugTimingTrivial' },
              },
              Element.text '',
            },
            children = triv_rows,
          }
        )
      end
      local phase_name = entry.name
      local function track_expanded()
        opts.expanded[phase_name] = not opts.expanded[phase_name]
      end
      table.insert(
        detail_rows,
        Table.foldable {
          cells = { Element.text(phase_name), duration_element(entry.ns, reference) },
          children = child_rows,
          open = opts.expanded[phase_name],
          on_open = track_expanded,
          on_close = track_expanded,
        }
      )
    else
      table.insert(
        detail_rows,
        Table.row { Element.text(entry.name), duration_element(entry.ns, reference) }
      )
    end
  end
  if #trivial_top > 0 then
    local triv_rows = {}
    for _, entry in ipairs(trivial_top) do
      table.insert(triv_rows, Table.row { Element.text(entry.name), duration_element(entry.ns) })
    end
    table.insert(
      detail_rows,
      Table.foldable {
        cells = {
          Element:new {
            text = ('%d trivial'):format(#trivial_top),
            hlgroups = { 'leanDebugTimingTrivial' },
          },
          Element.text '',
        },
        children = triv_rows,
      }
    )
  end
  if latest.stale then
    table.insert(detail_rows, Table.row { Element.text '(stale)', Element.text '—' })
  end

  table.insert(children, Element.text(('Last refresh at %s'):format(opts.position)))
  table.insert(children, Table.render(detail_rows))

  local columns = opts.text_columns

  ---@return Element
  local function render_times_body()
    local count = histogram:count()
    local summary_rows = {
      Table.row { Element.text 'min', duration_element(histogram:min()) },
      Table.row { Element.text 'p50', duration_element(histogram:value_at_quantile(50)) },
      Table.row { Element.text 'p90', duration_element(histogram:value_at_quantile(90)) },
      Table.row { Element.text 'p99', duration_element(histogram:value_at_quantile(99)) },
      Table.row { Element.text 'p99.9', duration_element(histogram:value_at_quantile(99.9)) },
      Table.row { Element.text 'max', duration_element(histogram:max()) },
    }
    return Element:concat({
      Element.text(('Aggregate (%d refreshes)'):format(count)),
      Graphic(function()
        return percentile_distribution(histogram, { columns = columns })
      end, function()
        return Table.render(summary_rows)
      end),
    }, '\n')
  end

  ---@return Element
  local function refresh_rate_body()
    local body_children = { flashes_element(self.flashes) }
    if #records > 0 then
      -- 60-second window, kernel density of refreshes per 500ms σ. Both
      -- branches sample the same continuous density — kitty at pixel
      -- resolution for the smooth wave, text at one cell per terminal
      -- column for the sparkline — so they move at the same wall-clock rate.
      local cols = columns or 60
      local kitty_density = refresh_density(records, 600, 60 * SECOND, 500 * MS)
      local text_density = refresh_density(records, cols, 60 * SECOND, 500 * MS)
      table.insert(
        body_children,
        Graphic(function()
          return plot.scatter(kitty_density, { columns = cols })
        end, function()
          return refresh_rate_sparkline_element(text_density)
        end)
      )
    end
    return Element:concat(body_children, '\n')
  end

  table.insert(children, Element.EMPTY)
  table.insert(
    children,
    Tabs {
      active = opts.active_tab,
      on_change = opts.on_tab_change,
      tabs = {
        { label = 'render times', body = render_times_body },
        { label = 'refresh rate', body = refresh_rate_body },
      },
    }
  )

  return Element:concat(children, '\n')
end

return Instrumentation
